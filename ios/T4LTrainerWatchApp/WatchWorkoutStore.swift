import Foundation
import SwiftUI
import WatchKit

@MainActor
final class WatchWorkoutStore: ObservableObject {
  @Published private(set) var workout: WatchPlannedWorkout?
  @Published private(set) var startedAt: Date?
  @Published private(set) var activeExerciseStartedAt: Date?
  @Published private(set) var isPaused = false
  @Published private(set) var completedPendingSync = false
  @Published private(set) var summary: WatchWorkoutSummary?
  /// When true the summary view takes over the screen. Cleared once the user
  /// dismisses it (or starts a new exercise / receives a new workout), at
  /// which point the Today view shows the "done" card instead.
  @Published var showSummaryOverlay = false
  @Published var exerciseIndex = 0

  /// Reflects whether the workout currently sent from the phone is already
  /// completed. Used to render the "done" card on the Today screen instead
  /// of a Start button.
  var isWorkoutCompleted: Bool { summary != nil }

  let connectivity = WatchConnectivityManager()
  let workoutManager = WatchWorkoutManager()

  private var sets: [WatchLoggedSet] = []
  private var timings: [WatchExerciseTiming] = []
  private var pausedAt: Date?
  private var pausedSeconds = 0

  init() {
    if let cached = UserDefaults.standard.data(forKey: "cachedWatchWorkout"),
       let envelope = try? JSONDecoder().decode(WatchWorkoutEnvelope.self, from: cached) {
      workout = envelope.workout
      if !applyCompletedLog(envelope.completedLog, workout: envelope.workout) {
        applyActiveLog(envelope.activeLog)
      }
    }
    connectivity.observeWorkouts { [weak self] envelope in
      Task { @MainActor in
        self?.receive(envelope)
      }
    }
    connectivity.observeEndWorkout { [weak self] workoutId in
      Task { @MainActor in
        guard let self else { return }
        guard self.isActive else { return }
        if let workoutId, let current = self.workout?.id, workoutId != current { return }
        self.finish()
      }
    }
  }

  var currentExercise: WatchExercise? {
    guard let workout, workout.exercises.indices.contains(exerciseIndex) else {
      return nil
    }
    return workout.exercises[exerciseIndex]
  }

  var isActive: Bool {
    startedAt != nil
  }

  var isExerciseRunning: Bool {
    activeExerciseStartedAt != nil
  }

  var hasRemainingExercises: Bool {
    guard let workout else { return false }
    return exerciseIndex < workout.exercises.count
  }

  func receive(_ envelope: WatchWorkoutEnvelope) {
    let previousSummaryWorkoutId = isWorkoutCompleted ? workout?.id : nil
    if workout?.id != envelope.workout.id {
      summary = nil
      showSummaryOverlay = false
      exerciseIndex = 0
    }
    workout = envelope.workout
    if let data = try? JSONEncoder().encode(envelope) {
      UserDefaults.standard.set(data, forKey: "cachedWatchWorkout")
    }
    if applyCompletedLog(envelope.completedLog, workout: envelope.workout) {
      completedPendingSync = false
      // Only auto-open the summary if this is a *new* completion (different
      // workout, or no summary previously). Phone-triggered re-syncs of the
      // same completed workout shouldn't pop the user back into Summary.
      if previousSummaryWorkoutId != envelope.workout.id {
        showSummaryOverlay = true
      }
      return
    }
    applyActiveLog(envelope.activeLog)
    completedPendingSync = false
  }

  func dismissSummaryOverlay() {
    showSummaryOverlay = false
  }

  func openSummaryOverlay() {
    guard summary != nil else { return }
    showSummaryOverlay = true
  }

  func start() {
    startNextExercise()
  }

  func pause() {
    guard isExerciseRunning, !isPaused else { return }
    isPaused = true
    pausedAt = Date()
    workoutManager.pause()
  }

  func resume() {
    guard isExerciseRunning, isPaused else { return }
    if let pausedAt {
      pausedSeconds += max(0, Int(Date().timeIntervalSince(pausedAt)))
    }
    self.pausedAt = nil
    isPaused = false
    workoutManager.resume()
  }

  func startNextExercise() {
    guard let workout, hasRemainingExercises, !isExerciseRunning else { return }
    summary = nil
    showSummaryOverlay = false
    completedPendingSync = false
    let now = Date()
    activeExerciseStartedAt = now
    isPaused = false

    if startedAt != nil {
      // HK session is already running from the first exercise. Defensively
      // resume it in case a prior pause/stop sequence left it paused — an
      // HKWorkoutSession that stays paused stops counting toward both the
      // Apple Fitness duration and active energy.
      workoutManager.resume()
      return
    }
    pausedAt = nil
    startedAt = now
    sets = []
    timings = []
    pausedSeconds = 0
    let workoutId = workout.id
    Task {
      await workoutManager.start(at: now)
      await MainActor.run {
        connectivity.notifySessionActive(workoutId: workoutId)
      }
    }
  }

  func stopCurrentExercise() {
    guard isExerciseRunning else { return }
    // If the exercise was paused, make sure the underlying HK session is
    // resumed before we record the timing — otherwise the session stays
    // paused across the rest period and the next exercise won't accrue
    // duration or calories in Apple Fitness.
    if isPaused {
      if let pausedAt {
        pausedSeconds += max(0, Int(Date().timeIntervalSince(pausedAt)))
      }
      pausedAt = nil
      isPaused = false
      workoutManager.resume()
    }
    finishCurrentExercise()
    if hasRemainingExercises {
      exerciseIndex += 1
    }
    if !hasRemainingExercises {
      finish()
    }
  }

  func finish() {
    guard let workout, let startedAt else { return }
    if let pausedAt {
      pausedSeconds += max(0, Int(Date().timeIntervalSince(pausedAt)))
      self.pausedAt = nil
    }
    if isPaused {
      // Resume before ending so HK closes the workout cleanly rather than
      // capturing the duration up to the last pause.
      isPaused = false
      workoutManager.resume()
    }
    if isExerciseRunning {
      finishCurrentExercise()
      if hasRemainingExercises {
        exerciseIndex += 1
      }
    }

    let completedAt = Date()
    Task {
      await workoutManager.finish(at: completedAt)
      let completion = WatchCompletionPayload(
        schemaVersion: 1,
        completionId: UUID().uuidString,
        workoutId: workout.id,
        title: workout.title,
        startedAt: iso(startedAt),
        completedAt: iso(completedAt),
        pausedSeconds: pausedSeconds,
        sets: sets,
        exerciseTimings: timings,
        healthMetrics: workoutManager.metrics,
        healthWriteStatus: workoutManager.healthStatus
      )
      let summary = WatchWorkoutSummary(
        title: workout.title,
        totalTime: completedAt.timeIntervalSince(startedAt),
        averageHeartRate: workoutManager.metrics?.heartRateBpm,
        totalCalories: workoutManager.metrics?.activeEnergyKcal,
        completedAt: completedAt
      )
      connectivity.sendCompletion(completion)
      connectivity.notifySessionEnded(workoutId: workout.id)
      completedPendingSync = true
      resetSession(summary: summary)
      // Auto-open the Summary overlay so the user sees their stats immediately
      // after finishing. They can dismiss to fall back to the Done card.
      showSummaryOverlay = true
    }
  }

  func cancel() {
    let workoutId = workout?.id
    workoutManager.discard()
    if let workoutId { connectivity.notifySessionEnded(workoutId: workoutId) }
    resetSession(summary: nil)
    showSummaryOverlay = false
  }

  private func finishCurrentExercise() {
    guard let exercise = currentExercise, let activeExerciseStartedAt else { return }
    let completed = Date()
    timings.append(
      WatchExerciseTiming(
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.name,
        startedAt: iso(activeExerciseStartedAt),
        completedAt: iso(completed),
        pausedSeconds: 0
      )
    )
    self.activeExerciseStartedAt = nil
    isPaused = false
    pausedAt = nil
    WKInterfaceDevice.current().play(.success)
  }

  private func resetSession(summary: WatchWorkoutSummary?) {
    startedAt = nil
    activeExerciseStartedAt = nil
    isPaused = false
    pausedAt = nil
    pausedSeconds = 0
    self.summary = summary
  }

  private func applyActiveLog(_ activeLog: WatchActiveLog?) {
    guard let activeLog else { return }
    startedAt = parseDate(activeLog.startedAt)
    pausedSeconds = activeLog.pausedSeconds ?? 0
    isPaused = activeLog.pausedAt != nil
    pausedAt = parseDate(activeLog.pausedAt)
  }

  private func applyCompletedLog(_ completedLog: WatchCompletedLog?, workout: WatchPlannedWorkout) -> Bool {
    guard let completedLog,
          completedLog.workoutId == workout.id,
          let completedAtValue = completedLog.completedAt,
          let completedAt = parseDate(completedAtValue) else {
      return false
    }

    let started = parseDate(completedLog.startedAt)
    let duration = completedLog.totalDurationSeconds.map(TimeInterval.init)
      ?? started.map { completedAt.timeIntervalSince($0) }
      ?? 0
    exerciseIndex = workout.exercises.count
    sets = []
    timings = []
    startedAt = nil
    activeExerciseStartedAt = nil
    isPaused = false
    pausedAt = nil
    pausedSeconds = completedLog.pausedSeconds ?? 0
    summary = WatchWorkoutSummary(
      title: completedLog.title,
      totalTime: duration,
      averageHeartRate: completedLog.healthMetrics?.heartRateBpm,
      totalCalories: completedLog.healthMetrics?.activeEnergyKcal,
      completedAt: completedAt
    )
    return true
  }

  private func iso(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
  }

  private func parseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    if let date = Self.fractionalIsoFormatter.date(from: value) {
      return date
    }
    if let date = Self.isoFormatter.date(from: value) {
      return date
    }
    if let date = Self.localFractionalIsoFormatter.date(from: value) {
      return date
    }
    return Self.localIsoFormatter.date(from: value)
  }

  private static let fractionalIsoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let isoFormatter = ISO8601DateFormatter()

  private static let localFractionalIsoFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    return formatter
  }()

  private static let localIsoFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return formatter
  }()
}
