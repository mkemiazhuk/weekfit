import XCTest
@testable import WeekFit

/// Re-runnable integrity checks for Localizable.xcstrings coverage and placeholders.
/// Complements `scripts/audit_localization.py` (run that for full-catalog offline audit).
final class LocalizationCatalogIntegrityTests: XCTestCase {

    private let appLanguages: [AppLanguage] = [
        .english, .russian, .chineseSimplified, .french, .polish,
        .spanish, .german, .japanese, .italian, .korean
    ]

    private let smokeKeys = [
        "today.greeting.morning",
        "today.greeting.afternoon",
        "today.greeting.evening",
        "today.greeting.night",
        "recovery.stressIndex.title",
        "recovery.stressIndex.calculation.bodyFormat",
        "recovery.stressIndex.short.sleep",
        "recovery.stressIndex.short.hrv",
        "healthAccess.signalReadiness",
        "healthAccess.status.minutesAgoFormat",
        "healthAccess.whatThisEnables",
        "healthAccess.action.manage",
        "activity.metric.steps",
        "activity.syncedFrom",
        "activity.route",
        "coach.proposal.chrome.reviewCTA.short",
        "settings.language.title",
        "paywall.restore.noneFound"
    ]

    func testSmokeKeysResolveForEveryAppLanguage() {
        var failures: [String] = []
        for language in appLanguages {
            let locale = Locale(identifier: language.rawValue)
            for key in smokeKeys {
                let value = WeekFitLocalizedString(key, locale: locale)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if value.isEmpty {
                    failures.append("\(language.rawValue) empty \(key)")
                }
                if value == key {
                    failures.append("\(language.rawValue) unresolved key \(key)")
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testStressIndexSleepLabelIsLocalizedOutsideEnglish() {
        let en = WeekFitLocalizedString(
            "recovery.stressIndex.short.sleep",
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(en, "sleep")

        let ko = WeekFitLocalizedString(
            "recovery.stressIndex.short.sleep",
            locale: Locale(identifier: "ko")
        )
        XCTAssertEqual(ko, "수면")

        let de = WeekFitLocalizedString(
            "recovery.stressIndex.short.sleep",
            locale: Locale(identifier: "de")
        )
        XCTAssertEqual(de, "Schlaf")

        let ja = WeekFitLocalizedString(
            "recovery.stressIndex.short.sleep",
            locale: Locale(identifier: "ja")
        )
        XCTAssertEqual(ja, "睡眠")
    }

    func testFormatPlaceholdersMatchEnglishForCriticalKeys() {
        let keys = [
            "recovery.stressIndex.calculation.bodyFormat",
            "healthAccess.status.minutesAgoFormat",
            "healthAccess.status.hoursAgoFormat",
            "activity.syncedFrom",
            "challenge.recovery7.summary.partialHeadline",
            "coach.narrative.activityLoadTodayFormat",
            "onboarding.v12.ready.title.youreReady.named"
        ]
        var failures: [String] = []
        for language in appLanguages where language != .english {
            let locale = Locale(identifier: language.rawValue)
            for key in keys {
                let en = WeekFitLocalizedString(key, locale: Locale(identifier: "en"))
                let tr = WeekFitLocalizedString(key, locale: locale)
                let enPh = Self.placeholders(in: en)
                let trPh = Self.placeholders(in: tr)
                // Positional args may appear in locale-natural order; compare as multisets.
                if Dictionary(grouping: enPh, by: { $0 }).mapValues(\.count)
                    != Dictionary(grouping: trPh, by: { $0 }).mapValues(\.count) {
                    failures.append(
                        "\(language.rawValue) \(key) en=\(enPh) tr=\(trPh)"
                    )
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testGreetingKeysNotHardcodedEnglishWhenLocaleIsGerman() {
        let locale = Locale(identifier: "de")
        XCTAssertEqual(
            WeekFitLocalizedString("today.greeting.morning", locale: locale),
            "Guten Morgen"
        )
        XCTAssertEqual(
            WeekFitLocalizedString("today.greeting.evening", locale: locale),
            "Guten Abend"
        )
    }

    func testKoreanHealthAccessStatusesAreNotPoisonTokens() {
        let locale = Locale(identifier: "ko")
        let ready = WeekFitLocalizedString("healthAccess.status.ready", locale: locale)
        let available = WeekFitLocalizedString("healthAccess.status.available", locale: locale)
        let enables = WeekFitLocalizedString("healthAccess.whatThisEnables", locale: locale)
        XCTAssertNotEqual(ready, "지원하다")
        XCTAssertNotEqual(available, "이용안내")
        XCTAssertFalse(enables.contains("활성화") && enables.count < 4)
        XCTAssertEqual(ready, "준비됨")
        XCTAssertEqual(available, "사용 가능")
        XCTAssertEqual(enables, "활성화되는 기능")
    }

    func testKoreanActivityDetailsIsNotGamingGarbage() {
        let ko = WeekFitLocalizedString(
            "activity.activityDetails",
            locale: Locale(identifier: "ko")
        )
        XCTAssertEqual(ko, "활동 상세")
        XCTAssertFalse(ko.lowercased().contains("game"))
    }

    func testRussianAndPolishQuantityFormsForCriticalCounts() {
        let counts = [0, 1, 2, 5, 11, 12, 13, 14, 21, 22, 25, 101, 111, 112, 113, 114]
        let ru = Locale(identifier: "ru")
        let pl = Locale(identifier: "pl")

        let expectedRU: [Int: String] = [
            0: "0 дней бесплатно",
            1: "1 день бесплатно",
            2: "2 дня бесплатно",
            5: "5 дней бесплатно",
            11: "11 дней бесплатно",
            12: "12 дней бесплатно",
            13: "13 дней бесплатно",
            14: "14 дней бесплатно",
            21: "21 день бесплатно",
            22: "22 дня бесплатно",
            25: "25 дней бесплатно",
            101: "101 день бесплатно",
            111: "111 дней бесплатно",
            112: "112 дней бесплатно",
            113: "113 дней бесплатно",
            114: "114 дней бесплатно"
        ]
        let expectedPL: [Int: String] = [
            0: "0 dni za darmo",
            1: "1 dzień za darmo",
            2: "2 dni za darmo",
            5: "5 dni za darmo",
            11: "11 dni za darmo",
            12: "12 dni za darmo",
            13: "13 dni za darmo",
            14: "14 dni za darmo",
            21: "21 dzień za darmo",
            22: "22 dni za darmo",
            25: "25 dni za darmo",
            101: "101 dzień za darmo",
            111: "111 dni za darmo",
            112: "112 dni za darmo",
            113: "113 dni za darmo",
            114: "114 dni za darmo"
        ]

        for count in counts {
            XCTAssertEqual(
                WeekFitLocalizedQuantityFormat("paywall.plan.trialFormat", count: count, locale: ru),
                expectedRU[count],
                "RU trial \(count)"
            )
            XCTAssertEqual(
                WeekFitLocalizedQuantityFormat("paywall.plan.trialFormat", count: count, locale: pl),
                expectedPL[count],
                "PL trial \(count)"
            )
        }

        XCTAssertEqual(
            WeekFitLocalizedQuantityFormat("common.count.meal", count: 1, locale: ru),
            "1 приём пищи"
        )
        XCTAssertEqual(
            WeekFitLocalizedQuantityFormat("common.count.meal", count: 2, locale: ru),
            "2 приёма пищи"
        )
        XCTAssertEqual(
            WeekFitLocalizedQuantityFormat("common.count.meal", count: 5, locale: ru),
            "5 приёмов пищи"
        )
        XCTAssertEqual(
            WeekFitLocalizedQuantityFormat("common.count.meal", count: 11, locale: ru),
            "11 приёмов пищи"
        )
        XCTAssertEqual(
            WeekFitLocalizedQuantityFormat("common.count.meal", count: 21, locale: ru),
            "21 приём пищи"
        )
        XCTAssertEqual(
            WeekFitLocalizedQuantityFormat("common.count.meal", count: 22, locale: pl),
            "22 posiłki"
        )
        XCTAssertEqual(
            WeekFitLocalizedQuantityFormat("common.count.meal", count: 25, locale: pl),
            "25 posiłków"
        )
        // 111–114 are teens → many (not few), same as 11–14.
        XCTAssertEqual(
            WeekFitLocalizedQuantityFormat("common.count.meal", count: 112, locale: pl),
            "112 posiłków"
        )
        XCTAssertEqual(
            WeekFitLocalizedQuantityFormat("common.count.meal", count: 114, locale: pl),
            "114 posiłków"
        )
    }

    func testGermanAndFrenchQuantityFormatsAreNotEnglishNouns() {
        let de = Locale(identifier: "de")
        let fr = Locale(identifier: "fr")
        let deMeal = WeekFitLocalizedQuantityFormat("common.count.meal", count: 2, locale: de)
        let frMeal = WeekFitLocalizedQuantityFormat("common.count.meal", count: 2, locale: fr)
        XCTAssertTrue(deMeal.contains("Mahlzeit"), deMeal)
        XCTAssertFalse(deMeal.lowercased().contains("meal"), deMeal)
        XCTAssertTrue(frMeal.lowercased().contains("repas"), frMeal)
        XCTAssertFalse(frMeal.lowercased().contains("meal"), frMeal)

        let deTrial = WeekFitLocalizedQuantityFormat("paywall.plan.trialFormat", count: 7, locale: de)
        XCTAssertTrue(deTrial.lowercased().contains("tag"), deTrial)
        XCTAssertFalse(deTrial.lowercased().contains("day"), deTrial)
    }

    func testQuantityFormatFallsBackWhenKeyMissing() {
        let value = WeekFitLocalizedQuantityFormat(
            "localization.test.missing.quantity",
            count: 3,
            locale: Locale(identifier: "de")
        )
        // Unresolved keys return the key name after format attempt — must not crash.
        XCTAssertFalse(value.isEmpty)
    }

    func testPortionsPhraseHandlesFractionalQuantitiesForRussian() {
        let locale = Locale(identifier: "ru")
        let phrase = WeekFitCountPluralization.portionsPhrase(
            quantity: 1.5,
            formattedQuantity: "1.5",
            locale: locale
        )
        // 1.5 rounds to 2 → few form «порции»
        XCTAssertEqual(phrase, "1.5 порции")
        let one = WeekFitCountPluralization.portionsPhrase(
            quantity: 1.0,
            formattedQuantity: "1",
            locale: locale
        )
        XCTAssertEqual(one, "1 порция")
    }

    func testJapaneseTodayTabLabelNoLongerMeansUpdate() {
        let ja = WeekFitLocalizedString("today.title", locale: Locale(identifier: "ja"))
        XCTAssertEqual(ja, "今日")
        XCTAssertFalse(ja.contains("更新"))
    }

    // MARK: - Helpers

    private static func placeholders(in text: String) -> [String] {
        // Mirror scripts/audit_localization.py: ignore %% and digit% literals.
        var s = text.replacingOccurrences(of: "%%", with: "")
        if let regex = try? NSRegularExpression(pattern: #"(?<=\d)%(?!\d|\$|@|[diouxXeEfFgGaAcspnhlqLzjt])"#) {
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
        }
        guard let regex = try? NSRegularExpression(
            pattern: #"%(\d+\$)?[#0\-+]*(\d+)?(\.\d+)?((h|hh|l|ll|q|L|z|t|j)*[diouxXeEfFgGaAcspn@]|@)"#
        ) else {
            return []
        }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return regex.matches(in: s, range: range).compactMap { match in
            Range(match.range, in: s).map { String(s[$0]) }
        }
    }
}
