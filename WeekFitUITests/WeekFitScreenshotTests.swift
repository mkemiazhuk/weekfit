//
//  WeekFitScreenshotTests.swift
//  WeekFitUITests
//
//  Captures App Store screenshot candidates. Run:
//  xcodebuild test -scheme WeekFit \
//    -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
//    -only-testing:WeekFitUITests/WeekFitScreenshotTests
//
//  Screenshots are saved to the test result bundle and stdout path below.
//

import XCTest

final class WeekFitScreenshotTests: XCTestCase {

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
    private func capture(_ name: String, app: XCUIApplication) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("WeekFitAppStoreScreenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(name).png")
        let imageData = screenshot.pngRepresentation
        try? imageData.write(to: fileURL)
        print("📸 Saved screenshot: \(fileURL.path)")
    }

    @MainActor
    func testCaptureCoreTabScreenshots() throws {
        let app = launchApp()
        XCTAssertTrue(app.otherElements["screen.today"].waitForExistence(timeout: 10))
        capture("01-today", app: app)

        app.buttons["tab.coach"].tap()
        XCTAssertTrue(app.otherElements["screen.coach"].waitForExistence(timeout: 8))
        capture("02-coach", app: app)

        app.buttons["tab.meals"].tap()
        XCTAssertTrue(app.otherElements["screen.meals"].waitForExistence(timeout: 8))
        capture("03-meals", app: app)

        app.buttons["tab.plan"].tap()
        XCTAssertTrue(app.otherElements["screen.plan"].waitForExistence(timeout: 8))
        capture("04-plan", app: app)
    }
}
