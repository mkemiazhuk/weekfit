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
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}
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
        if let storedLanguageCode = UserDefaults.standard.string(forKey: AppLanguage.storageKey),
           let storedLanguage = AppLanguage(rawValue: storedLanguageCode) {
            self.selectedLanguage = storedLanguage
            WeekFitSetCurrentLanguage(storedLanguage)
            return
        }

        let deviceCode = Locale.current.language.languageCode?.identifier ?? "en"
        let detected: AppLanguage = deviceCode.hasPrefix("ru") ? .russian : .english
        self.selectedLanguage = detected
        WeekFitSetCurrentLanguage(detected)
        UserDefaults.standard.set(detected.rawValue, forKey: AppLanguage.storageKey)
    }
}
