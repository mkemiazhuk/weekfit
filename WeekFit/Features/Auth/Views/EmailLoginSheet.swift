import SwiftUI

struct EmailLoginSheet: View {
    @ObservedObject var authViewModel: AuthViewModel
    let brandGreen: Color

    @Environment(\.dismiss) private var dismiss

    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private enum AuthMode {
        case signIn
        case createAccount
        case resetPassword

        var title: String {
            switch self {
            case .signIn: return "Welcome back"
            case .createAccount: return "Create account"
            case .resetPassword: return "Reset password"
            }
        }

        var subtitle: String {
            switch self {
            case .signIn: return "Continue your WeekFit journey."
            case .createAccount: return "Start building better routines."
            case .resetPassword: return "We’ll send you a reset link."
            }
        }

        var buttonTitle: String {
            switch self {
            case .signIn: return "Sign In"
            case .createAccount: return "Create Account"
            case .resetPassword: return "Send Reset Link"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 22) {
                header

                VStack(spacing: 12) {
                    inputField(
                        title: "Email",
                        text: $email,
                        icon: "envelope.fill",
                        keyboard: .emailAddress
                    )

                    if mode != .resetPassword {
                        secureField(
                            title: "Password",
                            text: $password,
                            icon: "lock.fill"
                        )
                    }

                    if mode == .createAccount {
                        secureField(
                            title: "Confirm password",
                            text: $confirmPassword,
                            icon: "checkmark.shield.fill"
                        )
                    }
                }

                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                mainButton

                bottomActions

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(width: 42, height: 5)
                .padding(.bottom, 12)

            Text(mode.title)
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(.white)

            Text(mode.subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
        }
    }

    private var mainButton: some View {
        Button {
            Task {
                await handleAction()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(canSubmit ? brandGreen : Color.white.opacity(0.12))
                    .frame(height: 52)

                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(mode.buttonTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .disabled(!canSubmit || authViewModel.isLoading)
        .padding(.top, 4)
    }

    private var bottomActions: some View {
        VStack(spacing: 12) {
            if mode == .signIn {
                Button("Forgot password?") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        mode = .resetPassword
                        password = ""
                        confirmPassword = ""
                        authViewModel.errorMessage = nil
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.66))
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    switch mode {
                    case .signIn:
                        mode = .createAccount
                    case .createAccount, .resetPassword:
                        mode = .signIn
                    }

                    password = ""
                    confirmPassword = ""
                    authViewModel.errorMessage = nil
                }
            } label: {
                Text(switchModeText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(brandGreen)
            }
        }
        .padding(.top, 2)
    }

    private var switchModeText: String {
        switch mode {
        case .signIn:
            return "New to WeekFit? Create account"
        case .createAccount:
            return "Already have an account? Sign in"
        case .resetPassword:
            return "Back to sign in"
        }
    }

    private var canSubmit: Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .signIn:
            return cleanEmail.contains("@") && password.count >= 6
        case .createAccount:
            return cleanEmail.contains("@")
                && password.count >= 6
                && password == confirmPassword
        case .resetPassword:
            return cleanEmail.contains("@")
        }
    }

    private func handleAction() async {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .signIn:
            await authViewModel.signInWithEmail(
                email: cleanEmail,
                password: password
            )

        case .createAccount:
            await authViewModel.createAccountWithEmail(
                email: cleanEmail,
                password: password
            )

        case .resetPassword:
            await authViewModel.sendPasswordReset(email: cleanEmail)
        }

        if authViewModel.isAuthenticated {
            dismiss()
        }
    }

    private func inputField(
        title: String,
        text: Binding<String>,
        icon: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
                .frame(width: 20)

            TextField(title, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
        }
    }

    private func secureField(
        title: String,
        text: Binding<String>,
        icon: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
                .frame(width: 20)

            SecureField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
        }
    }
}
