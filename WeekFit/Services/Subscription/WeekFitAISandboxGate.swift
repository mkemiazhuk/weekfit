import Foundation

/// How a build may talk to AI billing. A requested Sandbox that cannot be used
/// stays refused: it never falls through to Production.
enum WeekFitAISandboxRoute: Equatable, Sendable {
    case production
    case sandbox(URL)
    case refused
}

struct WeekFitAISandboxDecision: Equatable, Sendable {
    var route: WeekFitAISandboxRoute
    var billingEnabled: Bool
    var environmentHeader: String

    /// Host used when Sandbox was requested but this build must not call Production.
    static let refusedBaseURL = URL(string: "https://invalid.weekfit-sandbox.invalid")!

    static func decide(
        usageEnabled: Bool,
        sandboxRequested: Bool,
        sandboxURL: URL?,
        compiledSandboxAllowed: Bool
    ) -> WeekFitAISandboxDecision {
        guard sandboxRequested else {
            return WeekFitAISandboxDecision(
                route: .production,
                billingEnabled: usageEnabled,
                environmentHeader: "Production"
            )
        }
        guard compiledSandboxAllowed, usageEnabled, let sandboxURL, isSandboxOrigin(sandboxURL) else {
            return WeekFitAISandboxDecision(
                route: .refused,
                billingEnabled: false,
                environmentHeader: "Sandbox"
            )
        }
        return WeekFitAISandboxDecision(
            route: .sandbox(sandboxURL),
            billingEnabled: true,
            environmentHeader: "Sandbox"
        )
    }

    static func isSandboxOrigin(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host, !host.isEmpty else { return false }
        guard url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return false }
        return url.path.isEmpty || url.path == "/"
    }
}
