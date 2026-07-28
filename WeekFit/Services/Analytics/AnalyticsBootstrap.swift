import Foundation
import OSLog

/// Wires `AppAnalytics` after Firebase Core is ready.
/// Does not call `FirebaseApp.configure()` — that belongs to `FirebaseBootstrap`.
enum AnalyticsBootstrap {
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "Analytics")

    /// Call once from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
    /// **after** `FirebaseBootstrap.configureIfNeeded()`.
    static func configure() {
        let firebaseReady = FirebaseBootstrap.isConfigured
        _ = AppAnalytics.configure(firebaseConfigured: firebaseReady)
        if !firebaseReady {
            logger.warning("AppAnalytics using local logging backend (Firebase not configured)")
        }
    }
}
