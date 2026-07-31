import XCTest
@testable import WeekFit

final class ApplePersonNamePropagationTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var profileService: ProfileService!

    override func setUp() {
        super.setUp()
        suiteName = "weekfit.tests.apple-name.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        profileService = ProfileService(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        profileService = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Parser

    func testParseFullNameUsesPersonNameComponentsFormatter() {
        var components = PersonNameComponents()
        components.givenName = "  Maksim "
        components.familyName = " K "

        let parsed = ApplePersonNameParser.parse(components)
        XCTAssertEqual(parsed?.givenName, "Maksim")
        XCTAssertEqual(parsed?.familyName, "K")

        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        var expectedComponents = PersonNameComponents()
        expectedComponents.givenName = "Maksim"
        expectedComponents.familyName = "K"
        let expected = formatter.string(from: expectedComponents)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(parsed?.displayName, expected)
    }

    func testParseGivenNameOnly() {
        var components = PersonNameComponents()
        components.givenName = "Max"

        let parsed = ApplePersonNameParser.parse(components)
        XCTAssertEqual(parsed?.givenName, "Max")
        XCTAssertNil(parsed?.familyName)
        XCTAssertEqual(parsed?.displayName, "Max")
    }

    func testParseWhitespaceOnlyReturnsNil() {
        var components = PersonNameComponents()
        components.givenName = "   "
        components.familyName = "\n"
        XCTAssertNil(ApplePersonNameParser.parse(components))
        XCTAssertNil(ApplePersonNameParser.parse(nil))
        XCTAssertNil(ApplePersonNameParser.parse(PersonNameComponents()))
    }

    // MARK: - Profile persistence

    func testFirstAppleSignInPersistsNameWhenProfileEmpty() {
        var components = PersonNameComponents()
        components.givenName = "Maksim"
        components.familyName = "K"
        let parsed = try! XCTUnwrap(ApplePersonNameParser.parse(components))

        XCTAssertTrue(profileService.applyAppleNameIfEmpty(parsed))
        XCTAssertEqual(ProfileService.resolvedFullName(defaults: defaults), parsed.displayName)
        XCTAssertEqual(ProfileService.resolvedGivenName(defaults: defaults), "Maksim")
        XCTAssertEqual(profileService.loadUserProfile().fullName, parsed.displayName)
    }

    func testRepeatAppleSignInWithNilFullNameKeepsPersistedName() {
        var components = PersonNameComponents()
        components.givenName = "Maksim"
        components.familyName = "K"
        let parsed = try! XCTUnwrap(ApplePersonNameParser.parse(components))
        XCTAssertTrue(profileService.applyAppleNameIfEmpty(parsed))

        // Subsequent Apple auth: fullName nil → do not clear / overwrite.
        XCTAssertFalse(profileService.applyAppleNameIfEmpty(
            ApplePersonNameParser.ParsedName(givenName: nil, familyName: nil, displayName: "Other")
        ))
        // Even with a "new" parsed name, existing profile blocks overwrite.
        XCTAssertEqual(ProfileService.resolvedFullName(defaults: defaults), parsed.displayName)
    }

    func testManuallyEditedProfileNameIsNeverOverwrittenByApple() {
        profileService.saveUserProfile(
            UserProfile(initials: "A", fullName: "Alex Manual", email: "")
        )

        var components = PersonNameComponents()
        components.givenName = "Maksim"
        components.familyName = "K"
        let parsed = try! XCTUnwrap(ApplePersonNameParser.parse(components))

        XCTAssertFalse(profileService.applyAppleNameIfEmpty(parsed))
        XCTAssertEqual(ProfileService.resolvedFullName(defaults: defaults), "Alex Manual")
        XCTAssertEqual(ProfileService.resolvedGivenName(defaults: defaults), "Alex")
    }

    func testAppleEmailAppliesOnlyWhenEmpty() {
        profileService.applyAppleEmailIfEmpty("one@example.com")
        profileService.applyAppleEmailIfEmpty("two@example.com")
        XCTAssertEqual(profileService.loadUserProfile().email, "one@example.com")
    }

    func testIdentityCacheSurvivesNilCredentialOnRepeatSignIn() {
        let userID = "apple-user-\(UUID().uuidString)"
        AppleIdentityStore.merge(
            appleUserID: userID,
            displayName: "Maksim K",
            givenName: "Maksim",
            familyName: "K",
            email: "a@b.com"
        )
        defer { AppleIdentityStore.clear(appleUserID: userID) }

        // Simulate repeat sign-in with nil live name — cache still has values.
        AppleIdentityStore.merge(
            appleUserID: userID,
            displayName: nil,
            givenName: nil,
            familyName: nil,
            email: nil
        )
        let cached = AppleIdentityStore.load(appleUserID: userID)
        XCTAssertEqual(cached?.displayName, "Maksim K")
        XCTAssertEqual(cached?.givenName, "Maksim")
        XCTAssertEqual(cached?.email, "a@b.com")

        XCTAssertTrue(
            profileService.applyAppleNameIfEmpty(
                ApplePersonNameParser.ParsedName(
                    givenName: cached?.givenName,
                    familyName: cached?.familyName,
                    displayName: cached!.displayName!
                )
            )
        )
    }

    func testProfilePersistenceFailureLeavesExistingNameIntact() {
        // Simulate "failure" by attempting apply with empty display after a valid name exists —
        // applyAppleNameIfEmpty must no-op and keep prior value.
        profileService.saveUserProfile(UserProfile(initials: "M", fullName: "Kept Name", email: ""))
        let before = ProfileService.resolvedFullName(defaults: defaults)

        // Empty display is rejected by applyAppleNameIfEmpty.
        let rejected = profileService.applyAppleNameIfEmpty(
            ApplePersonNameParser.ParsedName(givenName: "X", familyName: nil, displayName: "   ")
        )
        XCTAssertFalse(rejected)
        XCTAssertEqual(ProfileService.resolvedFullName(defaults: defaults), before)
    }
}

@MainActor
final class OnboardingReadyNameGreetingTests: XCTestCase {

    private func date(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 21
        components.hour = hour
        return Calendar.current.date(from: components)!
    }

    func testReadyGreetingWithFirstName() {
        let preview = OnboardingCoachPreview.build(
            .init(
                now: date(hour: 8),
                goal: .maintenance,
                recoveryPercent: 70,
                health: .connected,
                firstName: "Max"
            )
        )
        XCTAssertEqual(
            preview.greetingTitle,
            String(format: WeekFitLocalizedString("onboarding.v12.ready.title.youreReady.named"), "Max")
        )
    }

    func testReadyGreetingWithoutName() {
        let preview = OnboardingCoachPreview.build(
            .init(
                now: date(hour: 8),
                goal: .maintenance,
                recoveryPercent: 70,
                health: .connected,
                firstName: nil
            )
        )
        XCTAssertEqual(
            preview.greetingTitle,
            WeekFitLocalizedString("onboarding.v12.ready.title.youreReady")
        )
    }

    func testReadyGreetingIgnoresWhitespaceOnlyName() {
        let preview = OnboardingCoachPreview.build(
            .init(
                now: date(hour: 20),
                goal: .fatLoss,
                health: .limited,
                firstName: "   "
            )
        )
        XCTAssertEqual(
            preview.greetingTitle,
            WeekFitLocalizedString("onboarding.v12.ready.title.youreReady")
        )
    }
}
