import Foundation
import HealthKit
import Observation

/// Owns the `HKWorkoutSession` that keeps the watch app alive for the entire
/// workout and streams live heart-rate / active-energy data.
///
/// Design notes:
/// - **One session per workout.** A single session spans every exercise and
///   rest period, so watchOS keeps the app frontmost and running in the
///   background for the whole training instead of suspending it between sets.
/// - **The keep-alive is never gated on read authorization.** The session is
///   started whenever HealthKit data is available; denied heart-rate access
///   degrades the metrics, not the always-on behaviour. (The previous version
///   bailed out of starting a session unless authorization had fully
///   succeeded, which is why the app kept suspending mid-workout.)
/// - **Authorization is requested up front** (app launch / workout load) so
///   tapping Start begins the session immediately instead of interrupting the
///   athlete with a permission sheet.
/// - **Thread-safe metrics.** Builder callbacks arrive on a background queue;
///   values are computed there and published on the main actor, so no mutable
///   state is shared across threads.
@MainActor
@Observable
final class WatchWorkoutManager: NSObject {
  private(set) var authState: HealthAuthState = .unavailable
  private(set) var isRunning = false
  private(set) var metrics: WatchHealthMetrics?
  private(set) var currentHeartRateBpm: Double?
  private(set) var activeEnergyKcal: Double?

  /// Legacy status string sent to the phone in progress / completion payloads.
  var healthStatus: String { authState.rawValue }
  var hasSession: Bool { session != nil }

  @ObservationIgnored private let healthStore = HKHealthStore()
  @ObservationIgnored private var session: HKWorkoutSession?
  @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
  @ObservationIgnored private var workoutStartedAt: Date?
  @ObservationIgnored private var latestHeartRate: Double?
  @ObservationIgnored private var averageHeartRate: Double?
  @ObservationIgnored private var latestEnergy: Double?
  @ObservationIgnored private var sampleCount = 0
  @ObservationIgnored private var canWriteActiveEnergy = false

  override init() {
    super.init()
  }

  // MARK: - Authorization

  /// Requests HealthKit authorization. Safe to call repeatedly and early
  /// (e.g. at launch) so the permission sheet never interrupts Start.
  @discardableResult
  func requestAuthorization() async -> HealthAuthState {
    guard HKHealthStore.isHealthDataAvailable() else {
      authState = .unavailable
      return authState
    }

    let workoutType = HKObjectType.workoutType()
    let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate)
    let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
    let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass)
    let share = Set([workoutType, heartRate, activeEnergy].compactMap { $0 })
    let read = Set([workoutType, heartRate, activeEnergy, bodyMass].compactMap { $0 })

    do {
      try await healthStore.requestAuthorization(toShare: share, read: read)
      canWriteActiveEnergy = activeEnergy.map {
        healthStore.authorizationStatus(for: $0) == .sharingAuthorized
      } ?? false
      // requestAuthorization() does not throw on denial; the workout share
      // status is what actually decides whether a session can start.
      authState = healthStore.authorizationStatus(for: workoutType) == .sharingDenied
        ? .denied : .collecting
    } catch {
      authState = .denied
    }
    return authState
  }

  // MARK: - Session lifecycle

  func start(at date: Date) async {
    guard HKHealthStore.isHealthDataAvailable() else {
      authState = .unavailable
      return
    }
    if session != nil {
      resume()
      return
    }
    if authState == .unavailable {
      await requestAuthorization()
    }

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .functionalStrengthTraining
    configuration.locationType = .indoor

    do {
      let session = try HKWorkoutSession(
        healthStore: healthStore, configuration: configuration)
      let builder = session.associatedWorkoutBuilder()
      builder.dataSource = HKLiveWorkoutDataSource(
        healthStore: healthStore, workoutConfiguration: configuration)
      session.delegate = self
      builder.delegate = self
      self.session = session
      self.builder = builder
      workoutStartedAt = date
      resetMetrics()
      session.startActivity(with: date)
      try await builder.beginCollection(at: date)
      isRunning = true
      if authState != .denied { authState = .collecting }
    } catch {
      // The most common failure is the user having denied workout sharing,
      // which HealthKit requires to run a session. Surface it so the UI can
      // prompt — but never silently disable the rest of the workout flow.
      authState = .denied
      isRunning = false
      session = nil
      builder = nil
    }
  }

  func pause() { session?.pause() }
  func resume() { session?.resume() }

  func finish(at date: Date) async {
    guard let liveBuilder = builder else {
      isRunning = false
      return
    }
    do {
      try await addFallbackActiveEnergyIfNeeded(endedAt: date)
      session?.end()
      try await liveBuilder.endCollection(at: date)
      _ = try await liveBuilder.finishWorkout()
      refreshMetrics()
    } catch {
      // The workout still happened; keep the last-known metrics and auth state
      // rather than clobbering the completion payload's status to unavailable.
    }
    isRunning = false
    session = nil
    builder = nil
    workoutStartedAt = nil
  }

  func discard() {
    session?.end()
    session = nil
    builder = nil
    workoutStartedAt = nil
    isRunning = false
  }

  // MARK: - Metrics

  private func resetMetrics() {
    latestHeartRate = nil
    averageHeartRate = nil
    latestEnergy = nil
    sampleCount = 0
    currentHeartRateBpm = nil
    activeEnergyKcal = nil
    metrics = nil
  }

  private func refreshMetrics() {
    metrics = WatchHealthMetrics(
      updatedAt: WatchClock.string(from: Date()),
      sampleCount: sampleCount,
      heartRateBpm: averageHeartRate ?? latestHeartRate,
      activeEnergyKcal: latestEnergy
    )
    currentHeartRateBpm = latestHeartRate
    activeEnergyKcal = latestEnergy
  }

  // MARK: - Estimated-energy fallback
  //
  // When the device never reported active energy (e.g. read access denied),
  // write a single MET-based estimate so the completion still carries a
  // plausible calorie figure.

  private func addFallbackActiveEnergyIfNeeded(endedAt: Date) async throws {
    guard canWriteActiveEnergy,
          let builder,
          let startedAt = workoutStartedAt,
          latestEnergy == nil || latestEnergy == 0,
          let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
    else { return }

    let duration = max(60, endedAt.timeIntervalSince(startedAt))
    let bodyMassKg = await latestBodyMassKg() ?? 75
    let estimatedKcal = estimateFunctionalStrengthCalories(
      duration: duration, bodyMassKg: bodyMassKg)
    guard estimatedKcal > 0 else { return }

    let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedKcal)
    let sample = HKQuantitySample(
      type: activeEnergyType, quantity: quantity, start: startedAt, end: endedAt)
    try await addSamples([sample], to: builder)
    latestEnergy = estimatedKcal
    sampleCount += 1
    activeEnergyKcal = estimatedKcal
  }

  private func latestBodyMassKg() async -> Double? {
    guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
      return nil
    }
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    return await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: bodyMassType, predicate: nil, limit: 1, sortDescriptors: [sort]
      ) { _, samples, _ in
        let value = (samples?.first as? HKQuantitySample)?
          .quantity.doubleValue(for: .gramUnit(with: .kilo))
        continuation.resume(returning: value)
      }
      healthStore.execute(query)
    }
  }

  private func estimateFunctionalStrengthCalories(
    duration: TimeInterval, bodyMassKg: Double
  ) -> Double {
    let functionalStrengthMet = 3.5
    let minutes = duration / 60
    return (functionalStrengthMet * 3.5 * bodyMassKg / 200) * minutes
  }

  private func addSamples(
    _ samples: [HKSample], to builder: HKLiveWorkoutBuilder
  ) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      builder.add(samples) { success, error in
        if let error {
          continuation.resume(throwing: error)
        } else if success {
          continuation.resume()
        } else {
          continuation.resume(throwing: CocoaError(.featureUnsupported))
        }
      }
    }
  }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState,
    date: Date
  ) {
    Task { @MainActor in
      self.isRunning = (toState == .running)
    }
  }

  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession, didFailWithError error: Error
  ) {
    Task { @MainActor in
      self.authState = .unavailable
      self.isRunning = false
    }
  }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
  nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

  nonisolated func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder,
    didCollectDataOf collectedTypes: Set<HKSampleType>
  ) {
    // Compute on the delegate's queue, then publish atomically on the main
    // actor — no mutable state is shared across threads.
    var newLatestHeartRate: Double?
    var newAverageHeartRate: Double?
    var newEnergy: Double?
    var didCollect = false

    for type in collectedTypes {
      guard let quantityType = type as? HKQuantityType else { continue }
      let statistics = workoutBuilder.statistics(for: quantityType)
      switch quantityType.identifier {
      case HKQuantityTypeIdentifier.heartRate.rawValue:
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        newLatestHeartRate = statistics?.mostRecentQuantity()?.doubleValue(for: bpmUnit)
        newAverageHeartRate = statistics?.averageQuantity()?.doubleValue(for: bpmUnit)
        didCollect = true
      case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
        newEnergy = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie())
        didCollect = true
      default:
        break
      }
    }
    guard didCollect else { return }

    Task { @MainActor in
      if let newLatestHeartRate { self.latestHeartRate = newLatestHeartRate }
      if let newAverageHeartRate { self.averageHeartRate = newAverageHeartRate }
      if let newEnergy { self.latestEnergy = newEnergy }
      self.sampleCount += 1
      self.refreshMetrics()
    }
  }
}
