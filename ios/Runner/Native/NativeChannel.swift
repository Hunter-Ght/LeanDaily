import Flutter
import UIKit

final class NativeChannel {
    private let channel: FlutterMethodChannel
    private let io = DispatchQueue(label: "app.leandaily.storage", qos: .userInitiated)
    private var store: LocalStore?
    private let http = NativeHTTP()
    private let pickers = NativePickers()
    private let notifications = NativeNotifications()
    private var launchPayload: [String: Any]?
    private var notificationListenerReady = false

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "leandaily/native", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
    }
    func notificationTap(_ payload: [String: Any]) {
        DispatchQueue.main.async {
            if self.notificationListenerReady { self.channel.invokeMethod("notificationTap", arguments: payload) }
            else { self.launchPayload = payload }
        }
    }
    private func database() throws -> LocalStore {
        if let store = store { return store }
        let value = try LocalStore(); store = value; return value
    }
    private func error(_ error: Error) -> FlutterError {
        let message: String
        if let failure = error as? NativeFailure { message = failure.message }
        else if let urlError = error as? URLError {
            message = urlError.code == .cancelled ? "请求已取消" : urlError.code == .timedOut ? "请求超时，请手动重试" : "网络不可用，请检查后重试"
        } else { message = "操作失败：文件或存储不可用，请检查后重试" }
        return FlutterError(code: "native", message: message, details: nil)
    }
    private func complete(_ outcome: Result<Any?, Error>, _ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            switch outcome {
            case .success(let value): result(value)
            case .failure(let failure): result(self.error(failure))
            }
        }
    }
    private func async(_ result: @escaping FlutterResult, _ work: @escaping () throws -> Any?) {
        io.async { self.complete(Result { try work() }, result) }
    }
    private func text(_ args: [String: Any], _ key: String) throws -> String {
        guard let value = args[key] as? String else { throw NativeFailure("缺少参数：\(key)") }; return value
    }
    private func zone(_ args: [String: Any]) throws -> TimeZone {
        guard let tz = TimeZone(identifier: try text(args, "tz")) else { throw NativeFailure("时区无效") }; return tz
    }
    private func formatter(_ tz: TimeZone, _ format: String) -> DateFormatter {
        let value = DateFormatter(); value.locale = Locale(identifier: "en_US_POSIX")
        value.calendar = Calendar(identifier: .gregorian); value.timeZone = tz
        value.dateFormat = format; value.isLenient = false; return value
    }
    private func handle(_ call: FlutterMethodCall, result raw: @escaping FlutterResult) {
        // A system UI or an asynchronous callback must never reply twice.
        var replied = false
        let result: FlutterResult = { value in
            dispatchPrecondition(condition: .onQueue(.main))
            guard !replied else { return }; replied = true; raw(value)
        }
        let args = call.arguments as? [String: Any] ?? [:]
        do {
            switch call.method {
            case "all": async(result) { try self.database().all() }
            case "put": async(result) { try self.database().put(self.text(args, "key"), self.text(args, "value")); return nil }
            case "secretsGet": async(result) { try self.database().secrets() }
            case "secretsSet": async(result) { try self.database().setSecrets(args["modelKey"] as? String ?? ""); return nil }
            case "pruneSecrets": async(result) {
                let store = try self.database(); try store.setSecrets(store.secrets()["modelKey"] ?? ""); return nil
            }
            case "photoWrite": async(result) {
                guard let bytes = args["bytes"] as? FlutterStandardTypedData else { throw NativeFailure("照片内容无效") }
                return try self.database().photoWrite(bytes.data)
            }
            case "photoRead": async(result) {
                let (bytes, hash) = try self.database().photoRead(self.text(args, "path"))
                return ["bytes": FlutterStandardTypedData(bytes: bytes), "size": bytes.count, "sha256": hash]
            }
            case "http":
                var parameters = args
                if var multipart = args["multipart"] as? [String: Any], let bytes = multipart["bytes"] as? FlutterStandardTypedData {
                    multipart["bytes"] = bytes.data; parameters["multipart"] = multipart
                }
                http.request(parameters) { outcome in self.complete(outcome.map { $0 as Any? }, result) }
            case "cancelHttp": http.cancel(try text(args, "id")); result(nil)
            case "exportDocument": pickers.exportDocument(data: try text(args, "data"), name: args["name"] as? String ?? "") { self.complete($0, result) }
            case "importDocument": pickers.importDocument { self.complete($0, result) }
            case "pickImages": pickers.pickImages(source: try text(args, "source"), limit: args["limit"] as? Int ?? 1) { outcome in
                self.complete(outcome.map { value in
                    (value as? [Data])?.map { FlutterStandardTypedData(bytes: $0) }
                }, result)
            }
            case "debugIsSimulator":
                #if DEBUG && targetEnvironment(simulator)
                result(true)
                #else
                result(false)
                #endif
            case "deviceTz": result(TimeZone.current.identifier)
            case "clock": async(result) {
                let tz = try self.zone(args), now = Date()
                return ["today": self.formatter(tz, "yyyy-MM-dd").string(from: now), "now": self.formatter(tz, "HH:mm").string(from: now)]
            }
            case "zonedMs": async(result) {
                let tz = try self.zone(args), raw = try self.text(args, "date")
                let format = self.formatter(tz, "yyyy-MM-dd")
                guard raw.count == 10, let date = format.date(from: raw), format.string(from: date) == raw else { throw NativeFailure("日期无效") }
                return Int64((date.timeIntervalSince1970 * 1000).rounded())
            }
            case "zonedDate": async(result) {
                guard let ms = args["ms"] as? NSNumber else { throw NativeFailure("日期无效") }
                return try self.formatter(self.zone(args), "yyyy-MM-dd").string(from: Date(timeIntervalSince1970: ms.doubleValue / 1000))
            }
            case "notifyState": notifications.state { self.complete(.success($0), result) }
            case "requestNotify": notifications.request { self.complete($0.map { $0 as Any? }, result) }
            case "openExactAlarmSettings":
                // There is no equivalent permission gate on iOS.
                result(nil)
            case "schedule":
                guard let notes = call.arguments as? [[String: Any]] else { throw NativeFailure("提醒内容无效") }
                notifications.schedule(notes) { self.complete($0.map { _ in nil }, result) }
            case "cancel":
                guard let ids = call.arguments as? [Int] else { throw NativeFailure("提醒标识无效") }
                notifications.cancel(ids); result(nil)
            case "pendingIds": notifications.pending { self.complete(.success($0), result) }
            case "takeLaunchPayload":
                notificationListenerReady = true; result(launchPayload); launchPayload = nil
            case "keepAwake": UIApplication.shared.isIdleTimerDisabled = call.arguments as? Bool ?? false; result(nil)
            case "openUrl":
                guard let url = URL(string: try text(args, "url")), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw NativeFailure("链接无效") }
                UIApplication.shared.open(url, options: [:]) { opened in
                    if opened { result(nil) } else { result(self.error(NativeFailure("暂时无法打开页面"))) }
                }
            case "minimize": result(nil) // iOS applications must not programmatically suspend or exit.
            default: result(FlutterMethodNotImplemented)
            }
        } catch { result(self.error(error)) }
    }
}
