import XCTest
@testable import WeekFit

final class CoachCopyClosureTimingTests: XCTestCase {

    func testRestOfDayGuardStartsAtEveningNotBefore() {
        XCTAssertFalse(CoachCopyClosureTiming.allowsRestOfDayPhrasing(.morning))
        XCTAssertFalse(CoachCopyClosureTiming.allowsRestOfDayPhrasing(.midday))
        XCTAssertFalse(CoachCopyClosureTiming.allowsRestOfDayPhrasing(.afternoon))
        XCTAssertTrue(CoachCopyClosureTiming.allowsRestOfDayPhrasing(.evening))
        XCTAssertTrue(CoachCopyClosureTiming.allowsRestOfDayPhrasing(.lateEvening))
    }

    func testDayClosureGuardStartsAtWindDownNotAtEvening() {
        XCTAssertFalse(CoachCopyClosureTiming.allowsDayClosurePhrasing(timeOfDay: .evening))
        XCTAssertTrue(CoachCopyClosureTiming.allowsDayClosurePhrasing(timeOfDay: .lateEvening))
        XCTAssertTrue(CoachCopyClosureTiming.allowsDayClosurePhrasing(timeOfDay: .night))
    }

    func testEveningAllowsRestOfDayButNotDayClosure() {
        XCTAssertTrue(CoachCopyClosureTiming.allowsRestOfDayPhrasing(.evening))
        XCTAssertFalse(CoachCopyClosureTiming.allowsDayClosurePhrasing(timeOfDay: .evening))
    }

    func testDayClosingPhaseAllowsClosureBeforeWindDownClock() {
        XCTAssertTrue(
            CoachCopyClosureTiming.allowsDayClosurePhrasing(
                timeOfDay: .afternoon,
                conversationPhase: .dayClosing
            )
        )
    }
}

final class CoachConversationTimingAuditTests: XCTestCase {

    func testBeforeEveningBlacklist() {
        let phrases = CoachConversationTimingAudit.forbiddenPhrases(
            in: "Остаток дня спокойный — вечер без нагрузки, перед сном отдых.",
            timeOfDay: .afternoon
        )
        XCTAssertTrue(phrases.contains("остаток дня"))
        XCTAssertTrue(phrases.contains("вечер"))
        XCTAssertTrue(phrases.contains("перед сном"))
    }

    func testBeforeWindDownBlacklist() {
        let phrases = CoachConversationTimingAudit.forbiddenPhrases(
            in: "На сегодня достаточно — плотный день позади, можно завершить день.",
            timeOfDay: .evening
        )
        XCTAssertTrue(phrases.contains("на сегодня достаточно"))
        XCTAssertTrue(phrases.contains("плотный день позади"))
        XCTAssertTrue(phrases.contains("завершить день"))
        XCTAssertFalse(phrases.contains("остаток дня"))
    }

    func testActivityPastTenseDoesNotTriggerDayClosureBlacklist() {
        let phrases = CoachConversationTimingAudit.forbiddenPhrases(
            in: "Игровой день позади — вечер для восстановления.",
            timeOfDay: .evening
        )
        XCTAssertTrue(phrases.isEmpty)
    }

    func testEveningAllowsRestOfDayPhrasesInAudit() {
        let phrases = CoachConversationTimingAudit.forbiddenPhrases(
            in: "Остаток дня спокойный — вечер без спешки.",
            timeOfDay: .evening
        )
        XCTAssertTrue(phrases.isEmpty)
    }

    func testWindDownAllowsClosurePhrasesInAudit() {
        let phrases = CoachConversationTimingAudit.forbiddenPhrases(
            in: "На сегодня достаточно — день можно завершить спокойно.",
            timeOfDay: .lateEvening
        )
        XCTAssertTrue(phrases.isEmpty)
    }

    func testBaselinePacksPassConversationTimingAudit() {
        var failures: [String] = []

        for scenario in CoachScenarioKey.allCases {
            let input = CoachCopyQualityTests.baselineInput(for: scenario)
            guard let pack = CoachCopyRegistry.resolve(input) else { continue }
            let report = CoachConversationTimingAudit.audit(pack: pack, input: input)
            if !report.isClean {
                let line = "\(scenario.rawValue) @ \(input.timeOfDay.rawValue): " +
                    report.findings.map { "\($0.section) \($0.phrase)" }.joined(separator: ", ")
                failures.append(line)
            }
        }

        for failure in failures {
            XCTFail(failure)
        }
    }
}
