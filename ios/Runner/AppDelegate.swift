import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let exchangeChannelName = "codex_fitness/exchange"
  private let watchChannelName = "codex_fitness/watch_sync"
  private let watchEventsName = "codex_fitness/watch_events"
  private let watchSync = WatchSyncCoordinator()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: exchangeChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "iCloudExchangeDirectory":
          self?.resolveICloudExchangeDirectory(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
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

  private func resolveICloudExchangeDirectory(result: FlutterResult) {
    guard let containerUrl = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
      result(nil)
      return
    }

    let documentsUrl = containerUrl
      .appendingPathComponent("Documents", isDirectory: true)
      .appendingPathComponent("CodexFitnessExchange", isDirectory: true)

    do {
      try FileManager.default.createDirectory(
        at: documentsUrl,
        withIntermediateDirectories: true,
        attributes: nil
      )
      result(documentsUrl.path)
    } catch {
      result(FlutterError(
        code: "icloud_exchange_directory_failed",
        message: "Could not create iCloud CodexFitnessExchange directory.",
        details: error.localizedDescription
      ))
    }
  }
}
