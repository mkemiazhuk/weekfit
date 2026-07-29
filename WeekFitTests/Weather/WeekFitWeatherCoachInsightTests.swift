import XCTest
@testable import WeekFit

final class WeekFitWeatherCoachInsightTests: XCTestCase {

    func testRecommendation_precipitationChanceHigh() {
        let summary = makeSummary(
            tempC: 20,
            windKmh: 10,
            precipitationChance: 70,
            condition: .clear,
            uvIndex: 2
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(for: summary, isRussian: false)
        XCTAssertTrue(rec.contains("Rain is expected"))
    }

    func testRecommendation_stormCondition() {
        let summary = makeSummary(
            tempC: 18,
            windKmh: 10,
            precipitationChance: 10,
            condition: .storm,
            uvIndex: 2
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(for: summary, isRussian: false)
        XCTAssertTrue(rec.contains("Storm"))
    }

    func testRecommendation_windy() {
        let summary = makeSummary(
            tempC: 20,
            windKmh: 55,
            precipitationChance: 10,
            condition: .windy,
            uvIndex: 2
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(for: summary, isRussian: false)
        XCTAssertTrue(rec.contains("Wind conditions"))
    }

    func testRecommendation_hot() {
        let summary = makeSummary(
            tempC: 34,
            windKmh: 10,
            precipitationChance: 10,
            condition: .clear,
            uvIndex: 2
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(for: summary, isRussian: false)
        XCTAssertTrue(rec.contains("Warm conditions"))
    }

    func testRecommendation_cool() {
        let summary = makeSummary(
            tempC: -1,
            windKmh: 10,
            precipitationChance: 10,
            condition: .cloudy,
            uvIndex: 2
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(for: summary, isRussian: false)
        XCTAssertTrue(rec.contains("Cool conditions"))
    }

    func testRecommendation_veryHighUV() {
        let summary = makeSummary(
            tempC: 20,
            windKmh: 10,
            precipitationChance: 10,
            condition: .clear,
            uvIndex: 9
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(for: summary, isRussian: false)
        XCTAssertTrue(rec.contains("Very high UV"))
    }

    func testRecommendation_clearAndComfortable() {
        let summary = makeSummary(
            tempC: 20,
            windKmh: 10,
            precipitationChance: 10,
            condition: .clear,
            uvIndex: 4
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(for: summary, isRussian: false)
        XCTAssertTrue(rec.contains("Excellent conditions"))
    }

    func testRecommendation_cloudy() {
        let summary = makeSummary(
            tempC: 20,
            windKmh: 10,
            precipitationChance: 10,
            condition: .cloudy,
            uvIndex: 4
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(for: summary, isRussian: false)
        XCTAssertTrue(rec.contains("Overcast skies"))
    }

    // MARK: - Helpers

    private func makeSummary(
        tempC: Double,
        windKmh: Double,
        precipitationChance: Int?,
        condition: WeekFitWeatherCondition,
        uvIndex: Int
    ) -> WeekFitWeatherSummary {
        WeekFitWeatherSummary(
            temperature: Measurement(value: tempC, unit: UnitTemperature.celsius),
            feelsLike: Measurement(value: tempC, unit: UnitTemperature.celsius),
            highTemperature: nil,
            lowTemperature: nil,
            symbolName: "symbol",
            condition: condition,
            humidityPercent: 40,
            windSpeed: Measurement(value: windKmh, unit: UnitSpeed.kilometersPerHour),
            uvIndex: uvIndex,
            precipitationChance: precipitationChance
        )
    }
}

