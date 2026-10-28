internal import Combine
import Foundation

/// Structured plan intent. Speech and any later model only fill this value.
/// The app validates it and saves through the existing planner path.
nonisolated struct PlanVoiceCreateRequest: Equatable, Sendable {
    let catalogTitle: String
    let plannerTypeTitle: String
    let start: Date
    let durationMinutes: Int
    /// Same command processed twice shares this key and is not saved again.
    let idempotencyKey: String
}

nonisolated enum PlanVoiceMissingField: Equatable, Sendable {
    case activity
    case startTime
}

nonisolated enum PlanVoiceCommandResult: Equatable, Sendable {
    case ready(PlanVoiceCreateRequest)
    case needsDetail(PlanVoiceMissingField, PlanVoiceCreateRequest?)
    case duplicate(PlanVoiceCreateRequest)
    case unrecognized
}

nonisolated struct PlanVoiceChatTurn: Identifiable, Equatable, Sendable {
    enum Speaker: Equatable, Sendable {
        case person
        case assistant
    }

    let id: UUID
    let speaker: Speaker
    let text: String

    init(speaker: Speaker, text: String) {
        id = UUID()
        self.speaker = speaker
        self.text = text
    }
}

/// Arms a turn only when the transcript actually changes. A pause with no new words ends it.
nonisolated struct PlanVoiceSilenceGate: Equatable, Sendable {
    static let pause: Duration = .milliseconds(1400)

    private(set) var revision = 0
    private(set) var transcript = ""

    mutating func note(_ text: String) -> Int? {
        let spoken = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard spoken != transcript else { return nil }
        transcript = spoken
        guard !spoken.isEmpty else { return nil }
        revision += 1
        return revision
    }
}

nonisolated enum PlanVoiceDayRelation: Equatable, Sendable {
    case today
    case tomorrow
    case dayAfterTomorrow
    case other
}

/// Turns a spoken phrase into a structured intent. Dates use `calendar`'s time zone.
nonisolated enum PlanVoiceCommandInterpreter {

    static func interpret(
        transcript: String,
        now: Date,
        calendar: Calendar,
        planningDay: Date,
        pending: PlanVoicePendingDraft? = nil
    ) -> (result: PlanVoiceCommandResult, pending: PlanVoicePendingDraft?) {
        let spoken = PlanVoiceTranscript.normalize(transcript)
        guard !spoken.isEmpty else {
            if let pending {
                return (.needsDetail(pending.missing ?? .startTime, nil), pending)
            }
            return (.unrecognized, nil)
        }

        var draft = pending ?? PlanVoicePendingDraft()
        draft.utterances.append(spoken)
        let fields = PlanVoiceTranscript.fields(in: spoken)

        if fields.activity != nil {
            draft.activity = fields.activity
        }
        if fields.dayOffset != nil {
            draft.dayOffset = fields.dayOffset
        }
        if fields.hour != nil {
            draft.hour = fields.hour
            draft.minute = fields.minute ?? 0
        }
        if fields.durationMinutes != nil {
            draft.durationMinutes = fields.durationMinutes
        }

        if draft.activity == nil {
            draft.missing = .activity
            return (.needsDetail(.activity, nil), draft)
        }

        let activity = draft.activity!
        let duration = draft.durationMinutes ?? activity.defaultDurationMinutes
        draft.durationMinutes = duration

        guard let hour = draft.hour, let minute = draft.minute else {
            draft.missing = .startTime
            return (.needsDetail(.startTime, nil), draft)
        }

        let day = resolvedDay(draft: draft, now: now, calendar: calendar, planningDay: planningDay)
        guard let start = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day
        ) else {
            draft.missing = .startTime
            return (.needsDetail(.startTime, nil), draft)
        }

        let request = PlanVoiceCreateRequest(
            catalogTitle: activity.catalogTitle,
            plannerTypeTitle: activity.plannerTypeTitle,
            start: start,
            durationMinutes: duration,
            idempotencyKey: [
                activity.catalogTitle,
                String(start.timeIntervalSince1970),
                String(duration),
                draft.utterances.joined(separator: "|")
            ].joined(separator: "#")
        )
        draft.missing = nil
        return (.ready(request), draft)
    }

    static func dayRelation(start: Date, now: Date, calendar: Calendar) -> PlanVoiceDayRelation {
        let startDay = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: startDay).day ?? 0
        switch days {
        case 0: return .today
        case 1: return .tomorrow
        case 2: return .dayAfterTomorrow
        default: return .other
        }
    }

    static func clock(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func endDate(start: Date, durationMinutes: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
    }

    private static func resolvedDay(
        draft: PlanVoicePendingDraft,
        now: Date,
        calendar: Calendar,
        planningDay: Date
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        if let offset = draft.dayOffset {
            return calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        return calendar.startOfDay(for: planningDay)
    }
}

nonisolated struct PlanVoicePendingDraft: Equatable, Sendable {
    var activity: PlanVoiceActivity?
    var dayOffset: Int?
    var hour: Int?
    var minute: Int?
    var durationMinutes: Int?
    var missing: PlanVoiceMissingField?
    var utterances: [String] = []
}

nonisolated struct PlanVoiceActivity: Equatable, Sendable {
    let catalogTitle: String
    let plannerTypeTitle: String
    /// Duration the add sheet already uses when the person does not name one.
    let defaultDurationMinutes: Int
}

nonisolated fileprivate struct PlanVoiceSpokenFields {
    var activity: PlanVoiceActivity?
    var dayOffset: Int?
    var hour: Int?
    var minute: Int?
    var durationMinutes: Int?
}

nonisolated enum PlanVoiceTranscript {

    static func normalize(_ text: String) -> String {
        var spoken = text
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
        spoken = spoken.replacingOccurrences(
            of: "a\\s*\\.\\s*m\\.?",
            with: "am",
            options: .regularExpression
        )
        spoken = spoken.replacingOccurrences(
            of: "p\\s*\\.\\s*m\\.?",
            with: "pm",
            options: .regularExpression
        )
        return spoken
            .replacingOccurrences(of: "[,.;!?]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    fileprivate static func fields(in spoken: String) -> PlanVoiceSpokenFields {
        var rest = spoken
        var fields = PlanVoiceSpokenFields()
        fields.activity = matchActivity(in: rest)
        if let day = matchDay(in: rest) {
            fields.dayOffset = day.offset
            rest = day.rest
        }
        if let duration = matchDuration(in: rest) {
            fields.durationMinutes = duration.minutes
            rest = duration.rest
        }
        if let time = matchTime(in: rest) {
            fields.hour = time.hour
            fields.minute = time.minute
        }
        return fields
    }

    private static func matchActivity(in spoken: String) -> PlanVoiceActivity? {
        let aliases = PlanVoiceCatalog.aliases.sorted { $0.alias.count > $1.alias.count }
        for entry in aliases {
            let pattern = "(^|[^\\p{L}\\p{N}])\(NSRegularExpression.escapedPattern(for: entry.alias))([^\\p{L}\\p{N}]|$)"
            if spoken.range(of: pattern, options: .regularExpression) != nil {
                return entry.activity
            }
        }
        return nil
    }

    private static func matchDay(in spoken: String) -> (offset: Int, rest: String)? {
        let phrases: [(String, Int)] = [
            ("послезавтра", 2),
            ("day after tomorrow", 2),
            ("завтра", 1),
            ("tomorrow", 1),
            ("сегодня", 0),
            ("today", 0)
        ]
        for (phrase, offset) in phrases where spoken.contains(phrase) {
            let rest = spoken.replacingOccurrences(of: phrase, with: " ")
            return (offset, collapse(rest))
        }
        return nil
    }

    private static func matchDuration(in spoken: String) -> (minutes: Int, rest: String)? {
        let fixed: [(String, Int)] = [
            ("на полтора часа", 90),
            ("полтора часа", 90),
            ("на полчаса", 30),
            ("на пол часа", 30),
            ("полчаса", 30)
        ]
        for (phrase, minutes) in fixed where spoken.contains(phrase) {
            return (minutes, collapse(spoken.replacingOccurrences(of: phrase, with: " ")))
        }

        if let minutes = firstInt(in: spoken, pattern: "(?:на\\s+)?(\\d{1,3})\\s+минут") {
            return minutes
        }
        if let hours = firstInt(in: spoken, pattern: "на\\s+(\\d{1,2})\\s+час") {
            return (hours.minutes * 60, hours.rest)
        }
        let words = [
            "один": 1, "одну": 1, "два": 2, "две": 2, "три": 3, "четыре": 4,
            "пять": 5, "шесть": 6
        ]
        for (word, count) in words {
            let phrase = "на \(word) час"
            if spoken.contains(phrase) {
                return (count * 60, collapse(spoken.replacingOccurrences(of: phrase, with: " ")))
            }
        }
        if spoken.range(of: "(^|\\s)на час(\\s|$)", options: .regularExpression) != nil {
            let rest = spoken.replacingOccurrences(
                of: "(^|\\s)на час(\\s|$)",
                with: " ",
                options: .regularExpression
            )
            return (60, collapse(rest))
        }
        return nil
    }

    private static func matchTime(in spoken: String) -> (hour: Int, minute: Int)? {
        if let match = firstMatch(
            in: spoken,
            pattern: "(?:\\b(?:at|в)\\s+)?(\\d{1,2})[:.\\-](\\d{2})(?:\\s*(am|pm))?"
        ) {
            guard let hour = Int(match.values[0]), let minute = Int(match.values[1]) else { return nil }
            let marker = match.values.count >= 3 ? match.values[2] : nil
            return clock(hour: hour, minute: minute, marker: marker)
        }

        if let named = namedHour(in: spoken) {
            return named
        }

        if let english = englishClock(in: spoken) {
            return english
        }

        if let match = firstMatch(in: spoken, pattern: "в\\s+(\\d{1,2})(?!\\d)") {
            guard let hour = Int(match.values[0]), (0...23).contains(hour) else { return nil }
            if (1...11).contains(hour), !spoken.contains("утра"), !spoken.contains("дня"),
               !spoken.contains("вечера"), !spoken.contains("ночи") {
                return nil
            }
            return (applyPeriod(hour, spoken: spoken), 0)
        }
        return nil
    }

    private static func namedHour(in spoken: String) -> (hour: Int, minute: Int)? {
        let words = [
            "час": 1, "два": 2, "три": 3, "четыре": 4, "пять": 5, "шесть": 6,
            "семь": 7, "восемь": 8, "девять": 9, "десять": 10,
            "одиннадцать": 11, "двенадцать": 12
        ]
        guard spoken.contains(" в ") || spoken.hasPrefix("в ") else { return nil }
        for (word, hour) in words.sorted(by: { $0.key.count > $1.key.count }) {
            let pattern = "(^|\\s)в\\s+\(word)(\\s+час[аов]*)?(\\s|$)"
            if spoken.range(of: pattern, options: .regularExpression) != nil {
                let resolved = applyPeriod(hour, spoken: spoken)
                if word == "час", !hasPeriod(spoken), hour == 1 {
                    return nil
                }
                return (resolved, 0)
            }
        }
        return nil
    }

    private static func englishClock(in spoken: String) -> (hour: Int, minute: Int)? {
        if let match = firstMatch(in: spoken, pattern: "\\b(?:at\\s+)?(\\d{1,2})\\s*(am|pm)\\b"),
           let hour = Int(match.values[0]),
           match.values.count >= 2 {
            return clock(hour: hour, minute: 0, marker: match.values[1])
        }

        let marker = loosePeriod(in: spoken)
        if let match = firstMatch(in: spoken, pattern: "\\bat\\s+(\\d{1,2})\\b"),
           let hour = Int(match.values[0]) {
            return clock(hour: hour, minute: 0, marker: marker)
        }
        if let match = firstMatch(in: spoken, pattern: "\\b(\\d{1,2})\\s+o'?clock\\b"),
           let hour = Int(match.values[0]) {
            return clock(hour: hour, minute: 0, marker: marker)
        }

        let words = [
            "twelve": 12, "eleven": 11, "ten": 10, "nine": 9, "eight": 8, "seven": 7,
            "six": 6, "five": 5, "four": 4, "three": 3, "two": 2, "one": 1
        ]
        for (word, hour) in words.sorted(by: { $0.key.count > $1.key.count }) {
            let saidAt = spoken.range(of: "\\bat\\s+\(word)\\b", options: .regularExpression) != nil
            let saidPeriod = spoken.range(of: "\\b\(word)\\s+(am|pm)\\b", options: .regularExpression) != nil
            let saidClock = spoken.range(of: "\\b\(word)\\s+o'?clock\\b", options: .regularExpression) != nil
            guard saidAt || saidPeriod || saidClock || spoken == word else { continue }
            let wordMarker = firstMatch(in: spoken, pattern: "\\b\(word)\\s+(am|pm)\\b")?.values.last
            return clock(hour: hour, minute: 0, marker: wordMarker ?? marker)
        }

        if spoken.range(of: "^\\d{1,2}$", options: .regularExpression) != nil, let hour = Int(spoken) {
            return clock(hour: hour, minute: 0, marker: nil)
        }
        return nil
    }

    private static func loosePeriod(in spoken: String) -> String? {
        if spoken.range(of: "\\bpm\\b", options: .regularExpression) != nil { return "pm" }
        if spoken.range(of: "\\bam\\b", options: .regularExpression) != nil { return "am" }
        if spoken.contains("afternoon") || spoken.contains("evening") { return "pm" }
        if spoken.contains("morning") { return "am" }
        return nil
    }

    private static func clock(hour: Int, minute: Int, marker: String?) -> (hour: Int, minute: Int)? {
        guard (0...59).contains(minute) else { return nil }
        let resolved: Int
        switch marker {
        case "am", "morning":
            if hour == 12 {
                resolved = 0
            } else if (0...11).contains(hour) {
                resolved = hour
            } else {
                return nil
            }
        case "pm", "afternoon", "evening":
            if hour == 12 {
                resolved = 12
            } else if (1...11).contains(hour) {
                resolved = hour + 12
            } else {
                return nil
            }
        default:
            guard (0...23).contains(hour) else { return nil }
            resolved = hour
        }
        return (resolved, minute)
    }

    private static func hasPeriod(_ spoken: String) -> Bool {
        spoken.contains("утра") || spoken.contains("дня") || spoken.contains("вечера") || spoken.contains("ночи")
    }

    private static func applyPeriod(_ hour: Int, spoken: String) -> Int {
        if spoken.contains("дня"), hour < 12 { return hour + 12 }
        if spoken.contains("вечера"), hour < 12 { return hour + 12 }
        if spoken.contains("ночи"), hour == 12 { return 0 }
        if spoken.contains("утра"), hour == 12 { return 0 }
        return hour
    }

    private static func firstInt(
        in spoken: String,
        pattern: String
    ) -> (minutes: Int, rest: String)? {
        guard let match = firstMatch(in: spoken, pattern: pattern),
              let value = Int(match.values[0]), value > 0 else { return nil }
        let rest = collapse(spoken.replacingOccurrences(of: match.full, with: " "))
        return (value, rest)
    }

    private static func firstMatch(
        in spoken: String,
        pattern: String
    ) -> (full: String, values: [String])? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(spoken.startIndex..., in: spoken)
        guard let match = regex.firstMatch(in: spoken, range: range) else { return nil }
        let full = Range(match.range, in: spoken).map { String(spoken[$0]) } ?? ""
        var values: [String] = []
        for index in 1..<match.numberOfRanges {
            guard let piece = Range(match.range(at: index), in: spoken) else { continue }
            values.append(String(spoken[piece]))
        }
        return (full, values)
    }

    private static func collapse(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated enum PlanVoiceCatalog {
    static let aliases: [(alias: String, activity: PlanVoiceActivity)] = {
        var rows: [(String, PlanVoiceActivity)] = []
        for entry in entries {
            for alias in entry.aliases {
                rows.append((PlanVoiceTranscript.normalize(alias), entry.activity))
            }
        }
        return rows
    }()

    private static let entries: [(aliases: [String], activity: PlanVoiceActivity)] = [
        entry(["cycling", "вело", "велосипед"], "Cycling", "Workout", 45),
        entry(["running", "бег", "пробежка"], "Running", "Workout", 45),
        entry(["swimming", "плавание", "бассейн"], "Swimming", "Workout", 45),
        entry(["hiking", "хайкинг", "поход"], "Hiking", "Workout", 45),
        entry(["snowboarding", "сноуборд"], "Snowboarding", "Workout", 45),
        entry(["alpine skiing", "лыжи", "горные лыжи"], "Alpine Skiing", "Workout", 45),
        entry(["upper body", "верх тела"], "Upper Body", "Workout", 45),
        entry(["core", "кор", "пресс"], "Core", "Workout", 45),
        entry(["lower body", "низ тела"], "Lower Body", "Workout", 45),
        entry(["full body", "все тело"], "Full Body", "Workout", 45),
        entry(["tennis", "теннис"], "Tennis", "Workout", 45),
        entry(["padel", "падел", "падл"], "Padel", "Workout", 45),
        entry(["squash", "сквош"], "Squash", "Workout", 45),
        entry(["hiit", "интервальная"], "High Intensity Interval Training", "Workout", 45),
        entry(["stretching", "растяжка"], "Stretching", "Recovery", 20),
        entry(["walk", "прогулка", "ходьба"], "Walk", "Recovery", 20),
        entry(["sauna", "сауна"], "Sauna", "Recovery", 20),
        entry(["yoga", "йога"], "Yoga", "Recovery", 20),
        entry(["breathing", "дыхание"], "Breathing", "Recovery", 20),
        entry(["drink water", "вода"], "Drink Water", "Habit", 15),
        entry(["sleep routine", "сон"], "Sleep Routine", "Habit", 15),
        entry(["no screens", "без экрана"], "No Screens", "Habit", 15),
        entry(["morning routine", "утренняя рутина"], "Morning Routine", "Habit", 15)
    ]

    private static func entry(
        _ aliases: [String],
        _ title: String,
        _ type: String,
        _ duration: Int
    ) -> (aliases: [String], activity: PlanVoiceActivity) {
        (aliases, PlanVoiceActivity(
            catalogTitle: title,
            plannerTypeTitle: type,
            defaultDurationMinutes: duration
        ))
    }
}

@MainActor
final class PlanVoiceCommandController: ObservableObject {

    enum Phase: Equatable {
        case idle
        case recording
        case processing
        case clarifying(String)
        case succeeded(String)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var turns: [PlanVoiceChatTurn] = []

    /// True when the assistant asked something and the next pause should answer it.
    var listensForReply: Bool {
        switch phase {
        case .clarifying:
            return true
        case .failed(let text):
            return text == PlanVoiceCommandCopy.conflict
        default:
            return false
        }
    }

    private var pending: PlanVoicePendingDraft?
    private var lastRequest: PlanVoiceCreateRequest?
    private var savedKeys: Set<String> = []
    private var isSaving = false

    func noteRecording() {
        phase = .recording
    }

    func noteDenied() {
        let reply = PlanVoiceCommandCopy.speechDenied
        phase = .failed(reply)
        appendAssistant(reply)
    }

    func endConversation() {
        guard !isSaving else { return }
        pending = nil
        lastRequest = nil
        turns = []
        phase = .idle
    }

    func cancelRecording() {
        if case .recording = phase {
            phase = pending == nil ? .idle : .clarifying(PlanVoiceCommandCopy.question(for: pending?.missing ?? .startTime))
        }
    }

    func submit(
        transcript: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        planningDay: Date
    ) {
        let spoken = PlanVoiceTranscript.normalize(transcript)
        if pending?.utterances.last == spoken {
            return
        }
        guard !spoken.isEmpty else { return }

        appendPerson(transcript)
        phase = .processing
        let interpreted = PlanVoiceCommandInterpreter.interpret(
            transcript: transcript,
            now: now,
            calendar: calendar,
            planningDay: planningDay,
            pending: pending
        )
        pending = interpreted.pending
        switch interpreted.result {
        case .ready(let request):
            if savedKeys.contains(request.idempotencyKey) {
                replyAlreadyPlanned()
                return
            }
            lastRequest = request
            phase = .processing
        case .needsDetail(let field, _):
            let question = questionAfterReply(for: field)
            phase = .clarifying(question)
            appendAssistant(question)
        case .duplicate:
            replyAlreadyPlanned()
        case .unrecognized:
            let reply = PlanVoiceCommandCopy.unrecognized
            phase = .failed(reply)
            appendAssistant(reply)
        }
    }

    /// Call after `submit` when the phase is still processing and a request is ready.
    func readyRequest() -> PlanVoiceCreateRequest? {
        guard case .processing = phase else { return nil }
        return lastRequest
    }

    func noteSaved(_ request: PlanVoiceCreateRequest, now: Date, calendar: Calendar) {
        savedKeys.insert(request.idempotencyKey)
        pending = nil
        lastRequest = request
        isSaving = false
        let reply = PlanVoiceCommandCopy.confirmation(for: request, now: now, calendar: calendar)
        phase = .succeeded(reply)
        appendAssistant(reply)
    }

    func noteSaveFailed(canRetry: Bool) {
        isSaving = false
        let reply = canRetry ? PlanVoiceCommandCopy.saveFailed : PlanVoiceCommandCopy.conflict
        phase = .failed(reply)
        appendAssistant(reply)
        if !canRetry {
            pending?.hour = nil
            pending?.minute = nil
            pending?.missing = .startTime
            lastRequest = nil
        }
    }

    var canRetrySave: Bool {
        if case .failed = phase, let lastRequest, !savedKeys.contains(lastRequest.idempotencyKey) {
            return true
        }
        return false
    }

    func retryRequest() -> PlanVoiceCreateRequest? {
        guard case .failed = phase, let lastRequest, !savedKeys.contains(lastRequest.idempotencyKey) else {
            return nil
        }
        phase = .processing
        return lastRequest
    }

    func beginSave() -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        return true
    }

    func endSave() {
        isSaving = false
    }

    private func questionAfterReply(for field: PlanVoiceMissingField) -> String {
        let standard = PlanVoiceCommandCopy.question(for: field)
        guard field == .startTime else { return standard }
        let again = PlanVoiceCommandCopy.askTimeAgain
        let alreadyAsked = turns.contains { turn in
            turn.speaker == .assistant && (turn.text == standard || turn.text == again)
        }
        return alreadyAsked ? again : standard
    }

    private func replyAlreadyPlanned() {
        let reply = PlanVoiceCommandCopy.alreadyInPlan
        pending = nil
        lastRequest = nil
        phase = .succeeded(reply)
        appendAssistant(reply)
    }

    private func appendPerson(_ transcript: String) {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        turns.append(PlanVoiceChatTurn(speaker: .person, text: text))
    }

    private func appendAssistant(_ text: String) {
        guard !text.isEmpty else { return }
        turns.append(PlanVoiceChatTurn(speaker: .assistant, text: text))
    }
}

enum PlanVoiceCommandCopy {
    static var speechDenied: String { WeekFitLocalizedString("planner.voice.speechDenied") }
    static var unrecognized: String { WeekFitLocalizedString("planner.voice.unrecognized") }
    static var saveFailed: String { WeekFitLocalizedString("planner.voice.saveFailed") }
    static var conflict: String { WeekFitLocalizedString("planner.voice.conflict") }
    static var retry: String { WeekFitLocalizedString("planner.voice.retry") }
    static var listening: String { WeekFitLocalizedString("planner.voice.listening") }
    static var processing: String { WeekFitLocalizedString("planner.voice.processing") }
    static var microphoneLabel: String { WeekFitLocalizedString("planner.voice.mic.a11y") }
    static var assistantTitle: String { WeekFitLocalizedString("planner.voice.assistantTitle") }
    static var greeting: String { WeekFitLocalizedString("planner.voice.greeting") }
    static var alreadyInPlan: String { WeekFitLocalizedString("planner.voice.alreadyInPlan") }
    static var close: String { WeekFitLocalizedString("planner.voice.close") }
    static var speak: String { WeekFitLocalizedString("planner.voice.speak") }
    static var askTimeAgain: String { WeekFitLocalizedString("planner.voice.askTimeAgain") }

    static func question(for field: PlanVoiceMissingField) -> String {
        switch field {
        case .activity:
            return WeekFitLocalizedString("planner.voice.askActivity")
        case .startTime:
            return WeekFitLocalizedString("planner.voice.askTime")
        }
    }

    static func confirmation(
        for request: PlanVoiceCreateRequest,
        now: Date,
        calendar: Calendar
    ) -> String {
        let title = PlannerOptionLocalization.localizedTitle(for: request.catalogTitle)
        let relation = PlanVoiceCommandInterpreter.dayRelation(
            start: request.start,
            now: now,
            calendar: calendar
        )
        let day: String
        switch relation {
        case .today:
            day = WeekFitLocalizedString("planner.voice.day.today")
        case .tomorrow:
            day = WeekFitLocalizedString("planner.voice.day.tomorrow")
        case .dayAfterTomorrow:
            day = WeekFitLocalizedString("planner.voice.day.dayAfter")
        case .other:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = WeekFitCurrentLocale()
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
            day = formatter.string(from: request.start)
        }
        let start = PlanVoiceCommandInterpreter.clock(request.start, calendar: calendar)
        let end = PlanVoiceCommandInterpreter.clock(
            PlanVoiceCommandInterpreter.endDate(
                start: request.start,
                durationMinutes: request.durationMinutes,
                calendar: calendar
            ),
            calendar: calendar
        )
        return String(
            format: WeekFitLocalizedString("planner.voice.addedFormat"),
            title,
            day,
            start,
            end
        )
    }
}
