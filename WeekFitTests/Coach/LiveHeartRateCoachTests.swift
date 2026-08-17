import XCTest
@testable import WeekFit

final class LiveHeartRateCoachTests: XCTestCase {
    func testAppleKarvonenBandsMatchFitnessCutover() {
        let profile = HeartRateZones.Profile.apple(age: 40, restingHeartRate: 60)
        // maxHR = 220 - 40 = 180, HRR = 120
        // Fitness labels: <132, 133–144, 145–155, 156–167, 168+
        XCTAssertEqual(HeartRateZones.zone(forBPM: 100, profile: profile), 1)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 132, profile: profile), 1)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 133, profile: profile), 2)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 144, profile: profile), 2)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 145, profile: profile), 3)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 155, profile: profile), 3)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 156, profile: profile), 4)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 167, profile: profile), 4)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 168, profile: profile), 5)
        XCTAssertEqual(HeartRateZones.zone(forBPM: 190, profile: profile), 5)
        XCTAssertTrue(HeartRateZones.isElevated(4))
        XCTAssertTrue(HeartRateZones.isCritical(5))
        XCTAssertFalse(HeartRateZones.isElevated(3))
    }

    func testZoneOneLabelMatchesAppleBelowFormat() {
        let profile = HeartRateZones.Profile.apple(age: 40, restingHeartRate: 60)
        let zone1 = HeartRateZones.definition(for: 1, profile: profile)
        XCTAssertEqual(Int(zone1.upperBound), 133)
        XCTAssertTrue(HeartRateZones.bpmRangeLabel(for: 1, profile: profile).contains("132"))
        XCTAssertTrue(HeartRateZones.bpmRangeLabel(for: 2, profile: profile).contains("133"))
        XCTAssertTrue(HeartRateZones.bpmRangeLabel(for: 5, profile: profile).contains("168"))
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

    func testLiveZoneColorSurvivesLowEnergyAdjustment() {
        XCTAssertEqual(
            CoachConversationEnergyPolicy.adjustedSemanticColor(
                base: .liveZone2,
                energy: .low,
                scenario: .duringRecovery
            ),
            .liveZone2
        )
        XCTAssertEqual(
            CoachConversationEnergyPolicy.adjustedSemanticColor(
                base: .liveCritical,
                energy: .medium,
                scenario: .walkLightDay
            ),
            .liveCritical
        )
        XCTAssertEqual(
            CoachConversationEnergyPolicy.adjustedSemanticColor(
                base: .live,
                energy: .low,
                scenario: .duringRecovery
            ),
            .recovery
        )
    }

    func testMissingAgeFallsBackTo190MaxHeartRate() {
        let profile = HeartRateZones.Profile.apple(age: 0, restingHeartRate: 60)
        let zone1 = HeartRateZones.definition(for: 1, profile: profile)
        XCTAssertEqual(Int(zone1.upperBound), 139)
        XCTAssertTrue(HeartRateZones.bpmRangeLabel(for: 1, profile: profile).contains("138"))
    }

    func testEachZoneHasADistinctColor() {
        let colors = (1...5).map { HeartRateZones.color(for: $0) }
        for (index, color) in colors.enumerated() {
            for (otherIndex, other) in colors.enumerated() where index != otherIndex {
                XCTAssertNotEqual(
                    String(describing: color),
                    String(describing: other),
                    "Zone \(index + 1) color collided with zone \(otherIndex + 1)"
                )
            }
        }
    }

    func testBadgeLabelShowsZoneOnly() {
        let label = HeartRateZones.badgeLabel(zone: 4)
        XCTAssertEqual(label, HeartRateZones.localizedTitle(for: 4))
        XCTAssertFalse(label.contains("162"))
    }
}
