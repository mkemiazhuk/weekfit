import XCTest
@testable import WeekFit

final class PlanRealtimeVoiceTests: XCTestCase {

    func testIdempotencyKeyKeepsASafeCallIdAndHashesTheRest() {
        XCTAssertEqual(planRealtimeIdempotencyKey("call_tennis_1"), "call_tennis_1")
        let hashed = planRealtimeIdempotencyKey("call/with space")
        XCTAssertNotEqual(hashed, "call/with space")
        XCTAssertTrue(hashed.range(of: "^[A-Za-z0-9_-]{8,80}$", options: .regularExpression) != nil)
    }

    func testMayaConfirmsAChangeInTheFeminineAndDoesNotConfirmAConflict() {
        XCTAssertEqual(
            planRealtimeMovedSpeak(spoken: "растяжку", day: "сегодня", time: "18:00", language: "ru"),
            "Перенесла растяжку на сегодня, на 18:00."
        )
        XCTAssertEqual(
            planRealtimeRemovedSpeak(spoken: "прогулку", day: "сегодня", language: "ru"),
            "Убрала прогулку на сегодня."
        )
        XCTAssertEqual(
            planRealtimePlanNotice("conflict", language: "ru"),
            "На это время уже что-то стоит. Выберем другое?"
        )
        let conflict = planRealtimeToolReply(
            action: .reject("time_conflict"),
            speak: planRealtimePlanNotice("conflict", language: "ru")
        )
        XCTAssertFalse(conflict.saved)
        XCTAssertFalse(conflict.ok)
    }

    func testFailedSaveDoesNotLookLikeSuccess() {
        let rejected = planRealtimeLocalAction(
            saved: false,
            alreadyApplied: false,
            alreadyOnPlan: false,
            error: "time_conflict"
        )
        XCTAssertEqual(rejected, .reject("time_conflict"))
        let conflict = planRealtimeToolReply(action: rejected, speak: "Это время уже занято.")
        XCTAssertFalse(conflict.ok)
        XCTAssertFalse(conflict.saved)
        XCTAssertEqual(conflict.speak, "Это время уже занято.")

        let failed = planRealtimeLocalAction(
            saved: false,
            alreadyApplied: false,
            alreadyOnPlan: false,
            error: "save_failed"
        )
        let reply = planRealtimeToolReply(action: failed, speak: "Добавил теннис на завтра, с 13 до 14.")
        XCTAssertFalse(reply.ok)
        XCTAssertNil(reply.speak)
    }

    func testRepeatedCallDoesNotInsertTwice() {
        var gate = PlanRealtimeCallGate()
        XCTAssertEqual(gate.begin("call_tennis_1"), .start)
        XCTAssertEqual(gate.begin("call_tennis_1"), .wait)
        gate.finish("call_tennis_1", reply: #"{"ok":true,"saved":true}"#)
        XCTAssertEqual(gate.begin("call_tennis_1"), .replay(#"{"ok":true,"saved":true}"#))

        let again = planRealtimeLocalAction(
            saved: true,
            alreadyApplied: true,
            alreadyOnPlan: false,
            error: nil
        )
        XCTAssertEqual(again, .alreadyPresent)
        let reply = planRealtimeToolReply(action: again, speak: "Добавил теннис на завтра, с 13 до 14.")
        XCTAssertTrue(reply.saved)
        XCTAssertEqual(reply.speak, "Добавил теннис на завтра, с 13 до 14.")
    }

    func testUnknownResultIsLookedUpBeforeAnotherPost() {
        XCTAssertEqual(planRealtimeTransportStep(transportFailed: true, lookedUp: false), .lookup)
        XCTAssertEqual(planRealtimeTransportStep(transportFailed: false, lookedUp: true), .post)
        XCTAssertEqual(planRealtimeTransportStep(transportFailed: true, lookedUp: true), .post)
        let onPlan = planRealtimeLocalAction(
            saved: true,
            alreadyApplied: false,
            alreadyOnPlan: true,
            error: nil
        )
        XCTAssertEqual(onPlan, .alreadyPresent)
    }

    func testDraftReadsTheToolArguments() {
        let draft = planRealtimeDraft(#"{"catalogTitle":"Tennis","date":"2026-10-29","startTime":"13:00","durationMinutes":60}"#)
        XCTAssertEqual(draft, PlanRealtimeActivityDraft(
            catalogTitle: "Tennis",
            date: "2026-10-29",
            startTime: "13:00",
            durationMinutes: 60
        ))
        XCTAssertNil(planRealtimeDraft("{}"))
    }

    func testAgendaKeepsTodayDoneAndTomorrowPlanned() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        let today = date(2026, 10, 28, 20, 0, calendar)
        let sources = [
            source("meal", "Lunch", date(2026, 10, 28, 13, 0, calendar), completed: true, voice: false),
            source("done", "Tennis", date(2026, 10, 28, 13, 0, calendar), completed: true, voice: true),
            source("later", "Walk", date(2026, 10, 28, 18, 0, calendar), completed: false, voice: true),
            source("next", "Tennis", date(2026, 10, 29, 13, 0, calendar), completed: false, voice: true),
            source("skip", "Yoga", date(2026, 10, 29, 9, 0, calendar), completed: false, voice: true, skipped: true),
        ]
        var book = PlanRealtimeRefBook()
        let rows = planRealtimeAgenda(sources, now: today, calendar: calendar, book: &book) { $0 }
        XCTAssertEqual(rows.map(\.ref), ["a1", "a2", "a3"])
        XCTAssertEqual(rows.map(\.scope), ["today_done", "today_planned", "tomorrow"])
        XCTAssertEqual(rows[2].startTime, "13:00")
        let again = planRealtimeAgenda(sources, now: today, calendar: calendar, book: &book) { $0 }
        XCTAssertEqual(again.map(\.ref), ["a1", "a2", "a3"])
    }

    func testPlanSpeechListsTomorrowAndAMove() {
        XCTAssertEqual(
            planRealtimeListSpeak(scope: "tomorrow", items: [], language: "ru"),
            "На завтра ничего не запланировано."
        )
        XCTAssertEqual(
            planRealtimeListSpeak(
                scope: "today_done",
                items: [(spoken: "теннис", startTime: "13:00")],
                language: "ru"
            ),
            "Сегодня сделано: теннис 13:00"
        )
        XCTAssertEqual(
            planRealtimeMovedSpeak(spoken: "теннис", day: "завтра", time: "15:00", language: "ru"),
            "Перенесла теннис на завтра, на 15:00."
        )
        XCTAssertEqual(
            planRealtimeEditDraft(#"{"ref":"a1","date":"2026-10-29","startTime":"15:00","durationMinutes":0,"catalogTitle":""}"#)?.ref,
            "a1"
        )
        XCTAssertEqual(planRealtimeListScope(#"{"scope":"today_done"}"#), "today_done")
        XCTAssertNil(planRealtimeDeleteRef(#"{"ref":"tennis"}"#))
    }

    func testDayStringUsesTheCalendarZone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var parts = DateComponents()
        parts.calendar = calendar
        parts.timeZone = calendar.timeZone
        parts.year = 2026
        parts.month = 10
        parts.day = 29
        parts.hour = 1
        parts.minute = 30
        let date = parts.date!
        XCTAssertEqual(planRealtimeDayString(date, calendar: calendar), "2026-10-29")
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        var utcParts = DateComponents()
        utcParts.calendar = utc
        utcParts.timeZone = utc.timeZone
        utcParts.year = 2026
        utcParts.month = 10
        utcParts.day = 29
        utcParts.hour = 10
        XCTAssertEqual(planRealtimeInstant("2026-10-29T10:00:00.000Z"), utcParts.date)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ calendar: Calendar) -> Date {
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

    private func source(
        _ id: String,
        _ title: String,
        _ date: Date,
        completed: Bool,
        voice: Bool,
        skipped: Bool = false
    ) -> PlanRealtimeSourceActivity {
        PlanRealtimeSourceActivity(
            id: id,
            title: title,
            date: date,
            durationMinutes: 60,
            completed: completed,
            skipped: skipped,
            voice: voice
        )
    }

    func testUsageBalanceDecodesReservedAndUsedTime() throws {
        let settled = """
        {"appAccountToken":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE","active":true,
         "productId":"com.weekfit.subscription.monthly","periodStart":1,"periodEnd":2,
         "grandfatheredPhotos":false,
         "photos":{"included":30,"purchased":0},"voice":{"included":260,"purchased":0,"reserved":0,"used":40},
         "voiceFinalizing":false}
        """
        let usage = try JSONDecoder().decode(WeekFitAIUsage.self, from: Data(settled.utf8))
        XCTAssertEqual(usage.voice.included, 260)
        XCTAssertEqual(usage.voice.used, 40)
        XCTAssertEqual(usage.voice.reserved, 0)
        XCTAssertFalse(usage.voiceFinalizing)
        let legacy = """
        {"appAccountToken":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE","active":true,
         "productId":"com.weekfit.subscription.monthly","periodStart":1,"periodEnd":2,
         "grandfatheredPhotos":false,"photos":{"included":30,"purchased":0},"voice":{"included":0,"purchased":0}}
        """
        let older = try JSONDecoder().decode(WeekFitAIUsage.self, from: Data(legacy.utf8))
        XCTAssertEqual(older.voice.reserved, 0)
        XCTAssertFalse(older.voiceFinalizing)
    }

    func testFailedVoiceStopStaysPendingAndRetryDoesNotOpenAnotherCall() async {
        let suiteName = "WeekFitVoiceStopTests"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        let previous = WeekFitVoiceStopLedger.defaults
        WeekFitVoiceStopLedger.defaults = suite
        defer { WeekFitVoiceStopLedger.defaults = previous }
        let probe = StopProbe()
        await WeekFitVoiceStopQueue.shared.setTransport { sessionId in
            if probe.record(sessionId) { throw URLError(.networkConnectionLost) }
        }
        defer { Task { await WeekFitVoiceStopQueue.shared.resetTransport() } }
        let sessionId = "voice_stop_test_1"
        await WeekFitVoiceStopQueue.shared.enqueue(sessionId)
        XCTAssertEqual(WeekFitVoiceStopLedger.pending(), [sessionId])
        XCTAssertEqual(probe.calls, [sessionId])
        probe.fail = false
        await WeekFitVoiceStopQueue.shared.flush()
        XCTAssertTrue(WeekFitVoiceStopLedger.pending().isEmpty)
        await WeekFitVoiceStopQueue.shared.flush()
        XCTAssertEqual(probe.calls, [sessionId, sessionId])
        await WeekFitVoiceStopQueue.shared.resetTransport()
    }
}

private final class StopProbe: @unchecked Sendable {
    let lock = NSLock()
    var calls: [String] = []
    var fail = true

    func record(_ sessionId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        calls.append(sessionId)
        return fail
    }
}
