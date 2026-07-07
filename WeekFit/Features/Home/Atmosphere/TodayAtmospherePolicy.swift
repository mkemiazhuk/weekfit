import Foundation

/// Toggle for the experimental Today atmosphere background.
/// Roll back instantly by setting `isEnabled` to `false` or env `WEEKFIT_TODAY_ATMOSPHERE=0`.
enum TodayAtmospherePolicy {
    static var isEnabled: Bool {
        if ProcessInfo.processInfo.environment["WEEKFIT_TODAY_ATMOSPHERE"] == "0" {
            return false
        }
        return _isEnabled
    }

    /// Flip to `false` to restore the legacy Today background.
    static var _isEnabled = true
}
