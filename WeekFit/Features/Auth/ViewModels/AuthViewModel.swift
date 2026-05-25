import Foundation
import SwiftUI
internal import Combine
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var isAuthenticated: Bool {
        isLoggedIn
    }

    private let authService = AuthService()

    func signIn(with provider: AuthProvider) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            try await authService.signIn(with: provider)
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            try await authService.signInWithEmail(
                email: email,
                password: password
            )

            isLoggedIn = true
        } catch {
            errorMessage = cleanError(error)
        }
    }

    func createAccountWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            try await authService.createAccountWithEmail(
                email: email,
                password: password
            )

            isLoggedIn = true
        } catch {
            errorMessage = cleanError(error)
        }
    }

    func sendPasswordReset(email: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            try await authService.sendPasswordReset(email: email)
            successMessage = "Password reset link sent to your email."
        } catch {
            errorMessage = cleanError(error)
        }
    }

    func handleAppleSignIn(
        _ result: Result<ASAuthorization, Error>
    ) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unable to read Apple credentials."
                return
            }

            do {
                let user = try await authService.handleAppleCredential(credential)

                print("Apple User ID:", user.id)
                print("Email:", user.email ?? "No email")
                print("First Name:", user.firstName ?? "No name")

                isLoggedIn = true
            } catch {
                errorMessage = cleanError(error)
            }

        case .failure(let error):
            errorMessage = cleanError(error)
        }
    }

    func signOut() {
        Task {
            try? await authService.signOut()
            isLoggedIn = false
            errorMessage = nil
            successMessage = nil
        }
    }

    private func cleanError(_ error: Error) -> String {
        let message = error.localizedDescription

        if message.lowercased().contains("invalid") {
            return "Invalid email or password."
        }

        if message.lowercased().contains("already") {
            return "This email is already registered."
        }

        if message.lowercased().contains("network") {
            return "Network error. Please try again."
        }

        return message
    }
}
