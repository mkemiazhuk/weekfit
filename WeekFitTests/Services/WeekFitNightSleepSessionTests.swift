import XCTest
@testable import WeekFit

final class WeekFitNightSleepSessionTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 2 * 3600)! // CEST-like
        calendar = cal
    }

    func testNightWindowIsLocal2100To0900() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        let night = WeekFitNightSleepSession.nightWindow(for: day, calendar: calendar)

        let expectedStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 21))!
        let expectedEnd = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 9))!

        XCTAssertEqual(night.start, expectedStart)
        XCTAssertEqual(night.end, expectedEnd)
    }

    func testDaytimeNapOutsideNightWindowIsIgnored() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        let night = WeekFitNightSleepSession.nightWindow(for: day, calendar: calendar)

        let napStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 14))!
        let napEnd = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 16))!

        let session = WeekFitNightSleepSession.primarySession(
            inBedSpans: [(napStart, napEnd)],
            asleepSpans: [(napStart, napEnd)],
            night: night
        )

        XCTAssertNil(session)
    }

    /// Regression: long awakening then continued sleep until morning must stay one night.
    func testLongAwakeningKeepsMorningContinuationInsideNightWindow() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        let night = WeekFitNightSleepSession.nightWindow(for: day, calendar: calendar)

        // Bout A ~21:35–01:48
        let aStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 21, minute: 35))!
        let aEnd = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 1, minute: 48))!

        // Gap ~2h37 awake (no inBed)

        // Bout B ~04:25–07:00
        let bStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 4, minute: 25))!
        let bEnd = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 7))!

        let session = WeekFitNightSleepSession.primarySession(
            inBedSpans: [(aStart, aEnd), (bStart, bEnd)],
            asleepSpans: [(aStart, aEnd), (bStart, bEnd)],
            night: night
        )

        XCTAssertEqual(session?.start, aStart)
        XCTAssertEqual(session?.end, bEnd)

        let durationHours = (session?.duration ?? 0) / 3600
        XCTAssertGreaterThan(durationHours, 8) // wall span across both bouts
        XCTAssertLessThan(durationHours, 12)
    }

    func testThreeShortAwakeningsStayOneNight() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        let night = WeekFitNightSleepSession.nightWindow(for: day, calendar: calendar)

        let spans: [(Date, Date)] = [
            (
                calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 22))!,
                calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 23, minute: 30))!
            ),
            (
                calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 0))!,
                calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 2))!
            ),
            (
                calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 2, minute: 20))!,
                calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 5))!
            ),
            (
                calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 5, minute: 15))!,
                calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 7, minute: 30))!
            )
        ]

        let session = WeekFitNightSleepSession.primarySession(
            inBedSpans: spans,
            asleepSpans: [],
            night: night
        )

        XCTAssertEqual(session?.start, spans.first?.0)
        XCTAssertEqual(session?.end, spans.last?.1)
    }

    func testSpansClippedToNightBounds() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        let night = WeekFitNightSleepSession.nightWindow(for: day, calendar: calendar)

        let earlyStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 19))!
        let lateEnd = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 10))!

        let session = WeekFitNightSleepSession.primarySession(
            inBedSpans: [(earlyStart, lateEnd)],
            asleepSpans: [],
            night: night
        )

        XCTAssertEqual(session?.start, night.start) // clipped to 21:00
        XCTAssertEqual(session?.end, night.end) // clipped to 09:00
    }
}
