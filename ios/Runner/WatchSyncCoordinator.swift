import Flutter
import Foundation
import WatchConnectivity

final class WatchSyncCoordinator: NSObject {
  private let session: WCSession?
  private var eventSink: FlutterEventSink?
  private var pendingCompletions: [[String: Any]] = []
  private var activeWatchWorkoutId: String?

  override init() {
    if WCSession.isSupported() {
      session = WCSession.default
    } else {
      session = nil
    }
    super.init()
    session?.delegate = self
    session?.activate()
  }

  func syncWorkout(_ payload: [String: Any]) -> String {
    guard let session else {
      return "Apple Watch sync unavailable on this device"
    }

    let sanitized = Self.stripNulls(payload) as? [String: Any] ?? payload
    let envelope: [String: Any] = ["currentWorkout": sanitized]

    do {
      try session.updateApplicationContext(envelope)
    } catch {
      return "Apple Watch context sync failed: \(error.localizedDescription)"
    }

    if session.isReachable {
      session.sendMessage(envelope, replyHandler: nil, errorHandler: nil)
    } else {
      session.transferUserInfo(envelope)
    }

    return "Apple Watch workout synced"
  }

  /// WatchConnectivity rejects payloads containing NSNull. Flutter's standard
  /// codec turns Dart `null` into NSNull, so strip those before handing the
  /// payload to WCSession.
  private static func stripNulls(_ value: Any) -> Any? {
    if value is NSNull { return nil }
    if let dict = value as? [String: Any] {
      var cleaned: [String: Any] = [:]
      for (key, item) in dict {
        if let kept = stripNulls(item) {
          cleaned[key] = kept
        }
      }
      return cleaned
    }
    if let array = value as? [Any] {
      return array.compactMap { stripNulls($0) }
    }
    return value
  }

  func markCompletionHandled(_ completionId: String) {
    pendingCompletions.removeAll { item in
      item["completionId"] as? String == completionId
    }
    if session?.isReachable == true {
      session?.sendMessage(["completionHandled": completionId], replyHandler: nil, errorHandler: nil)
    }
  }

  func endWatchWorkout(_ workoutId: String) {
    guard let session else { return }
    let message: [String: Any] = ["endWorkout": workoutId]
    if session.isReachable {
      session.sendMessage(message, replyHandler: nil, errorHandler: { [weak self] _ in
        self?.session?.transferUserInfo(message)
      })
    } else {
      session.transferUserInfo(message)
    }
  }

  private func receiveCompletion(_ payload: [String: Any]) {
    pendingCompletions.append(payload)
    emitCompletion(payload)
    if let workoutId = payload["workoutId"] as? String,
       activeWatchWorkoutId == workoutId {
      activeWatchWorkoutId = nil
      emitSessionEnded(workoutId)
    }
  }

  private func emitCompletion(_ payload: [String: Any]) {
    eventSink?([
      "type": "watchWorkoutCompleted",
      "payload": payload,
    ])
  }

  fileprivate func handleSessionActive(_ workoutId: String) {
    activeWatchWorkoutId = workoutId
    eventSink?([
      "type": "watchSessionActive",
      "workoutId": workoutId,
    ])
  }

  fileprivate func handleSessionEnded(_ workoutId: String?) {
    let id = workoutId ?? activeWatchWorkoutId ?? ""
    activeWatchWorkoutId = nil
    emitSessionEnded(id)
  }

  private func emitSessionEnded(_ workoutId: String) {
    eventSink?([
      "type": "watchSessionEnded",
      "workoutId": workoutId,
    ])
  }
}

extension WatchSyncCoordinator: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    if let workoutId = activeWatchWorkoutId {
      events([
        "type": "watchSessionActive",
        "workoutId": workoutId,
      ])
    }
    for completion in pendingCompletions {
      emitCompletion(completion)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

extension WatchSyncCoordinator: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    if let payload = message["watchWorkoutCompleted"] as? [String: Any] {
      DispatchQueue.main.async { self.receiveCompletion(payload) }
    } else if let workoutId = message["watchSessionActive"] as? String {
      DispatchQueue.main.async { self.handleSessionActive(workoutId) }
    } else if message["watchSessionEnded"] != nil {
      let workoutId = message["watchSessionEnded"] as? String
      DispatchQueue.main.async { self.handleSessionEnded(workoutId) }
    }
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    if let payload = userInfo["watchWorkoutCompleted"] as? [String: Any] {
      DispatchQueue.main.async { self.receiveCompletion(payload) }
    } else if let workoutId = userInfo["watchSessionActive"] as? String {
      DispatchQueue.main.async { self.handleSessionActive(workoutId) }
    } else if userInfo["watchSessionEnded"] != nil {
      let workoutId = userInfo["watchSessionEnded"] as? String
      DispatchQueue.main.async { self.handleSessionEnded(workoutId) }
    }
  }
}
