//
//  WeekFitUITests.swift
//  WeekFitUITests
//

import XCTest

final class WeekFitUITests: XCTestCase {

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
    func testUITestLaunchShowsTodayScreen() throws {
        let app = launchApp()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.otherElements["screen.today"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["tabBar.main"].exists)
    }

    @MainActor
    func testCoreTabNavigation() throws {
        let app = launchApp()
        XCTAssertTrue(app.otherElements["screen.today"].waitForExistence(timeout: 8))

        app.buttons["tab.coach"].tap()
        XCTAssertTrue(app.otherElements["screen.coach"].waitForExistence(timeout: 5))

        app.buttons["tab.meals"].tap()
        XCTAssertTrue(app.otherElements["screen.meals"].waitForExistence(timeout: 5))

        app.buttons["tab.plan"].tap()
        XCTAssertTrue(app.otherElements["screen.plan"].waitForExistence(timeout: 5))

        app.buttons["tab.today"].tap()
        XCTAssertTrue(app.otherElements["screen.today"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLoginBypassFromLaunchArgument() throws {
        let app = launchApp()

        XCTAssertFalse(app.buttons["login.signIn"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["screen.today"].exists)
    }
}
