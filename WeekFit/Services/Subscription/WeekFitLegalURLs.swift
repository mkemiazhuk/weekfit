import Foundation

/// Canonical legal URLs already used by App Store Connect and weekfit.app.
/// Do not invent parallel destinations.
enum WeekFitLegalURLs {
    static let privacy = URL(string: "https://weekfit.app/privacy.html")!
    static let terms = URL(string: "https://weekfit.app/terms/")!
}
