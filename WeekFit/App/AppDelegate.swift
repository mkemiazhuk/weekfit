import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 1) Firebase Core first — before AnalyticsBootstrap / AppAnalytics / Crashlytics.
        FirebaseBootstrap.configureIfNeeded()
        // 2) Install the app analytics backend (FirebaseAnalyticsService or logging fallback).
        AnalyticsBootstrap.configure()
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }
}
