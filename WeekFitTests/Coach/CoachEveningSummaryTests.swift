import XCTest
@testable import WeekFit

@MainActor
final class CoachEveningSummaryTests: XCTestCase {
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

    func testDisplayCommentaryPrefersNowPassage() {
        let input = input()
        let summary = CoachEveningSummary(
            headline: "Recap",
            today: .init(text: "Today takeaway about the whole day.", evidenceIds: ["sleep.duration"]),
            now: .init(text: "Keep your evening easy and wind down.", evidenceIds: ["sleep.duration"]),
            tomorrow: .init(text: "Plan is not yet known.", evidenceIds: ["sleep.duration"]),
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

    func testManualRefreshCallsAIInEveningWindow() async {
        let store = temporaryStore()
        XCTAssertTrue(try! store.claim(owner: "local", day: "2026-10-12"))
        var calls = 0
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            return self.answer(input, headline: "H\(calls)")
        }
        let evening = date("2026-10-12T18:30:00Z")
        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(coordinator.summary?.headline, "H1")
        XCTAssertFalse(coordinator.isRefreshing)

        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(coordinator.summary?.headline, "H2")
    }

    func testEnsureUpToDateRegeneratesWhenFingerprintChanges() async {
        let store = temporaryStore()
        var calls = 0
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            return self.answer(input, headline: "H\(calls)")
        }
        let evening = date("2026-10-12T18:30:00Z")
        coordinator.ensureUpToDate(
            input: input(),
            owner: "local",
            fingerprint: "fp1",
            now: evening,
            calendar: calendar(),
            isStillEligible: { true }
        )
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(coordinator.cachedFingerprint, "fp1")

        coordinator.ensureUpToDate(
            input: input(),
            owner: "local",
            fingerprint: "fp1",
            now: evening,
            calendar: calendar(),
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
            isStillEligible: { true }
        )
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(coordinator.cachedFingerprint, "fp2")
    }

    func testStaleResponseDiscardedWhenNoLongerEligible() async {
        let store = temporaryStore()
        let gate = AsyncGate()
        var eligible = true
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            await gate.wait()
            return self.answer(input, headline: "Late")
        }
        let evening = date("2026-10-12T18:30:00Z")
        coordinator.ensureUpToDate(
            input: input(),
            owner: "local",
            fingerprint: "fp1",
            now: evening,
            calendar: calendar(),
            isStillEligible: { eligible }
        )
        for _ in 0..<40 where !coordinator.isRefreshing {
            await Task.yield()
        }
        XCTAssertTrue(coordinator.isRefreshing)
        eligible = false
        await gate.open()
        for _ in 0..<40 where coordinator.isRefreshing {
            await Task.yield()
        }
        XCTAssertNil(coordinator.summary)
        XCTAssertFalse(coordinator.isRefreshing)
    }

    func testRefreshFailureKeepsPreviousSummary() async {
        let store = temporaryStore()
        var calls = 0
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            if calls == 1 { return self.answer(input, headline: "Good") }
            throw URLError(.timedOut)
        }
        let evening = date("2026-10-12T18:30:00Z")
        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(coordinator.summary?.headline, "Good")
        let received = coordinator.receivedAt

        coordinator.refresh(input: input(), owner: "local", now: evening, calendar: calendar())
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(coordinator.summary?.headline, "Good")
        XCTAssertEqual(coordinator.receivedAt, received)
        XCTAssertTrue(coordinator.lastRefreshFailed)
        XCTAssertFalse(coordinator.isRefreshing)
    }

    func testBlocksSecondPressWhileRefreshing() async {
        let store = temporaryStore()
        var calls = 0
        let gate = AsyncGate()
        let coordinator = CoachEveningSummaryCoordinator(store: store) { input, _ in
            calls += 1
            await gate.wait()
            return self.answer(input)
        }
        let now = date("2026-10-12T18:30:00Z")
        coordinator.refresh(input: input(), owner: "local", now: now, calendar: calendar())
        for _ in 0..<40 where !coordinator.isRefreshing {
            await Task.yield()
        }
        XCTAssertTrue(coordinator.isRefreshing)
        coordinator.refresh(input: input(), owner: "local", now: now, calendar: calendar())
        await gate.open()
        for _ in 0..<40 where coordinator.isRefreshing {
            await Task.yield()
        }
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
        // Prior daily claim / failure marker must not hide lasting cache.
        try store.saveClaim(.init(day: "2026-10-12", summary: nil), owner: "local")
        var calls = 0
        let coordinator = CoachEveningSummaryCoordinator(store: store) { _, _ in
            calls += 1
            throw URLError(.badServerResponse)
        }
        // Morning, before 20:00 — restore must still apply cache without AI.
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
        // Nil input short-circuits before the evening-window check; with no snapshot the
        // builder still reports stale rather than inventing facts.
    }

    func testCacheIsolatedByOwner() throws {
        let store = temporaryStore()
        try store.saveCache(.init(summary: answer(input()), receivedAt: date("2026-10-12T18:00:00Z")), owner: "a")
        XCTAssertNil(try store.loadCache(owner: "b"))
        XCTAssertNotNil(try store.loadCache(owner: "a"))
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
