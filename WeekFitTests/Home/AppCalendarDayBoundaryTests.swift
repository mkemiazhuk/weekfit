import XCTest
@testable import WeekFit

final class AppCalendarDayBoundaryTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        return calendar
    }

    private func date(day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = day
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)!
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "weekfit_last_active_calendar_day_start")
        super.tearDown()
    }

    func testFirstPersistedLaunchDoesNotReportRollover() {
        let now = date(day: 25, hour: 9)

        let rollover = AppCalendarDayBoundary.detectPersistedRollover(now: now, calendar: calendar)

        XCTAssertNil(rollover)
        XCTAssertEqual(
            AppCalendarDayBoundary.loadPersistedDayStart(),
            calendar.startOfDay(for: now)
        )
    }

    func testPersistedRolloverDetectsNextCalendarDay() {
        let yesterday = date(day: 25, hour: 22)
        AppCalendarDayBoundary.persistDayStart(calendar.startOfDay(for: yesterday))

        let todayMorning = date(day: 26, hour: 7)
        let rollover = AppCalendarDayBoundary.detectPersistedRollover(
            now: todayMorning,
            calendar: calendar
        )

        XCTAssertEqual(
            rollover?.previousDayStart,
            calendar.startOfDay(for: yesterday)
        )
        XCTAssertEqual(
            rollover?.newDayStart,
            calendar.startOfDay(for: todayMorning)
        )
    }

    func testRepeatedCheckSameDayDoesNotReportRollover() {
        let morning = date(day: 26, hour: 7)
        _ = AppCalendarDayBoundary.detectPersistedRollover(now: morning, calendar: calendar)

        let afternoon = date(day: 26, hour: 15)
        let rollover = AppCalendarDayBoundary.detectPersistedRollover(
            now: afternoon,
            calendar: calendar
        )

        XCTAssertNil(rollover)
    }
}
