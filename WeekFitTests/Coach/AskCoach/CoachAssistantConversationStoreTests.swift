import XCTest
@testable import WeekFit

final class CoachAssistantConversationStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "CoachAssistantConversationStoreTests.\(UUID().uuidString)")
        CoachAssistantConversationStore.useDefaults(defaults)
        CoachAssistantConversationStore.clear()
    }

    override func tearDown() {
        CoachAssistantConversationStore.clear()
        CoachAssistantConversationStore.resetDefaults()
        defaults = nil
        super.tearDown()
    }

    func testPersistAndLatestForDay() {
        let day1 = date(2026, 4, 15, hour: 9)
        let day2 = date(2026, 4, 16, hour: 9)
        let first = makeConversation(id: "a", at: day1, preview: "Tired reflection")
        let second = makeConversation(id: "b", at: day1.addingTimeInterval(3600), preview: "Updated")
        let next = makeConversation(id: "c", at: day2, preview: "New day")

        CoachAssistantConversationStore.upsert(first)
        CoachAssistantConversationStore.upsert(second)
        CoachAssistantConversationStore.upsert(next)

        XCTAssertEqual(CoachAssistantConversationStore.latest(on: day1, calendar: calendar)?.id, "b")
        XCTAssertEqual(CoachAssistantConversationStore.latest(on: day2, calendar: calendar)?.previewEnglish, "New day")
        XCTAssertEqual(CoachAssistantConversationStore.all().count, 3)
    }

    func testDeleteRemovesConversation() {
        let now = date(2026, 4, 15, hour: 10)
        CoachAssistantConversationStore.upsert(makeConversation(id: "x", at: now, preview: "Hi"))
        XCTAssertTrue(CoachAssistantConversationStore.delete(id: "x"))
        XCTAssertNil(CoachAssistantConversationStore.conversation(id: "x"))
    }

    func testEvidenceSnapshotSurvivesRoundTrip() {
        var conversation = makeConversation(id: "ev", at: date(2026, 4, 15), preview: "Snap")
        conversation.evidence.feelingOutcome = .supporting
        conversation.evidence.feelingEvidence.sleepMinutes = 360
        conversation.evidence.feelingEvidence.sleepBaselineMinutes = 450
        CoachAssistantConversationStore.upsert(conversation)

        let loaded = CoachAssistantConversationStore.conversation(id: "ev")
        XCTAssertEqual(loaded?.evidence.feelingOutcome, .supporting)
        XCTAssertEqual(loaded?.evidence.feelingEvidence.sleepMinutes, 360)
        XCTAssertEqual(loaded?.evidence.feelingEvidence.sleepBaselineMinutes, 450)
    }

    // MARK: - Helpers

    private func makeConversation(id: String, at date: Date, preview: String) -> CoachAssistantConversation {
        CoachAssistantConversation(
            id: id,
            createdAt: date,
            updatedAt: date,
            feeling: .tired,
            clarification: nil,
            area: nil,
            currentNodeID: .mindAsk,
            turns: [
                CoachAssistantTurn(
                    role: .coach,
                    text: .en(preview, preview),
                    nodeID: .feelingAsk,
                    createdAt: date
                )
            ],
            choiceIDs: [],
            evidence: .empty,
            previewEnglish: preview,
            previewRussian: preview,
            ended: false
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
