import Flutter
import Foundation
import WatchConnectivity

final class WatchSyncCoordinator: NSObject {
  private let session: WCSession?
  private var eventSink: FlutterEventSink?
  private var pendingCompletions: [[String: Any]] = []

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

    do {
      try session.updateApplicationContext(["currentWorkout": payload])
    } catch {
      return "Apple Watch context sync failed: \(error.localizedDescription)"
    }

    if session.isReachable {
      session.sendMessage(["currentWorkout": payload], replyHandler: nil, errorHandler: nil)
    } else {
      session.transferUserInfo(["currentWorkout": payload])
    }

    return "Apple Watch workout synced"
  }

  func markCompletionHandled(_ completionId: String) {
    pendingCompletions.removeAll { item in
      item["completionId"] as? String == completionId
    }
    if session?.isReachable == true {
      session?.sendMessage(["completionHandled": completionId], replyHandler: nil, errorHandler: nil)
    }
  }

  private func receiveCompletion(_ payload: [String: Any]) {
    pendingCompletions.append(payload)
    emitCompletion(payload)
  }

  private func emitCompletion(_ payload: [String: Any]) {
    eventSink?([
      "type": "watchWorkoutCompleted",
      "payload": payload,
    ])
  }
}

extension WatchSyncCoordinator: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
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
      DispatchQueue.main.async {
        self.receiveCompletion(payload)
      }
    }
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    if let payload = userInfo["watchWorkoutCompleted"] as? [String: Any] {
      DispatchQueue.main.async {
        self.receiveCompletion(payload)
      }
    }
  }
}
