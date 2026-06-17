import SwiftUI

struct EditUserProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @State private var name: String = ""

    private let background = Color.black
    private let cardBackground = Color.white.opacity(0.055)
    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.54)
    private let accentGreenTop = Color(red: 0.70, green: 0.88, blue: 0.72)
    private let accentGreenBottom = Color(red: 0.58, green: 0.79, blue: 0.62)
    
    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !cleanName.isEmpty
    }

    private var avatarInitial: String {
        ProfileService.makeInitials(from: cleanName)
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ProfilePremiumBackground(accent: accentGreenBottom)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header

                    VStack(spacing: 18) {
                        avatar

                        VStack(spacing: 6) {
                            Text(WeekFitLocalizedString("settings.profile.edit.headline"))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(WeekFitLocalizedString("settings.profile.edit.localNote"))
                                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                .foregroundStyle(textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    inputField(
                        title: WeekFitLocalizedString("settings.profile.edit.nameField"),
                        text: $name,
                        placeholder: WeekFitLocalizedString("settings.profile.edit.namePlaceholder")
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
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
        .onAppear {
            name = viewModel.userProfile.fullName
        }
    }

    private var header: some View {
        ProfilePremiumHeader(
            title: WeekFitLocalizedString("settings.profile.edit.title"),
            titleSize: 27,
            accent: accentGreenBottom
        ) {
            dismiss()
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(AppText.Common.Action.save)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(canSave ? 0.92 : 0.42))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentGreenTop.opacity(canSave ? 1 : 0.42),
                                    accentGreenBottom.opacity(canSave ? 1 : 0.42)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 248/255, green: 229/255, blue: 188/255),
                            Color(red: 217/255, green: 177/255, blue: 105/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(avatarInitial)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
        }
        .frame(width: 74, height: 74)
        .overlay {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }

    private func inputField(
        title: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            TextField(placeholder, text: text)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background {
                    Color.clear
                        .profilePremiumSectionCard(cornerRadius: 20)
                }
        }
    }

    private func save() {
        let updatedProfile = UserProfile(
            initials: avatarInitial,
            fullName: cleanName,
            email: ""
        )

        viewModel.updateUserProfile(updatedProfile)
        dismiss()
    }
}
