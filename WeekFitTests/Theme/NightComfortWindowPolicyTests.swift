import CoreLocation
import XCTest
@testable import WeekFit

final class NightComfortWindowPolicyTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
        return calendar
    }

    private func date(
        year: Int = 2026,
        month: Int = 6,
        day: Int = 25,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }

    func testPreferenceOffReturnsZeroBlend() {
        let blend = NightComfortWindowPolicy.blendFactor(
            NightComfortWindowPolicy.Input(
                now: date(hour: 22),
                sunset: date(hour: 20, minute: 30),
                sunrise: date(hour: 6, minute: 30),
                calendar: calendar,
                preference: .off
            )
        )

        XCTAssertEqual(blend, 0, accuracy: 0.001)
    }

    func testPreferenceAlwaysOnReturnsFullBlend() {
        let blend = NightComfortWindowPolicy.blendFactor(
            NightComfortWindowPolicy.Input(
                now: date(hour: 12),
                sunset: date(hour: 20, minute: 30),
                sunrise: date(hour: 6, minute: 30),
                calendar: calendar,
                preference: .alwaysOn
            )
        )

        XCTAssertEqual(blend, 1, accuracy: 0.001)
    }

    func testFallbackAtEightPMStartsEveningRamp() {
        let blend = NightComfortWindowPolicy.blendFactor(
            NightComfortWindowPolicy.Input(
                now: date(hour: 20, minute: 22),
                sunset: nil,
                sunrise: nil,
                calendar: calendar,
                preference: .automatic
            )
        )

        XCTAssertGreaterThan(blend, 0.4)
        XCTAssertLessThan(blend, 0.6)
    }

    func testFallbackLateNightIsFullComfort() {
        let blend = NightComfortWindowPolicy.blendFactor(
            NightComfortWindowPolicy.Input(
                now: date(hour: 23),
                sunset: nil,
                sunrise: nil,
                calendar: calendar,
                preference: .automatic
            )
        )

        XCTAssertEqual(blend, 1, accuracy: 0.001)
    }

    func testFallbackMiddayIsVivid() {
        let blend = NightComfortWindowPolicy.blendFactor(
            NightComfortWindowPolicy.Input(
                now: date(hour: 14),
                sunset: nil,
                sunrise: nil,
                calendar: calendar,
                preference: .automatic
            )
        )

        XCTAssertEqual(blend, 0, accuracy: 0.001)
    }

    func testSolarEveningRampUsesSunset() {
        let sunset = date(hour: 20, minute: 30)
        let blend = NightComfortWindowPolicy.blendFactor(
            NightComfortWindowPolicy.Input(
                now: date(hour: 21, minute: 0),
                sunset: sunset,
                sunrise: date(hour: 6, minute: 30),
                calendar: calendar,
                preference: .automatic
            )
        )

        XCTAssertGreaterThan(blend, 0.4)
        XCTAssertLessThanOrEqual(blend, 0.55)
    }

    func testSolarMorningRampFadesOut() {
        let sunrise = date(hour: 7, minute: 0)
        let blend = NightComfortWindowPolicy.blendFactor(
            NightComfortWindowPolicy.Input(
                now: date(hour: 7, minute: 10),
                sunset: date(hour: 20, minute: 30),
                sunrise: sunrise,
                calendar: calendar,
                preference: .automatic
            )
        )

        XCTAssertGreaterThan(blend, 0)
        XCTAssertLessThan(blend, 0.45)
    }

    func testSolarProviderReturnsOrderedSunriseBeforeSunset() {
        let coordinate = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)
        let day = date(hour: 12)
        let timeZone = TimeZone(identifier: "Europe/Moscow")!

        let solar = NightComfortSolarTimeProvider.solarTimes(
            on: day,
            coordinate: coordinate,
            timeZone: timeZone,
            calendar: calendar
        )

        XCTAssertNotNil(solar)
        XCTAssertLessThan(solar!.sunrise, solar!.sunset)
    }
}
