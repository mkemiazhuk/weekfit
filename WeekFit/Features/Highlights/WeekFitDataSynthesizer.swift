import Foundation

enum HealthMetric: String, CaseIterable, Hashable {
    case recovery
    case activity
    case nutrition
    case sleep
}

enum TrendDirection: String, CaseIterable, Hashable {
    case up
    case down
    case stable
}

struct DailyMetrics: Hashable {
    let date: Date
    let recoveryScore: Int
    let activityVolume: Int
    let nutritionScore: Int
    let sleepConsistency: Int
}

struct MetricSnapshot: Hashable {
    let metric: HealthMetric
    let currentBaseline: Int
    let trend: TrendDirection
}

struct HighlightStory: Hashable {
    let headline: String
    let bodyNarrative: String
    let primaryMetric: HealthMetric
    let trend: TrendDirection
    let trendLabel: String
    let focusChartMetric: HealthMetric
    let snapshots: [MetricSnapshot]
    let isEmptyState: Bool
}

final class WeekFitDataSynthesizer {

    static func generateMonthlyHighlight(from data: [DailyMetrics]) -> HighlightStory {
        WeekFitDataSynthesizer().generateMonthlyHighlight(from: data)
    }

    func generateMonthlyHighlight(from data: [DailyMetrics]) -> HighlightStory {
        guard data.count >= 20 else {
            return Self.emptyStateStory
        }

        let sortedWindow = data
            .sorted { $0.date < $1.date }
            .suffix(30)
            .filter(\.hasAnySignal)

        guard sortedWindow.count >= 20 else {
            return Self.emptyStateStory
        }

        let midpoint = sortedWindow.count / 2
        let firstHalf = Array(sortedWindow.prefix(midpoint))
        let lastHalf = Array(sortedWindow.suffix(sortedWindow.count - midpoint))
        let baselines = MetricBaselines(
            recovery: Self.average(lastHalf, \.recoveryScore),
            activity: Self.average(lastHalf, \.activityVolume),
            nutrition: Self.average(lastHalf, \.nutritionScore),
            sleep: Self.average(lastHalf, \.sleepConsistency)
        )
        let changes = MetricChanges(
            recovery: Self.percentageChange(from: Self.average(firstHalf, \.recoveryScore), to: baselines.recovery),
            activity: Self.percentageChange(from: Self.average(firstHalf, \.activityVolume), to: baselines.activity),
            nutrition: Self.percentageChange(from: Self.average(firstHalf, \.nutritionScore), to: baselines.nutrition),
            sleep: Self.percentageChange(from: Self.average(firstHalf, \.sleepConsistency), to: baselines.sleep)
        )
        let snapshots = Self.metricSnapshots(baselines: baselines, changes: changes)

        if changes.activity > 10, changes.recovery < -5 {
            return HighlightStory(
                headline: "Activity is up, but efficiency is dropping",
                bodyNarrative: "Your training volume increased by \(changes.activity)%, but your recovery metrics didn't match the output. Your body is running on a temporary deficit, causing your overall readiness to trend downward.",
                primaryMetric: .activity,
                trend: .down,
                trendLabel: Self.statusLabel(for: .down),
                focusChartMetric: .activity,
                snapshots: snapshots,
                isEmptyState: false
            )
        }

        if changes.sleep > 8, changes.recovery > 5 {
            return HighlightStory(
                headline: "Recovery became more predictable",
                bodyNarrative: "Your sleep schedule became more consistent by \(changes.sleep)%, helping your recovery stabilize and bounce back efficiently while training stayed steady.",
                primaryMetric: .sleep,
                trend: .up,
                trendLabel: Self.statusLabel(for: .up),
                focusChartMetric: .sleep,
                snapshots: snapshots,
                isEmptyState: false
            )
        }

        if changes.activity < -10, Self.recoveryOrSleepDroppedEarly(in: firstHalf) {
            return HighlightStory(
                headline: "Training took a back seat this month",
                bodyNarrative: "And it was likely the right call. Your recovery baselines dropped early in the cycle, and you naturally scaled back your activity volume to prevent burnout and protect your body.",
                primaryMetric: .recovery,
                trend: .down,
                trendLabel: Self.statusLabel(for: .down),
                focusChartMetric: .recovery,
                snapshots: snapshots,
                isEmptyState: false
            )
        }

        let downCount = snapshots.filter { $0.trend == .down }.count
        if downCount >= 3 {
            return HighlightStory(
                headline: "Your rhythm needs attention",
                bodyNarrative: "Recovery, activity, and sleep moved lower this month. WeekFit is watching whether this is a short dip or a pattern that needs more recovery support.",
                primaryMetric: .recovery,
                trend: .down,
                trendLabel: Self.statusLabel(for: .down),
                focusChartMetric: .recovery,
                snapshots: snapshots,
                isEmptyState: false
            )
        }

        let activityTrend = Self.trendDirection(for: changes.activity)
        let recoveryTrend = Self.trendDirection(for: changes.recovery)
        let sleepTrend = Self.trendDirection(for: changes.sleep)

        if recoveryTrend == .stable, activityTrend == .down || sleepTrend == .down {
            return HighlightStory(
                headline: "Recovery stayed resilient",
                bodyNarrative: "Your recovery stayed steady despite lighter activity and uneven sleep. A few weaker days did not change the overall pattern.",
                primaryMetric: .recovery,
                trend: .stable,
                trendLabel: Self.statusLabel(for: .stable),
                focusChartMetric: .recovery,
                snapshots: snapshots,
                isEmptyState: false
            )
        }

        return HighlightStory(
            headline: "You've found your rhythm",
            bodyNarrative: "Recovery stayed steady because your sleep timing and training load were more consistent this month.",
            primaryMetric: .recovery,
            trend: .stable,
            trendLabel: Self.statusLabel(for: .stable),
            focusChartMetric: .recovery,
            snapshots: snapshots,
            isEmptyState: false
        )
    }
}

private extension WeekFitDataSynthesizer {

    struct MetricBaselines {
        let recovery: Double
        let activity: Double
        let nutrition: Double
        let sleep: Double
    }

    struct MetricChanges {
        let recovery: Int
        let activity: Int
        let nutrition: Int
        let sleep: Int
    }

    static var emptyStateStory: HighlightStory {
        HighlightStory(
            headline: "We're studying your patterns...",
            bodyNarrative: "WeekFit needs at least 20 days of recovery, activity, nutrition, and sleep data before it can synthesize your first monthly story.",
            primaryMetric: .recovery,
            trend: .stable,
            trendLabel: statusLabel(for: .stable),
            focusChartMetric: .recovery,
            snapshots: HealthMetric.allCases.map {
                MetricSnapshot(metric: $0, currentBaseline: 0, trend: .stable)
            },
            isEmptyState: true
        )
    }

    static func average(_ data: [DailyMetrics], _ keyPath: KeyPath<DailyMetrics, Int>) -> Double {
        guard !data.isEmpty else { return 0 }
        let total = data.reduce(0) { $0 + $1[keyPath: keyPath] }
        return Double(total) / Double(data.count)
    }

    static func percentageChange(from baseline: Double, to current: Double) -> Int {
        guard baseline > 0 else { return 0 }
        return Int(((current - baseline) / baseline * 100).rounded())
    }

    static func trendDirection(for change: Int) -> TrendDirection {
        if change > 5 {
            return .up
        }

        if change < -5 {
            return .down
        }

        return .stable
    }

    static func statusLabel(for trend: TrendDirection) -> String {
        switch trend {
        case .up:
            return "IMPROVING"
        case .down:
            return "NEEDS ATTENTION"
        case .stable:
            return "STABLE"
        }
    }

    static func metricSnapshots(
        baselines: MetricBaselines,
        changes: MetricChanges
    ) -> [MetricSnapshot] {
        [
            MetricSnapshot(metric: .recovery, currentBaseline: Int(baselines.recovery.rounded()), trend: trendDirection(for: changes.recovery)),
            MetricSnapshot(metric: .activity, currentBaseline: Int(baselines.activity.rounded()), trend: trendDirection(for: changes.activity)),
            MetricSnapshot(metric: .nutrition, currentBaseline: Int(baselines.nutrition.rounded()), trend: trendDirection(for: changes.nutrition)),
            MetricSnapshot(metric: .sleep, currentBaseline: Int(baselines.sleep.rounded()), trend: trendDirection(for: changes.sleep))
        ]
    }

    static func recoveryOrSleepDroppedEarly(in firstHalf: [DailyMetrics]) -> Bool {
        guard firstHalf.count >= 6 else { return false }

        let earlyCount = max(3, firstHalf.count / 2)
        let earlyDays = Array(firstHalf.prefix(earlyCount))
        let laterBaselineDays = Array(firstHalf.suffix(firstHalf.count - earlyCount))

        let earlyRecoveryChange = percentageChange(
            from: average(laterBaselineDays, \.recoveryScore),
            to: average(earlyDays, \.recoveryScore)
        )
        let earlySleepChange = percentageChange(
            from: average(laterBaselineDays, \.sleepConsistency),
            to: average(earlyDays, \.sleepConsistency)
        )

        return earlyRecoveryChange < -5 || earlySleepChange < -5
    }
}

private extension DailyMetrics {

    var hasAnySignal: Bool {
        recoveryScore > 0 ||
            activityVolume > 0 ||
            nutritionScore > 0 ||
            sleepConsistency > 0
    }
}

#if DEBUG
extension WeekFitDataSynthesizer {

    static func makeCompensationTrapMockData(
        calendar: Calendar = .current,
        startDate: Date = Date()
    ) -> [DailyMetrics] {
        (0..<30).compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day, to: startDate) else { return nil }
            let isRecentHalf = day >= 15

            return DailyMetrics(
                date: date,
                recoveryScore: isRecentHalf ? 68 : 76,
                activityVolume: isRecentHalf ? 620 : 500,
                nutritionScore: isRecentHalf ? 82 : 80,
                sleepConsistency: isRecentHalf ? 76 : 75
            )
        }
    }

    static func mockMonthlyHighlight() -> HighlightStory {
        generateMonthlyHighlight(from: makeCompensationTrapMockData())
    }
}
#endif
