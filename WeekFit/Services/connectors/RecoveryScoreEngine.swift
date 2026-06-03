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

    static func calculate(
        sleepMinutes: Int,
        timeInBedMinutes: Int,
        awakeMinutes: Int,
        awakeningsCount: Int,
        deepSleepMinutes: Int,
        remSleepMinutes: Int,
        hrvSDNN: Double,
        restingHeartRate: Double
    ) -> RecoveryScoreBreakdown {
        guard sleepMinutes > 0 else { return .empty }

        let duration = sleepDurationScore(sleepMinutes) * 35.0

        let continuity = sleepContinuityScore(
            sleepMinutes: sleepMinutes,
            timeInBedMinutes: timeInBedMinutes,
            awakeMinutes: awakeMinutes,
            awakeningsCount: awakeningsCount
        ) * 25.0

        let quality = sleepQualityScore(
            sleepMinutes: sleepMinutes,
            deepSleepMinutes: deepSleepMinutes,
            remSleepMinutes: remSleepMinutes
        ) * 20.0

        let hrv = hrvScore(hrvSDNN) * 12.0
        let rhr = restingHeartRateScore(restingHeartRate) * 8.0

        let total = duration + continuity + quality + hrv + rhr

        return RecoveryScoreBreakdown(
            sleepDuration: Int(duration.rounded()),
            sleepContinuity: Int(continuity.rounded()),
            sleepQuality: Int(quality.rounded()),
            hrv: Int(hrv.rounded()),
            restingHeartRate: Int(rhr.rounded()),
            total: Int(max(0, min(100, total)).rounded())
        )
    }

    private static func sleepDurationScore(_ minutes: Int) -> Double {
        min(Double(minutes) / 450.0, 1.0)
    }

    private static func sleepContinuityScore(
        sleepMinutes: Int,
        timeInBedMinutes: Int,
        awakeMinutes: Int,
        awakeningsCount: Int
    ) -> Double {
        guard timeInBedMinutes > 0 else { return 0.6 }

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

    private static func sleepQualityScore(
        sleepMinutes: Int,
        deepSleepMinutes: Int,
        remSleepMinutes: Int
    ) -> Double {
        guard sleepMinutes > 0 else { return 0.0 }

        let qualityMinutes = deepSleepMinutes + remSleepMinutes
        let ratio = Double(qualityMinutes) / Double(sleepMinutes)

        return min(ratio / 0.40, 1.0)
    }

    private static func hrvScore(_ hrv: Double) -> Double {
        guard hrv > 0 else { return 0.6 }
        return min(hrv / 50.0, 1.0)
    }

    private static func restingHeartRateScore(_ rhr: Double) -> Double {
        guard rhr > 0 else { return 0.6 }

        switch rhr {
        case ..<55:
            return 1.0
        case 55..<65:
            return 0.85
        case 65..<75:
            return 0.60
        case 75..<85:
            return 0.35
        default:
            return 0.20
        }
    }
}
