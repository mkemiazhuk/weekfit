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
        makeInitials(from: cleanName)
    }
    
    private func makeInitials(from name: String) -> String {

        let parts = name
            .split(separator: " ")
            .map(String.init)

        guard !parts.isEmpty else {
            return "P"
        }

        let initials = parts
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()

        return initials.isEmpty ? "P" : initials
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 26) {
                header

                VStack(spacing: 18) {
                    avatar

                    VStack(spacing: 6) {
                        Text("Personalize your experience.")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary)

                        Text("This stays local on your device.")
                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                            .foregroundStyle(textSecondary)
                    }
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                inputField(
                    title: "Name or nickname",
                    text: $name,
                    placeholder: "Max"
                )

                Spacer()

                Button {
                    save()
                } label: {
                    Text("Save")
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
                .disabled(!canSave)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            name = viewModel.userProfile.fullName
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.065))
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.08), lineWidth: 1)
                        }

                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .frame(width: 48, height: 48)
            }

            Spacer()

            Text("Personalization")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            Spacer()

            Color.clear
                .frame(width: 48, height: 48)
        }
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

            TextField(placeholder, text: text)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(cardBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.08), lineWidth: 1)
                        }
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
