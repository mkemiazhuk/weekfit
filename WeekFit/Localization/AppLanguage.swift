import Foundation
internal import Combine

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

@MainActor
final class AppLanguageManager: ObservableObject {
    @Published var selectedLanguage: AppLanguage {
        didSet {
            guard selectedLanguage != oldValue else { return }
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: AppLanguage.storageKey)
            WeekFitSetCurrentLanguage(selectedLanguage)
        }
    }

    var locale: Locale {
        Locale(identifier: selectedLanguage.localeIdentifier)
    }

    init() {
        let storedLanguageCode = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
            ?? AppLanguage.english.rawValue
        let storedLanguage = AppLanguage(rawValue: storedLanguageCode) ?? .english
        self.selectedLanguage = storedLanguage
        WeekFitSetCurrentLanguage(storedLanguage)
    }
}
