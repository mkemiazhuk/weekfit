import Foundation
import FirebaseAuth

enum CoachEveningSummaryServiceError: Error {
    case unavailable
    case invalidResponse
    case server(Int)
}

/// Evening Coach summary over the shared WeekFit cloud origin + Firebase Auth.
/// Reuses `PhotoFoodFirebaseAuth` / `WeekFitCloudAPI` — no second auth stack.
@MainActor
enum CoachEveningSummaryService {
    private static let workspaceOwnerKey = "weekfit.ai.firebaseWorkspaceOwner"

    static func generate(_ input: CoachEveningSummaryInput, owner: String) async throws -> CoachEveningSummaryGenerationResult {
        var input = input
        let tag = CoachEveningSummaryDiagnostics.ownerTag(owner)
        let clientRequestId = UUID().uuidString
        try Task.checkCancellation()
        guard FirebaseBootstrap.isConfigured else {
            CoachEveningSummaryDiagnostics.error(
                "auth.blocked",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: "http",
                    requestId: clientRequestId, extra: "reason=firebaseNotConfigured"
                )
            )
            throw CoachEveningSummaryServiceError.unavailable
        }
        guard WorkspaceOwnerStore.currentIdentityToken() == owner else {
            CoachEveningSummaryDiagnostics.event(
                "auth.cancelled",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: "http",
                    requestId: clientRequestId, extra: "reason=ownerMismatchBeforeAuth"
                )
            )
            throw CancellationError()
        }

        try await bindAnonymousFirebaseSession(to: owner)
        try Task.checkCancellation()
        guard WorkspaceOwnerStore.currentIdentityToken() == owner else {
            CoachEveningSummaryDiagnostics.event(
                "auth.cancelled",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: "http",
                    requestId: clientRequestId, extra: "reason=ownerMismatchAfterBind"
                )
            )
            throw CancellationError()
        }

        let token: String
        do {
            token = try await PhotoFoodFirebaseAuth.idToken(forcingRefresh: false)
            CoachEveningSummaryDiagnostics.event(
                "auth.ok",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: "http",
                    requestId: clientRequestId, extra: "tokenPresent=true"
                )
            )
        } catch {
            CoachEveningSummaryDiagnostics.error(
                "auth.failed",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: "http",
                    requestId: clientRequestId,
                    extra: "error=\(String(describing: type(of: error)))"
                )
            )
            throw CoachEveningSummaryServiceError.unavailable
        }

        try Task.checkCancellation()
        let url = WeekFitCloudAPI.foodPhotoBaseURL.appending(path: "v1/coach/day-summary")
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientRequestId, forHTTPHeaderField: "X-Request-Id")
        #if DEBUG
        if CoachDebugSettings.eveningSummaryUnrestrictedEnabled {
            // Dev-only: ask the service to skip once-per-day reuse (honored for local-developer).
            request.setValue("1", forHTTPHeaderField: "X-WeekFit-Coach-Summary-Unrestricted")
        }
        #endif
        // Enrich only inside the shared flight: Root and Coach cannot each query/generate.
        // Skip weekly HK history only when Health is unavailable (`sleep.unavailable`).
        // `sleep.duration.unknown` must NOT block recentActivity / vitals / baseline enrichment.
        if AccountSessionController.shared.mode != .reviewDemo,
           input.facts["sleep"]?.contains(where: { $0.id == "sleep.unavailable" }) == false,
           let context = await weeklyFacts(for: input) {
            var facts = input.facts
            facts.merge(context) { _, new in new }
            if let cache = try? CoachEveningSummaryStore().loadCache(owner: owner),
               cache.summary.day < input.day {
                facts["recentRecaps"] = [.init(id: "history.previousRecap",
                    text: String(("Previous recap on " + cache.summary.day + ": "
                        + cache.summary.today.text + " " + cache.summary.tomorrow.text).prefix(500)))]
            }
            input = CoachEveningSummaryInput(schemaVersion: input.schemaVersion, day: input.day,
                timezone: input.timezone, locale: input.locale, phase: input.phase, facts: facts)
        }
        try Task.checkCancellation()
        guard WorkspaceOwnerStore.currentIdentityToken() == owner else { throw CancellationError() }
        let body = try JSONEncoder().encode(input)
        request.httpBody = body
        #if DEBUG
        // Log the exact HTTP body after weekly enrichment — do not rebuild a parallel payload.
        CoachEveningSummaryDebugTape.logInput(clientRequestId: clientRequestId, httpBody: body)
        #endif

        CoachEveningSummaryDiagnostics.event(
            "http.request",
            detail: CoachEveningSummaryDiagnostics.flightDetail(
                owner: owner, day: input.day, source: "http",
                requestId: clientRequestId,
                extra: "path=/v1/coach/day-summary locale=\(input.locale) bodyBytes=\(body.count)"
            )
        )
        let started = ContinuousClock.now

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            CoachEveningSummaryDiagnostics.event(
                "http.cancelled",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: "http", requestId: clientRequestId
                )
            )
            throw CancellationError()
        } catch {
            let elapsed = durationMs(since: started)
            #if DEBUG
            CoachEveningSummaryDebugTape.logOutput(
                clientRequestId: clientRequestId,
                serverRequestId: nil,
                status: nil,
                durationMs: elapsed,
                responseBody: nil,
                transportError: String(describing: type(of: error))
            )
            #endif
            CoachEveningSummaryDiagnostics.error(
                "http.transport",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: "http",
                    requestId: clientRequestId,
                    extra: "durationMs=\(elapsed) error=\(String(describing: type(of: error)))"
                )
            )
            throw CoachEveningSummaryServiceError.unavailable
        }

        let elapsed = durationMs(since: started)
        guard let http = response as? HTTPURLResponse else {
            #if DEBUG
            CoachEveningSummaryDebugTape.logOutput(
                clientRequestId: clientRequestId,
                serverRequestId: nil,
                status: nil,
                durationMs: elapsed,
                responseBody: data,
                transportError: "nonHTTP"
            )
            #endif
            CoachEveningSummaryDiagnostics.error(
                "http.nonHTTP",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: "http",
                    requestId: clientRequestId,
                    extra: "durationMs=\(elapsed) responseBytes=\(data.count)"
                )
            )
            throw CoachEveningSummaryServiceError.invalidResponse
        }

        let headerRequestId = http.value(forHTTPHeaderField: "X-Request-Id")
            ?? http.value(forHTTPHeaderField: "x-request-id")
        let bodyRequestId = extractRequestId(from: data)
        // Prefer body (server-authoritative), then header, then client-sent id.
        let requestId = firstNonEmpty(bodyRequestId, headerRequestId, clientRequestId) ?? clientRequestId

        #if DEBUG
        // Full UTF-8 response before decode — including non-200 bodies.
        CoachEveningSummaryDebugTape.logOutput(
            clientRequestId: clientRequestId,
            serverRequestId: requestId,
            status: http.statusCode,
            durationMs: elapsed,
            responseBody: data
        )
        #endif

        CoachEveningSummaryDiagnostics.event(
            "http.response",
            detail: CoachEveningSummaryDiagnostics.flightDetail(
                owner: owner, day: input.day, source: "http",
                requestId: requestId,
                extra: "status=\(http.statusCode) durationMs=\(elapsed) responseBytes=\(data.count) headerId=\(headerRequestId ?? "-") bodyId=\(bodyRequestId ?? "-") clientId=\(clientRequestId)"
            )
        )
        guard http.statusCode == 200 else {
            let serverCode = extractErrorCode(from: data) ?? "http.\(http.statusCode)"
            CoachEveningSummaryDiagnostics.error(
                "http.error",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: "http",
                    requestId: requestId,
                    extra: "status=\(http.statusCode) code=\(serverCode) durationMs=\(elapsed)"
                )
            )
            throw CoachEveningSummaryServiceError.server(http.statusCode)
        }
        let summary: CoachEveningSummary
        do {
            summary = try JSONDecoder().decode(CoachEveningSummary.self, from: data)
        } catch {
            CoachEveningSummaryDiagnostics.error(
                "decode.failed",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: "http",
                    requestId: requestId,
                    extra: "durationMs=\(elapsed) error=\(String(describing: type(of: error)))"
                )
            )
            throw CoachEveningSummaryServiceError.invalidResponse
        }
        guard summary.isValid(for: input) else {
            CoachEveningSummaryDiagnostics.error(
                "decode.invalid",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: summary.day, source: "http",
                    requestId: requestId,
                    extra: "locale=\(summary.locale) source=\(summary.source)"
                )
            )
            throw CoachEveningSummaryServiceError.invalidResponse
        }
        CoachEveningSummaryDiagnostics.event(
            "decode.ok",
            detail: CoachEveningSummaryDiagnostics.flightDetail(
                owner: owner, day: summary.day, source: "http",
                requestId: requestId,
                extra: "locale=\(summary.locale) headlineLen=\(summary.headline.count) source=\(summary.source)"
            )
        )
        return CoachEveningSummaryGenerationResult(summary: summary, requestId: requestId, validationInput: input)
    }

    private static func weeklyFacts(for input: CoachEveningSummaryInput) async -> [String: [CoachEveningSummaryInput.Fact]]? {
        var calendar = Calendar(identifier: .gregorian)
        guard let timezone = TimeZone(identifier: input.timezone) else { return nil }
        calendar.timeZone = timezone
        let now = Date()
        guard CoachEveningSummaryPolicy.dayKey(now, calendar: calendar) == input.day else { return nil }
        do {
            var facts = try await RecoveryHealthKitProvider(calendar: calendar).loadCoachHistory(now: now).facts()
            var feelings: [CoachEveningSummaryInput.Fact] = []
            for offset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: now),
                      let checkIn = CoachFeelingCheckInStore.latest(on: date, calendar: calendar) else { continue }
                let day = CoachEveningSummaryPolicy.dayKey(date, calendar: calendar)
                feelings.append(.init(id: "history.feeling.\(day)",
                    text: "Local day \(day): subjective self-report=\(checkIn.feeling.rawValue); clarification=\(checkIn.clarification?.rawValue ?? "none"). Not a physiological measurement."))
            }
            facts["recentFeeling"] = feelings
            return facts
        } catch {
            // Fall back to honest daily context on cancellation/query failure, without inventing history.
            return nil
        }
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values.first { value in
            guard let value else { return false }
            return !value.isEmpty
        } ?? nil
    }

    private static func durationMs(since started: ContinuousClock.Instant) -> Int {
        let elapsed = ContinuousClock.now - started
        return Int(elapsed.components.seconds * 1000)
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
    }

    private static func extractRequestId(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let requestId = object["requestId"] as? String,
            !requestId.isEmpty,
            requestId.count <= 80,
            requestId.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        else { return nil }
        return requestId
    }

    private static func extractErrorCode(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = object["error"] as? String,
            !error.isEmpty,
            error.count <= 80,
            error.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." })
        else { return nil }
        return error
    }

    /// Local workspace identities stay separate from Firebase. On workspace change,
    /// drop only an anonymous cloud session so another account cannot reuse its UID.
    private static func bindAnonymousFirebaseSession(to owner: String) async throws {
        let auth = Auth.auth()
        if UserDefaults.standard.string(forKey: workspaceOwnerKey) != owner {
            if let user = auth.currentUser {
                guard user.isAnonymous else {
                    throw CoachEveningSummaryServiceError.unavailable
                }
                try auth.signOut()
            }
        }
        UserDefaults.standard.set(owner, forKey: workspaceOwnerKey)
    }
}
