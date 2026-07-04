import SwiftUI
import SwiftData
import UserNotifications

@main
struct WeekFitApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var appSession = AppSessionState()
    @StateObject private var healthManager = HealthManager()
    @StateObject private var nutritionViewModel = NutritionViewModel()
    @StateObject private var coachCoordinator = CoachCoordinator()
    @StateObject private var activityCoordinator = WeekFitActivityCoordinator.shared
    @StateObject private var languageManager = AppLanguageManager()
    @StateObject private var nightComfort = NightComfortController()
    @State private var nightComfortLocationService: NightComfortLocationService?

    @State private var backgroundEnteredAt: Date?

    private let refreshThreshold: TimeInterval = 4 * 60

    init() {
        WeekFitWarmLocalizationCache()
        UNUserNotificationCenter.current().delegate =
            NotificationActionHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSession)
                .environmentObject(healthManager)
                .environmentObject(nutritionViewModel)
                .environmentObject(coachCoordinator)
                .environmentObject(activityCoordinator)
                .environmentObject(languageManager)
                .environmentObject(nightComfort)
                .environment(\.locale, languageManager.locale)
                .environment(\.weekFitPalette, WeekFitSemanticPalette.interpolated(blend: nightComfort.blendFactor))
                .animation(.easeInOut(duration: 0.8), value: nightComfort.blendFactor)
                .onAppear {
                    activityCoordinator.start()
                    activityCoordinator.beforePlannedActivityMutation = {
                        CoachSnapshotInvalidator.invalidate(
                            coordinator: coachCoordinator,
                            nutritionViewModel: nutritionViewModel,
                            reason: "healthKitActivityReconcile"
                        )
                    }
                    if nightComfortLocationService == nil {
                        nightComfortLocationService = NightComfortLocationService(nightComfort: nightComfort)
                    }
                    nightComfortLocationService?.refreshIfNeeded()
                }
                .onChange(of: languageManager.selectedLanguage) { _, language in
                    WeekFitSetCurrentLanguage(language)
                    ActivityNotificationService.shared.refreshLocalizedCategories()
                    coachCoordinator.forceRecomputeForLanguageChange(reason: "languageChange.\(language.rawValue)")
                    appSession.triggerHealthRefresh(source: "languageChange")
                    appSession.triggerCoachRefresh(source: "languageChange")
                }
                .onChange(of: scenePhase) {
                    handleScenePhaseChange()
                }
        }
        .modelContainer(for: PlannedActivity.self)
    }

    private func handleScenePhaseChange() {
        switch scenePhase {

        case .background:
            backgroundEnteredAt = Date()

        case .active:
            activityCoordinator.refresh()
            nightComfort.handleSceneBecameActive()
            nightComfortLocationService?.refreshIfNeeded()

            if backgroundEnteredAt != nil {
                appSession.triggerHealthRefresh(source: "appForeground")
            }

            let shouldReset =
                backgroundEnteredAt.map {
                    Date().timeIntervalSince($0) > refreshThreshold ||
                    !Calendar.current.isDate($0, inSameDayAs: Date())
                } ?? false

            if shouldReset {
                appSession.triggerReturnToToday()
            }

            backgroundEnteredAt = nil

        default:
            break
        }
    }
}
