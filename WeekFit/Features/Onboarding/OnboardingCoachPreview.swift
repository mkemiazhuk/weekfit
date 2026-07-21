import Foundation

/// Shared local-day greeting windows for Today + onboarding Ready.
/// Always derived from the device calendar (user's current time zone).
enum WeekFitLocalDayPeriod: Equatable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    /// Level‑1 windows: 05–10 prepare · 11–16 guide · 17–20 adjust · 21–04 recover.
    static func from(now: Date = Date(), calendar: Calendar = .current) -> WeekFitLocalDayPeriod {
        switch calendar.component(.hour, from: now) {
        case 5..<11: return .morning
        case 11..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }

    var isDaytime: Bool {
        self == .morning || self == .afternoon
    }

    var isWindDown: Bool {
        self == .evening || self == .night
    }
}

/// Simplified coach voice for onboarding Ready — same inputs Tomorrow/Today care about:
/// local time × recovery × goal × sleep × (optional) load. Not a second copy system.
enum OnboardingCoachPreview {

    enum HealthAvailability: Equatable, Sendable {
        case connected
        case limited
        case unavailable
    }

    enum RecoveryTier: Equatable, Sendable {
        case good
        case moderate
        case low
        case unknown

        /// Aligns with `CoachDayReadinessResolver` bands (good ≥70, low <55).
        static func from(recoveryPercent: Int?) -> RecoveryTier {
            guard let recoveryPercent, recoveryPercent > 0 else { return .unknown }
            if recoveryPercent >= 70 { return .good }
            if recoveryPercent >= 55 { return .moderate }
            return .low
        }
    }

    struct Input: Equatable, Sendable {
        var now: Date
        var calendar: Calendar
        var goal: NutritionGoal
        var recoveryPercent: Int?
        var sleepHours: Double?
        var activeCalories: Double?
        var steps: Int?
        var health: HealthAvailability

        init(
            now: Date = Date(),
            calendar: Calendar = .current,
            goal: NutritionGoal,
            recoveryPercent: Int? = nil,
            sleepHours: Double? = nil,
            activeCalories: Double? = nil,
            steps: Int? = nil,
            health: HealthAvailability
        ) {
            self.now = now
            self.calendar = calendar
            self.goal = goal
            self.recoveryPercent = recoveryPercent
            self.sleepHours = sleepHours
            self.activeCalories = activeCalories
            self.steps = steps
            self.health = health
        }
    }

    struct Output: Equatable, Sendable {
        var greetingTitle: String
        var supportingMessage: String
        var mirrorLine: String
        var primaryAction: String
        var secondaryAction: String
        var recoveryAction: String
        var footer: String
    }

    static func build(_ input: Input) -> Output {
        let period = WeekFitLocalDayPeriod.from(now: input.now, calendar: input.calendar)
        let recovery = RecoveryTier.from(recoveryPercent: input.recoveryPercent)
        let shortSleep = isShortSleep(input.sleepHours)
        let movedToday = hasMeaningfulLoad(activeCalories: input.activeCalories, steps: input.steps)

        return Output(
            greetingTitle: greetingTitle(for: period),
            supportingMessage: supportingMessage(
                period: period,
                recovery: recovery,
                goal: input.goal,
                shortSleep: shortSleep,
                movedToday: movedToday,
                health: input.health
            ),
            mirrorLine: mirrorLine(for: input.goal),
            primaryAction: primaryAction(
                period: period,
                recovery: recovery,
                goal: input.goal,
                movedToday: movedToday
            ),
            secondaryAction: secondaryAction(period: period, goal: input.goal),
            recoveryAction: recoveryAction(
                period: period,
                recovery: recovery,
                shortSleep: shortSleep
            ),
            footer: footer(for: input.health)
        )
    }

    // MARK: - Inputs

    private static func isShortSleep(_ sleepHours: Double?) -> Bool {
        guard let sleepHours, sleepHours > 0 else { return false }
        return sleepHours < 6
    }

    private static func hasMeaningfulLoad(activeCalories: Double?, steps: Int?) -> Bool {
        if let activeCalories, activeCalories >= 350 { return true }
        if let steps, steps >= 6_000 { return true }
        return false
    }

    // MARK: - Greeting

    private static func greetingTitle(for period: WeekFitLocalDayPeriod) -> String {
        switch period {
        case .morning:
            return WeekFitLocalizedString("onboarding.v12.ready.title.morning")
        case .afternoon:
            return WeekFitLocalizedString("onboarding.v12.ready.title.afternoon")
        case .evening:
            return WeekFitLocalizedString("onboarding.v12.ready.title.evening")
        case .night:
            return WeekFitLocalizedString("onboarding.v12.ready.title.night")
        }
    }

    // MARK: - Supporting message (time × recovery × goal × sleep)

    private static func supportingMessage(
        period: WeekFitLocalDayPeriod,
        recovery: RecoveryTier,
        goal: NutritionGoal,
        shortSleep: Bool,
        movedToday: Bool,
        health: HealthAvailability
    ) -> String {
        let live = health == .connected || health == .limited

        if live, shortSleep, period.isWindDown {
            return WeekFitLocalizedString("onboarding.coachPreview.support.windDown.shortSleep")
        }

        if live, period == .evening, recovery == .good, movedToday {
            return WeekFitLocalizedString("onboarding.coachPreview.support.evening.recoveredAndMoved")
        }

        if live, period == .evening, recovery == .good {
            return WeekFitLocalizedString("onboarding.coachPreview.support.evening.recoveredWell")
        }

        switch period {
        case .morning:
            if shortSleep || recovery == .low {
                return WeekFitLocalizedString("onboarding.coachPreview.support.morning.low")
            }
            switch recovery {
            case .good:
                return WeekFitLocalizedString("onboarding.coachPreview.support.morning.good")
            case .moderate:
                return WeekFitLocalizedString("onboarding.coachPreview.support.morning.moderate")
            case .low, .unknown:
                return WeekFitLocalizedString("onboarding.coachPreview.support.morning.unknown")
            }

        case .afternoon:
            switch recovery {
            case .good:
                return WeekFitLocalizedString("onboarding.coachPreview.support.afternoon.good")
            case .low:
                return WeekFitLocalizedString("onboarding.coachPreview.support.afternoon.low")
            case .moderate, .unknown:
                return WeekFitLocalizedString("onboarding.coachPreview.support.afternoon.guide")
            }

        case .evening:
            switch goal {
            case .fatLoss:
                return WeekFitLocalizedString("onboarding.coachPreview.support.evening.fatLoss")
            case .muscleGain:
                return WeekFitLocalizedString("onboarding.coachPreview.support.evening.muscleGain")
            case .maintenance:
                return WeekFitLocalizedString("onboarding.coachPreview.support.evening.maintenance")
            }

        case .night:
            if shortSleep || recovery == .low {
                return WeekFitLocalizedString("onboarding.coachPreview.support.night.low")
            }
            if recovery == .good {
                return WeekFitLocalizedString("onboarding.coachPreview.support.night.good")
            }
            return WeekFitLocalizedString("onboarding.coachPreview.support.night.default")
        }
    }

    private static func mirrorLine(for goal: NutritionGoal) -> String {
        switch goal {
        case .fatLoss:
            return WeekFitLocalizedString("onboarding.v12.ready.mirror.fatLoss")
        case .maintenance:
            return WeekFitLocalizedString("onboarding.v12.ready.mirror.maintenance")
        case .muscleGain:
            return WeekFitLocalizedString("onboarding.v12.ready.mirror.muscleGain")
        }
    }

    // MARK: - Actions (must be actionable now)

    private static func primaryAction(
        period: WeekFitLocalDayPeriod,
        recovery: RecoveryTier,
        goal: NutritionGoal,
        movedToday: Bool
    ) -> String {
        switch period {
        case .morning, .afternoon:
            switch recovery {
            case .good:
                return WeekFitLocalizedString("onboarding.coachPreview.action.train.day.good")
            case .low:
                return WeekFitLocalizedString("onboarding.coachPreview.action.train.day.low")
            case .moderate, .unknown:
                switch goal {
                case .fatLoss:
                    return WeekFitLocalizedString("onboarding.coachPreview.action.train.day.fatLoss")
                case .muscleGain:
                    return WeekFitLocalizedString("onboarding.coachPreview.action.train.day.muscleGain")
                case .maintenance:
                    return WeekFitLocalizedString("onboarding.coachPreview.action.train.day.steady")
                }
            }

        case .evening:
            if movedToday {
                return WeekFitLocalizedString("onboarding.coachPreview.action.train.evening.done")
            }
            switch goal {
            case .fatLoss:
                return WeekFitLocalizedString("onboarding.coachPreview.action.train.evening.fatLoss")
            case .muscleGain:
                return WeekFitLocalizedString("onboarding.coachPreview.action.train.evening.muscleGain")
            case .maintenance:
                return WeekFitLocalizedString("onboarding.coachPreview.action.train.evening.maintenance")
            }

        case .night:
            return WeekFitLocalizedString("onboarding.coachPreview.action.train.night")
        }
    }

    private static func secondaryAction(period: WeekFitLocalDayPeriod, goal: NutritionGoal) -> String {
        switch period {
        case .morning:
            switch goal {
            case .fatLoss:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.morning.fatLoss")
            case .muscleGain:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.morning.muscleGain")
            case .maintenance:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.morning.maintenance")
            }
        case .afternoon:
            switch goal {
            case .fatLoss:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.afternoon.fatLoss")
            case .muscleGain:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.afternoon.muscleGain")
            case .maintenance:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.afternoon.maintenance")
            }
        case .evening:
            switch goal {
            case .fatLoss:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.evening.fatLoss")
            case .muscleGain:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.evening.muscleGain")
            case .maintenance:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.evening.maintenance")
            }
        case .night:
            switch goal {
            case .fatLoss:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.night.fatLoss")
            case .muscleGain:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.night.muscleGain")
            case .maintenance:
                return WeekFitLocalizedString("onboarding.coachPreview.action.meal.night.maintenance")
            }
        }
    }

    private static func recoveryAction(
        period: WeekFitLocalDayPeriod,
        recovery: RecoveryTier,
        shortSleep: Bool
    ) -> String {
        if period == .night {
            if shortSleep || recovery == .low {
                return WeekFitLocalizedString("onboarding.coachPreview.action.recovery.night.low")
            }
            return WeekFitLocalizedString("onboarding.coachPreview.action.recovery.night.good")
        }

        if period == .evening {
            switch recovery {
            case .good:
                return WeekFitLocalizedString("onboarding.coachPreview.action.recovery.evening.good")
            case .low:
                return WeekFitLocalizedString("onboarding.coachPreview.action.recovery.evening.low")
            case .moderate, .unknown:
                return WeekFitLocalizedString("onboarding.coachPreview.action.recovery.evening.mid")
            }
        }

        switch recovery {
        case .good:
            return WeekFitLocalizedString("onboarding.coachPreview.action.recovery.day.good")
        case .low:
            return WeekFitLocalizedString("onboarding.coachPreview.action.recovery.day.low")
        case .moderate:
            return WeekFitLocalizedString("onboarding.coachPreview.action.recovery.day.mid")
        case .unknown:
            return WeekFitLocalizedString("onboarding.coachPreview.action.recovery.day.sample")
        }
    }

    private static func footer(for health: HealthAvailability) -> String {
        switch health {
        case .connected:
            return WeekFitLocalizedString("onboarding.v12.ready.body.connected")
        case .limited:
            return WeekFitLocalizedString("onboarding.v12.ready.body.limited")
        case .unavailable:
            return WeekFitLocalizedString("onboarding.v12.ready.body.skipped")
        }
    }
}
