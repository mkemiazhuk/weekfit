import Foundation
import AuthenticationServices

struct AppleUserData {
    let id: String
    let email: String?
    let firstName: String?
}

enum AuthProvider {
    case apple
    case email
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case invalidEmail
    case weakPassword
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password."

        case .emailAlreadyExists:
            return "This email is already registered."

        case .invalidEmail:
            return "Please enter a valid email."

        case .weakPassword:
            return "Password should be at least 6 characters."

        case .userNotFound:
            return "Account not found."
        }
    }
}

final class AuthService {

    // MARK: - Mock storage

    private var savedEmail = "demo@weekfit.app"
    private var savedPassword = "123456"

    // MARK: - Generic Sign In

    func signIn(with provider: AuthProvider) async throws {
        try await Task.sleep(nanoseconds: 700_000_000)
    }

    // MARK: - Email Auth

    func signInWithEmail(
        email: String,
        password: String
    ) async throws {

        try await Task.sleep(nanoseconds: 700_000_000)

        guard email.contains("@") else {
            throw AuthError.invalidEmail
        }

        guard email.lowercased() == savedEmail.lowercased(),
              password == savedPassword else {
            throw AuthError.invalidCredentials
        }
    }

    func createAccountWithEmail(
        email: String,
        password: String
    ) async throws {

        try await Task.sleep(nanoseconds: 900_000_000)

        guard email.contains("@") else {
            throw AuthError.invalidEmail
        }

        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }

        if email.lowercased() == savedEmail.lowercased() {
            throw AuthError.emailAlreadyExists
        }

        savedEmail = email
        savedPassword = password
    }

    func sendPasswordReset(
        email: String
    ) async throws {

        try await Task.sleep(nanoseconds: 800_000_000)

        guard email.contains("@") else {
            throw AuthError.invalidEmail
        }

        guard email.lowercased() == savedEmail.lowercased() else {
            throw AuthError.userNotFound
        }

        // Password reset is handled by the auth backend when production auth ships.
        _ = email
    }

    // MARK: - Apple Sign In

    func handleAppleCredential(
        _ credential: ASAuthorizationAppleIDCredential
    ) async throws -> AppleUserData {

        try await Task.sleep(nanoseconds: 400_000_000)

        return AppleUserData(
            id: credential.user,
            email: credential.email,
            firstName: credential.fullName?.givenName
        )
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
    }
}
