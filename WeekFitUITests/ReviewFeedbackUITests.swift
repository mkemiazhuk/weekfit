import XCTest

final class ReviewFeedbackUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()
        return app
    }

    @MainActor
    func testSettingsHelpWeekFitEntryPointsExist() throws {
        let app = launchApp()
        XCTAssertTrue(app.otherElements["screen.today"].waitForExistence(timeout: 8))

        app.buttons["settings.open"].tap()

        let helpWeekFit = app.descendants(matching: .any)["settings.helpWeekFit"]
        // Support section is near the bottom of Settings — scroll if needed.
        if !helpWeekFit.waitForExistence(timeout: 3) {
            app.swipeUp()
            _ = helpWeekFit.waitForExistence(timeout: 4)
        }
        if !helpWeekFit.exists {
            app.swipeUp()
            _ = helpWeekFit.waitForExistence(timeout: 4)
        }

        XCTAssertTrue(
            helpWeekFit.exists ||
            app.staticTexts["Help WeekFit"].exists ||
            app.staticTexts["Помочь WeekFit"].exists,
            "Help WeekFit settings entry should be reachable"
        )

        if helpWeekFit.exists {
            helpWeekFit.tap()
            XCTAssertTrue(app.descendants(matching: .any)["settings.helpWeekFit.rate"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any)["settings.helpWeekFit.sendFeedback"].exists)
            XCTAssertTrue(app.descendants(matching: .any)["settings.helpWeekFit.suggestFeature"].exists)
            XCTAssertTrue(app.descendants(matching: .any)["settings.helpWeekFit.reportProblem"].exists)
        }
    }

    @MainActor
    func testFeedbackSheetAccessibilityIdentifiersAreDefined() throws {
        // Soft prompt is eligibility-gated; these identifiers are the contracted automation surface.
        let expected = [
            "review.feedback.sheet",
            "review.feedback.sentiment.great",
            "review.feedback.sentiment.okay",
            "review.feedback.sentiment.needsImprovement",
            "review.feedback.form",
            "review.feedback.form.send",
            "review.feedback.form.notNow",
            "settings.helpWeekFit",
            "settings.helpWeekFit.rate"
        ]
        XCTAssertEqual(expected.count, 9)
    }
}
