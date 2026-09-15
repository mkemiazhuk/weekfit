import Foundation

/// App Group shared between WeekFit and WeekFitWidget.
public enum WeekFitAppGroup {
    public static let identifier = "group.com.weekfit.app"
}

/// Deep links opened from the Home Screen widget and In-App Events.
public enum WeekFitWidgetDeepLink {
    public static let scheme = "weekfit"
    public static let todayHost = "today"
    public static let challengeHost = "challenge"
    public static let recoveryChallengePath = "recovery7"

    public static var todayURL: URL {
        URL(string: "\(scheme)://\(todayHost)")!
    }

    public static var todayNextActionURL: URL {
        URL(string: "\(scheme)://\(todayHost)?focus=next")!
    }

    /// App Store Connect In-App Event deep link (custom URL scheme).
    public static var recoveryChallengeURL: URL {
        URL(string: "\(scheme)://\(challengeHost)/\(recoveryChallengePath)")!
    }

    public static func isTodayURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == scheme && url.host?.lowercased() == todayHost
    }

    public static func isRecoveryChallengeURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == scheme else { return false }
        let host = url.host?.lowercased()
        if host == challengeHost {
            let trimmed = url.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .lowercased()
            return trimmed == recoveryChallengePath
        }
        // Alternate form: weekfit://recovery7
        return host == recoveryChallengePath
    }
}
