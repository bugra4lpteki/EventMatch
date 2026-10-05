import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var secureField: UITextField?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let securityChannel = FlutterMethodChannel(name: "com.eventmatch.app/security", binaryMessenger: controller.binaryMessenger)

    securityChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(false)
        return
      }
      if call.method == "enableSecure" {
        self.enableIosSecurity()
        result(true)
      } else if call.method == "disableSecure" {
        self.disableIosSecurity()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func enableIosSecurity() {
    DispatchQueue.main.async {
      if self.secureField == nil, let win = self.window {
        let field = UITextField()
        field.isSecureTextEntry = true
        win.addSubview(field)
        field.centerYAnchor.constraint(equalTo: win.centerYAnchor).isActive = true
        field.centerXAnchor.constraint(equalTo: win.centerXAnchor).isActive = true
        win.layer.superlayer?.addSublayer(field.layer)
        field.layer.sublayers?.first?.addSublayer(win.layer)
        self.secureField = field
      }
    }
  }

  private func disableIosSecurity() {
    DispatchQueue.main.async {
      self.secureField?.removeFromSuperview()
      self.secureField = nil
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // iOS ön plandayken gelen bildirimlerin banner ve ses olarak sunulması
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .sound, .badge])
  }
}
