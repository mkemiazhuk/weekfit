import Foundation

/// App Store Connect subscription product identifiers.
enum WeekFitSubscriptionProductID: String, CaseIterable, Sendable {
    case monthly = "com.weekfit.subscription.monthly"
    case annual = "com.weekfit.subscription.annual"

    static var allRawValues: [String] {
        allCases.map(\.rawValue)
    }

    var isAnnual: Bool { self == .annual }
}
