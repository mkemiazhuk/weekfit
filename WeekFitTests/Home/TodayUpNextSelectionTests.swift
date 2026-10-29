import XCTest
@testable import WeekFit

final class TodayUpNextSelectionTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
    }

    func testChoosesNearestLaterEventOnTheSameLocalDay() {
        let now = date(hour: 15, minute: 0)
        let walk = candidate("walk", hour: 16, minute: 15)
        let sauna = candidate("sauna", hour: 18, minute: 0)
        let id = TodayUpNextSelection.nextID(
            among: [sauna, walk],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(id, "walk")
    }

    func testExcludesCompletedCancelledAndAlreadyStartedEvents() {
        let now = date(hour: 15, minute: 0)
        let completed = candidate("done", hour: 16, minute: 0, isCompleted: true)
        let cancelled = candidate("cancelled", hour: 16, minute: 30, isSkipped: true)
        let started = candidate("started", hour: 14, minute: 0)
        let id = TodayUpNextSelection.nextID(
            among: [completed, cancelled, started],
            now: now,
            calendar: calendar
        )
        XCTAssertNil(id)
    }

    func testTomorrowDoesNotQualifyAsUpNextToday() {
        let now = date(hour: 15, minute: 0)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date(hour: 9, minute: 0))!
        let id = TodayUpNextSelection.nextID(
            among: [TodayUpNextCandidate(id: "tomorrow", date: tomorrow, isCompleted: false, isSkipped: false)],
            now: now,
            calendar: calendar
        )
        XCTAssertNil(id)
    }

    private func date(hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: hour, minute: minute))!
    }

    private func candidate(
        _ id: String,
        hour: Int,
        minute: Int,
        isCompleted: Bool = false,
        isSkipped: Bool = false
    ) -> TodayUpNextCandidate {
        TodayUpNextCandidate(
            id: id,
            date: date(hour: hour, minute: minute),
            isCompleted: isCompleted,
            isSkipped: isSkipped
        )
    }
}
