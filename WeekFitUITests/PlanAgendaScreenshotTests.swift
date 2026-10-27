import XCTest

/// Captures Plan agenda redesign screenshots (light / dark).
final class PlanAgendaScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturePlanAgendaLightAndDark() throws {
        capture(appearance: "light")
        capture(appearance: "dark")
    }

    @MainActor
    private func capture(appearance: String) {
        let app = launch(appearance: appearance)
        openPlan(app)
        saveScreenshot(app, name: "plan-agenda-\(appearance)")
    }

    @MainActor
    private func launch(appearance: String) -> XCUIApplication {
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
            "-weekfit-appearance=\(appearance)",
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
    private func openPlan(_ app: XCUIApplication) {
        let planTab = app.buttons["tab.plan"]
        if planTab.waitForExistence(timeout: 4) {
            planTab.tap()
        } else {
            app.tabBars.buttons["Plan & journal"].tap()
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.plan"].waitForExistence(timeout: 12),
            "Plan screen missing"
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }

    @MainActor
    private func dismissSystemHealthAccessIfNeeded(app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Don’t Allow", "Don't Allow", "Cancel", "OK"] {
            let button = springboard.buttons[title]
            if button.waitForExistence(timeout: 0.5) {
                button.tap()
            }
        }
        _ = app
    }

    @MainActor
    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let docs = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/docs/screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: docs.appendingPathComponent("\(name).png"))

        let tmp = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.tmp/plan-agenda-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: tmp.appendingPathComponent("\(name).png"))
        print("📸 Saved \(name)")
    }
}
