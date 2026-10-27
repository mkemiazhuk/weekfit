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
    /// Debug-only: force WeekFit appearance preference for UI tests (`light` / `dark` / `system`).
    static let appearanceOverrideArgument = "-weekfit-appearance="
    /// Debug-only: open a main tab on launch (`today` / `coach` / `meals` / `plan` / `calendar`).
    static let startTabOverrideArgument = "-weekfit-start-tab="
    /// Debug-only: force in-app language for UI tests (`en` / `ru` / `zh-Hans` / `fr` / `pl` / `es` / `de` / `ja` / `it` / `ko`).
    static let languageOverrideArgument = "-weekfit-language="
    /// Debug-only: reset + present first-run onboarding (overrides the normal UI-test onboarding suppress).
    static let forceOnboardingArgument = "-weekfit-force-onboarding"
    /// Debug-only: open the real paywall via the temporary force-paywall diagnostics path.
    static let forcePaywallArgument = "-weekfit-force-paywall"
    /// Debug-only: mark Health access as already requested so the in-app HealthAccess gate is skipped.
    static let skipHealthAccessArgument = "-weekfit-skip-health-access"
    /// Debug-only: mark first-run onboarding completed (useful with skip-health / paywall / sheets).
    static let completeOnboardingArgument = "-weekfit-complete-onboarding"

    static var isActive: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        false
        #endif
    }

    static var shouldForceOnboarding: Bool {
        #if DEBUG
        isActive && ProcessInfo.processInfo.arguments.contains(forceOnboardingArgument)
        #else
        false
        #endif
    }

    static var shouldForcePaywall: Bool {
        #if DEBUG
        isActive && ProcessInfo.processInfo.arguments.contains(forcePaywallArgument)
        #else
        false
        #endif
    }

    static var shouldSkipHealthAccess: Bool {
        #if DEBUG
        isActive && ProcessInfo.processInfo.arguments.contains(skipHealthAccessArgument)
        #else
        false
        #endif
    }

    static var shouldCompleteOnboarding: Bool {
        #if DEBUG
        isActive && ProcessInfo.processInfo.arguments.contains(completeOnboardingArgument)
        #else
        false
        #endif
    }

    /// Apply UserDefaults side-effects for UI-test launch flags. DEBUG + `-ui-testing` only.
    static func applyLaunchOverridesIfNeeded() {
        #if DEBUG
        guard isActive else { return }
        if shouldCompleteOnboarding || shouldForcePaywall || shouldSkipHealthAccess {
            OnboardingStore.hasCompletedOnboarding = true
            OnboardingStore.dismissAllTabIntros()
            OnboardingStore.persistedStepRawValue = nil
        }
        if shouldForceOnboarding {
            OnboardingStore.hasCompletedOnboarding = false
            OnboardingStore.persistedStepRawValue = nil
        }
        if shouldSkipHealthAccess {
            UserDefaults.standard.set(true, forKey: "weekfit.healthAccessRequested")
        }
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
    static func appearanceOverridePreference() -> WeekFitAppearancePreference? {
        parseAppearanceOverride(
            from: ProcessInfo.processInfo.arguments,
            isUITesting: isActive
        )
    }

    static func parseAppearanceOverride(
        from arguments: [String],
        isUITesting: Bool
    ) -> WeekFitAppearancePreference? {
        guard isUITesting else { return nil }
        guard let raw = arguments.first(where: { $0.hasPrefix(appearanceOverrideArgument) }) else {
            return nil
        }
        let value = raw.dropFirst(appearanceOverrideArgument.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return WeekFitAppearancePreference(rawValue: value)
    }

    static func startTabOverride() -> WeekFitTab? {
        parseStartTabOverride(
            from: ProcessInfo.processInfo.arguments,
            isUITesting: isActive
        )
    }

    static func parseStartTabOverride(
        from arguments: [String],
        isUITesting: Bool
    ) -> WeekFitTab? {
        guard isUITesting else { return nil }
        guard let raw = arguments.first(where: { $0.hasPrefix(startTabOverrideArgument) }) else {
            return nil
        }
        let value = raw.dropFirst(startTabOverrideArgument.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch value {
        case "today": return .today
        case "coach": return .coach
        case "meals": return .meals
        case "plan", "calendar": return .calendar
        default: return nil
        }
    }

    static func languageOverride() -> AppLanguage? {
        parseLanguageOverride(
            from: ProcessInfo.processInfo.arguments,
            isUITesting: isActive
        )
    }

    static func parseLanguageOverride(
        from arguments: [String],
        isUITesting: Bool
    ) -> AppLanguage? {
        guard isUITesting else { return nil }
        guard let raw = arguments.first(where: { $0.hasPrefix(languageOverrideArgument) }) else {
            return nil
        }
        let value = String(raw.dropFirst(languageOverrideArgument.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return AppLanguage(rawValue: value)
    }
    #else
    static func entitlementOverrideState() -> WeekFitAccessState? { nil }
    static func appearanceOverridePreference() -> WeekFitAppearancePreference? { nil }
    static func startTabOverride() -> WeekFitTab? { nil }
    static func languageOverride() -> AppLanguage? { nil }
    #endif
}
