import XCTest

final class TodayHierarchyScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureTodayHierarchyLiveSession() throws {
        let app = launch(extraArguments: ["-seed-today-live-session"])
        // Wait for Today + seeded live session before capturing.
        let active = app.descendants(matching: .any)["today.activeSession"]
        let finish = app.descendants(matching: .any)["today.finishActivity"]
        _ = active.waitForExistence(timeout: 12)
            || finish.waitForExistence(timeout: 2)
            || app.staticTexts["In progress"].waitForExistence(timeout: 2)
            || app.staticTexts["IN PROGRESS"].waitForExistence(timeout: 2)
            || app.staticTexts["Breath Work"].waitForExistence(timeout: 2)
            || app.buttons["Finish activity"].waitForExistence(timeout: 2)
        saveScreenshot(app, name: "today-hierarchy-live")

        let hasActiveCard = active.exists
            || finish.exists
            || app.staticTexts["In progress"].exists
            || app.staticTexts["IN PROGRESS"].exists
            || app.staticTexts["Finish activity"].exists
            || app.buttons["Finish activity"].exists
            || app.staticTexts["Breath Work"].exists
        XCTAssertTrue(hasActiveCard, "Active session card did not appear")
        XCTAssertTrue(
            app.staticTexts["View session"].waitForExistence(timeout: 3)
                || app.staticTexts["Breath Work"].exists,
            "Live session identity / Quick Log View session missing"
        )
    }

    @MainActor
    func testCaptureTodayHierarchyUpcoming() throws {
        let app = launch(extraArguments: ["-seed-today-upcoming"])
        saveScreenshot(app, name: "today-hierarchy-upcoming")
        XCTAssertTrue(
            app.staticTexts["Easy Run"].waitForExistence(timeout: 10)
                || app.staticTexts["Up next"].waitForExistence(timeout: 3)
                || app.staticTexts["UP NEXT"].waitForExistence(timeout: 3)
                || app.staticTexts["Next Up"].waitForExistence(timeout: 3),
            "Upcoming activity card did not appear"
        )
    }

    @MainActor
    func testCaptureTodayHierarchyCompleted() throws {
        let app = launch(extraArguments: ["-seed-today-completed-session"])
        saveScreenshot(app, name: "today-hierarchy-completed")
        // After finish, Today restores normal order — no permanent completion section.
        XCTAssertFalse(
            app.staticTexts["Finish activity"].exists,
            "Completed fixture must not keep a live Finish control"
        )
        XCTAssertTrue(
            app.otherElements["screen.today"].waitForExistence(timeout: 10)
                || app.staticTexts["Your day"].waitForExistence(timeout: 3)
                || app.staticTexts["Your Day"].waitForExistence(timeout: 3)
                || app.staticTexts["Log quickly"].waitForExistence(timeout: 3)
                || app.staticTexts["Quick Log"].waitForExistence(timeout: 3),
            "Today should restore the normal stack after completion"
        )
    }

    @MainActor
    func testCaptureTodayHierarchyIdle() throws {
        let app = launch(extraArguments: [])
        saveScreenshot(app, name: "today-hierarchy-idle")
        XCTAssertFalse(
            app.staticTexts["Finish activity"].exists,
            "Idle Today should not show a live Finish activity control"
        )
    }

    @MainActor
    func testCaptureMayaPearlCardLightAndDark() throws {
        let light = launch(extraArguments: [
            "-weekfit-appearance=light",
            "-weekfit-show-maya-card"
        ])
        let card = light.buttons["today.maya.call"]
        XCTAssertTrue(card.waitForExistence(timeout: 8), "Maya card did not appear on Today")
        XCTAssertTrue(light.staticTexts["Let's talk"].exists)
        let drink = light.buttons["today.quickAction.drinks"]
        XCTAssertTrue(drink.waitForExistence(timeout: 5))
        XCTAssertLessThan(
            drink.frame.maxY,
            light.windows.firstMatch.frame.maxY - 52,
            "Quick actions should sit above the tab bar without scrolling"
        )
        saveScreenshot(light, name: "today-maya-pearl-light")

        let dark = launch(extraArguments: [
            "-weekfit-appearance=dark",
            "-weekfit-show-maya-card"
        ])
        XCTAssertTrue(dark.buttons["today.maya.call"].waitForExistence(timeout: 8))
        saveScreenshot(dark, name: "today-maya-pearl-dark")

        let russian = launch(extraArguments: [
            "-weekfit-appearance=light",
            "-weekfit-show-maya-card",
            "-weekfit-language=ru"
        ])
        XCTAssertTrue(
            russian.staticTexts["Давай поговорим"].waitForExistence(timeout: 8)
                || russian.staticTexts["Майя"].waitForExistence(timeout: 2)
        )
        saveScreenshot(russian, name: "today-maya-pearl-ru")
    }

    @MainActor
    func testCaptureMayaCallStates() throws {
        let listening = launchCallPreview("listening", extra: ["-weekfit-appearance=light"])
        XCTAssertTrue(listening.staticTexts["Maya"].exists || listening.staticTexts["Майя"].exists)
        saveScreenshot(listening, name: "maya-call-listening-light")

        let speaking = launchCallPreview("speaking", extra: ["-weekfit-appearance=dark"])
        saveScreenshot(speaking, name: "maya-call-speaking-dark")

        let receipt = launchCallPreview("receipt", extra: ["-weekfit-appearance=light"])
        XCTAssertTrue(receipt.otherElements["planner.voice.realtime.receipt"].waitForExistence(timeout: 5))
        saveScreenshot(receipt, name: "maya-call-receipt-light")

        let connecting = launchCallPreview("connecting", extra: [
            "-weekfit-appearance=light",
            "-weekfit-reduce-motion"
        ])
        saveScreenshot(connecting, name: "maya-call-connecting-reduced-motion")
    }

    @MainActor
    private func launchCallPreview(_ phase: String, extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-weekfit-force-legacy-user",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-weekfit-maya-preview=\(phase)"
        ] + extra
        app.launch()
        XCTAssertTrue(
            app.otherElements["planner.voice.realtime"].waitForExistence(timeout: 20),
            "Maya call preview did not appear"
        )
        return app
    }

    @MainActor
    func testCaptureTodayLightAndDark() throws {
        let light = launch(extraArguments: ["-weekfit-appearance=light"])
        saveScreenshot(light, name: "today-light-theme")
        XCTAssertTrue(light.otherElements["screen.today"].exists)

        let dark = launch(extraArguments: ["-weekfit-appearance=dark"])
        saveScreenshot(dark, name: "today-dark-theme")
        XCTAssertTrue(dark.otherElements["screen.today"].exists)
    }

    @MainActor
    private func launch(extraArguments: [String]) -> XCUIApplication {
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
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ] + extraArguments
        app.launch()
        dismissSystemHealthAccessIfNeeded(app: app)
        // Nudge interruption monitors that require a hit-test.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        dismissSystemHealthAccessIfNeeded(app: app)
        XCTAssertTrue(
            app.otherElements["screen.today"].waitForExistence(timeout: 20),
            "Today screen did not appear"
        )
        dismissSystemHealthAccessIfNeeded(app: app)
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        return app
    }

    /// UI-test bypass can still surface the HealthKit sheet; dismiss so screenshots capture Today.
    @MainActor
    private func dismissSystemHealthAccessIfNeeded(app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let hosts = [springboard, app]
        let titles = ["OK", "Don’t Allow", "Don't Allow", "Dont Allow", "Cancel"]

        for _ in 0..<3 {
            var tapped = false
            for host in hosts {
                for title in titles {
                    let button = host.buttons[title]
                    if button.exists {
                        button.tap()
                        tapped = true
                        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
                        break
                    }
                }
                if tapped { break }
            }
            if !tapped { break }
        }
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

        let tmp = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.tmp/today-typography-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let tmpURL = tmp.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: tmpURL)
        print("📸 Saved screenshot: \(docsURL.path)")
        print("📸 Saved screenshot: \(tmpURL.path)")
    }
}
