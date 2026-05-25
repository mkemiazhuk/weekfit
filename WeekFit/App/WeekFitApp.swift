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
    @StateObject private var nutritionViewModel = NutritionViewModel() // Наш синглтон

    @State private var backgroundEnteredAt: Date?

    private let refreshThreshold: TimeInterval = 10 * 60

    init() {
        UNUserNotificationCenter.current().delegate =
            NotificationActionHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSession)
                .environmentObject(healthManager)
                // ИСПРАВЛЕНО: Теперь вью-модель проброшена в самый корень дерева View!
                .environmentObject(nutritionViewModel)
        }
        .modelContainer(for: PlannedActivity.self)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                backgroundEnteredAt = Date()

            case .active:
                let shouldReset =
                    backgroundEnteredAt.map {
                        Date().timeIntervalSince($0) > refreshThreshold ||
                        !Calendar.current.isDate($0, inSameDayAs: Date())
                    } ?? false

                if shouldReset {
                    appSession.triggerReturnToToday()
                }

            default:
                break
            }
        }
    }
}
