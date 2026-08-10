import AuthenticationServices
import UIKit
internal import Combine

/// Presents the system Sign in with Apple sheet after an in-app confirmation.
/// Used when Sign in with Apple is destructive (replaces the current local workspace).
@MainActor
final class AppleSignInPresenter: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var onComplete: ((Result<ASAuthorization, Error>) -> Void)?

    func start(onComplete: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.onComplete = onComplete

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            let callback = onComplete
            onComplete = nil
            callback?(.success(authorization))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            let callback = onComplete
            onComplete = nil
            callback?(.failure(error))
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let key = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return key
        }
        return scenes.flatMap(\.windows).first ?? ASPresentationAnchor()
    }
}
