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
        XCTAssertTrue(decision.shouldPersistVerifiedEntitlement)
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

    #if DEBUG
    func testForceNonLegacyIgnoresSandboxSentinelWithoutSkippingSubscription() {
        // Apple Sandbox sentinel date that otherwise grandfathered as legacy.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let sandboxSentinel = calendar.date(from: DateComponents(year: 2013, month: 8, day: 1))!

        let withoutForce = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: sandboxSentinel, environment: "Sandbox"),
            subscription: nil
        )
        XCTAssertEqual(withoutForce.state, .legacy)

        let forced = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: sandboxSentinel, environment: "Sandbox"),
            subscription: nil,
            forceNonLegacyAppTransaction: true
        )
        XCTAssertEqual(forced.state, .unsubscribed)
        XCTAssertTrue(forced.shouldPersistVerifiedEntitlement)
        XCTAssertFalse(WeekFitEntitlementPolicy.hasFullAccess(for: forced.state))

        let withActiveSub = WeekFitEntitlementPolicy.resolve(
            appTransaction: .verified(originalPurchaseDate: sandboxSentinel, environment: "Sandbox"),
            subscription: WeekFitSubscriptionSnapshot(
                productID: WeekFitSubscriptionProductID.monthly.rawValue,
                isIntroductoryTrial: false,
                expirationDate: Date().addingTimeInterval(86_400),
                isExpired: false,
                isRevoked: false,
                inGraceOrRetry: false
            ),
            forceNonLegacyAppTransaction: true
        )
        XCTAssertEqual(withActiveSub.state, .subscribed)
        XCTAssertTrue(WeekFitEntitlementPolicy.hasFullAccess(for: withActiveSub.state))
    }
    #endif

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
    func testIntroductoryDayAndWeekMapping() {
        XCTAssertEqual(
            WeekFitPaywallCopy.introductoryDayCount(
                from: WeekFitIntroductoryOfferSnapshot(
                    periodValue: 3,
                    periodUnit: .day,
                    paymentMode: .free
                )
            ),
            3
        )
        XCTAssertEqual(
            WeekFitPaywallCopy.introductoryDayCount(
                from: WeekFitIntroductoryOfferSnapshot(
                    periodValue: 1,
                    periodUnit: .week,
                    paymentMode: .free
                )
            ),
            7
        )
        XCTAssertNil(WeekFitPaywallCopy.introductoryDayCount(from: nil))
    }

    func testEligibleAnnualThreeDayFreeTrial() {
        let offer = WeekFitIntroductoryOfferSnapshot(
            periodValue: 3,
            periodUnit: .day,
            paymentMode: .free
        )
        XCTAssertEqual(
            WeekFitPaywallCopy.verifiedFreeTrialDayCount(offer: offer, eligibility: .eligible),
            3
        )
        let annual = makeProduct(
            id: WeekFitSubscriptionProductID.annual.rawValue,
            price: "79.99",
            displayPrice: "79,99 zł",
            periodUnit: .year,
            offer: offer,
            eligibility: .eligible
        )
        XCTAssertEqual(WeekFitPaywallCopy.verifiedFreeTrialDayCount(for: annual), 3)
    }

    func testVerifiedFreeTrialRequiresEligibleFreeOffer() {
        let freeThreeDays = WeekFitIntroductoryOfferSnapshot(
            periodValue: 3,
            periodUnit: .day,
            paymentMode: .free
        )
        XCTAssertEqual(
            WeekFitPaywallCopy.verifiedFreeTrialDayCount(offer: freeThreeDays, eligibility: .eligible),
            3
        )
        XCTAssertNil(
            WeekFitPaywallCopy.verifiedFreeTrialDayCount(offer: freeThreeDays, eligibility: .ineligible)
        )
        XCTAssertNil(
            WeekFitPaywallCopy.verifiedFreeTrialDayCount(offer: freeThreeDays, eligibility: .unknown)
        )
    }

    func testVerifiedFreeTrialRejectsNonFreePaymentMode() {
        let paid = WeekFitIntroductoryOfferSnapshot(
            periodValue: 3,
            periodUnit: .day,
            paymentMode: .payAsYouGo
        )
        XCTAssertNil(
            WeekFitPaywallCopy.verifiedFreeTrialDayCount(offer: paid, eligibility: .eligible)
        )
    }

    func testVerifiedFreeTrialNilWithoutIntroOffer() {
        XCTAssertNil(
            WeekFitPaywallCopy.verifiedFreeTrialDayCount(offer: nil, eligibility: .eligible)
        )
        XCTAssertNil(
            WeekFitPaywallCopy.verifiedFreeTrialDayCount(offer: nil, eligibility: .unknown)
        )
    }

    func testMonthlySelectedUsesSelectedProductForTrialCTA() {
        let annual = makeProduct(
            id: WeekFitSubscriptionProductID.annual.rawValue,
            price: "79.99",
            displayPrice: "79,99 zł",
            periodUnit: .year,
            offer: .init(periodValue: 3, periodUnit: .day, paymentMode: .free),
            eligibility: .eligible
        )
        let monthly = makeProduct(
            id: WeekFitSubscriptionProductID.monthly.rawValue,
            price: "19.99",
            displayPrice: "19,99 zł",
            periodUnit: .month,
            offer: nil,
            eligibility: .unknown
        )

        XCTAssertEqual(WeekFitPaywallCopy.verifiedFreeTrialDayCount(for: annual), 3)
        XCTAssertNil(WeekFitPaywallCopy.verifiedFreeTrialDayCount(for: monthly))
    }

    func testPolandSavingsMatchesObservedStorefront() {
        let percent = WeekFitPaywallCopy.savingsPercent(
            monthlyPrice: Decimal(string: "19.99")!,
            yearlyPrice: Decimal(string: "79.99")!
        )
        // 1 - 79.99 / (19.99 * 12) ≈ 66.65% → 67
        XCTAssertEqual(percent, 67)
    }

    func testSavingsPercentMatchesCommercialExample() {
        let percent = WeekFitPaywallCopy.savingsPercent(
            monthlyPrice: Decimal(string: "4.99")!,
            yearlyPrice: Decimal(string: "34.99")!
        )
        XCTAssertEqual(percent, 42)
    }

    func testRegionalSavingsDiffersFromUSExample() {
        let percent = WeekFitPaywallCopy.savingsPercent(
            monthlyPrice: Decimal(string: "19.99")!,
            yearlyPrice: Decimal(string: "149.99")!
        )
        // 1 - 149.99 / (19.99 * 12) ≈ 37.47% → 37
        XCTAssertEqual(percent, 37)
        XCTAssertNotEqual(percent, 42)
    }

    func testSavingsDoesNotRequireIntroductoryOffer() {
        let percent = WeekFitPaywallCopy.savingsPercent(
            monthlyPrice: Decimal(string: "19.99")!,
            yearlyPrice: Decimal(string: "79.99")!
        )
        XCTAssertEqual(percent, 67)
    }

    func testMonthlyEquivalentDividesYearlyByTwelve() {
        XCTAssertEqual(
            WeekFitPaywallCopy.monthlyEquivalent(yearlyPrice: Decimal(string: "79.99")!),
            Decimal(string: "79.99")! / 12
        )
    }

    private func makeProduct(
        id: String,
        price: String,
        displayPrice: String,
        periodUnit: WeekFitSubscriptionPeriodUnit,
        offer: WeekFitIntroductoryOfferSnapshot?,
        eligibility: WeekFitIntroEligibility
    ) -> WeekFitProductSnapshot {
        WeekFitProductSnapshot(
            id: id,
            displayName: id,
            displayPrice: displayPrice,
            price: Decimal(string: price)!,
            periodUnit: periodUnit,
            periodValue: 1,
            currencyCode: "PLN",
            monthlyEquivalentDisplay: nil,
            introductoryOffer: offer,
            introductoryOfferEligibility: eligibility
        )
    }
}
