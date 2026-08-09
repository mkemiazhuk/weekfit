import Foundation
import StoreKit
import UIKit

protocol StoreKitReviewRequesting: AnyObject {
    @MainActor
    func requestReview()
}

/// Requests a native App Store review via StoreKit.
/// Apple may choose not to show the system prompt; callers must not re-request aggressively.
/// StoreKit Sandbox proxy noise (SKInternalErrorDomain Code=12) is non-fatal and is not
/// started from cold launch — WeekFit has no subscription PaymentQueue observer.
@MainActor
final class SystemStoreKitReviewRequester: StoreKitReviewRequesting {
    func requestReview() {
        guard let scene = activeWindowScene() else { return }
        // Does not throw. Safe if App Store / Sandbox is unreachable.
        AppStore.requestReview(in: scene)
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }
}

/// Opens the App Store write-review page when an explicit Settings action needs a guaranteed surface.
enum AppStoreReviewURL {
    /// Production App Store Connect Apple ID (see `web/public/llms.txt`).
    static var appleID: String? { "6776311371" }

    static var writeReview: URL? {
        guard let appleID, !appleID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appleID)?action=write-review")
    }

    static var productPage: URL? {
        guard let appleID, !appleID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appleID)")
    }

    @MainActor
    @discardableResult
    static func openWriteReviewIfAvailable(
        fallbackOpen: (URL) -> Void = { UIApplication.shared.open($0) }
    ) -> Bool {
        guard let url = writeReview else { return false }
        fallbackOpen(url)
        return true
    }
}

final class RecordingStoreKitReviewRequester: StoreKitReviewRequesting {
    private(set) var requestCount = 0

    @MainActor
    func requestReview() {
        requestCount += 1
    }
}
