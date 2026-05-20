import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let exchangeChannelName = "codex_fitness/exchange"

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
