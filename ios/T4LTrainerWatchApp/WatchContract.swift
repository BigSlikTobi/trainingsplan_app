import Foundation
import WatchKit

// MARK: - WatchConnectivity wire contract
//
// Single source of truth for the watch side of the app<->watch
// WatchConnectivity protocol. The iOS companion
// (`ios/Runner/WatchSyncCoordinator.swift`) and the Flutter event handler
// (`lib/src/state/fitness_controller.dart`) mirror these exact string values.
//
// ⚠️ Changing any raw value here breaks the contract with the phone. Keep them
// byte-identical across both sides.

enum WatchMessageKey {
  /// Phone → watch: the current planned workout envelope.
  static let currentWorkout = "currentWorkout"
  /// Watch → phone: incremental in-workout progress snapshot.
  static let workoutProgress = "watchWorkoutProgress"
  /// Watch → phone: a finished workout payload.
  static let workoutCompleted = "watchWorkoutCompleted"
  /// Watch → phone: a workout session became active on the watch.
  static let sessionActive = "watchSessionActive"
  /// Watch → phone: the watch workout session ended.
  static let sessionEnded = "watchSessionEnded"
  /// Phone → watch: request to end the active workout (optional workoutId).
  static let endWorkout = "endWorkout"
  /// Phone → watch: acknowledge a completion so the watch stops retrying.
  static let completionHandled = "completionHandled"
}

enum WatchStorageKey {
  /// Cached copy of the last workout envelope, so the watch renders instantly
  /// on launch before connectivity wakes up.
  static let cachedWorkout = "cachedWatchWorkout"
  /// Queue of completion payloads awaiting phone acknowledgement.
  static let pendingCompletions = "pendingWatchWorkoutCompletions"
}

// MARK: - Health authorization / collection state
//
// Raw values are sent to the phone in `healthWriteStatus` and must remain
// stable — the Flutter layer stores them verbatim.

enum HealthAuthState: String {
  /// HealthKit is unavailable on this device, or a session could not start.
  case unavailable = "watch_health_unavailable"
  /// Authorized and actively collecting heart rate / energy.
  case collecting = "watch_health_synced"
  /// The user declined the Health permissions a workout session requires.
  case denied = "watch_health_denied"
}

// MARK: - ISO-8601 clock
//
// One set of reusable formatters. `ISO8601DateFormatter` is comparatively
// expensive to allocate, and the previous implementation built a fresh one on
// every encode — wasteful inside a per-second progress loop.

enum WatchClock {
  /// Serializes a date for the wire. Matches the legacy whole-second,
  /// `Z`-suffixed format the phone already parses.
  static func string(from date: Date) -> String {
    plainFormatter.string(from: date)
  }

  /// Parses the several ISO-8601 variants the phone may emit (fractional or
  /// whole seconds, UTC `Z` or local).
  static func date(from value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    if let date = fractionalFormatter.date(from: value) { return date }
    if let date = plainFormatter.date(from: value) { return date }
    if let date = localFractionalFormatter.date(from: value) { return date }
    return localFormatter.date(from: value)
  }

  private static let plainFormatter = ISO8601DateFormatter()

  private static let fractionalFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let localFractionalFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    return formatter
  }()

  private static let localFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return formatter
  }()
}

// MARK: - Haptics
//
// Semantic wrapper over WatchKit haptics so call sites read by intent rather
// than by raw `WKHapticType`.

enum WatchHaptics {
  static func exerciseStart() { play(.start) }
  static func exerciseComplete() { play(.success) }
  static func restEnding() { play(.notification) }
  static func workoutComplete() { play(.success) }
  static func tap() { play(.click) }

  private static func play(_ type: WKHapticType) {
    WKInterfaceDevice.current().play(type)
  }
}
