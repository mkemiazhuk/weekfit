import XCTest
@testable import WeekFit

final class CoachUIPresentationDedupTests: XCTestCase {

    func testCompactRemovesExactDuplicateAdjacentBlocks() {
        let copy = CoachUIPresentationDedup.HeroCopy(
            coachTitle: "Recovery day",
            assessment: "Keep the first block light today.",
            recommendation: "Keep the first block light today.",
            avoid: "No late intensity.",
            nextAction: "Walk 20 minutes after breakfast."
        )

        let compact = CoachUIPresentationDedup.compact(copy)

        XCTAssertEqual(compact.coachTitle, "Recovery day")
        XCTAssertEqual(compact.assessment, "Keep the first block light today.")
        XCTAssertTrue(compact.recommendation.isEmpty)
        XCTAssertEqual(compact.avoid, "No late intensity.")
        XCTAssertEqual(compact.nextAction, "Walk 20 minutes after breakfast.")
    }

    func testCompactRemovesPhraseOverlapAcrossAdjacentBlocks() {
        let copy = CoachUIPresentationDedup.HeroCopy(
            coachTitle: "Morning check-in",
            assessment: "Short night — recovery matters more now.",
            recommendation: "Recovery matters more than intensity today.",
            avoid: "",
            nextAction: ""
        )

        let compact = CoachUIPresentationDedup.compact(copy)

        XCTAssertFalse(compact.assessment.isEmpty)
        XCTAssertTrue(compact.recommendation.isEmpty)
    }

    func testIsNearDuplicateDetectsSharedThreeWordPhrase() {
        XCTAssertTrue(
            CoachUIPresentationDedup.isNearDuplicate(
                "Keep the first block light.",
                "Start with the first block light."
            )
        )
    }
}
