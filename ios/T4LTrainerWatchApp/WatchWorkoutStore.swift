import Foundation
import SwiftUI
import WatchKit

@MainActor
final class WatchWorkoutStore: ObservableObject {
  @Published private(set) var workout: WatchPlannedWorkout?
  @Published private(set) var startedAt: Date?
  @Published private(set) var isPaused = false
  @Published private(set) var completedPendingSync = false
  @Published var exerciseIndex = 0
  @Published var currentSetNumber = 1
  @Published var reps = 8
  @Published var weightKg = 0.0
  @Published var rpe = 7.0
  @Published var restRemaining = 0

  let connectivity = WatchConnectivityManager()
  let workoutManager = WatchWorkoutManager()

  private var sets: [WatchLoggedSet] = []
  private var timings: [WatchExerciseTiming] = []
  private var exerciseStartedAt: Date?
  private var pausedAt: Date?
  private var pausedSeconds = 0
  private var restTask: Task<Void, Never>?

  init() {
    if let cached = UserDefaults.standard.data(forKey: "cachedWatchWorkout"),
       let envelope = try? JSONDecoder().decode(WatchWorkoutEnvelope.self, from: cached) {
      workout = envelope.workout
      applyActiveLog(envelope.activeLog)
    }
    connectivity.observeWorkouts { [weak self] envelope in
      Task { @MainActor in
        self?.receive(envelope)
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

  func receive(_ envelope: WatchWorkoutEnvelope) {
    workout = envelope.workout
    if let data = try? JSONEncoder().encode(envelope) {
      UserDefaults.standard.set(data, forKey: "cachedWatchWorkout")
    }
    applyActiveLog(envelope.activeLog)
    completedPendingSync = false
  }

  func start() {
    guard let workout, startedAt == nil else { return }
    startedAt = Date()
    exerciseIndex = 0
    currentSetNumber = 1
    sets = []
    timings = []
    exerciseStartedAt = Date()
    reps = defaultReps(for: workout.exercises.first)
    weightKg = 0
    rpe = workout.exercises.first?.targetRpe ?? 7
    Task { await workoutManager.start(at: startedAt ?? Date()) }
  }

  func pause() {
    guard !isPaused else { return }
    isPaused = true
    pausedAt = Date()
    workoutManager.pause()
  }

  func resume() {
    guard isPaused else { return }
    if let pausedAt {
      pausedSeconds += max(0, Int(Date().timeIntervalSince(pausedAt)))
    }
    self.pausedAt = nil
    isPaused = false
    workoutManager.resume()
  }

  func logCurrentSet() {
    guard let exercise = currentExercise else { return }
    if startedAt == nil { start() }
    sets.append(
      WatchLoggedSet(
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.name,
        setNumber: currentSetNumber,
        weightKg: weightKg,
        reps: reps,
        rpe: rpe
      )
    )

    if currentSetNumber >= exercise.sets {
      finishCurrentExercise()
      moveToNextExercise()
    } else {
      currentSetNumber += 1
      startRest(seconds: exercise.restSeconds)
    }
  }

  func skipExercise() {
    finishCurrentExercise()
    moveToNextExercise()
  }

  func finish() {
    guard let workout, let startedAt else { return }
    restTask?.cancel()
    if currentExercise != nil {
      finishCurrentExercise()
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
      connectivity.sendCompletion(completion)
      completedPendingSync = true
      resetSession()
    }
  }

  func cancel() {
    workoutManager.discard()
    resetSession()
  }

  private func moveToNextExercise() {
    guard let workout else { return }
    if exerciseIndex + 1 >= workout.exercises.count {
      finish()
      return
    }
    exerciseIndex += 1
    currentSetNumber = 1
    let exercise = workout.exercises[exerciseIndex]
    reps = defaultReps(for: exercise)
    weightKg = 0
    rpe = exercise.targetRpe
    exerciseStartedAt = Date()
    startRest(seconds: exercise.restSeconds)
  }

  private func finishCurrentExercise() {
    guard let exercise = currentExercise, let exerciseStartedAt else { return }
    let completed = Date()
    timings.append(
      WatchExerciseTiming(
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.name,
        startedAt: iso(exerciseStartedAt),
        completedAt: iso(completed),
        pausedSeconds: 0
      )
    )
    self.exerciseStartedAt = nil
  }

  private func startRest(seconds: Int) {
    restTask?.cancel()
    restRemaining = max(0, seconds)
    guard restRemaining > 0 else { return }
    restTask = Task {
      while !Task.isCancelled && restRemaining > 0 {
        try? await Task.sleep(for: .seconds(1))
        if !isPaused {
          restRemaining -= 1
        }
      }
      if !Task.isCancelled {
        WKInterfaceDevice.current().play(.notification)
      }
    }
  }

  private func resetSession() {
    startedAt = nil
    isPaused = false
    pausedAt = nil
    pausedSeconds = 0
    exerciseStartedAt = nil
    restRemaining = 0
    restTask?.cancel()
  }

  private func applyActiveLog(_ activeLog: WatchActiveLog?) {
    guard let activeLog else { return }
    startedAt = ISO8601DateFormatter().date(from: activeLog.startedAt)
    pausedSeconds = activeLog.pausedSeconds ?? 0
    isPaused = activeLog.pausedAt != nil
    pausedAt = activeLog.pausedAt.flatMap { ISO8601DateFormatter().date(from: $0) }
  }

  private func defaultReps(for exercise: WatchExercise?) -> Int {
    guard let reps = exercise?.reps else { return 8 }
    let digits = reps.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    return digits.first ?? 8
  }

  private func iso(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
  }
}
