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
    @StateObject private var activityCoordinator = WeekFitActivityCoordinator.shared

    @State private var backgroundEnteredAt: Date?

    private let refreshThreshold: TimeInterval = 4 * 60

    init() {
        UNUserNotificationCenter.current().delegate =
            NotificationActionHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSession)
                .environmentObject(healthManager)
                .environmentObject(nutritionViewModel)
                .environmentObject(activityCoordinator)
                .onAppear {
                    activityCoordinator.start()
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
