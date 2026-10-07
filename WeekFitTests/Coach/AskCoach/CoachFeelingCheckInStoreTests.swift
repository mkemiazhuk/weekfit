import XCTest
@testable import WeekFit

final class CoachFeelingCheckInStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "CoachFeelingCheckInStoreTests.\(UUID().uuidString)")
        CoachFeelingCheckInStore.useDefaults(defaults)
        CoachFeelingCheckInStore.clear()
    }

    override func tearDown() {
        CoachFeelingCheckInStore.clear()
        CoachFeelingCheckInStore.resetDefaults()
        defaults = nil
        super.tearDown()
    }

    func testUpsertAndLatestForLocalDay() {
        let day1 = date(2026, 4, 15, hour: 8)
        let day1Later = date(2026, 4, 15, hour: 18)
        let day2 = date(2026, 4, 16, hour: 9)

        let first = makeCheckIn(id: "a", at: day1, feeling: .tired)
        let second = makeCheckIn(id: "b", at: day1Later, feeling: .okay)
        let nextDay = makeCheckIn(id: "c", at: day2, feeling: .energized)

        CoachFeelingCheckInStore.upsert(first)
        CoachFeelingCheckInStore.upsert(second)
        CoachFeelingCheckInStore.upsert(nextDay)

        XCTAssertEqual(CoachFeelingCheckInStore.all().count, 3)
        XCTAssertEqual(CoachFeelingCheckInStore.latest(on: day1, calendar: calendar)?.id, "b")
        XCTAssertEqual(CoachFeelingCheckInStore.latest(on: day2, calendar: calendar)?.feeling, .energized)
        XCTAssertTrue(CoachFeelingCheckInStore.hasAnswer(on: day1, calendar: calendar))
    }

    func testNewDayShowsNoAnswerWhileHistoryPreserved() {
        let day1 = date(2026, 4, 15, hour: 10)
        let day2 = date(2026, 4, 16, hour: 10)
        CoachFeelingCheckInStore.upsert(makeCheckIn(id: "a", at: day1, feeling: .tired))

        XCTAssertNotNil(CoachFeelingCheckInStore.latest(on: day1, calendar: calendar))
        XCTAssertNil(CoachFeelingCheckInStore.latest(on: day2, calendar: calendar))
        XCTAssertEqual(CoachFeelingCheckInStore.all().count, 1)
    }

    func testEditAndDelete() {
        let now = date(2026, 4, 15, hour: 11)
        var checkIn = makeCheckIn(id: "edit-me", at: now, feeling: .okay)
        CoachFeelingCheckInStore.upsert(checkIn)

        checkIn.feeling = .tired
        checkIn.outcome = .mixed
        checkIn.updatedAt = date(2026, 4, 15, hour: 12)
        CoachFeelingCheckInStore.upsert(checkIn)

        XCTAssertEqual(CoachFeelingCheckInStore.checkIn(id: "edit-me")?.feeling, .tired)
        XCTAssertTrue(CoachFeelingCheckInStore.delete(id: "edit-me"))
        XCTAssertNil(CoachFeelingCheckInStore.checkIn(id: "edit-me"))
        XCTAssertTrue(CoachFeelingCheckInStore.all().isEmpty)
    }

    // MARK: - Helpers

    private func makeCheckIn(
        id: String,
        at date: Date,
        feeling: CoachFeelingKind
    ) -> CoachFeelingCheckIn {
        CoachFeelingCheckIn(
            id: id,
            createdAt: date,
            updatedAt: date,
            feeling: feeling,
            clarification: nil,
            outcome: .mixed,
            evidence: .empty,
            analysisVersion: CoachFeelingEvidenceRules.analysisVersion,
            followUpAnswers: []
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
