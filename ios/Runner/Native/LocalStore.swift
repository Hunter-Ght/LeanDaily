import Foundation
import SQLite3
import Security
import CryptoKit

struct NativeFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

/// All access is serialized by NativeChannel's IO queue. Nothing here uses UserDefaults.
final class LocalStore {
    let root: URL
    private var db: OpaquePointer?
    private let service: String
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(root: URL? = nil, service: String? = nil) throws {
        let fm = FileManager.default
        self.root = root ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LeanDaily", isDirectory: true)
        self.service = service ?? "\(Bundle.main.bundleIdentifier ?? "app.leandaily").credentials.v1"
        try fm.createDirectory(at: self.root, withIntermediateDirectories: true)
        try protect(self.root)
        let marker = self.root.appendingPathComponent(".installation")
        // Keychain survives uninstall. A fresh app sandbox must not resurrect an old API key.
        if !fm.fileExists(atPath: marker.path) {
            try deleteSecret()
            try Data("1".utf8).write(to: marker, options: .atomic)
        }
        if sqlite3_open(self.root.appendingPathComponent("fitness.db").path, &db) != SQLITE_OK {
            if let db = db { sqlite3_close(db) }; db = nil
            throw NativeFailure("无法打开本机数据库")
        }
        do {
            sqlite3_busy_timeout(db, 5000)
            let version = try queryInt("PRAGMA user_version")
            guard version <= 1 else { throw NativeFailure("数据库版本不兼容") }
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA synchronous=FULL")
            try execute("CREATE TABLE IF NOT EXISTS documents (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            try execute("PRAGMA user_version=1")
        } catch { sqlite3_close(db); db = nil; throw error }
    }
    deinit { sqlite3_close(db) }

    private func protect(_ url: URL) throws {
        var value = url
        var resources = URLResourceValues(); resources.isExcludedFromBackup = true
        try value.setResourceValues(resources)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
    }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw NativeFailure("本机数据保存失败，请检查存储空间") }
    }
    private func statement(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else { throw NativeFailure("无法读取本机数据") }
        return stmt
    }
    private func queryInt(_ sql: String) throws -> Int32 {
        let stmt = try statement(sql); defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw NativeFailure("无法读取数据库版本") }
        return sqlite3_column_int(stmt, 0)
    }
    func all() throws -> [String: String] {
        let stmt = try statement("SELECT key,value FROM documents"); defer { sqlite3_finalize(stmt) }
        var out: [String: String] = [:]
        var status = sqlite3_step(stmt)
        while status == SQLITE_ROW {
            guard let key = sqlite3_column_text(stmt, 0), let value = sqlite3_column_text(stmt, 1) else { throw NativeFailure("本机记录损坏") }
            out[String(cString: key)] = String(cString: value)
            status = sqlite3_step(stmt)
        }
        guard status == SQLITE_DONE else { throw NativeFailure("无法读取本机数据") }
        return out
    }
    func put(_ key: String, _ value: String) throws {
        guard !key.contains("\0"), !value.contains("\0") else { throw NativeFailure("保存内容无效") }
        let stmt = try statement("INSERT OR REPLACE INTO documents(key,value) VALUES (?,?)")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_bind_text(stmt, 1, key, -1, transient) == SQLITE_OK,
              sqlite3_bind_text(stmt, 2, value, -1, transient) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_DONE else { throw NativeFailure("本机数据保存失败，请检查存储空间") }
    }
    private var keyQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "modelKey", kSecAttrSynchronizable as String: false]
    }
    private func deleteSecret() throws {
        let status = SecItemDelete(keyQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw NativeFailure("无法清除本机密钥") }
    }
    func secrets() throws -> [String: String] {
        var query = keyQuery
        query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return ["modelKey": ""] }
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else { throw NativeFailure("无法读取本机密钥，请解锁设备后重试") }
        return ["modelKey": value]
    }
    func setSecrets(_ value: String) throws {
        if value.isEmpty { try deleteSecret(); return }
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(keyQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(keyQuery.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw NativeFailure("无法保存本机密钥，请解锁设备后重试") }
    }
    private func photoURL(_ path: String) throws -> URL {
        let directory = root.appendingPathComponent("photos", isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        let url = (path.hasPrefix("/") ? URL(fileURLWithPath: path) : root.appendingPathComponent(path))
            .standardizedFileURL.resolvingSymlinksInPath()
        guard url.deletingLastPathComponent() == directory,
              UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil,
              url.pathExtension == "jpg" else { throw NativeFailure("照片路径无效") }
        return url
    }
    func photoWrite(_ bytes: Data) throws -> String {
        guard bytes.count >= 3, bytes.count <= 12 * 1024 * 1024,
              bytes[0] == 255, bytes[1] == 216 else { throw NativeFailure("仅支持有效 JPEG 照片（最多12MB）") }
        let directory = root.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try protect(directory)
        // Relative paths survive iOS application-container relocation during updates.
        let path = "photos/\(UUID().uuidString.lowercased()).jpg"
        let url = try photoURL(path)
        try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try protect(url)
        return path
    }
    func photoRead(_ path: String) throws -> (Data, String) {
        let url = try photoURL(path)
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let bytes = try handle.read(upToCount: 12 * 1024 * 1024 + 1) ?? Data()
        guard bytes.count <= 12 * 1024 * 1024 else { throw NativeFailure("照片超过12MB") }
        return (bytes, SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
    }
}
