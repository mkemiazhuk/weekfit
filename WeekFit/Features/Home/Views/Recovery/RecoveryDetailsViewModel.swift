import SwiftUI
import HealthKit
internal import Combine

@MainActor
final class RecoveryDetailsViewModel: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

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

        let context = await provider.loadRecoveryScoreContext(
            for: date,
            currentBedStart: loadedSnapshot.bedStart
        )

        let input = RecoveryScoreInput(
            sleepMinutes: loadedSnapshot.asleepMinutes,
            timeInBedMinutes: loadedSnapshot.timeInBedMinutes,
            awakeMinutes: loadedSnapshot.awakeMinutes,
            awakeningsCount: loadedSnapshot.awakeningsCount,
            deepSleepMinutes: loadedSnapshot.deepSleepMinutes,
            remSleepMinutes: loadedSnapshot.remSleepMinutes,
            hrvSDNN: loadedSnapshot.hrv,
            restingHeartRate: loadedSnapshot.restingHeartRate,
            bedtimeDeviationMinutes: context.bedtimeDeviationMinutes,
            baseline: context.baseline,
            priorDayLoad: context.priorDayLoad
        )

        let breakdown = RecoveryScoreEngine.calculate(input)

        snapshot = loadedSnapshot.withRecovery(
            score: breakdown.total,
            breakdown: breakdown,
            input: input
        )

        isLoading = false
    }

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

    let recoveryInput: RecoveryScoreInput?

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
        recoveryInput: nil,
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
            recoveryInput: nil,
            insightTitle: WeekFitLocalizedString("recovery.empty.title"),
            insightText: WeekFitLocalizedString("recovery.empty.text"),
            actionTitle: WeekFitLocalizedString("recovery.empty.actionTitle"),
            actionText: WeekFitLocalizedString("recovery.empty.actionText")
        )
    }

    func withRecovery(
        score: Int,
        breakdown: RecoveryScoreBreakdown,
        input: RecoveryScoreInput
    ) -> RecoveryDaySnapshot {
        let clampedScore = min(max(score, 0), 100)
        let tier = RecoveryScoreEngine.statusTier(
            score: clampedScore,
            input: input,
            breakdown: breakdown
        )

        return RecoveryDaySnapshot(
            date: date,
            recoveryScore: clampedScore,
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
            recoveryInput: input,
            insightTitle: resolvedInsightTitle(for: clampedScore, tier: tier),
            insightText: resolvedInsightText(
                for: clampedScore,
                tier: tier,
                input: input,
                breakdown: breakdown
            ),
            actionTitle: resolvedActionTitle(for: clampedScore, tier: tier),
            actionText: resolvedActionText(for: clampedScore, tier: tier)
        )
    }

    private func resolvedInsightTitle(for score: Int, tier: RecoveryScoreEngine.RecoveryStatusTier) -> String {
        guard hasSleepData else { return WeekFitLocalizedString("recovery.empty.title") }

        switch tier {
        case .wellRecovered:
            return WeekFitLocalizedString("recovery.wellRecovered")
        case .moderatelyReady:
            return WeekFitLocalizedString("recovery.moderatelyReady")
        case .takeItEasier:
            return WeekFitLocalizedString("recovery.takeItEasier")
        case .recoveryPriority, .noData:
            return WeekFitLocalizedString("recovery.takeItEasier")
        }
    }

    private func resolvedInsightText(
        for score: Int,
        tier: RecoveryScoreEngine.RecoveryStatusTier,
        input: RecoveryScoreInput,
        breakdown: RecoveryScoreBreakdown
    ) -> String {
        guard hasSleepData else {
            return WeekFitLocalizedString("recovery.empty.text")
        }

        if breakdown.confidence == .low {
            return WeekFitLocalizedString("recovery.details.confidence.lowExplanation")
        }

        let sleepDurationIsStrong = asleepMinutes >= 420
        let sleepQualityIsStrong = deepSleepMinutes + remSleepMinutes >= Int(Double(asleepMinutes) * 0.35)
        let continuityIsStrong = timeInBedMinutes > 0 && Double(asleepMinutes) / Double(timeInBedMinutes) >= 0.88
        let physiologyIsStressed = RecoveryScoreEngine.physiologyIsStressed(input: input)

        if physiologyIsStressed {
            if !sleepDurationIsStrong {
                return WeekFitLocalizedString("recovery.sleepDurationWasBelowTargetSoRecoveryMayFeel")
            }

            if breakdown.baselineContext.usesPersonalizedHRV || breakdown.baselineContext.usesPersonalizedRHR {
                return WeekFitLocalizedString("recovery.recoveryIsModerateKeepIntensityControlledUntilSignalsImprove")
            }
        }

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

    private func resolvedActionTitle(for score: Int, tier: RecoveryScoreEngine.RecoveryStatusTier) -> String {
        guard hasSleepData else { return WeekFitLocalizedString("recovery.empty.actionTitle") }

        switch tier {
        case .wellRecovered:
            return WeekFitLocalizedString("recovery.trainNormally")
        case .moderatelyReady:
            return WeekFitLocalizedString("recovery.details.action.controlIntensity")
        case .takeItEasier, .recoveryPriority, .noData:
            return WeekFitLocalizedString("recovery.recover")
        }
    }

    private func resolvedActionText(for score: Int, tier: RecoveryScoreEngine.RecoveryStatusTier) -> String {
        guard hasSleepData else {
            return WeekFitLocalizedString("recovery.empty.actionText")
        }

        switch tier {
        case .wellRecovered:
            return WeekFitLocalizedString("recovery.aNormalSessionIsFineButAvoidForcingExtra")
        case .moderatelyReady:
            return WeekFitLocalizedString("recovery.chooseModerateWorkAndPayAttentionToHowYou")
        case .takeItEasier, .recoveryPriority, .noData:
            return WeekFitLocalizedString("recovery.keepActivityLightAndFocusOnRecoveryBasics")
        }
    }

    private var hasSleepData: Bool {
        asleepMinutes > 0 || timeInBedMinutes > 0
    }
}
