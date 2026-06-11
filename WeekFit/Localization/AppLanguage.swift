import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "weekfit.app.language"

    case english = "en"
    case russian = "ru"

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .english:
            return AppText.Settings.Language.Option.english
        case .russian:
            return AppText.Settings.Language.Option.russian
        }
    }
}
