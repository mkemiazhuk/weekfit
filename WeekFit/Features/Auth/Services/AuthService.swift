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
    case appleSignInUnavailable

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

        case .appleSignInUnavailable:
            return "Sign in with Apple is required."
        }
    }
}

final class AuthService {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    #if DEBUG
    private var savedEmail = "demo@weekfit.app"
    private var savedPassword = "123456"
    #endif

    func signIn(with provider: AuthProvider) async throws {
        switch provider {
        case .apple:
            try await Task.sleep(nanoseconds: 700_000_000)
        case .email:
            #if DEBUG
            try await Task.sleep(nanoseconds: 700_000_000)
            #else
            throw AuthError.appleSignInUnavailable
            #endif
        }
    }

    func signInWithEmail(
        email: String,
        password: String
    ) async throws {
        try await Task.sleep(nanoseconds: 700_000_000)

        guard email.contains("@") else {
            throw AuthError.invalidEmail
        }

        if AppReviewDemoCredentials.matches(email: email, password: password) {
            return
        }

        #if DEBUG
        guard email.lowercased() == savedEmail.lowercased(),
              password == savedPassword else {
            throw AuthError.invalidCredentials
        }
        #else
        throw AuthError.invalidCredentials
        #endif
    }

    func createAccountWithEmail(
        email: String,
        password: String
    ) async throws {
        #if DEBUG
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
        #else
        throw AuthError.appleSignInUnavailable
        #endif
    }

    func sendPasswordReset(
        email: String
    ) async throws {
        #if DEBUG
        try await Task.sleep(nanoseconds: 800_000_000)

        guard email.contains("@") else {
            throw AuthError.invalidEmail
        }

        guard email.lowercased() == savedEmail.lowercased() else {
            throw AuthError.userNotFound
        }
        #else
        throw AuthError.appleSignInUnavailable
        #endif
    }

    func handleAppleCredential(
        _ credential: ASAuthorizationAppleIDCredential
    ) async throws -> AppleUserData {
        try await Task.sleep(nanoseconds: 400_000_000)

        let user = AppleUserData(
            id: credential.user,
            email: credential.email,
            firstName: credential.fullName?.givenName
        )
        AuthSessionStore.appleUserID = user.id
        return user
    }

    func restoreAppleSessionIfValid() async -> Bool {
        guard let userID = AuthSessionStore.appleUserID else { return false }

        let provider = ASAuthorizationAppleIDProvider()
        let state: ASAuthorizationAppleIDProvider.CredentialState
        do {
            state = try await provider.credentialState(forUserID: userID)
        } catch {
            AuthSessionStore.clear()
            return false
        }

        switch state {
        case .authorized:
            return true
        case .revoked, .notFound, .transferred:
            AuthSessionStore.clear()
            return false
        @unknown default:
            AuthSessionStore.clear()
            return false
        }
    }

    func signOut() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        AuthSessionStore.clear()
    }
}
