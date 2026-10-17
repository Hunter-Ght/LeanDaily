import Foundation
import UserNotifications

final class NativeNotifications {
    private let center = UNUserNotificationCenter.current()
    private let prefix = "leandaily."
    func state(_ done: @escaping ([String: Bool]) -> Void) {
        center.getNotificationSettings { settings in
            let granted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral
            // iOS has no Android exact-alarm permission. The system schedules local notifications.
            done(["granted": granted, "exact": true])
        }
    }
    func request(_ done: @escaping (Result<Bool, Error>) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error { done(.failure(error)) } else { done(.success(granted)) }
        }
    }
    func schedule(_ notes: [[String: Any]], done: @escaping (Result<Void, Error>) -> Void) {
        // iOS limits pending requests. Fail explicitly rather than silently dropping reminders.
        center.getPendingNotificationRequests { current in
            do {
                let replacing = Set(notes.compactMap { ($0["id"] as? NSNumber).map { self.prefix + $0.stringValue } })
                let retained = current.filter { !replacing.contains($0.identifier) }.count
                guard retained + replacing.count <= 64 else { throw NativeFailure("提醒数量过多，请减少提醒后重试") }
                var requests: [UNNotificationRequest] = []
                var ids = Set<Int>()
                for note in notes {
                    guard let id = note["id"] as? Int, ids.insert(id).inserted,
                          let ms = note["atMs"] as? NSNumber,
                          let title = note["title"] as? String, let body = note["body"] as? String else { throw NativeFailure("提醒内容无效") }
                    let date = Date(timeIntervalSince1970: ms.doubleValue / 1000)
                    guard date > Date() else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = title; content.body = body; content.sound = .default
                    content.userInfo = ["plan": note["plan"] as? Bool ?? false]
                    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                    components.timeZone = calendar.timeZone
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    requests.append(UNNotificationRequest(identifier: self.prefix + String(id), content: content, trigger: trigger))
                }
                self.add(requests, index: 0, done: done)
            } catch { done(.failure(error)) }
        }
    }
    private func add(_ requests: [UNNotificationRequest], index: Int, done: @escaping (Result<Void, Error>) -> Void) {
        guard index < requests.count else { done(.success(())); return }
        center.add(requests[index]) { error in
            if let error = error { done(.failure(error)) }
            else { self.add(requests, index: index + 1, done: done) }
        }
    }
    func cancel(_ ids: [Int]) {
        let names = ids.map { prefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: names)
        center.removeDeliveredNotifications(withIdentifiers: names)
    }
    func pending(_ done: @escaping ([Int]) -> Void) {
        center.getPendingNotificationRequests { requests in
            done(requests.compactMap { request in
                guard request.identifier.hasPrefix(self.prefix) else { return nil }
                return Int(request.identifier.dropFirst(self.prefix.count))
            }.sorted())
        }
    }
}
