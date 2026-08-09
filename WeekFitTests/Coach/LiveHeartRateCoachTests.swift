import XCTest
@testable import WeekFit

final class LiveHeartRateCoachTests: XCTestCase {
    func testHeartRateZonesMapBPMBands() {
        XCTAssertEqual(HeartRateZones.zone(forBPM: 100), 1)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 130), 2)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 150), 3)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 170), 4)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 190), 5)
        XCTAssertTrue(HeartRateZones.isElevated(4))
        XCTAssertTrue(HeartRateZones.isCritical(5))
        XCTAssertFalse(HeartRateZones.isElevated(3))
    }

    func testSemanticColorMapsAllZones() {
        XCTAssertEqual(
            CoachPresentationResolver.semanticColor(for: .duringEndurance, liveHeartRateZone: 1),
            .liveZone1
        )
        XCTAssertEqual(
            CoachPresentationResolver.semanticColor(for: .duringEndurance, liveHeartRateZone: 2),
            .liveZone2
        )
        XCTAssertEqual(
            CoachPresentationResolver.semanticColor(for: .duringEndurance, liveHeartRateZone: 3),
            .liveZone3
        )
        XCTAssertEqual(
            CoachPresentationResolver.semanticColor(for: .duringEndurance, liveHeartRateZone: 4),
            .liveElevated
        )
        XCTAssertEqual(
            CoachPresentationResolver.semanticColor(for: .duringEndurance, liveHeartRateZone: 5),
            .liveCritical
        )
        XCTAssertEqual(
            CoachPresentationResolver.semanticColor(for: .walkLightDay, liveHeartRateZone: 4),
            .liveElevated
        )
        XCTAssertEqual(
            CoachPresentationResolver.semanticColor(for: .stableDay, liveHeartRateZone: 5),
            .stable
        )
    }

    func testBadgeLabelIncludesZoneAndBPM() {
        let label = HeartRateZones.badgeLabel(zone: 4, bpm: 162)
        XCTAssertTrue(label.contains("4"))
        XCTAssertTrue(label.contains("162"))
    }
}
