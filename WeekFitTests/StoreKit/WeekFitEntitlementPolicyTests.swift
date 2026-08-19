import XCTest
@testable import WeekFit

final class WeekFitEntitlementPolicyTests: XCTestCase {
    private let cutoff = WeekFitMonetizationCutoff.date

    func testProvisionalCutoffIsNotConfirmedForSubmission() {
        XCTAssertFalse(WeekFitReleaseConfiguration.Monetization.cutoffConfirmedForAppStoreSubmission)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour],
            from: WeekFitReleaseConfiguration.Monetization.provisionalCutoffDate
        )
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 19)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(WeekFitMonetizationCutoff.date, WeekFitReleaseConfiguration.Monetization.cutoffDate)
    }

    func testOriginalPurchaseBeforeCutoffIsLegacy() {
        let original = cutoff.addingTimeInterval(-60)
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: original, environment: "Production"),
            subscription: nil
        )
        XCTAssertEqual(decision.state, .legacy)
        XCTAssertTrue(decision.shouldPersistVerifiedEntitlement)
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: .legacy))
    }

    #if DEBUG
    func testXcodeEnvironmentDoesNotGrandfatherArtificialPurchaseDate() {
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(
                originalPurchaseDate: Date(timeIntervalSince1970: 0),
                environment: "Xcode"
            ),
            subscription: nil
        )
        XCTAssertEqual(decision.state, .unsubscribed)
        XCTAssertTrue(decision.shouldPersistVerifiedEntitlement)
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }
    #endif

    func testOriginalPurchaseOnCutoffIsNotLegacy() {
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: cutoff, environment: "test"),
            subscription: nil
        )
        XCTAssertEqual(decision.state, .unsubscribed)
        XCTAssertTrue(decision.shouldPersistVerifiedEntitlement)
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: .unsubscribed))
    }

    func testNewUserWithoutSubscriptionNeedsPaywall() {
        let original = cutoff.addingTimeInterval(86_400)
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: original, environment: "test"),
            subscription: nil
        )
        XCTAssertEqual(decision.state, .unsubscribed)
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }

    func testActiveTrialGrantsAccessEvenForNewUsers() {
        let original = cutoff.addingTimeInterval(86_400)
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: original, environment: "test"),
            subscription: WeekFitSubscriptionSnapshot(
                productID: WeekFitSubscriptionProductID.annual.rawValue,
                isIntroductoryTrial: true,
                expirationDate: Date().addingTimeInterval(86_400),
                isExpired: false,
                isRevoked: false,
                inGraceOrRetry: false
            )
        )
        XCTAssertEqual(decision.state, .trial)
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }

    func testActiveMonthlySubscriptionGrantsAccess() {
        let original = cutoff.addingTimeInterval(86_400)
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: original, environment: "test"),
            subscription: WeekFitSubscriptionSnapshot(
                productID: WeekFitSubscriptionProductID.monthly.rawValue,
                isIntroductoryTrial: false,
                expirationDate: Date().addingTimeInterval(86_400),
                isExpired: false,
                isRevoked: false,
                inGraceOrRetry: false
            )
        )
        XCTAssertEqual(decision.state, .subscribed)
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }

    func testExpiredSubscriptionIsGatedAndDoesNotWipeEligibility() {
        let original = cutoff.addingTimeInterval(86_400)
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: original, environment: "test"),
            subscription: WeekFitSubscriptionSnapshot(
                productID: WeekFitSubscriptionProductID.annual.rawValue,
                isIntroductoryTrial: false,
                expirationDate: Date().addingTimeInterval(-60),
                isExpired: true,
                isRevoked: false,
                inGraceOrRetry: false
            )
        )
        XCTAssertEqual(decision.state, .expired)
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }

    func testBillingRetryKeepsAccess() {
        let original = cutoff.addingTimeInterval(86_400)
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: original, environment: "test"),
            subscription: WeekFitSubscriptionSnapshot(
                productID: WeekFitSubscriptionProductID.annual.rawValue,
                isIntroductoryTrial: false,
                expirationDate: Date().addingTimeInterval(-60),
                isExpired: true,
                isRevoked: false,
                inGraceOrRetry: true
            )
        )
        XCTAssertEqual(decision.state, .subscribed)
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }

    func testNeverResolvedStoreKitOutageFailsOpen() {
        let unavailable = WeekFitEntitlementPolicy.resolve(
            appTransaction: .unavailable,
            subscription: nil
        )
        XCTAssertEqual(unavailable.state, .loading)
        XCTAssertFalse(unavailable.shouldPersistVerifiedEntitlement)

        let unverified = WeekFitEntitlementPolicy.resolve(
            appTransaction: .unverified(environment: "test"),
            subscription: nil
        )
        XCTAssertEqual(unverified.state, .loading)
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: .loading))
    }

    func testPreviouslyVerifiedUnsubscribedStaysGatedWhenStoreKitIsDown() {
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .unavailable,
            subscription: nil,
            lastVerified: .unsubscribed
        )
        XCTAssertEqual(decision.state, .unsubscribed)
        XCTAssertFalse(decision.shouldPersistVerifiedEntitlement)
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }

    func testPreviouslyVerifiedExpiredStaysGatedWhenStoreKitIsDown() {
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .unavailable,
            subscription: nil,
            lastVerified: .expired
        )
        XCTAssertEqual(decision.state, .expired)
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }

    func testPreviouslyVerifiedLegacyKeepsAccessWhenStoreKitIsDown() {
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .unavailable,
            subscription: nil,
            lastVerified: .legacy
        )
        XCTAssertEqual(decision.state, .legacy)
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
        XCTAssertFalse(decision.shouldPersistVerifiedEntitlement)
    }

    func testVerifiedStoreKitOverridesStaleFallback() {
        let original = cutoff.addingTimeInterval(86_400)
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: original, environment: "test"),
            subscription: nil,
            lastVerified: .legacy
        )
        XCTAssertEqual(decision.state, .unsubscribed)
        XCTAssertTrue(decision.shouldPersistVerifiedEntitlement)
    }

    func testExpiredEntitlementFromStoreKitPersistsWhileAppTransactionIsDown() {
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .unavailable,
            subscription: WeekFitSubscriptionSnapshot(
                productID: WeekFitSubscriptionProductID.monthly.rawValue,
                isIntroductoryTrial: false,
                expirationDate: Date().addingTimeInterval(-60),
                isExpired: true,
                isRevoked: false,
                inGraceOrRetry: false
            ),
            lastVerified: .subscribed
        )
        XCTAssertEqual(decision.state, .expired)
        XCTAssertTrue(decision.shouldPersistVerifiedEntitlement)
    }

    func testUnverifiedExpiredSubscriptionFailsOpenWhenNeverVerified() {
        // If we never resolved entitlement here before, we must not immediately gate
        // based solely on a (possibly stale / partial) subscription snapshot.
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .unavailable,
            subscription: WeekFitSubscriptionSnapshot(
                productID: WeekFitSubscriptionProductID.monthly.rawValue,
                isIntroductoryTrial: false,
                expirationDate: Date().addingTimeInterval(-60),
                isExpired: true,
                isRevoked: false,
                inGraceOrRetry: false
            ),
            lastVerified: nil
        )

        XCTAssertEqual(decision.state, .loading)
        XCTAssertFalse(decision.shouldPersistVerifiedEntitlement)
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }

    func testLoadingUsesFallbackWhenPreviouslyVerified() {
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .loading,
            subscription: nil,
            lastVerified: .unsubscribed
        )
        XCTAssertEqual(decision.state, .unsubscribed)
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }

    func testLoadingFailsOpenWhenNeverResolved() {
        let decision = WeekFitEntitlementPolicy.resolve(appTransaction: .loading, subscription: nil)
        XCTAssertEqual(decision.state, .loading)
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: .loading))
        XCTAssertFalse(decision.shouldPersistVerifiedEntitlement)
    }

    func testBypassAloneDoesNotGrantAccess() {
        let original = cutoff.addingTimeInterval(86_400)
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: original, environment: "test"),
            subscription: nil,
            bypass: .none
        )
        XCTAssertEqual(decision.state, .unsubscribed)
        XCTAssertFalse(decision.shouldPersistVerifiedEntitlement)
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }

    func testForceLegacyUserOverrideDoesNotPersist() {
        let original = cutoff.addingTimeInterval(86_400)
        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: original, environment: "test"),
            subscription: nil,
            forceLegacyUser: true
        )
        XCTAssertEqual(decision.state, .legacy)
        XCTAssertFalse(decision.shouldPersistVerifiedEntitlement)
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: decision.state))
    }

    func testUnknownProductIsNotAnActiveSubscription() {
        XCTAssertFalse(
            WeekFitEntitlementPolicy.isActiveSubscription(
                WeekFitSubscriptionSnapshot(
                    productID: "com.other.app.premium",
                    isIntroductoryTrial: false,
                    expirationDate: Date().addingTimeInterval(86_400),
                    isExpired: false,
                    isRevoked: false,
                    inGraceOrRetry: false
                )
            )
        )
    }
}

#if DEBUG
final class WeekFitUITestSupportTests: XCTestCase {
    func testEntitlementOverrideParsingRequiresUITestingFlag() {
        XCTAssertNil(
            WeekFitUITestSupport.parseEntitlementOverrideState(
                from: ["-weekfit-entitlement-test-state=subscribed"],
                isUITesting: false
            )
        )
    }

    func testEntitlementOverrideParsingMapsKnownStates() {
        XCTAssertEqual(
            WeekFitUITestSupport.parseEntitlementOverrideState(
                from: ["-ui-testing", "-weekfit-entitlement-test-state=legacy"],
                isUITesting: true
            ),
            .legacy
        )
        XCTAssertEqual(
            WeekFitUITestSupport.parseEntitlementOverrideState(
                from: ["-ui-testing", "-weekfit-entitlement-test-state=loading"],
                isUITesting: true
            ),
            .loading
        )
        XCTAssertEqual(
            WeekFitUITestSupport.parseEntitlementOverrideState(
                from: ["-ui-testing", "-weekfit-entitlement-test-state=expired"],
                isUITesting: true
            ),
            .expired
        )
    }
}
#endif

final class WeekFitPaywallCopyTests: XCTestCase {
    func testIntroductoryWeekMapsToSevenDays() {
        XCTAssertEqual(
            WeekFitPaywallCopy.introductoryDayCount(
                from: WeekFitIntroductoryOfferSnapshot(periodValue: 1, periodUnit: .week)
            ),
            7
        )
        XCTAssertEqual(
            WeekFitPaywallCopy.introductoryDayCount(
                from: WeekFitIntroductoryOfferSnapshot(periodValue: 7, periodUnit: .day)
            ),
            7
        )
        XCTAssertNil(WeekFitPaywallCopy.introductoryDayCount(from: nil))
    }

    func testSavingsPercentMatchesCommercialExample() {
        let percent = WeekFitPaywallCopy.savingsPercent(
            monthlyPrice: Decimal(string: "4.99")!,
            yearlyPrice: Decimal(string: "34.99")!
        )
        XCTAssertEqual(percent, 42)
    }

    func testMonthlyEquivalentDividesYearlyByTwelve() {
        XCTAssertEqual(
            WeekFitPaywallCopy.monthlyEquivalent(yearlyPrice: Decimal(string: "34.99")!),
            Decimal(string: "34.99")! / 12
        )
    }
}
