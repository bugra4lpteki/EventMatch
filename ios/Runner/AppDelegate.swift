import Flutter
import UIKit
import UserNotifications
import CoreSpotlight
import MobileCoreServices

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var spotlightChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()

    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      spotlightChannel = FlutterMethodChannel(name: "com.eventmatch.app/spotlight", binaryMessenger: controller.binaryMessenger)
      spotlightChannel?.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "indexEvent" {
          if let args = call.arguments as? [String: Any],
             let id = args["id"] as? String,
             let title = args["title"] as? String {
            let description = args["description"] as? String ?? ""
            let keywords = args["keywords"] as? [String] ?? []
            self?.indexSpotlightEvent(id: id, title: title, description: description, keywords: keywords)
            result(true)
          } else {
            result(false)
          }
        } else if call.method == "deindexEvent" {
          if let args = call.arguments as? [String: Any],
             let id = args["id"] as? String {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["event_\(id)"], completionHandler: nil)
            result(true)
          } else {
            result(false)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func indexSpotlightEvent(id: String, title: String, description: String, keywords: [String]) {
    let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
    attributeSet.title = title
    attributeSet.contentDescription = description
    var allKeywords = keywords
    allKeywords.append(contentsOf: ["EventMatch", "Konser", "Festival", "Etkinlik"])
    attributeSet.keywords = allKeywords

    let item = CSSearchableItem(uniqueIdentifier: "event_\(id)", domainIdentifier: "com.eventmatch.events", attributeSet: attributeSet)
    CSSearchableIndex.default().indexSearchableItems([item]) { error in
      if let error = error {
        print("[Spotlight] Indexing error: \(error)")
      } else {
        print("[Spotlight] Successfully indexed event: \(id)")
      }
    }

    // Siri Shortcuts Activity
    let activity = NSUserActivity(activityType: "com.eventmatch.app.viewEvent")
    activity.title = title
    activity.userInfo = ["eventId": id]
    activity.isEligibleForSearch = true
    if #available(iOS 12.0, *) {
      activity.isEligibleForPrediction = true
      activity.suggestedInvocationPhrase = "\(title) Etkinliği"
    }
    activity.becomeCurrent()
  }

  // Spotlight veya Siri Shortcuts üzerinden uygulamaya tıklandığında
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == CSSearchableItemActionType {
      if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
        let eventId = uniqueIdentifier.replacingOccurrences(of: "event_", with: "")
        spotlightChannel?.invokeMethod("onSpotlightEventTapped", arguments: eventId)
        return true
      }
    } else if userActivity.activityType == "com.eventmatch.app.viewEvent" {
      if let eventId = userActivity.userInfo?["eventId"] as? String {
        spotlightChannel?.invokeMethod("onSpotlightEventTapped", arguments: eventId)
        return true
      }
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
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
