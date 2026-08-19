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
    var monthlyEquivalentDisplay: String?
    var introductoryOffer: WeekFitIntroductoryOfferSnapshot?
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
