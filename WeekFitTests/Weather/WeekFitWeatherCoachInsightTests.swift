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
        XCTAssertTrue(rec.contains("rain") || rec.contains("Rain") || rec.contains("indoor"))
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
        XCTAssertTrue(rec.contains("storm") || rec.contains("Storm"))
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
        XCTAssertTrue(rec.contains("wind") || rec.contains("Wind"))
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
        XCTAssertTrue(rec.contains("Hydrate") || rec.contains("light activity"))
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
        XCTAssertTrue(rec.contains("layers") || rec.contains("warm-up"))
    }

    func testRecommendation_veryHighUV() {
        let summary = makeSummary(
            tempC: 20,
            windKmh: 10,
            precipitationChance: 10,
            condition: .clear,
            uvIndex: 9,
            isDaylight: true,
            sunrise: date(hour: 6),
            sunset: date(hour: 20)
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(
            for: summary,
            period: .day,
            isRussian: false
        )
        XCTAssertTrue(rec.contains("UV"))
    }

    func testRecommendation_clearAndComfortable() {
        let summary = makeSummary(
            tempC: 20,
            windKmh: 10,
            precipitationChance: 10,
            condition: .clear,
            uvIndex: 4,
            isDaylight: true,
            sunrise: date(hour: 6),
            sunset: date(hour: 20)
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(
            for: summary,
            period: .day,
            isRussian: false
        )
        XCTAssertTrue(rec.contains("Excellent") || rec.contains("outdoor"))
    }

    func testRecommendation_cloudy() {
        let summary = makeSummary(
            tempC: 20,
            windKmh: 10,
            precipitationChance: 10,
            condition: .cloudy,
            uvIndex: 4,
            isDaylight: true,
            sunrise: date(hour: 6),
            sunset: date(hour: 20)
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(
            for: summary,
            period: .day,
            isRussian: false
        )
        XCTAssertTrue(rec.contains("diffused") || rec.contains("comfortable"))
    }

    func testRecommendation_nightPrefersLitRoute() {
        let summary = makeSummary(
            tempC: 18,
            windKmh: 8,
            precipitationChance: 5,
            condition: .clear,
            uvIndex: 0,
            isDaylight: false
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(
            for: summary,
            period: .night,
            isRussian: false
        )
        XCTAssertTrue(rec.contains("well-lit") || rec.contains("visibility"))
    }

    func testRecommendation_avoidsGenericFallback() {
        let summary = makeSummary(
            tempC: 12,
            windKmh: 12,
            precipitationChance: 10,
            condition: .other,
            uvIndex: 3,
            isDaylight: true,
            sunrise: date(hour: 6),
            sunset: date(hour: 20)
        )

        let rec = WeekFitWeatherCoachInsight.recommendation(
            for: summary,
            period: .day,
            isRussian: false
        )
        XCTAssertFalse(rec.contains("Check conditions before heading out"))
    }

    // MARK: - Helpers

    private func date(hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = hour
        return calendar.date(from: components)!
    }

    private func makeSummary(
        tempC: Double,
        windKmh: Double,
        precipitationChance: Int?,
        condition: WeekFitWeatherCondition,
        uvIndex: Int,
        isDaylight: Bool = true,
        sunrise: Date? = nil,
        sunset: Date? = nil
    ) -> WeekFitWeatherSummary {
        WeekFitWeatherSummary(
            temperature: Measurement(value: tempC, unit: UnitTemperature.celsius),
            feelsLike: Measurement(value: tempC, unit: UnitTemperature.celsius),
            highTemperature: nil,
            lowTemperature: nil,
            symbolName: "symbol",
            condition: condition,
            isDaylight: isDaylight,
            humidityPercent: 40,
            windSpeed: Measurement(value: windKmh, unit: UnitSpeed.kilometersPerHour),
            uvIndex: uvIndex,
            precipitationChance: precipitationChance,
            sunrise: sunrise,
            sunset: sunset
        )
    }
}
