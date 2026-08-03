import SwiftUI
import SwiftData
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

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
    @StateObject private var appearance = WeekFitAppearanceController()
    @StateObject private var reviewPromptManager = ReviewPromptManager()
    @StateObject private var unitsStore = WeekFitUnitsStore.shared
    @State private var nightComfortLocationService: NightComfortLocationService?

    @State private var backgroundEnteredAt: Date?

    private let refreshThreshold: TimeInterval = 4 * 60

    init() {
        // Earliest SwiftUI App entry — once-guarded; AppDelegate still configures
        // first in didFinishLaunching before AnalyticsBootstrap (no double configure).
        FirebaseBootstrap.configureIfNeeded()
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
                .environmentObject(appearance)
                .environmentObject(reviewPromptManager)
                .environmentObject(unitsStore)
                .environment(\.locale, languageManager.locale)
                .preferredColorScheme(appearance.colorSchemeOverride)
                .modifier(WeekFitPaletteEnvironmentSync(
                    blendFactor: nightComfort.blendFactor,
                    preference: appearance.preference
                ))
                // Night Comfort crossfade is Dark-only. Never animate blend for Light / System —
                // resume flaps otherwise paint half-Light / half-Dark chrome.
                .animation(
                    appearance.preference == .dark
                        ? .easeInOut(duration: 0.8)
                        : nil,
                    value: nightComfort.blendFactor
                )
                .onAppear {
                    activityCoordinator.prepareLaunchServices()
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
                    // Locale/cache already updated in AppLanguageManager.didSet.
                    ActivityNotificationService.shared.refreshLocalizedCategories()
                    // Rebuild Coach copy immediately so Today/Coach never keep EN after RU switch.
                    coachCoordinator.forceRecomputeForLanguageChange(
                        reason: "languageChange.\(language.rawValue)"
                    )

                    Task { @MainActor in
                        WellnessNotificationService.shared.cancelAll()
                        // Language is presentation-only — do not reload HealthKit.
                        // Health refresh invalidates coach input and can re-freeze English copy.
                        appSession.triggerCoachRefresh(source: "languageChange")
                    }
                }
                .onChange(of: scenePhase) {
                    handleScenePhaseChange()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: .weekfitRequestSupplementaryPermissions)
                ) { _ in
                    guard AccountSessionController.shared.mode == .realUser else { return }

                    if nightComfortLocationService == nil {
                        nightComfortLocationService = NightComfortLocationService(nightComfort: nightComfort)
                    }
                    nightComfortLocationService?.requestWhenInUseAuthorizationIfNeeded()
                    Task {
                        _ = await ActivityNotificationService.shared.requestPermissionIfNotDetermined()
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: .weekfitDidCompleteAccountDeletion)
                ) { _ in
                    healthManager.prepareForAccountDeletion()
                    nightComfortLocationService?.stopAndClearForAccountDeletion()
                }
        }
    }

    private func handleScenePhaseChange() {
        switch scenePhase {

        case .background:
            backgroundEnteredAt = Date()

        case .active:
            activityCoordinator.refresh()
            nightComfort.handleSceneBecameActive()
            // Palette store is owned solely by `WeekFitPaletteEnvironmentSync`.
            // Do not write it here from `UITraitCollection` — that races SwiftUI's
            // `colorScheme` and leaves env Light + WeekFitTheme Dark (or vice versa).
            nightComfortLocationService?.refreshIfNeeded()
            healthManager.retryPendingWorkoutRouteAuthorizationIfNeeded()

            if backgroundEnteredAt != nil {
                healthManager.updateAuthorizationStatus()
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

/// Keeps `weekFitPalette` env + `WeekFitPaletteStore` aligned with appearance preference and Night Comfort.
private struct WeekFitPaletteEnvironmentSync: ViewModifier {
    let blendFactor: CGFloat
    let preference: WeekFitAppearancePreference
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    /// System scheme for `.system` preference. On resume, SwiftUI `colorScheme` can lag
    /// behind the window trait — prefer the trait when they disagree so store + env stay paired.
    private var resolvedSystemColorScheme: ColorScheme {
        guard preference == .system else { return colorScheme }
        #if canImport(UIKit)
        switch UITraitCollection.current.userInterfaceStyle {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return colorScheme
        }
        #else
        return colorScheme
        #endif
    }

    private var appearance: WeekFitAppearance {
        preference.resolvedAppearance(system: resolvedSystemColorScheme)
    }

    private var resolvedPalette: WeekFitSemanticPalette {
        let blend = appearance == .light ? 0 : blendFactor
        return .interpolated(blend: blend, appearance: appearance)
    }

    func body(content: Content) -> some View {
        // Align static store on every render *before* descendants read WeekFitTheme.*,
        // so env palette and Theme.* never diverge mid-frame after resume.
        let palette = resolvedPalette
        alignStore(to: palette)

        return content
            .environment(\.weekFitPalette, palette)
            .onChange(of: blendFactor) { _, _ in
                // Store already aligned in body; keep onChange for explicit resume snaps.
                alignStore(to: resolvedPalette)
            }
            .onChange(of: colorScheme) { _, _ in
                alignStore(to: resolvedPalette)
            }
            .onChange(of: preference) { _, _ in
                alignStore(to: resolvedPalette)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                // Snap immediately — then once more after traits settle.
                alignStore(to: resolvedPalette)
                DispatchQueue.main.async {
                    alignStore(to: resolvedPalette)
                }
            }
    }

    private func alignStore(to palette: WeekFitSemanticPalette) {
        WeekFitAppearanceSync.apply(
            preference: preference,
            system: resolvedSystemColorScheme,
            nightBlend: palette.blendFactor
        )
    }
}
