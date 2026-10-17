import XCTest
import UIKit
import SQLite3
@testable import Runner

final class RunnerTests: XCTestCase {
    private var root: URL!
    private var service: String!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("leandaily-test-\(UUID())", isDirectory: true)
        service = "app.leandaily.tests.\(UUID())"
    }
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) {
            // The future-schema test intentionally makes this database unopenable.
            if let store = try? LocalStore(root: root, service: service) { try store.setSecrets("") }
            try FileManager.default.removeItem(at: root)
        }
    }
    func testDocumentsPersistAfterReopenIncludingLargeUnicode() throws {
        let value = String(repeating: "训练🍊中文", count: 100000)
        do {
            let store = try LocalStore(root: root, service: service)
            try store.put("android-state", value)
            try store.put("fw-profile-v1", "{\"age\":30}")
            try store.put("fw-profile-v1", "{\"age\":31}")
        }
        let reopened = try LocalStore(root: root, service: service)
        XCTAssertEqual(try reopened.all(), ["android-state": value, "fw-profile-v1": "{\"age\":31}"])
        XCTAssertThrowsError(try reopened.put("key", "bad\0value"))
        XCTAssertEqual(try reopened.all()["android-state"], value)
        XCTAssertEqual(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }
    func testFutureSchemaIsRejectedWithoutDowngrading() throws {
        do { _ = try LocalStore(root: root, service: service) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(root.appendingPathComponent("fitness.db").path, &db), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "PRAGMA user_version=2", nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)
        XCTAssertThrowsError(try LocalStore(root: root, service: service))
    }
    func testKeychainIsSeparateAndSurvivesReopen() throws {
        do {
            let store = try LocalStore(root: root, service: service)
            try store.setSecrets("test-key-not-a-real-credential")
            XCTAssertTrue(try store.all().isEmpty)
        }
        let store = try LocalStore(root: root, service: service)
        XCTAssertEqual(try store.secrets()["modelKey"], "test-key-not-a-real-credential")
        try store.setSecrets("updated-test-value")
        XCTAssertEqual(try store.secrets()["modelKey"], "updated-test-value")
        try store.setSecrets("")
        XCTAssertEqual(try store.secrets()["modelKey"], "")
    }
    func testFreshSandboxDoesNotResurrectKeychain() throws {
        do { try LocalStore(root: root, service: service).setSecrets("old-install") }
        try FileManager.default.removeItem(at: root)
        XCTAssertEqual(try LocalStore(root: root, service: service).secrets()["modelKey"], "")
    }
    private func jpeg() throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 8)).image { context in
            UIColor.orange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 12, height: 8))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
    }
    func testPhotosAreRelativeAndSurviveContainerRelocation() throws {
        let bytes = try jpeg()
        let path: String
        do {
            let store = try LocalStore(root: root, service: service)
            path = try store.photoWrite(bytes)
            XCTAssertTrue(path.hasPrefix("photos/"))
            let (actual, hash) = try store.photoRead(path)
            XCTAssertEqual(actual, bytes); XCTAssertEqual(hash.count, 64)
            XCTAssertEqual(try root.appendingPathComponent(path).resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
            XCTAssertThrowsError(try store.photoRead("../outside.jpg"))
            XCTAssertThrowsError(try store.photoRead("/etc/passwd"))
            XCTAssertThrowsError(try store.photoWrite(Data([0, 1, 2])))
        }
        let moved = root.appendingPathExtension("moved")
        try FileManager.default.moveItem(at: root, to: moved); root = moved
        XCTAssertEqual(try LocalStore(root: root, service: service).photoRead(path).0, bytes)
    }
    func testImageDownsamplingAndOrientationProducesJPEG() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1800)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1800))
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("input.png")
        try XCTUnwrap(image.pngData()).write(to: url)
        let data = try NativePickers.jpeg(url)
        XCTAssertEqual(Array(data.prefix(2)), [255, 216])
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(decoded.size.width, decoded.size.height), 1600)
    }
    func testHTTPRejectsInsecureAndCredentialURLsWithoutNetwork() {
        let http = NativeHTTP()
        for url in ["http://example.test", "file:///etc/passwd", "https://key:secret@example.test"] {
            let done = expectation(description: url)
            http.request(["id": UUID().uuidString, "url": url]) { result in
                if case .success = result { XCTFail("Invalid URL accepted") }
                done.fulfill()
            }
            wait(for: [done], timeout: 2)
        }
    }
    func testHTTPCancellationBeforeRequestDoesNotConnect() {
        let http = NativeHTTP(), done = expectation(description: "cancel")
        http.cancel("cancel-before-start")
        http.request(["id": "cancel-before-start", "url": "https://example.test"]) { result in
            if case .failure(let error) = result { XCTAssertEqual(error.localizedDescription, "请求已取消") }
            else { XCTFail("Cancelled request succeeded") }
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
    }
    func testNotificationSchedulePendingAndCancel() throws {
        let notifications = NativeNotifications()
        let authorization = expectation(description: "notification authorization state")
        var granted = false
        notifications.state { state in granted = state["granted"] == true; authorization.fulfill() }
        wait(for: [authorization], timeout: 5)
        try XCTSkipIf(!granted, "Authorize local notifications on this test simulator to verify OS scheduling.")
        let done = expectation(description: "notification roundtrip")
        let id = 880001
        notifications.schedule([["id": id, "title": "测试", "body": "训练", "atMs": Date().addingTimeInterval(600).timeIntervalSince1970 * 1000, "plan": true]]) { result in
            if case .failure(let error) = result { XCTFail(error.localizedDescription); done.fulfill(); return }
            notifications.pending { ids in
                XCTAssertTrue(ids.contains(id))
                notifications.cancel([id])
                notifications.pending { remaining in
                    XCTAssertFalse(remaining.contains(id)); done.fulfill()
                }
            }
        }
        wait(for: [done], timeout: 8)
    }
    func testHTTPResponseAndMultipartEncoding() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let http = NativeHTTP(configuration: config)
        let done = expectation(description: "multipart response")
        StubURLProtocol.handler = { request, client, stub in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=LeanDaily") == true)
            // URLSession can expose a body as either Data or a stream to URLProtocol.
            var payload = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }; payload.append(contentsOf: buffer.prefix(count))
                }
            }
            let text = String(decoding: payload, as: UTF8.self)
            XCTAssertTrue(text.contains("name=\"model\""))
            XCTAssertTrue(text.contains("meal.jpg"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            client.urlProtocol(stub, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(stub, didLoad: Data("{\"ok\":true}".utf8))
            client.urlProtocolDidFinishLoading(stub)
        }
        http.request(["id": "multipart", "url": "https://example.test/upload", "method": "POST",
                      "headers": ["Authorization": "Bearer test-only"],
                      "multipart": ["fields": ["model": "vision"], "bytes": Data([255, 216, 255])]]) { result in
            switch result {
            case .success(let value):
                XCTAssertEqual(value["status"] as? Int, 201)
                XCTAssertEqual(value["body"] as? String, "{\"ok\":true}")
            case .failure(let error): XCTFail(error.localizedDescription)
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        StubURLProtocol.handler = nil
    }
    func testHTTPResponseSizeLimit() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let http = NativeHTTP(configuration: config), done = expectation(description: "response cap")
        StubURLProtocol.handler = { request, client, stub in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Length": "20000000"])!
            client.urlProtocol(stub, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(stub, didLoad: Data([1, 2, 3]))
            client.urlProtocolDidFinishLoading(stub)
        }
        http.request(["id": "large", "url": "https://example.test/large"]) { result in
            if case .failure(let error) = result { XCTAssertEqual(error.localizedDescription, "网络响应超过16MB") }
            else { XCTFail("Oversize response accepted") }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        StubURLProtocol.handler = nil
    }
    func testHTTPDeadlineCancelsStalledRequest() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let http = NativeHTTP(configuration: config), done = expectation(description: "deadline")
        StubURLProtocol.handler = { _, _, _ in }
        http.request(["id": "deadline", "url": "https://example.test/stalled", "timeout": 1000]) { result in
            if case .failure(let error) = result { XCTAssertEqual(error.localizedDescription, "请求超时，请手动重试") }
            else { XCTFail("Stalled request succeeded") }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        StubURLProtocol.handler = nil
    }

}


private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest, URLProtocolClient, StubURLProtocol) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let client = client { Self.handler?(request, client, self) }
    }
    override func stopLoading() {}
}
