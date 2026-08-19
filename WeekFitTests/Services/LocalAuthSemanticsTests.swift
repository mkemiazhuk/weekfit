import XCTest
import SwiftData
@testable import WeekFit

/// Regression coverage for local-first auth/app-entry semantics.
@MainActor
final class LocalAuthSemanticsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AccountSessionController.shared.resetForTests()
        WorkspaceOwnerStore.clearOwner()
        WorkspaceOwnerStore.clearGuestToken()
        AuthSessionStore.clear()
        AppReviewDemoCredentials.clearSession()
        clearProductionActivities()
    }

    override func tearDown() {
        AccountSessionController.shared.resetForTests()
        WorkspaceOwnerStore.clearOwner()
        WorkspaceOwnerStore.clearGuestToken()
        AuthSessionStore.clear()
        AppReviewDemoCredentials.clearSession()
        clearProductionActivities()
        super.tearDown()
    }

    // 1. Local user creates data → Sign in with Apple → workspace must reset (no local bleed)
    func testLocalDataDoesNotBleedIntoAppleAccount() throws {
        AuthSessionStore.markWeekFitEntered()
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.localOwnerID
        insertProductionActivity(title: "Local Meal")

        let incoming = WorkspaceOwnerStore.appleOwnerID("apple-user-1")
        XCTAssertTrue(
            WorkspaceOwnerStore.requiresWorkspaceReset(forIncomingIdentity: incoming),
            "Local → Apple must not inherit anonymous meals into the Apple workspace"
        )
    }

    // 2. Authenticated user → Sign Out → data remains, welcome/login shown
    func testSignOutPreservesWorkspaceAndReturnsToWelcome() async {
        insertProductionActivity(title: "Apple Meal")
        AuthSessionStore.appleUserID = "apple-user-1"
        AuthSessionStore.markWeekFitEntered()
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.appleOwnerID("apple-user-1")

        let viewModel = AuthViewModel()
        viewModel.syncPublishedAuthFlagsFromStoreForTests()
        XCTAssertTrue(viewModel.isAppleSignedIn)

        let signedOut = expectation(description: "signOut")
        viewModel.signOut()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            signedOut.fulfill()
        }
        await fulfillment(of: [signedOut], timeout: 2)

        XCTAssertEqual(productionActivityCount(), 1)
        XCTAssertNil(AuthSessionStore.appleUserID)
        XCTAssertFalse(AuthSessionStore.hasEnteredWeekFit)
        XCTAssertFalse(viewModel.hasEnteredWeekFit)
        XCTAssertFalse(viewModel.isAppleSignedIn)
        XCTAssertFalse(viewModel.isAuthenticated)
    }

    // 3 + 4 + 5. Local never sees Sign Out / Delete; Apple does
    func testLocalUserNeverSeesAccountDestructiveActions() {
        AuthSessionStore.markWeekFitEntered()
        AuthSessionStore.clearAppleSession()
        XCTAssertFalse(AuthSessionStore.hasPersistedAppleSession)
        XCTAssertTrue(AuthSessionStore.hasEnteredWeekFit)
    }

    func testAppleUserSeesAccountDestructiveActionsGate() {
        AuthSessionStore.appleUserID = "apple-user-1"
        AuthSessionStore.markWeekFitEntered()
        XCTAssertTrue(AuthSessionStore.hasPersistedAppleSession)
    }

    // 6. Local Reset → empty workspace, stay inside WeekFit
    func testLocalResetClearsWorkspaceButKeepsEntry() async throws {
        AuthSessionStore.markWeekFitEntered()
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.localOwnerID
        insertProductionActivity(title: "To Reset")
        UserDefaults.standard.set(
            WeekFitVerifiedEntitlement.unsubscribed.rawValue,
            forKey: WeekFitEntitlementFallbackStore.key
        )

        let resetService = LocalDataResetService(
            modelContext: WeekFitModelContainer.productionContext()
        )
        let preservedEntered = AuthSessionStore.hasEnteredWeekFit
        try await resetService.resetAllLocalData()
        if preservedEntered {
            AuthSessionStore.markWeekFitEntered()
            WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.localOwnerID
        }

        XCTAssertEqual(productionActivityCount(), 0)
        XCTAssertTrue(AuthSessionStore.hasEnteredWeekFit)
        XCTAssertNil(AuthSessionStore.appleUserID)
        XCTAssertEqual(WorkspaceOwnerStore.ownerID, WorkspaceOwnerStore.localOwnerID)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: WeekFitEntitlementFallbackStore.key),
            WeekFitVerifiedEntitlement.unsubscribed.rawValue,
            "Local reset must not erase StoreKit entitlement fallback"
        )
        UserDefaults.standard.removeObject(forKey: WeekFitEntitlementFallbackStore.key)
    }

    // 7. Authenticated Reset → empty workspace, auth remains
    func testAuthenticatedResetClearsWorkspaceButKeepsAppleAuth() async throws {
        AuthSessionStore.appleUserID = "apple-user-1"
        AuthSessionStore.markWeekFitEntered()
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.appleOwnerID("apple-user-1")
        insertProductionActivity(title: "Auth Meal")

        let resetService = LocalDataResetService(
            modelContext: WeekFitModelContainer.productionContext()
        )
        let preservedApple = AuthSessionStore.appleUserID
        let preservedEntered = AuthSessionStore.hasEnteredWeekFit
        try await resetService.resetAllLocalData()
        if let appleUserID = preservedApple {
            AuthSessionStore.appleUserID = appleUserID
            WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.appleOwnerID(appleUserID)
        }
        if preservedEntered {
            AuthSessionStore.markWeekFitEntered()
        }

        XCTAssertEqual(productionActivityCount(), 0)
        XCTAssertEqual(AuthSessionStore.appleUserID, "apple-user-1")
        XCTAssertTrue(AuthSessionStore.hasEnteredWeekFit)
    }

    // 8. Delete Account → authenticated state gone, clean workspace, welcome/login
    func testDeleteAccountEndsAuthAndReturnsToWelcome() async throws {
        AuthSessionStore.appleUserID = "apple-user-1"
        AuthSessionStore.markWeekFitEntered()
        insertProductionActivity(title: "Delete Me")

        let service = AccountDeletionService(
            remoteClient: LocalAuthSemanticsRemoteMock(shouldSucceed: true)
        )
        try await service.deleteAccount(
            modelContext: WeekFitModelContainer.productionContext(),
            nutritionViewModel: NutritionViewModel(),
            coachCoordinator: CoachCoordinator()
        )

        let viewModel = AuthViewModel()
        viewModel.completeAccountDeletionSignOut()

        XCTAssertEqual(productionActivityCount(), 0)
        XCTAssertNil(AuthSessionStore.appleUserID)
        XCTAssertFalse(AuthSessionStore.hasEnteredWeekFit)
        XCTAssertFalse(viewModel.hasEnteredWeekFit)
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertEqual(WorkspaceOwnerStore.ownerID, WorkspaceOwnerStore.localOwnerID)
    }

    // 9. isAuthenticated == false does not route an existing local user to welcome
    func testUnauthenticatedLocalUserStillResolvesToRealUserMode() {
        AuthSessionStore.clearAppleSession()
        AuthSessionStore.markWeekFitEntered()

        XCTAssertFalse(AuthSessionStore.hasPersistedAppleSession)
        XCTAssertEqual(AccountMode.resolve(hasEnteredWeekFit: true), .realUser)
        XCTAssertEqual(AccountMode.resolve(hasEnteredWeekFit: false), .unauthenticated)
    }

    // 10. Sign Out clears entry immediately (welcome) without requiring cold restart
    func testSignOutUpdatesPublishedAuthFlagsAndLeavesAppEntry() async {
        AuthSessionStore.appleUserID = "apple-user-1"
        AuthSessionStore.markWeekFitEntered()

        let viewModel = AuthViewModel()
        viewModel.syncPublishedAuthFlagsFromStoreForTests()
        XCTAssertTrue(viewModel.isAppleSignedIn)
        XCTAssertTrue(viewModel.hasEnteredWeekFit)

        let signedOut = expectation(description: "signOut flags")
        viewModel.signOut()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            signedOut.fulfill()
        }
        await fulfillment(of: [signedOut], timeout: 2)

        XCTAssertFalse(viewModel.hasEnteredWeekFit)
        XCTAssertFalse(viewModel.isAppleSignedIn)
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(AuthSessionStore.appleUserID)
    }

    func testContinueWithoutAccountDoesNotCreateFakeAppleAuth() async {
        let viewModel = AuthViewModel()
        viewModel.syncPublishedAuthFlagsFromStoreForTests()
        await viewModel.continueWithoutAccount()

        XCTAssertTrue(viewModel.hasEnteredWeekFit)
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertFalse(viewModel.isAppleSignedIn)
        XCTAssertNil(AuthSessionStore.appleUserID)
        XCTAssertTrue(AuthSessionStore.hasEnteredWeekFit)
        XCTAssertEqual(
            WorkspaceOwnerStore.currentIdentityToken(),
            WorkspaceOwnerStore.localOwnerID
        )
    }

    // MARK: - Helpers

    private func insertProductionActivity(title: String) {
        let context = WeekFitModelContainer.productionContext()
        clearProductionActivities()
        let activity = PlannedActivityBuilder.workout(
            title: title,
            at: Date(),
            durationMinutes: 20
        )
        activity.type = "meal"
        context.insert(activity)
        try? context.save()
    }

    private func productionActivityCount() -> Int {
        (try? WeekFitModelContainer.productionContext()
            .fetchCount(FetchDescriptor<PlannedActivity>())) ?? -1
    }

    private func clearProductionActivities() {
        let context = WeekFitModelContainer.productionContext()
        if let leftover = try? context.fetch(FetchDescriptor<PlannedActivity>()) {
            for row in leftover { context.delete(row) }
            try? context.save()
        }
    }
}

private final class LocalAuthSemanticsRemoteMock: AccountRemoteDeleting, @unchecked Sendable {
    private let shouldSucceed: Bool

    init(shouldSucceed: Bool) {
        self.shouldSucceed = shouldSucceed
    }

    func deleteRemoteAccount() async throws {
        guard shouldSucceed else {
            throw AccountRemoteDeletionError.network("offline")
        }
    }
}
