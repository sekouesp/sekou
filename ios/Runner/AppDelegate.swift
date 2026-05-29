import UIKit
import Flutter
import FirebaseCore
import OneSignalFramework

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    // OneSignal init
    // ⚠️ Remplace TON_ONESIGNAL_APP_ID par ton vrai App ID
    OneSignal.initialize("TON_ONESIGNAL_APP_ID", withLaunchOptions: launchOptions)
    OneSignal.Notifications.requestPermission({ accepted in
      print("ESP SEKOU - OneSignal permission: \(accepted)")
    }, fallbackToSettings: true)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
