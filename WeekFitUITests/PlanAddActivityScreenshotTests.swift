import XCTest

/// Captures Plan Add Activity sheet for Meal / Workout / Recovery / Habit polish review.
final class PlanAddActivityScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturePlanAddMealWorkoutRecoveryHabit() throws {
        let app = launch()
        openPlanAddSheet(app: app)

        XCTAssertTrue(app.navigationBars["Plan a meal"].waitForExistence(timeout: 8))

        tapFirstLibraryCard(app)
        saveScreenshot(app, name: "plan-add-meal")

        tapCategory(app, "Workout")
        XCTAssertTrue(app.navigationBars["Plan a workout"].waitForExistence(timeout: 4))
        tapFirstLibraryCard(app)
        saveScreenshot(app, name: "plan-add-workout")

        tapCategory(app, "Recovery")
        XCTAssertTrue(app.navigationBars["Plan recovery"].waitForExistence(timeout: 4))
        tapFirstLibraryCard(app)
        saveScreenshot(app, name: "plan-add-recovery")

        tapCategory(app, "Habit")
        XCTAssertTrue(app.navigationBars["Plan a habit"].waitForExistence(timeout: 4))
        tapFirstLibraryCard(app)
        saveScreenshot(app, name: "plan-add-habit")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Health Access") { alert in
            for title in ["Don’t Allow", "Don't Allow", "OK", "Cancel"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        app.launchArguments = [
            "-ui-testing",
            "-weekfit-entitlement-test-state=subscribed",
            "-weekfit-appearance=light",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
        dismissSystemHealthAccessIfNeeded(app: app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        dismissSystemHealthAccessIfNeeded(app: app)
        return app
    }

    @MainActor
    private func openPlanAddSheet(app: XCUIApplication) {
        let planTab = app.buttons["tab.plan"]
        if planTab.waitForExistence(timeout: 4) {
            planTab.tap()
        } else {
            app.tabBars.buttons["Plan"].tap()
        }

        XCTAssertTrue(app.descendants(matching: .any)["screen.plan"].waitForExistence(timeout: 12))

        let add = app.buttons["Add activity"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 8), "Add activity control missing")
        add.tap()

        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 8))
    }

    @MainActor
    private func tapCategory(_ app: XCUIApplication, _ title: String) {
        let button = app.buttons[title].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 4), "\(title) category missing")
        button.tap()
    }

    /// Taps the leading library card in the horizontal carousel.
    @MainActor
    private func tapFirstLibraryCard(_ app: XCUIApplication) {
        // Prefer cards with kcal (meals) or known activity subtitles.
        let mealCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "kcal")).firstMatch
        if mealCard.waitForExistence(timeout: 1.2) {
            mealCard.tap()
            return
        }

        // Activity cards: tap near leading content below the date row.
        let frame = app.frame
        let point = CGVector(
            dx: (contentPadding + 80) / max(frame.width, 1),
            dy: 0.38
        )
        app.coordinate(withNormalizedOffset: point).tap()
    }

    private var contentPadding: CGFloat { 20 }

    @MainActor
    private func dismissSystemHealthAccessIfNeeded(app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Don’t Allow", "Don't Allow", "OK", "Cancel"] {
            let button = springboard.buttons[title]
            if button.waitForExistence(timeout: 0.5) {
                button.tap()
            }
        }
        _ = app
    }

    @MainActor
    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 6))
        // Brief settle for selection / footer confirmation.
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let workspaceDir = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.tmp/plan-add-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: workspaceDir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: workspaceDir.appendingPathComponent("\(name).png"))
        print("📸 Saved screenshot: \(workspaceDir.appendingPathComponent("\(name).png").path)")
    }
}
