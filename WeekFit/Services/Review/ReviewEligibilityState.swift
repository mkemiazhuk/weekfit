import Foundation

struct ReviewEligibilityState: Equatable, Sendable {
    var firstAppUseDate: Date?
    var activeDayTimestamps: [TimeInterval]
    var meaningfulActionCount: Int
    var lastMeaningfulActionDate: Date?
    var lastFeedbackPromptDate: Date?
    var lastPromptedAppVersion: String?
    var nativeReviewRequestAttemptDate: Date?
    var lastFeedbackSentimentRaw: String?
    var isPermanentlyDismissed: Bool

    static let empty = ReviewEligibilityState(
        firstAppUseDate: nil,
        activeDayTimestamps: [],
        meaningfulActionCount: 0,
        lastMeaningfulActionDate: nil,
        lastFeedbackPromptDate: nil,
        lastPromptedAppVersion: nil,
        nativeReviewRequestAttemptDate: nil,
        lastFeedbackSentimentRaw: nil,
        isPermanentlyDismissed: false
    )

    var distinctActiveDayCount: Int {
        Set(activeDayTimestamps.map { Int($0) }).count
    }
}

enum ReviewEligibilityFailureReason: String, Equatable, Sendable {
    case missingFirstUse
    case insufficientCalendarDays
    case insufficientActiveDays
    case insufficientMeaningfulActions
    case noRecentMeaningfulAction
    case alreadyPromptedThisVersion
    case cooldownActive
    case permanentlyDismissed
    case uiBlocked
    case reviewDemoMode
}

struct ReviewEligibilityDecision: Equatable, Sendable {
    var isEligible: Bool
    var failureReasons: [ReviewEligibilityFailureReason]
    var daysSinceFirstUse: Int
    var distinctActiveDays: Int
    var meaningfulActionCount: Int

    static func ineligible(
        reasons: [ReviewEligibilityFailureReason],
        daysSinceFirstUse: Int = 0,
        distinctActiveDays: Int = 0,
        meaningfulActionCount: Int = 0
    ) -> ReviewEligibilityDecision {
        ReviewEligibilityDecision(
            isEligible: false,
            failureReasons: reasons,
            daysSinceFirstUse: daysSinceFirstUse,
            distinctActiveDays: distinctActiveDays,
            meaningfulActionCount: meaningfulActionCount
        )
    }
}

enum ReviewEligibilityRules {
    static let minimumCalendarDaysSinceFirstUse = 5
    static let minimumDistinctActiveDays = 5
    static let minimumMeaningfulActions = 5
    /// A meaningful action must have occurred within this many calendar days.
    static let recentActionWindowDays = 7
    static let promptCooldownDays = 120
}

enum ReviewEligibilityEvaluator {
    static func evaluate(
        state: ReviewEligibilityState,
        now: Date,
        calendar: Calendar = .current,
        currentAppVersion: String,
        isUIBlocked: Bool,
        isReviewDemoMode: Bool
    ) -> ReviewEligibilityDecision {
        var reasons: [ReviewEligibilityFailureReason] = []

        if isReviewDemoMode {
            reasons.append(.reviewDemoMode)
        }
        if isUIBlocked {
            reasons.append(.uiBlocked)
        }
        if state.isPermanentlyDismissed {
            reasons.append(.permanentlyDismissed)
        }

        guard let firstUse = state.firstAppUseDate else {
            reasons.append(.missingFirstUse)
            return .ineligible(
                reasons: reasons,
                distinctActiveDays: state.distinctActiveDayCount,
                meaningfulActionCount: state.meaningfulActionCount
            )
        }

        let daysSinceFirstUse = calendar.dateComponents([.day], from: startOfDay(firstUse, calendar), to: startOfDay(now, calendar)).day ?? 0
        let distinctActiveDays = state.distinctActiveDayCount
        let actionCount = state.meaningfulActionCount

        if daysSinceFirstUse < ReviewEligibilityRules.minimumCalendarDaysSinceFirstUse {
            reasons.append(.insufficientCalendarDays)
        }
        if distinctActiveDays < ReviewEligibilityRules.minimumDistinctActiveDays {
            reasons.append(.insufficientActiveDays)
        }
        if actionCount < ReviewEligibilityRules.minimumMeaningfulActions {
            reasons.append(.insufficientMeaningfulActions)
        }

        if let lastAction = state.lastMeaningfulActionDate {
            let daysSinceAction = calendar.dateComponents(
                [.day],
                from: startOfDay(lastAction, calendar),
                to: startOfDay(now, calendar)
            ).day ?? Int.max
            if daysSinceAction > ReviewEligibilityRules.recentActionWindowDays {
                reasons.append(.noRecentMeaningfulAction)
            }
        } else {
            reasons.append(.noRecentMeaningfulAction)
        }

        if let promptedVersion = state.lastPromptedAppVersion,
           promptedVersion == currentAppVersion {
            reasons.append(.alreadyPromptedThisVersion)
        }

        if let lastPrompt = state.lastFeedbackPromptDate {
            let daysSincePrompt = calendar.dateComponents(
                [.day],
                from: startOfDay(lastPrompt, calendar),
                to: startOfDay(now, calendar)
            ).day ?? 0
            if daysSincePrompt < ReviewEligibilityRules.promptCooldownDays {
                reasons.append(.cooldownActive)
            }
        }

        return ReviewEligibilityDecision(
            isEligible: reasons.isEmpty,
            failureReasons: reasons,
            daysSinceFirstUse: daysSinceFirstUse,
            distinctActiveDays: distinctActiveDays,
            meaningfulActionCount: actionCount
        )
    }

    private static func startOfDay(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }
}
