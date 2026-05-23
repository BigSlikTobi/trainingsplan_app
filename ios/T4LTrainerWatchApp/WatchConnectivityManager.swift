import Foundation
import WatchConnectivity

final class WatchConnectivityManager: NSObject, ObservableObject {
  @Published private(set) var isReachable = false

  private let session: WCSession?
  private var onWorkout: ((WatchWorkoutEnvelope) -> Void)?
  private let pendingKey = "pendingWatchWorkoutCompletions"

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

  func observeWorkouts(_ handler: @escaping (WatchWorkoutEnvelope) -> Void) {
    onWorkout = handler
  }

  func sendCompletion(_ payload: WatchCompletionPayload) {
    guard let message = try? DictionaryCoding.encode(payload) else { return }
    queue(payload)

    guard let session else { return }
    if session.isReachable {
      session.sendMessage(
        ["watchWorkoutCompleted": message],
        replyHandler: nil,
        errorHandler: { [weak self] _ in self?.transfer(message) }
      )
    } else {
      transfer(message)
    }
  }

  func retryPendingCompletions() {
    guard let session else { return }
    for payload in pendingCompletions() {
      guard let message = try? DictionaryCoding.encode(payload) else { continue }
      if session.isReachable {
        session.sendMessage(
          ["watchWorkoutCompleted": message],
          replyHandler: nil,
          errorHandler: { [weak self] _ in self?.transfer(message) }
        )
      } else {
        transfer(message)
      }
    }
  }

  func markCompletionHandled(_ completionId: String) {
    var pending = pendingCompletions()
    pending.removeAll { $0.completionId == completionId }
    if let data = try? JSONEncoder().encode(pending) {
      UserDefaults.standard.set(data, forKey: pendingKey)
    }
  }

  private func transfer(_ message: [String: Any]) {
    session?.transferUserInfo(["watchWorkoutCompleted": message])
  }

  private func receiveWorkout(_ value: Any) {
    guard let envelope = try? DictionaryCoding.decode(WatchWorkoutEnvelope.self, from: value) else {
      return
    }
    DispatchQueue.main.async {
      self.onWorkout?(envelope)
    }
  }

  private func queue(_ payload: WatchCompletionPayload) {
    var pending = pendingCompletions()
    pending.removeAll { $0.completionId == payload.completionId }
    pending.append(payload)
    if let data = try? JSONEncoder().encode(pending) {
      UserDefaults.standard.set(data, forKey: pendingKey)
    }
  }

  private func pendingCompletions() -> [WatchCompletionPayload] {
    guard let data = UserDefaults.standard.data(forKey: pendingKey),
          let pending = try? JSONDecoder().decode([WatchCompletionPayload].self, from: data) else {
      return []
    }
    return pending
  }
}

extension WatchConnectivityManager: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async {
      self.isReachable = session.isReachable
    }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async {
      self.isReachable = session.isReachable
      self.retryPendingCompletions()
    }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    if let workout = applicationContext["currentWorkout"] {
      receiveWorkout(workout)
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    if let workout = message["currentWorkout"] {
      receiveWorkout(workout)
    } else if let completionId = message["completionHandled"] as? String {
      markCompletionHandled(completionId)
    }
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    if let workout = userInfo["currentWorkout"] {
      receiveWorkout(workout)
    }
  }
}
