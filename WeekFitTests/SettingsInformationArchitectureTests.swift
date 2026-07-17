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

        XCTAssertEqual(types, [.notifications, .language, .nightComfort, .nutritionGoal])
        XCTAssertFalse(types.contains(.account))
        XCTAssertFalse(types.contains(.appleHealth))
    }

    func testRootSectionsKeepAccountHealthAndSupportSeparate() {
        XCTAssertEqual(service.loadAccountSettings().map(\.type), [.account])
        XCTAssertEqual(service.loadHealthSettings().map(\.type), [.appleHealth])
        XCTAssertEqual(service.loadSupportSettings().map(\.type), [.help])
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
            .editName
        ]
        XCTAssertEqual(Set(destinations.map(\.id)).count, destinations.count)
        XCTAssertFalse(destinations.map(\.id).contains("privacy"))
        XCTAssertFalse(destinations.map(\.id).contains("editProfile"))
    }
}
