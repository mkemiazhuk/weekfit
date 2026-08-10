import XCTest
@testable import WeekFit

final class WeekFitWeatherAdaptiveThemeTests: XCTestCase {

    func testPeriod_dawnAroundSunrise() {
        let sunrise = date(hour: 6, minute: 30)
        let sunset = date(hour: 20, minute: 0)
        let now = date(hour: 6, minute: 40)

        let period = WeekFitWeatherPeriod.resolve(
            now: now,
            sunrise: sunrise,
            sunset: sunset,
            isDaylightHint: true
        )
        XCTAssertEqual(period, .dawn)
    }

    func testPeriod_goldenHourBeforeSunset() {
        let sunrise = date(hour: 6, minute: 0)
        let sunset = date(hour: 20, minute: 0)
        let now = date(hour: 19, minute: 20)

        let period = WeekFitWeatherPeriod.resolve(
            now: now,
            sunrise: sunrise,
            sunset: sunset
        )
        XCTAssertEqual(period, .goldenHour)
    }

    func testPeriod_nightAfterDusk() {
        let sunrise = date(hour: 6, minute: 0)
        let sunset = date(hour: 20, minute: 0)
        let now = date(hour: 22, minute: 0)

        let period = WeekFitWeatherPeriod.resolve(
            now: now,
            sunrise: sunrise,
            sunset: sunset,
            isDaylightHint: false
        )
        XCTAssertEqual(period, .night)
    }

    func testTokens_nightUsesLightText() {
        let tokens = WeekFitWeatherTokens.resolve(
            period: .night,
            condition: .clear,
            temperatureC: 18,
            visibilityKm: 10,
            precipitationChance: 0,
            appAppearanceDark: true
        )
        XCTAssertTrue(tokens.isNightAtmosphere)
    }

    func testTokens_dayClearUsesDarkText() {
        let tokens = WeekFitWeatherTokens.resolve(
            period: .day,
            condition: .clear,
            temperatureC: 22,
            visibilityKm: 12,
            precipitationChance: 5
        )
        XCTAssertFalse(tokens.isNightAtmosphere)
    }

    func testTokens_dayClearInDarkAppUsesDarkChrome() {
        let lightApp = WeekFitWeatherTokens.resolve(
            period: .day,
            condition: .clear,
            temperatureC: 22,
            visibilityKm: 12,
            precipitationChance: 5,
            appAppearanceDark: false
        )
        let darkApp = WeekFitWeatherTokens.resolve(
            period: .day,
            condition: .clear,
            temperatureC: 22,
            visibilityKm: 12,
            precipitationChance: 5,
            appAppearanceDark: true
        )
        XCTAssertFalse(lightApp.isNightAtmosphere)
        XCTAssertTrue(darkApp.isNightAtmosphere)
        XCTAssertNotEqual(lightApp.backgroundPrimary, darkApp.backgroundPrimary)
        XCTAssertEqual(lightApp.primaryAccent, darkApp.primaryAccent)
    }

    func testTokens_nightInLightAppUsesLightChrome() {
        let lightApp = WeekFitWeatherTokens.resolve(
            period: .night,
            condition: .partlyCloudy,
            temperatureC: 18,
            visibilityKm: 10,
            precipitationChance: 0,
            appAppearanceDark: false
        )
        let darkApp = WeekFitWeatherTokens.resolve(
            period: .night,
            condition: .partlyCloudy,
            temperatureC: 18,
            visibilityKm: 10,
            precipitationChance: 0,
            appAppearanceDark: true
        )
        // Light app should not inherit the heavy dusk/night purple sheet.
        XCTAssertFalse(lightApp.isNightAtmosphere)
        XCTAssertTrue(darkApp.isNightAtmosphere)
        XCTAssertNotEqual(lightApp.backgroundPrimary, darkApp.backgroundPrimary)
    }

    func testTokens_duskInLightAppUsesLightChrome() {
        let tokens = WeekFitWeatherTokens.resolve(
            period: .dusk,
            condition: .partlyCloudy,
            temperatureC: 25,
            visibilityKm: 12,
            precipitationChance: 0,
            appAppearanceDark: false
        )
        XCTAssertFalse(tokens.isNightAtmosphere)
    }

    func testMetricsOrder_rainPrioritizesPrecipAndWind() {
        let summary = WeekFitWeatherSummary(
            temperature: Measurement(value: 16, unit: .celsius),
            feelsLike: Measurement(value: 15, unit: .celsius),
            highTemperature: Measurement(value: 18, unit: .celsius),
            lowTemperature: Measurement(value: 12, unit: .celsius),
            symbolName: "cloud.rain",
            condition: .rain,
            humidityPercent: 80,
            windSpeed: Measurement(value: 20, unit: .kilometersPerHour),
            uvIndex: 2,
            precipitationChance: 70,
            visibilityKilometers: 6
        )

        let secondary = WeekFitWeatherMetricsOrder.secondaryMetrics(for: summary, period: .day)
        XCTAssertEqual(secondary.first, .rainChance)
        XCTAssertTrue(secondary.contains(.wind))
    }

    func testMetricsOrder_fogPrioritizesVisibility() {
        let summary = WeekFitWeatherSummary(
            temperature: Measurement(value: 10, unit: .celsius),
            feelsLike: Measurement(value: 9, unit: .celsius),
            highTemperature: nil,
            lowTemperature: nil,
            symbolName: "cloud.fog",
            condition: .fog,
            humidityPercent: 95,
            windSpeed: Measurement(value: 5, unit: .kilometersPerHour),
            uvIndex: 1,
            precipitationChance: 10,
            visibilityKilometers: 0.6
        )

        let secondary = WeekFitWeatherMetricsOrder.secondaryMetrics(for: summary, period: .day)
        XCTAssertEqual(secondary.first, .visibility)
    }

    func testConditionMapping_partlyCloudy() {
        let condition = WeekFitWeatherCondition.from(
            symbolName: "cloud.sun.fill",
            rawDescription: "PartlyCloudy"
        )
        XCTAssertEqual(condition, .partlyCloudy)
    }

    func testRelevance_stormBadge() {
        let summary = WeekFitWeatherSummary(
            temperature: Measurement(value: 18, unit: .celsius),
            feelsLike: Measurement(value: 17, unit: .celsius),
            highTemperature: nil,
            lowTemperature: nil,
            symbolName: "cloud.bolt",
            condition: .storm,
            humidityPercent: 70,
            windSpeed: Measurement(value: 25, unit: .kilometersPerHour),
            uvIndex: 1,
            precipitationChance: 80
        )
        let content = WeekFitWeatherRelevance.content(for: summary, period: .day, isRussian: false)
        XCTAssertTrue(content.badge.lowercased().contains("indoor") || content.badge.lowercased().contains("stay"))
    }

    // MARK: - Helpers

    private func date(hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
}
