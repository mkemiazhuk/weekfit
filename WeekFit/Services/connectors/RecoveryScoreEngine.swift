import Foundation

// MARK: - Models

struct RecoveryPhysiologyBaseline: Equatable, Hashable {
    let hrvMedian: Double?
    let hrvSampleCount: Int
    let restingHeartRateMedian: Double?
    let restingHeartRateSampleCount: Int
    let windowDays: Int

    static let minimumSamplesForPersonalized = 7
    static let preferredWindowDays = 21

    var hasPersonalizedHRV: Bool {
        hrvSampleCount >= Self.minimumSamplesForPersonalized && hrvMedian != nil
    }

    var hasPersonalizedRHR: Bool {
        restingHeartRateSampleCount >= Self.minimumSamplesForPersonalized && restingHeartRateMedian != nil
    }

    static let empty = RecoveryPhysiologyBaseline(
        hrvMedian: nil,
        hrvSampleCount: 0,
        restingHeartRateMedian: nil,
        restingHeartRateSampleCount: 0,
        windowDays: preferredWindowDays
    )
}

struct RecoveryPriorDayLoad: Equatable, Hashable {
    let exerciseMinutes: Int
    let activeCalories: Double
    let workoutCount: Int

    static let empty = RecoveryPriorDayLoad(exerciseMinutes: 0, activeCalories: 0, workoutCount: 0)

    var strainLevel: RecoveryStrainLevel {
        if exerciseMinutes >= 90 || activeCalories >= 800 {
            return .heavy
        }
        if exerciseMinutes >= 45 || activeCalories >= 450 || workoutCount >= 2 {
            return .moderate
        }
        return .light
    }
}

enum RecoveryStrainLevel: Equatable {
    case light
    case moderate
    case heavy
}

enum RecoveryScoreConfidence: String, Equatable, Hashable {
    case high
    case medium
    case low
}

enum RecoveryUnavailableSignal: String, Equatable, Hashable, CaseIterable {
    case hrv
    case restingHeartRate
    case deepSleep
    case remSleep
    case priorDayLoad
}

struct RecoveryBaselineContext: Equatable, Hashable {
    let hrvBaseline: Double?
    let hrvBaselineSampleCount: Int
    let restingHeartRateBaseline: Double?
    let restingHeartRateBaselineSampleCount: Int
    let usesPersonalizedHRV: Bool
    let usesPersonalizedRHR: Bool

    static let empty = RecoveryBaselineContext(
        hrvBaseline: nil,
        hrvBaselineSampleCount: 0,
        restingHeartRateBaseline: nil,
        restingHeartRateBaselineSampleCount: 0,
        usesPersonalizedHRV: false,
        usesPersonalizedRHR: false
    )
}

struct RecoveryScoreInput: Equatable, Hashable {
    let sleepMinutes: Int
    let timeInBedMinutes: Int
    let awakeMinutes: Int
    let awakeningsCount: Int
    let deepSleepMinutes: Int
    let remSleepMinutes: Int
    let hrvSDNN: Double?
    let restingHeartRate: Double?
    let bedtimeDeviationMinutes: Int?
    let baseline: RecoveryPhysiologyBaseline
    let priorDayLoad: RecoveryPriorDayLoad?
}

struct RecoveryScoreBreakdown: Equatable, Hashable {
    let sleepDuration: Int
    let sleepConsistency: Int
    let sleepContinuity: Int
    let sleepArchitecture: Int
    let hrv: Int
    let restingHeartRate: Int
    let trainingLoadModifier: Int
    let total: Int
    let confidence: RecoveryScoreConfidence
    let baselineContext: RecoveryBaselineContext
    let unavailableSignals: [RecoveryUnavailableSignal]

    static let maxSleepDurationContribution = 26
    static let maxSleepConsistencyContribution = 13
    static let maxSleepContinuityContribution = 16
    static let maxSleepArchitectureContribution = 10
    static let maxHRVContribution = 25
    static let maxRestingHeartRateContribution = 10
    static let maxTrainingLoadPenalty = 8

    var componentSum: Int {
        sleepDuration
            + sleepConsistency
            + sleepContinuity
            + sleepArchitecture
            + hrv
            + restingHeartRate
            + trainingLoadModifier
    }

    static let empty = RecoveryScoreBreakdown(
        sleepDuration: 0,
        sleepConsistency: 0,
        sleepContinuity: 0,
        sleepArchitecture: 0,
        hrv: 0,
        restingHeartRate: 0,
        trainingLoadModifier: 0,
        total: 0,
        confidence: .low,
        baselineContext: .empty,
        unavailableSignals: RecoveryUnavailableSignal.allCases
    )
}

enum RecoveryScoreEngine {

    private static let durationTargetMinutes = 480.0
    private static let durationExponent = 1.2
    private static let bedtimeMaxDeviationMinutes = 180.0
    private static let shortSleepCapMinutes = 240
    private static let shortSleepRecoveryCap = 65.0
    private static let moderateSleepCapMinutes = 360
    private static let moderateSleepRecoveryCap = 68.0
    private static let minimumSleepMinutesForWellRecovered = 360

    private static let sleepBlockWeight = 0.65
    private static let hrvBlockWeight = 0.25
    private static let rhrBlockWeight = 0.10

    enum RecoveryStatusTier: Equatable {
        case wellRecovered
        case moderatelyReady
        case takeItEasier
        case recoveryPriority
        case noData
    }

    // MARK: - Public API

    static func calculate(_ input: RecoveryScoreInput) -> RecoveryScoreBreakdown {
        guard input.sleepMinutes > 0 else { return .empty }

        var unavailableSignals: [RecoveryUnavailableSignal] = []

        let sleepComponents = sleepBlockComponents(from: input, unavailableSignals: &unavailableSignals)
        let sleepBlockScore = sleepComponents.weightedScore

        let hrvScore = hrvComponentScore(
            hrv: input.hrvSDNN,
            baseline: input.baseline,
            unavailableSignals: &unavailableSignals
        )
        let rhrScore = rhrComponentScore(
            rhr: input.restingHeartRate,
            baseline: input.baseline,
            unavailableSignals: &unavailableSignals
        )

        let blend = blendedRecoveryScore(
            sleepBlockScore: sleepBlockScore,
            hrvScore: hrvScore,
            rhrScore: rhrScore
        )

        var recovery = blend.score

        if let cap = recoveryCap(for: input.sleepMinutes) {
            recovery = min(recovery, cap)
        }

        let physiology = physiologyAssessment(input: input)
        recovery = applyPhysiologyStressAdjustments(
            recovery: recovery,
            input: input,
            physiology: physiology
        )

        let loadModifier = trainingLoadModifier(
            load: input.priorDayLoad,
            physiology: physiology
        )
        recovery = max(0, recovery + Double(loadModifier))

        let clampedRecovery = Int(max(0, min(100, recovery)).rounded())

        unavailableSignals = Array(Set(unavailableSignals)).sorted { $0.rawValue < $1.rawValue }

        let baselineContext = RecoveryBaselineContext(
            hrvBaseline: input.baseline.hrvMedian,
            hrvBaselineSampleCount: input.baseline.hrvSampleCount,
            restingHeartRateBaseline: input.baseline.restingHeartRateMedian,
            restingHeartRateBaselineSampleCount: input.baseline.restingHeartRateSampleCount,
            usesPersonalizedHRV: input.baseline.hasPersonalizedHRV,
            usesPersonalizedRHR: input.baseline.hasPersonalizedRHR
        )

        let confidence = resolveConfidence(
            blend: blend,
            baselineContext: baselineContext,
            unavailableSignals: unavailableSignals
        )

        let breakdownRows = makeBreakdownRows(
            sleepComponents: sleepComponents,
            hrvScore: hrvScore,
            rhrScore: rhrScore,
            loadModifier: loadModifier,
            totalRecovery: clampedRecovery
        )

        return RecoveryScoreBreakdown(
            sleepDuration: breakdownRows.sleepDuration,
            sleepConsistency: breakdownRows.sleepConsistency,
            sleepContinuity: breakdownRows.sleepContinuity,
            sleepArchitecture: breakdownRows.sleepArchitecture,
            hrv: breakdownRows.hrv,
            restingHeartRate: breakdownRows.restingHeartRate,
            trainingLoadModifier: breakdownRows.trainingLoadModifier,
            total: clampedRecovery,
            confidence: confidence,
            baselineContext: baselineContext,
            unavailableSignals: unavailableSignals
        )
    }

    static func medianBaseline(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2.0
        }
        return sorted[middle]
    }

    static func normalizedBedtimeMinutes(_ date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return minutes < 12 * 60 ? minutes + 24 * 60 : minutes
    }

    static func circularAverageBedtimeMinutes(_ bedtimes: [Int]) -> Int {
        guard !bedtimes.isEmpty else { return 0 }

        let angles = bedtimes.map { Double($0) / (24.0 * 60.0) * 2.0 * Double.pi }
        let sinSum = angles.reduce(0.0) { $0 + sin($1) }
        let cosSum = angles.reduce(0.0) { $0 + cos($1) }
        let averageAngle = atan2(sinSum, cosSum)
        let normalizedAngle = averageAngle >= 0 ? averageAngle : averageAngle + 2.0 * Double.pi
        let averageMinutes = normalizedAngle / (2.0 * Double.pi) * (24.0 * 60.0)
        return Int(averageMinutes.rounded())
    }

    static func deviationMinutes(current: Int, average: Int) -> Int {
        let rawDifference = abs(current - average)
        return min(rawDifference, (24 * 60) - rawDifference)
    }

    static func bedtimeDeviationMinutes(
        currentBedStart: Date?,
        historicalBedStarts: [Date],
        calendar: Calendar = .current
    ) -> Int? {
        guard let currentBedStart else { return nil }

        let historicalMinutes = historicalBedStarts.map {
            normalizedBedtimeMinutes($0, calendar: calendar)
        }
        guard !historicalMinutes.isEmpty else { return nil }

        let average = circularAverageBedtimeMinutes(historicalMinutes)
        let current = normalizedBedtimeMinutes(currentBedStart, calendar: calendar)
        return deviationMinutes(current: current, average: average)
    }

    static func statusTier(
        score: Int,
        input: RecoveryScoreInput,
        breakdown: RecoveryScoreBreakdown
    ) -> RecoveryStatusTier {
        guard score > 0 else { return .noData }

        let physiology = physiologyAssessment(input: input)
        var tier = scoreBasedTier(for: score)

        if input.sleepMinutes > 0 && input.sleepMinutes < minimumSleepMinutesForWellRecovered {
            tier = minTier(tier, .moderatelyReady)
        }

        if input.sleepMinutes > 0 && input.sleepMinutes < shortSleepCapMinutes {
            tier = minTier(tier, .takeItEasier)
        }

        if physiology.hrvSignificantlyBelowBaseline && physiology.rhrElevatedVsBaseline {
            tier = minTier(tier, .moderatelyReady)
        }

        if breakdown.confidence == .low && tier == .wellRecovered {
            tier = .moderatelyReady
        }

        return tier
    }

    static func physiologyIsStressed(input: RecoveryScoreInput) -> Bool {
        physiologyAssessment(input: input).isStressed
    }

    // MARK: - Sleep Block

    private struct SleepBlockComponents {
        let durationScore: Double
        let consistencyScore: Double
        let continuityScore: Double
        let architectureScore: Double

        var weightedScore: Double {
            durationScore * 0.40
                + consistencyScore * 0.20
                + continuityScore * 0.25
                + architectureScore * 0.15
        }
    }

    private static func sleepBlockComponents(
        from input: RecoveryScoreInput,
        unavailableSignals: inout [RecoveryUnavailableSignal]
    ) -> SleepBlockComponents {
        let duration = sleepDurationScore(input.sleepMinutes)
        let consistency = bedtimeConsistencyScore(deviationMinutes: input.bedtimeDeviationMinutes)
        let continuity = sleepContinuityScore(
            sleepMinutes: input.sleepMinutes,
            timeInBedMinutes: input.timeInBedMinutes,
            awakeningsCount: input.awakeningsCount
        )
        let architecture = sleepArchitectureScore(
            sleepMinutes: input.sleepMinutes,
            deepSleepMinutes: input.deepSleepMinutes,
            remSleepMinutes: input.remSleepMinutes,
            unavailableSignals: &unavailableSignals
        )

        return SleepBlockComponents(
            durationScore: duration,
            consistencyScore: consistency,
            continuityScore: continuity,
            architectureScore: architecture
        )
    }

    private static func sleepDurationScore(_ minutes: Int) -> Double {
        let normalized = min(Double(minutes) / durationTargetMinutes, 1.0)
        return pow(normalized, durationExponent) * 100.0
    }

    private static func bedtimeConsistencyScore(deviationMinutes: Int?) -> Double {
        guard let deviationMinutes else {
            return 70.0
        }

        let ratio = min(max(Double(deviationMinutes) / bedtimeMaxDeviationMinutes, 0.0), 1.0)
        return (1.0 - ratio) * 100.0
    }

    private static func sleepContinuityScore(
        sleepMinutes: Int,
        timeInBedMinutes: Int,
        awakeningsCount: Int
    ) -> Double {
        guard timeInBedMinutes > 0 else { return 75.0 }

        let efficiency = min(max(Double(sleepMinutes) / Double(timeInBedMinutes), 0.0), 1.0)

        let efficiencyScore: Double
        switch efficiency {
        case 0.90...:
            efficiencyScore = 100.0
        case 0.85..<0.90:
            efficiencyScore = 90.0
        case 0.75..<0.85:
            efficiencyScore = 72.0
        default:
            efficiencyScore = 50.0
        }

        let awakeningModifier = min(Double(awakeningsCount) / 8.0, 1.0) * 10.0
        return max(0.0, efficiencyScore - awakeningModifier)
    }

    private static func sleepArchitectureScore(
        sleepMinutes: Int,
        deepSleepMinutes: Int,
        remSleepMinutes: Int,
        unavailableSignals: inout [RecoveryUnavailableSignal]
    ) -> Double {
        guard sleepMinutes > 0 else { return 70.0 }

        let hasDeep = deepSleepMinutes > 0
        let hasREM = remSleepMinutes > 0

        if !hasDeep {
            unavailableSignals.append(.deepSleep)
        }
        if !hasREM {
            unavailableSignals.append(.remSleep)
        }

        guard hasDeep || hasREM else {
            return 70.0
        }

        let deepRatio = Double(deepSleepMinutes) / Double(sleepMinutes)
        let remRatio = Double(remSleepMinutes) / Double(sleepMinutes)

        let deepScore = hasDeep ? min(deepRatio / 0.18, 1.0) * 100.0 : 70.0
        let remScore = hasREM ? min(remRatio / 0.22, 1.0) * 100.0 : 70.0

        if hasDeep && hasREM {
            return deepScore * 0.5 + remScore * 0.5
        }
        return hasDeep ? deepScore : remScore
    }

    // MARK: - Physiology

    private struct PhysiologyAssessment {
        let isStressed: Bool
        let hrvBelowBaseline: Bool
        let hrvSignificantlyBelowBaseline: Bool
        let rhrElevatedVsBaseline: Bool
    }

    private static func physiologyAssessment(input: RecoveryScoreInput) -> PhysiologyAssessment {
        let shortSleep = input.sleepMinutes > 0 && input.sleepMinutes < minimumSleepMinutesForWellRecovered

        let hrvBelowBaseline: Bool
        let hrvSignificantlyBelowBaseline: Bool
        if let hrv = input.hrvSDNN, hrv > 0, let baseline = input.baseline.hrvMedian, input.baseline.hasPersonalizedHRV {
            hrvBelowBaseline = hrv < baseline * 0.95
            hrvSignificantlyBelowBaseline = hrv < baseline * 0.85
        } else if let hrv = input.hrvSDNN, hrv > 0 {
            hrvBelowBaseline = hrv < 35
            hrvSignificantlyBelowBaseline = hrv < 30
        } else {
            hrvBelowBaseline = false
            hrvSignificantlyBelowBaseline = false
        }

        let rhrElevatedVsBaseline: Bool
        if let rhr = input.restingHeartRate, rhr > 0, let baseline = input.baseline.restingHeartRateMedian, input.baseline.hasPersonalizedRHR {
            rhrElevatedVsBaseline = rhr >= baseline + 4
        } else if let rhr = input.restingHeartRate, rhr > 0 {
            rhrElevatedVsBaseline = rhr >= 65
        } else {
            rhrElevatedVsBaseline = false
        }

        let isStressed = shortSleep || hrvBelowBaseline || rhrElevatedVsBaseline

        return PhysiologyAssessment(
            isStressed: isStressed,
            hrvBelowBaseline: hrvBelowBaseline,
            hrvSignificantlyBelowBaseline: hrvSignificantlyBelowBaseline,
            rhrElevatedVsBaseline: rhrElevatedVsBaseline
        )
    }

    private static func hrvComponentScore(
        hrv: Double?,
        baseline: RecoveryPhysiologyBaseline,
        unavailableSignals: inout [RecoveryUnavailableSignal]
    ) -> Double? {
        guard let hrv, hrv > 0 else {
            unavailableSignals.append(.hrv)
            return nil
        }

        if baseline.hasPersonalizedHRV, let baselineHRV = baseline.hrvMedian, baselineHRV > 0 {
            let ratio = hrv / baselineHRV
            switch ratio {
            case 1.12...:
                return 100.0
            case 1.05..<1.12:
                return 94.0
            case 0.95..<1.05:
                return 85.0
            case 0.85..<0.95:
                return 72.0
            case 0.75..<0.85:
                return 58.0
            default:
                return max(25.0, 40.0 + (ratio - 0.60) * 90.0)
            }
        }

        return min(hrv / 50.0, 1.0) * 70.0 + 15.0
    }

    private static func rhrComponentScore(
        rhr: Double?,
        baseline: RecoveryPhysiologyBaseline,
        unavailableSignals: inout [RecoveryUnavailableSignal]
    ) -> Double? {
        guard let rhr, rhr > 0 else {
            unavailableSignals.append(.restingHeartRate)
            return nil
        }

        if baseline.hasPersonalizedRHR, let baselineRHR = baseline.restingHeartRateMedian {
            let delta = rhr - baselineRHR
            switch delta {
            case ..<(-3):
                return 100.0
            case -3..<0:
                return 96.0
            case 0..<3:
                return 88.0
            case 3..<5:
                return 72.0
            case 5..<8:
                return 55.0
            default:
                return 35.0
            }
        }

        switch rhr {
        case ..<55:
            return 90.0
        case 55..<65:
            return 75.0
        case 65..<75:
            return 55.0
        default:
            return 35.0
        }
    }

    // MARK: - Blend & Modifiers

    private struct BlendResult {
        let score: Double
        let usedSleep: Bool
        let usedHRV: Bool
        let usedRHR: Bool
    }

    private static func blendedRecoveryScore(
        sleepBlockScore: Double,
        hrvScore: Double?,
        rhrScore: Double?
    ) -> BlendResult {
        var weightedSum = sleepBlockScore * sleepBlockWeight
        var totalWeight = sleepBlockWeight

        if let hrvScore {
            weightedSum += hrvScore * hrvBlockWeight
            totalWeight += hrvBlockWeight
        }

        if let rhrScore {
            weightedSum += rhrScore * rhrBlockWeight
            totalWeight += rhrBlockWeight
        }

        let normalized = totalWeight > 0 ? weightedSum / totalWeight : 0
        return BlendResult(
            score: normalized,
            usedSleep: true,
            usedHRV: hrvScore != nil,
            usedRHR: rhrScore != nil
        )
    }

    private static func trainingLoadModifier(
        load: RecoveryPriorDayLoad?,
        physiology: PhysiologyAssessment
    ) -> Int {
        guard let load else { return 0 }

        switch load.strainLevel {
        case .light:
            return 0
        case .moderate:
            if physiology.hrvSignificantlyBelowBaseline && physiology.rhrElevatedVsBaseline {
                return -6
            }
            if physiology.isStressed && (physiology.hrvBelowBaseline || physiology.rhrElevatedVsBaseline) {
                return -4
            }
            return 0
        case .heavy:
            if physiology.hrvSignificantlyBelowBaseline && physiology.rhrElevatedVsBaseline {
                return -8
            }
            if physiology.isStressed && physiology.hrvBelowBaseline && physiology.rhrElevatedVsBaseline {
                return -7
            }
            if physiology.isStressed && (physiology.hrvBelowBaseline || physiology.rhrElevatedVsBaseline) {
                return -5
            }
            if physiology.isStressed {
                return -3
            }
            return 0
        }
    }

    private static func applyPhysiologyStressAdjustments(
        recovery: Double,
        input: RecoveryScoreInput,
        physiology: PhysiologyAssessment
    ) -> Double {
        var adjusted = recovery

        let shortSleep = input.sleepMinutes < minimumSleepMinutesForWellRecovered
        let veryLateBedtime = (input.bedtimeDeviationMinutes ?? 0) >= 120

        if shortSleep && physiology.rhrElevatedVsBaseline {
            adjusted = min(adjusted, 62)
        }

        if shortSleep && physiology.hrvSignificantlyBelowBaseline {
            adjusted = min(adjusted, 64)
        }

        if shortSleep && physiology.rhrElevatedVsBaseline && physiology.hrvSignificantlyBelowBaseline {
            adjusted = min(adjusted, 58)
        }

        if shortSleep && veryLateBedtime {
            adjusted = min(adjusted, 60)
        }

        return adjusted
    }

    private static func recoveryCap(for sleepMinutes: Int) -> Double? {
        if sleepMinutes < shortSleepCapMinutes {
            return shortSleepRecoveryCap
        }

        if sleepMinutes < moderateSleepCapMinutes {
            let progress = Double(sleepMinutes - shortSleepCapMinutes)
                / Double(moderateSleepCapMinutes - shortSleepCapMinutes)
            return shortSleepRecoveryCap + progress * (moderateSleepRecoveryCap - shortSleepRecoveryCap)
        }

        return nil
    }

    // MARK: - Confidence & Status

    private static func resolveConfidence(
        blend: BlendResult,
        baselineContext: RecoveryBaselineContext,
        unavailableSignals: [RecoveryUnavailableSignal]
    ) -> RecoveryScoreConfidence {
        let hasHRV = blend.usedHRV
        let hasRHR = blend.usedRHR
        let personalizedHRV = baselineContext.usesPersonalizedHRV
        let personalizedRHR = baselineContext.usesPersonalizedRHR

        if !hasHRV && !hasRHR {
            return .low
        }

        if hasHRV && hasRHR && personalizedHRV && personalizedRHR && unavailableSignals.isEmpty {
            return .high
        }

        if hasHRV && hasRHR && (personalizedHRV || personalizedRHR) {
            return .medium
        }

        if unavailableSignals.contains(.hrv) || unavailableSignals.contains(.restingHeartRate) {
            return .low
        }

        if !personalizedHRV || !personalizedRHR {
            return .medium
        }

        return .medium
    }

    private static func scoreBasedTier(for score: Int) -> RecoveryStatusTier {
        switch score {
        case 85...:
            return .wellRecovered
        case 70..<85:
            return .moderatelyReady
        case 55..<70:
            return .takeItEasier
        default:
            return .recoveryPriority
        }
    }

    private static func minTier(_ current: RecoveryStatusTier, _ cap: RecoveryStatusTier) -> RecoveryStatusTier {
        tierRank(current) > tierRank(cap) ? cap : current
    }

    private static func tierRank(_ tier: RecoveryStatusTier) -> Int {
        switch tier {
        case .wellRecovered: return 4
        case .moderatelyReady: return 3
        case .takeItEasier: return 2
        case .recoveryPriority: return 1
        case .noData: return 0
        }
    }

    // MARK: - Breakdown Rows

    private static func makeBreakdownRows(
        sleepComponents: SleepBlockComponents,
        hrvScore: Double?,
        rhrScore: Double?,
        loadModifier: Int,
        totalRecovery: Int
    ) -> (
        sleepDuration: Int,
        sleepConsistency: Int,
        sleepContinuity: Int,
        sleepArchitecture: Int,
        hrv: Int,
        restingHeartRate: Int,
        trainingLoadModifier: Int
    ) {
        let availableWeight = sleepBlockWeight
            + (hrvScore != nil ? hrvBlockWeight : 0)
            + (rhrScore != nil ? rhrBlockWeight : 0)

        let contributions: [Double] = [
            sleepComponents.durationScore * 0.40 * sleepBlockWeight / availableWeight,
            sleepComponents.consistencyScore * 0.20 * sleepBlockWeight / availableWeight,
            sleepComponents.continuityScore * 0.25 * sleepBlockWeight / availableWeight,
            sleepComponents.architectureScore * 0.15 * sleepBlockWeight / availableWeight,
            hrvScore.map { $0 * hrvBlockWeight / availableWeight } ?? 0,
            rhrScore.map { $0 * rhrBlockWeight / availableWeight } ?? 0
        ]

        let positiveRounded = adjustRoundedValuesToTargetSum(
            values: contributions.map { Int(max(0, $0).rounded(.down)) },
            targetSum: max(0, totalRecovery - loadModifier),
            priorities: contributions.map { max(0, $0) - floor(max(0, $0)) }
        )

        return (
            sleepDuration: positiveRounded[0],
            sleepConsistency: positiveRounded[1],
            sleepContinuity: positiveRounded[2],
            sleepArchitecture: positiveRounded[3],
            hrv: positiveRounded[4],
            restingHeartRate: positiveRounded[5],
            trainingLoadModifier: loadModifier
        )
    }

    private static func adjustRoundedValuesToTargetSum(
        values: [Int],
        targetSum: Int,
        priorities: [Double]
    ) -> [Int] {
        var adjusted = values
        var difference = targetSum - adjusted.reduce(0, +)

        guard difference != 0 else { return adjusted }

        let orderedIndices = priorities.enumerated()
            .sorted {
                if difference > 0 {
                    return $0.element > $1.element
                }
                return $0.element < $1.element
            }
            .map(\.offset)

        var cursor = 0
        while difference != 0, !orderedIndices.isEmpty {
            let index = orderedIndices[cursor % orderedIndices.count]
            if difference > 0 {
                adjusted[index] += 1
                difference -= 1
            } else if adjusted[index] > 0 {
                adjusted[index] -= 1
                difference += 1
            }
            cursor += 1
            if cursor > orderedIndices.count * abs(targetSum - values.reduce(0, +)) + 10 {
                break
            }
        }

        return adjusted
    }
}
