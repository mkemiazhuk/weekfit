import Foundation

struct RecoveryScoreBreakdown: Equatable, Hashable {
    let sleepDuration: Int
    let sleepContinuity: Int
    let sleepQuality: Int
    let hrv: Int
    let restingHeartRate: Int
    let total: Int

    static let empty = RecoveryScoreBreakdown(
        sleepDuration: 0,
        sleepContinuity: 0,
        sleepQuality: 0,
        hrv: 0,
        restingHeartRate: 0,
        total: 0
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
    private static let elevatedRestingHeartRateThreshold = 65.0
    private static let suppressedHRVThreshold = 35.0

    enum RecoveryStatusTier: Equatable {
        case fullyRecovered
        case wellRecovered
        case moderatelyReady
        case takeItEasier
        case noData
    }

    static func calculate(
        sleepMinutes: Int,
        timeInBedMinutes: Int,
        awakeMinutes: Int,
        awakeningsCount: Int,
        deepSleepMinutes: Int,
        remSleepMinutes: Int,
        hrvSDNN: Double,
        restingHeartRate: Double,
        bedtimeDeviationMinutes: Int? = nil
    ) -> RecoveryScoreBreakdown {
        _ = deepSleepMinutes
        _ = remSleepMinutes
        guard sleepMinutes > 0 else { return .empty }

        let durationPoints = sleepDurationPoints(sleepMinutes)
        let bedtimePoints = bedtimeConsistencyPoints(deviationMinutes: bedtimeDeviationMinutes)
        let continuityPoints = sleepContinuityPoints(
            sleepMinutes: sleepMinutes,
            timeInBedMinutes: timeInBedMinutes,
            awakeMinutes: awakeMinutes,
            awakeningsCount: awakeningsCount
        )

        let sleepScore = durationPoints + bedtimePoints + continuityPoints
        let hrvPoints = hrvScore(hrvSDNN)
        let rhrPoints = restingHeartRateScore(restingHeartRate)

        var recovery = sleepScore * 0.70 + hrvPoints * 0.20 + rhrPoints * 0.10
        if let cap = recoveryCap(for: sleepMinutes) {
            recovery = min(recovery, cap)
        }
        recovery = applyPhysiologyStressAdjustments(
            recovery: recovery,
            sleepMinutes: sleepMinutes,
            hrvSDNN: hrvSDNN,
            restingHeartRate: restingHeartRate,
            bedtimeDeviationMinutes: bedtimeDeviationMinutes
        )

        let clampedRecovery = Int(max(0, min(100, recovery)).rounded())
        let breakdownRows = makeBreakdownRows(
            durationPoints: durationPoints,
            bedtimePoints: bedtimePoints,
            continuityPoints: continuityPoints,
            hrvPoints: hrvPoints,
            rhrPoints: rhrPoints,
            totalRecovery: clampedRecovery
        )

        return RecoveryScoreBreakdown(
            sleepDuration: breakdownRows.sleepDuration,
            sleepContinuity: breakdownRows.sleepContinuity,
            sleepQuality: breakdownRows.sleepQuality,
            hrv: breakdownRows.hrv,
            restingHeartRate: breakdownRows.restingHeartRate,
            total: clampedRecovery
        )
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
        sleepMinutes: Int,
        restingHeartRate: Double?,
        hrvSDNN: Double?
    ) -> RecoveryStatusTier {
        guard score > 0 else { return .noData }

        if physiologyIsStressed(
            sleepMinutes: sleepMinutes,
            restingHeartRate: restingHeartRate ?? 0,
            hrvSDNN: hrvSDNN ?? 0
        ) {
            if score >= 55 {
                return .moderatelyReady
            }
            return .takeItEasier
        }

        switch score {
        case 85...:
            return .fullyRecovered
        case 70..<85:
            return .wellRecovered
        case 55..<70:
            return .moderatelyReady
        default:
            return .takeItEasier
        }
    }

    static func physiologyIsStressed(
        sleepMinutes: Int,
        restingHeartRate: Double,
        hrvSDNN: Double
    ) -> Bool {
        let shortSleep = sleepMinutes > 0 && sleepMinutes < minimumSleepMinutesForWellRecovered
        let elevatedRHR = restingHeartRate >= elevatedRestingHeartRateThreshold
        let suppressedHRV = hrvSDNN > 0 && hrvSDNN < suppressedHRVThreshold
        return shortSleep || elevatedRHR || suppressedHRV
    }

    private static func applyPhysiologyStressAdjustments(
        recovery: Double,
        sleepMinutes: Int,
        hrvSDNN: Double,
        restingHeartRate: Double,
        bedtimeDeviationMinutes: Int?
    ) -> Double {
        var adjusted = recovery

        let shortSleep = sleepMinutes < minimumSleepMinutesForWellRecovered
        let elevatedRHR = restingHeartRate >= elevatedRestingHeartRateThreshold
        let suppressedHRV = hrvSDNN > 0 && hrvSDNN < suppressedHRVThreshold
        let veryLateBedtime = (bedtimeDeviationMinutes ?? 0) >= 120

        if shortSleep && elevatedRHR {
            adjusted = min(adjusted, 62)
        }

        if shortSleep && suppressedHRV {
            adjusted = min(adjusted, 64)
        }

        if shortSleep && elevatedRHR && suppressedHRV {
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

    private static func sleepDurationPoints(_ minutes: Int) -> Double {
        let normalized = min(Double(minutes) / durationTargetMinutes, 1.0)
        return 50.0 * pow(normalized, durationExponent)
    }

    private static func bedtimeConsistencyPoints(deviationMinutes: Int?) -> Double {
        guard let deviationMinutes else {
            return 12.0
        }

        let ratio = min(max(Double(deviationMinutes) / bedtimeMaxDeviationMinutes, 0.0), 1.0)
        return 30.0 * (1.0 - ratio)
    }

    private static func sleepContinuityPoints(
        sleepMinutes: Int,
        timeInBedMinutes: Int,
        awakeMinutes: Int,
        awakeningsCount: Int
    ) -> Double {
        sleepContinuityScore(
            sleepMinutes: sleepMinutes,
            timeInBedMinutes: timeInBedMinutes,
            awakeMinutes: awakeMinutes,
            awakeningsCount: awakeningsCount
        ) * 20.0
    }

    private static func sleepContinuityScore(
        sleepMinutes: Int,
        timeInBedMinutes: Int,
        awakeMinutes: Int,
        awakeningsCount: Int
    ) -> Double {
        guard timeInBedMinutes > 0 else { return 0.75 }

        let efficiency = min(max(Double(sleepMinutes) / Double(timeInBedMinutes), 0.0), 1.0)

        let efficiencyScore: Double
        switch efficiency {
        case 0.92...:
            efficiencyScore = 1.0
        case 0.85..<0.92:
            efficiencyScore = 0.82
        case 0.75..<0.85:
            efficiencyScore = 0.58
        default:
            efficiencyScore = 0.35
        }

        let awakePenalty = min(Double(awakeMinutes) / 60.0, 1.0) * 0.20
        let awakeningPenalty = min(Double(awakeningsCount) / 6.0, 1.0) * 0.20

        return max(0.0, min(1.0, efficiencyScore - awakePenalty - awakeningPenalty))
    }

    private static func hrvScore(_ hrv: Double) -> Double {
        guard hrv > 0 else { return 0.0 }
        return min(hrv / 50.0, 1.0) * 100.0
    }

    private static func restingHeartRateScore(_ rhr: Double) -> Double {
        guard rhr > 0 else { return 0.0 }

        switch rhr {
        case ..<55:
            return 100.0
        case 55..<65:
            return 85.0
        case 65..<75:
            return 45.0
        case 75..<85:
            return 35.0
        default:
            return 20.0
        }
    }

    private static func makeBreakdownRows(
        durationPoints: Double,
        bedtimePoints: Double,
        continuityPoints: Double,
        hrvPoints: Double,
        rhrPoints: Double,
        totalRecovery: Int
    ) -> (
        sleepDuration: Int,
        sleepContinuity: Int,
        sleepQuality: Int,
        hrv: Int,
        restingHeartRate: Int
    ) {
        let components: [(contribution: Double, maxContribution: Double, rowMax: Double)] = [
            (durationPoints * 0.70, 35.0, 35.0),
            (continuityPoints * 0.70, 14.0, 25.0),
            (bedtimePoints * 0.70, 21.0, 20.0),
            (hrvPoints * 0.20, 20.0, 12.0),
            (rhrPoints * 0.10, 10.0, 8.0)
        ]

        let uncappedRecovery = components.reduce(0.0) { $0 + $1.contribution }
        let scale = uncappedRecovery > 0 ? Double(totalRecovery) / uncappedRecovery : 0.0

        let displayValues = components.map { component -> Double in
            guard component.maxContribution > 0 else { return 0.0 }
            let scaledContribution = component.contribution * scale
            return scaledContribution / component.maxContribution * component.rowMax
        }

        let rounded = adjustRoundedValuesToTargetSum(
            values: displayValues.map { Int($0.rounded(.down)) },
            targetSum: totalRecovery,
            priorities: displayValues.map { $0 - floor($0) }
        )

        return (
            sleepDuration: rounded[0],
            sleepContinuity: rounded[1],
            sleepQuality: rounded[2],
            hrv: rounded[3],
            restingHeartRate: rounded[4]
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
