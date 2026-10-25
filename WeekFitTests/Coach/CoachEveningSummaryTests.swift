import XCTest
@testable import WeekFit

@MainActor
final class CoachEveningSummaryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Tests assert production once-per-day behavior even though DEBUG app defaults to unrestricted.
        UserDefaults.standard.set(true, forKey: CoachEveningSummaryPolicy.oncePerDayOverrideKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: CoachEveningSummaryPolicy.oncePerDayOverrideKey)
        super.tearDown()
    }

    private func calendar(_ zone: String = "Europe/Warsaw") -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    private func temporaryStore() -> CoachEveningSummaryStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return CoachEveningSummaryStore(directory: directory)
    }

    private func input(day: String = "2026-10-12", locale: String = "ru") -> CoachEveningSummaryInput {
        .init(schemaVersion: 1, day: day, timezone: "Europe/Warsaw", locale: locale,
              phase: "evening", facts: ["sleep": [.init(id: "sleep.duration", text: "6 hours")]])
    }

    private func answer(_ input: CoachEveningSummaryInput, headline: String = "Итог дня") -> CoachEveningSummary {
        let passage = CoachEveningSummary.Passage(text: "Текст", evidenceIds: ["sleep.duration"])
        return .init(headline: headline, today: passage, now: passage, tomorrow: passage,
                     limitations: [], day: input.day, locale: input.locale,
                     generatedAt: "2026-10-12T18:00:00Z", source: "ai")
    }

    private func result(_ input: CoachEveningSummaryInput, headline: String = "Итог дня", requestId: String = "req-1")
        -> CoachEveningSummaryGenerationResult {
        .init(summary: answer(input, headline: headline), requestId: requestId)
    }

    func testLocal20CutoffAndDayBoundary() {
        XCTAssertFalse(CoachEveningSummaryPolicy.isEvening(date("2026-10-12T17:59:59Z"), calendar: calendar()))
        XCTAssertTrue(CoachEveningSummaryPolicy.isEvening(date("2026-10-12T18:00:00Z"), calendar: calendar()))
        XCTAssertTrue(CoachEveningSummaryPolicy.isEvening(date("2026-11-12T19:00:00Z"), calendar: calendar()))
        XCTAssertEqual(CoachEveningSummaryPolicy.dayKey(date("2026-10-12T22:00:00Z"), calendar: calendar()), "2026-10-13")
    }

    func testProductionModeRequiresEveningWindow() {
        XCTAssertTrue(CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow)
        XCTAssertFalse(CoachEveningSummaryPolicy.allowsGeneration(
            at: date("2026-10-12T10:00:00Z"), calendar: calendar()))
        XCTAssertTrue(CoachEveningSummaryPolicy.allowsGeneration(
            at: date("2026-10-12T18:00:00Z"), calendar: calendar()))
    }

    func testDisplayCommentaryPrefersTodayAndTomorrow() {
        let input = input(locale: "en")
        let summary = CoachEveningSummary(
            headline: "Recap",
            today: .init(text: "Today takeaway about the whole day.", evidenceIds: ["sleep.duration"]),
            now: .init(text: "Keep your evening easy and wind down.", evidenceIds: ["sleep.duration"]),
            tomorrow: .init(text: "Tomorrow protect protein at breakfast.", evidenceIds: ["sleep.duration"]),
            limitations: [],
            day: input.day,
            locale: input.locale,
            generatedAt: "2026-10-12T18:00:00Z",
            source: "ai"
        )
        XCTAssertEqual(
            CoachEveningSummaryPolicy.displayCommentary(from: summary),
            "Today takeaway about the whole day. Tomorrow protect protein at breakfast."
        )
    }

    func testDisplayCommentaryFallsBackToNow() {
        let input = input(locale: "en")
        let summary = CoachEveningSummary(
            headline: "Recap",
            today: .init(text: " ", evidenceIds: ["sleep.duration"]),
            now: .init(text: "Keep your evening easy and wind down.", evidenceIds: ["sleep.duration"]),
            tomorrow: .init(text: " ", evidenceIds: ["sleep.duration"]),
            limitations: [],
            day: input.day,
            locale: input.locale,
            generatedAt: "2026-10-12T18:00:00Z",
            source: "ai"
        )
        XCTAssertEqual(
            CoachEveningSummaryPolicy.displayCommentary(from: summary),
            "Keep your evening easy and wind down."
        )
    }

    func testFallbackSourceIsAcceptedWhenFactsAreEmpty() {
        let input = CoachEveningSummaryInput(
            schemaVersion: 1,
            day: "2026-10-12",
            timezone: "Europe/Warsaw",
            locale: "pl",
            phase: "evening",
            facts: [:]
        )
        let summary = CoachEveningSummary(
            headline: "Spokojny wieczór",
            today: .init(text: "Dziś brakuje danych, by przygotować osobistą obserwację.", evidenceIds: []),
            now: .init(text: "Dziś brakuje danych, by przygotować osobistą obserwację.", evidenceIds: []),
            tomorrow: .init(text: "Jeśli chcesz, oceń, jak się dziś wieczorem czujesz.", evidenceIds: []),
            limitations: ["Brak faktów dnia."],
            day: input.day,
            locale: input.locale,
            generatedAt: "2026-10-12T18:00:00Z",
            source: "fallback"
        )
        XCTAssertTrue(summary.isValid(for: input))
        XCTAssertFalse(summary.isValid(for: input(locale: "en")), "locale mismatch must still fail")
    }

    func testDisplayCommentaryBlanksEnglishLeakUnderPolishLocale() {
        let summary = CoachEveningSummary(
            headline: "Notatka",
            today: .init(
                text: "You have logged only one meal so far today and your food log completeness is unknown.",
                evidenceIds: ["sleep.duration"]
            ),
            now: .init(text: "You have logged only one meal so far today.", evidenceIds: ["sleep.duration"]),
            tomorrow: .init(text: "How do you feel this evening?", evidenceIds: ["sleep.duration"]),
            limitations: [],
            day: "2026-10-12",
            locale: "pl",
            generatedAt: "2026-10-12T18:00:00Z",
            source: "ai"
        )
        XCTAssertEqual(CoachEveningSummaryPolicy.displayCommentary(from: summary), "")
        XCTAssertFalse(
            CoachEveningSummaryPolicy.textMatchesRequestedLocale(
                summary.today.text,
                locale: "pl"
            )
        )
    }

    func testNoteTextDropsEnglishTakeawayWhenMergingPolishComparison() {
        let note = CoachEveningRecapCopy.noteText(
            commentary: "You have logged only one meal so far today and your food log completeness is unknown.",
            comparison: "Spacer: 7,7 km mniej niż zwykle.",
            feelingReaction: nil,
            isLoading: false,
            failed: false,
            locale: "pl"
        )
        XCTAssertEqual(note, "Spacer: 7,7 km mniej niż zwykle.")
    }

    func testPersistedClaimSurvivesStoreRecreationAndIsScopedToOwner() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let a = CoachEveningSummaryStore(directory: directory)
        XCTAssertTrue(try a.claim(owner: "local", day: "2026-10-12"))
        let b = CoachEveningSummaryStore(directory: directory)
        XCTAssertFalse(try b.claim(owner: "local", day: "2026-10-12"))
        XCTAssertTrue(try b.claim(owner: "other", day: "2026-10-12"))
        XCTAssertTrue(try b.claim(owner: "local", day: "2026-10-13"))
    }

    func testManualRefreshReusesOncePerDayAnswer() async {
        let store = temporaryStore()
        var calls = 0
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            return self.result(input, headline: "H\(calls)")
        }
        let evening = date("2026-10-12T20:30:00Z")
        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(coordinator.summary?.headline, "H1")
        XCTAssertFalse(coordinator.isRefreshing)

        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 1, "once-per-day must not call AI again on Refresh")
        XCTAssertEqual(coordinator.summary?.headline, "H1")
    }

    func testEnsureUpToDateKeepsFirstAnswerWhenFingerprintChanges() async {
        XCTAssertTrue(CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow)
        let store = temporaryStore()
        var calls = 0
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            return self.result(input, headline: "H\(calls)")
        }
        let evening = date("2026-10-12T20:30:00Z")
        coordinator.ensureUpToDate(
            input: input(),
            owner: "local",
            fingerprint: "fp1",
            now: evening,
            calendar: calendar(),
            source: "coach",
            isStillEligible: { true }
        )
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(coordinator.summary?.headline, "H1")

        coordinator.ensureUpToDate(
            input: input(),
            owner: "local",
            fingerprint: "fp1",
            now: evening,
            calendar: calendar(),
            source: "coach",
            isStillEligible: { true }
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(calls, 1)

        coordinator.ensureUpToDate(
            input: input(),
            owner: "local",
            fingerprint: "fp2",
            now: evening,
            calendar: calendar(),
            source: "coach",
            isStillEligible: { true }
        )
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 1, "once-per-day must reuse first answer")
        XCTAssertEqual(coordinator.summary?.headline, "H1")
    }

    func testRootAndCoachTriggersShareSingleHTTP() async {
        let store = temporaryStore()
        var calls = 0
        let gate = AsyncGate()
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            await gate.wait()
            return self.result(input, headline: "Shared")
        }
        let evening = date("2026-10-12T20:30:00Z")

        coordinator.startIfNeeded(input: input(), owner: "local", now: evening, calendar: calendar(), source: "root")
        for _ in 0..<40 where !coordinator.isRefreshing { await Task.yield() }
        XCTAssertTrue(coordinator.isRefreshing)

        coordinator.ensureUpToDate(
            input: input(),
            owner: "local",
            fingerprint: "fp-coach",
            now: evening,
            calendar: calendar(),
            source: "coach",
            isStillEligible: { true }
        )
        await gate.open()
        for _ in 0..<40 where coordinator.isRefreshing { await Task.yield() }

        XCTAssertEqual(calls, 1, "Root + Coach must join one in-flight generation")
        XCTAssertEqual(coordinator.summary?.headline, "Shared")
        XCTAssertFalse(coordinator.isRefreshing)
    }

    func testLeavingScreenStillCachesSuccessfulResponse() async {
        let store = temporaryStore()
        let gate = AsyncGate()
        var eligible = true
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            await gate.wait()
            return self.result(input, headline: "Late")
        }
        let evening = date("2026-10-12T18:30:00Z")
        coordinator.ensureUpToDate(
            input: input(),
            owner: "local",
            fingerprint: "fp1",
            now: evening,
            calendar: calendar(),
            source: "coach",
            isStillEligible: { eligible }
        )
        for _ in 0..<40 where !coordinator.isRefreshing { await Task.yield() }
        XCTAssertTrue(coordinator.isRefreshing)
        eligible = false
        await gate.open()
        for _ in 0..<40 where coordinator.isRefreshing { await Task.yield() }

        XCTAssertEqual(coordinator.summary?.headline, "Late", "eligibility must not discard a valid success")
        XCTAssertEqual(try store.loadCache(owner: "local")?.summary.headline, "Late")
        XCTAssertFalse(coordinator.isRefreshing)

        // Re-open same session: no new generation.
        var calls = 0
        let reopen = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            return self.result(input, headline: "ShouldNotRun")
        }
        // Same coordinator memory path:
        eligible = true
        coordinator.ensureUpToDate(
            input: input(),
            owner: "local",
            fingerprint: "fp2",
            now: evening,
            calendar: calendar(),
            source: "coach",
            isStillEligible: { true }
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(coordinator.summary?.headline, "Late")

        reopen.restore(owner: "local")
        reopen.ensureUpToDate(
            input: input(),
            owner: "local",
            fingerprint: "fp3",
            now: evening,
            calendar: calendar(),
            source: "coach",
            isStillEligible: { true }
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(calls, 0, "disk cache must satisfy reopen")
        XCTAssertEqual(reopen.summary?.headline, "Late")
    }

    func testMemoryCacheSurvivesDiskSaveFailureWithoutRegeneration() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        // Create a regular file where the directory should be so writes fail.
        FileManager.default.createFile(atPath: directory.path, contents: Data("blocked".utf8))
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = CoachEveningSummaryStore(directory: directory)
        var calls = 0
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            return self.result(input, headline: "MemOnly")
        }
        let evening = date("2026-10-12T20:30:00Z")
        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(coordinator.summary?.headline, "MemOnly")

        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(calls, 1, "in-memory success must block same-session regeneration")
    }

    func testRefreshFailureAllowsRetry() async {
        let store = temporaryStore()
        var calls = 0
        let gate = AsyncGate()
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            if calls == 1 {
                await gate.wait()
                throw URLError(.timedOut)
            }
            return self.result(input, headline: "Good")
        }
        let evening = date("2026-10-12T18:30:00Z")
        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        for _ in 0..<40 where !coordinator.isRefreshing { await Task.yield() }
        await gate.open()
        for _ in 0..<40 where coordinator.isRefreshing { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertNil(coordinator.summary)
        XCTAssertTrue(coordinator.lastRefreshFailed)

        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(coordinator.summary?.headline, "Good")
        XCTAssertFalse(coordinator.lastRefreshFailed)
        XCTAssertFalse(coordinator.isRefreshing)
    }

    func testTimeoutDoesNotMintSecondHTTP() async {
        let store = temporaryStore()
        var calls = 0
        let gate = AsyncGate()
        let coordinator = CoachEveningSummaryCoordinator(store: store, timeoutSeconds: 0.05) { input, _ in
            calls += 1
            await gate.wait()
            return self.result(input, headline: "AfterTimeout")
        }
        let evening = date("2026-10-12T18:30:00Z")
        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        for _ in 0..<40 where !coordinator.isRefreshing { await Task.yield() }

        // Wait for UX timeout to clear spinner without cancelling the flight.
        let deadline = Date().addingTimeInterval(0.3)
        while coordinator.isRefreshing, Date() < deadline {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(coordinator.isRefreshing, "timeout should clear UI spinner")
        XCTAssertTrue(coordinator.lastRefreshFailed)
        XCTAssertEqual(calls, 1)

        // Second trigger must join the still-running flight, not start HTTP #2.
        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        XCTAssertEqual(calls, 1, "timeout must not allow a duplicate HTTP")
        XCTAssertTrue(coordinator.isRefreshing)

        await gate.open()
        for _ in 0..<80 where coordinator.isRefreshing { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(coordinator.summary?.headline, "AfterTimeout")
        XCTAssertFalse(coordinator.lastRefreshFailed)
    }

    func testOwnerChangeDoesNotApplyForeignResponse() async {
        let store = temporaryStore()
        let gate = AsyncGate()
        var calls = 0
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, owner in
            calls += 1
            await gate.wait()
            return self.result(input, headline: "For-\(owner)")
        }
        let evening = date("2026-10-12T20:30:00Z")
        coordinator.refresh(input: input(), owner: "owner-a", now: evening, calendar: calendar())
        for _ in 0..<40 where !coordinator.isRefreshing { await Task.yield() }

        // Switch owner while first flight is outstanding.
        coordinator.restore(owner: "owner-b")
        XCTAssertNil(coordinator.summary)

        await gate.open()
        for _ in 0..<40 { await Task.yield() }

        XCTAssertNil(try store.loadCache(owner: "owner-b")?.summary)
        // Cancelled flight for owner-a must not land on owner-b.
        XCTAssertNotEqual(coordinator.summary?.headline, "For-owner-a")
    }

    func testLocalDayChangeStartsNewFlight() async {
        let store = temporaryStore()
        var calls = 0
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            return self.result(input, headline: "Day-\(input.day)")
        }
        let day1 = date("2026-10-12T20:30:00Z")
        coordinator.refresh(input: input(day: "2026-10-12"), owner: "local", now: day1, calendar: calendar())
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(coordinator.summary?.headline, "Day-2026-10-12")

        let day2 = date("2026-10-13T20:30:00Z")
        coordinator.refresh(input: input(day: "2026-10-13"), owner: "local", now: day2, calendar: calendar())
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(coordinator.summary?.headline, "Day-2026-10-13")
    }

    func testBlocksSecondPressWhileRefreshing() async {
        let store = temporaryStore()
        var calls = 0
        let gate = AsyncGate()
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            await gate.wait()
            return self.result(input)
        }
        let now = date("2026-10-12T18:30:00Z")
        coordinator.refresh(input: input(), owner: "local", now: now, calendar: calendar())
        for _ in 0..<40 where !coordinator.isRefreshing { await Task.yield() }
        XCTAssertTrue(coordinator.isRefreshing)
        coordinator.refresh(input: input(), owner: "local", now: now, calendar: calendar())
        await gate.open()
        for _ in 0..<40 where coordinator.isRefreshing { await Task.yield() }
        XCTAssertFalse(coordinator.isRefreshing)
        XCTAssertEqual(calls, 1)
    }

    func testLastingCacheRestoresAcrossMidnightWithoutAI() throws {
        let store = temporaryStore()
        let cached = answer(input())
        let received = date("2026-10-12T18:30:00Z")
        try store.saveCache(.init(summary: cached, receivedAt: received), owner: "local")
        let coordinator = CoachEveningSummaryCoordinator(store: store) { _, _ in
            XCTFail("Restoring lasting cache must never call AI")
            throw URLError(.badServerResponse)
        }
        coordinator.restore(owner: "local")
        XCTAssertEqual(coordinator.summary, cached)
        XCTAssertEqual(coordinator.receivedAt, received)
    }

    func testRestoreIgnoresEveningWindowHealthAndClaims() throws {
        let store = temporaryStore()
        let cached = answer(input())
        let received = date("2026-10-11T08:00:00Z")
        try store.saveCache(.init(summary: cached, receivedAt: received), owner: "local")
        try store.saveClaim(.init(day: "2026-10-12", summary: nil), owner: "local")
        var calls = 0
        let coordinator = CoachEveningSummaryCoordinator(store: store) { _, _ in
            calls += 1
            throw URLError(.badServerResponse)
        }
        coordinator.restore(owner: "local")
        XCTAssertEqual(coordinator.summary, cached)
        XCTAssertEqual(coordinator.receivedAt, received)
        XCTAssertEqual(calls, 0)
        XCTAssertFalse(coordinator.lastRefreshFailed)
    }

    func testProductionModeBlocksMissingSnapshotAndOutsideEveningWindow() {
        XCTAssertTrue(CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow)
        XCTAssertEqual(
            CoachEveningSummaryInputBuilder.buildBlockReason(
                input: nil,
                now: date("2026-10-12T18:30:00Z"),
                calendar: calendar()
            ),
            .snapshotStale
        )
        XCTAssertEqual(
            CoachEveningSummaryInputBuilder.buildBlockReason(
                input: nil,
                now: date("2026-10-12T10:00:00Z"),
                calendar: calendar()
            ),
            .snapshotStale
        )
    }

    func testCacheIsolatedByOwner() throws {
        let store = temporaryStore()
        try store.saveCache(.init(summary: answer(input()), receivedAt: date("2026-10-12T18:00:00Z")), owner: "a")
        XCTAssertNil(try store.loadCache(owner: "b"))
        XCTAssertNotEqual(try store.loadCache(owner: "a")?.summary, nil)
    }

    func testDeletingSummaryTextPreservesDailyAttemptButClearsLastingCache() throws {
        let store = temporaryStore()
        try store.saveClaim(.init(day: "2026-10-12", summary: answer(input())), owner: "local")
        try store.saveCache(.init(summary: answer(input()), receivedAt: date("2026-10-12T18:00:00Z")), owner: "local")
        try store.eraseSummaryTextPreservingAttempts()
        XCTAssertNil(try store.record(owner: "local", day: "2026-10-12")?.summary)
        XCTAssertFalse(try store.claim(owner: "local", day: "2026-10-12"))
        XCTAssertNil(try store.loadCache(owner: "local"))
    }
}

/// Tiny async latch for in-flight refresh tests.
private actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}
