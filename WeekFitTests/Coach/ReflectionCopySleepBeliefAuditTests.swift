import XCTest
@testable import WeekFit

/// Localization and tone audit for sleep-belief reflection copy.
final class ReflectionCopySleepBeliefAuditTests: XCTestCase {

    private let sleepBeliefIDs: [CoachBeliefID] = [
        .sleepConsistencyRecovery,
        .sleepDurationRecovery,
        .lateBedtimeRecovery,
    ]

    private let operationalPhrases = [
        "you should",
        "tonight",
        "recommend",
        "make sure",
        "try to",
        "need to",
        "сегодня вечером",
        "рекомендую",
        "нужно",
        "следует",
    ]

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testEmergingCopyExistsInEnglishAndRussianForAllSleepBeliefs() {
        for beliefID in sleepBeliefIDs {
            let event = UnderstandingEvent.make(
                beliefID: beliefID,
                change: .emerged,
                maturity: .emerging
            )

            let english = localizedMessage(for: event, language: .english)
            let russian = localizedMessage(for: event, language: .russian)

            XCTAssertFalse(english.isEmpty, beliefID.rawValue)
            XCTAssertFalse(russian.isEmpty, beliefID.rawValue)
            XCTAssertNotEqual(
                english,
                fallbackEnglish,
                "Unexpected fallback copy for \(beliefID.rawValue)"
            )
        }
    }

    func testEstablishedCopyExistsInEnglishAndRussianForAllSleepBeliefs() {
        for beliefID in sleepBeliefIDs {
            let event = UnderstandingEvent.make(
                beliefID: beliefID,
                change: .strengthened,
                maturity: .established
            )

            let english = localizedMessage(for: event, language: .english)
            let russian = localizedMessage(for: event, language: .russian)

            XCTAssertFalse(english.isEmpty, beliefID.rawValue)
            XCTAssertFalse(russian.isEmpty, beliefID.rawValue)
            XCTAssertTrue(
                english.localizedCaseInsensitiveContains("confident")
                    || english.localizedCaseInsensitiveContains("more confident"),
                beliefID.rawValue
            )
            XCTAssertTrue(
                russian.localizedCaseInsensitiveContains("уверен"),
                beliefID.rawValue
            )
        }
    }

    func testSleepBeliefCopySoundsLikeQuietReflectionNotOperationalAdvice() {
        for beliefID in sleepBeliefIDs {
            let emerging = UnderstandingEvent.make(
                beliefID: beliefID,
                change: .emerged,
                maturity: .emerging
            )

            let english = localizedMessage(for: emerging, language: .english).lowercased()
            let russian = localizedMessage(for: emerging, language: .russian).lowercased()

            XCTAssertTrue(
                english.contains("notic") || english.contains("started"),
                beliefID.rawValue
            )
            XCTAssertTrue(
                russian.contains("замеча"),
                beliefID.rawValue
            )

            for phrase in operationalPhrases {
                XCTAssertFalse(english.contains(phrase), "\(beliefID.rawValue) EN contains '\(phrase)'")
                XCTAssertFalse(russian.contains(phrase), "\(beliefID.rawValue) RU contains '\(phrase)'")
            }
        }
    }

    // MARK: - Helpers

    private var fallbackEnglish: String {
        "I've learned something new about how your body responds over time."
    }

    private func localizedMessage(for event: UnderstandingEvent, language: AppLanguage) -> String {
        WeekFitSetCurrentLanguage(language)
        return ReflectionCopy.message(for: event)
    }
}
