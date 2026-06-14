import XCTest
@testable import WeekFit

final class WeekFitDataSynthesizerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
        WeekFitWarmLocalizationCache()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
        WeekFitWarmLocalizationCache()
        super.tearDown()
    }

    func testCompensationTrapPrioritizesActivityWhenRecoveryDrops() {
        let story = WeekFitDataSynthesizer.generateMonthlyHighlight(
            from: Self.makeMonthlyMetrics { day in
                DailyMetrics(
                    date: Self.date(day),
                    recoveryScore: day < 15 ? 76 : 68,
                    activityVolume: day < 15 ? 500 : 620,
                    nutritionScore: 80,
                    sleepConsistency: 75
                )
            }
        )

        XCTAssertEqual(story.headline, "Activity is up, but efficiency is dropping")
        XCTAssertEqual(story.primaryMetric, .activity)
        XCTAssertEqual(story.trend, .down)
        XCTAssertEqual(story.trendLabel, "NEEDS ATTENTION")
        XCTAssertEqual(story.focusChartMetric, .activity)
        XCTAssertEqual(story.snapshots.count, 4)
        XCTAssertFalse(story.isEmptyState)
        XCTAssertEqual(story.snapshots.first { $0.metric == .activity }?.currentBaseline, 620)
        XCTAssertEqual(story.snapshots.first { $0.metric == .activity }?.trend, .up)
    }

    func testPositiveStabilizationPrioritizesSleepWhenRecoveryImproves() {
        let story = WeekFitDataSynthesizer.generateMonthlyHighlight(
            from: Self.makeMonthlyMetrics { day in
                DailyMetrics(
                    date: Self.date(day),
                    recoveryScore: day < 15 ? 70 : 75,
                    activityVolume: 500,
                    nutritionScore: 82,
                    sleepConsistency: day < 15 ? 70 : 78
                )
            }
        )

        XCTAssertEqual(story.headline, "Recovery became more predictable")
        XCTAssertEqual(story.primaryMetric, .sleep)
        XCTAssertEqual(story.trend, .up)
        XCTAssertEqual(story.trendLabel, "IMPROVING")
        XCTAssertEqual(story.focusChartMetric, .sleep)
        XCTAssertEqual(story.snapshots.first { $0.metric == .sleep }?.trend, .up)
    }

    func testInsufficientDataReturnsFormingStory() {
        let story = WeekFitDataSynthesizer.generateMonthlyHighlight(
            from: Self.makeMonthlyMetrics(days: 19) { day in
                DailyMetrics(
                    date: Self.date(day),
                    recoveryScore: 80,
                    activityVolume: 450,
                    nutritionScore: 85,
                    sleepConsistency: 82
                )
            }
        )

        XCTAssertEqual(story.headline, "We're studying your patterns...")
        XCTAssertEqual(story.trend, .stable)
        XCTAssertEqual(story.trendLabel, "STABLE")
        XCTAssertEqual(story.snapshots.count, 4)
        XCTAssertTrue(story.isEmptyState)
    }

    func testRussianLocaleLocalizesPresentationWithoutChangingStoryLogic() {
        UserDefaults.standard.set(AppLanguage.russian.rawValue, forKey: AppLanguage.storageKey)
        WeekFitWarmLocalizationCache()

        let story = WeekFitDataSynthesizer.generateMonthlyHighlight(
            from: Self.makeMonthlyMetrics { day in
                DailyMetrics(
                    date: Self.date(day),
                    recoveryScore: day < 15 ? 76 : 68,
                    activityVolume: day < 15 ? 500 : 620,
                    nutritionScore: 80,
                    sleepConsistency: 75
                )
            }
        )

        XCTAssertEqual(story.headline, "Активность выросла, но эффективность падает")
        XCTAssertEqual(story.primaryMetric, .activity)
        XCTAssertEqual(story.trend, .down)
        XCTAssertEqual(story.trendLabel, "НУЖНО ВНИМАНИЕ")
        XCTAssertEqual(story.focusChartMetric, .activity)
        XCTAssertFalse(story.isEmptyState)
    }

    func testDebugMockDataDemonstratesExecution() {
        #if DEBUG
        let story = WeekFitDataSynthesizer.mockMonthlyHighlight()

        XCTAssertEqual(story.headline, "Activity is up, but efficiency is dropping")
        XCTAssertEqual(story.focusChartMetric, .activity)
        #endif
    }
}

private extension WeekFitDataSynthesizerTests {

    static func makeMonthlyMetrics(
        days: Int = 30,
        _ builder: (Int) -> DailyMetrics
    ) -> [DailyMetrics] {
        (0..<days).map(builder)
    }

    static func date(_ dayOffset: Int) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 1, day: 1 + dayOffset)
        ) ?? Date(timeIntervalSince1970: TimeInterval(dayOffset * 86_400))
    }
}
