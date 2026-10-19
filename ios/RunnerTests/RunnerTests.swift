import XCTest
import Flutter
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
    @MainActor
    func testNativeDockSynchronizesSelectionLabelsThemeAndBadge() throws {
        let messenger = DockTestMessenger()
        let icons = try dockTestIcons()
        let platformView = DockGlassPlatformView(
            frame: CGRect(x: 0, y: 0, width: 360, height: 64), viewId: 700,
            messenger: messenger,
            configuration: ["icons": icons, "selected": 2, "labels": ["Today", "Log", "Progress", "Me"],
                            "dark": true, "tint": 0xFF22AA88, "updateDot": true])
        let bar = try XCTUnwrap(platformView.view() as? UITabBar)
        XCTAssertTrue(bar.isUserInteractionEnabled)
        XCTAssertFalse(bar.accessibilityElementsHidden)
        XCTAssertEqual(bar.items?.count, 4)
        for item in try XCTUnwrap(bar.items) {
            XCTAssertEqual(item.image?.size, CGSize(width: 25, height: 25))
            XCTAssertEqual(item.selectedImage?.size, CGSize(width: 25, height: 25))
            XCTAssertEqual(item.image?.renderingMode, .alwaysTemplate)
            XCTAssertEqual(item.selectedImage?.renderingMode, .alwaysTemplate)
        }
        XCTAssertEqual(bar.selectedItem?.tag, 2)
        XCTAssertEqual(bar.items?.first?.title, "Today")
        XCTAssertEqual(bar.items?.last?.badgeValue, "")
        XCTAssertEqual(bar.overrideUserInterfaceStyle, .dark)
        platformView.update(["selected": 1, "labels": ["今日", "记录", "进度", "我的"],
                             "dark": false, "updateDot": false])
        XCTAssertEqual(bar.selectedItem?.tag, 1)
        XCTAssertEqual(bar.items?[1].title, "记录")
        XCTAssertNil(bar.items?.last?.badgeValue)
        XCTAssertEqual(bar.overrideUserInterfaceStyle, .light)
        platformView.tabBar(bar, didSelect: try XCTUnwrap(bar.items?[3]))
        let call = try XCTUnwrap(FlutterStandardMethodCodec.sharedInstance().decodeMethodCall(messenger.sent!))
        XCTAssertEqual(call.method, "select")
        XCTAssertEqual(call.arguments as? Int, 3)
        platformView.update(["selected": 99])
        XCTAssertEqual(bar.selectedItem?.tag, 1)
    }
    @MainActor
    private func dockTestIcons() throws -> [FlutterStandardTypedData] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let iconData = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 75, height: 75), format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 10, y: 10, width: 55, height: 55))
        }.pngData())
        return Array(repeating: FlutterStandardTypedData(bytes: iconData), count: 8)
    }
    @MainActor
    func testNativeDockColdStartAlignsAllTitlesBeforeAnyTap() async throws {
        let messenger = DockTestMessenger()
        let labels = ["今日", "记录", "进度", "我的"]
        // Flutter first creates platform views with a zero frame, then sizes
        // them. Exercise that lifecycle rather than selecting a tab to fix it.
        let platformView = DockGlassPlatformView(
            frame: .zero, viewId: 701, messenger: messenger,
            configuration: ["icons": try dockTestIcons(), "labels": labels, "selected": 0])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        let bar = platformView.tabBar
        controller.view.addSubview(bar)
        bar.frame = CGRect(x: 16, y: 720, width: 360, height: 64)
        window.layoutIfNeeded()
        bar.layoutIfNeeded()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        bar.layoutIfNeeded()
        func titleViews(_ view: UIView) -> [UILabel] {
            let own = (view as? UILabel).map { labels.contains($0.text ?? "") ? [$0] : [] } ?? []
            return own + view.subviews.flatMap { titleViews($0) }
        }
        let titles = titleViews(bar)
        XCTAssertEqual(Set(titles.compactMap(\.text)), Set(labels))
        let baseline = titles.map { $0.convert($0.bounds, to: bar).maxY }
        XCTAssertLessThanOrEqual((baseline.max() ?? 0) - (baseline.min() ?? 0), 1,
                                 "Cold-start titles must align without a selection event: \(baseline)")
        XCTAssertEqual(bar.selectedItem?.tag, 0)
        XCTAssertNil(messenger.sent, "Layout must not trigger navigation or fake a user tap")
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

private final class DockTestMessenger: NSObject, FlutterBinaryMessenger {
    var sent: Data?
    func send(onChannel channel: String, message: Data?) { sent = message }
    func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
        sent = message
    }
    func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection { 1 }
    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
