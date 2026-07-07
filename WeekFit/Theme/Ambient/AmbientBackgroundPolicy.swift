import Foundation

enum AmbientBackgroundPolicy {
    static var isEnabled: Bool {
        if ProcessInfo.processInfo.environment["WEEKFIT_AMBIENT_BACKGROUND"] == "0" {
            return false
        }
        return _isEnabled
    }

    static var _isEnabled = true
}
