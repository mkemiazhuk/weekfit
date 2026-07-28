import XCTest
@testable import WeekFit

final class CoachRecommendationCategoryMappingTests: XCTestCase {

    func testSleepScenarioMapsToSleep() {
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

    func testRecoveryFamiliesMapToRecovery() {
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

    func testSafetyAlertsOverrideScenarioCategory() {
        XCTAssertEqual(
            CoachRecommendationCategory.from(scenario: .duringEndurance, warningAlert: .hydrationCritical),
            .hydration
        )
        XCTAssertEqual(
            CoachRecommendationCategory.from(scenario: .stableDay, warningAlert: .fuelCritical),
            .nutrition
        )
    }

    func testAllScenariosMapWithoutSendingScenarioRawValue() throws {
        let recording = RecordingAnalyticsService()
        AppAnalytics.setSharedForTests(recording)
        defer { AppAnalytics.resetSharedForTests() }

        for scenario in CoachScenarioKey.allCases {
            let category = CoachRecommendationCategory.from(scenario: scenario)
            ProductAnalytics.coachRecommendationViewed(category: category)
            let event = try XCTUnwrap(recording.events(named: .coachRecommendationViewed).last)
            XCTAssertEqual(event.parameters[AnalyticsParameterKey.category], category.rawValue)
            XCTAssertNil(event.parameters["scenario"])
            XCTAssertFalse(event.parameters.values.contains(scenario.rawValue))
        }
    }

    func testProductAnalyticsScenarioHelperUsesMapping() {
        let recording = RecordingAnalyticsService()
        AppAnalytics.setSharedForTests(recording)
        defer { AppAnalytics.resetSharedForTests() }

        ProductAnalytics.coachRecommendationViewed(scenario: .duringStrength)
        XCTAssertEqual(
            recording.parameterValues(for: .coachRecommendationViewed, key: AnalyticsParameterKey.category),
            ["activity"]
        )
    }
}
