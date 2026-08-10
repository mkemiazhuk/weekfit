import XCTest
import SwiftData
@testable import WeekFit

@MainActor
final class WorkspaceIsolationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AccountSessionController.shared.resetForTests()
        WorkspaceOwnerStore.clearOwner()
        WorkspaceOwnerStore.clearGuestToken()
        AuthSessionStore.clear()
    }

    override func tearDown() {
        AccountSessionController.shared.resetForTests()
        WorkspaceOwnerStore.clearOwner()
        WorkspaceOwnerStore.clearGuestToken()
        AuthSessionStore.clear()
        super.tearDown()
    }

    func testRequiresResetWhenAppleOwnersDiffer() {
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.appleOwnerID("user-a")
        XCTAssertTrue(
            WorkspaceOwnerStore.requiresWorkspaceReset(
                forIncomingIdentity: WorkspaceOwnerStore.appleOwnerID("user-b")
            )
        )
        XCTAssertFalse(
            WorkspaceOwnerStore.requiresWorkspaceReset(
                forIncomingIdentity: WorkspaceOwnerStore.appleOwnerID("user-a")
            )
        )
    }

    func testUnownedWorkspaceIsClaimedWithoutForcedReset() {
        WorkspaceOwnerStore.clearOwner()
        XCTAssertFalse(
            WorkspaceOwnerStore.requiresWorkspaceReset(
                forIncomingIdentity: WorkspaceOwnerStore.appleOwnerID("user-a")
            )
        )
    }

    func testLocalEntryUsesStableLocalOwner() {
        AuthSessionStore.markWeekFitEntered()
        XCTAssertEqual(
            WorkspaceOwnerStore.currentIdentityToken(appleUserID: nil, hasEnteredWeekFit: true),
            WorkspaceOwnerStore.localOwnerID
        )
    }

    func testLocalToAppleRequiresReset() {
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.localOwnerID
        XCTAssertTrue(
            WorkspaceOwnerStore.requiresWorkspaceReset(
                forIncomingIdentity: WorkspaceOwnerStore.appleOwnerID("user-a")
            )
        )
    }

    func testLegacyGuestToAppleRequiresReset() {
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.guestOwnerID("legacy-token")
        XCTAssertTrue(
            WorkspaceOwnerStore.requiresWorkspaceReset(
                forIncomingIdentity: WorkspaceOwnerStore.appleOwnerID("user-a")
            )
        )
    }

    func testAppleToLocalRequiresReset() {
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.appleOwnerID("user-a")
        XCTAssertTrue(
            WorkspaceOwnerStore.requiresWorkspaceReset(
                forIncomingIdentity: WorkspaceOwnerStore.localOwnerID
            ),
            "Open WeekFit after Apple must not inherit account plan/meals"
        )
    }

    func testApplePlanIsWipedWhenEnteringAsLocal() async throws {
        let healthManager = HealthManager()
        let nutritionViewModel = NutritionViewModel()
        let coachCoordinator = CoachCoordinator()
        let appSession = AppSessionState()
        let activityCoordinator = WeekFitActivityCoordinator.shared

        AuthSessionStore.clear()
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.appleOwnerID("user-a")
        AuthSessionStore.markWeekFitEntered()
        AccountSessionController.shared.setMode(.unauthenticated, reason: "testSetup")

        let context = WeekFitModelContainer.productionContext()
        if let leftover = try? context.fetch(FetchDescriptor<PlannedActivity>()) {
            for row in leftover { context.delete(row) }
            try context.save()
        }

        let planItem = PlannedActivityBuilder.workout(
            title: "Apple Plan Workout",
            at: Date(),
            durationMinutes: 45
        )
        context.insert(planItem)
        let mealItem = PlannedActivityBuilder.workout(
            title: "Apple Meal",
            at: Date(),
            durationMinutes: 20
        )
        mealItem.type = "meal"
        context.insert(mealItem)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlannedActivity>()), 2)

        // Simulate Open WeekFit (local) after Apple Sign Out — owner stays apple until reconcile.
        AuthSessionStore.markWeekFitEntered()
        XCTAssertTrue(
            WorkspaceOwnerStore.requiresWorkspaceReset(
                forIncomingIdentity: WorkspaceOwnerStore.localOwnerID
            )
        )
        AccountSessionController.shared.requestLocalDataResetOnNextRealUserEntry()

        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        let remaining = try WeekFitModelContainer.productionContext()
            .fetchCount(FetchDescriptor<PlannedActivity>())
        XCTAssertEqual(remaining, 0, "Plan + meals must wipe when entering local after Apple")
        XCTAssertEqual(WorkspaceOwnerStore.ownerID, WorkspaceOwnerStore.localOwnerID)
        XCTAssertEqual(AccountSessionController.shared.mode, .realUser)
    }

    func testLocalPlanIsWipedWhenEnteringAsApple() async throws {
        let healthManager = HealthManager()
        let nutritionViewModel = NutritionViewModel()
        let coachCoordinator = CoachCoordinator()
        let appSession = AppSessionState()
        let activityCoordinator = WeekFitActivityCoordinator.shared

        AuthSessionStore.clear()
        AuthSessionStore.markWeekFitEntered()
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.localOwnerID
        AccountSessionController.shared.setMode(.realUser, reason: "testSetup")

        let context = WeekFitModelContainer.productionContext()
        if let leftover = try? context.fetch(FetchDescriptor<PlannedActivity>()) {
            for row in leftover { context.delete(row) }
            try context.save()
        }

        let planItem = PlannedActivityBuilder.workout(
            title: "Local Plan Workout",
            at: Date(),
            durationMinutes: 30
        )
        context.insert(planItem)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlannedActivity>()), 1)

        AuthSessionStore.appleUserID = "apple-user-1"
        AccountSessionController.shared.requestLocalDataResetOnNextRealUserEntry()

        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        let remaining = try WeekFitModelContainer.productionContext()
            .fetchCount(FetchDescriptor<PlannedActivity>())
        XCTAssertEqual(remaining, 0, "Local plan must wipe when signing in with Apple")
        XCTAssertEqual(
            WorkspaceOwnerStore.ownerID,
            WorkspaceOwnerStore.appleOwnerID("apple-user-1")
        )
    }

    func testLeavingAppEntryDoesNotWipeWorkspace() async throws {
        let healthManager = HealthManager()
        let nutritionViewModel = NutritionViewModel()
        let coachCoordinator = CoachCoordinator()
        let appSession = AppSessionState()
        let activityCoordinator = WeekFitActivityCoordinator.shared

        AuthSessionStore.appleUserID = "user-a"
        AuthSessionStore.markWeekFitEntered()
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.appleOwnerID("user-a")
        AccountSessionController.shared.setMode(.realUser, reason: "testSetup")

        let context = WeekFitModelContainer.productionContext()
        if let leftover = try? context.fetch(FetchDescriptor<PlannedActivity>()) {
            for row in leftover { context.delete(row) }
            try context.save()
        }

        let activity = PlannedActivityBuilder.workout(
            title: "User A Meal",
            at: Date(),
            durationMinutes: 20
        )
        activity.type = "meal"
        context.insert(activity)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlannedActivity>()), 1)

        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: false,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        let remaining = try WeekFitModelContainer.productionContext()
            .fetchCount(FetchDescriptor<PlannedActivity>())
        XCTAssertEqual(remaining, 1, "Leaving app entry must not wipe local workspace data")
        XCTAssertEqual(
            WorkspaceOwnerStore.ownerID,
            WorkspaceOwnerStore.appleOwnerID("user-a")
        )
        XCTAssertNil(AuthSessionStore.appleUserID)
        XCTAssertFalse(AuthSessionStore.hasEnteredWeekFit)
        XCTAssertEqual(AccountSessionController.shared.mode, .unauthenticated)
    }

    func testSigningInWithAppleWouldReplaceLocalWorkspace() {
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.localOwnerID
        XCTAssertTrue(WorkspaceIsolationPolicy.signingInWithAppleWouldReplaceLocalWorkspace())

        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.appleOwnerID("user-a")
        XCTAssertFalse(WorkspaceIsolationPolicy.signingInWithAppleWouldReplaceLocalWorkspace())

        WorkspaceOwnerStore.clearOwner()
        XCTAssertFalse(WorkspaceIsolationPolicy.signingInWithAppleWouldReplaceLocalWorkspace())
    }

    func testOpeningLocalWouldReplaceAppleWorkspace() {
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.appleOwnerID("user-a")
        XCTAssertTrue(WorkspaceIsolationPolicy.openingLocalWouldReplaceAppleWorkspace())

        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.localOwnerID
        XCTAssertFalse(WorkspaceIsolationPolicy.openingLocalWouldReplaceAppleWorkspace())
    }

    func testIdentitySwitchRequestsWorkspaceReset() {
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.appleOwnerID("user-a")
        AuthSessionStore.appleUserID = "user-b"
        AuthSessionStore.markWeekFitEntered()
        XCTAssertTrue(
            WorkspaceOwnerStore.requiresWorkspaceReset(
                forIncomingIdentity: WorkspaceOwnerStore.currentIdentityToken()
            )
        )
    }
}
