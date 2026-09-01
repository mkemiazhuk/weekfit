import Foundation

struct MovementFamilyOutcome: Codable, Sendable, Equatable {
    var offered: Bool = false
    var defaultSelected: Bool = false
    var selectedAtSettle: Bool = false
    var applied: Bool = false
    var explicitlyRejected: Bool = false
    var completed: Bool = false
    var partialCompletion: Bool = false
    var durationMinutes: Int?
    var completedDurationMinutes: Int?
    var scheduledHour: Int?
    var provenanceActivityId: String?
    var provenanceChangeId: String?
    var origin: MovementBehaviorOrigin?
}

/// One compact historical day record for similar-day personalization.
struct MorningAdjustmentDayRecord: Codable, Sendable, Equatable, Identifiable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let dayKey: String
    var recordedAt: Date
    let weekday: Int
    let isWeekend: Bool
    let proposalTimeBucket: ProposalTimeBucket
    let recoveryPercent: Int?
    let recoveryBand: ProposalRecoveryBandToken
    let strategy: DailyStrategy
    let outdoorSuitability: OutdoorSuitability
    let weatherRiskToken: ProposalWeatherRiskToken
    let yesterdayHeavy: Bool
    let previousDayLoad: PreviousDayLoadLabel
    let stackedLoad: ProposalStackedLoadToken
    let tomorrowDemand: CoachTomorrowDemand
    let existingPlanSuitability: ExistingPlanMovementSuitability
    let hadMorningProposal: Bool
    var movementOutcomesRaw: [String: MovementFamilyOutcome]

    var id: String { dayKey }

    var movementOutcomes: [RecoveryMovementFamily: MovementFamilyOutcome] {
        get {
            Dictionary(uniqueKeysWithValues: movementOutcomesRaw.compactMap { key, value in
                guard let family = RecoveryMovementFamily(rawValue: key) else { return nil }
                return (family, value)
            })
        }
        set {
            movementOutcomesRaw = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
        }
    }

    init(
        dayKey: String,
        recordedAt: Date,
        weekday: Int,
        isWeekend: Bool,
        proposalTimeBucket: ProposalTimeBucket,
        recoveryPercent: Int?,
        recoveryBand: ProposalRecoveryBandToken,
        strategy: DailyStrategy,
        outdoorSuitability: OutdoorSuitability,
        weatherRiskToken: ProposalWeatherRiskToken,
        yesterdayHeavy: Bool,
        previousDayLoad: PreviousDayLoadLabel,
        stackedLoad: ProposalStackedLoadToken,
        tomorrowDemand: CoachTomorrowDemand,
        existingPlanSuitability: ExistingPlanMovementSuitability,
        hadMorningProposal: Bool,
        movementOutcomes: [RecoveryMovementFamily: MovementFamilyOutcome] = [:],
        schemaVersion: Int = MorningAdjustmentDayRecord.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.dayKey = dayKey
        self.recordedAt = recordedAt
        self.weekday = weekday
        self.isWeekend = isWeekend
        self.proposalTimeBucket = proposalTimeBucket
        self.recoveryPercent = recoveryPercent
        self.recoveryBand = recoveryBand
        self.strategy = strategy
        self.outdoorSuitability = outdoorSuitability
        self.weatherRiskToken = weatherRiskToken
        self.yesterdayHeavy = yesterdayHeavy
        self.previousDayLoad = previousDayLoad
        self.stackedLoad = stackedLoad
        self.tomorrowDemand = tomorrowDemand
        self.existingPlanSuitability = existingPlanSuitability
        self.hadMorningProposal = hadMorningProposal
        self.movementOutcomesRaw = Dictionary(uniqueKeysWithValues: movementOutcomes.map { ($0.key.rawValue, $0.value) })
    }

    mutating func mergeOutcome(
        _ family: RecoveryMovementFamily,
        mutate: (inout MovementFamilyOutcome) -> Void
    ) {
        var outcome = movementOutcomesRaw[family.rawValue] ?? MovementFamilyOutcome()
        mutate(&outcome)
        movementOutcomesRaw[family.rawValue] = outcome
    }
}

enum PreviousDayLoadResolver {

    static func resolve(forDayKey dayKey: String, calendar: Calendar = .current) -> PreviousDayLoadLabel {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let dayDate = formatter.date(from: dayKey),
              let priorDate = calendar.date(byAdding: .day, value: -1, to: dayDate) else {
            return .unknown
        }
        let priorKey = ProposalInputFingerprintBuilder.dayKey(for: priorDate, calendar: calendar)
        if let observation = CoachObservationStore.observation(for: priorKey) {
            if observation.hadRestDay == true { return .rest }
            if observation.hadHardTraining == true { return .heavy }
            if let score = observation.trainingLoadScore, score >= 70 { return .heavy }
            if observation.exerciseMinutes ?? 0 >= 90 { return .heavy }
            if (observation.exerciseMinutes ?? 0) > 0 { return .normal }
            return .rest
        }
        return .unknown
    }
}
