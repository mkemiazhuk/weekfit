import SwiftUI

/// Preferences → Nutrition Goal (body / calorie trajectory).
struct NutritionGoalSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var healthManager: HealthManager
    @ObservedObject var viewModel: ProfileViewModel

    @State private var selectedGoal: NutritionGoal = .maintenance
    @State private var hasLoaded = false

    private let background = Color.black
    private let accentGreen = Color(red: 0.58, green: 0.79, blue: 0.62)

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
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.54))
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
                        colors: [
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
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.92))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background {
                    Capsule()
                        .fill(accentGreen)
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        }
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
