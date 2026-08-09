import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        StartupDiagnostics.step(1, "app init", detail: "AppDelegate.didFinishLaunching begin")
        // 1) Firebase Core first — before AnalyticsBootstrap / AppAnalytics / Crashlytics.
        //    Do not call Crashlytics / Analytics APIs before this returns.
        let firebaseReady = FirebaseBootstrap.configureIfNeeded()
        StartupDiagnostics.step(
            5,
            "Firebase configured",
            detail: firebaseReady ? "FirebaseApp ready" : "plist missing — analytics fallback"
        )
        // 2) Install the app analytics backend (FirebaseAnalyticsService or logging fallback).
        AnalyticsBootstrap.configure()
        StartupDiagnostics.step(5, "Firebase configured", detail: "AnalyticsBootstrap complete")
        if firebaseReady {
            StartupDiagnostics.logCrashlyticsStatus()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }
}
