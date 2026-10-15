import XCTest
@testable import WeekFit

final class CoachTodayCardCopyTests: XCTestCase {

    func testFocusMirrorsCoachHeroWhenTitlesDifferFromUpNext() {
        let presentation = makePresentation(
            scenario: .walkRecoveryAction,
            coachTitle: "Walk logged",
            todayTitle: "Walk logged",
            todayMessage: "Keep the rest of the day calm.",
            assessment: "That walk already helped you ease off today's load.",
            recommendation: "Walk is logged — keep an easy pace from here."
        )

        let display = CoachTodayCardCopy.display(
            from: presentation,
            nextActivityTitle: "Beef Buckwheat"
        )

        XCTAssertEqual(display.title, "Walk logged")
        XCTAssertEqual(
            display.message,
            "That walk already helped you ease off today's load."
        )
    }

    func testWalkTitleDoesNotEchoUpNextActivity() {
        let presentation = makePresentation(
            scenario: .walkLightDay,
            coachTitle: "Easy walk",
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
            coachTitle: "Strength next",
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
            coachTitle: "Recovery day",
            todayTitle: "Recovery day",
            todayMessage: "Yesterday still counts — go easier today.",
            assessment: "Yesterday still counts — go easier today."
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
        coachTitle: String,
        todayTitle: String,
        todayMessage: String,
        assessment: String = "Keep the day calm.",
        recommendation: String? = nil
    ) -> CoachUIPresentation {
        CoachUIPresentation(
            scenario: scenario,
            assessment: assessment,
            recommendation: recommendation ?? todayMessage,
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
            coachTitle: coachTitle,
            todayTitle: todayTitle,
            todayMessage: todayMessage,
            whyRows: []
        )
    }
}
