import XCTest
@testable import WeekFit

final class ProductAnalyticsTests: XCTestCase {

    private var recording: RecordingAnalyticsService!

    override func setUp() {
        super.setUp()
        recording = RecordingAnalyticsService()
        AppAnalytics.setSharedForTests(recording)
        ProductScreenTracker.shared.reset()
        ProductAnalyticsFlowTracker.shared.resetForTests()
    }

    override func tearDown() {
        AppAnalytics.resetSharedForTests()
        ProductScreenTracker.shared.reset()
        ProductAnalyticsFlowTracker.shared.resetForTests()
        recording = nil
        super.tearDown()
    }

    func testScreenIdentifiersMapToStableValues() {
        let expected: Set<String> = [
            "today", "coach", "meals", "plan", "settings", "onboarding",
            "recovery_details", "activity_details", "nutrition_details",
            "meal_builder", "help_weekfit", "feedback_form", "paywall"
        ]
        XCTAssertEqual(Set(AnalyticsScreen.allCases.map(\.rawValue)), expected)
    }

    func testRepeatedScreenTrackingDoesNotDuplicate() {
        ProductAnalytics.trackScreen(.today)
        ProductAnalytics.trackScreen(.today)
        ProductAnalytics.trackScreen(.today)
        XCTAssertEqual(recording.recordedScreens.filter { $0.screen == .today }.count, 1)

        ProductAnalytics.trackScreen(.coach)
        ProductAnalytics.trackScreen(.coach)
        XCTAssertEqual(recording.recordedScreens.filter { $0.screen == .coach }.count, 1)
        XCTAssertEqual(recording.recordedScreens.count, 2)
    }

    func testManualScreenCatalogStillTracksExpectedDestinations() {
        let screens: [AnalyticsScreen] = [
            .today, .coach, .meals, .mealBuilder, .plan, .settings,
            .recoveryDetails, .activityDetails, .nutritionDetails
        ]
        for screen in screens {
            ProductAnalytics.trackScreen(screen)
        }

        XCTAssertEqual(
            recording.recordedScreens.map(\.screen),
            screens,
            "Manual ProductScreenTracker must emit one screen_view per destination change"
        )

        // Re-tracking the active screen must not duplicate.
        ProductAnalytics.trackScreen(.nutritionDetails)
        XCTAssertEqual(recording.recordedScreens.count, screens.count)
    }

    func testFirebaseAutomaticScreenReportingDisabledInInfoPlist() {
        let value = Bundle.main.object(forInfoDictionaryKey: "FirebaseAutomaticScreenReportingEnabled")
        let disabled: Bool = {
            if let bool = value as? Bool { return bool == false }
            if let number = value as? NSNumber { return number.boolValue == false }
            return false
        }()
        XCTAssertTrue(
            disabled,
            "Info.plist must set FirebaseAutomaticScreenReportingEnabled=NO (Boolean) so only manual screen_view events are used"
        )
    }

    func testCustomProductEventsStillEmitThroughAnalyticsLayer() {
        ProductAnalytics.coachRecommendationViewed()
        ProductAnalytics.mealBuilderStarted(mode: .new, source: .meals)
        ProductAnalytics.mealBuilderCompleted(mode: .new, source: .meals)
        ProductAnalytics.foodLoggingCompleted(method: .quickLog, source: .today)

        XCTAssertEqual(recording.events(named: .coachRecommendationViewed).count, 1)
        XCTAssertEqual(recording.events(named: .mealBuilderStarted).count, 1)
        XCTAssertEqual(recording.events(named: .mealBuilderCompleted).count, 1)
        XCTAssertEqual(recording.events(named: .foodLoggingCompleted).count, 1)
    }

    func testFoodLoggingCompletedEmitsOnceAfterPersistenceSemantics() {
        ProductAnalytics.foodLoggingStarted(method: .quickLog, source: .today)
        ProductAnalytics.foodLoggingCompleted(method: .quickLog, source: .today)

        XCTAssertEqual(recording.events(named: .foodLoggingStarted).count, 1)
        XCTAssertEqual(recording.events(named: .foodLoggingCompleted).count, 1)
        XCTAssertTrue(recording.events(named: .foodLoggingFailed).isEmpty)
        XCTAssertEqual(
            recording.parameterValues(for: .foodLoggingCompleted, key: AnalyticsParameterKey.method),
            ["quick_log"]
        )
    }

    func testFoodLoggingCancelledDoesNotEmitCompletionOrFailure() {
        ProductAnalytics.foodLoggingStarted(method: .manual, source: .meals)
        ProductAnalytics.foodLoggingCancelled(method: .manual, source: .meals)

        XCTAssertEqual(recording.events(named: .foodLoggingCancelled).count, 1)
        XCTAssertTrue(recording.events(named: .foodLoggingCompleted).isEmpty)
        XCTAssertTrue(recording.events(named: .foodLoggingFailed).isEmpty)
    }

    func testBarcodeSuccessDoesNotIncludeScannedBarcode() {
        ProductAnalytics.barcodeScanStarted(source: .meals)
        ProductAnalytics.barcodeScanSucceeded(source: .meals)

        for event in recording.events(named: .barcodeScanSucceeded) {
            XCTAssertFalse(event.parameters.keys.contains("barcode"))
            XCTAssertEqual(event.parameters[AnalyticsParameterKey.source], "meals")
            XCTAssertEqual(Set(event.parameters.keys), [AnalyticsParameterKey.source])
        }
    }

    func testBarcodeLookupFailureMapsToBoundedReason() {
        let reasons: [BarcodeScanFailureReason] = [
            .cameraPermissionDenied, .cameraUnavailable, .barcodeNotRecognized,
            .productNotFound, .network, .decoding, .unknown
        ]
        for reason in reasons {
            ProductAnalytics.barcodeScanFailed(source: .meals, reason: reason)
        }
        let values = Set(recording.parameterValues(for: .barcodeScanFailed, key: AnalyticsParameterKey.reason))
        XCTAssertEqual(
            values,
            Set(reasons.map(\.rawValue))
        )
    }

    func testCoachRecommendationViewNotDuplicatedByHelperSemantics() {
        // Mirrors ExpertCoachView's once-guard: callers must not re-fire without reset.
        ProductAnalytics.coachRecommendationViewed(category: .recovery)
        ProductAnalytics.coachRecommendationViewed(category: .recovery)
        // Helper itself does not dedupe — view guard is required.
        XCTAssertEqual(recording.events(named: .coachRecommendationViewed).count, 2)

        for event in recording.events(named: .coachRecommendationViewed) {
            XCTAssertNil(event.parameters["text"])
            XCTAssertEqual(event.parameters[AnalyticsParameterKey.category], "recovery")
        }
    }

    func testCoachCompletionEventNotDefinedForUnreliableCompletion() {
        // Product UI has no coach action complete handler — ensure we did not invent it.
        XCTAssertNotNil(AnalyticsEvent(rawValue: "coach_recommendation_viewed"))
        XCTAssertNil(AnalyticsEvent(rawValue: "coach_action_completed"))
        XCTAssertNil(AnalyticsEvent(rawValue: "coach_action_tapped"))
        XCTAssertNil(AnalyticsEvent(rawValue: "coach_action_dismissed"))
    }

    func testHydrationLoggingCompletionAfterPersistenceSemantics() {
        ProductAnalytics.hydrationLoggingStarted(method: .quickLog, source: .today)
        ProductAnalytics.hydrationLoggingCompleted(method: .quickLog, source: .today)
        XCTAssertEqual(recording.events(named: .hydrationLoggingCompleted).count, 1)
        XCTAssertEqual(
            recording.parameterValues(for: .hydrationLoggingCompleted, key: AnalyticsParameterKey.method),
            ["quick_log"]
        )
    }

    func testActivityEventsContainNoHealthKitValues() {
        ProductAnalytics.activityStarted(category: .running, source: .today)
        ProductAnalytics.activityCompleted(category: .running, source: .today)

        let banned = ["hrv", "heart", "calorie", "distance", "pace", "route", "hkworkout", "bpm"]
        for event in recording.recordedEvents {
            for (key, value) in event.parameters {
                let haystack = "\(key)=\(value)".lowercased()
                for token in banned {
                    XCTAssertFalse(haystack.contains(token), "Found \(token) in \(haystack)")
                }
            }
        }
    }

    func testPlanItemEventsContainNoTitleNotesOrExactTime() {
        ProductAnalytics.planItemCreated(itemType: .activity)
        ProductAnalytics.planItemUpdated(itemType: .meal)
        ProductAnalytics.planItemCompleted(itemType: .habit)
        ProductAnalytics.planItemDeleted(itemType: .recovery)

        for event in recording.recordedEvents where event.event.rawValue.hasPrefix("plan_item_") {
            XCTAssertEqual(Set(event.parameters.keys), [AnalyticsParameterKey.itemType])
            XCTAssertFalse(event.parameters.values.contains { $0.contains(":") })
            XCTAssertFalse(event.parameters.values.contains { $0.contains(" ") })
        }
    }

    func testNotificationOpenContainsNoNotificationText() {
        ProductAnalytics.notificationOpened(category: .activity)
        let event = recording.events(named: .notificationOpened).first
        XCTAssertEqual(event?.parameters.keys.count, 1)
        XCTAssertEqual(event?.parameters[AnalyticsParameterKey.category], "activity")
        XCTAssertNil(event?.parameters["title"])
        XCTAssertNil(event?.parameters["body"])
    }

    func testDataResetLifecycleEvents() {
        ProductAnalytics.dataResetStarted()
        ProductScreenTracker.shared.trackScreenIfChanged(.today)
        ProductScreenTracker.shared.reset()
        ProductAnalytics.dataResetCompleted()
        ProductAnalytics.trackScreen(.today)

        XCTAssertEqual(recording.events(named: .dataResetStarted).count, 1)
        XCTAssertEqual(recording.events(named: .dataResetCompleted).count, 1)
        // After reset, today can be tracked again as a fresh destination.
        XCTAssertEqual(recording.recordedScreens.filter { $0.screen == .today }.count, 2)
    }

    func testNoSensitiveTokensInProductEventParameters() {
        ProductAnalytics.todayPrimaryActionTapped(.food)
        ProductAnalytics.todaySectionOpened(.recovery)
        ProductAnalytics.foodLoggingCompleted(method: .barcode, source: .meals)
        ProductAnalytics.mealBuilderCompleted(mode: .new, source: .meals)
        ProductAnalytics.barcodeScanFailed(source: .meals, reason: .productNotFound)
        ProductAnalytics.languageChanged(.en)

        let banned = [
            "hrv", "heart", "sleep", "calorie", "recovery_score", "mailto",
            "hkquantity", "localizeddescription", "openfoodfacts"
        ]
        for event in recording.recordedEvents {
            for (key, value) in event.parameters {
                XCTAssertFalse(value.contains("@"))
                let haystack = "\(key)=\(value)".lowercased()
                for token in banned {
                    XCTAssertFalse(haystack.contains(token), "\(event.event.rawValue): \(haystack)")
                }
            }
        }
    }
}
