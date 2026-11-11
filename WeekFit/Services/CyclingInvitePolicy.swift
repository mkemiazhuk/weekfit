import Foundation

/// A ride is a poor invitation in the cold months, at a chilly temperature,
/// after dark, or in a storm. A walk can still be fine in the same weather.
enum CyclingInvitePolicy {
    /// At or below this air temperature a ride is not offered.
    static let chillyCelsius: Double = 8
    /// At or below this feels-like temperature a ride is not offered.
    static let chillyFeelsLikeCelsius: Double = 6

    static func allows(
        now: Date,
        temperatureCelsius: Double?,
        feelsLikeCelsius: Double?,
        isStorm: Bool = false,
        calendar: Calendar = .current
    ) -> Bool {
        if isStorm { return false }
        let month = calendar.component(.month, from: now)
        if [11, 12, 1, 2, 3].contains(month) { return false }
        let hour = calendar.component(.hour, from: now)
        if hour >= 18 || hour < 6 { return false }
        if let temperatureCelsius, temperatureCelsius <= chillyCelsius { return false }
        if let feelsLikeCelsius, feelsLikeCelsius <= chillyFeelsLikeCelsius { return false }
        return true
    }
}
