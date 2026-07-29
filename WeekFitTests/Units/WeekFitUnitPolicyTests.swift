import XCTest
@testable import WeekFit

final class WeekFitUnitPolicyTests: XCTestCase {

    func testResolvedSystemAutomatic_metricLocale() {
        let locale = Locale(identifier: "fr_FR") // expected metric device settings
        let resolved = WeekFitUnitPolicy.resolvedSystem(for: .automatic, locale: locale)
        XCTAssertEqual(resolved, .metric)
    }

    func testResolvedSystemAutomatic_usLocale() {
        let locale = Locale(identifier: "en_US")
        let resolved = WeekFitUnitPolicy.resolvedSystem(for: .automatic, locale: locale)
        XCTAssertEqual(resolved, .us)
    }

    func testResolvedSystemAutomatic_ukLocale() {
        let locale = Locale(identifier: "en_GB")
        let resolved = WeekFitUnitPolicy.resolvedSystem(for: .automatic, locale: locale)
        XCTAssertEqual(resolved, .uk)
    }

    func testTemperatureValueForBadge_usConvertsCelsiusToFahrenheit() {
        let c = Measurement(value: 23, unit: UnitTemperature.celsius)
        let value = WeekFitUnitPolicy.temperatureValueForBadge(c, system: .us)
        XCTAssertEqual(value, 73) // 23C ≈ 73.4F
    }

    func testTemperatureValueForBadge_metricConvertsFahrenheitToCelsius() {
        let f = Measurement(value: 32, unit: UnitTemperature.fahrenheit)
        let value = WeekFitUnitPolicy.temperatureValueForBadge(f, system: .metric)
        XCTAssertEqual(value, 0) // 32F = 0C
    }

    func testDistanceConversion_usUsesMiles() {
        // 5.74 km ≈ 3.57 mi
        let miles = WeekFitUnitPolicy.distanceValue(kilometers: 5.74, system: .us)
        XCTAssertEqual(miles, 3.57, accuracy: 0.01)
        XCTAssertEqual(WeekFitUnitPolicy.distanceUnitLabel(for: .us), "mi")
    }

    func testSpeedConversion_usUsesMph() {
        // 5.8 km/h ≈ 3.6 mph
        let mph = WeekFitUnitPolicy.speedValue(kilometersPerHour: 5.8, system: .us)
        XCTAssertEqual(mph, 3.6, accuracy: 0.05)
        XCTAssertEqual(WeekFitUnitPolicy.speedUnitLabel(for: .us), "mph")
    }

    func testElevationConversion_usUsesFeet() {
        // 39 m ≈ 128 ft
        let feet = WeekFitUnitPolicy.elevationValue(meters: 39, system: .us)
        XCTAssertEqual(feet, 128, accuracy: 1)
        XCTAssertEqual(WeekFitUnitPolicy.elevationUnitLabel(for: .us), "ft")
    }

    func testMetricKeepsKilometers() {
        XCTAssertEqual(WeekFitUnitPolicy.distanceValue(kilometers: 5.74, system: .metric), 5.74, accuracy: 0.001)
        XCTAssertEqual(WeekFitUnitPolicy.speedValue(kilometersPerHour: 5.8, system: .metric), 5.8, accuracy: 0.001)
        XCTAssertEqual(WeekFitUnitPolicy.elevationValue(meters: 39, system: .metric), 39, accuracy: 0.001)
    }
}

