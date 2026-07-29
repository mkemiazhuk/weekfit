import XCTest
@testable import WeekFit

final class WeekFitWeatherCacheStoreTests: XCTestCase {

    func testCacheTTL_expiredAfter45Minutes() async {
        let store = WeekFitWeatherCacheStore()
        await store._testClearCache()

        let now = Date()
        let summary = WeekFitWeatherSummary(
            temperature: Measurement(value: 20, unit: UnitTemperature.celsius),
            feelsLike: Measurement(value: 21, unit: UnitTemperature.celsius),
            highTemperature: Measurement(value: 25, unit: UnitTemperature.celsius),
            lowTemperature: Measurement(value: 15, unit: UnitTemperature.celsius),
            symbolName: "sun.max",
            condition: .clear,
            humidityPercent: 50,
            windSpeed: Measurement(value: 10, unit: UnitSpeed.kilometersPerHour),
            uvIndex: 4,
            precipitationChance: 20
        )

        await store._testSetCache(summary: summary, now: now)

        let stillFresh = await store.cachedIfFresh(now: now.addingTimeInterval(44 * 60))
        XCTAssertNotNil(stillFresh)

        let expired = await store.cachedIfFresh(now: now.addingTimeInterval(46 * 60))
        XCTAssertNil(expired)
    }

    func testCachedSummaryAndFreshness_setsFreshnessFlag() async {
        let store = WeekFitWeatherCacheStore()
        await store._testClearCache()

        let now = Date()
        let summary = WeekFitWeatherSummary(
            temperature: Measurement(value: 5, unit: UnitTemperature.celsius),
            feelsLike: Measurement(value: 4, unit: UnitTemperature.celsius),
            highTemperature: nil,
            lowTemperature: nil,
            symbolName: "cloud",
            condition: .cloudy,
            humidityPercent: 40,
            windSpeed: Measurement(value: 8, unit: UnitSpeed.kilometersPerHour),
            uvIndex: 2,
            precipitationChance: nil
        )

        await store._testSetCache(summary: summary, now: now)

        let (cached1, isFresh1) = await store.cachedSummaryAndFreshness(now: now.addingTimeInterval(1))
        XCTAssertNotNil(cached1)
        XCTAssertTrue(isFresh1)

        let (cached2, isFresh2) = await store.cachedSummaryAndFreshness(now: now.addingTimeInterval((45 * 60) + 1))
        XCTAssertNotNil(cached2) // stale cache is still returned
        XCTAssertFalse(isFresh2)
    }
}

