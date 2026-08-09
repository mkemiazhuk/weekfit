import Foundation
import SwiftData

@MainActor
enum AccountSessionCoordinator {

    static func applySessionState(
        isLoggedIn: Bool,
        accountSession: AccountSessionController = .shared,
        healthManager: HealthManager,
        activityCoordinator: WeekFitActivityCoordinator,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState
    ) async {
        // Lifecycle boundary: meal seed is never triggered from SwiftUI body/init.
        StartupDiagnostics.step(
            12,
            "meal library seed ensure",
            detail: "AccountSessionCoordinator.applySessionState"
        )
        WeekFitUserSettings.shared.ensureMealLibrarySeeded()

        let targetMode = AccountMode.resolve(isLoggedIn: isLoggedIn)
        guard targetMode != accountSession.mode else {
            await refreshModeIfNeeded(
                targetMode: targetMode,
                accountSession: accountSession,
                healthManager: healthManager,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                appSession: appSession
            )
            return
        }

        accountSession.beginTransition()
        defer { accountSession.endTransition() }

        switch targetMode {
        case .reviewDemo:
            await enterReviewDemoMode(
                accountSession: accountSession,
                healthManager: healthManager,
                activityCoordinator: activityCoordinator,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                appSession: appSession
            )
        case .realUser:
            await enterRealUserMode(
                accountSession: accountSession,
                healthManager: healthManager,
                activityCoordinator: activityCoordinator,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                appSession: appSession
            )
        case .unauthenticated:
            await enterUnauthenticatedMode(
                accountSession: accountSession,
                healthManager: healthManager,
                activityCoordinator: activityCoordinator,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                appSession: appSession
            )
        }
    }

    static func prepareForLogout(
        healthManager: HealthManager,
        activityCoordinator: WeekFitActivityCoordinator,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState,
        accountSession: AccountSessionController = .shared
    ) async {
        accountSession.beginTransition()
        defer { accountSession.endTransition() }

        await tearDownReviewDemo(
            accountSession: accountSession,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        try? DemoDataMigration.cleanupLegacyDemoRecordsIfNeeded(
            in: WeekFitModelContainer.productionContext()
        )

        accountSession.setMode(.unauthenticated, reason: "logout")
        activityCoordinator.restartForRealUser()
        WeekFitActivityCoordinator.shared.resetReconciliationState()

        AccountSessionDiagnostics.log(
            "Logout cleanup completed",
            mode: .unauthenticated,
            store: accountSession.containerIdentity,
            demoProviderEnabled: false
        )
    }

    // MARK: - Private

    private static func enterReviewDemoMode(
        accountSession: AccountSessionController,
        healthManager: HealthManager,
        activityCoordinator: WeekFitActivityCoordinator,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState
    ) async {
        accountSession.setMode(.reviewDemo, reason: "reviewLogin")

        AppReviewDemoSettings.shared.setEnabled(true, scenario: .readyToTrain)
        healthManager.installAppReviewDemoProvider(scenario: AppReviewDemoSettings.shared.scenario)

        let demoContext = WeekFitModelContainer.reviewDemoContext()
        try? AppReviewDemoPlannedActivitySeeder.deleteDemoActivities(modelContext: demoContext)
        try? AppReviewDemoPlannedActivitySeeder.seed(
            scenario: AppReviewDemoSettings.shared.scenario,
            modelContext: demoContext
        )
        UserDefaults.standard.set(
            AppReviewDemoStore.currentSeedVersion,
            forKey: AppReviewDemoStore.seedVersionKey
        )
        UserDefaults.standard.set(
            Calendar.current.startOfDay(for: Date()).timeIntervalSince1970,
            forKey: AppReviewDemoStore.lastSeedDayKey
        )

        invalidateCaches(
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator
        )

        await healthManager.loadHealthData(for: Date())
        appSession.triggerHealthRefresh(source: "accountSession.reviewDemo")
        appSession.triggerCoachRefresh(source: "accountSession.reviewDemo")

        AccountSessionDiagnostics.log(
            "Entered review demo mode",
            mode: .reviewDemo,
            store: accountSession.containerIdentity,
            demoProviderEnabled: true
        )
    }

    private static func enterRealUserMode(
        accountSession: AccountSessionController,
        healthManager: HealthManager,
        activityCoordinator: WeekFitActivityCoordinator,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState
    ) async {
        await tearDownReviewDemo(
            accountSession: accountSession,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        if accountSession.consumeLocalDataResetOnNextRealUserEntry() {
            await resetLocalWorkspaceForNewAccount(
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                appSession: appSession
            )
        }

        StartupDiagnostics.step(3, "migration start", detail: "DemoDataMigration (realUser entry)")
        do {
            let removed = try DemoDataMigration.cleanupLegacyDemoRecordsIfNeeded(
                in: WeekFitModelContainer.productionContext()
            )
            StartupDiagnostics.step(
                4,
                "migration complete",
                detail: "DemoDataMigration removedRows=\(removed)"
            )
        } catch {
            StartupDiagnostics.failed(
                operation: "DemoDataMigration.cleanupLegacyDemoRecordsIfNeeded",
                error: error,
                step: 3
            )
        }

        accountSession.setMode(.realUser, reason: "realUserLogin")
        activityCoordinator.restartForRealUser()

        // Probe grant only — full HealthKit hydrate must not block the transition UI
        // (otherwise Login flashes then the app sits on a black screen that looks like a crash).
        StartupDiagnostics.step(6, "HealthKit service created", detail: "refreshHealthAccessStateAfterLogin(loadMetrics: false)")
        await healthManager.refreshHealthAccessStateAfterLogin(loadMetrics: false)
        StartupDiagnostics.step(
            6,
            "HealthKit service created",
            detail: "probe done granted=\(healthManager.isHealthAccessGranted) requested=\(healthManager.isHealthAccessRequested)"
        )
        if healthManager.isHealthAccessGranted {
            activityCoordinator.activateHealthKitSync()
        }

        OnboardingStore.migrateExistingUsersIfNeeded()

        // UserDefaults may have been wiped during account transition — re-apply Apple name.
        AppleIdentityStore.restoreProfileIfNeeded(appleUserID: AuthSessionStore.appleUserID)

        if !OnboardingStore.hasCompletedOnboarding {
            appSession.presentOnboarding()
        } else if !healthManager.isHealthAccessGranted && !healthManager.isHealthAccessRequested {
            appSession.presentHealthAccess()
        } else {
            appSession.dismissHealthAccess()
        }

        AccountSessionDiagnostics.log(
            "Entered real user mode",
            mode: .realUser,
            store: accountSession.containerIdentity,
            demoProviderEnabled: false
        )

        // Hydrate after the transition can end — Root appears while metrics catch up.
        Task {
            let taskName = "accountSession.realUser.postApplyHydrate"
            StartupDiagnostics.taskBegin(
                taskName,
                detail: "granted=\(healthManager.isHealthAccessGranted)"
            )
            if Task.isCancelled {
                StartupDiagnostics.taskCancelled(taskName)
                return
            }
            if healthManager.isHealthAccessGranted {
                await healthManager.loadHealthData(for: Date())
            }
            if Task.isCancelled {
                StartupDiagnostics.taskCancelled(taskName, detail: "after loadHealthData")
                return
            }
            appSession.triggerHealthRefresh(source: "accountSession.realUser")
            appSession.triggerCoachRefresh(source: "accountSession.realUser")
            StartupDiagnostics.taskSuccess(
                taskName,
                detail: "triggered health+coach refresh"
            )
        }
    }

    private static func resetLocalWorkspaceForNewAccount(
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState
    ) async {
        let resetService = LocalDataResetService(
            modelContext: WeekFitModelContainer.productionContext()
        )
        resetService.beforeDeletingPlannedActivities = {
            CoachSnapshotInvalidator.invalidate(
                coordinator: coachCoordinator,
                nutritionViewModel: nutritionViewModel,
                reason: "newAccountWorkspace"
            )
        }
        let preservedAppleUserID = AuthSessionStore.appleUserID
        try? await resetService.resetAllLocalData()

        // `resetAllLocalData` clears the UserDefaults domain (including appleUserID + profile).
        if let appleUserID = preservedAppleUserID {
            AuthSessionStore.appleUserID = appleUserID
            AppleIdentityStore.restoreProfileIfNeeded(appleUserID: appleUserID)
        }

        nutritionViewModel.resetLocalState()
        CoachObservationStore.clearAll()
        ActivityConfirmationState.shared.pendingActivity = nil
        WeekFitActivityCoordinator.shared.resetReconciliationState()
        HealthKitWorkoutSyncService.shared.resetSyncState()
        appSession.triggerLocalDataResetCompleted()

        AccountSessionDiagnostics.log(
            "Reset local workspace for new account",
            mode: .unauthenticated,
            store: "swiftdata-production",
            demoProviderEnabled: false
        )
    }

    private static func enterUnauthenticatedMode(
        accountSession: AccountSessionController,
        healthManager: HealthManager,
        activityCoordinator: WeekFitActivityCoordinator,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState
    ) async {
        await tearDownReviewDemo(
            accountSession: accountSession,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        try? DemoDataMigration.cleanupLegacyDemoRecordsIfNeeded(
            in: WeekFitModelContainer.productionContext()
        )

        accountSession.setMode(.unauthenticated, reason: "signedOut")
        activityCoordinator.restartForRealUser()

        AccountSessionDiagnostics.log(
            "Entered unauthenticated mode",
            mode: .unauthenticated,
            store: accountSession.containerIdentity,
            demoProviderEnabled: false
        )
    }

    private static func refreshModeIfNeeded(
        targetMode: AccountMode,
        accountSession: AccountSessionController,
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState
    ) async {
        guard targetMode == .reviewDemo else { return }

        if healthManager.appReviewDemoProvider == nil {
            AppReviewDemoSettings.shared.setEnabled(true, scenario: AppReviewDemoSettings.shared.scenario)
            healthManager.installAppReviewDemoProvider(scenario: AppReviewDemoSettings.shared.scenario)
        }

        let demoContext = WeekFitModelContainer.reviewDemoContext()
        let demoCount = (try? demoActivityCount(modelContext: demoContext)) ?? 0
        let storedSeedVersion = UserDefaults.standard.integer(forKey: AppReviewDemoStore.seedVersionKey)
        let todayStart = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let lastSeedDay = UserDefaults.standard.double(forKey: AppReviewDemoStore.lastSeedDayKey)
        let needsReseed =
            demoCount == 0
            || storedSeedVersion != AppReviewDemoStore.currentSeedVersion
            || lastSeedDay != todayStart

        if needsReseed {
            try? AppReviewDemoPlannedActivitySeeder.deleteDemoActivities(modelContext: demoContext)
            try? AppReviewDemoPlannedActivitySeeder.seed(
                scenario: AppReviewDemoSettings.shared.scenario,
                modelContext: demoContext
            )
            UserDefaults.standard.set(
                AppReviewDemoStore.currentSeedVersion,
                forKey: AppReviewDemoStore.seedVersionKey
            )
            UserDefaults.standard.set(todayStart, forKey: AppReviewDemoStore.lastSeedDayKey)

            if healthManager.appReviewDemoProvider == nil {
                healthManager.installAppReviewDemoProvider(scenario: AppReviewDemoSettings.shared.scenario)
            } else {
                healthManager.appReviewDemoProvider?.regenerate(
                    scenario: AppReviewDemoSettings.shared.scenario,
                    referenceDate: Date()
                )
            }
        }

        invalidateCaches(
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator
        )
        appSession.triggerHealthRefresh(source: "accountSession.reviewDemoRefresh")
        appSession.triggerCoachRefresh(source: "accountSession.reviewDemoRefresh")
    }

    private static func tearDownReviewDemo(
        accountSession: AccountSessionController,
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState
    ) async {
        let leavingReviewDemo = accountSession.mode == .reviewDemo

        AppReviewDemoSettings.shared.setEnabled(false)
        AppReviewDemoActivation.shared.resetForTests()
        healthManager.clearAppReviewDemoProvider()

        if leavingReviewDemo {
            healthManager.clearReviewPollutedHealthAccessState()
            healthManager.prepareForRealUserSession()
        }

        let demoContext = WeekFitModelContainer.reviewDemoContext()
        try? AppReviewDemoPlannedActivitySeeder.deleteDemoActivities(modelContext: demoContext)

        let productionContext = WeekFitModelContainer.productionContext()
        try? AppReviewDemoPlannedActivitySeeder.deleteDemoActivities(modelContext: productionContext)

        invalidateCaches(
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator
        )

        appSession.triggerHealthRefresh(source: "accountSession.demoTeardown")
        appSession.triggerCoachRefresh(source: "accountSession.demoTeardown")
    }

    private static func invalidateCaches(
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator
    ) {
        CoachSnapshotInvalidator.invalidate(
            coordinator: coachCoordinator,
            nutritionViewModel: nutritionViewModel,
            reason: "accountSession"
        )
        CoachObservationStore.clearAll()
    }

    private static func demoActivityCount(modelContext: ModelContext) throws -> Int {
        let source = AppReviewDemoStore.sourceIdentifier
        let descriptor = FetchDescriptor<PlannedActivity>(
            predicate: #Predicate { activity in
                activity.source == source
            }
        )
        return try modelContext.fetchCount(descriptor)
    }
}
