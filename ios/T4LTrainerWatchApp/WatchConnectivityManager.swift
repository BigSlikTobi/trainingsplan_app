import Foundation
import WatchConnectivity

/// Watch side of the app↔watch WatchConnectivity link. Sends workout progress
/// and completions to the phone, and receives planned workouts and
/// end-workout commands. All wire keys come from `WatchMessageKey`.
final class WatchConnectivityManager: NSObject {
  private(set) var isReachable = false

  private let session: WCSession?
  private var onWorkout: ((WatchWorkoutEnvelope) -> Void)?
  private var onEndWorkout: ((String?) -> Void)?

  override init() {
    session = WCSession.isSupported() ? WCSession.default : nil
    super.init()
    session?.delegate = self
    session?.activate()
  }

  // MARK: - Observation hooks

  func observeWorkouts(_ handler: @escaping (WatchWorkoutEnvelope) -> Void) {
    onWorkout = handler
  }

  func observeEndWorkout(_ handler: @escaping (String?) -> Void) {
    onEndWorkout = handler
  }

  // MARK: - Outbound

  func notifySessionActive(workoutId: String) {
    sendStateMessage([WatchMessageKey.sessionActive: workoutId])
  }

  func notifySessionEnded(workoutId: String) {
    sendStateMessage([WatchMessageKey.sessionEnded: workoutId])
  }

  func sendCompletion(_ payload: WatchCompletionPayload) {
    guard let message = try? DictionaryCoding.encode(payload) else { return }
    queue(payload)
    deliver([WatchMessageKey.workoutCompleted: message],
            fallback: { [weak self] in self?.transferCompletion(message) })
  }

  func sendProgress(_ payload: WatchProgressPayload) {
    guard let message = try? DictionaryCoding.encode(payload) else { return }
    let envelope = [WatchMessageKey.workoutProgress: message]
    try? session?.updateApplicationContext(envelope)
    deliver(envelope, fallback: { [weak self] in self?.transferProgress(message) })
  }

  func retryPendingCompletions() {
    for payload in pendingCompletions() {
      guard let message = try? DictionaryCoding.encode(payload) else { continue }
      deliver([WatchMessageKey.workoutCompleted: message],
              fallback: { [weak self] in self?.transferCompletion(message) })
    }
  }

  func markCompletionHandled(_ completionId: String) {
    var pending = pendingCompletions()
    pending.removeAll { $0.completionId == completionId }
    persist(pending)
  }

  // MARK: - Delivery primitives

  /// Sends a live message when the phone is reachable, otherwise falls back to
  /// the durable `transferUserInfo` queue.
  private func deliver(_ message: [String: Any], fallback: @escaping () -> Void) {
    guard let session else { return }
    if session.isReachable {
      session.sendMessage(message, replyHandler: nil, errorHandler: { _ in fallback() })
    } else {
      fallback()
    }
  }

  private func sendStateMessage(_ message: [String: Any]) {
    guard let session else { return }
    if session.isReachable {
      session.sendMessage(message, replyHandler: nil, errorHandler: { [weak self] _ in
        self?.session?.transferUserInfo(message)
      })
    } else {
      session.transferUserInfo(message)
    }
  }

  private func transferCompletion(_ message: [String: Any]) {
    session?.transferUserInfo([WatchMessageKey.workoutCompleted: message])
  }

  private func transferProgress(_ message: [String: Any]) {
    session?.transferUserInfo([WatchMessageKey.workoutProgress: message])
  }

  // MARK: - Inbound

  private func receiveWorkout(_ value: Any) {
    guard let envelope = try? DictionaryCoding.decode(WatchWorkoutEnvelope.self, from: value)
    else { return }
    DispatchQueue.main.async { self.onWorkout?(envelope) }
  }

  private func route(_ payload: [String: Any]) {
    if let workout = payload[WatchMessageKey.currentWorkout] {
      receiveWorkout(workout)
    } else if let completionId = payload[WatchMessageKey.completionHandled] as? String {
      markCompletionHandled(completionId)
    } else if payload[WatchMessageKey.endWorkout] != nil {
      let workoutId = payload[WatchMessageKey.endWorkout] as? String
      DispatchQueue.main.async { self.onEndWorkout?(workoutId) }
    }
  }

  // MARK: - Pending-completion persistence

  private func queue(_ payload: WatchCompletionPayload) {
    var pending = pendingCompletions()
    pending.removeAll { $0.completionId == payload.completionId }
    pending.append(payload)
    persist(pending)
  }

  private func persist(_ pending: [WatchCompletionPayload]) {
    if let data = try? JSONEncoder().encode(pending) {
      UserDefaults.standard.set(data, forKey: WatchStorageKey.pendingCompletions)
    }
  }

  private func pendingCompletions() -> [WatchCompletionPayload] {
    guard let data = UserDefaults.standard.data(forKey: WatchStorageKey.pendingCompletions),
          let pending = try? JSONDecoder().decode([WatchCompletionPayload].self, from: data)
    else { return [] }
    return pending
  }
}

extension WatchConnectivityManager: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    let reachable = session.isReachable
    DispatchQueue.main.async { self.isReachable = reachable }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    let reachable = session.isReachable
    DispatchQueue.main.async {
      self.isReachable = reachable
      self.retryPendingCompletions()
    }
  }

  func session(
    _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    if let workout = applicationContext[WatchMessageKey.currentWorkout] {
      receiveWorkout(workout)
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    route(message)
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    route(userInfo)
  }
}
