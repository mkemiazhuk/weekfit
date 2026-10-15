import XCTest

/// Screenshots for the Food quick-log sheet (AI Nutrition Assistant layout).
final class FoodLogScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureFoodLogLightRequiresSubscription() throws {
        let app = launch(
            entitlement: "unsubscribed",
            extraArguments: ["-weekfit-appearance=light"]
        )
        openFoodSheet(app: app)
        saveScreenshot(app, name: "food-log-light-requires-subscription")
        XCTAssertTrue(app.staticTexts["Requires paid subscription."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["AI Nutrition Assistant"].exists)
    }

    @MainActor
    func testCaptureFoodLogLightIncludedInPremium() throws {
        let app = launch(
            entitlement: "subscribed",
            extraArguments: ["-weekfit-appearance=light"]
        )
        openFoodSheet(app: app)
        saveScreenshot(app, name: "food-log-light-included")
        XCTAssertTrue(app.staticTexts["Included in Premium"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testCaptureFoodLogDarkRequiresSubscription() throws {
        let app = launch(
            entitlement: "unsubscribed",
            extraArguments: ["-weekfit-appearance=dark"]
        )
        openFoodSheet(app: app)
        saveScreenshot(app, name: "food-log-dark-requires-subscription")
        XCTAssertTrue(app.staticTexts["Requires paid subscription."].waitForExistence(timeout: 4))
    }

    @MainActor
    func testCaptureFoodLogAccessibilityLarge() throws {
        let app = launch(
            entitlement: "unsubscribed",
            extraArguments: [
                "-weekfit-appearance=light",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraLarge"
            ]
        )
        openFoodSheet(app: app)
        saveScreenshot(app, name: "food-log-accessibility-large")
        XCTAssertTrue(app.staticTexts["AI Nutrition Assistant"].waitForExistence(timeout: 4))
    }

    @MainActor
    private func launch(entitlement: String, extraArguments: [String]) -> XCUIApplication {
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
            "-weekfit-entitlement-test-state=\(entitlement)",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ] + extraArguments
        app.launch()
        dismissSystemHealthAccessIfNeeded(app: app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        dismissSystemHealthAccessIfNeeded(app: app)
        return app
    }

    @MainActor
    private func openFoodSheet(app: XCUIApplication) {
        let today = app.descendants(matching: .any)["screen.today"]
        XCTAssertTrue(today.waitForExistence(timeout: 20), "Today screen did not appear")

        // Prefer explicit Food quick-action label; fall back to fork.knife / Log food variants.
        let foodButton = app.buttons["Food"].firstMatch
        if foodButton.waitForExistence(timeout: 4) {
            foodButton.tap()
        } else if app.staticTexts["Food"].waitForExistence(timeout: 2) {
            app.staticTexts["Food"].tap()
        } else {
            let fork = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Food")).firstMatch
            XCTAssertTrue(fork.waitForExistence(timeout: 6), "Food quick action missing")
            fork.tap()
        }

        let sheet = app.descendants(matching: .any)["sheet.quickFoodLog"]
        XCTAssertTrue(
            sheet.waitForExistence(timeout: 10)
                || app.staticTexts["AI Nutrition Assistant"].waitForExistence(timeout: 4)
                || app.staticTexts["Log your food"].waitForExistence(timeout: 4),
            "Food log sheet did not appear"
        )
    }

    @MainActor
    private func dismissSystemHealthAccessIfNeeded(app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Don’t Allow", "Don't Allow", "Cancel", "OK"] {
            let button = springboard.buttons[title]
            if button.waitForExistence(timeout: 1.2) {
                button.tap()
            }
        }
        _ = app
    }

    @MainActor
    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let docs = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/docs/screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let docsURL = docs.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: docsURL)
        print("📸 Saved screenshot: \(docsURL.path)")
    }
}
