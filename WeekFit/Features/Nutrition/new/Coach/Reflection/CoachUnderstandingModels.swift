import Foundation

enum CoachWorkoutIntensityBand: String, Codable, Equatable, Sendable {
    case rest
    case light
    case moderate
    case hard
}

struct CoachWorkoutObservationSample: Equatable, Sendable {
    let typeToken: String
    let durationMinutes: Int
    let activeCalories: Int
    let isHardTraining: Bool
    let isRecoveryActivity: Bool
}

struct CoachDailyObservationTrainingSnapshot: Equatable, Sendable {
    let exerciseMinutes: Int
    let activeCalories: Int
    let workoutCount: Int
    let workoutTypes: [String]
    let hardWorkoutCount: Int
    let workoutIntensityBand: CoachWorkoutIntensityBand
    let hadHardTraining: Bool
    let hadRecoveryActivity: Bool
    let hadRestDay: Bool
    let trainingLoadScore: Int
}

struct CoachDailyObservationNutritionSnapshot: Equatable, Sendable {
    let proteinGrams: Int
    let carbsGrams: Int
    let fatGrams: Int
    let caloriesEaten: Int
    let calorieDeficit: Int?
    let hydrationLiters: Double
    let mealsLoggedCount: Int
}

struct CoachDailyObservation: Codable, Equatable, Identifiable, Sendable {
    let dayKey: String
    let sleepMinutes: Int
    let recoveryPercent: Int
    let bedStartNormalizedMinutes: Int?
    let exerciseMinutes: Int?
    let activeCalories: Int?
    let workoutCount: Int?
    let workoutTypes: [String]?
    let hardWorkoutCount: Int?
    let workoutIntensityBand: CoachWorkoutIntensityBand?
    let hadHardTraining: Bool?
    let hadRecoveryActivity: Bool?
    let hadRestDay: Bool?
    let trainingLoadScore: Int?
    let proteinGrams: Int?
    let carbsGrams: Int?
    let fatGrams: Int?
    let caloriesEaten: Int?
    let calorieDeficit: Int?
    let hydrationLiters: Double?
    let mealsLoggedCount: Int?
    let hasPopulatedNutritionFields: Bool?

    var id: String { dayKey }

    var hasSleepSignal: Bool { sleepMinutes > 0 }

    var hasRecoverySignal: Bool { recoveryPercent > 0 }

    var hasPopulatedTrainingFields: Bool { workoutIntensityBand != nil }

    var hasPopulatedNutritionFieldsResolved: Bool { hasPopulatedNutritionFields == true }

    var hasTrainingAndRecoverySignal: Bool {
        hasPopulatedTrainingFields && hasRecoverySignal
    }

    var hasNutritionAndRecoverySignal: Bool {
        hasPopulatedNutritionFieldsResolved && hasRecoverySignal
    }

    var isHardTrainingDay: Bool {
        guard hasPopulatedTrainingFields else { return false }
        if hadHardTraining == true { return true }
        return workoutIntensityBand == .hard
    }

    var isModerateOrHardTrainingDay: Bool {
        guard hasPopulatedTrainingFields else { return false }
        switch workoutIntensityBand {
        case .hard, .moderate:
            return true
        default:
            return false
        }
    }

    var isRestOrLightRecoveryDay: Bool {
        guard hasPopulatedTrainingFields else { return false }
        if hadRestDay == true { return true }
        if hadRecoveryActivity == true { return true }
        switch workoutIntensityBand {
        case .rest, .light:
            return true
        default:
            return false
        }
    }

    init(
        dayKey: String,
        sleepMinutes: Int,
        recoveryPercent: Int,
        bedStartNormalizedMinutes: Int? = nil,
        exerciseMinutes: Int? = nil,
        activeCalories: Int? = nil,
        workoutCount: Int? = nil,
        workoutTypes: [String]? = nil,
        hardWorkoutCount: Int? = nil,
        workoutIntensityBand: CoachWorkoutIntensityBand? = nil,
        hadHardTraining: Bool? = nil,
        hadRecoveryActivity: Bool? = nil,
        hadRestDay: Bool? = nil,
        trainingLoadScore: Int? = nil,
        proteinGrams: Int? = nil,
        carbsGrams: Int? = nil,
        fatGrams: Int? = nil,
        caloriesEaten: Int? = nil,
        calorieDeficit: Int? = nil,
        hydrationLiters: Double? = nil,
        mealsLoggedCount: Int? = nil,
        hasPopulatedNutritionFields: Bool? = nil
    ) {
        self.dayKey = dayKey
        self.sleepMinutes = sleepMinutes
        self.recoveryPercent = recoveryPercent
        self.bedStartNormalizedMinutes = bedStartNormalizedMinutes
        self.exerciseMinutes = exerciseMinutes
        self.activeCalories = activeCalories
        self.workoutCount = workoutCount
        self.workoutTypes = workoutTypes
        self.hardWorkoutCount = hardWorkoutCount
        self.workoutIntensityBand = workoutIntensityBand
        self.hadHardTraining = hadHardTraining
        self.hadRecoveryActivity = hadRecoveryActivity
        self.hadRestDay = hadRestDay
        self.trainingLoadScore = trainingLoadScore
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.caloriesEaten = caloriesEaten
        self.calorieDeficit = calorieDeficit
        self.hydrationLiters = hydrationLiters
        self.mealsLoggedCount = mealsLoggedCount
        self.hasPopulatedNutritionFields = hasPopulatedNutritionFields
    }

    func mergingTraining(_ training: CoachDailyObservationTrainingSnapshot) -> CoachDailyObservation {
        CoachDailyObservation(
            dayKey: dayKey,
            sleepMinutes: sleepMinutes,
            recoveryPercent: recoveryPercent,
            bedStartNormalizedMinutes: bedStartNormalizedMinutes,
            exerciseMinutes: training.exerciseMinutes,
            activeCalories: training.activeCalories,
            workoutCount: training.workoutCount,
            workoutTypes: training.workoutTypes,
            hardWorkoutCount: training.hardWorkoutCount,
            workoutIntensityBand: training.workoutIntensityBand,
            hadHardTraining: training.hadHardTraining,
            hadRecoveryActivity: training.hadRecoveryActivity,
            hadRestDay: training.hadRestDay,
            trainingLoadScore: training.trainingLoadScore,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            caloriesEaten: caloriesEaten,
            calorieDeficit: calorieDeficit,
            hydrationLiters: hydrationLiters,
            mealsLoggedCount: mealsLoggedCount,
            hasPopulatedNutritionFields: hasPopulatedNutritionFields
        )
    }

    func mergingNutrition(_ nutrition: CoachDailyObservationNutritionSnapshot) -> CoachDailyObservation {
        CoachDailyObservation(
            dayKey: dayKey,
            sleepMinutes: sleepMinutes,
            recoveryPercent: recoveryPercent,
            bedStartNormalizedMinutes: bedStartNormalizedMinutes,
            exerciseMinutes: exerciseMinutes,
            activeCalories: activeCalories,
            workoutCount: workoutCount,
            workoutTypes: workoutTypes,
            hardWorkoutCount: hardWorkoutCount,
            workoutIntensityBand: workoutIntensityBand,
            hadHardTraining: hadHardTraining,
            hadRecoveryActivity: hadRecoveryActivity,
            hadRestDay: hadRestDay,
            trainingLoadScore: trainingLoadScore,
            proteinGrams: nutrition.proteinGrams,
            carbsGrams: nutrition.carbsGrams,
            fatGrams: nutrition.fatGrams,
            caloriesEaten: nutrition.caloriesEaten,
            calorieDeficit: nutrition.calorieDeficit,
            hydrationLiters: nutrition.hydrationLiters,
            mealsLoggedCount: nutrition.mealsLoggedCount,
            hasPopulatedNutritionFields: true
        )
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let dayStart = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: dayStart)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return ISO8601DateFormatter().string(from: dayStart)
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(fromDayKey dayKey: String, calendar: Calendar = .current) -> Date? {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }
}

enum CoachBeliefID: String, Codable, CaseIterable, Sendable {
    case sleepConsistencyRecovery
    case sleepDurationRecovery
    case lateBedtimeRecovery
    case heavyLoadRecoveryLag
    case recoveryAfterRestDay
    case consecutiveHardDaysFatigue
    case underfuelingRecovery
}

enum CoachBeliefMaturity: String, Codable, Sendable, Comparable {
    case watching
    case emerging
    case established
    case weakening
    case retired

    static func < (lhs: Self, rhs: Self) -> Bool {
        strengthRank(lhs) < strengthRank(rhs)
    }

    func isUpgrade(from previous: CoachBeliefMaturity) -> Bool {
        switch (previous, self) {
        case (.watching, .emerging), (.watching, .established):
            return true
        case (.emerging, .established):
            return true
        case (.weakening, .emerging):
            return true
        default:
            return false
        }
    }

    func isDowngrade(from previous: CoachBeliefMaturity) -> Bool {
        switch (previous, self) {
        case (.established, .weakening), (.established, .emerging), (.established, .watching):
            return true
        case (.emerging, .watching):
            return true
        case (.weakening, .retired), (.weakening, .watching):
            return true
        default:
            return false
        }
    }

    private static func strengthRank(_ maturity: CoachBeliefMaturity) -> Int {
        switch maturity {
        case .watching: return 0
        case .retired: return 0
        case .weakening: return 1
        case .emerging: return 2
        case .established: return 3
        }
    }
}

struct CoachBelief: Codable, Equatable, Sendable {
    let id: CoachBeliefID
    var maturity: CoachBeliefMaturity
    var lastUpdated: Date
}

enum UnderstandingChange: String, Codable, Sendable {
    case emerged
    case strengthened
}

struct UnderstandingEvent: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let beliefID: CoachBeliefID
    let change: UnderstandingChange
    let maturity: CoachBeliefMaturity
    let createdAt: Date

    static func make(
        beliefID: CoachBeliefID,
        change: UnderstandingChange,
        maturity: CoachBeliefMaturity,
        createdAt: Date = Date()
    ) -> UnderstandingEvent {
        UnderstandingEvent(
            id: "\(beliefID.rawValue).\(change.rawValue).\(maturity.rawValue)",
            beliefID: beliefID,
            change: change,
            maturity: maturity,
            createdAt: createdAt
        )
    }
}

struct ConsecutiveHardDaysFatigueEvaluation: Equatable, Sendable {
    let isolatedRecoveryAverage: Double
    let consecutiveRecoveryAverage: Double
    let consecutiveSequenceCount: Int
    let isolatedSampleCount: Int
    let eligibleDayCount: Int

    var recoveryFatigue: Double {
        isolatedRecoveryAverage - consecutiveRecoveryAverage
    }

    var hasMinimumSamples: Bool {
        eligibleDayCount >= 14
            && consecutiveSequenceCount >= 3
            && isolatedSampleCount >= 4
    }

    var hasEstablishedSamples: Bool {
        eligibleDayCount >= 18
            && consecutiveSequenceCount >= 5
            && isolatedSampleCount >= 5
    }
}

struct UnderfuelingRecoveryEvaluation: Equatable, Sendable {
    let adequatelyFueledRecoveryAverage: Double
    let underfueledRecoveryAverage: Double
    let underfueledAnchorCount: Int
    let adequatelyFueledAnchorCount: Int
    let postUnderfueledSampleCount: Int
    let postFueledSampleCount: Int
    let eligibleDayCount: Int

    var recoveryDrop: Double {
        adequatelyFueledRecoveryAverage - underfueledRecoveryAverage
    }

    var hasMinimumSamples: Bool {
        eligibleDayCount >= 12
            && underfueledAnchorCount >= 3
            && adequatelyFueledAnchorCount >= 3
            && postUnderfueledSampleCount >= 3
            && postFueledSampleCount >= 4
    }

    var hasEstablishedSamples: Bool {
        eligibleDayCount >= 18
            && underfueledAnchorCount >= 5
            && adequatelyFueledAnchorCount >= 5
            && postUnderfueledSampleCount >= 5
            && postFueledSampleCount >= 6
    }
}

struct RecoveryAfterRestDayEvaluation: Equatable, Sendable {
    let postHeavyRecoveryAverage: Double
    let postRestFollowUpRecoveryAverage: Double
    let sequenceCount: Int
    let eligibleDayCount: Int

    var recoveryRebound: Double {
        postRestFollowUpRecoveryAverage - postHeavyRecoveryAverage
    }

    var hasMinimumSamples: Bool {
        eligibleDayCount >= 12 && sequenceCount >= 3
    }

    var hasEstablishedSamples: Bool {
        eligibleDayCount >= 18 && sequenceCount >= 5
    }
}

struct HeavyLoadRecoveryLagEvaluation: Equatable, Sendable {
    let baselineRecoveryAverage: Double
    let postHardRecoveryAverage: Double
    let hardAnchorCount: Int
    let postHardLagSampleCount: Int
    let baselineLagSampleCount: Int
    let eligibleDayCount: Int

    var recoveryLag: Double {
        baselineRecoveryAverage - postHardRecoveryAverage
    }

    var hasMinimumSamples: Bool {
        eligibleDayCount >= 10
            && hardAnchorCount >= 3
            && postHardLagSampleCount >= 4
            && baselineLagSampleCount >= 4
    }

    var hasEstablishedSamples: Bool {
        hardAnchorCount >= 5
            && postHardLagSampleCount + baselineLagSampleCount >= 14
    }
}

struct LateBedtimeEvaluation: Equatable, Sendable {
    let normalRecoveryAverage: Double
    let lateRecoveryAverage: Double
    let normalSampleCount: Int
    let lateSampleCount: Int

    var recoveryDrop: Double {
        normalRecoveryAverage - lateRecoveryAverage
    }

    var hasMinimumSamples: Bool {
        normalSampleCount >= 4 && lateSampleCount >= 2
    }

    var hasEstablishedSamples: Bool {
        normalSampleCount + lateSampleCount >= 12
    }
}

struct SleepDurationEvaluation: Equatable, Sendable {
    let sufficientRecoveryAverage: Double
    let insufficientRecoveryAverage: Double
    let sufficientSampleCount: Int
    let insufficientSampleCount: Int

    var recoveryDelta: Double {
        sufficientRecoveryAverage - insufficientRecoveryAverage
    }

    var hasMinimumSamples: Bool {
        sufficientSampleCount >= 4 && insufficientSampleCount >= 2
    }

    var hasEstablishedSamples: Bool {
        sufficientSampleCount + insufficientSampleCount >= 12
    }
}

struct SleepConsistencyEvaluation: Equatable, Sendable {
    let consistentRecoveryAverage: Double
    let inconsistentRecoveryAverage: Double
    let consistentSampleCount: Int
    let inconsistentSampleCount: Int

    var recoveryDelta: Double {
        consistentRecoveryAverage - inconsistentRecoveryAverage
    }

    var hasMinimumSamples: Bool {
        consistentSampleCount >= 4 && inconsistentSampleCount >= 2
    }

    var hasEstablishedSamples: Bool {
        consistentSampleCount + inconsistentSampleCount >= 12
    }
}
