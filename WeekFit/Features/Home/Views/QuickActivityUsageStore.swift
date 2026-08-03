import Foundation

/// Usage history for Activity Start sheet options (keyed by imageName).
enum QuickActivityUsageStore {

    static let storageKey = "weekfit_activity_option_usage_v1"

    struct Entry: Codable, Equatable, Sendable {
        var count: Int
        var lastUsedAt: Date

        init(count: Int, lastUsedAt: Date = Date()) {
            self.count = max(0, count)
            self.lastUsedAt = lastUsedAt
        }
    }

    struct Pick: Equatable, Sendable {
        let option: PlannerOption
        let isMostUsed: Bool
    }

    static func load() -> [String: Entry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func save(_ entries: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func record(imageName: String) {
        guard !imageName.isEmpty else { return }
        var entries = load()
        var entry = entries[imageName] ?? Entry(count: 0)
        entry.count += 1
        entry.lastUsedAt = Date()
        entries[imageName] = entry
        save(entries)
    }

    static func frequentPicks(
        options: [PlannerOption],
        usage: [String: Entry],
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 2
    ) -> [Pick] {
        guard !options.isEmpty else { return [] }
        let byImage = Dictionary(uniqueKeysWithValues: options.map { ($0.imageName, $0) })
        var picks: [Pick] = []
        var used = Set<String>()

        let rankedUsage = usage
            .filter { $0.value.count >= 1 && byImage[$0.key] != nil }
            .sorted { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    return lhs.value.lastUsedAt > rhs.value.lastUsedAt
                }
                return lhs.value.count > rhs.value.count
            }

        if let most = rankedUsage.first,
           let option = byImage[most.key] {
            picks.append(Pick(option: option, isMostUsed: true))
            used.insert(option.imageName)
        }

        let hour = calendar.component(.hour, from: now)
        let preferred = preferredImageNames(for: options, hour: hour)
        if let option = preferred.first(where: { !used.contains($0.imageName) }) {
            picks.append(Pick(option: option, isMostUsed: false))
            used.insert(option.imageName)
        }

        if picks.isEmpty {
            picks = options.prefix(limit).map { Pick(option: $0, isMostUsed: false) }
        }

        return Array(picks.prefix(limit))
    }

    static func recentOptions(
        options: [PlannerOption],
        usage: [String: Entry],
        excluding: Set<String>,
        limit: Int = 6
    ) -> [PlannerOption] {
        let byImage = Dictionary(uniqueKeysWithValues: options.map { ($0.imageName, $0) })
        return usage
            .filter {
                $0.value.lastUsedAt > .distantPast
                    && byImage[$0.key] != nil
                    && !excluding.contains($0.key)
            }
            .sorted { $0.value.lastUsedAt > $1.value.lastUsedAt }
            .prefix(limit)
            .compactMap { byImage[$0.key] }
    }

    private static func preferredImageNames(for options: [PlannerOption], hour: Int) -> [PlannerOption] {
        let preferredKeys: [String]
        switch hour {
        case 5..<10:
            // Morning — mobility / easy cardio first.
            preferredKeys = ["recovery-walk", "recovery-stretch", "workout-running", "recovery-yoga", "workout-cycling"]
        case 10..<14:
            preferredKeys = ["workout-strength", "workout-running", "workout-cycling", "workout-hiit", "recovery-walk"]
        case 14..<18:
            preferredKeys = ["workout-hiit", "workout-fullbody", "workout-tennis", "workout-running", "recovery-walk"]
        case 18..<22:
            preferredKeys = ["recovery-yoga", "recovery-stretch", "recovery-walk", "recovery-sauna", "recovery-breathing"]
        default:
            preferredKeys = ["recovery-breathing", "recovery-stretch", "recovery-yoga", "recovery-walk"]
        }

        return preferredKeys.compactMap { key in options.first(where: { $0.imageName == key }) }
    }
}
