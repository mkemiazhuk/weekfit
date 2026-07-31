import Foundation
import WeekFitPlanner

enum ProposalInputFingerprintBuilder {

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func make(
        dayKey: String,
        todayActivities: [PlannedActivity],
        tomorrowActivities: [PlannedActivity],
        recoveryBand: ProposalRecoveryBandToken,
        sleepPresence: ProposalSleepPresenceToken,
        scenarioKey: String,
        yesterdayHeavy: Bool,
        observationContextRevision: String = "none",
        behavioralGeneration: Int = 0,
        stackedLoad: ProposalStackedLoadToken = .unavailable,
        generationMode: MorningProposalGenerationMode = .closed,
        mealLibraryRevision: String = "0",
        physiologyContextRevision: String = "none",
        scorerVersion: Int = MorningProposalAssembler.scorerVersion,
        weatherRiskToken: ProposalWeatherRiskToken = .unavailable
    ) -> ProposalInputFingerprint {
        ProposalInputFingerprint(
            dayKey: dayKey,
            planSignature: PlannedActivityRefreshSignature.make(from: todayActivities),
            tomorrowPlanSignature: PlannedActivityRefreshSignature.make(from: tomorrowActivities),
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresence,
            scenarioKey: scenarioKey.isEmpty ? "none" : scenarioKey,
            yesterdayHeavy: yesterdayHeavy,
            schemaVersion: ProposalInputFingerprint.currentSchemaVersion,
            observationContextRevision: observationContextRevision,
            behavioralGeneration: behavioralGeneration,
            stackedLoad: stackedLoad,
            generationMode: generationMode.rawValue,
            mealLibraryRevision: mealLibraryRevision,
            physiologyContextRevision: physiologyContextRevision,
            scorerVersion: scorerVersion,
            weatherRiskToken: weatherRiskToken
        )
    }

    static func make(
        dayKey: String,
        todaySnapshots: [CoachPlannedActivitySnapshot],
        tomorrowSnapshots: [CoachPlannedActivitySnapshot],
        recoveryBand: ProposalRecoveryBandToken,
        sleepPresence: ProposalSleepPresenceToken,
        scenarioKey: String,
        yesterdayHeavy: Bool,
        observationContextRevision: String = "none",
        behavioralGeneration: Int = 0,
        stackedLoad: ProposalStackedLoadToken = .unavailable,
        generationMode: MorningProposalGenerationMode = .closed,
        mealLibraryRevision: String = "0",
        physiologyContextRevision: String = "none",
        scorerVersion: Int = MorningProposalAssembler.scorerVersion,
        weatherRiskToken: ProposalWeatherRiskToken = .unavailable
    ) -> ProposalInputFingerprint {
        ProposalInputFingerprint(
            dayKey: dayKey,
            planSignature: signature(from: todaySnapshots),
            tomorrowPlanSignature: signature(from: tomorrowSnapshots),
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresence,
            scenarioKey: scenarioKey.isEmpty ? "none" : scenarioKey,
            yesterdayHeavy: yesterdayHeavy,
            schemaVersion: ProposalInputFingerprint.currentSchemaVersion,
            observationContextRevision: observationContextRevision,
            behavioralGeneration: behavioralGeneration,
            stackedLoad: stackedLoad,
            generationMode: generationMode.rawValue,
            mealLibraryRevision: mealLibraryRevision,
            physiologyContextRevision: physiologyContextRevision,
            scorerVersion: scorerVersion,
            weatherRiskToken: weatherRiskToken
        )
    }

    static func recoveryBand(from readiness: CoachDayReadiness) -> ProposalRecoveryBandToken {
        guard readiness.recoveryDataAvailable else { return .unavailable }
        switch readiness.recoveryBand {
        case .good: return .good
        case .moderate: return .moderate
        case .low: return .low
        }
    }

    static func sleepPresence(
        sleepHours: Double,
        recoveryDataAvailable: Bool,
        timedOutWithoutSleep: Bool
    ) -> ProposalSleepPresenceToken {
        if sleepHours > 0 {
            return .present
        }
        if timedOutWithoutSleep || !recoveryDataAvailable {
            return .unavailable
        }
        return .missing
    }

    static func physiologyRevision(
        recoveryBand: ProposalRecoveryBandToken,
        sleepPresence: ProposalSleepPresenceToken,
        yesterdayHeavy: Bool,
        stackedLoad: ProposalStackedLoadToken
    ) -> String {
        [
            recoveryBand.rawValue,
            sleepPresence.rawValue,
            yesterdayHeavy ? "yh1" : "yh0",
            stackedLoad.rawValue
        ].joined(separator: "|")
    }

    private static func signature(from snapshots: [CoachPlannedActivitySnapshot]) -> String {
        snapshots
            .sorted { $0.id < $1.id }
            .map { activity in
                [
                    activity.id,
                    "\(Int(activity.date.timeIntervalSince1970 / 60))",
                    activity.title,
                    activity.type,
                    "\(activity.isCompleted)",
                    "\(activity.isSkipped)",
                    "\(activity.actualDurationMinutes ?? -1)",
                    activity.healthKitWorkoutUUID ?? "nil",
                    activity.source
                ].joined(separator: ":")
            }
            .joined(separator: "|")
    }
}
