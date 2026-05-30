import Foundation
import Observation
import WatchKit

/// Coarse UI phase derived from the store's state, used to drive the watch
/// surface and animate transitions between screens.
enum WatchPhase {
  case idle, ready, countdown, active, resting, completed
}

/// View-model for the watch workout experience. Owns the connectivity link and
/// the HealthKit session manager, and drives the phased UI:
///
///   ready → active (exercise) → resting → active → … → completed
///
/// A single workout session is kept alive across every exercise *and* every
/// rest period, so the app never suspends mid-workout and the athlete never
/// has to reopen it.
@MainActor
@Observable
final class WatchWorkoutStore {
  // Source-of-truth state for the sync payloads.
  private(set) var workout: WatchPlannedWorkout?
  private(set) var startedAt: Date?
  private(set) var activeExerciseStartedAt: Date?
  private(set) var isPaused = false
  private(set) var completedPendingSync = false
  private(set) var summary: WatchWorkoutSummary?
  private(set) var exerciseIndex = 0

  // Rest period — watch-only UI state, not part of the wire contract.
  private(set) var restStartedAt: Date?
  private(set) var restEndsAt: Date?

  // Pre-exercise 3-2-1 countdown — watch-only UI state.
  private(set) var countdownEndsAt: Date?

  /// Drives whether the summary screen is shown. Cleared when the user
  /// dismisses it or a new workout / exercise begins.
  var showSummaryOverlay = false

  let connectivity = WatchConnectivityManager()
  let workoutManager = WatchWorkoutManager()

  @ObservationIgnored private var sets: [WatchLoggedSet] = []
  @ObservationIgnored private var timings: [WatchExerciseTiming] = []
  @ObservationIgnored private var pausedAt: Date?
  @ObservationIgnored private var pausedSeconds = 0
  @ObservationIgnored private var activeExercisePausedSeconds = 0
  @ObservationIgnored private var progressRevision = 0
  @ObservationIgnored private var restTask: Task<Void, Never>?
  @ObservationIgnored private var countdownTask: Task<Void, Never>?
  /// True only when this watch *started* the live HK session (vs. mirroring a
  /// phone-driven session). While true the watch is the session owner and
  /// ignores inbound active-log echoes for the same workout.
  @ObservationIgnored private var startedOnWatch = false

  // MARK: - Derived state

  var isWorkoutCompleted: Bool { summary != nil }
  var isActive: Bool { startedAt != nil }
  var isExerciseRunning: Bool { activeExerciseStartedAt != nil }
  var isResting: Bool { restEndsAt != nil }

  var currentExercise: WatchExercise? {
    guard let workout, workout.exercises.indices.contains(exerciseIndex) else { return nil }
    return workout.exercises[exerciseIndex]
  }

  var hasRemainingExercises: Bool {
    guard let workout else { return false }
    return exerciseIndex < workout.exercises.count
  }

  var isCountingDown: Bool { countdownEndsAt != nil }

  /// Exercises after the current one, for the "Up Next" page.
  var upcomingExercises: [WatchExercise] {
    guard let workout else { return [] }
    let next = exerciseIndex + 1
    guard next < workout.exercises.count else { return [] }
    return Array(workout.exercises[next...])
  }

  /// True when the current exercise is the final one in the workout.
  var isOnLastExercise: Bool {
    guard let workout, !workout.exercises.isEmpty else { return false }
    return exerciseIndex >= workout.exercises.count - 1
  }

  /// Coarse phase for the UI layer to branch and animate on.
  var phase: WatchPhase {
    if isCountingDown { return .countdown }
    if isExerciseRunning { return .active }
    if isResting { return .resting }
    if showSummaryOverlay, summary != nil { return .completed }
    if workout != nil { return .ready }
    return .idle
  }

  // MARK: - Init

  init() {
    if let cached = UserDefaults.standard.data(forKey: WatchStorageKey.cachedWorkout),
       let envelope = try? JSONDecoder().decode(WatchWorkoutEnvelope.self, from: cached) {
      workout = envelope.workout
      if !applyCompletedLog(envelope.completedLog, workout: envelope.workout) {
        applyActiveLog(envelope.activeLog)
      }
    }

    connectivity.observeWorkouts { [weak self] envelope in
      Task { @MainActor in self?.receive(envelope) }
    }
    connectivity.observeEndWorkout { [weak self] workoutId in
      Task { @MainActor in
        guard let self, self.isActive else { return }
        if let workoutId, let current = self.workout?.id, workoutId != current { return }
        self.finish()
      }
    }

    // Resolve Health permissions up front so tapping Start begins the
    // keep-alive session instantly instead of popping a sheet mid-workout.
    Task { await workoutManager.requestAuthorization() }
  }

  // MARK: - Inbound workout

  func receive(_ envelope: WatchWorkoutEnvelope) {
    let isSameWorkout = (workout?.id == envelope.workout.id)
    // Ownership guard: while this watch is running the session it started, an
    // inbound active/completed log for the same workout is just the phone
    // echoing our own progress back. Keep our live state authoritative so the
    // echo can't reset the timer or exercise index. (Mirror of the phone's
    // revision dedup for watch→phone progress.) A different workout — or any
    // update while we are only mirroring a phone session — is still applied.
    let watchOwnsLiveSession = isSameWorkout && startedOnWatch

    let previousSummaryWorkoutId = isWorkoutCompleted ? workout?.id : nil
    if !isSameWorkout {
      summary = nil
      showSummaryOverlay = false
      exerciseIndex = 0
      startedOnWatch = false
      clearCountdown()
      clearRest()
    }
    workout = envelope.workout
    if let data = try? JSONEncoder().encode(envelope) {
      UserDefaults.standard.set(data, forKey: WatchStorageKey.cachedWorkout)
    }

    // Plan content is refreshed above; ignore echoed live state while we own
    // the session.
    guard !watchOwnsLiveSession else { return }

    if applyCompletedLog(envelope.completedLog, workout: envelope.workout) {
      completedPendingSync = false
      // Only auto-open the summary for a *new* completion; a phone re-sync of
      // the same completed workout shouldn't pop the user back into Summary.
      if previousSummaryWorkoutId != envelope.workout.id {
        showSummaryOverlay = true
      }
      return
    }
    applyActiveLog(envelope.activeLog)
    completedPendingSync = false
  }

  // MARK: - Summary overlay

  func dismissSummaryOverlay() { showSummaryOverlay = false }

  func openSummaryOverlay() {
    guard summary != nil else { return }
    showSummaryOverlay = true
  }

  // MARK: - Workout control

  func start() { beginExercise() }

  /// Start button entry point: runs a 3-2-1 countdown, then begins the next
  /// exercise. The session / keep-alive logic in `startNextExercise` is
  /// unchanged — this only adds a pre-roll with tick haptics.
  func beginExercise() {
    guard workout != nil, hasRemainingExercises, !isExerciseRunning, !isCountingDown
    else { return }
    clearRest()
    countdownEndsAt = Date().addingTimeInterval(3)
    WatchHaptics.tap()
    countdownTask?.cancel()
    countdownTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard let self, !Task.isCancelled, self.isCountingDown else { return }
      WatchHaptics.tap()
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled, self.isCountingDown else { return }
      WatchHaptics.tap()
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled, self.isCountingDown else { return }
      self.countdownEndsAt = nil
      self.countdownTask = nil
      self.startNextExercise()
    }
  }

  /// Skips the remaining countdown and starts immediately (tap-to-start).
  func skipCountdown() {
    guard isCountingDown else { return }
    clearCountdown()
    startNextExercise()
  }

  private func clearCountdown() {
    countdownTask?.cancel()
    countdownTask = nil
    countdownEndsAt = nil
  }

  func pause() {
    guard isExerciseRunning, !isPaused else { return }
    isPaused = true
    pausedAt = Date()
    workoutManager.pause()
    sendProgress()
  }

  func resume() {
    guard isExerciseRunning, isPaused else { return }
    if let pausedAt {
      let added = max(0, Int(Date().timeIntervalSince(pausedAt)))
      pausedSeconds += added
      activeExercisePausedSeconds += added
    }
    pausedAt = nil
    isPaused = false
    workoutManager.resume()
    sendProgress()
  }

  func startNextExercise() {
    guard let workout, hasRemainingExercises, !isExerciseRunning else { return }
    clearCountdown()
    clearRest()
    summary = nil
    showSummaryOverlay = false
    completedPendingSync = false
    let now = Date()
    activeExerciseStartedAt = now
    activeExercisePausedSeconds = 0
    isPaused = false
    WatchHaptics.exerciseStart()

    if startedAt != nil {
      // The session is already running from the first exercise. Defensively
      // resume it in case a prior pause/stop left it paused — a paused
      // HKWorkoutSession stops counting toward Apple Fitness duration/energy.
      workoutManager.resume()
      sendProgress()
      return
    }
    pausedAt = nil
    startedAt = now
    startedOnWatch = true
    sets = []
    timings = []
    pausedSeconds = 0
    let workoutId = workout.id
    Task {
      await workoutManager.start(at: now)
      connectivity.notifySessionActive(workoutId: workoutId)
      sendProgress()
    }
  }

  func stopCurrentExercise() {
    guard isExerciseRunning else { return }
    // If paused, resume the HK session before recording the timing so it does
    // not stay paused across the rest period and stall the next exercise's
    // duration / energy accrual.
    if isPaused {
      if let pausedAt {
        let added = max(0, Int(Date().timeIntervalSince(pausedAt)))
        pausedSeconds += added
        activeExercisePausedSeconds += added
      }
      pausedAt = nil
      isPaused = false
      workoutManager.resume()
    }

    let restSeconds = currentExercise?.restSeconds ?? 0
    finishCurrentExercise()
    if hasRemainingExercises {
      exerciseIndex += 1
    }
    if !hasRemainingExercises {
      finish()
    } else {
      beginRest(seconds: restSeconds)
      sendProgress()
    }
  }

  func finish() {
    clearCountdown()
    guard let workout, let startedAt else { return }
    clearRest()
    if let pausedAt {
      pausedSeconds += max(0, Int(Date().timeIntervalSince(pausedAt)))
      self.pausedAt = nil
    }
    if isPaused {
      // Resume before ending so HK closes the workout at the true end rather
      // than at the last pause.
      isPaused = false
      workoutManager.resume()
    }
    if isExerciseRunning {
      finishCurrentExercise()
      if hasRemainingExercises { exerciseIndex += 1 }
    }

    let completedAt = Date()
    Task {
      await workoutManager.finish(at: completedAt)
      let completion = WatchCompletionPayload(
        schemaVersion: 1,
        completionId: UUID().uuidString,
        workoutId: workout.id,
        title: workout.title,
        startedAt: WatchClock.string(from: startedAt),
        completedAt: WatchClock.string(from: completedAt),
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
      WatchHaptics.workoutComplete()
      // Auto-open Summary so stats are visible immediately; dismiss falls back
      // to the Done card.
      showSummaryOverlay = true
    }
  }

  func cancel() {
    let workoutId = workout?.id
    clearCountdown()
    clearRest()
    workoutManager.discard()
    if let workoutId { connectivity.notifySessionEnded(workoutId: workoutId) }
    resetSession(summary: nil)
    showSummaryOverlay = false
  }

  // MARK: - Rest period

  /// Skips the remaining rest and returns to the ready card for the next set.
  func skipRest() {
    guard isResting else { return }
    WatchHaptics.tap()
    completeRest(playHaptic: false)
  }

  private func beginRest(seconds: Int) {
    guard seconds > 0 else { return }
    let now = Date()
    restStartedAt = now
    let end = now.addingTimeInterval(TimeInterval(seconds))
    restEndsAt = end
    scheduleRestCompletion(at: end)
  }

  /// Adjusts the running rest timer (Digital Crown, ±15 s detents).
  func addRestSeconds(_ delta: Int) {
    guard isResting, let end = restEndsAt else { return }
    let newEnd = max(Date().addingTimeInterval(1), end.addingTimeInterval(TimeInterval(delta)))
    restEndsAt = newEnd
    scheduleRestCompletion(at: newEnd)
  }

  private func scheduleRestCompletion(at end: Date) {
    restTask?.cancel()
    let remaining = max(0, end.timeIntervalSinceNow)
    restTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(remaining))
      guard let self, !Task.isCancelled else { return }
      self.completeRest(playHaptic: true)
    }
  }

  private func completeRest(playHaptic: Bool) {
    guard isResting else { return }
    restTask?.cancel()
    restTask = nil
    restStartedAt = nil
    restEndsAt = nil
    if playHaptic { WatchHaptics.restEnding() }
  }

  private func clearRest() {
    restTask?.cancel()
    restTask = nil
    restStartedAt = nil
    restEndsAt = nil
  }

  // MARK: - Internals

  private func finishCurrentExercise() {
    guard let exercise = currentExercise, let activeExerciseStartedAt else { return }
    let completed = Date()
    timings.append(
      WatchExerciseTiming(
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.name,
        startedAt: WatchClock.string(from: activeExerciseStartedAt),
        completedAt: WatchClock.string(from: completed),
        pausedAt: nil,
        pausedSeconds: activeExercisePausedSeconds
      )
    )
    self.activeExerciseStartedAt = nil
    activeExercisePausedSeconds = 0
    isPaused = false
    pausedAt = nil
    WatchHaptics.exerciseComplete()
  }

  private func resetSession(summary: WatchWorkoutSummary?) {
    startedAt = nil
    activeExerciseStartedAt = nil
    isPaused = false
    pausedAt = nil
    pausedSeconds = 0
    activeExercisePausedSeconds = 0
    startedOnWatch = false
    clearCountdown()
    clearRest()
    self.summary = summary
  }

  private func applyActiveLog(_ activeLog: WatchActiveLog?) {
    guard let activeLog else { return }
    startedAt = WatchClock.date(from: activeLog.startedAt)
    pausedSeconds = activeLog.pausedSeconds ?? 0
    if let incomingSets = activeLog.sets {
      sets = incomingSets
    }
    if let incomingTimings = activeLog.exerciseTimings {
      timings = incomingTimings.filter { $0.completedAt != nil }
      applyExerciseProgress(incomingTimings, workout: workout)
    } else {
      isPaused = activeLog.pausedAt != nil
      pausedAt = WatchClock.date(from: activeLog.pausedAt)
    }
  }

  private func applyExerciseProgress(
    _ exerciseTimings: [WatchExerciseTiming], workout: WatchPlannedWorkout?
  ) {
    guard let workout else { return }
    if let running = exerciseTimings.first(where: { $0.completedAt == nil }) {
      if let index = workout.exercises.firstIndex(where: { $0.exerciseId == running.exerciseId }) {
        exerciseIndex = index
      }
      activeExerciseStartedAt = WatchClock.date(from: running.startedAt)
      activeExercisePausedSeconds = running.pausedSeconds
      isPaused = running.pausedAt != nil
      pausedAt = WatchClock.date(from: running.pausedAt)
      return
    }

    activeExerciseStartedAt = nil
    activeExercisePausedSeconds = 0
    isPaused = false
    pausedAt = nil
    let stoppedIds = Set(exerciseTimings.compactMap { $0.completedAt == nil ? nil : $0.exerciseId })
    exerciseIndex = min(stoppedIds.count, workout.exercises.count)
  }

  private func applyCompletedLog(
    _ completedLog: WatchCompletedLog?, workout: WatchPlannedWorkout
  ) -> Bool {
    guard let completedLog,
          completedLog.workoutId == workout.id,
          let completedAtValue = completedLog.completedAt,
          let completedAt = WatchClock.date(from: completedAtValue) else {
      return false
    }

    let started = WatchClock.date(from: completedLog.startedAt)
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

  // MARK: - Progress sync

  private func sendProgress() {
    guard let payload = progressPayload() else { return }
    connectivity.sendProgress(payload)
  }

  private func progressPayload() -> WatchProgressPayload? {
    guard let workout, let startedAt else { return nil }
    progressRevision += 1
    var progressTimings = timings
    if let exercise = currentExercise, let activeExerciseStartedAt {
      progressTimings.append(
        WatchExerciseTiming(
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.name,
          startedAt: WatchClock.string(from: activeExerciseStartedAt),
          completedAt: nil,
          pausedAt: pausedAt.map { WatchClock.string(from: $0) },
          pausedSeconds: activeExercisePausedSeconds
        )
      )
    }
    return WatchProgressPayload(
      schemaVersion: 1,
      revision: progressRevision,
      sentAt: WatchClock.string(from: Date()),
      workoutId: workout.id,
      title: workout.title,
      startedAt: WatchClock.string(from: startedAt),
      pausedAt: pausedAt.map { WatchClock.string(from: $0) },
      pausedSeconds: pausedSeconds,
      activeExerciseId: currentExercise?.exerciseId,
      exerciseIndex: exerciseIndex,
      sets: sets,
      exerciseTimings: progressTimings,
      healthMetrics: workoutManager.metrics,
      healthWriteStatus: workoutManager.healthStatus
    )
  }
}
