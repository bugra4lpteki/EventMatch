import Flutter
import UIKit
import UserNotifications
import CoreSpotlight
import MobileCoreServices
import Intents
import EventKit
import EventKitUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, EKEventEditViewDelegate {
  private var spotlightChannel: FlutterMethodChannel?
  private var calendarChannel: FlutterMethodChannel?
  private let eventStore = EKEventStore()

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

      setupCalendarChannel(controller: controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupCalendarChannel(controller: FlutterViewController) {
    calendarChannel = FlutterMethodChannel(name: "com.eventmatch.app/calendar", binaryMessenger: controller.binaryMessenger)
    calendarChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "addEvent" {
        guard let args = call.arguments as? [String: Any],
              let title = args["title"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Eksik parametre", details: nil))
          return
        }

        let startMillis: Int64
        if let val = args["startDate"] as? Int64 {
          startMillis = val
        } else if let val = args["startDate"] as? NSNumber {
          startMillis = val.int64Value
        } else if let val = args["startDate"] as? Int {
          startMillis = Int64(val)
        } else {
          startMillis = Int64(Date().timeIntervalSince1970 * 1000)
        }

        let endMillis: Int64
        if let val = args["endDate"] as? Int64 {
          endMillis = val
        } else if let val = args["endDate"] as? NSNumber {
          endMillis = val.int64Value
        } else if let val = args["endDate"] as? Int {
          endMillis = Int64(val)
        } else {
          endMillis = startMillis + 3 * 3600 * 1000
        }

        let location = args["location"] as? String ?? ""
        let notes = args["notes"] as? String ?? ""
        let urlString = args["url"] as? String
        let url = urlString != nil ? URL(string: urlString!) : nil

        let startDate = Date(timeIntervalSince1970: Double(startMillis) / 1000.0)
        let endDate = Date(timeIntervalSince1970: Double(endMillis) / 1000.0)

        self.presentCalendarEvent(
          title: title,
          notes: notes,
          location: location,
          startDate: startDate,
          endDate: endDate,
          url: url,
          result: result
        )
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func presentCalendarEvent(
    title: String,
    notes: String,
    location: String,
    startDate: Date,
    endDate: Date,
    url: URL?,
    result: @escaping FlutterResult
  ) {
    let showEditor = { [weak self] in
      guard let self = self else { return }
      DispatchQueue.main.async {
        guard let window = self.window,
              let rootVC = window.rootViewController else {
          result(FlutterError(code: "NO_ROOT_VC", message: "Pencere yöneticisi bulunamadı", details: nil))
          return
        }

        var topController = rootVC
        while let presented = topController.presentedViewController, !presented.isBeingDismissed {
          topController = presented
        }

        let event = EKEvent(eventStore: self.eventStore)
        event.title = title
        event.notes = notes
        event.location = location
        event.startDate = startDate
        event.endDate = endDate
        event.url = url
        event.calendar = self.eventStore.defaultCalendarForNewEvents

        let editVC = EKEventEditViewController()
        editVC.event = event
        editVC.eventStore = self.eventStore
        editVC.editViewDelegate = self

        topController.present(editVC, animated: true) {
          result(true)
        }
      }
    }

    let status = EKEventStore.authorizationStatus(for: .event)
    var isAuthorized = false
    if #available(iOS 17.0, *) {
      isAuthorized = (status == .fullAccess || status == .writeOnly)
    } else {
      isAuthorized = (status.rawValue == 3) // .authorized
    }

    if isAuthorized {
      showEditor()
      return
    }

    if status == .notDetermined {
      if #available(iOS 17.0, *) {
        eventStore.requestWriteOnlyAccessToEvents { granted, error in
          if granted {
            showEditor()
          } else {
            DispatchQueue.main.async {
              result(FlutterError(code: "PERMISSION_DENIED", message: error?.localizedDescription ?? "Takvim izni verilmedi", details: nil))
            }
          }
        }
      } else {
        eventStore.requestAccess(to: .event) { granted, error in
          if granted {
            showEditor()
          } else {
            DispatchQueue.main.async {
              result(FlutterError(code: "PERMISSION_DENIED", message: error?.localizedDescription ?? "Takvim izni verilmedi", details: nil))
            }
          }
        }
      }
    } else {
      DispatchQueue.main.async {
        result(FlutterError(code: "PERMISSION_DENIED", message: "Takvim erişim izni kapalı", details: nil))
      }
    }
  }

  // EKEventEditViewDelegate
  public func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
    controller.dismiss(animated: true, completion: nil)
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
