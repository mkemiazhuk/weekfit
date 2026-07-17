import SwiftUI

/// Lightweight name editor for Settings → Account → Edit Name.
struct EditNameView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @State private var name: String = ""
    @FocusState private var isNameFocused: Bool

    private let background = Color.black
    private var textPrimary: Color { WeekFitTheme.primaryText }
    private let textSecondary = WeekFitTheme.whiteOpacity(0.54)
    private let accentGreen = Color(red: 0.58, green: 0.79, blue: 0.62)

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !cleanName.isEmpty
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ProfilePremiumBackground(accent: accentGreen)

            VStack(alignment: .leading, spacing: 24) {
                ProfilePremiumHeader(
                    title: WeekFitLocalizedString("settings.editName.title"),
                    accent: accentGreen
                ) {
                    dismiss()
                }

                inputField

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            doneButton
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
        .onAppear {
            name = viewModel.userProfile.fullName
            isNameFocused = true
        }
    }

    private var inputField: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(WeekFitLocalizedString("settings.editName.nameField"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary)

            TextField(
                WeekFitLocalizedString("settings.editName.namePlaceholder"),
                text: $name
            )
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(textPrimary)
            .textContentType(.name)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($isNameFocused)
            .submitLabel(.done)
            .onSubmit {
                if canSave { save() }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background {
                Color.clear
                    .profilePremiumSectionCard(cornerRadius: 20)
            }
        }
    }

    private var doneButton: some View {
        Button {
            save()
        } label: {
            Text(AppText.Common.Action.done)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(canSave ? 0.92 : 0.42))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background {
                    Capsule()
                        .fill(accentGreen.opacity(canSave ? 1 : 0.42))
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .accessibilityIdentifier("settings.editName.done")
    }

    private func save() {
        guard canSave else { return }

        let updatedProfile = UserProfile(
            initials: ProfileService.makeInitials(from: cleanName),
            fullName: cleanName,
            email: viewModel.userProfile.email
        )
        viewModel.updateUserProfile(updatedProfile)
        dismiss()
    }
}
