import Foundation
import SwiftData

@MainActor
enum AppReviewDemoCoordinator {

    static func enable(
        scenario: AppReviewDemoScenario = .readyToTrain,
        modelContext: ModelContext,
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState
    ) async throws {
        AppReviewDemoSettings.shared.setEnabled(true, scenario: scenario)

        try await applyDemoData(
            modelContext: modelContext,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession,
            scenario: scenario
        )
    }

    static func disable(
        modelContext: ModelContext,
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState
    ) async throws {
        AppReviewDemoSettings.shared.setEnabled(false)
        healthManager.clearAppReviewDemoProvider()

        try AppReviewDemoPlannedActivitySeeder.deleteDemoActivities(modelContext: modelContext)
        invalidateCaches(
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator
        )

        healthManager.updateAuthorizationStatus()
        appSession.triggerHealthRefresh(source: "appReviewDemoDisabled")
        appSession.triggerCoachRefresh(source: "appReviewDemoDisabled")
    }

    static func changeScenario(
        _ scenario: AppReviewDemoScenario,
        modelContext: ModelContext,
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState
    ) async throws {
        guard AppReviewDemoSettings.shared.isEnabled else { return }
        AppReviewDemoSettings.shared.setScenario(scenario)

        try AppReviewDemoPlannedActivitySeeder.deleteDemoActivities(modelContext: modelContext)
        try await applyDemoData(
            modelContext: modelContext,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession,
            scenario: scenario
        )
    }

    static func restoreIfNeeded(
        healthManager: HealthManager,
        modelContext: ModelContext,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState
    ) async {
        guard AppReviewDemoCredentials.hasActiveSession else {
            await teardownUnlessReviewSession(
                healthManager: healthManager,
                modelContext: modelContext,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                appSession: appSession
            )
            return
        }

        guard AppReviewDemoSettings.shared.isEnabled else { return }

        if healthManager.appReviewDemoProvider == nil {
            healthManager.installAppReviewDemoProvider(
                scenario: AppReviewDemoSettings.shared.scenario
            )
        }

        let demoCount = (try? demoActivityCount(modelContext: modelContext)) ?? 0
        let storedSeedVersion = UserDefaults.standard.integer(forKey: AppReviewDemoStore.seedVersionKey)
        let todayStart = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let lastSeedDay = UserDefaults.standard.double(forKey: AppReviewDemoStore.lastSeedDayKey)
        let needsReseed =
            demoCount == 0
            || storedSeedVersion != AppReviewDemoStore.currentSeedVersion
            || lastSeedDay != todayStart

        if needsReseed {
            try? AppReviewDemoPlannedActivitySeeder.deleteDemoActivities(modelContext: modelContext)
            try? AppReviewDemoPlannedActivitySeeder.seed(
                scenario: AppReviewDemoSettings.shared.scenario,
                modelContext: modelContext
            )
            UserDefaults.standard.set(
                AppReviewDemoStore.currentSeedVersion,
                forKey: AppReviewDemoStore.seedVersionKey
            )
            UserDefaults.standard.set(todayStart, forKey: AppReviewDemoStore.lastSeedDayKey)

            if let provider = healthManager.appReviewDemoProvider {
                provider.regenerate(
                    scenario: AppReviewDemoSettings.shared.scenario,
                    referenceDate: Date()
                )
            } else {
                healthManager.installAppReviewDemoProvider(
                    scenario: AppReviewDemoSettings.shared.scenario
                )
            }
        }

        invalidateCaches(
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator
        )
        appSession.triggerHealthRefresh(source: "appReviewDemoRestore")
        appSession.triggerCoachRefresh(source: "appReviewDemoRestore")
    }

    static func teardownUnlessReviewSession(
        healthManager: HealthManager,
        modelContext: ModelContext? = nil,
        nutritionViewModel: NutritionViewModel? = nil,
        coachCoordinator: CoachCoordinator? = nil,
        appSession: AppSessionState? = nil
    ) async {
        guard !AppReviewDemoCredentials.hasActiveSession else { return }

        let needsTeardown =
            AppReviewDemoSettings.shared.isEnabled
            || healthManager.appReviewDemoProvider != nil

        guard needsTeardown else { return }

        if
            let modelContext,
            let nutritionViewModel,
            let coachCoordinator,
            let appSession
        {
            try? await disable(
                modelContext: modelContext,
                healthManager: healthManager,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                appSession: appSession
            )
        } else {
            AppReviewDemoSettings.shared.setEnabled(false)
            healthManager.clearAppReviewDemoProvider()
            healthManager.updateAuthorizationStatus()
        }
    }

    private static func applyDemoData(
        modelContext: ModelContext,
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        appSession: AppSessionState,
        scenario: AppReviewDemoScenario
    ) async throws {
        healthManager.installAppReviewDemoProvider(scenario: scenario)
        try AppReviewDemoPlannedActivitySeeder.seed(
            scenario: scenario,
            modelContext: modelContext
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
        appSession.triggerHealthRefresh(source: "appReviewDemoEnabled")
        appSession.triggerCoachRefresh(source: "appReviewDemoEnabled")
    }

    private static func invalidateCaches(
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator
    ) {
        CoachSnapshotInvalidator.invalidate(
            coordinator: coachCoordinator,
            nutritionViewModel: nutritionViewModel,
            reason: "appReviewDemo"
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
