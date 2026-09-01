import XCTest
@testable import WeekFit

/// Mapping helpers remain for local product logic; Firebase no longer receives health topic categories.
final class CoachRecommendationCategoryMappingTests: XCTestCase {

    func testSleepScenarioMapsToSleepLocally() {
        XCTAssertEqual(
            CoachRecommendationCategory.from(scenario: .morningReadiness),
            .sleep
        )
    }

    func testStableDayFallsBackToGeneral() {
        XCTAssertEqual(
            CoachRecommendationCategory.from(scenario: .stableDay),
            .general
        )
    }

    func testActivityFamiliesMapToActivity() {
        let activityScenarios: [CoachScenarioKey] = [
            .activeEndurance, .duringEndurance, .postEnduranceImmediate,
            .postEnduranceSettled, .eveningAfterEndurance,
            .activeRacket, .duringRacket, .postRacketImmediate,
            .postRacketSettled, .eveningAfterRacket,
            .activeStrength, .duringStrength, .postStrengthImmediate,
            .postStrengthSettled, .eveningAfterStrength
        ]
        for scenario in activityScenarios {
            XCTAssertEqual(
                CoachRecommendationCategory.from(scenario: scenario),
                .activity,
                scenario.rawValue
            )
        }
    }

    func testRecoveryFamiliesMapToRecoveryLocally() {
        let recoveryScenarios: [CoachScenarioKey] = [
            .tomorrowProtection, .protectTomorrowFresh,
            .recoveryAfterHeavyYesterday, .lowRecoveryPrep,
            .walkLightDay, .walkAfterHeavyLoad, .walkEveningWindDown, .walkRecoveryAction,
            .activeRecovery, .duringRecovery, .postRecoveryImmediate,
            .postRecoverySettled, .eveningAfterRecovery,
            .saunaPreparation, .saunaActive, .saunaRecovery
        ]
        for scenario in recoveryScenarios {
            XCTAssertEqual(
                CoachRecommendationCategory.from(scenario: scenario),
                .recovery,
                scenario.rawValue
            )
        }
    }

    func testSafetyAlertsOverrideScenarioCategoryLocally() {
        XCTAssertEqual(
            CoachRecommendationCategory.from(scenario: .duringEndurance, warningAlert: .hydrationCritical),
            .hydration
        )
        XCTAssertEqual(
            CoachRecommendationCategory.from(scenario: .stableDay, warningAlert: .fuelCritical),
            .nutrition
        )
    }

    func testProductAnalyticsDoesNotSendCoachHealthCategories() throws {
        let recording = RecordingAnalyticsService()
        AppAnalytics.setSharedForTests(recording)
        defer { AppAnalytics.resetSharedForTests() }

        for scenario in CoachScenarioKey.allCases {
            ProductAnalytics.coachRecommendationViewed(scenario: scenario)
            let event = try XCTUnwrap(recording.events(named: .coachRecommendationViewed).last)
            XCTAssertNil(event.parameters[AnalyticsParameterKey.category])
            XCTAssertNil(event.parameters["scenario"])
            XCTAssertEqual(event.parameters[AnalyticsParameterKey.source], "coach")
            XCTAssertTrue(AnalyticsPrivacyContract.violations(in: event.parameters).isEmpty)
            XCTAssertFalse(event.parameters.values.contains(scenario.rawValue))
        }
    }
}
