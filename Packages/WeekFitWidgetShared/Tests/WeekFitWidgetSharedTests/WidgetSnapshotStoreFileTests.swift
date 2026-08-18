import XCTest
@testable import WeekFitWidgetShared

final class WidgetSnapshotStoreFileTests: XCTestCase {
    func testPlaceholderEmptyIsCodableAndStaleAware() throws {
        let past = Date().addingTimeInterval(-7 * 60 * 60)
        let snap = WeekFitWidgetSnapshot.placeholderEmpty(now: past)
        XCTAssertEqual(snap.dayMode, .empty)
        XCTAssertTrue(snap.isStale)
        XCTAssertFalse(snap.hasNextAction)

        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(WeekFitWidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded.dateKey, snap.dateKey)
        XCTAssertEqual(decoded.schemaVersion, WeekFitWidgetSnapshot.currentSchemaVersion)
    }

    func testYesterdaySnapshotIsNotUsedForTodayTimeline() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 21))!
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 8))!
        let loaded = WeekFitWidgetSnapshot.placeholderEmpty(now: yesterday)
        let resolved = WeekFitWidgetTimelineResolver.snapshot(loaded: loaded, now: today, calendar: calendar)
        XCTAssertEqual(resolved.dateKey, "2026-08-18")
        XCTAssertEqual(resolved.dayMode, .empty)
        XCTAssertTrue(resolved.dayGuidance.isEmpty)
    }

    func testDayKeyFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = DateComponents(calendar: calendar, year: 2026, month: 8, day: 11)
        let date = calendar.date(from: comps)!
        XCTAssertEqual(WeekFitWidgetSnapshot.dayKey(for: date, calendar: calendar), "2026-08-11")
    }
}
