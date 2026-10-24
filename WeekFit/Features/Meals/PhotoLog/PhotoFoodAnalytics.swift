import Foundation

enum PhotoFoodAnalytics {
    private static var logFoodOpenedAt: Date?
    /// True only when this scan opened the food-logging flow itself.
    /// A scan inside an already-open Quick Log must not start or fail that flow.
    private static var ownsFoodLoggingFlow = false

    static func noteLogFoodOpened() {
        logFoodOpenedAt = Date()
    }

    #if DEBUG
    static func resetForTests() {
        logFoodOpenedAt = nil
        ownsFoodLoggingFlow = false
    }
    #endif

    static func scanStarted(method: PhotoFoodCaptureMethod) {
        let loggingMethod: FoodLoggingMethod = method == .barcode ? .barcode : .photo
        if ProductAnalytics.hasOpenFoodLoggingFlow() {
            ownsFoodLoggingFlow = false
        } else {
            ownsFoodLoggingFlow = true
            ProductAnalytics.foodLoggingStarted(method: loggingMethod, source: .today, operation: .diary)
        }
        AppAnalytics.shared.track(
            .foodPhotoScanStarted,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: AnalyticsSource.today.rawValue
            ]
        )
    }

    static func scanCompleted(method: PhotoFoodCaptureMethod) {
        AppAnalytics.shared.track(
            .foodPhotoScanCompleted,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: AnalyticsSource.today.rawValue
            ]
        )
    }

    static func scanFailed(method: PhotoFoodCaptureMethod, reason: SafeAnalyticsFailureReason) {
        AppAnalytics.shared.track(
            .foodPhotoScanFailed,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: AnalyticsSource.today.rawValue,
                AnalyticsParameterKey.reason: reason.rawValue
            ]
        )
        if ownsFoodLoggingFlow {
            ownsFoodLoggingFlow = false
            ProductAnalytics.foodLoggingFailed(
                method: method == .barcode ? .barcode : .photo,
                source: .today,
                operation: .diary,
                reason: reason
            )
        }
    }

    static func confirmationShown(method: PhotoFoodCaptureMethod) {
        AppAnalytics.shared.track(
            .foodPhotoConfirmationShown,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: AnalyticsSource.today.rawValue
            ]
        )
    }

    static func logged(
        method: FoodLoggingMethod,
        savedToLibrary: Bool,
        estimateKind: PhotoFoodEstimateKind
    ) {
        var parameters: [String: String] = [
            AnalyticsParameterKey.method: method.rawValue,
            AnalyticsParameterKey.source: AnalyticsSource.today.rawValue,
            AnalyticsParameterKey.savedToLibrary: savedToLibrary ? "true" : "false",
            AnalyticsParameterKey.estimateKind: estimateKind.rawValue
        ]
        if let opened = logFoodOpenedAt {
            parameters[AnalyticsParameterKey.durationBucket] = durationBucket(
                seconds: Date().timeIntervalSince(opened)
            )
        }
        AppAnalytics.shared.track(.foodPhotoLogged, parameters: parameters)
        logFoodOpenedAt = nil
        ownsFoodLoggingFlow = false
    }

    private static func durationBucket(seconds: TimeInterval) -> String {
        switch seconds {
        case ..<15: return "0_15s"
        case ..<30: return "15_30s"
        case ..<60: return "30_60s"
        case ..<120: return "60_120s"
        default: return "120s_plus"
        }
    }
}
