import XCTest

/// Captures Morning Proposal Today card + review sheet.
///
/// Output: `/tmp/WeekFitMorningProposalScreenshots/*.png`
final class MorningProposalScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp(extraArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launchArguments.append("-AppleLanguages")
        app.launchArguments.append("(en)")
        app.launchArguments.append("-AppleLocale")
        app.launchArguments.append("en_US")
        app.launchArguments.append(contentsOf: extraArguments)
        app.launch()
        return app
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory = URL(fileURLWithPath: "/tmp/WeekFitMorningProposalScreenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: fileURL)

        // Also copy into the workspace for the agent to display.
        let workspace = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.screenshot-artifacts", isDirectory: true)
        try? FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let workspaceFile = workspace.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: workspaceFile)
        print("📸 Saved screenshot: \(fileURL.path)")
        print("📸 Workspace copy: \(workspaceFile.path)")
    }

    @MainActor
    func testCaptureMorningProposalTodayCard() throws {
        let app = launchApp(extraArguments: ["-seed-morning-proposal"])
        XCTAssertTrue(app.descendants(matching: .any)["screen.today"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["morning.proposal.card"].waitForExistence(timeout: 12))
        // Let layout settle.
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        capture("01-today-morning-proposal-card", app: app)
    }

    @MainActor
    func testCaptureMorningProposalReviewSheet() throws {
        let app = launchApp(extraArguments: [
            "-seed-morning-proposal",
            "-open-morning-proposal-review"
        ])
        XCTAssertTrue(app.descendants(matching: .any)["screen.today"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["morning.proposal.review"].waitForExistence(timeout: 12))
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        capture("02-morning-proposal-review", app: app)
    }
}
