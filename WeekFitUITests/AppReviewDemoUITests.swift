import XCTest

final class AppReviewDemoUITests: XCTestCase {

    private let reviewerEmail = "review@weekfit.app"
    private let reviewerPassword = "review_passw0rd"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func signInAsReviewer(in app: XCUIApplication) {
        app.buttons["login.signIn"].tap()

        let emailField = app.textFields["login.signIn.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(reviewerEmail)

        let passwordField = app.secureTextFields["login.signIn.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        passwordField.typeText(reviewerPassword)

        app.buttons["login.signIn.submit"].tap()
    }

    @MainActor
    func testReviewerCredentialLoginPopulatesApp() throws {
        let app = launchApp()

        XCTAssertTrue(app.buttons["login.signIn"].waitForExistence(timeout: 8))
        signInAsReviewer(in: app)

        XCTAssertTrue(app.otherElements["screen.today"].waitForExistence(timeout: 12))

        app.buttons["tab.coach"].tap()
        XCTAssertTrue(app.otherElements["screen.coach"].waitForExistence(timeout: 8))

        app.buttons["tab.meals"].tap()
        XCTAssertTrue(app.otherElements["screen.meals"].waitForExistence(timeout: 8))

        app.buttons["tab.plan"].tap()
        XCTAssertTrue(app.otherElements["screen.plan"].waitForExistence(timeout: 8))

        app.buttons["tab.today"].tap()
        XCTAssertTrue(app.otherElements["screen.today"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testReviewerDemoPersistsAcrossRelaunch() throws {
        let app = launchApp()
        signInAsReviewer(in: app)
        XCTAssertTrue(app.otherElements["screen.today"].waitForExistence(timeout: 12))

        app.terminate()
        let relaunched = launchApp()
        XCTAssertTrue(relaunched.otherElements["screen.today"].waitForExistence(timeout: 8))
    }
}
