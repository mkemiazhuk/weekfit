import XCTest

/// Visual localization pass across all 10 app languages.
/// Screenshots → `.tmp/i18n-audit/screenshots/`
///
/// Launch flags (DEBUG + `-ui-testing` only; production-inert):
/// - `-weekfit-language=`
/// - `-weekfit-complete-onboarding` / `-weekfit-force-onboarding`
/// - `-weekfit-skip-health-access`
/// - `-weekfit-force-paywall` (diagnostics force-paywall path)
/// - `-weekfit-entitlement-test-state=`
final class LocalizationVisualPassUITests: XCTestCase {

    private let languages: [(code: String, locale: String)] = [
        ("en", "en_US"),
        ("ru", "ru_RU"),
        ("zh-Hans", "zh_CN"),
        ("fr", "fr_FR"),
        ("pl", "pl_PL"),
        ("es", "es_ES"),
        ("de", "de_DE"),
        ("ja", "ja_JP"),
        ("it", "it_IT"),
        ("ko", "ko_KR")
    ]

    private var outDir: URL {
        URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.tmp/i18n-audit/screenshots", isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    @MainActor
    func testCaptureCoreTabsForAllLanguages() throws {
        for language in languages {
            let app = launch(
                language: language,
                extra: [
                    "-weekfit-force-legacy-user",
                    "-weekfit-complete-onboarding",
                    "-weekfit-skip-health-access",
                    "-weekfit-entitlement-test-state=subscribed"
                ]
            )
            dismissSystemAlerts(app)

            guard waitForToday(app) else {
                XCTFail("\(language.code): Today missing")
                app.terminate()
                continue
            }
            save("\(language.code)-01-today", app: app)

            tapTab(app, "tab.coach")
            _ = app.otherElements["screen.coach"].waitForExistence(timeout: 8)
            save("\(language.code)-02-coach", app: app)

            tapTab(app, "tab.meals")
            _ = app.otherElements["screen.meals"].waitForExistence(timeout: 8)
            save("\(language.code)-03-meals", app: app)

            tapTab(app, "tab.plan")
            _ = app.otherElements["screen.plan"].waitForExistence(timeout: 8)
            save("\(language.code)-04-plan", app: app)

            app.terminate()
        }
    }

    @MainActor
    func testCapturePaywallForAllLanguages() throws {
        for language in languages {
            let app = launch(
                language: language,
                extra: [
                    "-weekfit-force-legacy-user",
                    "-weekfit-complete-onboarding",
                    "-weekfit-skip-health-access",
                    "-weekfit-entitlement-test-state=subscribed",
                    "-weekfit-force-paywall"
                ]
            )
            dismissSystemAlerts(app)

            let paywall = app.buttons["paywall.cta"]
            XCTAssertTrue(
                paywall.waitForExistence(timeout: 16),
                "\(language.code): paywall.cta missing — not counting gate screens as paywall"
            )
            if paywall.exists {
                save("\(language.code)-06-paywall", app: app)
            }
            app.terminate()
        }
    }

    @MainActor
    func testCaptureOnboardingForAllLanguages() throws {
        for language in languages {
            let app = launch(
                language: language,
                extra: [
                    "-weekfit-force-legacy-user",
                    "-weekfit-force-onboarding",
                    "-weekfit-skip-health-access"
                ]
            )
            dismissSystemAlerts(app)

            let onboarding = app.otherElements["screen.onboarding"]
            XCTAssertTrue(
                onboarding.waitForExistence(timeout: 16)
                    || app.descendants(matching: .any)["screen.onboarding"].waitForExistence(timeout: 4),
                "\(language.code): onboarding UI not detected"
            )
            // Must not be the main tab shell.
            XCTAssertFalse(
                app.buttons["tab.today"].exists && app.otherElements["screen.today"].exists,
                "\(language.code): expected onboarding, got Today shell"
            )
            save("\(language.code)-07-onboarding", app: app)
            app.terminate()
        }
    }

    @MainActor
    func testCaptureQuickLogAndSettingsForAllLanguages() throws {
        for language in languages {
            let app = launch(
                language: language,
                extra: [
                    "-weekfit-force-legacy-user",
                    "-weekfit-complete-onboarding",
                    "-weekfit-skip-health-access",
                    "-weekfit-entitlement-test-state=subscribed"
                ]
            )
            dismissSystemAlerts(app)
            guard waitForToday(app) else {
                XCTFail("\(language.code): Today missing before sheets")
                app.terminate()
                continue
            }

            dismissSystemAlerts(app)
            openFoodQuickLog(app)
            dismissSystemAlerts(app)
            let foodOK = foodLogChromeVisible(app)
            save("\(language.code)-08-quicklog-food\(foodOK ? "" : "-miss")", app: app)
            if !foodOK { XCTFail("\(language.code): food quick log missing") }
            dismissSheet(app)
            dismissSystemAlerts(app)
            _ = waitForToday(app)

            dismissSystemAlerts(app)
            openDrinksQuickLog(app)
            dismissSystemAlerts(app)
            let drinkOK = drinkLogChromeVisible(app)
            save("\(language.code)-09-quicklog-drinks\(drinkOK ? "" : "-miss")", app: app)
            if !drinkOK { XCTFail("\(language.code): drinks quick log missing") }
            dismissSheet(app)
            dismissSystemAlerts(app)
            _ = waitForToday(app)

            openSettings(app)
            if app.descendants(matching: .any)["settings.open"].waitForExistence(timeout: 2)
                || app.navigationBars.firstMatch.waitForExistence(timeout: 4)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Language")).firstMatch
                    .waitForExistence(timeout: 4)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "WeekFit")).firstMatch.exists {
                save("\(language.code)-10-settings", app: app)
            } else {
                XCTFail("\(language.code): settings sheet missing")
            }

            app.terminate()
        }
    }

    // MARK: - Launch / helpers

    @MainActor
    private func launch(
        language: (code: String, locale: String),
        extra: [String]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for title in ["Don’t Allow", "Don't Allow", "OK", "Cancel", "Allow", "Not Now"]
            where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        app.launchArguments = [
            "-ui-testing",
            "-weekfit-language=\(language.code)",
            "-AppleLanguages", "(\(language.code))",
            "-AppleLocale", language.locale
        ] + extra
        app.launch()
        return app
    }

    @MainActor
    private func waitForToday(_ app: XCUIApplication) -> Bool {
        dismissSystemAlerts(app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        dismissSystemAlerts(app)
        return app.otherElements["screen.today"].waitForExistence(timeout: 20)
    }

    @MainActor
    private func tapTab(_ app: XCUIApplication, _ id: String) {
        let tab = app.buttons[id]
        if tab.waitForExistence(timeout: 4) {
            tab.tap()
        }
    }

    @MainActor
    private func openFoodQuickLog(_ app: XCUIApplication) {
        scrollForQuickActions(app)
        let identified = app.descendants(matching: .any)["today.quickAction.food"]
        if identified.waitForExistence(timeout: 6) {
            identified.tap()
            return
        }
        // Combined a11y label is "Food, Log food" (localized).
        let byLabel = app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR label CONTAINS[c] %@", "today.quickAction.food", "Food")
        ).firstMatch
        if byLabel.waitForExistence(timeout: 3) {
            byLabel.tap()
            return
        }
        tapLabeledButton(app, candidates: [
            "Food", "Log food", "Еда", "Питание", "Ernährung", "Mahlzeit",
            "Repas", "Comida", "食事", "식사", "Cibo", "Posiłek", "饮食", "食物"
        ])
    }

    @MainActor
    private func openDrinksQuickLog(_ app: XCUIApplication) {
        scrollForQuickActions(app)
        let identified = app.descendants(matching: .any)["today.quickAction.drinks"]
        if identified.waitForExistence(timeout: 6) {
            identified.tap()
            return
        }
        let byLabel = app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR label CONTAINS[c] %@", "today.quickAction.drinks", "Drink")
        ).firstMatch
        if byLabel.waitForExistence(timeout: 3) {
            byLabel.tap()
            return
        }
        tapLabeledButton(app, candidates: [
            "Drinks", "Log drink", "Getränke", "Напитки", "Boissons",
            "Bebidas", "ドリンク", "음료", "Bevande", "Napoje", "饮品", "음료 기록"
        ])
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        let open = app.descendants(matching: .any)["settings.open"]
        if open.waitForExistence(timeout: 4) {
            open.tap()
            return
        }
        // Profile chrome in header.
        let profile = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Profile")).firstMatch
        if profile.waitForExistence(timeout: 2) {
            profile.tap()
            return
        }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.12)).tap()
    }

    @MainActor
    private func scrollForQuickActions(_ app: XCUIApplication) {
        let food = app.descendants(matching: .any)["today.quickAction.food"]
        if food.exists { return }
        for _ in 0..<6 {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            if food.waitForExistence(timeout: 0.4) { return }
            if app.buttons["today.quickAction.activity"].waitForExistence(timeout: 0.2) { return }
        }
    }

    @MainActor
    private func tapLabeledButton(_ app: XCUIApplication, candidates: [String]) {
        for label in candidates {
            let exact = app.buttons[label].firstMatch
            if exact.waitForExistence(timeout: 0.6) {
                exact.tap()
                return
            }
            let begins = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", label)).firstMatch
            if begins.waitForExistence(timeout: 0.4) {
                begins.tap()
                return
            }
        }
        XCTFail("No matching quick-action among \(candidates.prefix(4))…")
    }

    @MainActor
    private func foodLogChromeVisible(_ app: XCUIApplication) -> Bool {
        if app.descendants(matching: .any)["sheet.quickFoodLog"].waitForExistence(timeout: 8) {
            return true
        }
        // Planner meal sheet can appear from the same quick-action path in some builds.
        let markers = [
            "AI Nutrition Assistant", "Log your food", "Add food", "Добавить еду",
            "Essen hinzufügen", "Ajouter un repas", "食事を追加", "음식 추가", "添加食物"
        ]
        for marker in markers {
            if app.staticTexts[marker].waitForExistence(timeout: 0.4) { return true }
        }
        return false
    }

    @MainActor
    private func drinkLogChromeVisible(_ app: XCUIApplication) -> Bool {
        if app.descendants(matching: .any)["sheet.quickDrinkLog"].waitForExistence(timeout: 8) {
            return true
        }
        let markers = ["Log drinks", "Drinks", "Напитки", "Getränke", "Boissons", "음료", "ドリンク"]
        for marker in markers {
            if app.staticTexts[marker].waitForExistence(timeout: 0.4) { return true }
        }
        return false
    }

    @MainActor
    private func dismissSheet(_ app: XCUIApplication) {
        for label in ["Close", "Cancel", "Done", "Schließen", "Abbrechen", "Закрыть", "Готово", "닫기", "閉じる"] {
            let button = app.buttons[label].firstMatch
            if button.waitForExistence(timeout: 0.5) {
                button.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.3))
                return
            }
        }
        app.swipeDown()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
    }

    @MainActor
    private func dismissSystemAlerts(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Don’t Allow", "Don't Allow", "Cancel", "OK", "Not Now"] {
            let button = springboard.buttons[title]
            if button.waitForExistence(timeout: 0.5) {
                button.tap()
            }
        }
        app.tap() // wake interruption monitor
        _ = app
    }

    @MainActor
    private func save(_ name: String, app: XCUIApplication) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = outDir.appendingPathComponent("\(name).png")
        try? shot.pngRepresentation.write(to: url)
        print("📸 \(url.path)")
    }
}
