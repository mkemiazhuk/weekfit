import XCTest
@testable import WeekFit

final class WeekFitForcePaywallStoreTests: XCTestCase {
    func testAppStoreDistributionNeverAllowsForcePaywall() {
        XCTAssertFalse(AppDistribution.appStore.allowsTemporaryForcePaywall)
        XCTAssertFalse(
            WeekFitForcePaywallStore.resolvedIsEnabled(
                distribution: .appStore,
                storedValue: true
            )
        )
    }

    func testDebugDistributionAllowsForcePaywall() {
        XCTAssertTrue(AppDistribution.debug.allowsTemporaryForcePaywall)
        XCTAssertTrue(
            WeekFitForcePaywallStore.resolvedIsEnabled(
                distribution: .debug,
                storedValue: true
            )
        )
    }

    func testTestFlightNeverAllowsForcePaywall() {
        XCTAssertFalse(AppDistribution.testFlight.allowsTemporaryForcePaywall)
        XCTAssertFalse(
            WeekFitForcePaywallStore.resolvedIsEnabled(
                distribution: .testFlight,
                storedValue: true
            )
        )
        XCTAssertFalse(AppDistribution.testFlight.showsTemporaryStoreKitPaywallDiagnostics)
    }

    func testStoredFlagIgnoredAndScrubbedOutsideDebug() {
        let key = "weekfit.tests.forcePaywall.scrub.\(UUID().uuidString)"
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: key)
        defer { defaults.removeObject(forKey: key) }

        for distribution in [AppDistribution.appStore, .testFlight] {
            defaults.set(true, forKey: key)
            XCTAssertFalse(
                WeekFitForcePaywallStore.resolvedIsEnabled(
                    distribution: distribution,
                    storedValue: true
                )
            )
            WeekFitForcePaywallStore.scrubStoredFlagIfNeeded(
                defaults: defaults,
                distribution: distribution,
                key: key
            )
            XCTAssertFalse(defaults.bool(forKey: key))
        }
    }

    func testScrubDoesNotClearFlagOnDebug() {
        let key = "weekfit.tests.forcePaywall.keep.\(UUID().uuidString)"
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: key)
        defer { defaults.removeObject(forKey: key) }

        WeekFitForcePaywallStore.scrubStoredFlagIfNeeded(
            defaults: defaults,
            distribution: .debug,
            key: key
        )
        XCTAssertTrue(defaults.bool(forKey: key))
        XCTAssertTrue(
            WeekFitForcePaywallStore.resolvedIsEnabled(
                distribution: .debug,
                storedValue: true
            )
        )
    }

    func testForcePaywallDoesNotAlterAccessStateValues() {
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: .legacy))
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: .subscribed))
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: .trial))
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: .expired))
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: .unsubscribed))
        XCTAssertEqual(
            WeekFitStoreKitPaywallDiagnosticsFormatter.accessStateLabel(.legacy),
            "legacy"
        )
        // Force flag resolution never feeds entitlement policy.
        XCTAssertTrue(
            WeekFitForcePaywallStore.resolvedIsEnabled(
                distribution: .debug,
                storedValue: true
            )
        )
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: .legacy))
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: .unsubscribed))
    }

    func testForcePaywallDoesNotInventProductPricesInDiagnostics() {
        let annual = WeekFitProductSnapshot(
            id: WeekFitSubscriptionProductID.annual.rawValue,
            displayName: "Annual",
            displayPrice: "79,99 zł",
            price: Decimal(string: "79.99")!,
            periodUnit: .year,
            periodValue: 1,
            currencyCode: "PLN",
            monthlyEquivalentDisplay: "6,67 zł",
            introductoryOffer: nil,
            introductoryOfferEligibility: .unknown
        )
        let text = WeekFitStoreKitPaywallDiagnosticsFormatter.text(
            distribution: .debug,
            appVersion: "1.3.2",
            appBuild: "23",
            storefrontCountryCode: "POL",
            storefrontID: "143478",
            rawReturnedCount: 1,
            products: [annual],
            productsFailedToLoad: false,
            accessState: .legacy,
            forcePaywallActive: true
        )
        XCTAssertTrue(text.contains("Real access state: legacy"))
        XCTAssertTrue(text.contains("Force Paywall: ON"))
        XCTAssertTrue(text.contains("Display price: 79,99 zł"))
        XCTAssertTrue(text.contains("Intro eligibility: not evaluated"))
        XCTAssertTrue(text.contains("Intro offer: none"))
        XCTAssertFalse(text.contains("$34.99"))
        XCTAssertFalse(text.contains("$4.99"))
        XCTAssertFalse(text.contains("$2.92"))
    }

    func testReleaseDistributionsHideDiagnosticsAndForcePaywall() {
        XCTAssertFalse(AppDistribution.appStore.showsTemporaryStoreKitPaywallDiagnostics)
        XCTAssertFalse(AppDistribution.appStore.allowsTemporaryForcePaywall)
        XCTAssertFalse(AppDistribution.testFlight.showsTemporaryStoreKitPaywallDiagnostics)
        XCTAssertFalse(AppDistribution.testFlight.allowsTemporaryForcePaywall)
    }

    func testEntitlementGateIndependentOfForcePaywall() {
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: .legacy))
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: .subscribed))
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: .unsubscribed))
        XCTAssertTrue(
            WeekFitForcePaywallStore.resolvedIsEnabled(
                distribution: .debug,
                storedValue: true
            )
        )
    }
}
