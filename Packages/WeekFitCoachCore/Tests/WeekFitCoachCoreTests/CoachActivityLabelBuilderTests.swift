import XCTest
@testable import WeekFitCoachCore

final class CoachActivityLabelBuilderTests: XCTestCase {

    // MARK: - Duration thresholds

    func testDurationClassBoundaries() {
        XCTAssertEqual(CoachWalkDurationClass.from(minutes: 0), .short)
        XCTAssertEqual(CoachWalkDurationClass.from(minutes: 20), .short)
        XCTAssertEqual(CoachWalkDurationClass.from(minutes: 29), .short)
        XCTAssertEqual(CoachWalkDurationClass.from(minutes: 30), .standard)
        XCTAssertEqual(CoachWalkDurationClass.from(minutes: 60), .standard)
        XCTAssertEqual(CoachWalkDurationClass.from(minutes: 89), .standard)
        XCTAssertEqual(CoachWalkDurationClass.from(minutes: 90), .long)
        XCTAssertEqual(CoachWalkDurationClass.from(minutes: 179), .long)
        XCTAssertEqual(CoachWalkDurationClass.from(minutes: 180), .extended)
        XCTAssertEqual(CoachWalkDurationClass.from(minutes: 240), .extended)
    }

    // MARK: - Matrix: 20 / 60 / 90 / 179 / 180 / 240

    func testTwentyMinuteWalkWithoutSupportingData() {
        let descriptor = requireDescriptor(walkMinutes: 20)
        XCTAssertEqual(descriptor.durationClass, .short)
        XCTAssertEqual(descriptor.intensityClass, .unknown)
        XCTAssertEqual(descriptor.volumeClass, .unknown)
        XCTAssertEqual(descriptor.englishLabel, "Short walk")
        XCTAssertEqual(descriptor.russianLabel, "Короткая прогулка")
        XCTAssertFalse(descriptor.englishLabel.lowercased() == "easy walk")
    }

    func testTwentyMinuteEasyTitledWalk() {
        let descriptor = requireDescriptor(walkMinutes: 20, title: "Easy Walk")
        XCTAssertEqual(descriptor.durationClass, .short)
        XCTAssertEqual(descriptor.intensityClass, .easy)
        XCTAssertEqual(descriptor.volumeClass, .unknown)
        XCTAssertEqual(descriptor.englishLabel, "Short easy walk")
        XCTAssertNotEqual(descriptor.englishLabel.lowercased(), "easy walk")
    }

    func testSixtyMinuteWalkIsStandardNotEasyWalk() {
        let descriptor = requireDescriptor(walkMinutes: 60)
        XCTAssertEqual(descriptor.durationClass, .standard)
        XCTAssertEqual(descriptor.intensityClass, .unknown)
        XCTAssertEqual(descriptor.volumeClass, .unknown)
        XCTAssertEqual(descriptor.englishLabel, "Walk")
        XCTAssertNotEqual(descriptor.englishLabel.lowercased(), "easy walk")
    }

    func testSixtyMinuteEasyTitledWalkUsesEasyPaceNotBareEasyWalk() {
        let descriptor = requireDescriptor(walkMinutes: 60, title: "Easy Walk")
        XCTAssertEqual(descriptor.durationClass, .standard)
        XCTAssertEqual(descriptor.intensityClass, .easy)
        XCTAssertEqual(descriptor.englishLabel, "Easy-pace walk")
        XCTAssertNotEqual(descriptor.englishLabel.lowercased(), "easy walk")
    }

    func testNinetyMinuteWalkIsLongWithUnknownVolumeWithoutCalories() {
        let descriptor = requireDescriptor(walkMinutes: 90)
        XCTAssertEqual(descriptor.durationClass, .long)
        XCTAssertEqual(descriptor.intensityClass, .unknown)
        XCTAssertEqual(descriptor.volumeClass, .unknown)
        XCTAssertEqual(descriptor.englishLabel, "Long walk")
        XCTAssertFalse(descriptor.englishLabel.lowercased().contains("easy walk"))
        XCTAssertFalse(descriptor.englishLabel.lowercased().contains("meaningful"))
    }

    func testOneHundredSeventyNineMinuteWalkStaysLong() {
        let descriptor = requireDescriptor(walkMinutes: 179, title: "Easy Walk")
        XCTAssertEqual(descriptor.durationClass, .long)
        XCTAssertEqual(descriptor.intensityClass, .easy)
        XCTAssertEqual(descriptor.volumeClass, .unknown)
        XCTAssertEqual(descriptor.englishLabel, "Long low-intensity walk")
        XCTAssertNotEqual(descriptor.englishLabel.lowercased(), "easy walk")
    }

    func testOneHundredEightyMinuteWalkIsExtendedNotEasyWalk() {
        let descriptor = requireDescriptor(walkMinutes: 180, title: "Easy Walk")
        XCTAssertEqual(descriptor.durationClass, .extended)
        XCTAssertEqual(descriptor.intensityClass, .easy)
        XCTAssertEqual(descriptor.volumeClass, .unknown)
        XCTAssertEqual(descriptor.englishLabel, "Extended low-intensity walk")
        XCTAssertNotEqual(descriptor.englishLabel.lowercased(), "easy walk")
    }

    func testFourHourWalkWithoutSupportingDataKeepsVolumeUnknown() {
        let descriptor = requireDescriptor(walkMinutes: 240, title: "Easy Walk")
        XCTAssertEqual(descriptor.durationClass, .extended)
        XCTAssertEqual(descriptor.intensityClass, .easy)
        XCTAssertEqual(descriptor.volumeClass, .unknown)
        XCTAssertEqual(descriptor.englishLabel, "Extended low-intensity walk")
        XCTAssertFalse(descriptor.englishLabel.lowercased().hasPrefix("easy walk"))
        XCTAssertFalse(descriptor.englishLabel.lowercased().contains("meaningful"))
    }

    // MARK: - Volume confidence

    func testVolumeMeaningfulRequiresCaloriesAndDuration() {
        let descriptor = requireDescriptor(walkMinutes: 90, activeCalories: 450)
        XCTAssertEqual(descriptor.volumeClass, .meaningful)
        XCTAssertTrue(descriptor.englishLabel.contains("meaningful activity volume"))
        XCTAssertTrue(descriptor.russianLabel.contains("заметным объёмом"))
    }

    func testVolumeHighForExtendedWithEnoughCalories() {
        let descriptor = requireDescriptor(walkMinutes: 180, activeCalories: 650)
        XCTAssertEqual(descriptor.volumeClass, .high)
        XCTAssertTrue(descriptor.englishLabel.contains("high activity volume"))
    }

    func testZeroCaloriesDoesNotCountAsSupportingSignal() {
        let descriptor = requireDescriptor(walkMinutes: 240, activeCalories: 0)
        XCTAssertEqual(descriptor.volumeClass, .unknown)
        XCTAssertEqual(descriptor.englishLabel, "Extended walk")
    }

    func testShortWalkLowVolumeWhenCaloriesPresent() {
        let descriptor = requireDescriptor(walkMinutes: 20, activeCalories: 80)
        XCTAssertEqual(descriptor.volumeClass, .low)
        XCTAssertEqual(descriptor.englishLabel, "Short walk")
    }

    // MARK: - Intensity cues

    func testBriskTitleSetsIntensityIndependentlyOfDuration() {
        let descriptor = requireDescriptor(walkMinutes: 100, title: "Brisk Walk")
        XCTAssertEqual(descriptor.durationClass, .long)
        XCTAssertEqual(descriptor.intensityClass, .brisk)
        XCTAssertEqual(descriptor.englishLabel, "Long brisk walk")
    }

    func testRussianEasyTitleSetsEasyIntensity() {
        let descriptor = requireDescriptor(
            walkMinutes: 45,
            title: "Лёгкая прогулка",
            type: "recovery"
        )
        XCTAssertEqual(descriptor.intensityClass, .easy)
        XCTAssertEqual(descriptor.englishLabel, "Easy-pace walk")
        XCTAssertEqual(descriptor.russianLabel, "Прогулка в лёгком темпе")
    }

    // MARK: - Hike

    func testHikeUsesHikeNounNotEasyWalk() {
        let signals = CoachActivityLabelSignals(
            durationMinutes: 120,
            title: "Mountain Hike",
            type: "hiking"
        )
        let descriptor = try! XCTUnwrap(CoachActivityLabelBuilder.descriptor(for: signals))
        XCTAssertEqual(descriptor.locomotion, .hike)
        XCTAssertEqual(descriptor.durationClass, .long)
        XCTAssertEqual(descriptor.englishLabel, "Long hike")
        XCTAssertFalse(descriptor.englishLabel.lowercased().contains("walk"))
    }

    func testNonWalkReturnsNil() {
        let signals = CoachActivityLabelSignals(
            durationMinutes: 60,
            title: "Tempo Run",
            type: "running"
        )
        XCTAssertNil(CoachActivityLabelBuilder.descriptor(for: signals))
    }

    // MARK: - Helpers

    private func requireDescriptor(
        walkMinutes: Int,
        title: String = "Morning Walk",
        type: String = "walking",
        activeCalories: Int? = nil
    ) -> CoachActivityLabelDescriptor {
        let signals = CoachActivityLabelSignals(
            durationMinutes: walkMinutes,
            title: title,
            type: type,
            icon: "figure.walk",
            imageName: "figure.walk",
            activeCalories: activeCalories
        )
        return try! XCTUnwrap(CoachActivityLabelBuilder.descriptor(for: signals))
    }
}
