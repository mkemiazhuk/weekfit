import Foundation

enum WeekFitUITestSupport {
    static let launchArgument = "-ui-testing"
    /// Debug-only: treat StoreKit AppTransaction as a new user (paywall path).
    static let forceNewUserLaunchArgument = "-weekfit-force-new-user"
    /// Debug-only: treat the install as grandfathered (no paywall).
    static let forceLegacyUserLaunchArgument = "-weekfit-force-legacy-user"
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
