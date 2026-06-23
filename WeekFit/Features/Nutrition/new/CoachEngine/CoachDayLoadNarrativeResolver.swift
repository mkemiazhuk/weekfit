import Foundation

/// Accumulated day load bands for narrative modifier (Phase F).
enum CoachDayLoadBand: Equatable {
    case fresh
    case moderate
    case heavy
    case extreme
}

/// What the coach is trying to accomplish in the live session.
enum CoachDayLoadCoachingJob: Equatable {
    /// Standard chapter progression — optimize execution of this session.
    case optimizeExecution
    /// Single heavy/extreme session — finish without breaking the day.
    case survivalExecution
    /// Stacked serious session — protect the day, not performance.
    case dayCap
}

/// Performance vs protection copy within the same activity family and chapter clock.
enum CoachEnduranceNarrativeTrack: Equatable {
    case performance
    case protection
}

enum CoachDayLoadNarrativeResolver {

    struct Context {
        let band: CoachDayLoadBand
        let coachingJob: CoachDayLoadCoachingJob
        let priorCompletedSeriousSession: PlannedActivity?
        let narrativeTrack: CoachEnduranceNarrativeTrack
    }

    static func resolve(
        input: CoachInputSnapshot,
        activeActivity: PlannedActivity?,
        seriousCompleted: PlannedActivity?,
        shouldProtectTomorrow: Bool
    ) -> Context {
        let priorCompletedSerious = priorCompletedSeriousSession(
            seriousCompleted: seriousCompleted,
            activeActivity: activeActivity
        )
        let activeSerious = activeActivity.flatMap { isSeriousTraining($0) ? $0 : nil }
        let band = dayLoadBand(
            input: input,
            priorCompletedSerious: priorCompletedSerious,
            activeSerious: activeSerious
        )
        let coachingJob = coachingJob(
            band: band,
            priorCompletedSerious: priorCompletedSerious,
            activeSerious: activeSerious,
            shouldProtectTomorrow: shouldProtectTomorrow
        )
        let narrativeTrack: CoachEnduranceNarrativeTrack =
            coachingJob == .optimizeExecution ? .performance : .protection

        return Context(
            band: band,
            coachingJob: coachingJob,
            priorCompletedSeriousSession: priorCompletedSerious,
            narrativeTrack: narrativeTrack
        )
    }

    static func priorCompletedSeriousSession(
        seriousCompleted: PlannedActivity?,
        activeActivity: PlannedActivity?
    ) -> PlannedActivity? {
        guard let prior = seriousCompleted,
              prior.isCompleted,
              isSeriousTraining(prior) else {
            return nil
        }
        guard let active = activeActivity,
              !active.isCompleted,
              isSeriousTraining(active) else {
            return nil
        }
        guard prior.id != active.id else { return nil }
        return prior
    }

    static func resolveFromSnapshot(
        input: CoachInputSnapshot,
        shouldProtectTomorrow: Bool
    ) -> Context {
        let activeActivity = input.plannedActivities.first {
            !$0.isSkipped && !$0.isCompleted && $0.isActive(at: input.now)
        }
        let calendar = Calendar.current
        let seriousCompleted = input.plannedActivities
            .filter {
                calendar.isDate($0.date, inSameDayAs: input.now) &&
                    $0.isCompleted &&
                    !$0.isSkipped &&
                    isSeriousTraining($0)
            }
            .sorted { $0.date > $1.date }
            .first
        return resolve(
            input: input,
            activeActivity: activeActivity,
            seriousCompleted: seriousCompleted,
            shouldProtectTomorrow: shouldProtectTomorrow
        )
    }

    private static func coachingJob(
        band: CoachDayLoadBand,
        priorCompletedSerious: PlannedActivity?,
        activeSerious: PlannedActivity?,
        shouldProtectTomorrow: Bool
    ) -> CoachDayLoadCoachingJob {
        if priorCompletedSerious != nil, activeSerious != nil {
            return .dayCap
        }
        if band == .extreme, activeSerious != nil {
            return .survivalExecution
        }
        if band == .heavy, activeSerious != nil, shouldProtectTomorrow {
            return .survivalExecution
        }
        return .optimizeExecution
    }

    private static func dayLoadBand(
        input: CoachInputSnapshot,
        priorCompletedSerious: PlannedActivity?,
        activeSerious: PlannedActivity?
    ) -> CoachDayLoadBand {
        let bands: [CoachDayLoadBand] = [
            bandFromSeriousWork(
                priorCompletedSerious: priorCompletedSerious,
                activeSerious: activeSerious,
                input: input
            ),
            bandFromCalories(input.actualLoad.activeCalories),
            bandFromProgress(input.actualLoad.activityProgress),
            bandFromVolume(input.dayContext.completedActivityVolumeMinutes)
        ]
        return bands.max { bandRank($0) < bandRank($1) } ?? .fresh
    }

    private static func bandRank(_ band: CoachDayLoadBand) -> Int {
        switch band {
        case .fresh: return 0
        case .moderate: return 1
        case .heavy: return 2
        case .extreme: return 3
        }
    }

    private static func bandFromSeriousWork(
        priorCompletedSerious: PlannedActivity?,
        activeSerious: PlannedActivity?,
        input: CoachInputSnapshot
    ) -> CoachDayLoadBand {
        if priorCompletedSerious != nil, activeSerious != nil {
            return .extreme
        }
        if priorCompletedSerious != nil {
            return .heavy
        }

        let completedSeriousCount = input.plannedActivities.filter {
            Calendar.current.isDate($0.date, inSameDayAs: input.now) &&
                $0.isCompleted &&
                !$0.isSkipped &&
                isSeriousTraining($0)
        }.count
        if completedSeriousCount >= 2 {
            return .extreme
        }
        if completedSeriousCount >= 1, activeSerious != nil {
            return .heavy
        }
        return .fresh
    }

    private static func bandFromCalories(_ calories: Double) -> CoachDayLoadBand {
        switch calories {
        case 1_200...:
            return .extreme
        case 700..<1_200:
            return .heavy
        case 400..<700:
            return .moderate
        default:
            return .fresh
        }
    }

    private static func bandFromProgress(_ progress: Double?) -> CoachDayLoadBand {
        guard let progress else { return .fresh }
        switch progress {
        case 1.9...:
            return .extreme
        case 1.5..<1.9:
            return .heavy
        case 1.0..<1.5:
            return .moderate
        default:
            return .fresh
        }
    }

    private static func bandFromVolume(_ minutes: Int) -> CoachDayLoadBand {
        switch minutes {
        case 240...:
            return .extreme
        case 90..<240:
            return .heavy
        case 60..<90:
            return .moderate
        default:
            return .fresh
        }
    }

    private static func isSeriousTraining(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
        let minutes = activity.effectiveDurationMinutes
        let text = "\(activity.title) \(activity.type)".lowercased()

        if text.contains("recovery") ||
            text.contains("stretch") ||
            text.contains("mobility") ||
            text.contains("yoga") ||
            text.contains("breath") ||
            text.contains("walk") ||
            text.contains("walking") {
            return false
        }

        if kind == .endurance {
            return minutes >= 75 || load == .high || load == .extreme ||
                text.contains("interval") || text.contains("long")
        }

        if kind == .workout {
            let strength = text.contains("strength") || text.contains("gym") ||
                text.contains("lift") || text.contains("weight")
            let racket = text.contains("tennis") || text.contains("squash")
            return (strength && (minutes >= 45 || load == .high || load == .extreme)) ||
                (racket && (minutes >= 60 || load == .high || load == .extreme)) ||
                load == .extreme
        }

        return false
    }
}
