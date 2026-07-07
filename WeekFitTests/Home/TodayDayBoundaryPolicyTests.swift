import XCTest
@testable import WeekFit

final class TodayDayBoundaryPolicyTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        return calendar
    }

    private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }

    func testFirstLaunchDoesNotForceHealthRefresh() {
        let now = date(day: 25, hour: 9)
        let output = TodayDayBoundaryPolicy.reconcile(
            TodayDayBoundaryPolicy.Input(
                now: now,
                selectedDate: now,
                trackedDayStart: nil,
                calendar: calendar
            )
        )

        XCTAssertFalse(output.didCrossBoundary)
        XCTAssertFalse(output.shouldRefreshHealth)
        XCTAssertEqual(output.trackedDayStart, calendar.startOfDay(for: now))
    }

    func testDayBoundaryAdvancesSelectedDateWhenViewingToday() {
        let yesterday = date(day: 25, hour: 22)
        let todayMorning = date(day: 26, hour: 7)
        let tracked = calendar.startOfDay(for: yesterday)

        let output = TodayDayBoundaryPolicy.reconcile(
            TodayDayBoundaryPolicy.Input(
                now: todayMorning,
                selectedDate: yesterday,
                trackedDayStart: tracked,
                calendar: calendar
            )
        )

        XCTAssertTrue(output.didCrossBoundary)
        XCTAssertTrue(output.shouldRefreshHealth)
        XCTAssertTrue(calendar.isDate(output.selectedDate, inSameDayAs: todayMorning))
    }

    func testDayBoundaryPreservesHistoricalSelectedDate() {
        let historical = date(day: 20, hour: 12)
        let todayMorning = date(day: 26, hour: 7)
        let tracked = calendar.startOfDay(for: date(day: 25, hour: 12))

        let output = TodayDayBoundaryPolicy.reconcile(
            TodayDayBoundaryPolicy.Input(
                now: todayMorning,
                selectedDate: historical,
                trackedDayStart: tracked,
                calendar: calendar
            )
        )

        XCTAssertTrue(output.didCrossBoundary)
        XCTAssertTrue(output.shouldRefreshHealth)
        XCTAssertEqual(output.selectedDate, historical)
    }

    func testNextBoundaryIsStartOfNextDay() {
        let now = date(day: 25, hour: 23, minute: 30)
        let next = TodayDayBoundaryPolicy.nextBoundary(after: now, calendar: calendar)
        XCTAssertEqual(next, date(day: 26, hour: 0))
    }
}
