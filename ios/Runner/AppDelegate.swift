import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var dockGlassChannel: FlutterMethodChannel?
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
        let glassChannel = FlutterMethodChannel(name: "leandaily/dock-glass", binaryMessenger: registrar.messenger())
        glassChannel.setMethodCallHandler { call, result in
            guard call.method == "isSupported" else { result(FlutterMethodNotImplemented); return }
            if #available(iOS 26.0, *) { result(true) } else { result(false) }
        }
        dockGlassChannel = glassChannel
        registrar.register(DockGlassFactory(messenger: registrar.messenger()), withId: "leandaily/dock-glass")
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

/// A real system tab bar: UIKit owns its glass, selection and accessibility.
final class DockGlassFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        DockGlassPlatformView(frame: frame, viewId: viewId, messenger: messenger,
                              configuration: args as? [String: Any] ?? [:])
    }
}

final class DockGlassPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {
    let tabBar = UITabBar()
    private let channel: FlutterMethodChannel
    init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, configuration: [String: Any]) {
        channel = FlutterMethodChannel(name: "leandaily/dock-glass/\(viewId)", binaryMessenger: messenger)
        super.init()
        tabBar.frame = frame
        tabBar.backgroundColor = .clear
        // Keep UIKit's default appearance. A custom background or selection
        // image would replace the system's Liquid Glass rendering.
        let icons = configuration["icons"] as? [FlutterStandardTypedData] ?? []
        let labels = configuration["labels"] as? [String] ?? []
        tabBar.items = (0..<4).map { index in
            func icon(_ selected: Bool) -> UIImage? {
                let offset = index * 2 + (selected ? 1 : 0)
                guard icons.indices.contains(offset) else { return nil }
                return UIImage(data: icons[offset].data, scale: 3)?.withRenderingMode(.alwaysTemplate)
            }
            // Titles must exist BEFORE installing items. UIKit otherwise caches
            // the unselected items' icon-only layout until their first tap.
            let title = labels.indices.contains(index) ? labels[index] : ""
            let item = UITabBarItem(title: title, image: icon(false), selectedImage: icon(true))
            item.tag = index
            item.accessibilityIdentifier = "leandaily-tab-\(index)"
            return item
        }
        tabBar.delegate = self
        update(configuration)
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "update", let config = call.arguments as? [String: Any] else {
                result(FlutterMethodNotImplemented); return
            }
            self?.update(config)
            result(nil)
        }
    }
    deinit { channel.setMethodCallHandler(nil) }
    func update(_ configuration: [String: Any]) {
        if let labels = configuration["labels"] as? [String], labels.count == 4 {
            for (item, title) in zip(tabBar.items ?? [], labels) where item.title != title {
                item.title = title
            }
        }
        if let selected = configuration["selected"] as? Int,
           let items = tabBar.items, items.indices.contains(selected),
           tabBar.selectedItem !== items[selected] {
            tabBar.selectedItem = items[selected]
        }
        if let argb = configuration["tint"] as? NSNumber {
            let value = argb.uint32Value
            tabBar.tintColor = UIColor(red: CGFloat((value >> 16) & 255) / 255,
                                       green: CGFloat((value >> 8) & 255) / 255,
                                       blue: CGFloat(value & 255) / 255, alpha: 1)
        }
        let style: UIUserInterfaceStyle = configuration["dark"] as? Bool == true ? .dark : .light
        if tabBar.overrideUserInterfaceStyle != style { tabBar.overrideUserInterfaceStyle = style }
        let badge = configuration["updateDot"] as? Bool == true ? "" : nil
        if tabBar.items?.last?.badgeValue != badge { tabBar.items?.last?.badgeValue = badge }
    }
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        UISelectionFeedbackGenerator().selectionChanged()
        channel.invokeMethod("select", arguments: item.tag)
    }
    func view() -> UIView { tabBar }
}
