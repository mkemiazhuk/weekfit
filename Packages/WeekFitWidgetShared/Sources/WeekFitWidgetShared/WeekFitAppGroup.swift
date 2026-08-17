import Foundation

/// App Group shared between WeekFit and WeekFitWidget.
public enum WeekFitAppGroup {
    public static let identifier = "group.com.weekfit.app"
}

/// Deep links opened from the Home Screen widget.
public enum WeekFitWidgetDeepLink {
    public static let scheme = "weekfit"
    public static let todayHost = "today"

    public static var todayURL: URL {
        URL(string: "\(scheme)://\(todayHost)")!
    }

    public static var todayNextActionURL: URL {
        URL(string: "\(scheme)://\(todayHost)?focus=next")!
    }

    public static func isTodayURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == scheme && url.host?.lowercased() == todayHost
    }
}
