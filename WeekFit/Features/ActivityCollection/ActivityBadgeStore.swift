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

    static var screenTitle: String { text["screen", default: "Awards"] }
    static var unlockedTitle: String { text["unlocked", default: "Badge unlocked"] }
    static var done: String { text["done", default: "Done"] }
    static var viewCollection: String { text["view", default: "View awards"] }
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
        case .energy: return text["energy", default: "Calories"]
        case .recovery: return text["recovery", default: "Recovery"]
        case .habit: return text["habits", default: "Habits"]
        }
    }

    static var sessionTitle: String { text["session", default: "Activity"] }
    static var sessionToday: String { text["today", default: "Today"] }

    private static var text: [String: String] {
        let pack = chrome[code] ?? chrome["en"] ?? [:]
        return pack
    }

    private static let chrome: [String: [String: String]] = [
        "en": [
            "screen": "Awards", "unlocked": "Badge unlocked", "done": "Done",
            "view": "View awards", "suggest": "Activity suggestions",
            "suggestBody": "One invitation after 14 days away from WeekFit",
            "profile": "What you have already tried", "progress": "%d of %d unlocked",
            "activities": "Activities", "energy": "Calories", "recovery": "Recovery", "habits": "Habits",
            "session": "Activity", "today": "Today"
        ],
        "ru": [
            "screen": "Награды", "unlocked": "Награда получена", "done": "Готово",
            "view": "Смотреть награды", "suggest": "Подсказки активностей",
            "suggestBody": "Одно приглашение, если две недели не открывать WeekFit",
            "profile": "Что уже попробовано", "progress": "%d из %d открыто",
            "activities": "Активности", "energy": "Калории", "recovery": "Восстановление", "habits": "Привычки",
            "session": "Активность", "today": "Сегодня"
        ],
        "de": [
            "screen": "Auszeichnungen", "unlocked": "Abzeichen geschafft", "done": "Fertig",
            "view": "Auszeichnungen ansehen", "suggest": "Aktivitätsvorschläge",
            "suggestBody": "Eine Einladung nach 14 Tagen ohne WeekFit",
            "profile": "Was du schon probiert hast", "progress": "%d von %d geschafft",
            "activities": "Aktivitäten", "energy": "Kalorien", "recovery": "Erholung", "habits": "Gewohnheiten",
            "session": "Aktivität", "today": "Heute"
        ],
        "es": [
            "screen": "Premios", "unlocked": "Insignia desbloqueada", "done": "Listo",
            "view": "Ver premios", "suggest": "Sugerencias de actividad",
            "suggestBody": "Una invitación tras 14 días sin abrir WeekFit",
            "profile": "Lo que ya probaste", "progress": "%d de %d desbloqueadas",
            "activities": "Actividades", "energy": "Calorías", "recovery": "Recuperación", "habits": "Hábitos",
            "session": "Actividad", "today": "Hoy"
        ],
        "fr": [
            "screen": "Récompenses", "unlocked": "Badge débloqué", "done": "OK",
            "view": "Voir les récompenses", "suggest": "Suggestions d’activité",
            "suggestBody": "Une invitation après 14 jours sans ouvrir WeekFit",
            "profile": "Ce que tu as déjà essayé", "progress": "%d sur %d débloqués",
            "activities": "Activités", "energy": "Calories", "recovery": "Récupération", "habits": "Habitudes",
            "session": "Activité", "today": "Aujourd’hui"
        ],
        "it": [
            "screen": "Premi", "unlocked": "Badge sbloccato", "done": "Fatto",
            "view": "Vedi i premi", "suggest": "Suggerimenti attività",
            "suggestBody": "Un invito dopo 14 giorni senza aprire WeekFit",
            "profile": "Quello che hai già provato", "progress": "%d di %d sbloccati",
            "activities": "Attività", "energy": "Calorie", "recovery": "Recupero", "habits": "Abitudini",
            "session": "Attività", "today": "Oggi"
        ],
        "pl": [
            "screen": "Nagrody", "unlocked": "Odznaka zdobyta", "done": "Gotowe",
            "view": "Zobacz nagrody", "suggest": "Propozycje aktywności",
            "suggestBody": "Jedno zaproszenie po 14 dniach bez WeekFit",
            "profile": "Co już sprawdzone", "progress": "%d z %d zdobyte",
            "activities": "Aktywności", "energy": "Kalorie", "recovery": "Regeneracja", "habits": "Nawyki",
            "session": "Aktywność", "today": "Dziś"
        ],
        "ja": [
            "screen": "表彰", "unlocked": "バッジを獲得", "done": "完了",
            "view": "表彰を見る", "suggest": "アクティビティの提案",
            "suggestBody": "WeekFitを14日開かなかったら、一度だけお知らせします",
            "profile": "すでに試したこと", "progress": "%d / %d 獲得",
            "activities": "アクティビティ", "energy": "カロリー", "recovery": "回復", "habits": "習慣",
            "session": "アクティビティ", "today": "今日"
        ],
        "ko": [
            "screen": "수상", "unlocked": "배지 획득", "done": "완료",
            "view": "수상 보기", "suggest": "활동 제안",
            "suggestBody": "WeekFit을 14일 동안 열지 않으면 한 번 알림",
            "profile": "이미 해본 것", "progress": "%d / %d 획득",
            "activities": "활동", "energy": "칼로리", "recovery": "회복", "habits": "습관",
            "session": "활동", "today": "오늘"
        ],
        "zh-Hans": [
            "screen": "奖项", "unlocked": "徽章已解锁", "done": "完成",
            "view": "查看奖项", "suggest": "活动建议",
            "suggestBody": "连续 14 天未打开 WeekFit 时发一次邀请",
            "profile": "已经尝试过的", "progress": "已解锁 %d / %d",
            "activities": "活动", "energy": "卡路里", "recovery": "恢复", "habits": "习惯",
            "session": "活动", "today": "今天"
        ]
    ]

    private static let customFirst: [String: String] = [
        "en": "First Check-in",
        "ru": "Первая отметка",
            "de": "Erstes Mal",
            "es": "Primera vez",
            "fr": "Première fois",
            "it": "Prima volta",
            "pl": "Pierwszy raz",
        "ja": "初めてのチェック",
        "ko": "첫 체크",
        "zh-Hans": "第一次打卡"
    ]

    private static let awardNames: [String: [String: String]] = [
        "en": [
            "activity.cycling": "Two Wheels", "activity.running": "First Run", "activity.swimming": "First Wave",
            "activity.hiking": "First Trail", "activity.snowboarding": "First Ride", "activity.alpine-skiing": "First Descent",
            "activity.upper-body": "Upper Start", "activity.core": "Core Start", "activity.lower-body": "Lower Start",
            "activity.full-body": "Full Effort", "activity.tennis": "First Serve", "activity.padel": "First Rally",
            "activity.squash": "First Point", "activity.hiit": "First Interval", "recovery.stretching": "Stretch Break",
            "recovery.walk": "First Steps", "recovery.sauna": "Sauna Reset", "recovery.yoga": "On the Mat",
            "recovery.breathing": "First Pause", "habit.drink-water": "First Glass", "habit.sleep-routine": "Lights Down",
            "habit.no-screens": "Screen Break", "habit.morning-routine": "Morning Mark"
        ],
        "ru": [
            "activity.cycling": "На двух колёсах", "activity.running": "Первая пробежка", "activity.swimming": "Первая волна",
            "activity.hiking": "Первая тропа", "activity.snowboarding": "На сноуборде", "activity.alpine-skiing": "Первый спуск",
            "activity.upper-body": "Сильный верх", "activity.core": "Крепкий корпус", "activity.lower-body": "Сильные ноги",
            "activity.full-body": "Всё тело", "activity.tennis": "Первая подача", "activity.padel": "Дебют в паделе",
            "activity.squash": "Дебют в сквоше", "activity.hiit": "Первые интервалы", "recovery.stretching": "Пауза на растяжку",
            "recovery.walk": "Первая прогулка", "recovery.sauna": "Первый пар", "recovery.yoga": "На коврике",
            "recovery.breathing": "Дыхательная пауза", "habit.drink-water": "Первый глоток", "habit.sleep-routine": "Вечерний ритуал",
            "habit.no-screens": "Без экрана", "habit.morning-routine": "Утренний ритуал"
        ],
        "de": [
            "activity.cycling": "Zwei Räder", "activity.running": "Erster Lauf", "activity.swimming": "Erste Welle",
            "activity.hiking": "Erster Pfad", "activity.snowboarding": "Erstes Board", "activity.alpine-skiing": "Erste Abfahrt",
            "activity.upper-body": "Oberkörper", "activity.core": "Rumpf", "activity.lower-body": "Beine",
            "activity.full-body": "Ganzer Körper", "activity.tennis": "Erster Aufschlag", "activity.padel": "Erster Ballwechsel",
            "activity.squash": "Erster Punkt", "activity.hiit": "Erstes Intervall", "recovery.stretching": "Dehnpause",
            "recovery.walk": "Erste Schritte", "recovery.sauna": "Sauna-Pause", "recovery.yoga": "Auf der Matte",
            "recovery.breathing": "Erste Pause", "habit.drink-water": "Erstes Glas", "habit.sleep-routine": "Licht aus",
            "habit.no-screens": "Ohne Bildschirm", "habit.morning-routine": "Morgenritual"
        ],
        "es": [
            "activity.cycling": "Dos ruedas", "activity.running": "Primera carrera", "activity.swimming": "Primera ola",
            "activity.hiking": "Primer sendero", "activity.snowboarding": "Primera tabla", "activity.alpine-skiing": "Primer descenso",
            "activity.upper-body": "Parte de arriba", "activity.core": "Primer abdomen", "activity.lower-body": "Piernas",
            "activity.full-body": "Cuerpo entero", "activity.tennis": "Primer saque", "activity.padel": "Primer peloteo",
            "activity.squash": "Primer punto", "activity.hiit": "Primer intervalo", "recovery.stretching": "Pausa de estiramiento",
            "recovery.walk": "Primeros pasos", "recovery.sauna": "Pausa de sauna", "recovery.yoga": "En la esterilla",
            "recovery.breathing": "Primera pausa", "habit.drink-water": "Primer vaso", "habit.sleep-routine": "Luces apagadas",
            "habit.no-screens": "Sin pantalla", "habit.morning-routine": "Ritual de mañana"
        ],
        "fr": [
            "activity.cycling": "Deux roues", "activity.running": "Première course", "activity.swimming": "Première vague",
            "activity.hiking": "Premier sentier", "activity.snowboarding": "Première glisse", "activity.alpine-skiing": "Première descente",
            "activity.upper-body": "Haut du corps", "activity.core": "Premiers abdos", "activity.lower-body": "Bas du corps",
            "activity.full-body": "Corps entier", "activity.tennis": "Premier service", "activity.padel": "Premier échange",
            "activity.squash": "Premier point", "activity.hiit": "Premier intervalle", "recovery.stretching": "Pause étirement",
            "recovery.walk": "Premiers pas", "recovery.sauna": "Pause sauna", "recovery.yoga": "Sur le tapis",
            "recovery.breathing": "Première pause", "habit.drink-water": "Premier verre", "habit.sleep-routine": "Lumières éteintes",
            "habit.no-screens": "Sans écran", "habit.morning-routine": "Rituel du matin"
        ],
        "it": [
            "activity.cycling": "Due ruote", "activity.running": "Prima corsa", "activity.swimming": "Prima onda",
            "activity.hiking": "Primo sentiero", "activity.snowboarding": "Prima tavola", "activity.alpine-skiing": "Prima sciata",
            "activity.upper-body": "Parte alta", "activity.core": "Primo addome", "activity.lower-body": "Parte bassa",
            "activity.full-body": "Tutto il corpo", "activity.tennis": "Prima battuta", "activity.padel": "Primo scambio",
            "activity.squash": "Primo punto", "activity.hiit": "Primo intervallo", "recovery.stretching": "Pausa stretching",
            "recovery.walk": "Primi passi", "recovery.sauna": "Pausa sauna", "recovery.yoga": "Sul tappetino",
            "recovery.breathing": "Prima pausa", "habit.drink-water": "Primo bicchiere", "habit.sleep-routine": "Luci spente",
            "habit.no-screens": "Senza schermo", "habit.morning-routine": "Rituale del mattino"
        ],
        "pl": [
            "activity.cycling": "Dwa koła", "activity.running": "Pierwszy bieg", "activity.swimming": "Pierwsza fala",
            "activity.hiking": "Pierwszy szlak", "activity.snowboarding": "Pierwszy zjazd", "activity.alpine-skiing": "Pierwsze narty",
            "activity.upper-body": "Góra", "activity.core": "Brzuch", "activity.lower-body": "Nogi",
            "activity.full-body": "Całe ciało", "activity.tennis": "Pierwszy serwis", "activity.padel": "Pierwsza wymiana",
            "activity.squash": "Pierwszy punkt", "activity.hiit": "Pierwszy interwał", "recovery.stretching": "Przerwa na rozciąganie",
            "recovery.walk": "Pierwsze kroki", "recovery.sauna": "Przerwa w saunie", "recovery.yoga": "Na macie",
            "recovery.breathing": "Pierwsza pauza", "habit.drink-water": "Pierwsza szklanka", "habit.sleep-routine": "Zgaszone światło",
            "habit.no-screens": "Bez ekranu", "habit.morning-routine": "Poranny rytuał"
        ],
        "ja": [
            "activity.cycling": "初めての自転車", "activity.running": "初めてのラン", "activity.swimming": "初めての波",
            "activity.hiking": "初めてのハイキング", "activity.snowboarding": "初めての滑走", "activity.alpine-skiing": "初めての滑降",
            "activity.upper-body": "上半身デビュー", "activity.core": "初めての体幹", "activity.lower-body": "下半身デビュー",
            "activity.full-body": "全身", "activity.tennis": "初めてのサーブ", "activity.padel": "初めてのラリー",
            "activity.squash": "初めてのポイント", "activity.hiit": "初めてのインターバル", "recovery.stretching": "ストレッチ",
            "recovery.walk": "初めての一歩", "recovery.sauna": "サウナ", "recovery.yoga": "マットの上",
            "recovery.breathing": "初めての一呼吸", "habit.drink-water": "最初の一杯", "habit.sleep-routine": "消灯",
            "habit.no-screens": "画面オフ", "habit.morning-routine": "朝の習慣"
        ],
        "ko": [
            "activity.cycling": "첫 두 바퀴", "activity.running": "첫 달리기", "activity.swimming": "첫 파도",
            "activity.hiking": "첫 길", "activity.snowboarding": "첫 라이딩", "activity.alpine-skiing": "첫 활강",
            "activity.upper-body": "상체 시작", "activity.core": "코어 시작", "activity.lower-body": "하체 시작",
            "activity.full-body": "전신", "activity.tennis": "첫 서브", "activity.padel": "첫 랠리",
            "activity.squash": "첫 포인트", "activity.hiit": "첫 인터벌", "recovery.stretching": "스트레칭",
            "recovery.walk": "첫걸음", "recovery.sauna": "사우나", "recovery.yoga": "매트 위",
            "recovery.breathing": "숨 고르기", "habit.drink-water": "첫 잔", "habit.sleep-routine": "불 끄기",
            "habit.no-screens": "화면 끄기", "habit.morning-routine": "아침 습관"
        ],
        "zh-Hans": [
            "activity.cycling": "两轮", "activity.running": "第一次跑步", "activity.swimming": "第一浪",
            "activity.hiking": "第一条小路", "activity.snowboarding": "第一次滑行", "activity.alpine-skiing": "第一次滑雪",
            "activity.upper-body": "上肢起步", "activity.core": "核心起步", "activity.lower-body": "下肢起步",
            "activity.full-body": "全身", "activity.tennis": "第一次发球", "activity.padel": "第一次对打",
            "activity.squash": "第一分", "activity.hiit": "第一次间歇", "recovery.stretching": "拉伸一下",
            "recovery.walk": "第一步", "recovery.sauna": "桑拿", "recovery.yoga": "在垫上",
            "recovery.breathing": "缓一口气", "habit.drink-water": "第一杯", "habit.sleep-routine": "关灯",
            "habit.no-screens": "离开屏幕", "habit.morning-routine": "晨间习惯"
        ]
    ]

    static func unlockLine(minutes: Int?, badgeName: String) -> String {
        let line = unlockLines[code] ?? unlockLines["en"]!
        if let minutes {
            return String(format: line.timed, minutes, badgeName)
        }
        return String(format: line.plain, badgeName)
    }

    private static let unlockLines: [String: (timed: String, plain: String)] = [
        "en": ("%d min · Unlock %@", "Unlock %@"),
        "ru": ("%d мин · откроется «%@»", "Откроется «%@»"),
        "de": ("%d Min. · %@ schaffen", "%@ schaffen"),
        "es": ("%d min · Consigue %@", "Consigue %@"),
        "fr": ("%d min · Décroche %@", "Décroche %@"),
        "it": ("%d min · Ottieni %@", "Ottieni %@"),
        "pl": ("%d min · Zdobądź %@", "Zdobądź %@"),
        "ja": ("%d分で%@", "%@を獲得"),
        "ko": ("%d분이면 %@", "%@ 획득"),
        "zh-Hans": ("%d 分钟获得%@", "获得%@")
    ]

    static func badgeName(id: String, ledger: ActivityBadgeLedger) -> String {
        if ActivityBadgeCatalog.definition(id: id) != nil {
            return awardNames[code]?[id] ?? awardNames["en"]?[id] ?? id
        }
        return ledger.customNames[id] ?? (customFirst[code] ?? customFirst["en"] ?? "First Check-in")
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
    /// How many times this award itself was earned. One-time awards are 1.
    var times: Int = 0
    var award: ActivityAwardState = ActivityAwardState()
    var source: ActivityAwardSource? = nil
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
        if category == .energy {
            return calorieCells(
                ledger: ledger,
                inputs: inputs,
                now: now,
                calendar: calendar,
                activityName: activityName
            )
        }
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

    private static func calorieCells(
        ledger: ActivityBadgeLedger,
        inputs: [ActivityBadgeInput],
        now: Date,
        calendar: Calendar,
        activityName: (String) -> String
    ) -> [ActivityBadgeDisplay] {
        let earned = ActivityBadgeEngine.calorieTierDates(
            inputs: inputs,
            ledger: ledger,
            now: now,
            calendar: calendar
        )
        return ActivityBadgeEngine.calorieTiers.map { tier in
            let id = ActivityBadgeEngine.calorieAwardID(tier)
            let date = earned[tier]
            let unlocked = date != nil
            return ActivityBadgeDisplay(
                id: id,
                name: ActivityAwardCopy.name(kind: .personalRecord, goal: tier, unit: .kilocalories, activity: ""),
                caption: ActivityAwardCopy.caption(kind: .personalRecord, goal: tier, unit: .kilocalories, activity: ""),
                symbol: "flame.fill",
                category: .energy,
                condition: ActivityAwardCopy.condition(kind: .personalRecord, goal: tier, unit: .kilocalories, activity: ""),
                activityName: "",
                isUnlocked: unlocked,
                unlockedAt: unlocked ? date : nil,
                canStart: false,
                actionTitle: "",
                actionMinutes: nil,
                times: unlocked ? 1 : 0,
                award: ActivityAwardState(
                    kind: .personalRecord,
                    current: tier,
                    goal: tier,
                    unit: .kilocalories,
                    rangeEnd: date
                ),
                source: sessionSource(
                    id: id,
                    earned: unlocked,
                    inputs: inputs,
                    ledger: ledger,
                    now: now,
                    calendar: calendar,
                    activityName: activityName
                )
            )
        }
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
            times: ledger.unlocks[id] == nil
                ? 0
                : (ActivityBadgeEngine.distanceAwardIDs.contains(id) ? 1 : max(resolvedFacts.completions, 1)),
            award: ActivityAwardState(
                kind: .first,
                current: ledger.unlocks[id] == nil ? 0 : 1,
                goal: 1,
                best: resolvedFacts.firstMeasured,
                unit: resolvedFacts.firstMeasured == nil ? .sessions : .minutes,
                rangeEnd: ledger.unlocks[id]
            ),
            source: sessionSource(
                id: id,
                earned: ledger.unlocks[id] != nil,
                inputs: inputs,
                ledger: ledger,
                now: now,
                calendar: calendar,
                activityName: activityName
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
        if ActivityBadgeEngine.distanceAwardIDs.contains(baseID) {
            rows.append(contentsOf: distanceAwards(
                base: base,
                baseID: baseID,
                facts: facts,
                ledger: ledger,
                inputs: inputs,
                now: now,
                calendar: calendar,
                activityName: activityName
            ))
        }
        let tiers = ActivityBadgeEngine.awardTiers
        if !ActivityBadgeEngine.distanceAwardIDs.contains(baseID) {
        for tier in tiers {
            let key = "\(baseID).count.\(tier)"
            let stored = ledger.storedAwards[key]
            let earned = stored != nil || facts.completions >= tier
            guard earned, usesOwnArtwork(key, baseID: baseID) else { continue }
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
        if hasCountProgress, let next = tiers.first(where: { ledger.storedAwards["\(baseID).count.\($0)"] == nil && facts.completions < $0 && usesOwnArtwork("\(baseID).count.\($0)", baseID: baseID) }) {
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
        }
        let streakKey = "\(baseID).streak"
        let storedStreak = ledger.storedAwards[streakKey]
        let best = max(storedStreak?.value ?? 0, facts.bestStreak)
        if (best >= 1 || storedStreak != nil), usesOwnArtwork(streakKey, baseID: baseID) {
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
        let distanceRecord = ActivityBadgeEngine.distanceRecordIDs.contains(baseID)
        let value = distanceRecord
            ? (facts.recordValue ?? storedRecord?.value ?? 0)
            : (unit == .kilocalories
                ? (facts.recordValue ?? 0)
                : max(storedRecord?.value ?? 0, facts.recordValue ?? 0))
        if value > 0, (unit != nil || storedRecord != nil), distanceRecord || usesOwnArtwork(recordKey, baseID: baseID) {
            let storedWins = (storedRecord?.value ?? 0) >= (facts.recordValue ?? 0)
            rows.append(derived(
                base: base,
                id: recordKey,
                kind: .personalRecord,
                earned: true,
                earnedAt: storedWins ? (storedRecord?.rangeEnd ?? storedRecord?.earnedAt) : facts.recordDate,
                current: value,
                goal: unit == .kilocalories ? value : nil,
                unit: unit ?? .minutes,
                rangeEnd: storedWins ? storedRecord?.rangeEnd : facts.recordDate,
                times: distanceRecord ? 0 : nil,
                inputs: inputs,
                now: now,
                calendar: calendar,
                ledger: ledger,
                activityName: activityName
            ))
        }
        return rows
    }

    /// Streaks, records, and repeat plates stay out until they have a picture of their own.
    /// The number under the first badge is the repeat count.
    private static func usesOwnArtwork(_ id: String, baseID: String) -> Bool {
        guard let art = ActivityBadgeArt.asset(for: id),
              let baseArt = ActivityBadgeArt.asset(for: baseID) else { return false }
        return art != baseArt
    }

    private static func distanceAwards(
        base: ActivityBadgeDisplay,
        baseID: String,
        facts: ActivityAwardFacts,
        ledger: ActivityBadgeLedger,
        inputs: [ActivityBadgeInput],
        now: Date,
        calendar: Calendar,
        activityName: (String) -> String
    ) -> [ActivityBadgeDisplay] {
        var rows: [ActivityBadgeDisplay] = []
        let tiers = ActivityBadgeEngine.distanceTiers(for: baseID)
        for tier in tiers {
            let key = "\(baseID).km.\(tier)"
            let stored = ledger.storedAwards[key]
            let count = facts.distanceCounts[tier] ?? 0
            guard count > 0, usesOwnArtwork(key, baseID: baseID) || (baseID == "activity.cycling" && (tier == 25 || tier == 50)) else { continue }
            rows.append(derived(
                base: base,
                id: key,
                kind: .accumulation,
                earned: true,
                earnedAt: stored?.earnedAt ?? facts.distanceTiers[tier],
                current: count,
                goal: tier,
                unit: .kilometers,
                times: max(count, 1),
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
        times: Int? = nil,
        inputs: [ActivityBadgeInput],
        now: Date,
        calendar: Calendar,
        ledger: ActivityBadgeLedger,
        activityName: (String) -> String
    ) -> ActivityBadgeDisplay {
        let baseID = ActivityBadgeEngine.awardBaseID(id)
        let definition = ActivityBadgeCatalog.definition(id: baseID)
        let catalogTitle = definition?.catalogTitle ?? base.activityName
        let activity = activityName(catalogTitle)
        let copyActivity = kind == .personalRecord && unit == .kilometers ? catalogTitle : activity
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
            name: ActivityAwardCopy.name(kind: kind, goal: goal, unit: unit, activity: copyActivity),
            caption: ActivityAwardCopy.caption(kind: kind, goal: goal, unit: unit, activity: copyActivity),
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
            times: times ?? (earned ? 1 : 0),
            award: state,
            source: sessionSource(
                id: id,
                earned: earned,
                inputs: inputs,
                ledger: ledger,
                now: now,
                calendar: calendar,
                activityName: activityName,
                waterTotal: unit == .milliliters ? current : nil
            )
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

    private static func sessionSource(
        id: String,
        earned: Bool,
        inputs: [ActivityBadgeInput],
        ledger: ActivityBadgeLedger,
        now: Date,
        calendar: Calendar,
        activityName: (String) -> String,
        waterTotal: Int? = nil
    ) -> ActivityAwardSource? {
        guard earned,
              let input = ActivityBadgeEngine.earningInput(
                for: id,
                inputs: inputs,
                ledger: ledger,
                now: now,
                calendar: calendar
              ) else { return nil }
        let symbol = ActivityBadgeCatalog.definition(catalogTitle: input.title)?.symbol
            ?? ActivityBadgeCatalog.definition(id: ActivityBadgeEngine.awardBaseID(id))?.symbol
            ?? "figure.mixed.cardio"
        let calories = input.activeKilocalories ?? 0
        let distance = input.distanceMeters ?? 0
        return ActivityAwardSource(
            recordID: input.recordID,
            title: activityName(input.title),
            icon: input.icon.isEmpty ? symbol : input.icon,
            startedAt: input.startedAt,
            durationMinutes: input.actualDurationMinutes ?? input.durationMinutes,
            kilocalories: calories > 0 ? calories : nil,
            distanceMeters: distance > 0 ? distance : nil,
            waterMilliliters: waterTotal ?? input.waterMilliliters
        )
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
