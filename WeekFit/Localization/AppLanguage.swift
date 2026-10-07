import Foundation
internal import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "weekfit.app.language"

    case english = "en"
    case russian = "ru"
    case chineseSimplified = "zh-Hans"

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .english:
            return AppText.Settings.Language.Option.english
        case .russian:
            return AppText.Settings.Language.Option.russian
        case .chineseSimplified:
            return AppText.Settings.Language.Option.chineseSimplified
        }
    }

    /// Detect preferred app language from the device locale.
    static func detectedFromDevice(languageCode: String? = Locale.current.language.languageCode?.identifier) -> AppLanguage {
        let code = (languageCode ?? "en").lowercased()
        if code.hasPrefix("ru") { return .russian }
        if code == "zh" || code.hasPrefix("zh-hans") || code.hasPrefix("zh_hans") || code.hasPrefix("zh-cn") {
            return .chineseSimplified
        }
        // Traditional Chinese and other zh variants fall back to Simplified for now.
        if code.hasPrefix("zh") { return .chineseSimplified }
        return .english
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

        let detected = AppLanguage.detectedFromDevice()
        self.selectedLanguage = detected
        WeekFitSetCurrentLanguage(detected)
        UserDefaults.standard.set(detected.rawValue, forKey: AppLanguage.storageKey)
    }
}
