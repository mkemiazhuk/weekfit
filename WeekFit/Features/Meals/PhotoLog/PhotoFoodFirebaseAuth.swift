import Foundation
import FirebaseAuth
import OSLog

/// Shared Firebase Authentication for WeekFit cloud APIs (food photo + evening Coach summary).
///
/// WeekFit’s Sign in with Apple / DEBUG email accounts remain a separate local session
/// (`AuthService` / `AppSessionState`). This layer does **not** replace that account system.
/// Guests get a silent Firebase anonymous user so cloud routes can verify a Firebase ID token.
/// Link Apple → Firebase later if product wants a single identity.
enum PhotoFoodFirebaseAuth {
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "PhotoFoodAuth")

    enum AuthFailure: Error, Equatable {
        case firebaseNotConfigured
        /// Identity Toolkit / Anonymous provider missing or disabled for this Firebase project.
        case authConfigurationMissing
        case signInFailed
        case tokenUnavailable
    }

    /// Returns a Firebase ID token. Never log the token value.
    static func idToken(forcingRefresh: Bool = false) async throws -> String {
        guard FirebaseBootstrap.isConfigured else {
            throw AuthFailure.firebaseNotConfigured
        }

        if Auth.auth().currentUser == nil {
            do {
                _ = try await Auth.auth().signInAnonymously()
                logger.info("Firebase anonymous session established for photo recognition")
            } catch {
                throw mapSignInError(error)
            }
        }

        guard let user = Auth.auth().currentUser else {
            throw AuthFailure.tokenUnavailable
        }

        do {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                user.getIDTokenForcingRefresh(forcingRefresh) { token, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let token, !token.isEmpty else {
                        continuation.resume(throwing: AuthFailure.tokenUnavailable)
                        return
                    }
                    continuation.resume(returning: token)
                }
            }
        } catch {
            logger.error("Firebase ID token fetch failed refresh=\(forcingRefresh, privacy: .public)")
            throw AuthFailure.tokenUnavailable
        }
    }

    private static func mapSignInError(_ error: Error) -> AuthFailure {
        let ns = error as NSError
        let message = (ns.userInfo[NSLocalizedDescriptionKey] as? String ?? ns.localizedDescription)
            .lowercased()
        logger.error(
            "Firebase anonymous sign-in failed domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)"
        )

        // Identity Toolkit returns CONFIGURATION_NOT_FOUND when Authentication was never
        // initialized for the Firebase project, or Anonymous is not enabled.
        // 17085 = adminRestrictedOperation (Anonymous disabled / ADMIN_ONLY_OPERATION)
        // 17006 = operationNotAllowed
        let looksLikeMissingConfig =
            message.contains("configuration_not_found")
            || message.contains("configuration not found")
            || message.contains("operation is not allowed")
            || message.contains("admin-restricted-operation")
            || message.contains("admin_only_operation")
            || ns.code == AuthErrorCode.adminRestrictedOperation.rawValue
            || ns.code == AuthErrorCode.operationNotAllowed.rawValue
            || ns.code == AuthErrorCode.invalidAPIKey.rawValue
            || ns.code == AuthErrorCode.appNotAuthorized.rawValue

        if looksLikeMissingConfig {
            return .authConfigurationMissing
        }
        return .signInFailed
    }
}
