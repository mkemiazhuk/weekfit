import SwiftUI
import HealthKit
internal import Combine

@MainActor
final class RecoveryDetailsViewModel: ObservableObject {

    @Published private(set) var snapshot: RecoveryDaySnapshot = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var authorizationFailed = false

    private let provider: RecoveryHealthKitProvider
    private var loadToken = UUID()

    init(provider: RecoveryHealthKitProvider = RecoveryHealthKitProvider()) {
        self.provider = provider
    }

    func load(for date: Date) async {
        let token = UUID()
        loadToken = token

        isLoading = true
        authorizationFailed = false

        let authorized = await provider.requestAuthorization()

        guard loadToken == token else { return }

        guard authorized else {
            authorizationFailed = true
            snapshot = RecoveryDaySnapshot.empty(for: date)
            isLoading = false
            return
        }

        let loadedSnapshot = await provider.loadSnapshot(for: date)

        guard loadToken == token else { return }

        let breakdown = RecoveryScoreEngine.calculate(
            sleepMinutes: loadedSnapshot.asleepMinutes,
            timeInBedMinutes: loadedSnapshot.timeInBedMinutes,
            awakeMinutes: loadedSnapshot.awakeMinutes,
            awakeningsCount: loadedSnapshot.awakeningsCount,
            deepSleepMinutes: loadedSnapshot.deepSleepMinutes,
            remSleepMinutes: loadedSnapshot.remSleepMinutes,
            hrvSDNN: loadedSnapshot.hrv ?? 0,
            restingHeartRate: loadedSnapshot.restingHeartRate ?? 0
        )

        snapshot = loadedSnapshot.withRecovery(
            score: breakdown.total,
            breakdown: breakdown
        )

        isLoading = false
    }

    // Kept for backward compatibility if another place still calls the old API.
    // It now ignores passed Today values and recalculates recovery for the requested date.
    func load(
        for date: Date,
        recoveryScore: Int,
        recoveryBreakdown: RecoveryScoreBreakdown
    ) async {
        await load(for: date)
    }
}

// MARK: - Recovery Day Snapshot

struct RecoveryDaySnapshot: Equatable {
    let date: Date

    let recoveryScore: Int
    let recoveryBreakdown: RecoveryScoreBreakdown

    let sleepScore: Int

    let timeInBedMinutes: Int
    let asleepMinutes: Int
    let awakeMinutes: Int

    let deepSleepMinutes: Int
    let remSleepMinutes: Int
    let coreSleepMinutes: Int

    let bedStart: Date?
    let wakeTime: Date?
    let awakeningsCount: Int

    let restingHeartRate: Double?
    let hrv: Double?

    let insightTitle: String
    let insightText: String
    let actionTitle: String
    let actionText: String

    static let empty = RecoveryDaySnapshot(
        date: Date(),
        recoveryScore: 0,
        recoveryBreakdown: .empty,
        sleepScore: 0,
        timeInBedMinutes: 0,
        asleepMinutes: 0,
        awakeMinutes: 0,
        deepSleepMinutes: 0,
        remSleepMinutes: 0,
        coreSleepMinutes: 0,
        bedStart: nil,
        wakeTime: nil,
        awakeningsCount: 0,
        restingHeartRate: nil,
        hrv: nil,
        insightTitle: WeekFitLocalizedString("recovery.empty.title"),
        insightText: WeekFitLocalizedString("recovery.empty.text"),
        actionTitle: WeekFitLocalizedString("recovery.empty.actionTitle"),
        actionText: WeekFitLocalizedString("recovery.empty.actionText")
    )

    static func empty(for date: Date) -> RecoveryDaySnapshot {
        RecoveryDaySnapshot(
            date: date,
            recoveryScore: 0,
            recoveryBreakdown: .empty,
            sleepScore: 0,
            timeInBedMinutes: 0,
            asleepMinutes: 0,
            awakeMinutes: 0,
            deepSleepMinutes: 0,
            remSleepMinutes: 0,
            coreSleepMinutes: 0,
            bedStart: nil,
            wakeTime: nil,
            awakeningsCount: 0,
            restingHeartRate: nil,
            hrv: nil,
            insightTitle: WeekFitLocalizedString("recovery.empty.title"),
            insightText: WeekFitLocalizedString("recovery.empty.text"),
            actionTitle: WeekFitLocalizedString("recovery.empty.actionTitle"),
            actionText: WeekFitLocalizedString("recovery.empty.actionText")
        )
    }

    func withRecovery(
        score: Int,
        breakdown: RecoveryScoreBreakdown
    ) -> RecoveryDaySnapshot {
        RecoveryDaySnapshot(
            date: date,
            recoveryScore: min(max(score, 0), 100),
            recoveryBreakdown: breakdown,
            sleepScore: sleepScore,
            timeInBedMinutes: timeInBedMinutes,
            asleepMinutes: asleepMinutes,
            awakeMinutes: awakeMinutes,
            deepSleepMinutes: deepSleepMinutes,
            remSleepMinutes: remSleepMinutes,
            coreSleepMinutes: coreSleepMinutes,
            bedStart: bedStart,
            wakeTime: wakeTime,
            awakeningsCount: awakeningsCount,
            restingHeartRate: restingHeartRate,
            hrv: hrv,
            insightTitle: resolvedInsightTitle(for: min(max(score, 0), 100)),
            insightText: resolvedInsightText(for: min(max(score, 0), 100)),
            actionTitle: resolvedActionTitle(for: min(max(score, 0), 100)),
            actionText: resolvedActionText(for: min(max(score, 0), 100))
        )
    }

    private func resolvedInsightTitle(for score: Int) -> String {
        guard hasSleepData else { return WeekFitLocalizedString("recovery.empty.title") }

        switch score {
        case 85...:
            return WeekFitLocalizedString("recovery.fullyRecovered")
        case 70..<85:
            return WeekFitLocalizedString("recovery.wellRecovered")
        case 55..<70:
            return WeekFitLocalizedString("recovery.moderatelyReady")
        case 1..<55:
            return WeekFitLocalizedString("recovery.takeItEasier")
        default:
            return WeekFitLocalizedString("recovery.empty.title")
        }
    }

    private func resolvedInsightText(for score: Int) -> String {
        guard hasSleepData else {
            return WeekFitLocalizedString("recovery.empty.text")
        }

        let sleepDurationIsStrong = asleepMinutes >= 420
        let sleepQualityIsStrong = deepSleepMinutes + remSleepMinutes >= Int(Double(asleepMinutes) * 0.35)
        let continuityIsStrong = timeInBedMinutes > 0 && Double(asleepMinutes) / Double(timeInBedMinutes) >= 0.88

        if score >= 85 {
            return WeekFitLocalizedString("recovery.sleepDurationContinuityAndSleepStructureWereSupportiveOvernight")
        }

        if score >= 70 {
            if sleepDurationIsStrong && sleepQualityIsStrong {
                return WeekFitLocalizedString("recovery.sleepDurationAndSleepStructureSupportedRecoveryOvernight")
            }

            if continuityIsStrong {
                return WeekFitLocalizedString("recovery.sleepContinuityWasStrongWithOnlyLimitedAwakeTime")
            }

            return WeekFitLocalizedString("recovery.recoveryLooksSolidWithOneOrTwoSignalsStill")
        }

        if score >= 55 {
            if !sleepDurationIsStrong {
                return WeekFitLocalizedString("recovery.sleepDurationWasBelowTargetSoRecoveryMayFeel")
            }

            if !sleepQualityIsStrong {
                return WeekFitLocalizedString("recovery.sleepStructureWasLighterThanIdealWhichMayLimit")
            }

            return WeekFitLocalizedString("recovery.recoveryIsModerateKeepIntensityControlledUntilSignalsImprove")
        }

        return WeekFitLocalizedString("recovery.recoverySignalsAreLowPrioritizeEasyMovementHydrationAnd")
    }

    private func resolvedActionTitle(for score: Int) -> String {
        guard hasSleepData else { return WeekFitLocalizedString("recovery.empty.actionTitle") }

        switch score {
        case 85...:
            return WeekFitLocalizedString("recovery.ready")
        case 70..<85:
            return WeekFitLocalizedString("recovery.trainNormally")
        case 55..<70:
            return WeekFitLocalizedString("recovery.details.action.controlIntensity")
        default:
            return WeekFitLocalizedString("recovery.recover")
        }
    }

    private func resolvedActionText(for score: Int) -> String {
        guard hasSleepData else {
            return WeekFitLocalizedString("recovery.empty.actionText")
        }

        switch score {
        case 85...:
            return WeekFitLocalizedString("recovery.youCanHandleNormalTrainingLoadToday")
        case 70..<85:
            return WeekFitLocalizedString("recovery.aNormalSessionIsFineButAvoidForcingExtra")
        case 55..<70:
            return WeekFitLocalizedString("recovery.chooseModerateWorkAndPayAttentionToHowYou")
        default:
            return WeekFitLocalizedString("recovery.keepActivityLightAndFocusOnRecoveryBasics")
        }
    }

    private var hasSleepData: Bool {
        asleepMinutes > 0 || timeInBedMinutes > 0
    }
}
