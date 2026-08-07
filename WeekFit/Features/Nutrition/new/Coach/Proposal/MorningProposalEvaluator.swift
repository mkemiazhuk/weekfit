import Foundation
import WeekFitPlanner

/// Shared morning-proposal evaluation used by Today and Root.
@MainActor
enum MorningProposalEvaluator {

    struct Input {
        var now: Date = Date()
        var dayRolloverCompleted: Bool = true
        var plannedActivities: [PlannedActivity]
        var isHealthAccessGranted: Bool
        var sleepHours: Double
        var hasSettledMetrics: Bool
        var hasRecoverySignals: Bool
        var readiness: CoachDayReadiness
        var scenarioKey: CoachScenarioKey?
        var mealLibrary: [ProposalMealCandidate]
        var mealLibraryRevision: String
        var weatherRiskToken: ProposalWeatherRiskToken
        var forceRegenerate: Bool = false
    }

    @discardableResult
    static func evaluate(_ input: Input) -> MorningPlanProposal? {
        let calendar = Calendar.current
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: input.now, calendar: calendar)

        if input.forceRegenerate {
            MorningProposalStore.remove(dayKey: dayKey)
        }

        let todayStart = calendar.startOfDay(for: input.now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let todayActivities = input.plannedActivities
            .filter { calendar.isDate($0.date, inSameDayAs: todayStart) }
            .map(CoachPlannedActivitySnapshot.init(from:))
        let tomorrowActivities = input.plannedActivities
            .filter { calendar.isDate($0.date, inSameDayAs: tomorrowStart) }
            .map(CoachPlannedActivitySnapshot.init(from:))

        let tomorrowDemand = CoachTomorrowDemandResolver.resolve(activities: tomorrowActivities).level

        let completedWalkToday = todayActivities.contains {
            $0.isCompleted && CoachActivityClassifier.type(for: $0) == .walk
        }

        let hasCompletedPlannedItemToday = todayActivities.contains {
            ($0.isCompleted || $0.isPartialCompletion || ($0.actualDurationMinutes ?? 0) > 0) && !$0.isSkipped
        }

        let isMorningWindow = CoachMorningOverviewPolicy.isBeforeLocalNoon(now: input.now, calendar: calendar)
        let healthRefreshCompleted = input.hasSettledMetrics || input.hasRecoverySignals
        let existingProposal = MorningProposalStore.proposal(for: dayKey)
        let healthRefreshTimedOut = !healthRefreshCompleted
            && existingProposal?.status == .gatheringData
            && input.now.timeIntervalSince(existingProposal?.generatedAt ?? input.now)
                >= MorningProposalGate.healthTimeoutSeconds

        let recentDayTemplates = buildRecentDayTemplates(
            from: input.plannedActivities,
            excludingDayStart: todayStart,
            calendar: calendar,
            lookbackDays: 90
        )
        let observationContextRevision = ProposalObservationContextRevision.make(from: recentDayTemplates)
        let behavioralSnapshot = ProposalBehavioralPreferences.load()

        let recoveryBand = ProposalInputFingerprintBuilder.recoveryBand(from: input.readiness)
        let sleepPresenceForFP = MorningProposalGate.sleepPresence(
            from: MorningProposalGateInput(
                now: input.now,
                dayRolloverCompleted: input.dayRolloverCompleted,
                healthRefreshCompleted: healthRefreshCompleted,
                healthRefreshTimedOut: healthRefreshTimedOut,
                isHealthAccessGranted: input.isHealthAccessGranted,
                sleepHours: input.sleepHours,
                recoveryDataAvailable: input.readiness.recoveryDataAvailable,
                todayPlanLoaded: true,
                tomorrowPlanLoaded: true,
                yesterdayContextLoaded: true,
                isMorningWindow: isMorningWindow,
                hasCompletedPlannedItemToday: hasCompletedPlannedItemToday,
                existingStatus: existingProposal?.status
            )
        )
        let seriousOpen = todayActivities.filter {
            !$0.isCompleted && !$0.isSkipped && CoachActivityClassifier.isSeriousTraining($0)
        }.count
        let stackedLoad = ProposalStackedLoadResolver.resolve(
            yesterdayHeavy: input.readiness.hadHeavyYesterday,
            tomorrowDemand: tomorrowDemand,
            recoveryBand: recoveryBand,
            todaySeriousOpenCount: seriousOpen
        )
        let generationMode = MorningProposalGenerationModeResolver.resolve(
            openCount: todayActivities.filter {
                !$0.isCompleted && !$0.isSkipped && CoachActivityClassifier.type(for: $0) != .none
            }.count,
            hasCompletedOrPartialToday: hasCompletedPlannedItemToday,
            isMorningWindow: isMorningWindow
        )
        let physiologyRevision = ProposalInputFingerprintBuilder.physiologyRevision(
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresenceForFP,
            yesterdayHeavy: input.readiness.hadHeavyYesterday,
            stackedLoad: stackedLoad
        )

        let liveFingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: dayKey,
            todaySnapshots: todayActivities,
            tomorrowSnapshots: tomorrowActivities,
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresenceForFP,
            scenarioKey: input.scenarioKey?.rawValue ?? "none",
            yesterdayHeavy: input.readiness.hadHeavyYesterday,
            observationContextRevision: observationContextRevision,
            behavioralGeneration: ProposalBehavioralPreferences.generation,
            stackedLoad: stackedLoad,
            generationMode: generationMode,
            mealLibraryRevision: input.mealLibraryRevision,
            physiologyContextRevision: physiologyRevision,
            weatherRiskToken: input.weatherRiskToken
        )
        MorningProposalService.markStaleIfNeeded(dayKey: dayKey, liveFingerprint: liveFingerprint)

        return MorningProposalService.evaluateAndPersist(
            context: .init(
                now: input.now,
                dayRolloverCompleted: input.dayRolloverCompleted,
                healthRefreshCompleted: healthRefreshCompleted,
                healthRefreshTimedOut: healthRefreshTimedOut,
                isHealthAccessGranted: input.isHealthAccessGranted,
                sleepHours: input.sleepHours,
                readiness: input.readiness,
                scenarioKey: input.scenarioKey,
                tomorrowDemand: tomorrowDemand,
                stackedLoad: stackedLoad,
                yesterdayHeavy: input.readiness.hadHeavyYesterday,
                completedWalkToday: completedWalkToday,
                todayActivities: todayActivities,
                tomorrowActivities: tomorrowActivities,
                isMorningWindow: isMorningWindow,
                hasCompletedPlannedItemToday: hasCompletedPlannedItemToday,
                recentDayTemplates: recentDayTemplates,
                mealLibrary: input.mealLibrary,
                observationContextRevision: observationContextRevision,
                mealLibraryRevision: input.mealLibraryRevision,
                behavioralGeneration: ProposalBehavioralPreferences.generation,
                walkRejectPenalty: ProposalBehavioralPreferences.walkRejectPenalty(from: behavioralSnapshot),
                stronglyRejectsWalk: ProposalBehavioralPreferences.stronglyRejectsWalk(from: behavioralSnapshot),
                weatherRiskToken: input.weatherRiskToken
            )
        )
    }

    /// Convenience readiness when Coach input is unavailable.
    nonisolated static func readinessFallback(
        readyScore: Double,
        sleepHours: Double,
        hadHeavyYesterday: Bool = false
    ) -> CoachDayReadiness {
        let percent = Int(readyScore.rounded())
        return CoachDayReadiness(
            recoveryPercent: percent,
            sleepHours: sleepHours,
            recoveryBand: percent >= 70 ? .good : (percent >= 55 ? .moderate : .low),
            hadHeavyYesterday: hadHeavyYesterday,
            sleepIsLow: sleepHours > 0 && sleepHours < 6,
            recoveryDataAvailable: percent > 0 || sleepHours > 0
        )
    }

    nonisolated static func hasRecoverySignals(
        sleepMinutes: Int,
        timeInBedMinutes: Int,
        hrvSDNN: Double,
        restingHeartRate: Double
    ) -> Bool {
        sleepMinutes > 0 || timeInBedMinutes > 0 || hrvSDNN > 0 || restingHeartRate > 0
    }

    static func mealLibrary(from settings: WeekFitUserSettings) -> (
        candidates: [ProposalMealCandidate],
        revision: String
    ) {
        let candidates = settings.customMealsCatalog.map {
            ProposalMealCandidate(
                id: $0.id,
                title: $0.title,
                imageName: $0.imageName,
                calories: $0.calories,
                protein: $0.protein,
                carbs: $0.carbs,
                fats: $0.fats,
                fiber: $0.fiber,
                mealsTypeRaw: $0.type.rawValue,
                suggestedTime: $0.suggestedTime
            )
        }
        return (candidates, "\(settings.customMealsCatalogRevision)")
    }

    static func buildRecentDayTemplates(
        from activities: [PlannedActivity],
        excludingDayStart: Date,
        calendar: Calendar,
        lookbackDays: Int
    ) -> [SimilarDayTemplate] {
        let oldest = calendar.date(byAdding: .day, value: -lookbackDays, to: excludingDayStart) ?? excludingDayStart
        let grouped = Dictionary(grouping: activities) { calendar.startOfDay(for: $0.date) }
        return grouped.compactMap { dayStart, dayActivities -> SimilarDayTemplate? in
            guard dayStart < excludingDayStart, dayStart >= oldest else { return nil }
            let dayKey = ProposalInputFingerprintBuilder.dayKey(for: dayStart, calendar: calendar)
            let snapshots = dayActivities.map(CoachPlannedActivitySnapshot.init(from:))
            guard snapshots.contains(where: { !$0.isSkipped }) else { return nil }

            let observation = CoachObservationStore.observation(for: dayKey)
            let observationAvailable = observation?.hasRecoverySignal == true
            let band: ProposalRecoveryBandToken
            let sleepPresence: ProposalSleepPresenceToken
            if let observation, observation.hasRecoverySignal {
                band = SimilarDayPlanMiner.recoveryBand(fromPercent: observation.recoveryPercent)
                sleepPresence = observation.hasSleepSignal ? .present : .missing
            } else {
                band = .unavailable
                sleepPresence = .unavailable
            }

            return SimilarDayTemplate(
                dayKey: dayKey,
                recoveryBand: band,
                observationAvailable: observationAvailable,
                sleepPresence: sleepPresence,
                activities: snapshots
            )
        }
    }
}
