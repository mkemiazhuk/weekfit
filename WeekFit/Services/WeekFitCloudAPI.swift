import Foundation

/// Shared WeekFit cloud API configuration (account deletion, photo recognition, etc.).
enum WeekFitCloudAPI {
    static let baseURLInfoPlistKey = "WeekFitCloudAPIBaseURL"
    static let debugUserDefaultsKey = "WeekFitCloudAPIBaseURL"
    static let debugLaunchArgument = "-WeekFitCloudAPIBaseURL"
    /// Explicit Debug-only fixture gate. Off by default — never auto-substitutes live recognition.
    static let debugUseFixtureDefaultsKey = "WeekFitUsePhotoFoodFixture"

    /// Default deployed origin; explicit Sandbox builds use a separate service.
    static let productionFoodPhotoBaseURL = URL(string: "https://weekfit-food-photo.onrender.com")!

    /// Local-dev bearer for Mac proxy when `ALLOW_DEV_AUTH=1` (Debug overrides only).
    static let debugDevToken = "weekfit-dev-local-token"

    nonisolated(unsafe) static var configuredBaseURL: URL? {
        get { AccountRemoteDeletionClient.configuredBaseURL }
        set { AccountRemoteDeletionClient.configuredBaseURL = newValue }
    }

    nonisolated(unsafe) static var sessionTokenProvider: () -> String? {
        get { AccountRemoteDeletionClient.sessionTokenProvider }
        set { AccountRemoteDeletionClient.sessionTokenProvider = newValue }
    }

    /// Explicit test configuration. Debug may honor it. Release also needs `WEEKFIT_AI_SANDBOX`.
    nonisolated static var sandboxBillingRequested: Bool {
        Bundle.main.object(forInfoDictionaryKey: "WeekFitAISandboxEnabled") as? Bool == true
    }

    nonisolated static var sandboxCompiledIn: Bool {
        #if DEBUG || WEEKFIT_AI_SANDBOX
        true
        #else
        false
        #endif
    }

    nonisolated static var billingDecision: WeekFitAISandboxDecision {
        let raw = Bundle.main.object(forInfoDictionaryKey: "WeekFitAISandboxBaseURL") as? String
        return WeekFitAISandboxDecision.decide(
            usageEnabled: Bundle.main.object(forInfoDictionaryKey: "WeekFitAIUsageEnabled") as? Bool == true,
            sandboxRequested: sandboxBillingRequested,
            sandboxURL: raw.flatMap { URL(string: $0) },
            compiledSandboxAllowed: sandboxCompiledIn
        )
    }

    /// Usable Sandbox origin. Nil when Sandbox was not requested, or when it was refused.
    nonisolated static var sandboxBillingBaseURL: URL? {
        if case .sandbox(let url) = billingDecision.route { return url }
        return nil
    }

    nonisolated static var sandboxRefused: Bool {
        if case .refused = billingDecision.route { return true }
        return false
    }

    /// Sandbox archive or the AISandbox run configuration → Debug overrides → production HTTPS.
    /// A refused Sandbox build does not continue on to Production.
    static func bootstrapFromInfoPlistIfNeeded() {
        switch billingDecision.route {
        case .sandbox(let url):
            configuredBaseURL = url
            return
        case .refused:
            configuredBaseURL = nil
            return
        case .production:
            break
        }
        #if DEBUG
        if let fromLaunch = debugLaunchArgumentURL() {
            configuredBaseURL = fromLaunch
            return
        }
        if let raw = UserDefaults.standard.string(forKey: debugUserDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            configuredBaseURL = url
            return
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: baseURLInfoPlistKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let url = URL(string: trimmed) {
                configuredBaseURL = url
                return
            }
        }
        #endif

        configuredBaseURL = productionFoodPhotoBaseURL
    }

    static var isConfigured: Bool {
        configuredBaseURL != nil
    }

    /// Food, voice, and billing origin. A refused Sandbox build does not use Production.
    static var foodPhotoBaseURL: URL {
        if sandboxRefused { return WeekFitAISandboxDecision.refusedBaseURL }
        return configuredBaseURL ?? productionFoodPhotoBaseURL
    }

    #if DEBUG
    static var usePhotoFoodFixture: Bool {
        UserDefaults.standard.bool(forKey: debugUseFixtureDefaultsKey)
    }

    static func setDebugBaseURLString(_ raw: String?) {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: debugUserDefaultsKey)
            configuredBaseURL = productionFoodPhotoBaseURL
            return
        }
        UserDefaults.standard.set(trimmed, forKey: debugUserDefaultsKey)
        configuredBaseURL = URL(string: trimmed)
    }

    static func setUsePhotoFoodFixture(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: debugUseFixtureDefaultsKey)
    }
    #endif

    private static func debugLaunchArgumentURL() -> URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: debugLaunchArgument),
              args.indices.contains(index + 1) else {
            return nil
        }
        let raw = args[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}
