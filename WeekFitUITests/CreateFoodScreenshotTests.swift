import XCTest

/// Captures Create Food before/after barcode states.
final class CreateFoodScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
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

        let directory = URL(fileURLWithPath: "/tmp/WeekFitCreateFoodScreenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: fileURL)
        print("📸 Saved screenshot: \(fileURL.path)")
    }

    @MainActor
    private func openCreateFood(app: XCUIApplication) {
        let today = app.descendants(matching: .any)["screen.today"]
        XCTAssertTrue(today.waitForExistence(timeout: 20), "Today screen did not appear")

        app.buttons["tab.meals"].tap()
        let meals = app.descendants(matching: .any)["screen.meals"]
        XCTAssertTrue(meals.waitForExistence(timeout: 10))

        let create = app.descendants(matching: .any)["meals.create"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 8), "Create entry missing")
        create.tap()

        let customFood = app.descendants(matching: .any)["meals.creation.customFood"]
        XCTAssertTrue(customFood.waitForExistence(timeout: 8))
        customFood.tap()

        let form = app.descendants(matching: .any)["meals.foodForm"]
        XCTAssertTrue(form.waitForExistence(timeout: 8))
    }

    @MainActor
    func testCaptureCreateFoodBeforeScan() throws {
        let app = launchApp()
        openCreateFood(app: app)
        capture("create-food-before-scan", app: app)
    }

    @MainActor
    func testCaptureCreateFoodLoading() throws {
        let app = launchApp(extraArguments: ["-create-food-fixture-barcode-loading"])
        openCreateFood(app: app)
        XCTAssertTrue(app.staticTexts["Looking up product…"].waitForExistence(timeout: 4))
        capture("create-food-loading", app: app)
    }

    @MainActor
    func testCaptureCreateFoodSuccess() throws {
        let app = launchApp(extraArguments: ["-create-food-fixture-barcode-success"])
        openCreateFood(app: app)
        XCTAssertTrue(app.descendants(matching: .any)["meals.foodForm.barcodeResult"].waitForExistence(timeout: 4))
        capture("create-food-success", app: app)
    }

    @MainActor
    func testCaptureCreateFoodPartial() throws {
        let app = launchApp(extraArguments: ["-create-food-fixture-barcode-partial"])
        openCreateFood(app: app)
        XCTAssertTrue(app.descendants(matching: .any)["meals.foodForm.barcodeResult"].waitForExistence(timeout: 4))
        capture("create-food-partial", app: app)
    }

    @MainActor
    func testCaptureCreateFoodFailure() throws {
        let app = launchApp(extraArguments: ["-create-food-fixture-barcode-failure"])
        openCreateFood(app: app)
        XCTAssertTrue(app.descendants(matching: .any)["meals.foodForm.lookupBanner"].waitForExistence(timeout: 4))
        capture("create-food-failure", app: app)
    }
}
