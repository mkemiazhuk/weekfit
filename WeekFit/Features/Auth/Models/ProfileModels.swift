import Foundation

struct UserProfile {
    var initials: String
    var fullName: String
    var email: String
}

struct ProfileItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let type: ProfileItemType
}

enum ProfileItemType {
    case notifications
    case language
    case nightComfort
    case healthAccess
    case units
    case privacy
    case help
    case terms
    case appleHealth
}

enum ProfileDestination: Identifiable {
    case notifications
    case language
    case nightComfort
    case healthAccess
    case privacy
    case helpSupport
    case termsPrivacy
    case editProfile

    var id: String {
        switch self {
        case .notifications: return "notifications"
        case .language: return "language"
        case .nightComfort: return "nightComfort"
        case .healthAccess: return "healthAccess"
        case .privacy: return "privacy"
        case .helpSupport: return "helpSupport"
        case .termsPrivacy: return "termsPrivacy"
        case .editProfile: return "editProfile"
        }
    }
}
