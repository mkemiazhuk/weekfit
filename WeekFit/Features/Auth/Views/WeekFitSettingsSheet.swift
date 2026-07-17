import SwiftUI

// MARK: - Settings navigation environment

private enum SettingsNavigationPushKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when this screen was pushed inside the Settings `NavigationStack`.
    var isSettingsNavigationPush: Bool {
        get { self[SettingsNavigationPushKey.self] }
        set { self[SettingsNavigationPushKey.self] = newValue }
    }
}

extension View {
    /// Marks destination screens so headers show Back instead of Close.
    func settingsNavigationPush() -> some View {
        environment(\.isSettingsNavigationPush, true)
    }
}

// MARK: - Shared Settings sheet

/// Single presentation host for Settings across all tabs.
struct WeekFitSettingsSheetModifier: ViewModifier {
    @Binding var isPresented: Bool

    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var languageManager: AppLanguageManager
    @EnvironmentObject private var nightComfort: NightComfortController
    @EnvironmentObject private var authViewModel: AuthViewModel

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            NavigationStack {
                ProfileView()
            }
            .environmentObject(appSession)
            .environmentObject(healthManager)
            .environmentObject(nutritionViewModel)
            .environmentObject(coachCoordinator)
            .environmentObject(languageManager)
            .environmentObject(nightComfort)
            .environmentObject(authViewModel)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .weekFitSheetChrome(cornerRadius: 36)
        }
    }
}

extension View {
    func weekFitSettingsSheet(isPresented: Binding<Bool>) -> some View {
        modifier(WeekFitSettingsSheetModifier(isPresented: isPresented))
    }
}
