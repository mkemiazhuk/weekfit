import XCTest
@testable import WeekFit

final class CoachWeeklyContextTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return c
    }
    private func context(missing: Bool = false) -> CoachWeeklyContext {
        let end = ISO8601DateFormatter().date(from: "2026-10-26T12:00:00Z")!
        let days = (0..<35).map { i -> CoachWeeklyContext.Day in
            let date = calendar.date(byAdding: .day, value: i - 34, to: end)!
            return .init(day: CoachEveningSummaryPolicy.dayKey(date, calendar: calendar), complete: i < 34,
                sleepMinutes: missing ? nil : (i < 28 ? 480 : 420),
                bedStart: nil, wakeTime: nil, awakeMinutes: nil, awakenings: nil,
                deepMinutes: nil, remMinutes: nil,
                hrv: missing ? nil : (i < 28 ? 40 : 30), hrvSamples: missing ? 0 : 2, hrvMeasuredAt: nil,
                rhr: missing ? nil : 60, rhrSamples: missing ? 0 : 1, rhrMeasuredAt: nil,
                activeKcal: nil, exerciseMinutes: nil)
        }
        return CoachWeeklyContext(days: days, sessions: [], calendar: calendar)
    }
    func testRecentWindowAndBaselineAreDisjointAcrossDST() {
        let facts = context().facts()
        XCTAssertEqual(facts["recentSleep"]?.count, 7)
        XCTAssertTrue(facts["recentSleep"]!.first!.text.contains("2026-10-20"))
        XCTAssertTrue(facts["recentSleep"]!.last!.text.contains("2026-10-26"))
        let baseline = facts["baseline"]!.first { $0.id == "baseline.sleepMinutes" }!
        XCTAssertTrue(baseline.text.contains("median=480.0"))
        XCTAssertTrue(baseline.text.contains("28/28"))
        let activityDays = facts["recentActivity"]!.filter { $0.id.hasPrefix("history.activity.") }
        XCTAssertTrue(activityDays.last!.text.contains("complete=false"))
    }
    func testMissingReadingsDoNotBecomeZero() {
        let facts = context(missing: true).facts()
        XCTAssertTrue(facts["recentSleep"]!.allSatisfy { $0.text.contains("asleep=unknown") })
        let activityDays = facts["recentActivity"]!.filter { $0.id.hasPrefix("history.activity.") }
        XCTAssertEqual(activityDays.count, 7)
        XCTAssertTrue(activityDays.allSatisfy { $0.text.contains("energy=unknown") })
        XCTAssertTrue(facts["baseline"]!.first { $0.id == "baseline.hrvSDNN" }!.text.contains("median=unknown"))
    }
    func testEvidenceFitsServerEnvelope() {
        let facts = context().facts()
        let rows = facts.values.flatMap { $0 }
        XCTAssertTrue(facts.values.allSatisfy { $0.count <= 40 })
        XCTAssertTrue(rows.allSatisfy { $0.text.count <= 500 && $0.id.count <= 80 })
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
    }

    func testSessionBudgetMarksTruncationWithoutDroppingDaySummaries() {
        let end = ISO8601DateFormatter().date(from: "2026-10-26T12:00:00Z")!
        let days = (0..<35).map { i -> CoachWeeklyContext.Day in
            let date = calendar.date(byAdding: .day, value: i - 34, to: end)!
            return .init(
                day: CoachEveningSummaryPolicy.dayKey(date, calendar: calendar),
                complete: i < 34,
                sleepMinutes: 420,
                bedStart: nil, wakeTime: nil, awakeMinutes: nil, awakenings: nil,
                deepMinutes: nil, remMinutes: nil,
                hrv: 40, hrvSamples: 2, hrvMeasuredAt: nil,
                rhr: 60, rhrSamples: 1, rhrMeasuredAt: nil,
                activeKcal: 500, exerciseMinutes: 30
            )
        }
        let sessions = (0..<30).map { i in
            let start = calendar.date(byAdding: .hour, value: -i, to: end)!
            return CoachWeeklyContext.Session(
                type: "Running",
                start: start,
                end: start.addingTimeInterval(1800),
                minutes: 30
            )
        }
        let facts = CoachWeeklyContext(days: days, sessions: sessions, calendar: calendar).facts()
        let activity = facts["recentActivity"]!
        XCTAssertEqual(activity.filter { $0.id.hasPrefix("history.activity.") }.count, 7)
        XCTAssertTrue(activity.contains { $0.id == "history.sessionsCoverage" && $0.text.contains("truncated=true") })
        XCTAssertEqual(activity.filter { $0.id.hasPrefix("history.session.") }.count, CoachWeeklyContext.maxIncludedSessions)
        XCTAssertLessThanOrEqual(activity.count, 40)
        XCTAssertTrue(facts["baseline"]!.contains { $0.id == "baseline.hrvSDNN.daily" })
    }
}
