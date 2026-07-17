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
    case nutritionGoal
    case healthAccess
    case units
    case account
    case help
    case terms
    case appleHealth
}

enum ProfileDestination: Identifiable {
    case notifications
    case language
    case nightComfort
    case nutritionGoal
    case healthAccess
    case account
    case helpSupport
    case termsPrivacy
    case editName

    var id: String {
        switch self {
        case .notifications: return "notifications"
        case .language: return "language"
        case .nightComfort: return "nightComfort"
        case .nutritionGoal: return "nutritionGoal"
        case .healthAccess: return "healthAccess"
        case .account: return "account"
        case .helpSupport: return "helpSupport"
        case .termsPrivacy: return "termsPrivacy"
        case .editName: return "editName"
        }
    }
}
