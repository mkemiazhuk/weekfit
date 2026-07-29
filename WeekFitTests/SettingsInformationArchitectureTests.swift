import XCTest
@testable import WeekFit

final class SettingsInformationArchitectureTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var service: ProfileService!

    override func setUp() {
        super.setUp()
        suiteName = "weekfit.tests.settings.ia.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        service = ProfileService(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        service = nil
        suiteName = nil
        super.tearDown()
    }

    func testPreferenceSettingsIncludeNutritionGoalAndExcludePrivacyDeadEnd() {
        let preferences = service.loadPreferenceSettings()
        let types = preferences.map(\.type)

        XCTAssertEqual(types, [.notifications, .language, .nightComfort, .nutritionGoal, .units])
        XCTAssertFalse(types.contains(.account))
        XCTAssertFalse(types.contains(.appleHealth))
    }

    func testRootSectionsKeepAccountHealthAndSupportSeparate() {
        XCTAssertEqual(service.loadAccountSettings().map(\.type), [.account])
        XCTAssertEqual(service.loadHealthSettings().map(\.type), [.appleHealth])
        XCTAssertEqual(service.loadSupportSettings().map(\.type), [.helpWeekFit, .help])
        XCTAssertEqual(service.loadPrivacyLegalSettings().map(\.type), [.terms])
    }

    func testNutritionGoalDestinationIsNotUnderAccount() {
        let accountTypes = service.loadAccountSettings().map(\.type)
        XCTAssertFalse(accountTypes.contains(.nutritionGoal))
        XCTAssertTrue(service.loadPreferenceSettings().map(\.type).contains(.nutritionGoal))
    }

    func testProfileDestinationCasesMatchApprovedSettingsIA() {
        let destinations: [ProfileDestination] = [
            .account,
            .healthAccess,
            .notifications,
            .language,
            .nightComfort,
            .nutritionGoal,
            .termsPrivacy,
            .helpSupport,
            .helpWeekFit,
            .editName
        ]
        XCTAssertEqual(Set(destinations.map(\.id)).count, destinations.count)
        XCTAssertFalse(destinations.map(\.id).contains("privacy"))
        XCTAssertFalse(destinations.map(\.id).contains("editProfile"))
    }

    func testVersionLocalizationExistsForEnglishAndRussian() {
        XCTAssertEqual(
            WeekFitLocalizedString("settings.version.format", locale: Locale(identifier: "en")),
            "Version %@ (%@)"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("settings.version.format", locale: Locale(identifier: "ru")),
            "Версия %@ (%@)"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("settings.version.copied", locale: Locale(identifier: "en")),
            "Version information copied"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("settings.version.copied", locale: Locale(identifier: "ru")),
            "Информация о версии скопирована"
        )
    }

    func testAppVersionReadsFromBundleAndFormatsDisplayLine() {
        let metadata = FeedbackMetadata.current()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        XCTAssertEqual(metadata.appVersion, version ?? "unknown")
        XCTAssertEqual(metadata.buildNumber, build ?? "unknown")

        let line = String(
            format: WeekFitLocalizedString("settings.version.format", locale: Locale(identifier: "en")),
            metadata.appVersion,
            metadata.buildNumber
        )
        XCTAssertEqual(line, "Version \(metadata.appVersion) (\(metadata.buildNumber))")
        XCTAssertFalse(metadata.diagnosticClipboardText.contains("@"))
    }
}
