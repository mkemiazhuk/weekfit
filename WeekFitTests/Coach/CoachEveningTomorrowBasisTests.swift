import XCTest
import WeekFitPlanner
@testable import WeekFit

@MainActor
final class CoachEveningTomorrowBasisTests: XCTestCase {
    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func local(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int,
        calendar: Calendar
    ) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        parts.timeZone = calendar.timeZone
        return calendar.date(from: parts)!
    }

    private func activity(
        id: String,
        type: String = "running",
        title: String = "Run",
        date: Date,
        minutes: Int = 40,
        skipped: Bool = false
    ) -> PlannedActivity {
        PlannedActivity(
            id: id,
            date: date,
            type: type,
            title: title,
            durationMinutes: minutes,
            icon: "figure.run",
            colorRed: 0,
            colorGreen: 0,
            colorBlue: 0,
            isSkipped: skipped
        )
    }

    private func summary(today: String, tomorrow: String) -> CoachEveningSummary {
        CoachEveningSummary(
            headline: "Evening",
            today: .init(text: today, evidenceIds: []),
            now: .init(text: today, evidenceIds: []),
            tomorrow: .init(text: tomorrow, evidenceIds: []),
            limitations: [],
            day: "2026-10-29",
            locale: "en",
            generatedAt: "2026-10-29T18:00:00Z",
            source: "ai"
        )
    }

    func testTomorrowUsesTheNextLocalCalendarDay() {
        let warsaw = calendar("Europe/Warsaw")
        let evening = local(2026, 10, 29, 21, 0, calendar: warsaw)
        let lateToday = activity(id: "late", date: local(2026, 10, 29, 23, 30, calendar: warsaw))
        let afterMidnight = activity(id: "midnight", date: local(2026, 10, 30, 0, 10, calendar: warsaw))
        let endOfTomorrow = activity(id: "evening", date: local(2026, 10, 30, 23, 50, calendar: warsaw))
        let dayAfter = activity(id: "later", date: local(2026, 10, 31, 0, 5, calendar: warsaw))

        let basis = CoachEveningTomorrowBasis.capture(
            activities: [lateToday, afterMidnight, endOfTomorrow, dayAfter],
            now: evening,
            calendar: warsaw
        )

        XCTAssertEqual(basis.day, "2026-10-30")
        XCTAssertEqual(basis.timeZoneIdentifier, "Europe/Warsaw")
        XCTAssertEqual(Set(basis.events.map(\.id)), ["midnight", "evening"])
        XCTAssertFalse(basis.assertedEmpty)
    }

    func testTimezoneChangesWhichLocalDayOwnsTheEvent() {
        let warsaw = calendar("Europe/Warsaw")
        let utc = calendar("UTC")
        let evening = local(2026, 10, 29, 21, 0, calendar: warsaw)
        let justAfterWarsawMidnight = activity(
            id: "run",
            date: local(2026, 10, 30, 0, 10, calendar: warsaw)
        )

        let inWarsaw = CoachEveningTomorrowBasis.capture(
            activities: [justAfterWarsawMidnight],
            now: evening,
            calendar: warsaw
        )
        let inUTC = CoachEveningTomorrowBasis.capture(
            activities: [justAfterWarsawMidnight],
            now: evening,
            calendar: utc
        )

        XCTAssertEqual(inWarsaw.events.map(\.id), ["run"])
        XCTAssertTrue(inUTC.events.isEmpty)
        XCTAssertTrue(inUTC.assertedEmpty)
    }

    func testReplacingOrDeletingTheRunHidesTheDependentSentence() {
        let warsaw = calendar("Europe/Warsaw")
        let evening = local(2026, 10, 29, 20, 30, calendar: warsaw)
        let run = activity(id: "run", date: local(2026, 10, 30, 7, 0, calendar: warsaw))
        let basis = CoachEveningTomorrowBasis.capture(activities: [run], now: evening, calendar: warsaw)
        let stored = summary(
            today: "Keep tonight quiet and get to bed on time.",
            tomorrow: "Tomorrow keep the planned run and leave out any extra intensity."
        )

        let replaced = activity(
            id: "cycle",
            type: "cycling",
            title: "Ride",
            date: local(2026, 10, 30, 7, 0, calendar: warsaw)
        )
        let afterReplace = CoachEveningSummaryPolicy.resolvedNote(
            from: stored, basis: basis, activities: [replaced], calendar: warsaw
        )
        XCTAssertTrue(afterReplace.planChanged)
        XCTAssertNil(afterReplace.tomorrow)
        XCTAssertEqual(afterReplace.today, "Keep tonight quiet and get to bed on time.")

        let afterDelete = CoachEveningSummaryPolicy.resolvedNote(
            from: stored, basis: basis, activities: [], calendar: warsaw
        )
        XCTAssertTrue(afterDelete.planChanged)
        XCTAssertNil(afterDelete.tomorrow)
        XCTAssertFalse(afterDelete.today.isEmpty)
    }

    func testTimeDurationAndLocalDateChangesMakeTheRecommendationStale() {
        let warsaw = calendar("Europe/Warsaw")
        let evening = local(2026, 10, 29, 20, 30, calendar: warsaw)
        let run = activity(id: "run", date: local(2026, 10, 30, 7, 0, calendar: warsaw), minutes: 40)
        let basis = CoachEveningTomorrowBasis.capture(activities: [run], now: evening, calendar: warsaw)

        let later = activity(id: "run", date: local(2026, 10, 30, 8, 15, calendar: warsaw), minutes: 40)
        XCTAssertFalse(basis.stillMatches(activities: [later], calendar: warsaw))

        let shorter = activity(id: "run", date: local(2026, 10, 30, 7, 0, calendar: warsaw), minutes: 20)
        XCTAssertFalse(basis.stillMatches(activities: [shorter], calendar: warsaw))

        let moved = activity(id: "run", date: local(2026, 10, 31, 7, 0, calendar: warsaw), minutes: 40)
        XCTAssertFalse(basis.stillMatches(activities: [moved], calendar: warsaw))

        let cancelled = activity(
            id: "run",
            date: local(2026, 10, 30, 7, 0, calendar: warsaw),
            minutes: 40,
            skipped: true
        )
        XCTAssertFalse(basis.stillMatches(activities: [cancelled], calendar: warsaw))
    }

    func testAnUnrelatedEventLeavesTheRecommendationInPlace() {
        let warsaw = calendar("Europe/Warsaw")
        let evening = local(2026, 10, 29, 20, 30, calendar: warsaw)
        let run = activity(id: "run", date: local(2026, 10, 30, 7, 0, calendar: warsaw))
        let basis = CoachEveningTomorrowBasis.capture(activities: [run], now: evening, calendar: warsaw)
        let stored = summary(
            today: "Keep tonight quiet and get to bed on time.",
            tomorrow: "Tomorrow keep the planned run and leave out any extra intensity."
        )

        let todayWalk = activity(
            id: "walk",
            type: "walking",
            title: "Walk",
            date: local(2026, 10, 29, 18, 0, calendar: warsaw),
            minutes: 15
        )
        let addedYoga = activity(
            id: "yoga",
            type: "yoga",
            title: "Yoga",
            date: local(2026, 10, 30, 18, 0, calendar: warsaw),
            minutes: 25
        )
        let note = CoachEveningSummaryPolicy.resolvedNote(
            from: stored,
            basis: basis,
            activities: [run, todayWalk, addedYoga],
            calendar: warsaw
        )
        XCTAssertFalse(note.planChanged)
        XCTAssertEqual(
            note.tomorrow,
            "Tomorrow keep the planned run and leave out any extra intensity."
        )
        XCTAssertEqual(note.today, "Keep tonight quiet and get to bed on time.")
    }

    func testAddingAPlanInvalidatesAnEmptyTomorrowBasis() {
        let warsaw = calendar("Europe/Warsaw")
        let evening = local(2026, 10, 29, 20, 30, calendar: warsaw)
        let basis = CoachEveningTomorrowBasis.capture(activities: [], now: evening, calendar: warsaw)
        XCTAssertTrue(basis.assertedEmpty)
        let run = activity(id: "run", date: local(2026, 10, 30, 7, 0, calendar: warsaw))
        XCTAssertFalse(basis.stillMatches(activities: [run], calendar: warsaw))
        XCTAssertTrue(basis.stillMatches(activities: [], calendar: warsaw))
    }

    func testOlderCacheWithoutABasisHidesTomorrowAndKeepsToday() throws {
        let summary = summary(
            today: "Keep tonight quiet and get to bed on time.",
            tomorrow: "Tomorrow keep the planned run and leave out any extra intensity."
        )
        let cache = CoachEveningSummaryStore.LastingCache(
            summary: summary,
            receivedAt: Date(timeIntervalSince1970: 1_761_700_000),
            inputFingerprint: "day:2026-10-29:en"
        )
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(cache)) as! [String: Any]
        object.removeValue(forKey: "tomorrowBasis")
        let decoded = try JSONDecoder().decode(
            CoachEveningSummaryStore.LastingCache.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertNil(decoded.tomorrowBasis)
        XCTAssertEqual(decoded.summary.tomorrow.text, summary.tomorrow.text)

        let note = CoachEveningSummaryPolicy.resolvedNote(
            from: decoded.summary,
            basis: decoded.tomorrowBasis,
            activities: [],
            calendar: calendar("Europe/Warsaw")
        )
        XCTAssertTrue(note.planChanged)
        XCTAssertNil(note.tomorrow)
        XCTAssertEqual(note.today, "Keep tonight quiet and get to bed on time.")
    }

    func testPlanEditLanguageChangeAndRelaunchKeepASingleProviderCall() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = CoachEveningSummaryStore(directory: directory)
        var calls = 0
        let warsaw = calendar("Europe/Warsaw")
        let evening = local(2026, 10, 12, 20, 30, calendar: warsaw)
        let run = activity(id: "run", date: local(2026, 10, 13, 7, 0, calendar: warsaw))
        let basis = CoachEveningTomorrowBasis.capture(activities: [run], now: evening, calendar: warsaw)
        let today = "Keep tonight quiet and get to bed on time."
        let tomorrow = "Tomorrow keep the planned run and leave out any extra intensity."

        let coordinator = CoachEveningSummaryCoordinator(store: store, generate: { input, _ in
            calls += 1
            return CoachEveningSummaryGenerationResult(
                summary: CoachEveningSummary(
                    headline: "Evening",
                    today: .init(text: today, evidenceIds: ["sleep.duration"]),
                    now: .init(text: today, evidenceIds: ["sleep.duration"]),
                    tomorrow: .init(text: tomorrow, evidenceIds: []),
                    limitations: [],
                    day: input.day,
                    locale: input.locale,
                    generatedAt: "2026-10-12T18:30:00Z",
                    source: "ai"
                ),
                requestId: "req-1"
            )
        })
        let request = CoachEveningSummaryInput(
            schemaVersion: 1,
            day: "2026-10-12",
            timezone: "Europe/Warsaw",
            locale: "en",
            phase: "evening",
            facts: ["sleep": [.init(id: "sleep.duration", text: "6 hours")]]
        )
        coordinator.ensureUpToDate(
            input: request,
            owner: "local",
            fingerprint: "day:2026-10-12:en",
            tomorrowBasis: basis,
            now: evening,
            calendar: warsaw,
            isStillEligible: { true }
        )
        for _ in 0..<40 where coordinator.summary == nil { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(
            coordinator.resolvedNote(activities: [run], calendar: warsaw)?.tomorrow,
            tomorrow
        )

        let moved = activity(id: "run", date: local(2026, 10, 13, 9, 0, calendar: warsaw))
        let changedBasis = CoachEveningTomorrowBasis.capture(
            activities: [moved],
            now: evening,
            calendar: warsaw
        )
        coordinator.ensureUpToDate(
            input: request,
            owner: "local",
            fingerprint: "day:2026-10-12:en",
            tomorrowBasis: changedBasis,
            now: evening,
            calendar: warsaw,
            isStillEligible: { true }
        )
        let russian = CoachEveningSummaryInput(
            schemaVersion: 1,
            day: "2026-10-12",
            timezone: "Europe/Warsaw",
            locale: "ru",
            phase: "evening",
            facts: request.facts
        )
        coordinator.ensureUpToDate(
            input: russian,
            owner: "local",
            fingerprint: "day:2026-10-12:ru",
            tomorrowBasis: changedBasis,
            now: evening,
            calendar: warsaw,
            isStillEligible: { true }
        )
        coordinator.refresh(
            input: russian,
            owner: "local",
            tomorrowBasis: changedBasis,
            now: evening,
            calendar: warsaw
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertNotNil(try store.record(owner: "local", day: "2026-10-12"))
        let stale = coordinator.resolvedNote(activities: [moved], calendar: warsaw)
        XCTAssertEqual(stale?.today, today)
        XCTAssertNil(stale?.tomorrow)
        XCTAssertEqual(stale?.planChanged, true)

        var relaunchCalls = 0
        let relaunched = CoachEveningSummaryCoordinator(store: store, generate: { input, _ in
            relaunchCalls += 1
            return CoachEveningSummaryGenerationResult(
                summary: CoachEveningSummary(
                    headline: "Should not run",
                    today: .init(text: today, evidenceIds: ["sleep.duration"]),
                    now: .init(text: today, evidenceIds: ["sleep.duration"]),
                    tomorrow: .init(text: tomorrow, evidenceIds: []),
                    limitations: [],
                    day: input.day,
                    locale: input.locale,
                    generatedAt: "2026-10-12T18:30:00Z",
                    source: "ai"
                ),
                requestId: "req-relaunch"
            )
        })
        relaunched.restore(owner: "local", now: evening, calendar: warsaw)
        XCTAssertEqual(relaunchCalls, 0)
        XCTAssertEqual(calls, 1)
        let restored = relaunched.resolvedNote(activities: [moved], calendar: warsaw)
        XCTAssertEqual(restored?.today, today)
        XCTAssertNil(restored?.tomorrow)
        XCTAssertEqual(restored?.planChanged, true)
        let unchanged = relaunched.resolvedNote(activities: [run], calendar: warsaw)
        XCTAssertEqual(unchanged?.tomorrow, tomorrow)
        XCTAssertEqual(unchanged?.planChanged, false)
    }
}
