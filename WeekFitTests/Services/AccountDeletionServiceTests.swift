import XCTest
import SwiftData
@testable import WeekFit

@MainActor
final class AccountDeletionServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var container: ModelContainer!
    private var modelContext: ModelContext!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "weekfit.tests.accountDeletion.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: PlannedActivity.self, configurations: configuration)
        modelContext = ModelContext(container)

        AuthSessionStore.clear()
        AppReviewDemoCredentials.clearSession()
        CoachObservationStore.clearAll()
    }

    override func tearDown() async throws {
        AuthSessionStore.clear()
        AppReviewDemoCredentials.clearSession()
        AccountSessionController.shared.resetForTests()

        let production = WeekFitModelContainer.productionContext()
        if let leftover = try? production.fetch(FetchDescriptor<PlannedActivity>()) {
            for activity in leftover {
                production.delete(activity)
            }
            try? production.save()
        }

        if let suiteName {
            defaults?.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        modelContext = nil
        container = nil
        try await super.tearDown()
    }

    func testSuccessfulDeletionClearsAuthTokensAndLocalActivities() async throws {
        AuthSessionStore.appleUserID = "apple.user.test"
        AppReviewDemoCredentials.markSessionActive()

        modelContext.insert(makeActivity(title: "Run"))
        try modelContext.save()

        let remote = MockAccountRemoteDeletionClient(shouldSucceed: true)
        let service = AccountDeletionService(remoteClient: remote, defaults: defaults)
        let nutrition = NutritionViewModel()
        let coach = CoachCoordinator()

        try await service.deleteAccount(
            modelContext: modelContext,
            nutritionViewModel: nutrition,
            coachCoordinator: coach
        )

        XCTAssertTrue(remote.didDelete)
        XCTAssertNil(AuthSessionStore.appleUserID)
        XCTAssertFalse(AppReviewDemoCredentials.hasActiveSession)
        XCTAssertEqual(
            try modelContext.fetch(FetchDescriptor<PlannedActivity>()).count,
            0
        )
    }

    func testDeletionClearsProductionStoreEvenWhenActiveContextIsSeparate() async throws {
        let production = WeekFitModelContainer.productionContext()
        production.insert(makeActivity(title: "Production leftover"))
        try production.save()

        let remote = MockAccountRemoteDeletionClient(shouldSucceed: true)
        let service = AccountDeletionService(remoteClient: remote, defaults: defaults)

        // Wipe via an in-memory context (simulates review-demo / alternate context).
        try await service.deleteAccount(
            modelContext: modelContext,
            nutritionViewModel: NutritionViewModel(),
            coachCoordinator: CoachCoordinator()
        )

        XCTAssertEqual(
            try production.fetch(FetchDescriptor<PlannedActivity>()).count,
            0
        )
    }

    func testCreateAccountRequestsFreshLocalWorkspace() async {
        AccountSessionController.shared.resetForTests()
        XCTAssertFalse(AccountSessionController.shared.shouldResetLocalDataOnNextRealUserEntry)

        let viewModel = AuthViewModel()
        await viewModel.createAccountWithEmail(email: "fresh@weekfit.app", password: "123456")

        #if DEBUG
        XCTAssertTrue(viewModel.isLoggedIn)
        XCTAssertTrue(AccountSessionController.shared.shouldResetLocalDataOnNextRealUserEntry)
        #endif
    }

    func testRemoteFailureKeepsAuthAndLocalData() async throws {
        AuthSessionStore.appleUserID = "apple.user.keep"
        AppReviewDemoCredentials.markSessionActive()

        modelContext.insert(makeActivity(title: "Lift"))
        try modelContext.save()

        let remote = MockAccountRemoteDeletionClient(
            shouldSucceed: false,
            error: AccountRemoteDeletionError.network("offline")
        )
        let service = AccountDeletionService(remoteClient: remote, defaults: defaults)

        do {
            try await service.deleteAccount(
                modelContext: modelContext,
                nutritionViewModel: NutritionViewModel(),
                coachCoordinator: CoachCoordinator()
            )
            XCTFail("Expected remote deletion failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, "offline")
        }

        XCTAssertEqual(AuthSessionStore.appleUserID, "apple.user.keep")
        XCTAssertTrue(AppReviewDemoCredentials.hasActiveSession)
        XCTAssertEqual(
            try modelContext.fetch(FetchDescriptor<PlannedActivity>()).count,
            1
        )
    }

    func testReviewDemoAccountDeletionSucceeds() async throws {
        AppReviewDemoCredentials.markSessionActive()
        XCTAssertTrue(AppReviewDemoCredentials.hasActiveSession)

        let remote = MockAccountRemoteDeletionClient(shouldSucceed: true)
        let service = AccountDeletionService(remoteClient: remote, defaults: defaults)

        try await service.deleteAccount(
            modelContext: modelContext,
            nutritionViewModel: NutritionViewModel(),
            coachCoordinator: CoachCoordinator()
        )

        XCTAssertFalse(AppReviewDemoCredentials.hasActiveSession)
        XCTAssertTrue(remote.didDelete)
    }

    func testAuthViewModelCompletesSignOutAfterDeletion() {
        let viewModel = AuthViewModel()
        viewModel.isLoggedIn = true
        AuthSessionStore.appleUserID = "to-clear"
        AppReviewDemoCredentials.markSessionActive()

        viewModel.completeAccountDeletionSignOut()

        XCTAssertFalse(viewModel.isLoggedIn)
        XCTAssertNil(AuthSessionStore.appleUserID)
        XCTAssertFalse(AppReviewDemoCredentials.hasActiveSession)
    }

    #if DEBUG
    func testDeletedEmailAccountCanBeRegisteredAgain() async throws {
        AuthService.DebugEmailAuthStorage.clear()

        let createVM = AuthViewModel()
        await createVM.createAccountWithEmail(email: "reuse@weekfit.app", password: "123456")
        XCTAssertTrue(createVM.isLoggedIn)
        XCTAssertNil(createVM.errorMessage)
        XCTAssertEqual(
            AuthService.DebugEmailAuthStorage.registeredEmail()?.lowercased(),
            "reuse@weekfit.app"
        )

        let service = AccountDeletionService(
            remoteClient: MockAccountRemoteDeletionClient(shouldSucceed: true),
            defaults: defaults
        )
        try await service.deleteAccount(
            modelContext: modelContext,
            nutritionViewModel: NutritionViewModel(),
            coachCoordinator: CoachCoordinator()
        )
        createVM.completeAccountDeletionSignOut()

        XCTAssertNil(AuthService.DebugEmailAuthStorage.registeredEmail())

        let recreateVM = AuthViewModel()
        await recreateVM.createAccountWithEmail(email: "reuse@weekfit.app", password: "123456")
        XCTAssertTrue(recreateVM.isLoggedIn)
        XCTAssertNil(recreateVM.errorMessage)

        AuthService.DebugEmailAuthStorage.clear()
    }
    #endif

    private func makeActivity(title: String) -> PlannedActivity {
        PlannedActivity(
            date: Date(),
            type: "workout",
            title: title,
            durationMinutes: 30,
            icon: "figure.run",
            colorRed: 0.2,
            colorGreen: 0.7,
            colorBlue: 0.4
        )
    }
}

private final class MockAccountRemoteDeletionClient: AccountRemoteDeleting, @unchecked Sendable {
    private let shouldSucceed: Bool
    private let error: Error
    private(set) var didDelete = false

    init(shouldSucceed: Bool, error: Error = AccountRemoteDeletionError.invalidResponse) {
        self.shouldSucceed = shouldSucceed
        self.error = error
    }

    func deleteRemoteAccount() async throws {
        guard shouldSucceed else { throw error }
        didDelete = true
    }
}
