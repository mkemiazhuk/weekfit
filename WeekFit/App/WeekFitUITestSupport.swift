import Foundation

enum WeekFitUITestSupport {
    static let launchArgument = "-ui-testing"
    /// Debug-only: treat StoreKit AppTransaction as a new user (paywall path).
    ///
    /// Skips both legacy AppTransaction *and* active-subscription checks.
    /// Prefer ``forceNonLegacyLaunchArgument`` when testing the real purchase flow.
    static let forceNewUserLaunchArgument = "-weekfit-force-new-user"
    /// Debug-only: treat the install as grandfathered (no paywall).
    static let forceLegacyUserLaunchArgument = "-weekfit-force-legacy-user"
    /// Debug-only: ignore AppTransaction legacy grandfathering only.
    ///
    /// Prefer for Xcode StoreKit Testing. Sandbox Apple IDs already treat the
    /// 2013-08-01 sentinel as non-legacy in all builds (see
    /// `WeekFitEntitlementPolicy.isSandboxSentinelOriginalPurchaseDate`).
    /// Does **not** require `-ui-testing`, does **not** skip active subscriptions,
    /// and is compiled out of Release.
    static let forceNonLegacyLaunchArgument = "-weekfit-force-non-legacy"
    /// DEBUG-only: allow Firebase Analytics (and Crashlytics) while running a
    /// Debug build — for Sandbox QA + DebugView. Production Release policy is
    /// unchanged: DEBUG without this flag still keeps analytics OFF.
    static let enableDebugAnalyticsLaunchArgument = "-weekfit-enable-debug-analytics"
    /// Debug-only: entitlement state override for UI tests.
    ///
    /// Allowed values:
    /// - new / unsubscribed
    /// - legacy
    /// - subscribed / active
    /// - expired
    /// - loading / unavailable
    static let entitlementStateOverrideArgument = "-weekfit-entitlement-test-state="

    static var isActive: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        false
        #endif
    }

    /// DEBUG-only: force AppTransaction legacy check to non-legacy.
    /// Available for manual Sandbox runs without `-ui-testing`.
    static var shouldForceNonLegacyAppTransaction: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(forceNonLegacyLaunchArgument)
        #else
        false
        #endif
    }

    /// DEBUG-only: opt into Firebase Analytics collection for Sandbox QA.
    static var shouldEnableDebugAnalytics: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(enableDebugAnalyticsLaunchArgument)
        #else
        false
        #endif
    }

    /// Returns an explicit access state override for UI tests.
    ///
    /// This is compiled only into DEBUG; Release / App Store builds cannot observe it.
    #if DEBUG
    static func entitlementOverrideState() -> WeekFitAccessState? {
        parseEntitlementOverrideState(
            from: ProcessInfo.processInfo.arguments,
            isUITesting: isActive
        )
    }

    static func parseEntitlementOverrideState(
        from arguments: [String],
        isUITesting: Bool
    ) -> WeekFitAccessState? {
        guard isUITesting else { return nil }
        guard let raw = arguments.first(where: { $0.hasPrefix(entitlementStateOverrideArgument) }) else {
            return nil
        }
        let value = raw.dropFirst(entitlementStateOverrideArgument.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch value {
        case "new", "unsubscribed": return .unsubscribed
        case "legacy": return .legacy
        case "subscribed", "active": return .subscribed
        case "expired": return .expired
        case "loading", "unavailable": return .loading
        default: return nil
        }
    }
    #else
    static func entitlementOverrideState() -> WeekFitAccessState? { nil }
    #endif
}
