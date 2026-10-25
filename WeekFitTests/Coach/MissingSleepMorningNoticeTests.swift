import XCTest
@testable import WeekFit

final class MissingSleepMorningNoticeTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: MissingSleepMorningNoticeStore!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "MissingSleepMorningNoticeTests")!
        defaults.removePersistentDomain(forName: "MissingSleepMorningNoticeTests")
        store = MissingSleepMorningNoticeStore(defaults: defaults)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func testFirstMorningWithoutSleepShowsOnceAndStaysUntilDismissed() {
        var coordinator = MissingSleepMorningNoticeCoordinator(holder: nil, store: store)
        let morning = date(hour: 8)
        var input = confirmedMissing(at: morning)

        XCTAssertEqual(coordinator.phase(for: .today, input: input), .show)
        XCTAssertEqual(coordinator.phase(for: .coach, input: input), .show)

        coordinator.noteAppeared(surface: .today, owner: "local", dayKey: dayKey(morning))
        input.hasShownToday = true

        XCTAssertEqual(coordinator.phase(for: .today, input: input), .show)
        XCTAssertEqual(coordinator.phase(for: .coach, input: input), .hidden)

        coordinator.end(.today)
        XCTAssertEqual(coordinator.phase(for: .today, input: input), .hidden)
        XCTAssertEqual(coordinator.phase(for: .coach, input: input), .hidden)
    }

    func testRestartAndTabChangeDoNotShowAgain() {
        var coordinator = MissingSleepMorningNoticeCoordinator(holder: nil, store: store)
        let morning = date(hour: 9)
        coordinator.noteAppeared(surface: .coach, owner: "apple:user", dayKey: dayKey(morning))
        coordinator.end(.coach)

        let restarted = MissingSleepMorningNoticeCoordinator(holder: nil, store: store)
        var input = confirmedMissing(at: morning)
        input.hasShownToday = restarted.store.hasShown(owner: "apple:user", dayKey: dayKey(morning))

        XCTAssertEqual(restarted.phase(for: .today, input: input), .hidden)
        XCTAssertEqual(restarted.phase(for: .coach, input: input), .hidden)
    }

    func testAfterElevenStartsOnStandardFlow() {
        let input = confirmedMissing(at: date(hour: 11))
        XCTAssertEqual(MissingSleepMorningNoticePolicy.phase(input), .hidden)
    }

    func testCutoffIsElevenLocalAndDoesNotAutoDismissEarly() {
        let morning = date(hour: 8, minute: 30)
        XCTAssertEqual(
            MissingSleepMorningNoticePolicy.secondsUntilCutoff(now: morning, calendar: calendar),
            2.5 * 60 * 60,
            accuracy: 0.5
        )
        XCTAssertEqual(
            MissingSleepMorningNoticePolicy.secondsUntilCutoff(now: date(hour: 10, minute: 59), calendar: calendar),
            60,
            accuracy: 0.5
        )
        XCTAssertEqual(
            MissingSleepMorningNoticePolicy.secondsUntilCutoff(now: date(hour: 11), calendar: calendar),
            0,
            accuracy: 0.5
        )

        var held = confirmedMissing(at: morning)
        held.isHeldOnScreen = true
        XCTAssertEqual(MissingSleepMorningNoticePolicy.phase(held), .show)
    }

    func testOpenAppCrossingElevenHidesHeldNotice() {
        var input = confirmedMissing(at: date(hour: 10, minute: 30))
        input.isHeldOnScreen = true
        XCTAssertEqual(MissingSleepMorningNoticePolicy.phase(input), .show)

        input.now = date(hour: 11)
        XCTAssertEqual(MissingSleepMorningNoticePolicy.phase(input), .hidden)
    }

    func testLateSleepSyncHidesNoticeAndDoesNotRepeat() {
        var coordinator = MissingSleepMorningNoticeCoordinator(holder: nil, store: store)
        let morning = date(hour: 7)
        coordinator.noteAppeared(surface: .today, owner: "local", dayKey: dayKey(morning))

        var withSleep = confirmedMissing(at: morning)
        withSleep.hasSleepRecords = true
        withSleep.hasShownToday = true
        XCTAssertEqual(coordinator.phase(for: .today, input: withSleep), .hidden)

        coordinator.end(.today)
        var stillMissing = confirmedMissing(at: date(hour: 8))
        stillMissing.hasShownToday = true
        XCTAssertEqual(coordinator.phase(for: .today, input: stillMissing), .hidden)
    }

    func testLoadingPermissionAndReadErrorsStayHidden() {
        let morning = date(hour: 8)
        var loading = confirmedMissing(at: morning)
        loading.isLoadingMetrics = true
        loading.hasSettledMetrics = false
        XCTAssertEqual(MissingSleepMorningNoticePolicy.phase(loading), .hidden)

        var denied = confirmedMissing(at: morning)
        denied.isHealthAccessGranted = false
        XCTAssertEqual(MissingSleepMorningNoticePolicy.phase(denied), .hidden)

        var failedRead = confirmedMissing(at: morning)
        failedRead.sleepReadConfirmed = false
        XCTAssertEqual(MissingSleepMorningNoticePolicy.phase(failedRead), .hidden)
    }

    func testNewLocalDayAllowsOneNewShow() {
        let yesterday = date(day: 24, hour: 8)
        store.markShown(owner: "local", dayKey: dayKey(yesterday))

        let today = date(day: 25, hour: 8)
        var input = confirmedMissing(at: today)
        input.hasShownToday = store.hasShown(owner: "local", dayKey: dayKey(today))
        XCTAssertEqual(MissingSleepMorningNoticePolicy.phase(input), .show)
    }

    func testShownStateDoesNotTransferBetweenAccounts() {
        let morning = date(hour: 8)
        store.markShown(owner: "apple:one", dayKey: dayKey(morning))

        var other = confirmedMissing(at: morning)
        other.hasShownToday = store.hasShown(owner: "apple:two", dayKey: dayKey(morning))
        XCTAssertFalse(other.hasShownToday)
        XCTAssertEqual(MissingSleepMorningNoticePolicy.phase(other), .show)
    }

    private func confirmedMissing(at now: Date) -> MissingSleepMorningNoticeInput {
        MissingSleepMorningNoticeInput(
            now: now,
            calendar: calendar,
            isHealthAccessGranted: true,
            hasSettledMetrics: true,
            isLoadingMetrics: false,
            sleepReadConfirmed: true,
            hasSleepRecords: false,
            hasShownToday: false,
            isHeldOnScreen: false
        )
    }

    private func dayKey(_ date: Date) -> String {
        MissingSleepMorningNoticePolicy.dayKey(for: date, calendar: calendar)
    }

    private func date(day: Int = 25, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
}
