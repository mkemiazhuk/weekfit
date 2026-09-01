import Foundation

enum WeekFitSubscriptionPeriodUnit: Equatable, Sendable {
    case day
    case week
    case month
    case year
}

struct WeekFitIntroductoryOfferSnapshot: Equatable, Sendable {
    var periodValue: Int
    var periodUnit: WeekFitSubscriptionPeriodUnit
}

struct WeekFitProductSnapshot: Equatable, Identifiable, Sendable {
    var id: String
    var displayName: String
    var displayPrice: String
    var price: Decimal
    var periodUnit: WeekFitSubscriptionPeriodUnit
    /// Subscription period length from the same StoreKit `Product` (e.g. 1 for P1Y).
    var periodValue: Int
    /// ISO currency from `Product.priceFormatStyle.currencyCode` (same Product as displayPrice).
    var currencyCode: String?
    var monthlyEquivalentDisplay: String?
    var introductoryOffer: WeekFitIntroductoryOfferSnapshot?

    /// Human period for temporary StoreKit diagnostics screenshots.
    var diagnosticsPeriodDescription: String {
        let unitLabel: String
        switch periodUnit {
        case .day: unitLabel = periodValue == 1 ? "day" : "days"
        case .week: unitLabel = periodValue == 1 ? "week" : "weeks"
        case .month: unitLabel = periodValue == 1 ? "month" : "months"
        case .year: unitLabel = periodValue == 1 ? "year" : "years"
        }
        return "\(periodValue) \(unitLabel)"
    }

    /// Stable decimal string for diagnostics (no currency symbol).
    var diagnosticsNumericPrice: String {
        NSDecimalNumber(decimal: price).stringValue
    }
}

/// Storefront captured alongside a product load (same refresh as paywall prices).
struct WeekFitStorefrontSnapshot: Equatable, Sendable {
    var countryCode: String?
    var id: String?

    static let unknown = WeekFitStorefrontSnapshot(countryCode: nil, id: nil)
}

/// Result of `Product.products(for:)` mapped for the paywall — one path for UI + diagnostics.
struct WeekFitProductsLoadResult: Equatable, Sendable {
    var products: [WeekFitProductSnapshot]
    /// Count returned by `Product.products(for:)` before subscription filtering.
    var rawReturnedCount: Int
    var storefront: WeekFitStorefrontSnapshot
}

enum WeekFitPaywallCopy {
    /// Days covered by an introductory offer, for CTA copy. Returns nil when
    /// StoreKit did not attach an introductory offer.
    static func introductoryDayCount(from offer: WeekFitIntroductoryOfferSnapshot?) -> Int? {
        guard let offer, offer.periodValue > 0 else { return nil }
        switch offer.periodUnit {
        case .day:
            return offer.periodValue
        case .week:
            return offer.periodValue * 7
        case .month, .year:
            return nil
        }
    }

    static func savingsPercent(monthlyPrice: Decimal, yearlyPrice: Decimal) -> Int? {
        let yearOfMonthly = monthlyPrice * 12
        guard yearOfMonthly > 0, yearlyPrice > 0, yearlyPrice < yearOfMonthly else {
            return nil
        }
        let saved = ((yearOfMonthly - yearlyPrice) / yearOfMonthly) * 100
        let rounded = Int(NSDecimalNumber(decimal: saved).doubleValue.rounded())
        return rounded > 0 ? rounded : nil
    }

    static func monthlyEquivalent(yearlyPrice: Decimal) -> Decimal {
        yearlyPrice / 12
    }
}
