import Foundation

/// Which activities are worth suggesting at a given hour.
/// The full catalog stays available; this only gates invitations.
enum ActivityInviteTime {
    /// Hours when suggesting this catalog image is a good idea. Unknown images stay allowed.
    static func allows(imageName: String, hour: Int) -> Bool {
        guard let window = windows[imageName] else { return true }
        return window.contains(hour)
    }

    static func allows(actionID: String, hour: Int) -> Bool {
        guard let imageName = imageNames[actionID] else { return true }
        return allows(imageName: imageName, hour: hour)
    }

    static func imageName(forActivityType raw: String) -> String {
        switch raw {
        case "running": return "workout-running"
        case "cycling": return "workout-cycling"
        case "swimming": return "workout-swimming"
        case "hiit": return "workout-hiit"
        case "tennis": return "workout-tennis"
        case "padel": return "workout-padel"
        case "squash": return "workout-squash"
        case "upperBody": return "workout-strength"
        case "lowerBody": return "workout-lowerbody"
        case "core": return "workout-core"
        case "fullBody": return "workout-fullbody"
        case "walk": return "recovery-walk"
        case "stretching": return "recovery-stretch"
        case "yoga": return "recovery-yoga"
        case "breathing": return "recovery-breathing"
        case "sauna": return "recovery-sauna"
        case "snowboarding": return "workout-snowboarding"
        case "downhillSkiing": return "workout-skiing"
        default: return ""
        }
    }

    private static let imageNames: [String: String] = [
        "activity.running": "workout-running",
        "activity.cycling": "workout-cycling",
        "activity.swimming": "workout-swimming",
        "activity.hiit": "workout-hiit",
        "activity.tennis": "workout-tennis",
        "activity.padel": "workout-padel",
        "activity.squash": "workout-squash",
        "activity.upper-body": "workout-strength",
        "activity.lower-body": "workout-lowerbody",
        "activity.core": "workout-core",
        "activity.full-body": "workout-fullbody",
        "activity.hiking": "workout-hiking",
        "activity.snowboarding": "workout-snowboarding",
        "activity.alpine-skiing": "workout-skiing",
        "recovery.walk": "recovery-walk",
        "recovery.stretching": "recovery-stretch",
        "recovery.yoga": "recovery-yoga",
        "recovery.breathing": "recovery-breathing",
        "recovery.sauna": "recovery-sauna"
    ]

    /// Inclusive start, exclusive end. A run belongs to the morning and the day, not 19:16.
    private static let windows: [String: Range<Int>] = [
        "workout-running": 6..<18,
        "workout-cycling": 6..<18,
        "workout-hiking": 8..<17,
        "workout-snowboarding": 8..<16,
        "workout-skiing": 8..<16,
        "workout-tennis": 8..<18,
        "workout-padel": 9..<21,
        "workout-squash": 8..<21,
        "workout-swimming": 6..<22,
        "workout-strength": 6..<21,
        "workout-core": 6..<21,
        "workout-lowerbody": 6..<21,
        "workout-fullbody": 6..<21,
        "workout-hiit": 6..<18,
        "recovery-walk": 7..<21,
        "recovery-stretch": 6..<23,
        "recovery-yoga": 6..<23,
        "recovery-sauna": 6..<23,
        "recovery-breathing": 0..<24
    ]
}
