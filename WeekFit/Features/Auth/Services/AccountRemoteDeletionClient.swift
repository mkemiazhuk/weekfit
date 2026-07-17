import Foundation

/// Remote WeekFit account deletion (cloud record + associated server data).
protocol AccountRemoteDeleting: Sendable {
    func deleteRemoteAccount() async throws
}

enum AccountRemoteDeletionError: LocalizedError, Equatable {
    case invalidResponse
    case server(statusCode: Int, message: String?)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unable to delete your account. Please try again."
        case .server(_, let message):
            return message ?? "Unable to delete your account. Please try again."
        case .network(let message):
            return message
        }
    }
}

/// Calls `DELETE /v1/account` when a WeekFit cloud API base URL is configured.
///
/// Until cloud sync ships, accounts are device-local (Sign in with Apple session,
/// App Review demo, or debug email). In that mode deletion succeeds locally so
/// App Review and users can permanently remove the in-app account and data.
struct AccountRemoteDeletionClient: AccountRemoteDeleting {

    /// Injected for tests; production uses `URLSession.shared`.
    var session: URLSession = .shared

    /// Optional override used by unit tests.
    var baseURLOverride: URL?
    var authTokenOverride: String?

    func deleteRemoteAccount() async throws {
        guard let baseURL = baseURLOverride ?? Self.configuredBaseURL else {
            // No WeekFit cloud account exists yet — treat as successful remote deletion.
            try await Task.sleep(nanoseconds: 350_000_000)
            return
        }

        var request = URLRequest(url: baseURL.appending(path: "v1/account"))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        if let token = authTokenOverride ?? Self.sessionTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AccountRemoteDeletionError.network(
                "Network error. Check your connection and try again."
            )
        }

        guard let http = response as? HTTPURLResponse else {
            throw AccountRemoteDeletionError.invalidResponse
        }

        switch http.statusCode {
        case 200, 202, 204:
            return
        case 401, 403:
            throw AccountRemoteDeletionError.server(
                statusCode: http.statusCode,
                message: "Your session expired. Sign in again, then retry account deletion."
            )
        default:
            let message = Self.parseErrorMessage(from: data)
            throw AccountRemoteDeletionError.server(
                statusCode: http.statusCode,
                message: message
            )
        }
    }

    // MARK: - Configuration

    /// Set when the WeekFit account API is available in production.
    /// Example: `https://api.weekfit.app`
    nonisolated(unsafe) static var configuredBaseURL: URL?

    /// Provides the current bearer token for authenticated DELETE requests.
    nonisolated(unsafe) static var sessionTokenProvider: () -> String? = { nil }

    private static func parseErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        if let error = json["error"] as? String, !error.isEmpty {
            return error
        }
        return nil
    }
}
