import Foundation
import OSLog

/// Composition-root facade for product analytics.
///
/// Call `AppAnalytics.configure()` once at launch. Feature code should use
/// `AppAnalytics.shared` (or an injected `AnalyticsTracking`) — never Firebase APIs.
enum AppAnalytics {
    private static let lock = NSLock()
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "Analytics")

    nonisolated(unsafe) private static var _shared: AnalyticsTracking = LoggingAnalyticsService.shared

    static var shared: AnalyticsTracking {
        lock.lock()
        defer { lock.unlock() }
        return _shared
    }

    /// Installs the production analytics backend. Safe to call once from app startup.
    /// Requires `GoogleService-Info.plist` in the app bundle for Firebase.
    @discardableResult
    static func configure(firebaseConfigured: Bool) -> AnalyticsTracking {
        let service: AnalyticsTracking
        if firebaseConfigured {
            service = FirebaseAnalyticsService()
            logger.info("Analytics backend: Firebase")
        } else {
            service = LoggingAnalyticsService.shared
            logger.warning("Analytics backend: local logging only (Firebase not configured)")
        }

        lock.lock()
        _shared = service
        lock.unlock()
        return service
    }

        /// Test seam — installs a mock `AnalyticsTracking` backend.
    static func setSharedForTests(_ service: AnalyticsTracking) {
        lock.lock()
        _shared = service
        lock.unlock()
    }

    static func resetSharedForTests() {
        lock.lock()
        _shared = LoggingAnalyticsService.shared
        lock.unlock()
    }
}
