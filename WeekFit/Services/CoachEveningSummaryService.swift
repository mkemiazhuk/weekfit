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

    static func generate(_ input: CoachEveningSummaryInput, owner: String) async throws -> CoachEveningSummary {
        let tag = CoachEveningSummaryDiagnostics.ownerTag(owner)
        try Task.checkCancellation()
        guard FirebaseBootstrap.isConfigured else {
            CoachEveningSummaryDiagnostics.error("auth.blocked", detail: "owner=\(tag) reason=firebaseNotConfigured")
            throw CoachEveningSummaryServiceError.unavailable
        }
        guard WorkspaceOwnerStore.currentIdentityToken() == owner else {
            CoachEveningSummaryDiagnostics.event("auth.cancelled", detail: "owner=\(tag) reason=ownerMismatchBeforeAuth")
            throw CancellationError()
        }

        try await bindAnonymousFirebaseSession(to: owner)
        try Task.checkCancellation()
        guard WorkspaceOwnerStore.currentIdentityToken() == owner else {
            CoachEveningSummaryDiagnostics.event("auth.cancelled", detail: "owner=\(tag) reason=ownerMismatchAfterBind")
            throw CancellationError()
        }

        let token: String
        do {
            token = try await PhotoFoodFirebaseAuth.idToken(forcingRefresh: false)
            CoachEveningSummaryDiagnostics.event("auth.ok", detail: "owner=\(tag) tokenLen=\(token.count)")
        } catch {
            CoachEveningSummaryDiagnostics.error(
                "auth.failed",
                detail: "owner=\(tag) error=\(String(describing: type(of: error)))"
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
        let body = try JSONEncoder().encode(input)
        request.httpBody = body

        CoachEveningSummaryDiagnostics.event(
            "http.request",
            detail: "owner=\(tag) path=/v1/coach/day-summary day=\(input.day) locale=\(input.locale) bodyBytes=\(body.count)"
        )
        let started = ContinuousClock.now

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            CoachEveningSummaryDiagnostics.event("http.cancelled", detail: "owner=\(tag)")
            throw CancellationError()
        } catch {
            let elapsed = durationMs(since: started)
            CoachEveningSummaryDiagnostics.error(
                "http.transport",
                detail: "owner=\(tag) durationMs=\(elapsed) error=\(String(describing: type(of: error)))"
            )
            throw CoachEveningSummaryServiceError.unavailable
        }

        let elapsed = durationMs(since: started)
        guard let http = response as? HTTPURLResponse else {
            CoachEveningSummaryDiagnostics.error(
                "http.nonHTTP",
                detail: "owner=\(tag) durationMs=\(elapsed) responseBytes=\(data.count)"
            )
            throw CoachEveningSummaryServiceError.invalidResponse
        }
        let requestId = http.value(forHTTPHeaderField: "X-Request-Id")
            ?? http.value(forHTTPHeaderField: "x-request-id")
        CoachEveningSummaryDiagnostics.event(
            "http.response",
            detail: "owner=\(tag) status=\(http.statusCode) durationMs=\(elapsed) responseBytes=\(data.count) requestId=\(requestId ?? "-")"
        )
        guard http.statusCode == 200 else {
            let serverCode = extractErrorCode(from: data) ?? "http.\(http.statusCode)"
            CoachEveningSummaryDiagnostics.error(
                "http.error",
                detail: "owner=\(tag) status=\(http.statusCode) code=\(serverCode) durationMs=\(elapsed)"
            )
            throw CoachEveningSummaryServiceError.server(http.statusCode)
        }
        let summary: CoachEveningSummary
        do {
            summary = try JSONDecoder().decode(CoachEveningSummary.self, from: data)
        } catch {
            CoachEveningSummaryDiagnostics.error(
                "decode.failed",
                detail: "owner=\(tag) durationMs=\(elapsed) error=\(String(describing: type(of: error)))"
            )
            throw CoachEveningSummaryServiceError.invalidResponse
        }
        guard summary.isValid(for: input) else {
            CoachEveningSummaryDiagnostics.error(
                "decode.invalid",
                detail: "owner=\(tag) day=\(summary.day) locale=\(summary.locale) source=\(summary.source)"
            )
            throw CoachEveningSummaryServiceError.invalidResponse
        }
        CoachEveningSummaryDiagnostics.event(
            "decode.ok",
            detail: "owner=\(tag) day=\(summary.day) locale=\(summary.locale) headlineLen=\(summary.headline.count)"
        )
        return summary
    }

    private static func durationMs(since started: ContinuousClock.Instant) -> Int {
        let elapsed = ContinuousClock.now - started
        return Int(elapsed.components.seconds * 1000)
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
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
