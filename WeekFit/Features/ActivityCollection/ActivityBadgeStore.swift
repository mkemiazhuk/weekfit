import Foundation
internal import Combine

@MainActor
final class ActivityBadgeStore: ObservableObject {
    static let shared = ActivityBadgeStore()

    @Published private(set) var ledger = ActivityBadgeLedger()
    @Published var pendingUnlockID: String?
    @Published var showCollection = false
    @Published var collectionHighlight: String?
    @Published var openWaterLog = false

    private let defaults: UserDefaults
    private let storageKey = "activityBadges.ledger"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(ActivityBadgeLedger.self, from: data) {
            ledger = stored
            pendingUnlockID = stored.pendingUnlockID
        }
    }

    func replace(_ ledger: ActivityBadgeLedger) {
        self.ledger = ledger
        pendingUnlockID = ledger.pendingUnlockID
        persist()
    }

    func noteLiveFinish(recordID: String, elapsedSeconds: Int, catalogTitle: String) {
        var next = ledger
        if ActivityBadgeCatalog.canonicalCatalogTitle(catalogTitle) == "Breathing", elapsedSeconds < 60 {
            if !next.disqualifiedRecordIDs.contains(recordID) {
                next.disqualifiedRecordIDs.append(recordID)
            }
        } else if !next.justFinishedRecordIDs.contains(recordID) {
            next.justFinishedRecordIDs.append(recordID)
        }
        ledger = next
        persist()
    }

    func clearPending() {
        var next = ledger
        next.pendingUnlockID = nil
        ledger = next
        pendingUnlockID = nil
        persist()
    }

    func isUnlocked(_ id: String) -> Bool {
        ledger.unlocks[id] != nil
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

enum ActivityBadgeCopy {
    static var russian: Bool { WeekFitCurrentLanguageCode() == "ru" }
    private static var code: String { WeekFitCurrentLanguageCode() }

    static var screenTitle: String { text["screen", default: "Activity Collection"] }
    static var unlockedTitle: String { text["unlocked", default: "Badge unlocked"] }
    static var done: String { text["done", default: "Done"] }
    static var viewCollection: String { text["view", default: "View collection"] }
    static var suggestionsTitle: String { text["suggest", default: "Activity suggestions"] }
    static var suggestionsSubtitle: String { text["suggestBody", default: "One invitation after 14 days away from WeekFit"] }
    static var profileTitle: String { screenTitle }
    static var profileSubtitle: String { text["profile", default: "What you have already tried"] }

    static func progress(unlocked: Int, total: Int) -> String {
        String(format: text["progress", default: "%d of %d unlocked"], unlocked, total)
    }

    static func sectionTitle(_ category: ActivityBadgeCategory) -> String {
        switch category {
        case .activity: return text["activities", default: "Activities"]
        case .recovery: return text["recovery", default: "Recovery"]
        case .habit: return text["habits", default: "Habits"]
        }
    }

    private static var text: [String: String] {
        let pack = chrome[code] ?? chrome["en"] ?? [:]
        return pack
    }

    private static let chrome: [String: [String: String]] = [
        "en": [
            "screen": "Activity Collection", "unlocked": "Badge unlocked", "done": "Done",
            "view": "View collection", "suggest": "Activity suggestions",
            "suggestBody": "One invitation after 14 days away from WeekFit",
            "profile": "What you have already tried", "progress": "%d of %d unlocked",
            "activities": "Activities", "recovery": "Recovery", "habits": "Habits"
        ],
        "ru": [
            "screen": "Коллекция активностей", "unlocked": "Бейдж открыт", "done": "Готово",
            "view": "Смотреть коллекцию", "suggest": "Подсказки активностей",
            "suggestBody": "Одно приглашение, если две недели не открывать WeekFit",
            "profile": "Что уже попробовано", "progress": "%d из %d открыто",
            "activities": "Активности", "recovery": "Восстановление", "habits": "Привычки"
        ],
        "de": [
            "screen": "Aktivitätensammlung", "unlocked": "Abzeichen offen", "done": "Fertig",
            "view": "Sammlung ansehen", "suggest": "Aktivitätsvorschläge",
            "suggestBody": "Eine Einladung nach 14 Tagen ohne WeekFit",
            "profile": "Was du schon probiert hast", "progress": "%d von %d offen",
            "activities": "Aktivitäten", "recovery": "Erholung", "habits": "Gewohnheiten"
        ],
        "es": [
            "screen": "Colección de actividades", "unlocked": "Insignia desbloqueada", "done": "Listo",
            "view": "Ver colección", "suggest": "Sugerencias de actividad",
            "suggestBody": "Una invitación tras 14 días sin abrir WeekFit",
            "profile": "Lo que ya probaste", "progress": "%d de %d desbloqueadas",
            "activities": "Actividades", "recovery": "Recuperación", "habits": "Hábitos"
        ],
        "fr": [
            "screen": "Collection d’activités", "unlocked": "Badge débloqué", "done": "OK",
            "view": "Voir la collection", "suggest": "Suggestions d’activité",
            "suggestBody": "Une invitation après 14 jours sans ouvrir WeekFit",
            "profile": "Ce que tu as déjà essayé", "progress": "%d sur %d débloqués",
            "activities": "Activités", "recovery": "Récupération", "habits": "Habitudes"
        ],
        "it": [
            "screen": "Collezione attività", "unlocked": "Badge sbloccato", "done": "Fatto",
            "view": "Vedi collezione", "suggest": "Suggerimenti attività",
            "suggestBody": "Un invito dopo 14 giorni senza aprire WeekFit",
            "profile": "Quello che hai già provato", "progress": "%d di %d sbloccati",
            "activities": "Attività", "recovery": "Recupero", "habits": "Abitudini"
        ],
        "pl": [
            "screen": "Kolekcja aktywności", "unlocked": "Odznaka otwarta", "done": "Gotowe",
            "view": "Zobacz kolekcję", "suggest": "Propozycje aktywności",
            "suggestBody": "Jedno zaproszenie po 14 dniach bez WeekFit",
            "profile": "Co już sprawdzone", "progress": "%d z %d otwarte",
            "activities": "Aktywności", "recovery": "Regeneracja", "habits": "Nawyki"
        ],
        "ja": [
            "screen": "アクティビティコレクション", "unlocked": "バッジを獲得", "done": "完了",
            "view": "コレクションを見る", "suggest": "アクティビティの提案",
            "suggestBody": "WeekFitを14日開かなかったら、一度だけお知らせします",
            "profile": "すでに試したこと", "progress": "%d / %d 獲得",
            "activities": "アクティビティ", "recovery": "回復", "habits": "習慣"
        ],
        "ko": [
            "screen": "활동 컬렉션", "unlocked": "배지 획득", "done": "완료",
            "view": "컬렉션 보기", "suggest": "활동 제안",
            "suggestBody": "WeekFit을 14일 동안 열지 않으면 한 번 알림",
            "profile": "이미 해본 것", "progress": "%d / %d 열림",
            "activities": "활동", "recovery": "회복", "habits": "습관"
        ],
        "zh-Hans": [
            "screen": "活动收藏", "unlocked": "徽章已解锁", "done": "完成",
            "view": "查看收藏", "suggest": "活动建议",
            "suggestBody": "连续 14 天未打开 WeekFit 时发一次邀请",
            "profile": "已经尝试过的", "progress": "已解锁 %d / %d",
            "activities": "活动", "recovery": "恢复", "habits": "习惯"
        ]
    ]

    static func unlockLine(minutes: Int?, badgeName: String) -> String {
        if let minutes {
            return russian
                ? "\(minutes) мин · откроется «\(badgeName)»"
                : "\(minutes) min · Unlock \(badgeName)"
        }
        return russian ? "Откроется «\(badgeName)»" : "Unlock \(badgeName)"
    }

    static func badgeName(id: String, ledger: ActivityBadgeLedger) -> String {
        if let definition = ActivityBadgeCatalog.definition(id: id) {
            return definition.name(russian: russian)
        }
        return russian ? ActivityBadgeCatalog.customAchievementRU : ActivityBadgeCatalog.customAchievementEN
    }

    static func caption(id: String, ledger: ActivityBadgeLedger) -> String {
        if ActivityBadgeCatalog.definition(id: id) != nil {
            return badgeName(id: id, ledger: ledger)
        }
        return ledger.customNames[id] ?? badgeName(id: id, ledger: ledger)
    }

    static func condition(id: String) -> String {
        if let definition = ActivityBadgeCatalog.definition(id: id) {
            return definition.condition(russian: russian)
        }
        return russian ? ActivityBadgeCatalog.customConditionRU : ActivityBadgeCatalog.customConditionEN
    }

    static func actionTitle(id: String, ledger: ActivityBadgeLedger) -> String {
        if let definition = ActivityBadgeCatalog.definition(id: id) {
            return definition.action(russian: russian)
        }
        let name = ledger.customNames[id] ?? ""
        return russian ? "Отметить \(name)" : "Check in \(name)"
    }
}

struct ActivityBadgeDisplay: Identifiable, Equatable {
    let id: String
    let name: String
    let caption: String
    let symbol: String
    let category: ActivityBadgeCategory
    let condition: String
    let activityName: String
    let isUnlocked: Bool
    let unlockedAt: Date?
    let canStart: Bool
    let actionTitle: String
    let actionMinutes: Int?
    var award: ActivityAwardState = ActivityAwardState()
}

enum ActivityBadgePresenter {
    static func sections(
        ledger: ActivityBadgeLedger,
        inputs: [ActivityBadgeInput],
        now: Date = Date(),
        calendar: Calendar = .current,
        activityName: (String) -> String
    ) -> [ActivityBadgeSection] {
        ActivityBadgeCategory.allCases.map { category in
            let cells = cells(category: category, ledger: ledger, inputs: inputs, now: now, calendar: calendar, activityName: activityName)
            return ActivityBadgeSection(
                id: category.rawValue,
                title: ActivityBadgeCopy.sectionTitle(category),
                unlocked: cells.filter(\.isUnlocked).count,
                total: cells.count,
                cells: cells
            )
        }
    }

    static func focusSuggestion(
        ledger: ActivityBadgeLedger,
        inputs: [ActivityBadgeInput],
        now: Date = Date()
    ) -> ActivityBadgeDisplay? {
        guard let id = ActivityBadgeEngine.suggestionID(ledger: ledger, inputs: inputs, now: now) else { return nil }
        return cell(id: id, ledger: ledger, inputs: inputs, now: now, calendar: .current, activityName: { $0 })
    }

    private static func cells(
        category: ActivityBadgeCategory,
        ledger: ActivityBadgeLedger,
        inputs: [ActivityBadgeInput],
        now: Date,
        calendar: Calendar,
        activityName: (String) -> String
    ) -> [ActivityBadgeDisplay] {
        var ids = ActivityBadgeCatalog.definitions.filter { $0.category == category }.map(\.id)
        if category == .habit {
            let custom = ledger.customNames.keys.sorted()
            ids.append(contentsOf: custom)
        }
        let groups = ids.compactMap { id -> [ActivityBadgeDisplay]? in
            let facts = ActivityBadgeEngine.awardFacts(
                for: id,
                inputs: inputs,
                ledger: ledger,
                now: now,
                calendar: calendar
            )
            guard let first = cell(
                id: id,
                ledger: ledger,
                inputs: inputs,
                now: now,
                calendar: calendar,
                activityName: activityName,
                facts: facts
            ) else { return [ActivityBadgeDisplay]() }
            return [first] + derivedAwards(
                baseID: id,
                facts: facts,
                ledger: ledger,
                inputs: inputs,
                now: now,
                calendar: calendar,
                activityName: activityName
            )
        }
        // Let people browse the distinct activities before their count and streak variants.
        return groups.compactMap(\.first) + groups.flatMap { $0.dropFirst() }
    }

    private static func cell(
        id: String,
        ledger: ActivityBadgeLedger,
        inputs: [ActivityBadgeInput],
        now: Date,
        calendar: Calendar,
        activityName: (String) -> String,
        facts: ActivityAwardFacts? = nil
    ) -> ActivityBadgeDisplay? {
        let resolvedFacts = facts ?? ActivityBadgeEngine.awardFacts(
            for: id,
            inputs: inputs,
            ledger: ledger,
            now: now,
            calendar: calendar
        )
        let definition = ActivityBadgeCatalog.definition(id: id)
        let category = definition?.category ?? .habit
        let symbol = definition?.symbol ?? "checkmark"
        let catalogTitle = definition?.catalogTitle ?? (ledger.customNames[id] ?? "")
        let configured = ActivityBadgeEngine.suggestionID(ledger: ledger, inputs: inputs, now: now, calendar: calendar)
        let canStart: Bool = {
            if ledger.unlocks[id] != nil { return false }
            if definition?.startsImmediately == true { return true }
            if definition?.requirement == .habitCheckIn || id.hasPrefix(ActivityBadgeEngine.customPrefix) {
                return inputs.contains { input in
                    !input.isCompleted && !input.isSkipped
                        && calendar.isDate(input.startedAt, inSameDayAs: now)
                        && ActivityBadgeCatalog.normalize(input.title) == ActivityBadgeCatalog.normalize(catalogTitle)
                }
            }
            return definition != nil
        }()
        _ = configured
        return ActivityBadgeDisplay(
            id: id,
            name: ActivityBadgeCopy.badgeName(id: id, ledger: ledger),
            caption: ActivityBadgeCopy.caption(id: id, ledger: ledger),
            symbol: symbol,
            category: category,
            condition: ActivityBadgeCopy.condition(id: id),
            activityName: activityName(catalogTitle),
            isUnlocked: ledger.unlocks[id] != nil,
            unlockedAt: ledger.unlocks[id],
            canStart: canStart,
            actionTitle: ActivityBadgeCopy.actionTitle(id: id, ledger: ledger),
            actionMinutes: definition?.actionMinutes,
            award: ActivityAwardState(
                kind: .first,
                current: ledger.unlocks[id] == nil ? 0 : 1,
                goal: 1,
                best: resolvedFacts.firstMeasured,
                unit: resolvedFacts.firstMeasured == nil ? .sessions : .minutes,
                rangeEnd: ledger.unlocks[id]
            )
        )
    }

    private static func derivedAwards(
        baseID: String,
        facts: ActivityAwardFacts,
        ledger: ActivityBadgeLedger,
        inputs: [ActivityBadgeInput],
        now: Date,
        calendar: Calendar,
        activityName: (String) -> String
    ) -> [ActivityBadgeDisplay] {
        guard let base = cell(
            id: baseID,
            ledger: ledger,
            inputs: inputs,
            now: now,
            calendar: calendar,
            activityName: activityName,
            facts: facts
        ) else { return [] }
        var rows: [ActivityBadgeDisplay] = []
        let tiers = ActivityBadgeEngine.awardTiers
        for tier in tiers {
            let key = "\(baseID).count.\(tier)"
            let stored = ledger.storedAwards[key]
            let earned = stored != nil || facts.completions >= tier
            guard earned else { continue }
            let earnedAt = earliest(stored?.earnedAt, facts.tierEarnedAt[tier])
            rows.append(derived(
                base: base,
                id: key,
                kind: .accumulation,
                earned: true,
                earnedAt: earnedAt,
                current: max(facts.completions, tier),
                goal: tier,
                unit: baseID == "habit.drink-water" ? .days : .sessions,
                inputs: inputs,
                now: now,
                calendar: calendar,
                ledger: ledger,
                activityName: activityName
            ))
        }
        let hasCountProgress = facts.completions > 0 || tiers.contains { ledger.storedAwards["\(baseID).count.\($0)"] != nil }
        if hasCountProgress, let next = tiers.first(where: { ledger.storedAwards["\(baseID).count.\($0)"] == nil && facts.completions < $0 }) {
            rows.append(derived(
                base: base,
                id: "\(baseID).count.\(next)",
                kind: .accumulation,
                earned: false,
                earnedAt: nil,
                current: facts.completions,
                goal: next,
                unit: baseID == "habit.drink-water" ? .days : .sessions,
                inputs: inputs,
                now: now,
                calendar: calendar,
                ledger: ledger,
                activityName: activityName
            ))
        }
        let streakKey = "\(baseID).streak"
        let storedStreak = ledger.storedAwards[streakKey]
        let best = max(storedStreak?.value ?? 0, facts.bestStreak)
        if best >= 1 || storedStreak != nil {
            let earned = best >= ActivityBadgeEngine.streakLengthGoal
            let useStoredRange = (storedStreak?.value ?? 0) >= facts.bestStreak
            rows.append(derived(
                base: base,
                id: streakKey,
                kind: .streak,
                earned: earned,
                earnedAt: storedStreak?.earnedAt ?? facts.bestStreakEnd,
                current: facts.currentStreak,
                goal: earned ? nil : ActivityBadgeEngine.streakLengthGoal,
                best: best,
                unit: .days,
                rangeStart: useStoredRange ? storedStreak?.rangeStart : facts.bestStreakStart,
                rangeEnd: useStoredRange ? storedStreak?.rangeEnd : facts.bestStreakEnd,
                inputs: inputs,
                now: now,
                calendar: calendar,
                ledger: ledger,
                activityName: activityName
            ))
        }
        let recordKey = "\(baseID).record"
        let storedRecord = ledger.storedAwards[recordKey]
        let unit = facts.recordUnit
        let value = max(storedRecord?.value ?? 0, facts.recordValue ?? 0)
        if value > 0, unit != nil || storedRecord != nil {
            let storedWins = (storedRecord?.value ?? 0) >= (facts.recordValue ?? 0)
            rows.append(derived(
                base: base,
                id: recordKey,
                kind: .personalRecord,
                earned: true,
                earnedAt: storedWins ? (storedRecord?.rangeEnd ?? storedRecord?.earnedAt) : facts.recordDate,
                current: value,
                goal: nil,
                unit: unit ?? .minutes,
                rangeEnd: storedWins ? storedRecord?.rangeEnd : facts.recordDate,
                inputs: inputs,
                now: now,
                calendar: calendar,
                ledger: ledger,
                activityName: activityName
            ))
        }
        return rows
    }

    private static func derived(
        base: ActivityBadgeDisplay,
        id: String,
        kind: ActivityAwardKind,
        earned: Bool,
        earnedAt: Date?,
        current: Int,
        goal: Int?,
        best: Int? = nil,
        unit: ActivityAwardUnit,
        rangeStart: Date? = nil,
        rangeEnd: Date? = nil,
        inputs: [ActivityBadgeInput],
        now: Date,
        calendar: Calendar,
        ledger: ActivityBadgeLedger,
        activityName: (String) -> String
    ) -> ActivityBadgeDisplay {
        let baseID = ActivityBadgeEngine.awardBaseID(id)
        let definition = ActivityBadgeCatalog.definition(id: baseID)
        let activity = activityName(definition?.catalogTitle ?? base.activityName)
        let state = ActivityAwardState(
            kind: kind,
            current: current,
            goal: goal,
            best: best ?? (kind == .personalRecord ? current : nil),
            unit: unit,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd ?? earnedAt
        )
        return ActivityBadgeDisplay(
            id: id,
            name: ActivityAwardCopy.name(kind: kind, goal: goal, unit: unit, activity: activity),
            caption: ActivityAwardCopy.caption(kind: kind, goal: goal, unit: unit, activity: activity),
            symbol: base.symbol,
            category: base.category,
            condition: ActivityAwardCopy.condition(kind: kind, goal: goal, unit: unit, activity: activity),
            activityName: activity,
            isUnlocked: earned,
            unlockedAt: earned ? earnedAt : nil,
            canStart: earned ? false : canStartBase(
                baseID: baseID,
                ledger: ledger,
                inputs: inputs,
                now: now,
                calendar: calendar
            ),
            actionTitle: base.actionTitle,
            actionMinutes: base.actionMinutes,
            award: state
        )
    }

    private static func canStartBase(
        baseID: String,
        ledger: ActivityBadgeLedger,
        inputs: [ActivityBadgeInput],
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let definition = ActivityBadgeCatalog.definition(id: baseID)
        if definition?.startsImmediately == true { return true }
        let catalogTitle = definition?.catalogTitle ?? (ledger.customNames[baseID] ?? "")
        if definition?.requirement == .habitCheckIn || baseID.hasPrefix(ActivityBadgeEngine.customPrefix) {
            return inputs.contains { input in
                !input.isCompleted && !input.isSkipped
                    && calendar.isDate(input.startedAt, inSameDayAs: now)
                    && ActivityBadgeCatalog.normalize(input.title) == ActivityBadgeCatalog.normalize(catalogTitle)
            }
        }
        return definition != nil
    }

    private static func earliest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return min(lhs, rhs)
        case let (lhs?, nil): return lhs
        case let (nil, rhs?): return rhs
        default: return nil
        }
    }
}

struct ActivityBadgeSection: Identifiable, Equatable {
    let id: String
    let title: String
    let unlocked: Int
    let total: Int
    let cells: [ActivityBadgeDisplay]
}
