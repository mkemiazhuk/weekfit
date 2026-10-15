import XCTest

final class TodayRedesignScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureTodayRedesignScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-weekfit-force-legacy-user",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()

        XCTAssertTrue(
            app.otherElements["screen.today"].waitForExistence(timeout: 20),
            "Today screen did not appear"
        )

        RunLoop.current.run(until: Date().addingTimeInterval(1.5))

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "today-redesign"
        attachment.lifetime = .keepAlways
        add(attachment)

        let docs = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/docs/screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let docsURL = docs.appendingPathComponent("today-redesign.png")
        try? screenshot.pngRepresentation.write(to: docsURL)
        print("📸 Saved screenshot: \(docsURL.path)")
    }
}
