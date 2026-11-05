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

enum PlanVoiceEngine {
    static let storageKey = "planner.voice.engine"

    static var current: String {
        UserDefaults.standard.string(forKey: storageKey) == "live" ? "live" : "realtime"
    }

    static func choose(_ engine: String) {
        UserDefaults.standard.set(engine == "live" ? "live" : "realtime", forKey: storageKey)
    }

    static var alternate: String { current == "live" ? "realtime" : "live" }
}

func planRealtimeLiveChangeAllowed(day: String, today: String, start: Date?, now: Date) -> Bool {
    if !day.isEmpty, day != today { return false }
    if let start, start.timeIntervalSince(now) < -60 { return false }
    return true
}

func planVoiceEngineOffer(_ engine: String, language: String) -> String {
    let live = engine == "live"
    switch language {
    case "ru": return live ? "Начать через Live" : "Начать через Realtime"
    case "pl": return live ? "Zacznij przez Live" : "Zacznij przez Realtime"
    case "fr": return live ? "Commencer avec Live" : "Commencer avec Realtime"
    case "es": return live ? "Empezar con Live" : "Empezar con Realtime"
    case "de": return live ? "Mit Live starten" : "Mit Realtime starten"
    case "it": return live ? "Inizia con Live" : "Inizia con Realtime"
    case "ja": return live ? "Liveで始める" : "Realtimeで始める"
    case "ko": return live ? "Live로 시작" : "Realtime으로 시작"
    case "zh-Hans": return live ? "用 Live 开始" : "用 Realtime 开始"
    default: return live ? "Start with Live" : "Start with Realtime"
    }
}

func planVoiceLanguageSwitch(_ language: String) -> String {
    switch language {
    case "ru": return "Дальше говорю на выбранном языке. Язык приложения не меняю."
    case "pl": return "Dalej mówię w wybranym języku. Języka aplikacji nie zmieniam."
    case "fr": return "Je continue dans la langue choisie. La langue de l'app ne change pas."
    case "es": return "Sigo en el idioma elegido. El idioma de la app no cambia."
    case "de": return "Ich spreche weiter in der gewählten Sprache. Die App-Sprache bleibt."
    case "it": return "Continuo nella lingua scelta. La lingua dell'app non cambia."
    case "ja": return "この通話はこの言語で続ける。アプリの言語は変えない。"
    case "ko": return "이 통화는 고른 언어로 이어갈게. 앱 언어는 바꾸지 않아."
    case "zh-Hans": return "这通电话接下来用这个语言。应用语言不变。"
    default: return "I'll speak that language for the rest of this call. The app language stays as it is."
    }
}
func planVoiceEngineTitle(_ language: String) -> String {
    switch language {
    case "ru": return "Голосовой помощник"
    case "pl": return "Asystent głosowy"
    case "fr": return "Assistant vocal"
    case "es": return "Asistente de voz"
    case "de": return "Sprachassistent"
    case "it": return "Assistente vocale"
    case "ja": return "音声アシスタント"
    case "ko": return "음성 도우미"
    case "zh-Hans": return "语音助手"
    default: return "Voice assistant"
    }
}

func planVoiceEngineFootnote(_ language: String) -> String {
    switch language {
    case "ru": return "Действует со следующего звонка. Текущий звонок не переключается."
    case "pl": return "Zadziała od następnej rozmowy. Trwająca rozmowa się nie zmienia."
    case "fr": return "S'applique au prochain appel. L'appel en cours ne change pas."
    case "es": return "Se aplica a la próxima llamada. La llamada actual no cambia."
    case "de": return "Gilt ab dem nächsten Anruf. Der laufende Anruf bleibt."
    case "it": return "Vale dalla prossima chiamata. La chiamata in corso non cambia."
    case "ja": return "次の通話から有効。今の通話は切り替わらない。"
    case "ko": return "다음 통화부터 적용돼. 진행 중인 통화는 바뀌지 않아."
    case "zh-Hans": return "从下一通电话开始生效。当前通话不会切换。"
    default: return "Applies to the next call. The current call does not switch."
    }
}

func planVoiceEngineLimit(language: String, past: Bool) -> String {
    switch language {
    case "ru": return past ? "Это время уже прошло. Назови сегодняшнее время, которое ещё впереди." : "В этом звонке я меняю только сегодняшний план."
    case "pl": return past ? "Ta godzina już minęła. Podaj późniejszą godzinę dzisiaj." : "W tej rozmowie zmieniam tylko dzisiejszy plan."
    case "fr": return past ? "Cette heure est déjà passée. Donne une heure plus tard aujourd'hui." : "Dans cet appel, je ne change que le plan d'aujourd'hui."
    case "es": return past ? "Esa hora ya pasó. Di una hora de hoy que todavía no haya pasado." : "En esta llamada solo cambio el plan de hoy."
    case "de": return past ? "Diese Uhrzeit ist vorbei. Nenne eine spätere Zeit heute." : "In diesem Anruf ändere ich nur den Plan von heute."
    case "it": return past ? "Quell'orario è già passato. Dimmi un orario di oggi ancora avanti." : "In questa chiamata cambio solo il piano di oggi."
    case "ja": return past ? "その時間は過ぎている。今日のこれからの時間を言って。" : "この通話で変えるのは今日の予定だけ。"
    case "ko": return past ? "그 시간은 이미 지났어. 오늘 남은 시간을 말해 줘." : "이 통화에서는 오늘 계획만 바꿔."
    case "zh-Hans": return past ? "这个时间已经过了。说一个今天还没到的时间。" : "这通电话只改今天的计划。"
    default: return past ? "That time has already passed. Give me a later time today." : "In this call I only change today's plan."
    }
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
    var schedule: [PlanRealtimeScheduleRow] = []

    var jsonObject: [String: Any] {
        var body: [String: Any] = ["ok": ok, "saved": saved]
        if let speak { body["speak"] = speak }
        if let error { body["error"] = error }
        if !schedule.isEmpty {
            body["items"] = schedule.map {
                var row: [String: Any] = [
                    "ref": $0.ref,
                    "title": $0.title,
                    "startTime": $0.startTime,
                    "durationMinutes": $0.durationMinutes,
                    "done": $0.done,
                ]
                if !$0.catalogTitle.isEmpty {
                    row["catalogTitle"] = $0.catalogTitle
                }
                return row
            }
        }
        return body
    }
}

nonisolated struct PlanRealtimeScheduleRow: Equatable {
    var ref: String
    var title: String
    var catalogTitle: String = ""
    var startTime: String
    var durationMinutes: Int
    var done: Bool
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
    var place: String = ""
    var anchorRef: String = ""
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
    var nutrition = Nutrition()
    var training: [Training] = []

    struct Meal: Equatable {
        var title: String
        var time: String
    }

    struct Nutrition: Equatable {
        var caloriesEaten: Int?
        var caloriesBudget: Int?
        var proteinGrams: Int?
        var proteinGoalGrams: Int?
        var carbsGrams: Int?
        var carbsGoalGrams: Int?
        var fatGrams: Int?
        var fatGoalGrams: Int?
        var goal: String?
        var waterMilliliters: Int?
        var waterGoalMilliliters: Int?
    }

    struct Training: Equatable {
        var title: String
        var minutes: Int
        var done: Bool
    }

    var isEmpty: Bool {
        recoveryPercent == nil && sleepMinutes == nil && meals.isEmpty && nutrition.isEmpty && training.isEmpty
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
        let nutrition = nutrition.jsonObject()
        if !nutrition.isEmpty {
            body["nutrition"] = nutrition
        }
        body["training"] = training.prefix(4).map {
            ["title": $0.title, "minutes": $0.minutes, "done": $0.done]
        }
        return body
    }
}

private extension PlanVoiceDayContext.Nutrition {
    var isEmpty: Bool {
        caloriesEaten == nil && caloriesBudget == nil && proteinGrams == nil
            && proteinGoalGrams == nil && carbsGrams == nil && carbsGoalGrams == nil
            && fatGrams == nil && fatGoalGrams == nil && goal == nil
            && waterMilliliters == nil && waterGoalMilliliters == nil
    }

    func jsonObject() -> [String: Any] {
        var body: [String: Any] = [:]
        if let caloriesEaten { body["caloriesEaten"] = caloriesEaten }
        if let caloriesBudget { body["caloriesBudget"] = caloriesBudget }
        if let proteinGrams { body["proteinGrams"] = proteinGrams }
        if let proteinGoalGrams { body["proteinGoalGrams"] = proteinGoalGrams }
        if let carbsGrams { body["carbsGrams"] = carbsGrams }
        if let carbsGoalGrams { body["carbsGoalGrams"] = carbsGoalGrams }
        if let fatGrams { body["fatGrams"] = fatGrams }
        if let fatGoalGrams { body["fatGoalGrams"] = fatGoalGrams }
        if let goal, ["lose", "maintain", "gain"].contains(goal) { body["goal"] = goal }
        if let waterMilliliters { body["waterMilliliters"] = waterMilliliters }
        if let waterGoalMilliliters { body["waterGoalMilliliters"] = waterGoalMilliliters }
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
        reconnected: Bool = false,
        addressee: String = "unknown"
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
            "addressee": addressee == "male" || addressee == "female" ? addressee : "unknown",
            "engine": PlanVoiceEngine.current,
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

nonisolated func planRealtimeCallLanguage(_ arguments: String) -> String? {
    let allowed = ["ru", "en", "zh-Hans", "ko", "ja", "de", "it", "pl", "fr", "es"]
    guard let object = planRealtimeJSON(arguments),
          let language = object["language"] as? String,
          allowed.contains(language) else { return nil }
    return language
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
    let shown = items.prefix(6).map {
        "\($0.spoken) \(planRealtimeSpokenClock($0.startTime, language: code))"
    }.joined(separator: ", ")
    let lead = scope == "tomorrow" ? copy.tomorrowLead : (scope == "today_planned" ? copy.todayPlannedLead : copy.todayDoneLead)
    let extra = items.count > 6 ? " \(copy.more(items.count - 6))" : ""
    return lead + shown + extra
}

private func russianSpokenTime(hour: Int, minute: Int) -> String {
    if hour == 0 && minute == 0 { return "полночь" }
    if hour == 12 && minute == 0 { return "полдень" }
    let names = ["двенадцать", "час", "два часа", "три часа", "четыре часа", "пять", "шесть", "семь", "восемь", "девять", "десять", "одиннадцать"]
    let period = hour < 12 ? "утра" : (hour < 17 ? "дня" : "вечера")
    let name = names[hour % 12]
    let minuteWords = russianMinuteWords(minute)
    return minuteWords.isEmpty ? "\(name) \(period)" : "\(name) \(minuteWords) \(period)"
}

private func russianMinuteWords(_ minute: Int) -> String {
    if minute == 0 { return "" }
    let under = ["", "один", "два", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять", "десять", "одиннадцать", "двенадцать", "тринадцать", "четырнадцать", "пятнадцать", "шестнадцать", "семнадцать", "восемнадцать", "девятнадцать"]
    if minute < 20 { return minute < 10 ? "ноль \(under[minute])" : under[minute] }
    let tens = ["", "", "двадцать", "тридцать", "сорок", "пятьдесят"]
    let one = minute % 10
    let ten = minute / 10
    return one == 0 ? tens[ten] : "\(tens[ten]) \(under[one])"
}

func planRealtimeSaveFingerprint(catalogTitle: String, start: Date, durationMinutes: Int) -> String {
    "\(catalogTitle)|\(Int(start.timeIntervalSince1970.rounded()))|\(durationMinutes)"
}

func planRealtimeReplayReply(reply: String?, savedAt: Date?, now: Date, within seconds: TimeInterval?) -> String? {
    guard let reply, let savedAt else { return nil }
    if let seconds, now.timeIntervalSince(savedAt) > seconds { return nil }
    return reply
}

func planRealtimeWaterReminderEffect() -> (blocksSchedule: Bool, drunkMilliliters: Int) {
    let reminder = PlannedActivity(
        date: Date(),
        type: "habit",
        title: "Drink Water",
        durationMinutes: 5,
        icon: "drop.fill",
        imageName: "habit-water",
        colorRed: 0.2,
        colorGreen: 0.6,
        colorBlue: 0.9,
        isCompleted: false,
        source: "planner"
    )
    return (
        reminder.blocksPlannerTime,
        QuickLogActivityPortions.waterMilliliters(for: reminder)
    )
}

nonisolated func planRealtimeSpokenClock(_ time: String, language: String) -> String {
    let parts = time.split(separator: ":")
    guard parts.count == 2,
          let hour = Int(parts[0]),
          let minute = Int(parts[1]),
          (0...23).contains(hour),
          (0...59).contains(minute) else { return time }
    let clockHour = hour % 12 == 0 ? 12 : hour % 12
    let minutes = minute == 0 ? "" : String(format: ":%02d", minute)
    switch planRealtimeSpeechLanguage(language) {
    case "en":
        return "\(clockHour)\(minutes)\(hour < 12 ? "am" : "pm")"
    case "pl":
        let period = hour < 12 ? "rano" : "wieczorem"
        return "\(clockHour)\(minutes) \(period)"
    case "fr":
        let period = hour < 12 ? "du matin" : "du soir"
        return "\(clockHour)h\(minute == 0 ? "" : String(format: "%02d", minute)) \(period)"
    case "es":
        let period = hour < 12 ? "de la mañana" : "de la tarde"
        return "\(clockHour)\(minutes) \(period)"
    case "de":
        let period = hour < 12 ? "morgens" : "abends"
        return "\(clockHour)\(minutes) Uhr \(period)"
    case "it":
        let period = hour < 12 ? "di mattina" : "di sera"
        return "\(clockHour)\(minutes) \(period)"
    case "ja":
        return "\(hour < 12 ? "午前" : "午後")\(clockHour)時\(minute == 0 ? "" : "\(minute)分")"
    case "ko":
        return "\(hour < 12 ? "오전" : "오후") \(clockHour)시\(minute == 0 ? "" : " \(minute)분")"
    case "zh-Hans":
        return "\(hour < 12 ? "早上" : "晚上")\(clockHour)点\(minute == 0 ? "" : "\(minute)分")"
    default:
        return russianSpokenTime(hour: hour, minute: minute)
    }
}

nonisolated func planRealtimeAsked(kind: String, spoken: String, day: String, time: String, language: String) -> String {
    let clock = planRealtimeSpokenClock(time, language: language)
    switch planRealtimeSpeechLanguage(language) {
    case "en":
        switch kind {
        case "moved": return "Move \(spoken) to \(day) at \(clock)."
        case "added": return "Add \(spoken) on \(day) at \(clock)."
        default: return "Remove \(spoken) on \(day)."
        }
    case "pl":
        switch kind {
        case "moved": return "Przenieś \(spoken) na \(day), na \(clock)."
        case "added": return "Dodaj \(spoken) na \(day), na \(clock)."
        default: return "Usuń \(spoken) na \(day)."
        }
    case "fr":
        switch kind {
        case "moved": return "Déplace \(spoken) à \(day), à \(clock)."
        case "added": return "Ajoute \(spoken) à \(day), à \(clock)."
        default: return "Retire \(spoken) \(day)."
        }
    case "es":
        switch kind {
        case "moved": return "Pasa \(spoken) a \(day), a las \(clock)."
        case "added": return "Añade \(spoken) el \(day) a las \(clock)."
        default: return "Quita \(spoken) de \(day)."
        }
    case "de":
        switch kind {
        case "moved": return "Verschiebe \(spoken) auf \(day) um \(clock)."
        case "added": return "Füge \(spoken) am \(day) um \(clock) hinzu."
        default: return "Entferne \(spoken) am \(day)."
        }
    case "it":
        switch kind {
        case "moved": return "Sposta \(spoken) a \(day), alle \(clock)."
        case "added": return "Aggiungi \(spoken) \(day) alle \(clock)."
        default: return "Togli \(spoken) di \(day)."
        }
    case "ja":
        switch kind {
        case "moved": return "\(spoken)を\(day)の\(clock)に移して。"
        case "added": return "\(day)の\(clock)に\(spoken)を追加して。"
        default: return "\(day)の\(spoken)を外して。"
        }
    case "ko":
        switch kind {
        case "moved": return "\(spoken)을 \(day) \(clock)으로 옮겨 줘."
        case "added": return "\(day) \(clock)에 \(spoken)을 추가해 줘."
        default: return "\(day) \(spoken)을 지워 줘."
        }
    case "zh-Hans":
        switch kind {
        case "moved": return "把\(spoken)改到\(day) \(clock)。"
        case "added": return "在\(day) \(clock)加上\(spoken)。"
        default: return "去掉\(day)的\(spoken)。"
        }
    default:
        switch kind {
        case "moved": return "Перенеси \(spoken) на \(day), на \(clock)."
        case "added": return "Добавь \(spoken) на \(day), на \(clock)."
        default: return "Убери \(spoken) на \(day)."
        }
    }
}

nonisolated func planRealtimeMovedSpeak(spoken: String, day: String, time: String, language: String) -> String {
    let copy = planRealtimeSpeech[planRealtimeSpeechLanguage(language)] ?? planRealtimeSpeech["ru"]!
    return copy.moved(spoken, day, planRealtimeSpokenClock(time, language: language))
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
        todayDoneEmpty: "Сегодня ещё ничего не отмечено.",
        todayPlannedEmpty: "На сегодня ничего не запланировано.",
        tomorrowEmpty: "На завтра ничего нет.",
        todayDoneLead: "Сегодня уже было: ", todayPlannedLead: "На сегодня ещё: ", tomorrowLead: "На завтра: ",
        alreadyDone: "Это уже сделано, не трогаю.",
        missing: "Не нашла это в плане.",
        unchanged: "Оставила как есть.",
        conflict: "Это время уже занято. Во сколько поставим?",
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

enum PlanRealtimeAnchorResult: Equatable {
    case save(day: String, time: String, duration: Int)
    case suggest(day: String, time: String, duration: Int)
    case missing
    case ambiguous
}

func planRealtimeWaterMilliliters(_ arguments: String) -> Int? {
    guard let object = planRealtimeJSON(arguments) else { return nil }
    let raw = object["milliliters"]
    let value: Int?
    if let int = raw as? Int {
        value = int
    } else if let number = raw as? Double {
        value = Int(number)
    } else {
        value = nil
    }
    guard let value, (50...2000).contains(value) else { return nil }
    return value
}

func planRealtimeRemindDraft(_ arguments: String) -> (date: String, startTime: String, place: String, anchorRef: String)? {
    guard let object = planRealtimeJSON(arguments) else { return nil }
    let place = object["place"] as? String ?? ""
    guard place.isEmpty || place == "before" || place == "after" else { return nil }
    return (
        object["date"] as? String ?? "",
        object["startTime"] as? String ?? "",
        place,
        object["anchorRef"] as? String ?? ""
    )
}

func planRealtimeDefaultDuration(_ catalogTitle: String) -> Int {
    switch catalogTitle {
    case "Stretching", "Walk", "Sauna", "Yoga", "Breathing":
        return 20
    case "Sleep Routine", "No Screens", "Morning Routine":
        return 15
    default:
        return 45
    }
}

func planRealtimeResolveAnchor(
    place: String,
    anchorRef: String,
    durationMinutes: Int,
    agenda: [PlanRealtimeAgendaEntry],
    calendar: Calendar
) -> PlanRealtimeAnchorResult {
    let duration = max(durationMinutes, 1)
    let matches = agenda.filter { $0.ref == anchorRef }
    if matches.isEmpty { return .missing }
    if matches.count > 1 { return .ambiguous }
    guard let anchor = matches.first,
          let anchorStart = planRealtimeClockDate(day: anchor.day, time: anchor.startTime, calendar: calendar) else {
        return .missing
    }
    let ideal = place == "before"
        ? calendar.date(byAdding: .minute, value: -duration, to: anchorStart)
        : calendar.date(byAdding: .minute, value: anchor.durationMinutes, to: anchorStart)
    guard let ideal else { return .missing }
    let busy = agenda.compactMap { entry -> (Date, Date)? in
        guard let start = planRealtimeClockDate(day: entry.day, time: entry.startTime, calendar: calendar) else { return nil }
        let end = calendar.date(byAdding: .minute, value: max(entry.durationMinutes, 1), to: start) ?? start
        return (start, end)
    }
    if !planRealtimeOverlaps(ideal, duration: duration, busy: busy, calendar: calendar) {
        return .save(day: anchor.day, time: planRealtimeClockText(ideal, calendar: calendar), duration: duration)
    }
    guard let nearest = planRealtimeNearestFree(
        ideal: ideal,
        duration: duration,
        day: anchor.day,
        busy: busy,
        calendar: calendar
    ) else { return .missing }
    return .suggest(day: anchor.day, time: planRealtimeClockText(nearest, calendar: calendar), duration: duration)
}

func planRealtimeClockDate(day: String, time: String, calendar: Calendar) -> Date? {
    guard day.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
          time.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil else { return nil }
    let dateParts = day.split(separator: "-").compactMap { Int($0) }
    let timeParts = time.split(separator: ":").compactMap { Int($0) }
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

func planRealtimeClockText(_ date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
}

func planRealtimeOverlaps(_ start: Date, duration: Int, busy: [(Date, Date)], calendar: Calendar) -> Bool {
    let end = calendar.date(byAdding: .minute, value: duration, to: start) ?? start
    return busy.contains { start < $0.1 && end > $0.0 }
}

func planRealtimeNearestFree(
    ideal: Date,
    duration: Int,
    day: String,
    busy: [(Date, Date)],
    calendar: Calendar
) -> Date? {
    guard let opening = planRealtimeClockDate(day: day, time: "06:00", calendar: calendar),
          let closing = planRealtimeClockDate(day: day, time: "22:00", calendar: calendar) else { return nil }
    var best: Date?
    var bestDistance = TimeInterval.greatestFiniteMagnitude
    var cursor = opening
    while cursor <= closing {
        let end = calendar.date(byAdding: .minute, value: duration, to: cursor) ?? cursor
        if end <= closing,
           !planRealtimeOverlaps(cursor, duration: duration, busy: busy, calendar: calendar) {
            let distance = abs(cursor.timeIntervalSince(ideal))
            if distance < bestDistance {
                best = cursor
                bestDistance = distance
            }
        }
        guard let next = calendar.date(byAdding: .minute, value: 5, to: cursor) else { break }
        cursor = next
    }
    return best
}

func planRealtimeRussianRangeClock(hour: Int, minute: Int) -> String {
    let names = [
        "полуночи", "часа", "двух", "трёх", "четырёх", "пяти", "шести", "семи", "восьми", "девяти", "десяти", "одиннадцати",
        "двенадцати", "тринадцати", "четырнадцати", "пятнадцати", "шестнадцати", "семнадцати", "восемнадцати", "девятнадцати",
        "двадцати", "двадцати одного", "двадцати двух", "двадцати трёх",
    ]
    guard (0...23).contains(hour) else { return String(hour) }
    if hour == 0, minute == 0 { return names[0] }
    var minutes = ""
    if (1...59).contains(minute) {
        let under = ["", "одного", "двух", "трёх", "четырёх", "пяти", "шести", "семи", "восьми", "девяти", "десяти", "одиннадцати", "двенадцати", "тринадцати", "четырнадцати", "пятнадцати", "шестнадцати", "семнадцати", "восемнадцати", "девятнадцати"]
        if minute < 20 {
            minutes = minute < 10 ? "ноль \(under[minute])" : under[minute]
        } else {
            let tens = ["", "", "двадцати", "тридцати", "сорока", "пятидесяти"]
            let one = minute % 10
            let ten = minute / 10
            minutes = one == 0 ? tens[ten] : "\(tens[ten]) \(under[one])"
        }
    }
    return minutes.isEmpty ? names[hour] : "\(names[hour]) \(minutes)"
}
