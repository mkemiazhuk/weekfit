import Foundation

/// Persists the last Today coach card for stale-while-revalidate on cold start.
enum CoachTodayInsightCache {

    struct Snapshot: Codable, Equatable, Sendable {
        let dayStart: Int
        let languageCode: String
        let scenario: String
        let todayTitle: String
        let todayMessage: String
        let recommendation: String
        let icon: String
        let semanticColor: String
        let showsLimitedConfidenceBadge: Bool
    }

    private static let storageKey = "coach_today_insight_cache_v1"
    private static let lock = NSLock()

    static func load() -> Snapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    static func store(
        presentation: CoachUIPresentation,
        dayStart: Date,
        languageCode: String,
        calendar: Calendar = .current
    ) {
        let snapshot = Snapshot(
            dayStart: dayKey(for: dayStart, calendar: calendar),
            languageCode: languageCode,
            scenario: presentation.scenario.rawValue,
            todayTitle: presentation.todayTitle,
            todayMessage: presentation.todayMessage,
            recommendation: presentation.recommendation,
            icon: presentation.icon,
            semanticColor: presentation.semanticColor.rawValue,
            showsLimitedConfidenceBadge: presentation.showsLimitedConfidenceBadge
        )

        lock.lock()
        defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func presentation(
        for dayStart: Date,
        languageCode: String,
        calendar: Calendar = .current
    ) -> CoachUIPresentation? {
        guard let snapshot = load(),
              snapshot.dayStart == dayKey(for: dayStart, calendar: calendar),
              snapshot.languageCode == languageCode,
              let scenario = CoachScenarioKey(rawValue: snapshot.scenario),
              let semanticColor = CoachSemanticColor(rawValue: snapshot.semanticColor) else {
            return nil
        }

        return CoachUIPresentation(
            scenario: scenario,
            assessment: snapshot.recommendation,
            recommendation: snapshot.recommendation,
            avoid: "",
            nextAction: snapshot.recommendation,
            supportingSignals: [],
            warningMessage: nil,
            warningAlert: nil,
            semanticColor: semanticColor,
            alertSeverity: .none,
            icon: snapshot.icon,
            urgencyLevel: .calm,
            statusLabel: snapshot.todayTitle,
            coachTitle: snapshot.todayTitle,
            todayTitle: snapshot.todayTitle,
            todayMessage: snapshot.todayMessage,
            whyRows: [],
            showsLimitedConfidenceBadge: snapshot.showsLimitedConfidenceBadge
        )
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSince1970 / 86_400)
    }

    #if DEBUG
    static func resetForTests() {
        lock.lock()
        defer { lock.unlock() }
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    #endif
}
