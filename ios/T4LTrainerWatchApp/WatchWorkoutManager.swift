import Foundation
import HealthKit

final class WatchWorkoutManager: NSObject, ObservableObject {
  @Published private(set) var healthStatus = "watch_health_unavailable"
  @Published private(set) var metrics: WatchHealthMetrics?

  private let healthStore = HKHealthStore()
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private var workoutStartedAt: Date?
  private var latestHeartRate: Double?
  private var latestEnergy: Double?
  private var sampleCount = 0
  private var canWriteActiveEnergy = false

  func requestAuthorization() async -> Bool {
    guard HKHealthStore.isHealthDataAvailable() else {
      await MainActor.run { healthStatus = "watch_health_unavailable" }
      return false
    }

    let workoutType = HKObjectType.workoutType()
    let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)
    let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
    let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)
    let shareTypes = Set([
      workoutType,
      heartRateType,
      activeEnergyType,
    ].compactMap { $0 })
    let readTypes = Set([
      HKObjectType.workoutType(),
      HKQuantityType.quantityType(forIdentifier: .heartRate),
      HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
      bodyMassType,
    ].compactMap { $0 })

    do {
      try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
      let canWriteActiveEnergy = activeEnergyType.map {
        healthStore.authorizationStatus(for: $0) == .sharingAuthorized
      } ?? false
      await MainActor.run {
        self.canWriteActiveEnergy = canWriteActiveEnergy
        healthStatus = "watch_health_synced"
      }
      return true
    } catch {
      await MainActor.run { healthStatus = "watch_health_denied" }
      return false
    }
  }

  func start(at date: Date) async {
    _ = await requestAuthorization()
    guard healthStatus == "watch_health_synced" else { return }

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .functionalStrengthTraining
    configuration.locationType = .indoor

    do {
      let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
      let builder = session.associatedWorkoutBuilder()
      builder.dataSource = HKLiveWorkoutDataSource(
        healthStore: healthStore,
        workoutConfiguration: configuration
      )
      session.delegate = self
      builder.delegate = self
      self.session = session
      self.builder = builder
      workoutStartedAt = date
      latestHeartRate = nil
      latestEnergy = nil
      sampleCount = 0
      session.startActivity(with: date)
      try await builder.beginCollection(at: date)
    } catch {
      await MainActor.run { healthStatus = "watch_health_unavailable" }
    }
  }

  func pause() {
    session?.pause()
  }

  func resume() {
    session?.resume()
  }

  func finish(at date: Date) async {
    guard let builder else { return }
    do {
      try await addFallbackActiveEnergyIfNeeded(endedAt: date)
      session?.end()
      try await builder.endCollection(at: date)
      _ = try await builder.finishWorkout()
      await refreshMetrics()
    } catch {
      await MainActor.run { healthStatus = "watch_health_unavailable" }
    }
  }

  func discard() {
    session?.end()
    session = nil
    builder = nil
    workoutStartedAt = nil
  }

  private func refreshMetrics() async {
    let now = ISO8601DateFormatter().string(from: Date())
    let metrics = WatchHealthMetrics(
      updatedAt: now,
      sampleCount: sampleCount,
      heartRateBpm: latestHeartRate,
      activeEnergyKcal: latestEnergy
    )
    await MainActor.run {
      self.metrics = metrics
    }
  }

  private func addFallbackActiveEnergyIfNeeded(endedAt: Date) async throws {
    guard canWriteActiveEnergy,
          let builder,
          let startedAt = workoutStartedAt,
          latestEnergy == nil || latestEnergy == 0,
          let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
    else {
      return
    }

    let duration = max(60, endedAt.timeIntervalSince(startedAt))
    let bodyMassKg = await latestBodyMassKg() ?? 75
    let estimatedKcal = estimateFunctionalStrengthCalories(
      duration: duration,
      bodyMassKg: bodyMassKg
    )
    guard estimatedKcal > 0 else { return }

    let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedKcal)
    let sample = HKQuantitySample(
      type: activeEnergyType,
      quantity: quantity,
      start: startedAt,
      end: endedAt
    )
    try await addSamples([sample], to: builder)
    latestEnergy = estimatedKcal
    sampleCount += 1
  }

  private func latestBodyMassKg() async -> Double? {
    guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
      return nil
    }

    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    return await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: bodyMassType,
        predicate: nil,
        limit: 1,
        sortDescriptors: [sort]
      ) { _, samples, _ in
        let value = (samples?.first as? HKQuantitySample)?
          .quantity
          .doubleValue(for: .gramUnit(with: .kilo))
        continuation.resume(returning: value)
      }
      healthStore.execute(query)
    }
  }

  private func estimateFunctionalStrengthCalories(duration: TimeInterval, bodyMassKg: Double) -> Double {
    let functionalStrengthMet = 3.5
    let minutes = duration / 60
    return (functionalStrengthMet * 3.5 * bodyMassKg / 200) * minutes
  }

  private func addSamples(_ samples: [HKSample], to builder: HKLiveWorkoutBuilder) async throws {
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

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
  func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState,
    date: Date
  ) {}

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    DispatchQueue.main.async {
      self.healthStatus = "watch_health_unavailable"
    }
  }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
  func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

  func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder,
    didCollectDataOf collectedTypes: Set<HKSampleType>
  ) {
    for type in collectedTypes {
      guard let quantityType = type as? HKQuantityType else { continue }
      let statistics = workoutBuilder.statistics(for: quantityType)
      switch quantityType.identifier {
      case HKQuantityTypeIdentifier.heartRate.rawValue:
        latestHeartRate = statistics?
          .mostRecentQuantity()?
          .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        sampleCount += 1
      case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
        latestEnergy = statistics?
          .sumQuantity()?
          .doubleValue(for: .kilocalorie())
        sampleCount += 1
      default:
        break
      }
    }
    Task {
      await refreshMetrics()
    }
  }
}
