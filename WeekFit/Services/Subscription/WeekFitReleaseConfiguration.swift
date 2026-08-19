import Foundation

/// Release-time switches that must be confirmed before submitting WeekFit 1.3.
///
/// Keep product policy here so a launch decision is not buried in StoreKit code.
enum WeekFitReleaseConfiguration {
    enum Monetization {
        /// **Must be confirmed immediately before submitting / releasing 1.3.**
        ///
        /// Product rule (do not change): anyone whose original App Store
        /// download is strictly before paid subscriptions go live remains a
        /// legacy user with lifetime access. That includes people who
        /// downloaded the currently free production app before 1.3 with IAP
        /// is publicly available.
        ///
        /// `false` until the cutoff below is the real monetization launch
        /// instant — not a convenient calendar guess.
        static let cutoffConfirmedForAppStoreSubmission = false

        /// Provisional value for development and unit tests only.
        ///
        /// Replace this with the actual public IAP launch instant (UTC)
        /// before App Store submission. Eligibility still uses StoreKit 2
        /// `AppTransaction.originalPurchaseDate`, never app version and
        /// never UserDefaults as the source of truth.
        static let provisionalCutoffDate: Date = {
            var components = DateComponents()
            components.year = 2026
            components.month = 8
            components.day = 19
            components.hour = 0
            components.minute = 0
            components.second = 0
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            return calendar.date(from: components)!
        }()

        static var cutoffDate: Date { provisionalCutoffDate }
    }
}

/// Instant at which new App Store downloads require a WeekFit subscription.
///
/// Reads `WeekFitReleaseConfiguration.Monetization`. Do not treat the
/// provisional date as final until `cutoffConfirmedForAppStoreSubmission` is
/// flipped to `true` at submit time.
enum WeekFitMonetizationCutoff {
    static var date: Date { WeekFitReleaseConfiguration.Monetization.cutoffDate }
}
