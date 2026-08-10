import Foundation

/// Single source of truth for Firebase telemetry environment.
///
/// - DEBUG / Xcode: `.debug`
/// - TestFlight: `.testFlight` (sandbox App Store receipt)
/// - App Store: `.appStore`
enum AppDistribution: String, Sendable {
    case debug
    case testFlight = "testflight"
    case appStore = "appstore"

    /// Value for Analytics user property / Crashlytics custom key `distribution`.
    var analyticsValue: String { rawValue }

    /// Production resolution. Prefer `resolve(isDebugBuild:receiptURL:)` in tests.
    static var current: AppDistribution {
        #if DEBUG
        resolve(isDebugBuild: true, receiptURL: Bundle.main.appStoreReceiptURL)
        #else
        resolve(isDebugBuild: false, receiptURL: Bundle.main.appStoreReceiptURL)
        #endif
    }

    /// Pure resolver for unit tests and production.
    static func resolve(isDebugBuild: Bool, receiptURL: URL?) -> AppDistribution {
        if isDebugBuild { return .debug }
        if isTestFlightReceipt(receiptURL) { return .testFlight }
        return .appStore
    }

    /// TestFlight installs use the sandbox App Store receipt filename.
    static func isTestFlightReceipt(_ receiptURL: URL?) -> Bool {
        receiptURL?.lastPathComponent == "sandboxReceipt"
    }
}

// Compatibility alias for the previous name used in early analytics work.
typealias AppDistributionChannel = AppDistribution
