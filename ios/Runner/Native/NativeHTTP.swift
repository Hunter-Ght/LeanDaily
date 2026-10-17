import Foundation

/// Ephemeral sessions: no cookie jar, disk cache, credentials or automatic redirects.
final class NativeHTTP: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    private struct Pending {
        let id: String
        let task: URLSessionDataTask
        let done: (Result<[String: Any], Error>) -> Void
        var bytes = Data()
        var failure: Error?
    }
    private let configuration: URLSessionConfiguration
    init(configuration: URLSessionConfiguration = .ephemeral) {
        self.configuration = configuration
        super.init()
    }
    private let lock = NSLock()
    private var requests: [Int: Pending] = [:]
    private var cancelled: [String: Date] = [:]
    private lazy var session: URLSession = {
        let config = configuration
        config.httpShouldSetCookies = false
        config.urlCache = nil; config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    func request(_ args: [String: Any], done: @escaping (Result<[String: Any], Error>) -> Void) {
        do {
            guard let id = args["id"] as? String, !id.isEmpty,
                  let raw = args["url"] as? String, let url = URL(string: raw),
                  url.scheme?.lowercased() == "https", url.host != nil,
                  url.user == nil, url.password == nil else { throw NativeFailure("接口必须使用有效 HTTPS 地址") }
            let seconds = min(120, max(1000, (args["timeout"] as? NSNumber)?.doubleValue ?? 120000) / 1000)
            var request = URLRequest(url: url, timeoutInterval: seconds)
            request.httpMethod = args["method"] as? String ?? "GET"
            for (key, value) in args["headers"] as? [String: String] ?? [:] { request.setValue(value, forHTTPHeaderField: key) }
            if let multipart = args["multipart"] as? [String: Any] {
                let boundary = "LeanDaily\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
                var payload = Data()
                func append(_ value: String) { payload.append(Data(value.utf8)) }
                for (key, value) in multipart["fields"] as? [String: String] ?? [:] {
                    guard !key.contains("\r"), !key.contains("\n"), !key.contains("\"") else { throw NativeFailure("上传字段无效") }
                    append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n")
                }
                guard let bytes = multipart["bytes"] as? Data, bytes.count <= 12 * 1024 * 1024 else { throw NativeFailure("上传照片无效或过大") }
                append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"meal.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n")
                payload.append(bytes); append("\r\n--\(boundary)--\r\n")
                request.httpBody = payload
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            } else if let body = args["body"] as? String { request.httpBody = Data(body.utf8) }
            lock.lock()
            cancelled = cancelled.filter { $0.value > Date().addingTimeInterval(-120) }
            if cancelled.removeValue(forKey: id) != nil {
                lock.unlock(); throw NativeFailure("请求已取消")
            }
            guard !requests.values.contains(where: { $0.id == id }) else { lock.unlock(); throw NativeFailure("请求标识重复") }
            let task = session.dataTask(with: request)
            requests[task.taskIdentifier] = Pending(id: id, task: task, done: done)
            lock.unlock()
            // URLRequest timeout is an inactivity timeout. Also enforce a wall-clock deadline.
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { [weak self, weak task] in
                guard let self = self, let task = task else { return }
                self.lock.lock()
                if self.requests[task.taskIdentifier] != nil {
                    self.requests[task.taskIdentifier]?.failure = NativeFailure("请求超时，请手动重试")
                    task.cancel()
                }
                self.lock.unlock()
            }
            task.resume()
        } catch { done(.failure(error)) }
    }
    func cancel(_ id: String) {
        lock.lock(); defer { lock.unlock() }
        if let pending = requests.values.first(where: { $0.id == id }) {
            requests[pending.task.taskIdentifier]?.failure = NativeFailure("请求已取消")
            pending.task.cancel()
        } else {
            cancelled = cancelled.filter { $0.value > Date().addingTimeInterval(-120) }
            cancelled[id] = Date()
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if response.expectedContentLength > 16 * 1024 * 1024 {
            lock.lock(); requests[dataTask.taskIdentifier]?.failure = NativeFailure("网络响应超过16MB"); lock.unlock()
            completionHandler(.cancel)
        } else { completionHandler(.allow) }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard let pending = requests[dataTask.taskIdentifier] else { return }
        if pending.bytes.count + data.count > 16 * 1024 * 1024 {
            requests[dataTask.taskIdentifier]?.failure = NativeFailure("网络响应超过16MB"); dataTask.cancel()
        } else { requests[dataTask.taskIdentifier]?.bytes.append(data) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock(); let pending = requests.removeValue(forKey: task.taskIdentifier); lock.unlock()
        guard let pending = pending else { return }
        if let failure = pending.failure ?? error { pending.done(.failure(failure)); return }
        guard let response = task.response as? HTTPURLResponse else { pending.done(.failure(NativeFailure("网络响应无效"))); return }
        pending.done(.success(["status": response.statusCode, "body": String(decoding: pending.bytes, as: UTF8.self)]))
    }
}
