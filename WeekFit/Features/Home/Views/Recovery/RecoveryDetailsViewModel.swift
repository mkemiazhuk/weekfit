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
        insightTitle: "No recovery data yet",
        insightText: "Wear Apple Watch during sleep to unlock recovery insights.",
        actionTitle: "Today",
        actionText: "Keep the day easy until more data is available."
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
            insightTitle: "No recovery data yet",
            insightText: "Wear Apple Watch during sleep to unlock recovery insights.",
            actionTitle: "Today",
            actionText: "Keep the day easy until more data is available."
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
        guard hasSleepData else { return "No recovery data yet" }

        switch score {
        case 85...:
            return "Fully recovered"
        case 70..<85:
            return "Well recovered"
        case 55..<70:
            return "Moderately ready"
        case 1..<55:
            return "Take it easier"
        default:
            return "No recovery data yet"
        }
    }

    private func resolvedInsightText(for score: Int) -> String {
        guard hasSleepData else {
            return "Wear Apple Watch during sleep to unlock recovery insights."
        }

        let sleepDurationIsStrong = asleepMinutes >= 420
        let sleepQualityIsStrong = deepSleepMinutes + remSleepMinutes >= Int(Double(asleepMinutes) * 0.35)
        let continuityIsStrong = timeInBedMinutes > 0 && Double(asleepMinutes) / Double(timeInBedMinutes) >= 0.88

        if score >= 85 {
            return "Sleep duration, continuity and sleep structure were supportive overnight."
        }

        if score >= 70 {
            if sleepDurationIsStrong && sleepQualityIsStrong {
                return "Sleep duration and sleep structure supported recovery overnight."
            }

            if continuityIsStrong {
                return "Sleep continuity was strong, with only limited awake time overnight."
            }

            return "Recovery looks solid, with one or two signals still holding the score back."
        }

        if score >= 55 {
            if !sleepDurationIsStrong {
                return "Sleep duration was below target, so recovery may feel less stable today."
            }

            if !sleepQualityIsStrong {
                return "Sleep structure was lighter than ideal, which may limit recovery today."
            }

            return "Recovery is moderate. Keep intensity controlled until signals improve."
        }

        return "Recovery signals are low. Prioritize easy movement, hydration and an earlier night."
    }

    private func resolvedActionTitle(for score: Int) -> String {
        guard hasSleepData else { return "Today" }

        switch score {
        case 85...:
            return "Ready"
        case 70..<85:
            return "Train normally"
        case 55..<70:
            return "Control intensity"
        default:
            return "Recover"
        }
    }

    private func resolvedActionText(for score: Int) -> String {
        guard hasSleepData else {
            return "Keep the day easy until more data is available."
        }

        switch score {
        case 85...:
            return "You can handle normal training load today."
        case 70..<85:
            return "A normal session is fine, but avoid forcing extra intensity."
        case 55..<70:
            return "Choose moderate work and pay attention to how you feel."
        default:
            return "Keep activity light and focus on recovery basics."
        }
    }

    private var hasSleepData: Bool {
        asleepMinutes > 0 || timeInBedMinutes > 0
    }
}
