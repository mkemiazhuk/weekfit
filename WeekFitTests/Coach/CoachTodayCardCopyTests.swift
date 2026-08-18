import XCTest
@testable import WeekFit

final class CoachTodayCardCopyTests: XCTestCase {

    func testWalkTitleDoesNotEchoUpNextActivity() {
        let presentation = makePresentation(
            scenario: .walkLightDay,
            todayTitle: "Easy walk",
            todayMessage: "Easy pace — no goal to hit.",
            assessment: "Easy walk day — movement without a scoreboard."
        )

        let display = CoachTodayCardCopy.display(
            from: presentation,
            nextActivityTitle: "Walk"
        )

        XCTAssertFalse(
            CoachTodayCardCopy.echoesActivity(display.title, activityTitle: "Walk"),
            "Expected why-title, got: \(display.title)"
        )
        XCTAssertEqual(display.title, "Keep it light")
        XCTAssertEqual(display.message, "Easy pace — no goal to hit.")
    }

    func testStrengthTitleDoesNotEchoUpNextActivity() {
        let presentation = makePresentation(
            scenario: .activeStrength,
            todayTitle: "Strength next",
            todayMessage: "Leave a couple of reps in the tank.",
            assessment: "Strength next — keep something in reserve."
        )

        let display = CoachTodayCardCopy.display(
            from: presentation,
            nextActivityTitle: "Strength"
        )

        XCTAssertFalse(CoachTodayCardCopy.echoesActivity(display.title, activityTitle: "Strength"))
        XCTAssertFalse(display.title.lowercased().contains("strength"))
        XCTAssertEqual(display.message, "Leave a couple of reps in the tank.")
    }

    func testIndependentStanceTitleIsKept() {
        let presentation = makePresentation(
            scenario: .recoveryAfterHeavyYesterday,
            todayTitle: "Recovery day",
            todayMessage: "Yesterday still counts — go easier today."
        )

        let display = CoachTodayCardCopy.display(
            from: presentation,
            nextActivityTitle: "Walk"
        )

        XCTAssertEqual(display.title, "Recovery day")
        XCTAssertEqual(display.message, "Yesterday still counts — go easier today.")
    }

    func testEchoesActivityDetectsContainedEventName() {
        XCTAssertTrue(CoachTodayCardCopy.echoesActivity("Easy walk", activityTitle: "Walk"))
        XCTAssertTrue(CoachTodayCardCopy.echoesActivity("Before sauna", activityTitle: "Sauna"))
        XCTAssertTrue(CoachTodayCardCopy.echoesActivity("Strength next", activityTitle: "Strength"))
        XCTAssertFalse(CoachTodayCardCopy.echoesActivity("Keep it light", activityTitle: "Walk"))
        XCTAssertFalse(CoachTodayCardCopy.echoesActivity("Protect your energy", activityTitle: "Walk"))
    }

    private func makePresentation(
        scenario: CoachScenarioKey,
        todayTitle: String,
        todayMessage: String,
        assessment: String = "Keep the day calm."
    ) -> CoachUIPresentation {
        CoachUIPresentation(
            scenario: scenario,
            assessment: assessment,
            recommendation: todayMessage,
            avoid: "Don't add extra load.",
            nextAction: "",
            supportingSignals: [],
            warningMessage: nil,
            warningAlert: nil,
            semanticColor: .stable,
            alertSeverity: .none,
            icon: "figure.walk",
            urgencyLevel: .calm,
            statusLabel: "Steady",
            coachTitle: todayTitle,
            todayTitle: todayTitle,
            todayMessage: todayMessage,
            whyRows: []
        )
    }
}
