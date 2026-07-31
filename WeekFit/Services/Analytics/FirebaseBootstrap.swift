import FirebaseCore
import Foundation
import OSLog

/// Earliest Firebase Core bootstrap. Call before any Analytics / Crashlytics use.
///
/// Important: never call `FirebaseApp.app()` before `FirebaseApp.configure()` —
/// `FIRApp.defaultApp` logs "The default Firebase app has not yet been configured."
enum FirebaseBootstrap {
    private static let lock = NSLock()
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "Analytics")

    /// Whether `configureIfNeeded()` has already run (success or missing-plist fallback).
    private static var didRun = false
    /// True only when `FirebaseApp.configure()` completed successfully.
    private static var didConfigureFirebase = false

    /// Configures the default Firebase app at most once.
    /// Returns `true` when Firebase is ready for Analytics / Crashlytics.
    @discardableResult
    static func configureIfNeeded() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if didRun {
            return didConfigureFirebase
        }
        didRun = true

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            logger.warning(
                "GoogleService-Info.plist not found in bundle. Copy docs/GoogleService-Info.plist.example to WeekFit/GoogleService-Info.plist and replace with Firebase Console values."
            )
            didConfigureFirebase = false
            return false
        }

        // Quiet Firebase internal chatter before configure (does not disable collection).
        #if DEBUG
        FirebaseConfiguration.shared.setLoggerLevel(.warning)
        #else
        FirebaseConfiguration.shared.setLoggerLevel(.error)
        #endif

        // Do not probe FirebaseApp.app() here — that emits the pre-configure warning.
        FirebaseApp.configure()
        didConfigureFirebase = true
        logger.info("FirebaseApp configured")
        return true
    }

    /// Whether Firebase was configured in this process (for AppAnalytics wiring).
    static var isConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didConfigureFirebase
    }
}
