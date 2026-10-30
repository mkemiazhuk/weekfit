import CryptoKit
import Foundation

struct PlanRealtimeAccess: Decodable, Equatable {
    var enabled: Bool
    var accountId: String
}

struct PlanRealtimeSessionSecret: Decodable, Equatable {
    var value: String
    var model: String
    var idleSeconds: Int
    var managed: Bool? = nil
    var sessionId: String? = nil
    var budgetSeconds: Int? = nil
}

enum PlanRealtimeMayaMemory {
    private static let key = "planner.voice.maya.introduced"

    static var introduced: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markIntroduced() {
        UserDefaults.standard.set(true, forKey: key)
    }
}

struct PlanRealtimeLine: Decodable, Equatable {
    var ticket: String
    var state: String
    var position: Int
}

struct PlanRealtimeCommit: Decodable, Equatable {
    var ok: Bool?
    var saved: Bool
    var duplicate: Bool?
    var error: String?
    var speak: String?
    var activity: Activity?

    struct Activity: Decodable, Equatable {
        var catalogTitle: String
        var plannerTypeTitle: String
        var durationMinutes: Int
        var start: String
        var idempotencyKey: String
    }
}

nonisolated struct PlanRealtimeToolReply: Equatable {
    var ok: Bool
    var saved: Bool
    var speak: String?
    var error: String?

    var jsonObject: [String: Any] {
        var body: [String: Any] = ["ok": ok, "saved": saved]
        if let speak { body["speak"] = speak }
        if let error { body["error"] = error }
        return body
    }
}

nonisolated enum PlanRealtimeLocalAction: Equatable {
    case insert
    case alreadyPresent
    case reject(String)
}

nonisolated enum PlanRealtimeTransportStep: Equatable {
    case lookup
    case post
}

nonisolated func planRealtimeIdempotencyKey(_ callId: String) -> String {
    if callId.range(of: "^[A-Za-z0-9_-]{8,80}$", options: .regularExpression) != nil {
        return callId
    }
    let digest = SHA256.hash(data: Data(callId.utf8))
    let hex = digest.map { String(format: "%02x", $0) }.joined()
    return "c\(hex.prefix(20))"
}

nonisolated func planRealtimeLocalAction(
    saved: Bool,
    alreadyApplied: Bool,
    alreadyOnPlan: Bool,
    error: String?
) -> PlanRealtimeLocalAction {
    guard saved else { return .reject(error ?? "save_failed") }
    if alreadyApplied || alreadyOnPlan { return .alreadyPresent }
    return .insert
}

nonisolated func planRealtimeToolReply(
    action: PlanRealtimeLocalAction,
    speak: String?
) -> PlanRealtimeToolReply {
    switch action {
    case .insert, .alreadyPresent:
        return PlanRealtimeToolReply(ok: true, saved: true, speak: speak, error: nil)
    case .reject(let error):
        let spoken = error == "time_conflict"
            || error == "start_time_required"
            || error == "unknown_activity"
        return PlanRealtimeToolReply(ok: false, saved: false, speak: spoken ? speak : nil, error: error)
    }
}

nonisolated func planRealtimeTransportStep(transportFailed: Bool, lookedUp: Bool) -> PlanRealtimeTransportStep {
    transportFailed && !lookedUp ? .lookup : .post
}

nonisolated struct PlanRealtimeCallGate {
    enum Begin: Equatable {
        case start
        case wait
        case replay(String)
    }

    private var inflight = Set<String>()
    private var finished: [String: String] = [:]

    mutating func begin(_ callId: String) -> Begin {
        if let reply = finished[callId] { return .replay(reply) }
        if inflight.contains(callId) { return .wait }
        inflight.insert(callId)
        return .start
    }

    mutating func finish(_ callId: String, reply: String) {
        inflight.remove(callId)
        finished[callId] = reply
    }
}

nonisolated struct PlanRealtimeActivityDraft: Equatable {
    var catalogTitle: String
    var date: String
    var startTime: String
    var durationMinutes: Int
}

nonisolated struct PlanRealtimeSourceActivity: Equatable {
    var id: String
    var title: String
    var date: Date
    var durationMinutes: Int
    var completed: Bool
    var skipped: Bool
    var voice: Bool
}

nonisolated struct PlanRealtimeAgendaEntry: Equatable {
    var ref: String
    var activityID: String
    var scope: String
    var title: String
    var spoken: String
    var day: String
    var startTime: String
    var durationMinutes: Int
}

nonisolated struct PlanRealtimeRefBook: Equatable {
    private var assigned: [String: String] = [:]
    private var next = 1

    mutating func ref(for id: String) -> String {
        if let existing = assigned[id] { return existing }
        let ref = "a\(next)"
        next += 1
        assigned[id] = ref
        return ref
    }
}

nonisolated struct PlanRealtimeEditDraft: Equatable {
    var ref: String
    var date: String
    var startTime: String
    var durationMinutes: Int
    var catalogTitle: String
}

struct PlanVoiceDayContext: Equatable {
    var recoveryPercent: Int?
    var recoveryBand: String?
    var sleepMinutes: Int?
    var meals: [Meal] = []

    struct Meal: Equatable {
        var title: String
        var time: String
    }

    var isEmpty: Bool {
        recoveryPercent == nil && sleepMinutes == nil && meals.isEmpty
    }

    func jsonObject() -> [String: Any] {
        var recovery: [String: Any] = [:]
        if let recoveryPercent, (1...100).contains(recoveryPercent) {
            recovery["percent"] = recoveryPercent
        }
        if let recoveryBand, ["good", "ok", "need_rest"].contains(recoveryBand), recovery["percent"] != nil {
            recovery["band"] = recoveryBand
        }
        if let sleepMinutes, (1...(24 * 60)).contains(sleepMinutes) {
            recovery["sleepMinutes"] = sleepMinutes
        }
        var body: [String: Any] = [:]
        if !recovery.isEmpty {
            body["recovery"] = recovery
        }
        let rows = meals.prefix(8).map { ["title": $0.title, "time": $0.time] }
        if !rows.isEmpty {
            body["meals"] = rows
        }
        return body
    }
}

nonisolated struct PlanVoiceUpdateRequest: Equatable {
    var activityID: String
    var start: Date
    var durationMinutes: Int
    var catalogTitle: String?
}

enum PlanRealtimeClientError: Error {
    case unauthorized
    case forbidden
    case notFound
    case transport
    case lineFull
    case invalid
}

struct PlanRealtimeClient {
    var baseURL: URL
    var token: String
    var session: URLSession = .shared

    func access() async throws -> PlanRealtimeAccess {
        try await send(method: "GET", path: "v1/planner-voice/access", body: nil)
    }

    func placeInLine() async throws -> PlanRealtimeLine {
        try await send(method: "POST", path: "v1/planner-voice/line", body: [:])
    }

    func beatLine(ticket: String) async {
        await postLine(path: "v1/planner-voice/line/beat", ticket: ticket)
    }

    func leaveLine(ticket: String) async {
        await postLine(path: "v1/planner-voice/line/release", ticket: ticket)
    }

    func openSession(
        timeZone: String,
        now: Date,
        planningDay: String,
        givenName: String,
        language: String,
        plan: [[String: Any]],
        dayContext: [String: Any] = [:],
        ticket: String,
        introduced: Bool,
        reconnected: Bool = false
    ) async throws -> PlanRealtimeSessionSecret {
        var body: [String: Any] = [
            "ticket": ticket,
            "timeZone": timeZone,
            "now": ISO8601DateFormatter().string(from: now),
            "planningDay": planningDay,
            "givenName": givenName,
            "language": language,
            "plan": plan,
            "introduced": introduced,
            "reconnected": reconnected,
        ]
        if !dayContext.isEmpty {
            body["dayContext"] = dayContext
        }
        if WeekFitAIBilling.enabled {
            body["idempotencyKey"] = UUID().uuidString
            return try await WeekFitAIClient(baseURL: baseURL).request(path: "v2/ai/voice/session",
                body: JSONSerialization.data(withJSONObject: body))
        }
        return try await send(
            method: "POST",
            path: "v1/planner-voice/session",
            body: body
        )
    }

    private func postLine(path: String, ticket: String) async {
        var request = URLRequest(url: baseURL.appending(path: path))
        if WeekFitAIBilling.enabled {
            request.setValue(WeekFitAIBilling.environment, forHTTPHeaderField: "X-WeekFit-Billing-Environment")
        }
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["ticket": ticket])
        _ = try? await session.data(for: request)
    }

    func commit(_ body: [String: Any]) async throws -> PlanRealtimeCommit {
        try await send(method: "POST", path: "v1/planner-voice/activities", body: body)
    }

    func lookup(idempotencyKey: String) async throws -> PlanRealtimeCommit {
        let url = baseURL
            .appending(path: "v1/planner-voice/activities")
            .appending(queryItems: [URLQueryItem(name: "idempotencyKey", value: idempotencyKey)])
        return try await send(method: "GET", url: url, body: nil)
    }

    func reportUsage(responseId: String, inputTokens: Int, outputTokens: Int) async {
        let body: [String: Any] = [
            "responseId": responseId,
            "inputTokens": inputTokens,
            "outputTokens": outputTokens,
        ]
        var request = URLRequest(url: baseURL.appending(path: "v1/planner-voice/usage"))
        if WeekFitAIBilling.enabled {
            request.setValue(WeekFitAIBilling.environment, forHTTPHeaderField: "X-WeekFit-Billing-Environment")
        }
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await session.data(for: request)
    }

    private func send<Response: Decodable>(
        method: String,
        path: String,
        body: [String: Any]?
    ) async throws -> Response {
        try await send(method: method, url: baseURL.appending(path: path), body: body)
    }

    private func send<Response: Decodable>(
        method: String,
        url: URL,
        body: [String: Any]?
    ) async throws -> Response {
        var request = URLRequest(url: url)
        if WeekFitAIBilling.enabled {
            request.setValue(WeekFitAIBilling.environment, forHTTPHeaderField: "X-WeekFit-Billing-Environment")
        }
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if WeekFitAIBilling.enabled && url.path == "/v1/planner-voice/line" {
            guard let proof = await WeekFitAIProof.subscriptionJWS() else {
                throw WeekFitAIUsageError.subscriptionRequired
            }
            request.setValue(proof, forHTTPHeaderField: "X-WeekFit-Subscription-JWS")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PlanRealtimeClientError.transport
        }
        guard let http = response as? HTTPURLResponse else { throw PlanRealtimeClientError.invalid }
        if WeekFitAIBilling.enabled && http.statusCode == 402 { throw WeekFitAIUsageError.subscriptionRequired }
        if http.statusCode == 401 { throw PlanRealtimeClientError.unauthorized }
        if http.statusCode == 403 { throw PlanRealtimeClientError.forbidden }
        if http.statusCode == 404 { throw PlanRealtimeClientError.notFound }
        if http.statusCode == 503 { throw PlanRealtimeClientError.lineFull }
        if !(200...299).contains(http.statusCode) {
            if let decoded = try? JSONDecoder().decode(Response.self, from: data) {
                return decoded
            }
            throw PlanRealtimeClientError.invalid
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw PlanRealtimeClientError.invalid
        }
    }
}

nonisolated func planRealtimeAgenda(
    _ sources: [PlanRealtimeSourceActivity],
    now: Date,
    calendar: Calendar,
    book: inout PlanRealtimeRefBook,
    spoken: (String) -> String
) -> [PlanRealtimeAgendaEntry] {
    let today = calendar.startOfDay(for: now)
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
    let visible = sources
        .filter { $0.voice && !$0.skipped }
        .sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.id < rhs.id
        }
    var rows: [PlanRealtimeAgendaEntry] = []
    for source in visible {
        let scope: String
        if calendar.isDate(source.date, inSameDayAs: today) {
            scope = source.completed ? "today_done" : "today_planned"
        } else if calendar.isDate(source.date, inSameDayAs: tomorrow), !source.completed {
            scope = "tomorrow"
        } else {
            continue
        }
        let parts = calendar.dateComponents([.hour, .minute], from: source.date)
        rows.append(PlanRealtimeAgendaEntry(
            ref: book.ref(for: source.id),
            activityID: source.id,
            scope: scope,
            title: source.title,
            spoken: spoken(source.title),
            day: planRealtimeDayString(source.date, calendar: calendar),
            startTime: String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0),
            durationMinutes: max(source.durationMinutes, 1)
        ))
        if rows.count == 24 { break }
    }
    return rows
}

nonisolated func planRealtimeListScope(_ arguments: String) -> String? {
    guard let object = planRealtimeJSON(arguments),
          let scope = object["scope"] as? String,
          ["today_done", "tomorrow", "today_planned"].contains(scope) else { return nil }
    return scope
}

nonisolated func planRealtimeEditDraft(_ arguments: String) -> PlanRealtimeEditDraft? {
    guard let object = planRealtimeJSON(arguments),
          let ref = object["ref"] as? String,
          ref.range(of: "^a[1-9][0-9]{0,2}$", options: .regularExpression) != nil else { return nil }
    return PlanRealtimeEditDraft(
        ref: ref,
        date: object["date"] as? String ?? "",
        startTime: object["startTime"] as? String ?? "",
        durationMinutes: object["durationMinutes"] as? Int ?? 0,
        catalogTitle: object["catalogTitle"] as? String ?? ""
    )
}

nonisolated func planRealtimeDeleteRef(_ arguments: String) -> String? {
    guard let object = planRealtimeJSON(arguments),
          let ref = object["ref"] as? String,
          ref.range(of: "^a[1-9][0-9]{0,2}$", options: .regularExpression) != nil else { return nil }
    return ref
}

nonisolated func planRealtimeMergedStart(
    day: String,
    time: String,
    original: Date,
    calendar: Calendar
) -> Date? {
    let dayText = day.isEmpty ? planRealtimeDayString(original, calendar: calendar) : day
    let originalParts = calendar.dateComponents([.hour, .minute], from: original)
    let timeText = time.isEmpty
        ? String(format: "%02d:%02d", originalParts.hour ?? 0, originalParts.minute ?? 0)
        : time
    guard dayText.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
          timeText.range(of: #"^([01]\d|2[0-3]):[0-5]\d$"#, options: .regularExpression) != nil else { return nil }
    let dateParts = dayText.split(separator: "-").compactMap { Int($0) }
    let timeParts = timeText.split(separator: ":").compactMap { Int($0) }
    guard dateParts.count == 3, timeParts.count == 2 else { return nil }
    var parts = DateComponents()
    parts.calendar = calendar
    parts.timeZone = calendar.timeZone
    parts.year = dateParts[0]
    parts.month = dateParts[1]
    parts.day = dateParts[2]
    parts.hour = timeParts[0]
    parts.minute = timeParts[1]
    return calendar.date(from: parts)
}

nonisolated func planRealtimeListSpeak(
    scope: String,
    items: [(spoken: String, startTime: String)],
    language: String
) -> String {
    let code = planRealtimeSpeechLanguage(language)
    let copy = planRealtimeSpeech[code] ?? planRealtimeSpeech["ru"]!
    if items.isEmpty {
        switch scope {
        case "tomorrow": return copy.tomorrowEmpty
        case "today_planned": return copy.todayPlannedEmpty
        default: return copy.todayDoneEmpty
        }
    }
    let shown = items.prefix(6).map { "\($0.spoken) \($0.startTime)" }.joined(separator: ", ")
    let lead = scope == "tomorrow" ? copy.tomorrowLead : (scope == "today_planned" ? copy.todayPlannedLead : copy.todayDoneLead)
    let extra = items.count > 6 ? " \(copy.more(items.count - 6))" : ""
    return lead + shown + extra
}

nonisolated func planRealtimeMovedSpeak(spoken: String, day: String, time: String, language: String) -> String {
    let copy = planRealtimeSpeech[planRealtimeSpeechLanguage(language)] ?? planRealtimeSpeech["ru"]!
    return copy.moved(spoken, day, time)
}

nonisolated func planRealtimeRemovedSpeak(spoken: String, day: String, language: String) -> String {
    let copy = planRealtimeSpeech[planRealtimeSpeechLanguage(language)] ?? planRealtimeSpeech["ru"]!
    return copy.removed(spoken, day)
}

nonisolated func planRealtimePlanNotice(_ kind: String, language: String) -> String {
    let copy = planRealtimeSpeech[planRealtimeSpeechLanguage(language)] ?? planRealtimeSpeech["ru"]!
    switch kind {
    case "already_done": return copy.alreadyDone
    case "unchanged": return copy.unchanged
    case "conflict": return copy.conflict
    default: return copy.missing
    }
}

nonisolated func planRealtimeDayLabel(
    day: String,
    today: String,
    tomorrow: String,
    language: String,
    calendar: Calendar
) -> String {
    let copy = planRealtimeSpeech[planRealtimeSpeechLanguage(language)] ?? planRealtimeSpeech["ru"]!
    if day == today { return copy.today }
    if day == tomorrow { return copy.tomorrow }
    guard let date = planRealtimeMergedStart(day: day, time: "12:00", original: Date(), calendar: calendar) else {
        return day
    }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: planRealtimeSpeechLanguage(language))
    formatter.setLocalizedDateFormatFromTemplate("d MMMM")
    return formatter.string(from: date)
}

private func planRealtimeJSON(_ arguments: String) -> [String: Any]? {
    guard let data = arguments.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
}

private func planRealtimeSpeechLanguage(_ language: String) -> String {
    planRealtimeSpeech[language] == nil ? "ru" : language
}

private struct PlanRealtimeSpeechCopy {
    var today: String
    var tomorrow: String
    var todayDoneEmpty: String
    var todayPlannedEmpty: String
    var tomorrowEmpty: String
    var todayDoneLead: String
    var todayPlannedLead: String
    var tomorrowLead: String
    var alreadyDone: String
    var missing: String
    var unchanged: String
    var conflict: String
    var moved: (String, String, String) -> String
    var removed: (String, String) -> String
    var more: (Int) -> String
}

private let planRealtimeSpeech: [String: PlanRealtimeSpeechCopy] = [
    "ru": .init(
        today: "сегодня", tomorrow: "завтра",
        todayDoneEmpty: "Сегодня ничего не отмечено как сделанное.",
        todayPlannedEmpty: "На сегодня ничего не запланировано.",
        tomorrowEmpty: "На завтра ничего не запланировано.",
        todayDoneLead: "Сегодня сделано: ", todayPlannedLead: "На сегодня ещё: ", tomorrowLead: "На завтра: ",
        alreadyDone: "Это уже сделано, я его не убираю.",
        missing: "Не нашла эту активность.",
        unchanged: "Оставила как есть.",
        conflict: "На это время уже что-то стоит. Выберем другое?",
        moved: { spoken, day, time in "Перенесла \(spoken) на \(day), на \(time)." },
        removed: { spoken, day in "Убрала \(spoken) на \(day)." },
        more: { count in "и ещё \(count)." }
    ),
    "en": .init(
        today: "today", tomorrow: "tomorrow",
        todayDoneEmpty: "Nothing is marked done today.",
        todayPlannedEmpty: "Nothing else is planned for today.",
        tomorrowEmpty: "Nothing is planned for tomorrow.",
        todayDoneLead: "Done today: ", todayPlannedLead: "Still planned today: ", tomorrowLead: "Tomorrow: ",
        alreadyDone: "That's already done, so I'm leaving it.",
        missing: "I can't find that activity.",
        unchanged: "I left it as it is.",
        conflict: "Something is already there then. Want another time?",
        moved: { spoken, day, time in "I moved \(spoken) to \(day) at \(time)." },
        removed: { spoken, day in "I removed \(spoken) on \(day)." },
        more: { count in "and \(count) more." }
    ),
    "pl": .init(
        today: "dzisiaj", tomorrow: "jutro",
        todayDoneEmpty: "Dziś nic nie jest oznaczone jako zrobione.",
        todayPlannedEmpty: "Na dziś nic więcej nie jest zaplanowane.",
        tomorrowEmpty: "Na jutro nic nie jest zaplanowane.",
        todayDoneLead: "Dziś zrobione: ", todayPlannedLead: "Na dziś jeszcze: ", tomorrowLead: "Na jutro: ",
        alreadyDone: "To już jest zrobione, więc tego nie usuwam.",
        missing: "Nie znalazłam tej aktywności.",
        unchanged: "Zostawiłam bez zmian.",
        conflict: "Ta godzina jest już zajęta. Wybierzemy inną?",
        moved: { spoken, day, time in "Przeniosłam \(spoken) na \(day), na \(time)." },
        removed: { spoken, day in "Usunęłam \(spoken) na \(day)." },
        more: { count in "i jeszcze \(count)." }
    ),
    "fr": .init(
        today: "aujourd'hui", tomorrow: "demain",
        todayDoneEmpty: "Rien n'est marqué comme fait aujourd'hui.",
        todayPlannedEmpty: "Rien d'autre n'est prévu aujourd'hui.",
        tomorrowEmpty: "Rien n'est prévu pour demain.",
        todayDoneLead: "Fait aujourd'hui : ", todayPlannedLead: "Encore prévu aujourd'hui : ", tomorrowLead: "Demain : ",
        alreadyDone: "C'est déjà fait, je le laisse.",
        missing: "Je ne trouve pas cette activité.",
        unchanged: "Je l'ai laissée telle quelle.",
        conflict: "Ce créneau est déjà pris.",
        moved: { spoken, day, time in "J'ai déplacé \(spoken) à \(day), à \(time)." },
        removed: { spoken, day in "J'ai retiré \(spoken) \(day)." },
        more: { count in "et \(count) de plus." }
    ),
    "es": .init(
        today: "hoy", tomorrow: "mañana",
        todayDoneEmpty: "Hoy no hay nada marcado como hecho.",
        todayPlannedEmpty: "No queda nada planeado para hoy.",
        tomorrowEmpty: "No hay nada planeado para mañana.",
        todayDoneLead: "Hecho hoy: ", todayPlannedLead: "Todavía planeado hoy: ", tomorrowLead: "Mañana: ",
        alreadyDone: "Eso ya está hecho, así que lo dejo.",
        missing: "No encuentro esa actividad.",
        unchanged: "Lo dejé como está.",
        conflict: "Esa hora ya está ocupada.",
        moved: { spoken, day, time in "Pasé \(spoken) a \(day), a las \(time)." },
        removed: { spoken, day in "Quité \(spoken) de \(day)." },
        more: { count in "y \(count) más." }
    ),
    "de": .init(
        today: "heute", tomorrow: "morgen",
        todayDoneEmpty: "Heute ist nichts als erledigt markiert.",
        todayPlannedEmpty: "Für heute ist sonst nichts geplant.",
        tomorrowEmpty: "Für morgen ist nichts geplant.",
        todayDoneLead: "Heute erledigt: ", todayPlannedLead: "Heute noch geplant: ", tomorrowLead: "Morgen: ",
        alreadyDone: "Das ist schon erledigt, das lasse ich.",
        missing: "Diese Aktivität finde ich nicht.",
        unchanged: "Ich habe es gelassen.",
        conflict: "Diese Zeit ist schon belegt.",
        moved: { spoken, day, time in "Ich habe \(spoken) auf \(day) um \(time) verschoben." },
        removed: { spoken, day in "Ich habe \(spoken) am \(day) entfernt." },
        more: { count in "und \(count) weitere." }
    ),
    "it": .init(
        today: "oggi", tomorrow: "domani",
        todayDoneEmpty: "Oggi non c'è niente segnato come fatto.",
        todayPlannedEmpty: "Per oggi non c'è altro in programma.",
        tomorrowEmpty: "Per domani non c'è niente in programma.",
        todayDoneLead: "Fatto oggi: ", todayPlannedLead: "Ancora in programma oggi: ", tomorrowLead: "Domani: ",
        alreadyDone: "Questo è già fatto, quindi lo lascio.",
        missing: "Non trovo questa attività.",
        unchanged: "L'ho lasciata com'era.",
        conflict: "Quell'orario è già occupato.",
        moved: { spoken, day, time in "Ho spostato \(spoken) a \(day), alle \(time)." },
        removed: { spoken, day in "Ho tolto \(spoken) di \(day)." },
        more: { count in "e altri \(count)." }
    ),
    "ja": .init(
        today: "今日", tomorrow: "明日",
        todayDoneEmpty: "今日は完了したアクティビティがありません。",
        todayPlannedEmpty: "今日はこのあと予定がありません。",
        tomorrowEmpty: "明日の予定はありません。",
        todayDoneLead: "今日やったこと: ", todayPlannedLead: "今日の残り: ", tomorrowLead: "明日: ",
        alreadyDone: "これはもう完了しているので、消しません。",
        missing: "そのアクティビティが見つかりません。",
        unchanged: "そのままでにしました。",
        conflict: "その時間はすでに埋まっています。",
        moved: { spoken, day, time in "\(spoken)を\(day)の\(time)に移しました。" },
        removed: { spoken, day in "\(day)の\(spoken)を外しました。" },
        more: { count in "ほか\(count)件。" }
    ),
    "ko": .init(
        today: "오늘", tomorrow: "내일",
        todayDoneEmpty: "오늘 완료된 활동이 없어요.",
        todayPlannedEmpty: "오늘 남은 예정이 없어요.",
        tomorrowEmpty: "내일 예정된 활동이 없어요.",
        todayDoneLead: "오늘 한 일: ", todayPlannedLead: "오늘 남은 일정: ", tomorrowLead: "내일: ",
        alreadyDone: "이미 완료된 일이라 지우지 않을게요.",
        missing: "그 활동을 찾지 못했어요.",
        unchanged: "그대로 두었어요.",
        conflict: "그 시간은 이미 차 있어요.",
        moved: { spoken, day, time in "\(spoken)을 \(day) \(time)으로 옮겼어요." },
        removed: { spoken, day in "\(day) \(spoken)을 지웠어요." },
        more: { count in "외 \(count)개." }
    ),
    "zh-Hans": .init(
        today: "今天", tomorrow: "明天",
        todayDoneEmpty: "今天没有标成已完成的活动。",
        todayPlannedEmpty: "今天没有其他安排。",
        tomorrowEmpty: "明天没有安排。",
        todayDoneLead: "今天完成的：", todayPlannedLead: "今天还要做的：", tomorrowLead: "明天：",
        alreadyDone: "这项已经完成了，我不删。",
        missing: "没有找到这项活动。",
        unchanged: "保持原样。",
        conflict: "这个时间已经有安排了。",
        moved: { spoken, day, time in "把\(spoken)改到\(day) \(time)。" },
        removed: { spoken, day in "去掉了\(day)的\(spoken)。" },
        more: { count in "还有\(count)项。" }
    ),
]
