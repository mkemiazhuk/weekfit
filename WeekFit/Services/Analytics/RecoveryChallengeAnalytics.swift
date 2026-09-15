import Foundation

enum RecoveryChallengeAnalytics {
    private static var analytics: AnalyticsTracking { AppAnalytics.shared }

    static func cardViewed(kind: String) {
        analytics.track(
            .recoveryChallengeCardViewed,
            parameters: [AnalyticsParameterKey.source: kind]
        )
    }

    static func overviewOpened(source: String) {
        analytics.track(
            .recoveryChallengeOverviewOpened,
            parameters: [AnalyticsParameterKey.source: source]
        )
    }

    static func enrolled() {
        analytics.track(.recoveryChallengeEnrolled)
    }

    static func dayCompleted(dayIndex: Int) {
        analytics.track(
            .recoveryChallengeDayCompleted,
            parameters: ["day_index": String(dayIndex)]
        )
    }

    static func summaryViewed(completedCount: Int) {
        analytics.track(
            .recoveryChallengeSummaryViewed,
            parameters: ["completed_count": String(completedCount)]
        )
    }

    static func habitChosen() {
        analytics.track(.recoveryChallengeHabitChosen)
    }
}
