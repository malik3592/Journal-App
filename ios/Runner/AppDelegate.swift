import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let fileExport = journalFileExportPlugin()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    fileExport.attach(to: engineBridge.applicationRegistrar.messenger())
  }
}

final class journalFileExportPlugin: NSObject, UIDocumentPickerDelegate {
  private var channel: FlutterMethodChannel?
  private var pending: FlutterResult?

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "journal/file_export", binaryMessenger: messenger)
    channel.setMethodCallHandler(handle)
    self.channel = channel
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "exportFile" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
      result(FlutterError(code: "bad_args", message: "Missing path", details: nil))
      return
    }
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
      result(FlutterError(code: "missing", message: "Backup file was not found.", details: nil))
      return
    }
    if pending != nil {
      result(FlutterError(code: "busy", message: "A save dialog is already open.", details: nil))
      return
    }
    pending = result
    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    } else {
      picker = UIDocumentPickerViewController(url: url, in: .exportToService)
    }
    picker.delegate = self
    picker.allowsMultipleSelection = false
    guard let presenter = Self.topViewController() else {
      finish(false)
      return
    }
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finish(true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(false)
  }

  private func finish(_ saved: Bool) {
    pending?(saved)
    pending = nil
  }

  private static func topViewController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    let window = windows.first(where: \.isKeyWindow) ?? windows.first
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}
