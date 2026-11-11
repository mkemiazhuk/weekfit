import Foundation

enum ActivityAwardUnit: String, Equatable, Codable {
    case sessions
    case days
    case minutes
    case milliliters
    case kilometers
    case kilocalories
}

enum ActivityAwardKind: String, Equatable {
    case first
    case accumulation
    case streak
    case personalRecord
}

struct ActivityAwardFacts: Equatable {
    var completions: Int = 0
    var tierEarnedAt: [Int: Date] = [:]
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var bestStreakStart: Date?
    var bestStreakEnd: Date?
    var recordValue: Int?
    var recordDate: Date?
    var recordUnit: ActivityAwardUnit?
    var firstMeasured: Int?
    /// First time a walk or ride reached each kilometer tier.
    var distanceTiers: [Int: Date] = [:]
    /// How many measured sessions reached each kilometer tier.
    var distanceCounts: [Int: Int] = [:]
}

struct ActivityAwardState: Equatable {
    var kind: ActivityAwardKind = .first
    var current: Int = 0
    var goal: Int? = 1
    var best: Int?
    var unit: ActivityAwardUnit = .sessions
    var rangeStart: Date?
    var rangeEnd: Date?
}

struct ActivityBadgeInput: Equatable {
    var recordID: String
    var title: String
    var type: String
    var imageName: String
    var isCompleted: Bool
    var isSkipped: Bool
    var startedAt: Date
    var durationMinutes: Int
    var actualDurationMinutes: Int?
    var source: String
    var waterMilliliters: Int
    var distanceMeters: Int? = nil
    var activeKilocalories: Int? = nil
    var icon: String = ""
}

struct ActivityAwardSource: Equatable, Identifiable {
    var id: String { recordID }
    var recordID: String
    var title: String
    var icon: String
    var startedAt: Date
    var durationMinutes: Int
    var kilocalories: Int?
    var distanceMeters: Int?
    var waterMilliliters: Int
}

struct ActivityStoredAward: Equatable, Codable {
    var earnedAt: Date
    var value: Int
    var rangeStart: Date?
    var rangeEnd: Date?
}

struct ActivityBadgeLedger: Equatable, Codable {
    var unlocks: [String: Date] = [:]
    var customNames: [String: String] = [:]
    var customIDsByTitle: [String: String] = [:]
    var disqualifiedRecordIDs: [String] = []
    var justFinishedRecordIDs: [String] = []
    var backfilledAt: Date?
    var pendingUnlockID: String?
    var suggestedBadgeID: String?
    var lastInviteAt: Date?
    var scheduledFireAt: Date?
    var waterGoalMilliliters: Int = 0
    /// Earned totals, streaks, and records. Never removed and never lowered.
    var storedAwards: [String: ActivityStoredAward] = [:]

    enum CodingKeys: String, CodingKey {
        case unlocks, customNames, customIDsByTitle, disqualifiedRecordIDs, justFinishedRecordIDs
        case backfilledAt, pendingUnlockID, suggestedBadgeID, lastInviteAt, scheduledFireAt
        case waterGoalMilliliters, storedAwards
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unlocks = try container.decodeIfPresent([String: Date].self, forKey: .unlocks) ?? [:]
        customNames = try container.decodeIfPresent([String: String].self, forKey: .customNames) ?? [:]
        customIDsByTitle = try container.decodeIfPresent([String: String].self, forKey: .customIDsByTitle) ?? [:]
        disqualifiedRecordIDs = try container.decodeIfPresent([String].self, forKey: .disqualifiedRecordIDs) ?? []
        justFinishedRecordIDs = try container.decodeIfPresent([String].self, forKey: .justFinishedRecordIDs) ?? []
        backfilledAt = try container.decodeIfPresent(Date.self, forKey: .backfilledAt)
        pendingUnlockID = try container.decodeIfPresent(String.self, forKey: .pendingUnlockID)
        suggestedBadgeID = try container.decodeIfPresent(String.self, forKey: .suggestedBadgeID)
        lastInviteAt = try container.decodeIfPresent(Date.self, forKey: .lastInviteAt)
        scheduledFireAt = try container.decodeIfPresent(Date.self, forKey: .scheduledFireAt)
        waterGoalMilliliters = try container.decodeIfPresent(Int.self, forKey: .waterGoalMilliliters) ?? 0
        storedAwards = try container.decodeIfPresent([String: ActivityStoredAward].self, forKey: .storedAwards) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(unlocks, forKey: .unlocks)
        try container.encode(customNames, forKey: .customNames)
        try container.encode(customIDsByTitle, forKey: .customIDsByTitle)
        try container.encode(disqualifiedRecordIDs, forKey: .disqualifiedRecordIDs)
        try container.encode(justFinishedRecordIDs, forKey: .justFinishedRecordIDs)
        try container.encodeIfPresent(backfilledAt, forKey: .backfilledAt)
        try container.encodeIfPresent(pendingUnlockID, forKey: .pendingUnlockID)
        try container.encodeIfPresent(suggestedBadgeID, forKey: .suggestedBadgeID)
        try container.encodeIfPresent(lastInviteAt, forKey: .lastInviteAt)
        try container.encodeIfPresent(scheduledFireAt, forKey: .scheduledFireAt)
        try container.encode(waterGoalMilliliters, forKey: .waterGoalMilliliters)
        try container.encode(storedAwards, forKey: .storedAwards)
    }
}

enum ActivityBadgeEngine {
    static let customPrefix = "habit.custom."

    static func ingest(
        _ inputs: [ActivityBadgeInput],
        waterGoalMilliliters: Int,
        now: Date,
        into ledger: inout ActivityBadgeLedger,
        makeCustomID: () -> String = { UUID().uuidString },
        calendar: Calendar = .current
    ) {
        let firstScan = ledger.backfilledAt == nil
        if firstScan {
            ledger.backfilledAt = now
        }
        if waterGoalMilliliters > 0 {
            ledger.waterGoalMilliliters = waterGoalMilliliters
        }
        let disqualified = Set(ledger.disqualifiedRecordIDs)
        let justFinished = Set(ledger.justFinishedRecordIDs)
        var fresh: [String] = []

        registerCustomHabits(inputs, into: &ledger, makeCustomID: makeCustomID)

        for input in inputs where qualifies(input, disqualified: disqualified, ledger: ledger) {
            guard let id = badgeID(for: input, ledger: ledger) else { continue }
            let completedAt = completionDate(input, justFinished: justFinished, now: now)
            if let existing = ledger.unlocks[id] {
                if completedAt < existing {
                    ledger.unlocks[id] = completedAt
                }
                continue
            }
            ledger.unlocks[id] = completedAt
            fresh.append(id)
            let announce = !firstScan && (justFinished.contains(input.recordID) || completedAt >= (ledger.backfilledAt ?? now))
            if announce {
                ledger.pendingUnlockID = id
            }
        }

        if ledger.waterGoalMilliliters > 0, let water = firstWaterGoalCrossing(inputs, goal: ledger.waterGoalMilliliters) {
            let id = "habit.drink-water"
            if ledger.unlocks[id] == nil {
                ledger.unlocks[id] = water.at
                fresh.append(id)
                let announce = !firstScan && (justFinished.contains(water.recordID) || water.at >= (ledger.backfilledAt ?? now))
                if announce {
                    ledger.pendingUnlockID = id
                }
            } else if water.at < ledger.unlocks[id]! {
                ledger.unlocks[id] = water.at
            }
        }

        raiseStoredAwards(
            inputs: inputs,
            now: now,
            calendar: calendar,
            into: &ledger
        )
        ledger.justFinishedRecordIDs = []
        if firstScan {
            ledger.pendingUnlockID = nil
        }
        _ = fresh
    }

    static func renameCustomHabit(from oldTitle: String, to newTitle: String, ledger: inout ActivityBadgeLedger) {
        let oldKey = ActivityBadgeCatalog.normalize(oldTitle)
        let newKey = ActivityBadgeCatalog.normalize(newTitle)
        guard oldKey != newKey else { return }
        guard ActivityBadgeCatalog.definition(catalogTitle: oldTitle) == nil else { return }
        guard let id = ledger.customIDsByTitle[oldKey] else { return }
        ledger.customIDsByTitle[oldKey] = nil
        ledger.customIDsByTitle[newKey] = id
        ledger.customNames[id] = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func suggestionID(
        ledger: ActivityBadgeLedger,
        inputs: [ActivityBadgeInput],
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        let configured = configuredHabitIDs(inputs, ledger: ledger, now: now, calendar: calendar)
        var order = ["recovery.breathing", "recovery.walk"]
        order.append(contentsOf: configured)
        order.append("habit.drink-water")
        for id in order where ledger.unlocks[id] == nil {
            if ActivityBadgeCatalog.definition(id: id)?.requirement == .habitCheckIn || id.hasPrefix(customPrefix) {
                guard configured.contains(id) else { continue }
            }
            return id
        }
        return nil
    }

    static func isStepCounter(_ source: String) -> Bool {
        switch source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "steps", "stepcount", "step_count", "dailysteps", "step-count":
            return true
        default:
            return false
        }
    }

    private static func qualifies(
        _ input: ActivityBadgeInput,
        disqualified: Set<String>,
        ledger: ActivityBadgeLedger
    ) -> Bool {
        guard input.isCompleted, !input.isSkipped else { return false }
        guard !isStepCounter(input.source) else { return false }
        guard let id = badgeID(for: input, ledger: ledger),
              let requirement = requirement(for: id, ledger: ledger) else { return false }
        switch requirement {
        case .waterGoal:
            return false
        case .breathingMinute:
            guard !disqualified.contains(input.recordID) else { return false }
            if let actual = input.actualDurationMinutes {
                return actual >= 1
            }
            return input.durationMinutes >= 1
        case .completedSession, .habitCheckIn:
            return true
        }
    }

    private static func requirement(for id: String, ledger: ActivityBadgeLedger) -> ActivityBadgeRequirement? {
        if let definition = ActivityBadgeCatalog.definition(id: id) {
            return definition.requirement
        }
        if ledger.customNames[id] != nil || id.hasPrefix(customPrefix) {
            return .habitCheckIn
        }
        return nil
    }

    private static func badgeID(for input: ActivityBadgeInput, ledger: ActivityBadgeLedger) -> String? {
        if let title = ActivityBadgeCatalog.canonicalCatalogTitle(input.title),
           let definition = ActivityBadgeCatalog.definition(catalogTitle: title) {
            return definition.id
        }
        guard isHabit(input) else { return nil }
        let key = ActivityBadgeCatalog.normalize(input.title)
        return ledger.customIDsByTitle[key]
    }

    private static func isHabit(_ input: ActivityBadgeInput) -> Bool {
        let type = input.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let image = input.imageName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if type == "habit" || image.hasPrefix("habit-") { return true }
        return ActivityBadgeCatalog.definition(catalogTitle: input.title)?.category == .habit
    }

    private static func registerCustomHabits(
        _ inputs: [ActivityBadgeInput],
        into ledger: inout ActivityBadgeLedger,
        makeCustomID: () -> String
    ) {
        for input in inputs {
            guard isHabit(input) else { continue }
            guard ActivityBadgeCatalog.canonicalCatalogTitle(input.title) == nil else { continue }
            let name = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = ActivityBadgeCatalog.normalize(name)
            if ledger.customIDsByTitle[key] == nil {
                let id = customPrefix + makeCustomID()
                ledger.customIDsByTitle[key] = id
                ledger.customNames[id] = name
            } else if let id = ledger.customIDsByTitle[key] {
                ledger.customNames[id] = name
            }
        }
    }

    private static func completionDate(
        _ input: ActivityBadgeInput,
        justFinished: Set<String>,
        now: Date
    ) -> Date {
        if justFinished.contains(input.recordID) { return now }
        let minutes = input.actualDurationMinutes ?? input.durationMinutes
        return input.startedAt.addingTimeInterval(TimeInterval(max(minutes, 0) * 60))
    }

    private struct WaterCrossing {
        var at: Date
        var recordID: String
    }

    private static func firstWaterGoalCrossing(_ inputs: [ActivityBadgeInput], goal: Int) -> WaterCrossing? {
        let logs = inputs
            .filter { $0.isCompleted && !$0.isSkipped && $0.waterMilliliters > 0 }
            .sorted { $0.startedAt < $1.startedAt }
        let calendar = Calendar.current
        var totals: [Date: Int] = [:]
        var crossed: [Date: WaterCrossing] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.startedAt)
            let next = totals[day, default: 0] + log.waterMilliliters
            totals[day] = next
            if next >= goal, crossed[day] == nil {
                crossed[day] = WaterCrossing(at: log.startedAt, recordID: log.recordID)
            }
        }
        return crossed.values.min { $0.at < $1.at }
    }

    private static func configuredHabitIDs(
        _ inputs: [ActivityBadgeInput],
        ledger: ActivityBadgeLedger,
        now: Date,
        calendar: Calendar
    ) -> [String] {
        inputs.compactMap { input in
            guard !input.isCompleted, !input.isSkipped else { return nil }
            guard calendar.isDate(input.startedAt, inSameDayAs: now) else { return nil }
            guard let id = badgeID(for: input, ledger: ledger) else { return nil }
            guard requirement(for: id, ledger: ledger) == .habitCheckIn else { return nil }
            return id
        }
    }

    static let awardTiers = [5, 10, 25, 50]
    static let distanceAwardIDs: Set<String> = ["recovery.walk", "activity.cycling"]
    static let distanceRecordIDs: Set<String> = ["recovery.walk", "activity.running", "activity.cycling"]
    static let distanceTiersKm = [1, 2, 3, 5]

    static func distanceTiers(for id: String) -> [Int] {
        switch id {
        case "activity.cycling": return [1, 2, 3, 5, 25, 50]
        case "recovery.walk": return distanceTiersKm
        default: return []
        }
    }

    /// One session belongs to one distance badge: the highest tier it reaches.
    /// A 5 km walk is only 5 km. Under 1 km belongs to none of these badges.
    static func distanceBand(meters: Int, tiers: [Int]) -> Int? {
        guard meters > 0 else { return nil }
        let kilometers = Double(meters) / 1000
        let sorted = tiers.sorted()
        for (index, tier) in sorted.enumerated() {
            guard kilometers + 0.000_001 >= Double(tier) else { return nil }
            let upper = index + 1 < sorted.count ? Double(sorted[index + 1]) : Double.infinity
            if kilometers < upper { return tier }
        }
        return nil
    }
    static let calorieTiers = [300, 500, 1000, 2000, 3000]
    static let streakLengthGoal = 2

    static func calorieAwardID(_ tier: Int) -> String { "energy.kcal.\(tier)" }

    static func awardBaseID(_ awardID: String) -> String {
        if let range = awardID.range(of: ".count.") {
            return String(awardID[..<range.lowerBound])
        }
        if let range = awardID.range(of: ".km.") {
            return String(awardID[..<range.lowerBound])
        }
        if awardID.hasSuffix(".streak") {
            return String(awardID.dropLast(".streak".count))
        }
        if awardID.hasSuffix(".record") {
            return String(awardID.dropLast(".record".count))
        }
        return awardID
    }

    /// The session that earned this award. Later sessions that only repeat it are left out.
    static func earningInput(
        for awardID: String,
        inputs: [ActivityBadgeInput],
        ledger: ActivityBadgeLedger,
        now: Date,
        calendar: Calendar = .current
    ) -> ActivityBadgeInput? {
        if awardID.hasPrefix("energy.kcal.") {
            let tier = Int(awardID.dropFirst("energy.kcal.".count)) ?? 0
            guard tier > 0 else { return nil }
            let earned = calorieTierDates(inputs: inputs, ledger: ledger, now: now, calendar: calendar)
            guard let date = earned[tier] else { return nil }
            return pinned(
                calorieEvents(inputs: inputs, ledger: ledger, now: now),
                to: ledger.storedAwards[awardID]?.earnedAt ?? date,
                now: now,
                calendar: calendar
            )
        }
        if awardID == "habit.drink-water" {
            guard ledger.waterGoalMilliliters > 0,
                  let crossing = firstWaterGoalCrossing(inputs, goal: ledger.waterGoalMilliliters) else { return nil }
            return inputs.first { $0.recordID == crossing.recordID }
        }
        if awardID == "habit.drink-water.record" {
            let facts = waterFacts(inputs, goal: ledger.waterGoalMilliliters, now: now, calendar: calendar)
            guard let day = facts.recordDate else { return nil }
            return inputs
                .filter {
                    $0.isCompleted && !$0.isSkipped && $0.waterMilliliters > 0
                        && calendar.isDate($0.startedAt, inSameDayAs: day)
                }
                .max { $0.startedAt < $1.startedAt }
        }
        let base = awardBaseID(awardID)
        let events = qualifyingEvents(for: base, inputs: inputs, ledger: ledger, now: now)
        if awardID == base {
            return pinned(events, to: ledger.unlocks[awardID], now: now, calendar: calendar)
        }
        if let range = awardID.range(of: ".km."), let tier = Int(awardID[range.upperBound...]) {
            let tiers = distanceTiers(for: base)
            let hits = events.filter { distanceBand(meters: $0.distanceMeters ?? 0, tiers: tiers) == tier }
            return pinned(hits, to: ledger.storedAwards[awardID]?.earnedAt, now: now, calendar: calendar)
        }
        if let range = awardID.range(of: ".count."), let tier = Int(awardID[range.upperBound...]), events.count >= tier {
            return events[tier - 1]
        }
        if awardID.hasSuffix(".streak") {
            let end = ledger.storedAwards[awardID]?.rangeEnd
                ?? awardFacts(for: base, inputs: inputs, ledger: ledger, now: now, calendar: calendar).bestStreakEnd
            return pinned(events, to: end, now: now, calendar: calendar)
        }
        if awardID.hasSuffix(".record") {
            let measured = events.filter { ($0.actualDurationMinutes ?? 0) > 0 }
            let date = ledger.storedAwards[awardID]?.rangeEnd ?? ledger.storedAwards[awardID]?.earnedAt
            return pinned(measured, to: date, now: now, calendar: calendar)
        }
        return nil
    }

    /// Award plates to show on the activity that earned them. At most three, highest tier only.
    static func plaques(
        ledger: ActivityBadgeLedger,
        inputs: [ActivityBadgeInput],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [String: [String]] {
        var ids = Set(ledger.unlocks.keys)
        ids.formUnion(ledger.storedAwards.keys)
        var byRecord: [String: [String]] = [:]
        for id in ids {
            guard let art = ActivityBadgeArt.asset(for: id) else { continue }
            let base = awardBaseID(id)
            if id != base, ActivityBadgeArt.asset(for: base) == art { continue }
            guard let input = earningInput(for: id, inputs: inputs, ledger: ledger, now: now, calendar: calendar) else { continue }
            byRecord[input.recordID, default: []].append(id)
        }
        return byRecord.mapValues(headlinePlaques)
    }

    private static func headlinePlaques(_ ids: [String]) -> [String] {
        func tier(_ id: String, marker: String) -> Int {
            guard let range = id.range(of: marker), let value = Int(id[range.upperBound...]) else { return -1 }
            return value
        }
        func maxID(_ marker: String) -> String? {
            ids.filter { tier($0, marker: marker) >= 0 }.max { tier($0, marker: marker) < tier($1, marker: marker) }
        }
        var result: [String] = []
        result.append(contentsOf: ids.filter { awardBaseID($0) == $0 && !$0.hasPrefix("energy.kcal.") }.sorted())
        if let km = maxID(".km.") { result.append(km) }
        if let kcal = maxID(".kcal.") { result.append(kcal) }
        if let record = ids.first(where: { $0.hasSuffix(".record") }) { result.append(record) }
        if let count = maxID(".count.") { result.append(count) }
        if let streak = ids.first(where: { $0.hasSuffix(".streak") }) { result.append(streak) }
        var seen = Set<String>()
        return result.filter { seen.insert($0).inserted }.prefix(3).map { $0 }
    }

    private static func qualifyingEvents(
        for id: String,
        inputs: [ActivityBadgeInput],
        ledger: ActivityBadgeLedger,
        now: Date
    ) -> [ActivityBadgeInput] {
        let disqualified = Set(ledger.disqualifiedRecordIDs)
        return inputs
            .filter { qualifies($0, disqualified: disqualified, ledger: ledger) && badgeID(for: $0, ledger: ledger) == id }
            .sorted { completionDate($0, justFinished: [], now: now) < completionDate($1, justFinished: [], now: now) }
    }

    private static func calorieEvents(
        inputs: [ActivityBadgeInput],
        ledger: ActivityBadgeLedger,
        now: Date
    ) -> [ActivityBadgeInput] {
        let disqualified = Set(ledger.disqualifiedRecordIDs)
        return inputs
            .filter { countsTowardCalorieAward($0, disqualified: disqualified) }
            .sorted { completionDate($0, justFinished: [], now: now) < completionDate($1, justFinished: [], now: now) }
    }

    /// Any finished workout or recovery counts, including one with no activity badge of its own.
    private static func countsTowardCalorieAward(
        _ input: ActivityBadgeInput,
        disqualified: Set<String>
    ) -> Bool {
        guard input.isCompleted, !input.isSkipped, !disqualified.contains(input.recordID) else { return false }
        guard !isStepCounter(input.source) else { return false }
        let type = input.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if type == "meal" || type == "habit" { return false }
        return (input.activeKilocalories ?? 0) > 0
    }

    private static func pinned(
        _ events: [ActivityBadgeInput],
        to date: Date?,
        now: Date,
        calendar: Calendar
    ) -> ActivityBadgeInput? {
        guard !events.isEmpty else { return nil }
        guard let date else { return events.first }
        let stamped = events.map { ($0, completionDate($0, justFinished: [], now: now)) }
        let sameDay = stamped.filter { calendar.isDate($0.1, inSameDayAs: date) }
        if let match = sameDay.min(by: { abs($0.1.timeIntervalSince(date)) < abs($1.1.timeIntervalSince(date)) }) {
            return match.0
        }
        guard let nearest = stamped.min(by: { abs($0.1.timeIntervalSince(date)) < abs($1.1.timeIntervalSince(date)) }),
              abs(nearest.1.timeIntervalSince(date)) <= 36 * 3_600 else { return nil }
        return nearest.0
    }

    static func awardFacts(
        for id: String,
        inputs: [ActivityBadgeInput],
        ledger: ActivityBadgeLedger,
        now: Date,
        calendar: Calendar = .current
    ) -> ActivityAwardFacts {
        if id == "habit.drink-water" {
            return waterFacts(inputs, goal: ledger.waterGoalMilliliters, now: now, calendar: calendar)
        }
        let disqualified = Set(ledger.disqualifiedRecordIDs)
        let events = inputs
            .filter { qualifies($0, disqualified: disqualified, ledger: ledger) && badgeID(for: $0, ledger: ledger) == id }
            .sorted { completionDate($0, justFinished: [], now: now) < completionDate($1, justFinished: [], now: now) }
        let dates = events.map { completionDate($0, justFinished: [], now: now) }
        let days = dates.map { calendar.startOfDay(for: $0) }
        let streak = streakStats(days: days, now: now, calendar: calendar)
        let measured = events.compactMap { event -> (date: Date, minutes: Int)? in
            guard let minutes = event.actualDurationMinutes, minutes > 0 else { return nil }
            return (completionDate(event, justFinished: [], now: now), minutes)
        }
        let best = measured.max { lhs, rhs in
            if lhs.minutes == rhs.minutes { return lhs.date > rhs.date }
            return lhs.minutes < rhs.minutes
        }
        let firstMeasured = events.first.flatMap { $0.actualDurationMinutes }.flatMap { $0 > 0 ? $0 : nil }
        var tiers: [Int: Date] = [:]
        if !distanceAwardIDs.contains(id) {
            for tier in awardTiers where dates.count >= tier {
                tiers[tier] = dates[tier - 1]
            }
        }
        var distanceDates: [Int: Date] = [:]
        var distanceCounts: [Int: Int] = [:]
        if distanceAwardIDs.contains(id) {
            let bands = distanceTiers(for: id)
            for tier in bands {
                let hits = events.filter { distanceBand(meters: $0.distanceMeters ?? 0, tiers: bands) == tier }
                distanceCounts[tier] = hits.count
                if let first = hits.first {
                    distanceDates[tier] = completionDate(first, justFinished: [], now: now)
                }
            }
        }
        let longestDistance = events.compactMap { event -> (date: Date, meters: Int)? in
            guard let meters = event.distanceMeters, meters > 0 else { return nil }
            return (completionDate(event, justFinished: [], now: now), meters)
        }.max { lhs, rhs in
            if lhs.meters == rhs.meters { return lhs.date > rhs.date }
            return lhs.meters < rhs.meters
        }
        let unit = recordUnit(for: id, ledger: ledger)
        let recordValue: Int?
        let recordDate: Date?
        if distanceRecordIDs.contains(id) {
            recordValue = longestDistance?.meters
            recordDate = longestDistance?.date
        } else {
            switch unit {
            case .minutes:
                recordValue = best?.minutes
                recordDate = best?.date
            default:
                recordValue = nil
                recordDate = nil
            }
        }
        return ActivityAwardFacts(
            completions: dates.count,
            tierEarnedAt: tiers,
            currentStreak: streak.current,
            bestStreak: streak.best,
            bestStreakStart: streak.start,
            bestStreakEnd: streak.end,
            recordValue: recordValue,
            recordDate: recordDate,
            recordUnit: distanceRecordIDs.contains(id) ? .kilometers : unit,
            firstMeasured: firstMeasured,
            distanceTiers: distanceDates,
            distanceCounts: distanceCounts
        )
    }

    private static func raiseStoredAwards(
        inputs: [ActivityBadgeInput],
        now: Date,
        calendar: Calendar,
        into ledger: inout ActivityBadgeLedger
    ) {
        var ids = Set(ActivityBadgeCatalog.definitions.map(\.id))
        ids.formUnion(ledger.customNames.keys)
        for id in ids {
            let facts = awardFacts(for: id, inputs: inputs, ledger: ledger, now: now, calendar: calendar)
            if distanceAwardIDs.contains(id) {
                let tiers = distanceTiers(for: id)
                for tier in tiers {
                    guard let reached = facts.distanceTiers[tier] else { continue }
                    let key = "\(id).km.\(tier)"
                    let count = facts.distanceCounts[tier] ?? 0
                    guard count > 0 else { continue }
                    if var existing = ledger.storedAwards[key] {
                        if reached < existing.earnedAt {
                            existing.earnedAt = reached
                        }
                        existing.value = count
                        ledger.storedAwards[key] = existing
                    } else {
                        ledger.storedAwards[key] = ActivityStoredAward(earnedAt: reached, value: count)
                    }
                }
            }
            for tier in awardTiers where !distanceAwardIDs.contains(id) {
                guard let reached = facts.tierEarnedAt[tier] else { continue }
                let key = "\(id).count.\(tier)"
                if var existing = ledger.storedAwards[key] {
                    if reached < existing.earnedAt {
                        existing.earnedAt = reached
                        ledger.storedAwards[key] = existing
                    }
                } else {
                    ledger.storedAwards[key] = ActivityStoredAward(earnedAt: reached, value: tier)
                }
            }
            if facts.bestStreak >= streakLengthGoal, let end = facts.bestStreakEnd {
                let key = "\(id).streak"
                if var existing = ledger.storedAwards[key] {
                    if facts.bestStreak > existing.value {
                        existing.value = facts.bestStreak
                        existing.rangeStart = facts.bestStreakStart
                        existing.rangeEnd = end
                        ledger.storedAwards[key] = existing
                    }
                } else {
                    ledger.storedAwards[key] = ActivityStoredAward(
                        earnedAt: end,
                        value: facts.bestStreak,
                        rangeStart: facts.bestStreakStart,
                        rangeEnd: end
                    )
                }
            }
            if keepsPersonalRecord(id) {
                if facts.recordUnit != nil, let value = facts.recordValue, value > 0, let date = facts.recordDate {
                    let key = "\(id).record"
                    let replaces = distanceRecordIDs.contains(id)
                    if var existing = ledger.storedAwards[key] {
                        if replaces || value > existing.value {
                            existing.value = value
                            existing.earnedAt = date
                            existing.rangeEnd = date
                            ledger.storedAwards[key] = existing
                        }
                    } else {
                        ledger.storedAwards[key] = ActivityStoredAward(earnedAt: date, value: value, rangeEnd: date)
                    }
                }
            } else {
                ledger.storedAwards["\(id).record"] = nil
            }
        }
        raiseCalorieAwards(inputs: inputs, now: now, calendar: calendar, into: &ledger)
    }

    static func calorieTierDates(
        inputs: [ActivityBadgeInput],
        ledger: ActivityBadgeLedger,
        now: Date,
        calendar: Calendar = .current
    ) -> [Int: Date] {
        let events = calorieEvents(inputs: inputs, ledger: ledger, now: now)
        var earned: [Int: Date] = [:]
        var dayTotals: [Date: Int] = [:]
        for event in events {
            let when = completionDate(event, justFinished: [], now: now)
            let day = calendar.startOfDay(for: when)
            let before = dayTotals[day, default: 0]
            let after = before + (event.activeKilocalories ?? 0)
            dayTotals[day] = after
            for tier in calorieTiers where earned[tier] == nil && before < tier && after >= tier {
                earned[tier] = when
            }
        }
        return earned
    }

    private static func raiseCalorieAwards(
        inputs: [ActivityBadgeInput],
        now: Date,
        calendar: Calendar,
        into ledger: inout ActivityBadgeLedger
    ) {
        let earned = calorieTierDates(inputs: inputs, ledger: ledger, now: now, calendar: calendar)
        for tier in calorieTiers {
            let key = calorieAwardID(tier)
            guard let date = earned[tier] else {
                ledger.storedAwards[key] = nil
                continue
            }
            if var existing = ledger.storedAwards[key] {
                if date < existing.earnedAt { existing.earnedAt = date }
                existing.value = tier
                ledger.storedAwards[key] = existing
            } else {
                ledger.storedAwards[key] = ActivityStoredAward(earnedAt: date, value: tier)
            }
        }
    }

    private static func keepsPersonalRecord(_ id: String) -> Bool {
        distanceRecordIDs.contains(id) || id == "habit.drink-water"
    }

    private static func recordUnit(for id: String, ledger: ActivityBadgeLedger) -> ActivityAwardUnit? {
        if id == "habit.drink-water" { return .milliliters }
        switch requirement(for: id, ledger: ledger) {
        case .completedSession, .breathingMinute:
            return .minutes
        case .waterGoal:
            return .milliliters
        case .habitCheckIn, .none:
            return nil
        }
    }

    private static func waterFacts(
        _ inputs: [ActivityBadgeInput],
        goal: Int,
        now: Date,
        calendar: Calendar
    ) -> ActivityAwardFacts {
        let logs = inputs
            .filter { $0.isCompleted && !$0.isSkipped && $0.waterMilliliters > 0 }
            .sorted { $0.startedAt < $1.startedAt }
        var totals: [Date: Int] = [:]
        var crossings: [(day: Date, at: Date)] = []
        for log in logs {
            let day = calendar.startOfDay(for: log.startedAt)
            let next = totals[day, default: 0] + log.waterMilliliters
            totals[day] = next
            if goal > 0, next >= goal, !crossings.contains(where: { calendar.isDate($0.day, inSameDayAs: day) }) {
                crossings.append((day, log.startedAt))
            }
        }
        let bestDay = totals.max { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key > rhs.key }
            return lhs.value < rhs.value
        }
        let streak = streakStats(days: crossings.map(\.day), now: now, calendar: calendar)
        var tiers: [Int: Date] = [:]
        for tier in awardTiers where crossings.count >= tier {
            tiers[tier] = crossings[tier - 1].at
        }
        return ActivityAwardFacts(
            completions: crossings.count,
            tierEarnedAt: tiers,
            currentStreak: streak.current,
            bestStreak: streak.best,
            bestStreakStart: streak.start,
            bestStreakEnd: streak.end,
            recordValue: bestDay?.value,
            recordDate: bestDay?.key,
            recordUnit: .milliliters,
            firstMeasured: nil
        )
    }

    private static func streakStats(
        days: [Date],
        now: Date,
        calendar: Calendar
    ) -> (current: Int, best: Int, start: Date?, end: Date?) {
        let unique = Array(Set(days.map { calendar.startOfDay(for: $0) })).sorted()
        guard let first = unique.first else { return (0, 0, nil, nil) }
        var best = 1
        var bestStart = first
        var bestEnd = first
        var run = 1
        var runStart = first
        for index in unique.indices.dropFirst() {
            let day = unique[index]
            let previous = unique[index - 1]
            let continues = calendar.date(byAdding: .day, value: 1, to: previous).map { calendar.isDate($0, inSameDayAs: day) } ?? false
            if continues {
                run += 1
            } else {
                run = 1
                runStart = day
            }
            if run > best {
                best = run
                bestStart = runStart
                bestEnd = day
            }
        }
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let last = unique[unique.count - 1]
        var current = 0
        if calendar.isDate(last, inSameDayAs: today) || calendar.isDate(last, inSameDayAs: yesterday) {
            current = 1
            var cursor = last
            let daySet = Set(unique)
            while let previous = calendar.date(byAdding: .day, value: -1, to: cursor), daySet.contains(previous) {
                current += 1
                cursor = previous
            }
        }
        return (current, best, bestStart, bestEnd)
    }
}

enum ActivitySuggestionPlanner {
    static let idleInterval: TimeInterval = 14 * 24 * 60 * 60
    static let minimumGap: TimeInterval = 30 * 24 * 60 * 60

    struct Decision: Equatable {
        var fireAt: Date
        var badgeID: String
        var lastInviteAt: Date?
    }

    static func decide(
        now: Date,
        suggestionID: String?,
        enabled: Bool,
        notificationsAuthorized: Bool,
        lastInviteAt: Date?,
        scheduledFireAt: Date?
    ) -> Decision? {
        guard enabled, notificationsAuthorized, let suggestionID else { return nil }
        var invite = lastInviteAt
        if let scheduledFireAt, now >= scheduledFireAt {
            invite = scheduledFireAt
        }
        let earliest = now.addingTimeInterval(idleInterval)
        let afterGap = (invite ?? .distantPast).addingTimeInterval(minimumGap)
        return Decision(
            fireAt: max(earliest, afterGap),
            badgeID: suggestionID,
            lastInviteAt: invite
        )
    }
}
