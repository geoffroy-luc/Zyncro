import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let notifChannel = FlutterMethodChannel(
      name: "com.zyncro.app/notifications",
      binaryMessenger: controller.binaryMessenger
    )
    notifChannel.setMethodCallHandler { call, result in
      if call.method == "dismissAllNotifications" {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
