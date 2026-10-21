import XCTest

/// Captures Food / Drinks / Workout / Recovery frequent-card polish in light and dark.
final class QuickSheetFrequentCardScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureFoodLight() throws {
        let app = launch(appearance: "light")
        openFood(app)
        revealFrequentCards(app)
        saveScreenshot(app, name: "frequent-food-light")
    }

    @MainActor
    func testCaptureFoodDark() throws {
        let app = launch(appearance: "dark")
        openFood(app)
        revealFrequentCards(app)
        saveScreenshot(app, name: "frequent-food-dark")
    }

    @MainActor
    func testCaptureDrinksLight() throws {
        let app = launch(appearance: "light")
        openDrinks(app)
        revealFrequentCards(app)
        saveScreenshot(app, name: "frequent-drinks-light")
    }

    @MainActor
    func testCaptureDrinksDark() throws {
        let app = launch(appearance: "dark")
        openDrinks(app)
        revealFrequentCards(app)
        saveScreenshot(app, name: "frequent-drinks-dark")
    }

    @MainActor
    func testCaptureWorkoutRecoveryLight() throws {
        let app = launch(appearance: "light")
        openActivity(app)
        revealFrequentCards(app)
        saveScreenshot(app, name: "frequent-workout-light")
        tapSegment(app, "Recovery")
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
        revealFrequentCards(app)
        saveScreenshot(app, name: "frequent-recovery-light")
    }

    @MainActor
    func testCaptureWorkoutRecoveryDark() throws {
        let app = launch(appearance: "dark")
        openActivity(app)
        revealFrequentCards(app)
        saveScreenshot(app, name: "frequent-workout-dark")
        tapSegment(app, "Recovery")
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
        revealFrequentCards(app)
        saveScreenshot(app, name: "frequent-recovery-dark")
    }

    @MainActor
    func testCaptureFrequentCardsAccessibilityLargeLight() throws {
        let app = launch(
            appearance: "light",
            extraArguments: [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityExtraLarge"
            ]
        )
        openFood(app)
        revealFrequentCards(app)
        saveScreenshot(app, name: "frequent-food-a11y-large-light")
        dismissSheet(app)

        openDrinks(app)
        revealFrequentCards(app)
        saveScreenshot(app, name: "frequent-drinks-a11y-large-light")
        dismissSheet(app)

        openActivity(app)
        revealFrequentCards(app)
        saveScreenshot(app, name: "frequent-workout-a11y-large-light")
    }

    @MainActor
    private func launch(appearance: String, extraArguments: [String] = []) -> XCUIApplication {
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
        ] + extraArguments
        app.launch()
        dismissSystemHealthAccessIfNeeded(app: app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        dismissSystemHealthAccessIfNeeded(app: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.today"].waitForExistence(timeout: 20),
            "Today screen did not appear"
        )
        return app
    }

    @MainActor
    private func openFood(_ app: XCUIApplication) {
        tapQuickAction(app, labels: ["Food", "Log food"])
        let sheet = app.descendants(matching: .any)["sheet.quickFoodLog"]
        XCTAssertTrue(
            sheet.waitForExistence(timeout: 10)
                || app.staticTexts["AI Nutrition Assistant"].waitForExistence(timeout: 4),
            "Food sheet missing"
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
    }

    @MainActor
    private func openDrinks(_ app: XCUIApplication) {
        tapQuickAction(app, labels: ["Drinks", "Log drinks"])
        let sheet = app.descendants(matching: .any)["sheet.quickDrinkLog"]
        XCTAssertTrue(
            sheet.waitForExistence(timeout: 10)
                || app.staticTexts["Log drinks"].waitForExistence(timeout: 4)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "drink")).firstMatch
                    .waitForExistence(timeout: 4),
            "Drinks sheet missing"
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
    }

    @MainActor
    private func openActivity(_ app: XCUIApplication) {
        scrollTodayToQuickActions(app)
        let identified = app.descendants(matching: .any)["today.quickAction.activity"]
        if identified.waitForExistence(timeout: 3) {
            identified.tap()
        } else {
            tapQuickAction(app, labels: ["Activity", "Start Activity", "Workout"])
        }
        let sheet = app.descendants(matching: .any)["sheet.activityStart"]
        XCTAssertTrue(
            sheet.waitForExistence(timeout: 10)
                || app.staticTexts["Start Activity"].waitForExistence(timeout: 4)
                || app.buttons["Workout"].waitForExistence(timeout: 4)
                || app.staticTexts["Frequently Used"].waitForExistence(timeout: 4),
            "Activity sheet missing"
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
    }

    @MainActor
    private func scrollTodayToQuickActions(_ app: XCUIApplication) {
        let activity = app.buttons["Activity"].firstMatch
        if activity.exists { return }
        for _ in 0..<4 {
            app.swipeUp()
            if activity.waitForExistence(timeout: 0.6) { return }
        }
    }

    @MainActor
    private func revealFrequentCards(_ app: XCUIApplication) {
        // Prefer settling on the default detent — a full swipe jumps into All lists.
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
    }

    @MainActor
    private func tapQuickAction(_ app: XCUIApplication, labels: [String]) {
        scrollTodayToQuickActions(app)
        for label in labels {
            let exact = app.buttons[label].firstMatch
            if exact.waitForExistence(timeout: 1.5) {
                exact.tap()
                return
            }
            // Quick actions use combined a11y labels: "Activity, Start".
            let contains = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH[c] %@", label)
            ).firstMatch
            if contains.waitForExistence(timeout: 1.5) {
                contains.tap()
                return
            }
            let text = app.staticTexts[label].firstMatch
            if text.waitForExistence(timeout: 0.8) {
                text.tap()
                return
            }
        }
        let fallback = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", labels[0])
        ).firstMatch
        XCTAssertTrue(fallback.waitForExistence(timeout: 6), "Quick action \(labels[0]) missing")
        fallback.tap()
    }

    @MainActor
    private func tapSegment(_ app: XCUIApplication, _ title: String) {
        let button = app.buttons[title].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 4), "\(title) segment missing")
        button.tap()
    }

    @MainActor
    private func dismissSheet(_ app: XCUIApplication) {
        for label in ["Close", "Cancel", "Done"] {
            let button = app.buttons[label].firstMatch
            if button.waitForExistence(timeout: 0.8) {
                button.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.35))
                return
            }
        }
        app.swipeDown()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
    }

    @MainActor
    private func dismissSystemHealthAccessIfNeeded(app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Don’t Allow", "Don't Allow", "Cancel", "OK"] {
            let button = springboard.buttons[title]
            if button.waitForExistence(timeout: 0.6) {
                button.tap()
            }
        }
        _ = app
    }

    @MainActor
    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 6))
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let docs = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/docs/screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: docs.appendingPathComponent("\(name).png"))

        let tmp = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.tmp/frequent-card-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: tmp.appendingPathComponent("\(name).png"))
        print("📸 Saved screenshot: \(name)")
    }
}
