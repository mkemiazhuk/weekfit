import Foundation

/// Persists quick-log drink/snack usage for Frequently Used + Recent personalization.
enum QuickItemUsageStore {

    static let storageKey = "weekfit_quick_item_usage_v2"
    private static let legacyCountKey = "weekfit_quick_item_usage_v1"

    struct Entry: Codable, Equatable, Sendable {
        var count: Int
        var lastUsedAt: Date

        init(count: Int, lastUsedAt: Date = Date()) {
            self.count = max(0, count)
            self.lastUsedAt = lastUsedAt
        }
    }

    struct Partition: Equatable, Sendable {
        let frequentlyUsed: [QuickItem]
        let recent: [QuickItem]
        let all: [QuickItem]
    }

    static func load() -> [String: Entry] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            return decoded
        }

        // Migrate legacy count-only map.
        let legacy = UserDefaults.standard.dictionary(forKey: legacyCountKey) as? [String: Int] ?? [:]
        guard !legacy.isEmpty else { return [:] }

        let migrated = legacy.reduce(into: [String: Entry]()) { result, pair in
            result[pair.key] = Entry(count: pair.value, lastUsedAt: .distantPast)
        }
        save(migrated)
        return migrated
    }

    static func save(_ entries: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func recordUse(of itemID: String, in entries: inout [String: Entry]) {
        var entry = entries[itemID] ?? Entry(count: 0)
        entry.count += 1
        entry.lastUsedAt = Date()
        entries[itemID] = entry
    }

    static func counts(from entries: [String: Entry]) -> [String: Int] {
        entries.mapValues(\.count)
    }

    /// Recent: distinct drinks logged in the last 7 days, newest first,
    /// excluding Frequent picks. Not an all-time history strip.
    static let recentWindow: TimeInterval = 7 * 24 * 60 * 60
    static let defaultRecentLimit = 6

    static func partition(
        drinks: [QuickItem],
        usage: [String: Entry],
        excludingFromRecent frequentIDs: Set<String> = [],
        recentLimit: Int = defaultRecentLimit,
        now: Date = Date()
    ) -> Partition {
        let drinkByID = Dictionary(uniqueKeysWithValues: drinks.map { ($0.id, $0) })
        let oldestRecent = now.addingTimeInterval(-recentWindow)

        let recentIDs = usage
            .filter {
                $0.value.lastUsedAt > oldestRecent
                    && $0.value.lastUsedAt > .distantPast
                    && drinkByID[$0.key] != nil
                    && !frequentIDs.contains($0.key)
            }
            .sorted { $0.value.lastUsedAt > $1.value.lastUsedAt }
            .prefix(recentLimit)
            .map(\.key)

        let recent = recentIDs.compactMap { drinkByID[$0] }

        let all = drinks.sorted {
            $0.localizedTitle.localizedCaseInsensitiveCompare($1.localizedTitle) == .orderedAscending
        }

        return Partition(
            frequentlyUsed: [],
            recent: recent,
            all: all
        )
    }
}
