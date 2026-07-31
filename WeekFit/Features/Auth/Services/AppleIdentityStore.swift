import Foundation
import Security
import OSLog

/// Persists Apple identity fields that Apple only delivers on the first authorization.
/// Survives UserDefaults wipes via Keychain + Application Support mirror + in-process cache.
enum AppleIdentityStore {

    struct Record: Equatable, Sendable {
        var displayName: String?
        var givenName: String?
        var familyName: String?
        var email: String?
    }

    private static let service = "com.weekfit.apple-identity"
    private static let logger = Logger(subsystem: "WeekFit", category: "AppleIdentity")

    /// Survives `UserDefaults.removePersistentDomain` within the same process (same login).
    private static var sessionCache: [String: Record] = [:]

    static func load(appleUserID: String) -> Record? {
        if let cached = sessionCache[appleUserID], hasIdentity(cached) {
            return cached
        }
        if let record = loadFromKeychain(appleUserID: appleUserID) {
            sessionCache[appleUserID] = record
            return record
        }
        if let record = loadFromDisk(appleUserID: appleUserID) {
            sessionCache[appleUserID] = record
            return record
        }
        return nil
    }

    /// Merges non-empty fields from Apple (first auth) without erasing earlier values.
    static func merge(
        appleUserID: String,
        displayName: String?,
        givenName: String? = nil,
        familyName: String? = nil,
        email: String?
    ) {
        var record = load(appleUserID: appleUserID) ?? Record()
        if let displayName = clean(displayName) { record.displayName = displayName }
        if let givenName = clean(givenName) { record.givenName = givenName }
        if let familyName = clean(familyName) { record.familyName = familyName }
        if let email = clean(email) { record.email = email }
        guard hasIdentity(record) else { return }

        sessionCache[appleUserID] = record
        persist(record, appleUserID: appleUserID)
    }

    static func clear(appleUserID: String) {
        sessionCache.removeValue(forKey: appleUserID)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: appleUserID
        ]
        SecItemDelete(query as CFDictionary)
        try? FileManager.default.removeItem(at: diskURL(appleUserID: appleUserID))
    }

    /// Re-applies cached Apple name/email into the local profile (after UserDefaults wipes).
    @MainActor
    static func restoreProfileIfNeeded(appleUserID: String?) {
        guard let appleUserID, let cached = load(appleUserID: appleUserID) else { return }
        let profileService = ProfileService()
        if let display = cached.displayName {
            _ = profileService.applyAppleNameIfEmpty(
                ApplePersonNameParser.ParsedName(
                    givenName: cached.givenName,
                    familyName: cached.familyName,
                    displayName: display
                )
            )
        }
        profileService.applyAppleEmailIfEmpty(cached.email)
        WeekFitUserSettings.shared.refreshFromStorage()
    }

    // MARK: - Persistence

    private static func hasIdentity(_ record: Record) -> Bool {
        record.displayName != nil || record.givenName != nil || record.email != nil
    }

    private static func persist(_ record: Record, appleUserID: String) {
        var payload: [String: String] = [:]
        if let displayName = record.displayName { payload["displayName"] = displayName }
        if let givenName = record.givenName { payload["givenName"] = givenName }
        if let familyName = record.familyName { payload["familyName"] = familyName }
        if let email = record.email { payload["email"] = email }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        writeKeychain(data, account: appleUserID)
        writeDisk(data, appleUserID: appleUserID)
    }

    private static func loadFromKeychain(appleUserID: String) -> Record? {
        guard let data = readKeychain(account: appleUserID) else { return nil }
        return decode(data)
    }

    private static func loadFromDisk(appleUserID: String) -> Record? {
        let url = diskURL(appleUserID: appleUserID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    private static func decode(_ data: Data) -> Record? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        let record = Record(
            displayName: clean(json["displayName"]),
            givenName: clean(json["givenName"]),
            familyName: clean(json["familyName"]),
            email: clean(json["email"])
        )
        return hasIdentity(record) ? record : nil
    }

    private static func readKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func writeKeychain(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Keychain write failed status=\(status)")
        }
    }

    private static func writeDisk(_ data: Data, appleUserID: String) {
        let url = diskURL(appleUserID: appleUserID)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            logger.error("Disk identity write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func diskURL(appleUserID: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("WeekFit/AppleIdentity", isDirectory: true)
        let digest = StableHash.hex(appleUserID)
        return folder.appendingPathComponent("\(digest).json")
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum StableHash {
    static func hex(_ string: String) -> String {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
}
