import XCTest
@testable import WeekFit

final class AskCoachPeriodCalculatorTests: XCTestCase {

    func testLast7DaysEndsOnReferenceDayInclusive() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!

        let range = AskCoachPeriodCalculator.range(
            length: .last7Days,
            endingOn: reference,
            calendar: calendar,
            timeZone: calendar.timeZone
        )

        XCTAssertEqual(range.dayCount, 7)
        XCTAssertEqual(range.dayStarts.count, 7)
        XCTAssertEqual(range.endInclusive, calendar.startOfDay(for: reference))
        XCTAssertEqual(
            range.start,
            calendar.date(byAdding: .day, value: -6, to: range.endInclusive)
        )
    }

    func testPreviousPeriodIsEqualLengthWithoutOverlap() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        let reference = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 15))!

        let current = AskCoachPeriodCalculator.range(
            length: .last28Days,
            endingOn: reference,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        let previous = AskCoachPeriodCalculator.previousRange(
            for: current,
            calendar: calendar,
            timeZone: calendar.timeZone
        )

        XCTAssertEqual(previous.dayCount, 28)
        XCTAssertEqual(previous.dayCount, current.dayCount)

        let dayAfterPrevious = calendar.date(byAdding: .day, value: 1, to: previous.endInclusive)
        XCTAssertEqual(dayAfterPrevious, current.start)

        let overlap = Set(previous.dayStarts).intersection(Set(current.dayStarts))
        XCTAssertTrue(overlap.isEmpty)
    }

    func testTimezoneUsesProvidedCalendarDayBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // 2026-04-10 01:30 UTC is still 2026-04-09 in LA.
        let utc = TimeZone(secondsFromGMT: 0)!
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = utc
        let instant = utcCalendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 1, minute: 30))!

        let range = AskCoachPeriodCalculator.range(
            length: .last7Days,
            endingOn: instant,
            calendar: calendar,
            timeZone: calendar.timeZone
        )

        let endKey = CoachDailyObservation.dayKey(for: range.endInclusive, calendar: calendar)
        XCTAssertEqual(endKey, "2026-04-09")
    }
}
