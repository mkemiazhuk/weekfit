import XCTest
@testable import WeekFit

final class PlanVoiceCommandTests: XCTestCase {

    func testTennisTomorrowAtOneForSixtyMinutes() {
        let calendar = makeCalendar("Europe/Moscow")
        let now = makeDate(calendar, 2026, 10, 28, 9, 0)
        let interpreted = PlanVoiceCommandInterpreter.interpret(
            transcript: "Давай запланируем на завтра теннис, 60 минут, в 13:00",
            now: now,
            calendar: calendar,
            planningDay: now
        )

        guard case .ready(let request) = interpreted.result else {
            return XCTFail("expected a ready activity, got \(interpreted.result)")
        }
        XCTAssertEqual(request.catalogTitle, "Tennis")
        XCTAssertEqual(request.durationMinutes, 60)
        XCTAssertEqual(request.start, makeDate(calendar, 2026, 10, 29, 13, 0))
        XCTAssertEqual(
            PlanVoiceCommandInterpreter.endDate(start: request.start, durationMinutes: 60, calendar: calendar),
            makeDate(calendar, 2026, 10, 29, 14, 0)
        )
        XCTAssertEqual(
            PlanVoiceCommandInterpreter.dayRelation(start: request.start, now: now, calendar: calendar),
            .tomorrow
        )
        XCTAssertEqual(PlanVoiceCommandInterpreter.clock(request.start, calendar: calendar), "13:00")
        XCTAssertEqual(
            PlanVoiceCommandInterpreter.clock(
                PlanVoiceCommandInterpreter.endDate(start: request.start, durationMinutes: 60, calendar: calendar),
                calendar: calendar
            ),
            "14:00"
        )
    }

    func testMissingTimeKeepsContextUntilTheFollowUp() {
        let calendar = makeCalendar("Europe/Moscow")
        let now = makeDate(calendar, 2026, 10, 28, 9, 0)
        let first = PlanVoiceCommandInterpreter.interpret(
            transcript: "Запланируй теннис завтра на час",
            now: now,
            calendar: calendar,
            planningDay: now
        )
        guard case .needsDetail(.startTime, _) = first.result else {
            return XCTFail("expected a time question")
        }

        let second = PlanVoiceCommandInterpreter.interpret(
            transcript: "в 13:00",
            now: now,
            calendar: calendar,
            planningDay: now,
            pending: first.pending
        )
        guard case .ready(let request) = second.result else {
            return XCTFail("expected the follow-up to finish the command")
        }
        XCTAssertEqual(request.catalogTitle, "Tennis")
        XCTAssertEqual(request.durationMinutes, 60)
        XCTAssertEqual(request.start, makeDate(calendar, 2026, 10, 29, 13, 0))
    }

    func testRelativeDayUsesTheUserTimeZone() {
        let tokyo = makeCalendar("Asia/Tokyo")
        let now = makeDate(tokyo, 2026, 10, 29, 1, 30)
        let interpreted = PlanVoiceCommandInterpreter.interpret(
            transcript: "теннис послезавтра в час дня на полтора часа",
            now: now,
            calendar: tokyo,
            planningDay: now
        )
        guard case .ready(let request) = interpreted.result else {
            return XCTFail("expected a ready activity")
        }
        XCTAssertEqual(request.durationMinutes, 90)
        XCTAssertEqual(request.start, makeDate(tokyo, 2026, 10, 31, 13, 0))
        XCTAssertEqual(
            PlanVoiceCommandInterpreter.dayRelation(start: request.start, now: now, calendar: tokyo),
            .dayAfterTomorrow
        )
    }

    func testEnglishTimePhrasesFinishThePendingActivity() {
        let calendar = makeCalendar("Europe/Moscow")
        let now = makeDate(calendar, 2026, 10, 28, 9, 0)
        let phrases = ["10 AM", "10 a.m.", "At 10", "They said at 10", "at ten", "ten am"]
        for phrase in phrases {
            let first = PlanVoiceCommandInterpreter.interpret(
                transcript: "Stretching",
                now: now,
                calendar: calendar,
                planningDay: now
            )
            guard case .needsDetail(.startTime, _) = first.result else {
                return XCTFail("expected a time question before \(phrase)")
            }
            let second = PlanVoiceCommandInterpreter.interpret(
                transcript: phrase,
                now: now,
                calendar: calendar,
                planningDay: now,
                pending: first.pending
            )
            guard case .ready(let request) = second.result else {
                return XCTFail("\(phrase) did not set a time, got \(second.result)")
            }
            XCTAssertEqual(request.catalogTitle, "Stretching", phrase)
            XCTAssertEqual(request.durationMinutes, 20, phrase)
            XCTAssertEqual(request.start, makeDate(calendar, 2026, 10, 28, 10, 0), phrase)
        }

        let evening = PlanVoiceCommandInterpreter.interpret(
            transcript: "Stretching",
            now: now,
            calendar: calendar,
            planningDay: now
        )
        let atTenPM = PlanVoiceCommandInterpreter.interpret(
            transcript: "at 10 pm",
            now: now,
            calendar: calendar,
            planningDay: now,
            pending: evening.pending
        )
        guard case .ready(let request) = atTenPM.result else {
            return XCTFail("expected 10 pm to be 22:00")
        }
        XCTAssertEqual(request.start, makeDate(calendar, 2026, 10, 28, 22, 0))
    }

    @MainActor
    func testUnclearTimeReplyDoesNotRepeatTheSameQuestion() {
        let calendar = makeCalendar("Europe/Moscow")
        let now = makeDate(calendar, 2026, 10, 28, 9, 0)
        let controller = PlanVoiceCommandController()
        controller.submit(transcript: "Stretching", now: now, calendar: calendar, planningDay: now)
        XCTAssertEqual(controller.turns.last?.text, PlanVoiceCommandCopy.question(for: .startTime))

        controller.submit(
            transcript: "What's wrong with you",
            now: now,
            calendar: calendar,
            planningDay: now
        )
        XCTAssertNil(controller.readyRequest())
        XCTAssertEqual(controller.turns.last?.text, PlanVoiceCommandCopy.askTimeAgain)
        XCTAssertTrue(controller.listensForReply)

        controller.submit(transcript: "10 AM", now: now, calendar: calendar, planningDay: now)
        guard let request = controller.readyRequest() else {
            return XCTFail("expected 10 AM to finish stretching")
        }
        XCTAssertEqual(request.catalogTitle, "Stretching")
        XCTAssertEqual(request.start, makeDate(calendar, 2026, 10, 28, 10, 0))
    }

    func testSilenceDoesNotStartATurnUntilTheWordsChange() {
        var gate = PlanVoiceSilenceGate()
        XCTAssertNil(gate.note("   "))
        XCTAssertEqual(gate.note("теннис"), 1)
        XCTAssertNil(gate.note("теннис"))
        XCTAssertNil(gate.note("  теннис  "))
        XCTAssertEqual(gate.note("теннис завтра"), 2)
    }

    @MainActor
    func testDialogueAsksThenConfirmsOnlyAfterSave() {
        let calendar = makeCalendar("Europe/Moscow")
        let now = makeDate(calendar, 2026, 10, 28, 9, 0)
        let controller = PlanVoiceCommandController()

        controller.submit(
            transcript: "Запланируй теннис завтра на час",
            now: now,
            calendar: calendar,
            planningDay: now
        )
        XCTAssertNil(controller.readyRequest())
        XCTAssertTrue(controller.listensForReply)
        XCTAssertEqual(controller.turns.map(\.speaker), [.person, .assistant])
        XCTAssertEqual(controller.turns.last?.text, PlanVoiceCommandCopy.question(for: .startTime))

        controller.submit(
            transcript: "в 13:00",
            now: now,
            calendar: calendar,
            planningDay: now
        )
        guard let request = controller.readyRequest() else {
            return XCTFail("expected the reply to finish the command")
        }
        XCTAssertEqual(controller.turns.filter { $0.speaker == .assistant }.count, 1)
        controller.noteSaved(request, now: now, calendar: calendar)
        XCTAssertFalse(controller.listensForReply)
        XCTAssertEqual(
            controller.turns.last?.text,
            PlanVoiceCommandCopy.confirmation(for: request, now: now, calendar: calendar)
        )
        XCTAssertEqual(controller.turns.map(\.speaker), [.person, .assistant, .person, .assistant])
    }

    func testUnspokenDurationUsesThePlannerDefault() {
        let calendar = makeCalendar("Europe/Moscow")
        let now = makeDate(calendar, 2026, 10, 28, 9, 0)
        let interpreted = PlanVoiceCommandInterpreter.interpret(
            transcript: "теннис завтра в 13:00",
            now: now,
            calendar: calendar,
            planningDay: now
        )
        guard case .ready(let request) = interpreted.result else {
            return XCTFail("expected a ready activity")
        }
        XCTAssertEqual(request.durationMinutes, 45)
    }

    @MainActor
    func testSaveFailureCanBeRetriedAndDoesNotCreateADuplicate() {
        let calendar = makeCalendar("Europe/Moscow")
        let now = makeDate(calendar, 2026, 10, 28, 9, 0)
        let controller = PlanVoiceCommandController()
        let phrase = "Давай запланируем на завтра теннис, 60 минут, в 13:00"

        controller.submit(transcript: phrase, now: now, calendar: calendar, planningDay: now)
        let first = controller.readyRequest()
        XCTAssertEqual(first?.catalogTitle, "Tennis")

        controller.noteSaveFailed(canRetry: true)
        XCTAssertTrue(controller.canRetrySave)
        XCTAssertEqual(controller.retryRequest()?.idempotencyKey, first?.idempotencyKey)

        guard let saved = first else { return XCTFail("missing request") }
        controller.noteSaved(saved, now: now, calendar: calendar)
        XCTAssertEqual(controller.phase, .succeeded(PlanVoiceCommandCopy.confirmation(for: saved, now: now, calendar: calendar)))

        controller.submit(transcript: phrase, now: now, calendar: calendar, planningDay: now)
        XCTAssertNil(controller.readyRequest())
    }

    @MainActor
    func testRepeatingOneCommandDoesNotProduceASecondSave() {
        let calendar = makeCalendar("Europe/Moscow")
        let now = makeDate(calendar, 2026, 10, 28, 9, 0)
        let controller = PlanVoiceCommandController()
        let phrase = "Давай запланируем на завтра теннис, 60 минут, в 13:00"

        controller.submit(transcript: phrase, now: now, calendar: calendar, planningDay: now)
        let request = controller.readyRequest()
        controller.submit(transcript: phrase, now: now, calendar: calendar, planningDay: now)
        XCTAssertEqual(controller.readyRequest()?.idempotencyKey, request?.idempotencyKey)

        guard let request else { return XCTFail("missing request") }
        controller.noteSaved(request, now: now, calendar: calendar)
        controller.submit(transcript: phrase, now: now, calendar: calendar, planningDay: now)
        XCTAssertNil(controller.readyRequest())
    }

    private func makeCalendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func makeDate(
        _ calendar: Calendar,
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> Date {
        var parts = DateComponents()
        parts.calendar = calendar
        parts.timeZone = calendar.timeZone
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        return parts.date!
    }
}
