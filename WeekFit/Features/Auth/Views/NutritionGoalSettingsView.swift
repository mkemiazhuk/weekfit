import SwiftUI

/// Preferences → Nutrition Goal (body / calorie trajectory).
struct NutritionGoalSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var healthManager: HealthManager
    @ObservedObject var viewModel: ProfileViewModel

    @State private var selectedGoal: NutritionGoal = .maintenance
    @State private var hasLoaded = false

    private var background: Color { WeekFitTheme.backgroundColor }
    private var accentGreen: Color { WeekFitTheme.settingsAccent }

    private var hasHealthBiometrics: Bool {
        UserNutritionProfile.hasSufficientHealthDataForAutoGoal(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm
        )
    }

    private var suggestedGoal: NutritionGoal? {
        guard hasHealthBiometrics, !viewModel.hasManualNutritionGoal() else { return nil }
        let suggested = UserNutritionProfile.suggestedGoal(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm
        )
        return suggested == selectedGoal ? nil : suggested
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ProfilePremiumBackground(accent: accentGreen)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    ProfilePremiumHeader(
                        title: WeekFitLocalizedString("settings.nutritionGoal.title"),
                        accent: accentGreen
                    ) {
                        dismiss()
                    }

                    Text(WeekFitLocalizedString("settings.nutritionGoal.subtitle"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    BodyGoalPickerSection(
                        selectedGoal: $selectedGoal,
                        hasHealthBiometrics: hasHealthBiometrics,
                        suggestedGoal: suggestedGoal
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            saveButton
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background {
                    LinearGradient(
                        colors: palette.isLight
                            ? [
                                WeekFitTheme.backgroundColor.opacity(0),
                                WeekFitTheme.backgroundColor.opacity(0.94)
                            ]
                            : [
                                Color.black.opacity(0.0),
                                Color.black.opacity(0.82)
                            ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
        }
        .task {
            await loadHealthProfileIfNeeded()
            syncSelectedGoal()
            hasLoaded = true
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(AppText.Common.Action.save)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryCTAForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    Capsule()
                        .fill(WeekFitTheme.primaryCTA)
                }
        }
        .buttonStyle(.plain)
        .disabled(!hasLoaded)
        .accessibilityIdentifier("settings.nutritionGoal.save")
    }

    private func loadHealthProfileIfNeeded() async {
        let actualAccess = await healthManager.checkReadAuthorizationStatus()
        await MainActor.run {
            healthManager.isHealthAccessGranted = actualAccess
        }
        guard actualAccess else { return }
        await healthManager.loadUserProfile()
    }

    private func syncSelectedGoal() {
        selectedGoal = ProfileService().resolvedNutritionGoal(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm
        )
    }

    private func save() {
        viewModel.saveBodyGoal(selectedGoal)
        appSession.triggerCoachRefresh(source: "nutritionGoalChanged")
        appSession.triggerHealthRefresh(source: "nutritionGoalChanged")
        dismiss()
    }
}
