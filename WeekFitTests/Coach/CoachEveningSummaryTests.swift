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

    private func answer(_ input: CoachEveningSummaryInput) -> CoachEveningSummary {
        let passage = CoachEveningSummary.Passage(text: "Текст", evidenceIds: ["sleep.duration"])
        return .init(headline: "Итог дня", today: passage, now: passage, tomorrow: passage,
                     limitations: [], day: input.day, locale: input.locale,
                     generatedAt: "2026-10-12T18:00:00Z", source: "ai")
    }

    func testLocal20CutoffAndDayBoundary() {
        XCTAssertFalse(CoachEveningSummaryPolicy.isEvening(date("2026-10-12T17:59:59Z"), calendar: calendar()))
        XCTAssertTrue(CoachEveningSummaryPolicy.isEvening(date("2026-10-12T18:00:00Z"), calendar: calendar()))
        XCTAssertTrue(CoachEveningSummaryPolicy.isEvening(date("2026-11-12T19:00:00Z"), calendar: calendar()))
        XCTAssertEqual(CoachEveningSummaryPolicy.dayKey(date("2026-10-12T22:00:00Z"), calendar: calendar()), "2026-10-13")
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

    func testNoRequestBefore20AndNoRepeatsAfterChangingLanguageOrMetrics() async {
        var calls = 0
        let coordinator = CoachEveningSummaryCoordinator(store: temporaryStore()) { input, _ in
            calls += 1
            return self.answer(input)
        }
        coordinator.startIfNeeded(input: input(), owner: "local", now: date("2026-10-12T17:59:59Z"), calendar: calendar())
        XCTAssertEqual(calls, 0)
        for _ in 0..<5 {
            coordinator.startIfNeeded(input: input(), owner: "local", now: date("2026-10-12T18:00:00Z"), calendar: calendar())
        }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(calls, 1)
        coordinator.startIfNeeded(input: input(locale: "en"), owner: "local", now: date("2026-10-12T19:00:00Z"), calendar: calendar())
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(calls, 1)
    }

    func testFailureAndNewCoordinatorCannotRetry() async {
        let store = temporaryStore()
        var calls = 0
        let generate: (CoachEveningSummaryInput, String) async throws -> CoachEveningSummary = { _, _ in
            calls += 1
            throw URLError(.timedOut)
        }
        let a = CoachEveningSummaryCoordinator(store: store, generate: generate)
        a.startIfNeeded(input: input(), owner: "local", now: date("2026-10-12T18:00:00Z"), calendar: calendar())
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(a.status, .failed)
        let b = CoachEveningSummaryCoordinator(store: store, generate: generate)
        b.startIfNeeded(input: input(), owner: "local", now: date("2026-10-12T19:00:00Z"), calendar: calendar())
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(b.status, .failed)
    }

    func testStoredAnswerRestoresWithoutAI() throws {
        let store = temporaryStore()
        try store.save(.init(day: "2026-10-12", summary: answer(input())), owner: "local")
        let coordinator = CoachEveningSummaryCoordinator(store: store) { _, _ in
            XCTFail("Restoring a stored answer must never call AI")
            throw URLError(.badServerResponse)
        }
        coordinator.restore(owner: "local", now: date("2026-10-12T18:00:00Z"), calendar: calendar())
        XCTAssertEqual(coordinator.status, .ready(answer(input())))
    }

    func testDeletingSummaryTextPreservesDailyAttempt() throws {
        let store = temporaryStore()
        try store.save(.init(day: "2026-10-12", summary: answer(input())), owner: "local")
        try store.eraseSummaryTextPreservingAttempts()
        XCTAssertNil(try store.record(owner: "local", day: "2026-10-12")?.summary)
        XCTAssertFalse(try store.claim(owner: "local", day: "2026-10-12"))
    }
}
