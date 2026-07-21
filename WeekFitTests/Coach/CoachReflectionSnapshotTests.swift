import XCTest
@testable import WeekFit

final class CoachReflectionPresentationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testNewDiscoveryUsesNoticingLeadIn() {
        let leadIn = CoachReflectionPresentation.leadIn(
            for: .newDiscovery,
            pauseReason: "settledPostNoWorkRemaining"
        )

        XCTAssertTrue(leadIn.contains("noticing") || leadIn.contains("One thing"))
        XCTAssertFalse(leadIn.uppercased() == leadIn)
    }

    func testEveningPauseUsesBeforeWeFinishLeadIn() {
        let leadIn = CoachReflectionPresentation.leadIn(
            for: .newDiscovery,
            pauseReason: "eveningNoWorkRemaining"
        )

        XCTAssertTrue(leadIn.lowercased().contains("before we finish"))
    }

    func testConfirmationUsesLookingBackLeadIn() {
        let leadIn = CoachReflectionPresentation.leadIn(
            for: .confirmation,
            pauseReason: "settledPostNoWorkRemaining"
        )

        XCTAssertTrue(leadIn.lowercased().contains("looking back"))
    }

    func testRussianLeadInLocalization() {
        WeekFitSetCurrentLanguage(.russian)

        let leadIn = CoachReflectionPresentation.leadIn(
            for: .newDiscovery,
            pauseReason: "settledPostNoWorkRemaining"
        )

        XCTAssertTrue(leadIn.contains("замеча"))
    }

    func testContentPreservesReflectionMessage() {
        let offer = CoachReflectionPreviewFixtures.emergingOffer
        let content = CoachReflectionPresentation.content(for: offer)

        XCTAssertEqual(content.message, offer.message)
        XCTAssertFalse(content.leadIn.isEmpty)
    }
}

final class CoachReflectionSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testGuidanceOnlySnapshotHasNoReflectionSection() {
        let snapshot = CoachReflectionSnapshotPrinter.render(CoachReflectionSnapshotPrinter.guidanceOnly)

        XCTAssertTrue(snapshot.contains("HAS_REFLECTION: false"))
        XCTAssertFalse(snapshot.contains("REFLECTION_LEAD_IN:"))
        XCTAssertFalse(snapshot.contains("REFLECTION_MESSAGE:"))
    }

    func testGuidanceWithReflectionSnapshotIncludesContinuationCopy() {
        let snapshot = CoachReflectionSnapshotPrinter.render(CoachReflectionSnapshotPrinter.guidanceWithReflection)

        XCTAssertTrue(snapshot.contains("HAS_REFLECTION: true"))
        XCTAssertTrue(snapshot.contains("REFLECTION_LEAD_IN: One thing I've been noticing"))
        XCTAssertTrue(snapshot.contains("REFLECTION_MESSAGE:"))
    }

    func testLongRussianSnapshotPreservesFullMessage() {
        WeekFitSetCurrentLanguage(.russian)

        let snapshot = CoachReflectionSnapshotPrinter.render(CoachReflectionSnapshotPrinter.longRussian)

        XCTAssertTrue(snapshot.contains("HAS_REFLECTION: true"))
        XCTAssertTrue(snapshot.contains("восстановление на следующий день"))
        XCTAssertTrue(snapshot.contains("REFLECTION_LEAD_IN:"))
    }

    func testNarrowWidthSnapshotDocumentsLayoutWidth() {
        let snapshot = CoachReflectionSnapshotPrinter.render(CoachReflectionSnapshotPrinter.narrowWidth)

        XCTAssertTrue(snapshot.contains("WIDTH: 320pt"))
        XCTAssertTrue(snapshot.contains("HAS_REFLECTION: true"))
    }

    func testEveningSettledSnapshotUsesBeforeWeFinishLeadIn() {
        let snapshot = CoachReflectionSnapshotPrinter.render(CoachReflectionSnapshotPrinter.eveningSettled)

        XCTAssertTrue(snapshot.contains("PAUSE_REASON: eveningNoWorkRemaining"))
        XCTAssertTrue(snapshot.contains("REFLECTION_LEAD_IN: Before we finish"))
        XCTAssertTrue(snapshot.contains("GUIDANCE_RECOMMENDATION: Let the evening stay calm"))
    }
}
