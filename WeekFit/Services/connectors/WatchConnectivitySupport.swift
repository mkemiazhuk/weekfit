import Foundation
import WatchConnectivity

enum WatchConnectivitySupport {

    /// True once the iOS app declares a Watch companion in Info.plist (added with the watch target).
    static var hasCompanionWatchApp: Bool {
        guard let bundleID = Bundle.main.object(forInfoDictionaryKey: "WKCompanionAppBundleIdentifier") as? String else {
            return false
        }
        return !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var shouldActivateSession: Bool {
        WCSession.isSupported() && hasCompanionWatchApp
    }

    static func activateSession(delegate: WCSessionDelegate) {
        guard shouldActivateSession else { return }

        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = delegate
        }
        guard session.activationState == .notActivated else { return }
        session.activate()
    }

    static var isLiveBridgeAvailable: Bool {
        guard shouldActivateSession else { return false }
        let session = WCSession.default
        return session.activationState == .activated &&
            session.isPaired &&
            session.isWatchAppInstalled
    }
}
