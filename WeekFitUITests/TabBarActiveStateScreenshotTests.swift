import XCTest

/// Captures bottom-tab active states (light / dark × Today / Coach / Meals / Plan).
final class TabBarActiveStateScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureActiveTabStatesLightAndDark() throws {
        for appearance in ["light", "dark"] {
            let app = launch(appearance: appearance)
            for tab in ["today", "coach", "meals", "plan"] {
                selectTab(app, name: tab)
                saveScreenshot(app, name: "tabbar-\(appearance)-\(tab)")
            }
        }
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
            "-weekfit-force-legacy-user",
            "-weekfit-entitlement-test-state=subscribed",
            "-weekfit-appearance=\(appearance)",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
        dismissSystemHealthAccessIfNeeded(app: app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        dismissSystemHealthAccessIfNeeded(app: app)
        XCTAssertTrue(
            app.otherElements["tabBar.main"].waitForExistence(timeout: 20)
                || app.otherElements["screen.today"].waitForExistence(timeout: 12),
            "Tab bar / Today did not appear"
        )
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        return app
    }

    @MainActor
    private func selectTab(_ app: XCUIApplication, name: String) {
        let button = app.buttons["tab.\(name)"]
        if button.waitForExistence(timeout: 4) {
            button.tap()
        } else {
            let fallbackTitle: String = {
                switch name {
                case "today": return "Today"
                case "coach": return "Coach"
                case "meals": return "Meals"
                case "plan": return "Plan & journal"
                default: return name.capitalized
                }
            }()
            app.buttons[fallbackTitle].tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.55))
    }

    @MainActor
    private func dismissSystemHealthAccessIfNeeded(app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Don’t Allow", "Don't Allow", "Cancel", "OK"] {
            let button = springboard.buttons[title]
            if button.waitForExistence(timeout: 0.4) {
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

        let tmp = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.tmp/tabbar-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: tmp.appendingPathComponent("\(name).png"))
        print("📸 Saved \(name)")
    }
}
