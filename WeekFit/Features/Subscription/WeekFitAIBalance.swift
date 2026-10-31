import Foundation

enum WeekFitAIBalancePack: String, Identifiable, Equatable {
    case time
    case photos

    var id: String { rawValue }

    func matches(_ productID: String) -> Bool {
        switch self {
        case .time: productID.contains("voice")
        case .photos: productID.contains("photos")
        }
    }

    var titleKey: String {
        switch self {
        case .time: "ai.balance.addTime"
        case .photos: "ai.balance.addPhotos"
        }
    }

    var noteKey: String {
        switch self {
        case .time: "ai.balance.purchasedTimeNeverExpires"
        case .photos: "ai.balance.purchasedPhotosNeverExpire"
        }
    }

    var buttonKey: String {
        switch self {
        case .time: "ai.balance.addTimeButton"
        case .photos: "ai.balance.addPhotosButton"
        }
    }

    var introKey: String {
        switch self {
        case .time: "ai.balance.timeIntro"
        case .photos: "ai.balance.photosIntro"
        }
    }

    /// Smaller packs sort first. Unknown products stay after the known catalog.
    static func quantityRank(_ productID: String) -> Int {
        switch productID {
        case "com.weekfit.topup.voice15", "com.weekfit.topup.photos20": 0
        case "com.weekfit.topup.voice30", "com.weekfit.topup.photos50": 1
        default: 2
        }
    }
}

enum WeekFitAIClock {
    static func compact(seconds: Int, locale: Locale) -> String {
        formatted(seconds: seconds, locale: locale, style: .abbreviated)
            .replacingOccurrences(of: ", ", with: " ")
    }

    static func spoken(seconds: Int, locale: Locale) -> String {
        formatted(seconds: seconds, locale: locale, style: .full)
    }

    private static func formatted(seconds: Int, locale: Locale, style: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar
        formatter.unitsStyle = style
        formatter.maximumUnitCount = 2
        let seconds = max(0, seconds)
        if seconds == 0 || seconds.isMultiple(of: 60) {
            formatter.allowedUnits = [.minute]
        } else if seconds >= 60 {
            formatter.allowedUnits = [.minute, .second]
        } else {
            formatter.allowedUnits = [.second]
        }
        return formatter.string(from: TimeInterval(seconds)) ?? "0"
    }
}

struct WeekFitAIBalanceContent: Equatable {
    struct Card: Equatable {
        var symbolName: String
        var title: String
        var hero: String
        var heroIsStatus: Bool
        var heroAccessibility: String
        var caption: String?
        var fractionCaption: String?
        var includedTitle: String
        var includedValue: String?
        var includedAccessibility: String
        var purchasedTitle: String
        var purchasedValue: String?
        var purchasedAccessibility: String
        var note: String
        var action: WeekFitAIBalancePack?
        var showsBreakdown: Bool
    }

    var voice: Card
    var photos: Card
    var renews: String?
    var usedFirst: String
    var accessNote: String?

    static func make(_ usage: WeekFitAIUsage, now: Date = Date(), locale: Locale? = nil) -> WeekFitAIBalanceContent {
        let locale = locale ?? WeekFitCurrentLocale()
        let voiceHold = hold(for: usage)
        let photosUnlimited = unlimitedPhotos(usage)
        let renewal = renewalDate(periodEndMillis: usage.periodEnd, active: usage.active, now: now)
        return WeekFitAIBalanceContent(
            voice: voiceCard(usage, hold: voiceHold, locale: locale),
            photos: photoCard(usage, unlimited: photosUnlimited, locale: locale),
            renews: renewal.map { date in
                let formatted = date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
                return String(format: text("ai.balance.renews", locale), locale: locale, formatted)
            },
            usedFirst: text("ai.balance.usedFirst", locale),
            accessNote: usage.active ? nil : text("ai.usage.subscriptionRequired", locale)
        )
    }

    static func renewalDate(periodEndMillis: Double, active: Bool, now: Date) -> Date? {
        guard active, periodEndMillis > 0 else { return nil }
        let date = Date(timeIntervalSince1970: periodEndMillis / 1000)
        guard date > now else { return nil }
        return date
    }

    static func packTitle(_ productID: String, locale: Locale? = nil) -> String? {
        let locale = locale ?? WeekFitCurrentLocale()
        let key: String? = switch productID {
        case "com.weekfit.topup.photos20": "ai.balance.pack.photos20"
        case "com.weekfit.topup.photos50": "ai.balance.pack.photos50"
        case "com.weekfit.topup.voice15": "ai.balance.pack.voice15"
        case "com.weekfit.topup.voice30": "ai.balance.pack.voice30"
        default: nil
        }
        return key.map { text($0, locale) }
    }

    private static func voiceCard(_ usage: WeekFitAIUsage, hold: VoiceHold, locale: Locale) -> Card {
        let title = text("ai.usage.voice", locale)
        let includedTitle = text("ai.balance.includedWithPremium", locale)
        let purchasedTitle = text("ai.balance.purchasedTime", locale)
        let note = text("ai.balance.purchasedTimeNeverExpires", locale)
        if hold != .none {
            let status = text(hold == .finalizing ? "ai.usage.finalizing" : "ai.balance.voiceHeld", locale)
            return Card(
                symbolName: "waveform",
                title: title,
                hero: status,
                heroIsStatus: true,
                heroAccessibility: status,
                caption: nil,
                fractionCaption: nil,
                includedTitle: includedTitle,
                includedValue: nil,
                includedAccessibility: status,
                purchasedTitle: purchasedTitle,
                purchasedValue: nil,
                purchasedAccessibility: status,
                note: note,
                action: .time,
                showsBreakdown: false
            )
        }
        let remaining = max(0, usage.voice.included)
        let purchased = max(0, usage.voice.purchased)
        let allowance = fractionAllowance(remaining: remaining, limit: usage.limits?.voice)
        let bought = purchasedGrant(
            remaining: purchased,
            includedRemaining: remaining,
            used: usage.voice.used,
            limit: usage.limits?.voice
        )
        let includedValue = fraction(remaining, allowance: allowance, locale: locale, voice: true)
        let purchasedValue = fraction(purchased, allowance: bought, locale: locale, voice: true)
        let hero = WeekFitAIClock.compact(seconds: remaining + purchased, locale: locale)
        let caption = text("ai.balance.availableToUse", locale)
        return Card(
            symbolName: "waveform",
            title: title,
            hero: hero,
            heroIsStatus: false,
            heroAccessibility: "\(WeekFitAIClock.spoken(seconds: remaining + purchased, locale: locale)), \(caption)",
            caption: caption,
            fractionCaption: allowance == nil ? nil : text("ai.balance.remainingIncluded", locale),
            includedTitle: includedTitle,
            includedValue: includedValue,
            includedAccessibility: fractionAccessibility(
                title: includedTitle,
                remaining: remaining,
                allowance: allowance,
                locale: locale,
                voice: true,
                fallback: includedValue
            ),
            purchasedTitle: purchasedTitle,
            purchasedValue: purchasedValue,
            purchasedAccessibility: fractionAccessibility(
                title: purchasedTitle,
                remaining: purchased,
                allowance: bought,
                locale: locale,
                voice: true,
                fallback: purchasedValue,
                phraseKey: "ai.balance.fractionPurchased"
            ),
            note: note,
            action: .time,
            showsBreakdown: true
        )
    }

    private static func photoCard(_ usage: WeekFitAIUsage, unlimited: Bool, locale: Locale) -> Card {
        let title = text("ai.usage.photos", locale)
        let includedTitle = text("ai.balance.includedWithPremium", locale)
        let purchasedTitle = text("ai.balance.purchasedPhotos", locale)
        let note = text("ai.balance.purchasedPhotosNeverExpire", locale)
        let purchased = max(0, usage.photos.purchased)
        let purchasedValue = count(purchased, locale: locale)
        if unlimited {
            let preserved = text("ai.usage.existingAccess", locale)
            let caption = text("ai.balance.photosAvailable", locale)
            return Card(
                symbolName: "camera.fill",
                title: title,
                hero: preserved,
                heroIsStatus: true,
                heroAccessibility: "\(preserved), \(caption)",
                caption: caption,
                fractionCaption: nil,
                includedTitle: includedTitle,
                includedValue: preserved,
                includedAccessibility: "\(includedTitle), \(preserved)",
                purchasedTitle: purchasedTitle,
                purchasedValue: purchasedValue,
                purchasedAccessibility: "\(purchasedTitle), \(purchasedValue)",
                note: note,
                action: nil,
                showsBreakdown: true
            )
        }
        let remaining = max(0, usage.photos.included)
        let allowance = fractionAllowance(remaining: remaining, limit: usage.limits?.photos)
        let includedValue = fraction(remaining, allowance: allowance, locale: locale, voice: false)
        let hero = count(remaining + purchased, locale: locale)
        let caption = text("ai.balance.photosAvailable", locale)
        return Card(
            symbolName: "camera.fill",
            title: title,
            hero: hero,
            heroIsStatus: false,
            heroAccessibility: "\(hero), \(caption)",
            caption: caption,
            fractionCaption: allowance == nil ? nil : text("ai.balance.remainingIncluded", locale),
            includedTitle: includedTitle,
            includedValue: includedValue,
            includedAccessibility: fractionAccessibility(
                title: includedTitle,
                remaining: remaining,
                allowance: allowance,
                locale: locale,
                voice: false,
                fallback: includedValue
            ),
            purchasedTitle: purchasedTitle,
            purchasedValue: purchasedValue,
            purchasedAccessibility: "\(purchasedTitle), \(purchasedValue)",
            note: note,
            action: .photos,
            showsBreakdown: true
        )
    }

    private enum VoiceHold { case none, onCall, finalizing }

    private static func hold(for usage: WeekFitAIUsage) -> VoiceHold {
        if usage.voiceFinalizing { return .finalizing }
        if usage.voice.reserved > 0 { return .onCall }
        return .none
    }

    private static func unlimitedPhotos(_ usage: WeekFitAIUsage) -> Bool {
        if usage.grandfatheredPhotos { return true }
        if let limit = usage.limits?.photos, usage.photos.included > limit { return true }
        return false
    }

    /// Voice `used` is allowance spent plus purchased time spent. That is enough to recover how much was bought.
    /// A total smaller than the remainder means the payload did not account for the spend, so it stays a single number.
    private static func purchasedGrant(remaining: Int, includedRemaining: Int, used: Int, limit: Int?) -> Int? {
        guard let limit, limit > 0, remaining >= 0, used >= 0 else { return nil }
        let includedSpent = max(0, limit - max(0, includedRemaining))
        guard used >= includedSpent else { return nil }
        let granted = remaining + (used - includedSpent)
        guard granted > 0 else { return nil }
        return granted
    }

    private static func fractionAllowance(remaining: Int, limit: Int?) -> Int? {
        guard let limit, limit > 0, remaining >= 0, remaining <= limit else { return nil }
        return limit
    }

    private static func fraction(_ remaining: Int, allowance: Int?, locale: Locale, voice: Bool) -> String {
        let value = voice
            ? WeekFitAIClock.compact(seconds: remaining, locale: locale)
            : count(remaining, locale: locale)
        guard let allowance else { return value }
        let total = voice
            ? WeekFitAIClock.compact(seconds: allowance, locale: locale)
            : count(allowance, locale: locale)
        return "\(value) / \(total)"
    }

    private static func fractionAccessibility(
        title: String,
        remaining: Int,
        allowance: Int?,
        locale: Locale,
        voice: Bool,
        fallback: String,
        phraseKey: String = "ai.balance.fraction"
    ) -> String {
        guard let allowance else { return "\(title), \(fallback)" }
        let left = voice
            ? WeekFitAIClock.spoken(seconds: remaining, locale: locale)
            : count(remaining, locale: locale)
        let total = voice
            ? WeekFitAIClock.spoken(seconds: allowance, locale: locale)
            : count(allowance, locale: locale)
        let phrase = String(
            format: text(phraseKey, locale),
            locale: locale,
            left,
            total
        )
        return "\(title), \(phrase)"
    }

    private static func count(_ value: Int, locale: Locale) -> String {
        value.formatted(.number.locale(locale))
    }

    private static func text(_ key: String, _ locale: Locale) -> String {
        WeekFitLocalizedString(key, locale: locale)
    }
}
