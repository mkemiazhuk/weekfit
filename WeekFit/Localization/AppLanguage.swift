import Foundation
internal import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "weekfit.app.language"
    /// Set when the user picks a language in Settings; auto-detect must not override it.
    static let explicitSelectionKey = "weekfit.app.language.explicit"

    case english = "en"
    case russian = "ru"
    case chineseSimplified = "zh-Hans"
    case french = "fr"
    case polish = "pl"
    case spanish = "es"
    case german = "de"
    case japanese = "ja"
    case italian = "it"
    case korean = "ko"

    var id: String { rawValue }

    /// Region-qualified locale for DateFormatter / Calendar (bare `en`/`ru` can mix
    /// device-region weekday symbols with the app language).
    var localeIdentifier: String {
        switch self {
        case .english: return "en_US"
        case .russian: return "ru_RU"
        case .chineseSimplified: return "zh_CN"
        case .french: return "fr_FR"
        case .polish: return "pl_PL"
        case .spanish: return "es_ES"
        case .german: return "de_DE"
        case .japanese: return "ja_JP"
        case .italian: return "it_IT"
        case .korean: return "ko_KR"
        }
    }

    /// Stable Latin badge codes — same in every UI language.
    var shortCode: String {
        switch self {
        case .english: return "EN"
        case .russian: return "RU"
        case .chineseSimplified: return "ZH"
        case .french: return "FR"
        case .polish: return "PL"
        case .spanish: return "ES"
        case .german: return "DE"
        case .japanese: return "JA"
        case .italian: return "IT"
        case .korean: return "KO"
        }
    }

    /// Flag emoji shown on the language picker (region that matches `localeIdentifier`).
    var flagEmoji: String {
        switch self {
        case .english: return "🇺🇸"
        case .russian: return "🇷🇺"
        case .chineseSimplified: return "🇨🇳"
        case .french: return "🇫🇷"
        case .polish: return "🇵🇱"
        case .spanish: return "🇪🇸"
        case .german: return "🇩🇪"
        case .japanese: return "🇯🇵"
        case .italian: return "🇮🇹"
        case .korean: return "🇰🇷"
        }
    }

    /// Full name in the current app UI language.
    var title: LocalizedStringResource {
        switch self {
        case .english:
            return AppText.Settings.Language.Option.english
        case .russian:
            return AppText.Settings.Language.Option.russian
        case .chineseSimplified:
            return AppText.Settings.Language.Option.chineseSimplified
        case .french:
            return AppText.Settings.Language.Option.french
        case .polish:
            return AppText.Settings.Language.Option.polish
        case .spanish:
            return AppText.Settings.Language.Option.spanish
        case .german:
            return AppText.Settings.Language.Option.german
        case .japanese:
            return AppText.Settings.Language.Option.japanese
        case .italian:
            return AppText.Settings.Language.Option.italian
        case .korean:
            return AppText.Settings.Language.Option.korean
        }
    }

    /// First supported tag in the phone language list; otherwise English.
    static func detectedFromDevice(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        for tag in preferredLanguages {
            if let match = matchLanguageTag(tag) {
                return match
            }
        }
        return .english
    }

    /// Match a single BCP-47 / language-code tag (tests + legacy callers).
    static func detectedFromDevice(languageCode: String?) -> AppLanguage {
        guard let languageCode, !languageCode.isEmpty else { return .english }
        return matchLanguageTag(languageCode) ?? .english
    }

    /// `nil` when the tag is unsupported so preferred-language walks can skip to the next.
    static func matchLanguageTag(_ tag: String) -> AppLanguage? {
        let code = tag
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        if code.hasPrefix("ru") { return .russian }
        if code.hasPrefix("pl") { return .polish }
        if code.hasPrefix("fr") { return .french }
        if code.hasPrefix("es") { return .spanish }
        if code.hasPrefix("de") { return .german }
        if code.hasPrefix("ja") { return .japanese }
        if code.hasPrefix("it") { return .italian }
        if code.hasPrefix("ko") { return .korean }
        if code.hasPrefix("en") { return .english }
        if code == "zh"
            || code.hasPrefix("zh-hans")
            || code.hasPrefix("zh-cn")
            || code.hasPrefix("zh-sg") {
            return .chineseSimplified
        }
        // Traditional Chinese and other zh variants fall back to Simplified for now.
        if code.hasPrefix("zh") { return .chineseSimplified }
        return nil
    }

    static var hasExplicitUserSelection: Bool {
        UserDefaults.standard.bool(forKey: explicitSelectionKey)
    }

    static func markExplicitUserSelection() {
        UserDefaults.standard.set(true, forKey: explicitSelectionKey)
    }

    /// Until onboarding finishes (and the user hasn't picked a language), follow the phone.
    static var shouldFollowDeviceLanguage: Bool {
        !hasExplicitUserSelection && !OnboardingStore.hasCompletedOnboarding
    }
}

@MainActor
final class AppLanguageManager: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}
    @Published var selectedLanguage: AppLanguage {
        didSet {
            guard selectedLanguage != oldValue else { return }
            WeekFitSetCurrentLanguage(selectedLanguage)
            MealBuilderTitleComposer.warmCaches(for: selectedLanguage)
        }
    }

    var locale: Locale {
        Locale(identifier: selectedLanguage.localeIdentifier)
    }

    init() {
        let language = Self.resolveLaunchLanguage()
        self.selectedLanguage = language
        WeekFitSetCurrentLanguage(language)
        MealBuilderTitleComposer.warmCaches(for: language)
    }

    /// Re-apply phone language while first-run onboarding is still active.
    func syncWithDeviceLanguageIfNeeded() {
        guard AppLanguage.shouldFollowDeviceLanguage else { return }
        let detected = AppLanguage.detectedFromDevice()
        guard detected != selectedLanguage else { return }
        selectedLanguage = detected
    }

    /// Settings picker — persists as an explicit user choice.
    func selectLanguage(_ language: AppLanguage) {
        AppLanguage.markExplicitUserSelection()
        selectedLanguage = language
    }

    private static func resolveLaunchLanguage() -> AppLanguage {
        #if DEBUG
        if let override = WeekFitUITestSupport.languageOverride() {
            return override
        }
        #endif
        if AppLanguage.shouldFollowDeviceLanguage {
            return AppLanguage.detectedFromDevice()
        }
        if let storedLanguageCode = UserDefaults.standard.string(forKey: AppLanguage.storageKey),
           let storedLanguage = AppLanguage(rawValue: storedLanguageCode) {
            return storedLanguage
        }
        return AppLanguage.detectedFromDevice()
    }
}
