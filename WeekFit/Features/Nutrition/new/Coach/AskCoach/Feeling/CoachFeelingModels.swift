import Foundation

/// Self-reported feeling — never fed into recovery scoring.
enum CoachFeelingKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case energized
    case okay
    case tired
    /// Soft low mood / “not great” — routed like tired for Recovery, without forcing intensity changes.
    case low

    var id: String { rawValue }

    /// Tired or “not great” — fatigue follow-ups may apply.
    var suggestsFatigueFollowUp: Bool {
        self == .tired || self == .low
    }

    var titleKey: String {
        switch self {
        case .energized: return "coach.feeling.choice.energized"
        case .okay: return "coach.feeling.choice.okay"
        case .tired: return "coach.feeling.choice.tired"
        case .low: return "coach.feeling.choice.low"
        }
    }

    var bilingualTitle: CoachBilingualText {
        switch self {
        case .energized: return .en("Good", "Хорошо")
        case .okay: return .en("Okay", "Нормально")
        case .tired: return .en("Tired", "Устал")
        case .low: return .en("Not great", "Не очень")
        }
    }
}

enum CoachFeelingClarification: String, Codable, CaseIterable, Identifiable, Sendable {
    case lowEnergy
    case soreMuscles
    case sleepiness

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .lowEnergy: return "coach.feeling.clarify.lowEnergy"
        case .soreMuscles: return "coach.feeling.clarify.soreMuscles"
        case .sleepiness: return "coach.feeling.clarify.sleepiness"
        }
    }

    var bilingualTitle: CoachBilingualText {
        switch self {
        case .lowEnergy: return .en("Low energy", "Мало энергии")
        case .soreMuscles: return .en("Sore muscles", "Болят мышцы")
        case .sleepiness: return .en("Sleepiness", "Сонливость")
        }
    }
}

enum CoachFeelingComparisonKind: String, Codable, Sendable {
    /// Available metrics are directionally consistent with the reported feeling.
    case supporting
    /// Metrics are near baseline / mixed relative to the reported feeling.
    case mixed
    /// Not enough recent, non-stale observations to compare.
    case insufficient
}

/// Snapshot of metric evidence used at comparison time (timestamp-relevant).
struct CoachFeelingEvidenceSnapshot: Codable, Equatable, Sendable {
    var sleepMinutes: Int?
    var sleepBaselineMinutes: Int?
    var sleepDayKey: String?
    var sleepIsStale: Bool
    var sleepSampleCount: Int

    var recoveryPercent: Int?
    var recoveryBaselinePercent: Int?
    var recoveryDayKey: String?
    var recoveryIsStale: Bool
    var recoverySampleCount: Int

    var recentActivityCount: Int
    var recentActivityDayKeys: [String]
    var activityWindowHours: Int

    static let empty = CoachFeelingEvidenceSnapshot(
        sleepMinutes: nil,
        sleepBaselineMinutes: nil,
        sleepDayKey: nil,
        sleepIsStale: false,
        sleepSampleCount: 0,
        recoveryPercent: nil,
        recoveryBaselinePercent: nil,
        recoveryDayKey: nil,
        recoveryIsStale: false,
        recoverySampleCount: 0,
        recentActivityCount: 0,
        recentActivityDayKeys: [],
        activityWindowHours: 48
    )
}

struct CoachFeelingComparisonResult: Equatable, Sendable {
    let outcome: CoachFeelingComparisonKind
    let headline: CoachBilingualText
    let explanation: CoachBilingualText
    let supportingFacts: [CoachBilingualText]
    let detailFacts: [CoachBilingualText]
    let evidence: CoachFeelingEvidenceSnapshot
    let analysisVersion: Int
}

struct CoachFeelingCheckIn: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var createdAt: Date
    var updatedAt: Date
    var feeling: CoachFeelingKind
    var clarification: CoachFeelingClarification?
    var outcome: CoachFeelingComparisonKind
    var evidence: CoachFeelingEvidenceSnapshot
    var analysisVersion: Int
    /// Optional later answers in the same check-in (e.g. duration follow-up).
    var followUpAnswers: [String]

    /// Local calendar day key for the check-in timestamp.
    func dayKey(calendar: Calendar = .current) -> String {
        CoachDailyObservation.dayKey(for: createdAt, calendar: calendar)
    }
}

enum CoachFeelingFollowUp: String, CaseIterable, Identifiable, Sendable {
    case last7Days
    case tryToday
    case feelingDuration
    case reviewWeek

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .last7Days: return "coach.feeling.followUp.last7"
        case .tryToday: return "coach.feeling.followUp.tryToday"
        case .feelingDuration: return "coach.feeling.followUp.duration"
        case .reviewWeek: return "coach.feeling.followUp.reviewWeek"
        }
    }

    var prompt: CoachBilingualText {
        switch self {
        case .last7Days:
            return .en("Look at the last 7 days", "Посмотреть последние 7 дней")
        case .tryToday:
            return .en("What could I try today?", "Что можно попробовать сегодня?")
        case .feelingDuration:
            return .en("Did this start today, or has it lasted a few days?", "Это началось сегодня или длится несколько дней?")
        case .reviewWeek:
            return .en("Review my week", "Обзор недели")
        }
    }
}

struct CoachFeelingConversationTurn: Identifiable, Equatable {
    let id: UUID
    let userPrompt: CoachBilingualText
    var answerHeadline: CoachBilingualText?
    var answerExplanation: CoachBilingualText?
    var supportingFacts: [CoachBilingualText]
    var detailFacts: [CoachBilingualText]
    var isLoading: Bool
    var detailsExpanded: Bool
}

/// Documented evidence rules for feeling ↔ metric comparison (analysis v1).
enum CoachFeelingEvidenceRules {
    static let analysisVersion = 1

    /// Sleep older than this relative to check-in is not treated as “current”.
    static let sleepFreshnessHours: Double = 36
    /// Recovery score older than this relative to check-in is stale.
    static let recoveryFreshnessHours: Double = 36
    /// Baseline window ending the day before the check-in day.
    static let baselineLookbackDays = 14
    static let minimumSleepBaselineSamples = 5
    static let minimumRecoveryBaselineSamples = 4
    /// Sleep shorter than baseline by this many minutes may support “tired”.
    static let tiredSleepShortfallMinutes = 45
    /// Recovery below baseline by this many points may support “tired”.
    static let tiredRecoveryShortfallPoints = 8
    /// Near-baseline band for “okay” / non-support.
    static let sleepNearBaselineMinutes = 30
    static let recoveryNearBaselinePoints = 6
    /// Activity context window (descriptive only — not intensity).
    static let recentActivityHours = 48
}
