import SwiftUI

enum AmbientBackgroundStyle: String, Equatable, Sendable, CaseIterable {
    case morning
    case day
    case evening
    case night
    case recovery
    case restProtection
    case activity
    case nutrition

    var primaryColor: Color {
        switch self {
        case .morning:
            return Color(red: 0.34, green: 0.58, blue: 0.82)
        case .day:
            return Color(red: 0.86, green: 0.72, blue: 0.42)
        case .evening:
            return Color(red: 0.72, green: 0.48, blue: 0.58)
        case .night:
            return Color(red: 0.22, green: 0.28, blue: 0.58)
        case .recovery:
            return Color(red: 0.38, green: 0.72, blue: 0.78)
        case .restProtection:
            return Color(red: 0.52, green: 0.40, blue: 0.78)
        case .activity:
            return Color(red: 0.42, green: 0.68, blue: 0.48)
        case .nutrition:
            return Color(red: 0.82, green: 0.58, blue: 0.30)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .morning:
            return Color(red: 0.28, green: 0.68, blue: 0.76)
        case .day:
            return Color(red: 0.92, green: 0.78, blue: 0.52)
        case .evening:
            return Color(red: 0.58, green: 0.42, blue: 0.72)
        case .night:
            return Color(red: 0.14, green: 0.18, blue: 0.42)
        case .recovery:
            return Color(red: 0.30, green: 0.58, blue: 0.66)
        case .restProtection:
            return Color(red: 0.44, green: 0.34, blue: 0.62)
        case .activity:
            return Color(red: 0.34, green: 0.58, blue: 0.42)
        case .nutrition:
            return Color(red: 0.72, green: 0.50, blue: 0.26)
        }
    }

    /// Barely visible top ambient before Night Comfort scaling.
    var baseIntensity: CGFloat {
        switch self {
        case .morning, .day, .evening, .night:
            return 0.034
        case .recovery, .activity:
            return 0.030
        case .restProtection, .nutrition:
            return 0.038
        }
    }
}
