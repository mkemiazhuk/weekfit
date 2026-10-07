import Foundation

// MARK: - Questions & period

enum AskCoachQuestion: String, CaseIterable, Identifiable, Sendable {
    case weeklyOverview
    case recovery
    case consistency

    var id: String { rawValue }

    var defaultPeriod: AskCoachPeriodLength {
        switch self {
        case .weeklyOverview: return .last7Days
        case .recovery, .consistency: return .last28Days
        }
    }

    var titleKey: String {
        switch self {
        case .weeklyOverview: return "coach.ask.question.week"
        case .recovery: return "coach.ask.question.recovery"
        case .consistency: return "coach.ask.question.consistency"
        }
    }
}

enum AskCoachPeriodLength: String, CaseIterable, Identifiable, Sendable {
    case last7Days
    case last28Days

    var id: String { rawValue }

    var dayCount: Int {
        switch self {
        case .last7Days: return 7
        case .last28Days: return 28
        }
    }

    var titleKey: String {
        switch self {
        case .last7Days: return "coach.ask.period.last7"
        case .last28Days: return "coach.ask.period.last28"
        }
    }
}

struct AskCoachDateRange: Equatable, Sendable {
    /// Inclusive start-of-day.
    let start: Date
    /// Inclusive start-of-day of the last day in the range.
    let endInclusive: Date
    let dayCount: Int

    var dayStarts: [Date] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        return (0..<dayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }
}

enum AskCoachFollowUp: String, CaseIterable, Identifiable, Sendable {
    case myRecovery
    case shorterSleepDays
    case comparePrevious
    case workoutDistribution
    case nextWeekFocus
    case backToQuestions

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .myRecovery: return "coach.ask.followUp.myRecovery"
        case .shorterSleepDays: return "coach.ask.followUp.shorterSleep"
        case .comparePrevious: return "coach.ask.followUp.comparePrevious"
        case .workoutDistribution: return "coach.ask.followUp.distribution"
        case .nextWeekFocus: return "coach.ask.followUp.focus"
        case .backToQuestions: return "coach.ask.followUp.back"
        }
    }

    /// User-facing follow-up prompt shown in the conversation thread.
    var promptText: CoachBilingualText {
        switch self {
        case .myRecovery:
            return .en("How am I recovering?", "Как я восстанавливаюсь?")
        case .shorterSleepDays:
            return .en("Which days had shorter sleep?", "В какие дни сон был короче?")
        case .comparePrevious:
            return .en("How does that compare?", "Как это сравнивается?")
        case .workoutDistribution:
            return .en("How were my activities spread?", "Как распределялась активность?")
        case .nextWeekFocus:
            return .en("What should I focus on next week?", "На чём сфокусироваться на следующей неделе?")
        case .backToQuestions:
            return .en("Ask another question", "Задать другой вопрос")
        }
    }
}

enum AskCoachFocusKind: String, Codable, CaseIterable, Sendable {
    case consistentBedtime
    case protectRecovery
    case keepTrainingDays
    case steadySleepDuration

    var titleKey: String {
        switch self {
        case .consistentBedtime: return "coach.ask.focus.consistentBedtime"
        case .protectRecovery: return "coach.ask.focus.protectRecovery"
        case .keepTrainingDays: return "coach.ask.focus.keepTrainingDays"
        case .steadySleepDuration: return "coach.ask.focus.steadySleep"
        }
    }

    var detailKey: String {
        switch self {
        case .consistentBedtime: return "coach.ask.focus.consistentBedtime.detail"
        case .protectRecovery: return "coach.ask.focus.protectRecovery.detail"
        case .keepTrainingDays: return "coach.ask.focus.keepTrainingDays.detail"
        case .steadySleepDuration: return "coach.ask.focus.steadySleep.detail"
        }
    }
}

struct AskCoachWeeklyFocus: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: AskCoachFocusKind
    /// Inclusive calendar start (start of day).
    let startDayKey: String
    /// Inclusive calendar end (start of day).
    let endDayKey: String
    let createdAt: Date
    var dismissed: Bool

    var isActive: Bool { !dismissed }

    func includes(dayKey: String) -> Bool {
        dayKey >= startDayKey && dayKey <= endDayKey
    }

    func hasEnded(on dayKey: String) -> Bool {
        !dismissed && dayKey > endDayKey
    }
}

// MARK: - Day / period metrics

struct AskCoachCompletedSession: Equatable, Identifiable, Sendable {
    enum Source: String, Sendable {
        case healthKit
        case localCompleted
    }

    let id: String
    let startDate: Date
    let durationMinutes: Int
    let healthKitWorkoutUUID: UUID?
    let source: Source
    /// Planner-sourced planned slot (not Quick Start). Used only for planned-vs-completed.
    let isPlannerSourced: Bool
    /// True for recovery-tier sessions (walk cool-down, yoga, breathing, etc.).
    let isRecoveryActivity: Bool
}

struct AskCoachConversationTurn: Identifiable, Equatable {
    let id: UUID
    let userPrompt: CoachBilingualText
    var answer: AskCoachAnswer?
    var isLoading: Bool
    var detailsExpanded: Bool
}

struct AskCoachDayMetrics: Equatable, Identifiable, Sendable {
    let dayStart: Date
    let dayKey: String
    /// Nil when sleep was not recorded (missing ≠ zero).
    let sleepMinutes: Int?
    /// Nil when recovery score unavailable.
    let recoveryPercent: Int?
    /// Nil when HRV unavailable; never treat 0 as a valid sample.
    let hrvSDNN: Double?
    /// Nil when RHR unavailable; never treat 0 as a valid sample.
    let restingHeartRate: Double?
    let completedSessions: [AskCoachCompletedSession]
    /// Planner workout/recovery slots scheduled this day (excluding meals / skipped).
    let plannedPlannerSessionCount: Int
    /// Among planner slots, how many were completed.
    let completedPlannerSessionCount: Int
    /// True when training fields were populated for the day (observation or sessions).
    let hasTrainingSignal: Bool

    var id: String { dayKey }

    var completedSessionCount: Int { completedSessions.count }

    var completedDurationMinutes: Int {
        completedSessions.reduce(0) { $0 + $1.durationMinutes }
    }

    var isActiveTrainingDay: Bool { completedSessionCount > 0 }
}

struct AskCoachMetricCoverage: Equatable, Sendable {
    let metricKey: String
    let observedDays: Int
    let totalDays: Int

    var summaryKeyArguments: (observed: Int, total: Int) {
        (observedDays, totalDays)
    }
}

struct AskCoachEvidenceItem: Equatable, Identifiable, Sendable {
    let id: String
    let title: CoachBilingualText
    let detail: CoachBilingualText?
}

struct AskCoachSuggestedFocus: Equatable, Sendable {
    let kind: AskCoachFocusKind
    let rationale: CoachBilingualText
}

enum AskCoachLoadState: Sendable {
    case idle
    case loading
    case ready
    case noData
    case permissionUnavailable
    case partialData
    case error(String)
}

extension AskCoachLoadState: Equatable {
    nonisolated static func == (lhs: AskCoachLoadState, rhs: AskCoachLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loading, .loading),
             (.ready, .ready),
             (.noData, .noData),
             (.permissionUnavailable, .permissionUnavailable),
             (.partialData, .partialData):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

struct AskCoachAnswer: Equatable, Sendable {
    let question: AskCoachQuestion
    let period: AskCoachPeriodLength
    let range: AskCoachDateRange
    let previousRange: AskCoachDateRange
    /// Short human finding — not a numeric dashboard headline.
    let headline: CoachBilingualText
    let explanation: CoachBilingualText
    /// At most two key facts for the initial card.
    let supportingFacts: [CoachBilingualText]
    /// Coverage, sample counts, and extra metrics for “View details”.
    let detailFacts: [CoachBilingualText]
    /// Shown inline only when missing data materially changes the conclusion.
    let inlineLimitation: CoachBilingualText?
    let coverage: [AskCoachMetricCoverage]
    let evidence: [AskCoachEvidenceItem]
    let followUps: [AskCoachFollowUp]
    let suggestedFocus: AskCoachSuggestedFocus?
    let loadState: AskCoachLoadState
    /// Compact follow-up replies skip repeating the root overview.
    let isCompactFollowUp: Bool
}

struct AskCoachPeriodBundle: Equatable, Sendable {
    let currentDays: [AskCoachDayMetrics]
    let previousDays: [AskCoachDayMetrics]
    let range: AskCoachDateRange
    let previousRange: AskCoachDateRange
    let healthAccessGranted: Bool
}
