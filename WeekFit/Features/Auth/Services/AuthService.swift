import Foundation
import AuthenticationServices

struct AppleUserData {
    let id: String
    let email: String?
    let givenName: String?
    let familyName: String?
    /// Locale-aware display name for Settings → Profile.
    let displayName: String?
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
    /// Device-local DEBUG email accounts. Cleared with account deletion / local data reset.
    enum DebugEmailAuthStorage {
        static let emailKey = "weekfit.debug.auth.email"
        static let passwordKey = "weekfit.debug.auth.password"
        static let builtinEmail = "demo@weekfit.app"
        static let builtinPassword = "123456"

        static func registeredEmail(in defaults: UserDefaults = .standard) -> String? {
            defaults.string(forKey: emailKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
        }

        static func registeredPassword(in defaults: UserDefaults = .standard) -> String? {
            defaults.string(forKey: passwordKey)
        }

        static func register(email: String, password: String, in defaults: UserDefaults = .standard) {
            defaults.set(email, forKey: emailKey)
            defaults.set(password, forKey: passwordKey)
        }

        static func clear(in defaults: UserDefaults = .standard) {
            defaults.removeObject(forKey: emailKey)
            defaults.removeObject(forKey: passwordKey)
        }
    }
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
        let normalizedEmail = email.lowercased()
        if let registered = DebugEmailAuthStorage.registeredEmail()?.lowercased(),
           registered == normalizedEmail,
           password == DebugEmailAuthStorage.registeredPassword() {
            return
        }

        if normalizedEmail == DebugEmailAuthStorage.builtinEmail.lowercased(),
           password == DebugEmailAuthStorage.builtinPassword {
            return
        }

        throw AuthError.invalidCredentials
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

        let normalizedEmail = email.lowercased()
        if let registered = DebugEmailAuthStorage.registeredEmail()?.lowercased(),
           registered == normalizedEmail {
            throw AuthError.emailAlreadyExists
        }

        DebugEmailAuthStorage.register(email: normalizedEmail, password: password)
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

        let normalizedEmail = email.lowercased()
        let isRegistered = DebugEmailAuthStorage.registeredEmail()?.lowercased() == normalizedEmail
        let isBuiltin = normalizedEmail == DebugEmailAuthStorage.builtinEmail.lowercased()
        guard isRegistered || isBuiltin else {
            throw AuthError.userNotFound
        }
        #else
        throw AuthError.appleSignInUnavailable
        #endif
    }

    func handleAppleCredential(
        _ credential: ASAuthorizationAppleIDCredential
    ) async throws -> AppleUserData {
        // Capture identity fields BEFORE any await — Apple only sends name/email
        // on the first authorization; later logins return nil even though the sheet shows them.
        let appleUserID = credential.user
        let existingProfileDisplay = ProfileService.resolvedFullName()
        let parsed = ApplePersonNameParser.parse(credential.fullName)
        let liveEmail = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines)

        AppleIdentityStore.merge(
            appleUserID: appleUserID,
            displayName: parsed?.displayName,
            givenName: parsed?.givenName,
            familyName: parsed?.familyName,
            email: (liveEmail?.isEmpty == false) ? liveEmail : nil
        )

        let cached = AppleIdentityStore.load(appleUserID: appleUserID)
        let resolvedDisplay = parsed?.displayName ?? cached?.displayName
        let resolvedGiven = parsed?.givenName ?? cached?.givenName
        let resolvedFamily = parsed?.familyName ?? cached?.familyName
        let resolvedEmail = ((liveEmail?.isEmpty == false) ? liveEmail : nil) ?? cached?.email

        AuthSessionStore.appleUserID = appleUserID

        // Persist into profile BEFORE any navigation / session transition.
        // Never overwrite a manually edited / already-persisted non-empty name.
        let profileService = ProfileService()
        if existingProfileDisplay.isEmpty {
            if let parsed {
                _ = profileService.applyAppleNameIfEmpty(parsed)
            } else if let display = resolvedDisplay {
                _ = profileService.applyAppleNameIfEmpty(
                    ApplePersonNameParser.ParsedName(
                        givenName: resolvedGiven,
                        familyName: resolvedFamily,
                        displayName: display
                    )
                )
            }
        }
        profileService.applyAppleEmailIfEmpty(resolvedEmail)

        await MainActor.run {
            WeekFitUserSettings.shared.refreshFromStorage()
        }

        try await Task.sleep(nanoseconds: 400_000_000)

        return AppleUserData(
            id: appleUserID,
            email: resolvedEmail,
            givenName: resolvedGiven,
            familyName: resolvedFamily,
            displayName: resolvedDisplay
        )
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

    func deleteAccount() async throws {
        // Remote deletion + local wipe are orchestrated by AccountDeletionService.
        AuthSessionStore.clear()
        #if DEBUG
        DebugEmailAuthStorage.clear()
        #endif
    }

    func signOut() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        AuthSessionStore.clear()
    }
}

#if DEBUG
private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
#endif
