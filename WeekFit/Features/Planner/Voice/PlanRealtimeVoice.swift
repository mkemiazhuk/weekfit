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

enum PlanRealtimeClientError: Error {
    case unauthorized
    case forbidden
    case notFound
    case transport
    case invalid
}

struct PlanRealtimeClient {
    var baseURL: URL
    var token: String
    var session: URLSession = .shared

    func access() async throws -> PlanRealtimeAccess {
        try await send(method: "GET", path: "v1/planner-voice/access", body: nil)
    }

    func openSession(
        timeZone: String,
        now: Date,
        planningDay: String,
        givenName: String,
        language: String
    ) async throws -> PlanRealtimeSessionSecret {
        try await send(
            method: "POST",
            path: "v1/planner-voice/session",
            body: [
                "timeZone": timeZone,
                "now": ISO8601DateFormatter().string(from: now),
                "planningDay": planningDay,
                "givenName": givenName,
                "language": language,
            ]
        )
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
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
        if http.statusCode == 401 { throw PlanRealtimeClientError.unauthorized }
        if http.statusCode == 403 { throw PlanRealtimeClientError.forbidden }
        if http.statusCode == 404 { throw PlanRealtimeClientError.notFound }
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
