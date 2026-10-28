import XCTest
@testable import WeekFit

final class PlanRealtimeVoiceTests: XCTestCase {

    func testIdempotencyKeyKeepsASafeCallIdAndHashesTheRest() {
        XCTAssertEqual(planRealtimeIdempotencyKey("call_tennis_1"), "call_tennis_1")
        let hashed = planRealtimeIdempotencyKey("call/with space")
        XCTAssertNotEqual(hashed, "call/with space")
        XCTAssertTrue(hashed.range(of: "^[A-Za-z0-9_-]{8,80}$", options: .regularExpression) != nil)
    }

    func testFailedSaveDoesNotLookLikeSuccess() {
        let rejected = planRealtimeLocalAction(
            saved: false,
            alreadyApplied: false,
            alreadyOnPlan: false,
            error: "time_conflict"
        )
        XCTAssertEqual(rejected, .reject("time_conflict"))
        let reply = planRealtimeToolReply(action: rejected, speak: "Добавил теннис на завтра, с 13 до 14.")
        XCTAssertFalse(reply.ok)
        XCTAssertFalse(reply.saved)
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
}
