import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var native: NativeChannel?
    private var pendingTap: [String: Any]?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        let registrar = engineBridge.applicationRegistrar
        native = NativeChannel(messenger: registrar.messenger())
        if let payload = pendingTap { native?.notificationTap(payload); pendingTap = nil }
    }
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier.hasPrefix("leandaily."),
           response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            let payload: [String: Any] = ["plan": response.notification.request.content.userInfo["plan"] as? Bool ?? false]
            if let native = native { native.notificationTap(payload) } else { pendingTap = payload }
        }
        completionHandler()
    }
}
