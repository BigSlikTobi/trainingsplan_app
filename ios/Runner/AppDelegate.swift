import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let watchChannelName = "t4l_trainer/watch_sync"
  private let watchEventsName = "t4l_trainer/watch_events"
  private let watchSync = WatchSyncCoordinator()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let watchChannel = FlutterMethodChannel(
        name: watchChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      watchChannel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "syncWorkout":
          guard let payload = call.arguments as? [String: Any] else {
            result(FlutterError(
              code: "invalid_watch_payload",
              message: "Expected watch workout payload.",
              details: nil
            ))
            return
          }
          result(self?.watchSync.syncWorkout(payload))
        case "markCompletionHandled":
          let args = call.arguments as? [String: Any]
          if let completionId = args?["completionId"] as? String {
            self?.watchSync.markCompletionHandled(completionId)
          }
          result(nil)
        case "endWatchWorkout":
          let args = call.arguments as? [String: Any]
          if let workoutId = args?["workoutId"] as? String, !workoutId.isEmpty {
            self?.watchSync.endWatchWorkout(workoutId)
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      FlutterEventChannel(
        name: watchEventsName,
        binaryMessenger: controller.binaryMessenger
      ).setStreamHandler(watchSync)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
