import Foundation
@testable import WeekFit

final class TodayCoachScenarioFactory {
    private let calendar: Calendar
    private(set) var activities: [PlannedActivity]
    private(set) var cancelledActivities: [PlannedActivity] = []
    private(set) var deletedMealIDs: Set<String> = []

    private var sleepHours: Double?
    private var recoveryPercent: Int
    private var waterLitersByActivityID: [String: Double] = [:]

    private let strengthID = "stress-day-strength-1800"
    private let recoveryWalkID = "stress-day-recovery-walk"
    private let saunaID = "stress-day-sauna"

    init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        var calendar = calendar
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        self.calendar = calendar
        self.sleepHours = nil
        self.recoveryPercent = 58

        self.activities = [
            PlannedActivity(
                id: strengthID,
                date: Self.date(hour: 18, minute: 0, calendar: calendar),
                type: "workout",
                title: "Strength",
                durationMinutes: 60,
                icon: "figure.strengthtraining.traditional",
                colorRed: 0.94,
                colorGreen: 0.42,
                colorBlue: 0.30,
                source: "planner"
            )
        ]
    }

    var selectedDate: Date {
        Self.date(hour: 0, minute: 0, calendar: calendar)
    }

    func time(hour: Int, minute: Int = 0) -> Date {
        Self.date(hour: hour, minute: minute, calendar: calendar)
    }

    func syncPoorSleep() {
        sleepHours = 4.7
        recoveryPercent = 46
    }

    @discardableResult
    func logMeal(
        id: String,
        title: String,
        at date: Date,
        calories: Int,
        protein: Int,
        carbs: Int,
        fats: Int
    ) -> PlannedActivity {
        let meal = PlannedActivity(
            id: id,
            date: date,
            type: "meal",
            title: title,
            durationMinutes: 1,
            icon: "fork.knife",
            imageName: "fork.knife",
            colorRed: 0.16,
            colorGreen: 0.80,
            colorBlue: 0.43,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            isCompleted: true,
            source: "nutritionLog"
        )
        activities.removeAll { $0.id == id }
        activities.append(meal)
        deletedMealIDs.remove(id)
        return meal
    }

    func deleteMeal(id: String) {
        activities.removeAll { activity in
            let shouldDelete = activity.id == id && CoachCanonicalDayState.isNutritionLog(activity)
            if shouldDelete {
                deletedMealIDs.insert(activity.id)
            }
            return shouldDelete
        }
    }

    @discardableResult
    func logWater(id: String, title: String, liters: Double, at date: Date) -> PlannedActivity {
        let drink = PlannedActivity(
            id: id,
            date: date,
            type: "drink",
            title: title,
            durationMinutes: 1,
            icon: "drop.fill",
            imageName: "hydration",
            colorRed: 0.2,
            colorGreen: 0.5,
            colorBlue: 0.95,
            isCompleted: true,
            source: "hydration"
        )
        activities.removeAll { $0.id == id }
        activities.append(drink)
        waterLitersByActivityID[id] = liters
        return drink
    }

    func startRecoveryWalk(at date: Date) {
        activities.removeAll { $0.id == recoveryWalkID }
        cancelledActivities.removeAll { $0.id == recoveryWalkID }
        let walk = PlannedActivity(
            id: recoveryWalkID,
            date: date,
            type: "recovery",
            title: "Recovery Walk",
            durationMinutes: 35,
            icon: "figure.walk",
            colorRed: 0.35,
            colorGreen: 0.72,
            colorBlue: 0.48,
            source: "today"
        )
        activities.append(walk)
    }

    func cancelRecoveryWalk() {
        guard let index = activities.firstIndex(where: { $0.id == recoveryWalkID }) else { return }
        let cancelled = activities.remove(at: index)
        cancelled.isSkipped = true
        cancelledActivities.append(cancelled)
    }

    func completeRecoveryWalk(at date: Date, actualDurationMinutes: Int = 35) {
        if activities.contains(where: { $0.id == recoveryWalkID }) == false {
            startRecoveryWalk(at: date.addingTimeInterval(TimeInterval(-actualDurationMinutes * 60)))
        }

        guard let walk = activities.first(where: { $0.id == recoveryWalkID }) else { return }
        walk.isCompleted = true
        walk.actualDurationMinutes = actualDurationMinutes
        walk.date = date.addingTimeInterval(TimeInterval(-actualDurationMinutes * 60))
    }

    func startSauna(at date: Date) {
        activities.removeAll { $0.id == saunaID }
        let sauna = PlannedActivity(
            id: saunaID,
            date: date,
            type: "sauna",
            title: "Sauna",
            durationMinutes: 30,
            icon: "flame.fill",
            colorRed: 0.95,
            colorGreen: 0.46,
            colorBlue: 0.23,
            source: "today"
        )
        activities.append(sauna)
    }

    func completeSauna(at date: Date, actualDurationMinutes: Int = 30) {
        if activities.contains(where: { $0.id == saunaID }) == false {
            startSauna(at: date.addingTimeInterval(TimeInterval(-actualDurationMinutes * 60)))
        }

        guard let sauna = activities.first(where: { $0.id == saunaID }) else { return }
        sauna.isCompleted = true
        sauna.actualDurationMinutes = actualDurationMinutes
        sauna.date = date.addingTimeInterval(TimeInterval(-actualDurationMinutes * 60))
        recoveryPercent = min(recoveryPercent, 42)
    }

    func startPlannedStrength(at date: Date) {
        guard let strength = activities.first(where: { $0.id == strengthID }) else { return }
        strength.date = date
        strength.isCompleted = false
        strength.isSkipped = false
        strength.actualDurationMinutes = nil
    }

    func stopStrengthEarly(at date: Date, actualDurationMinutes: Int = 10) {
        guard let strength = activities.first(where: { $0.id == strengthID }) else { return }
        strength.date = date.addingTimeInterval(TimeInterval(-actualDurationMinutes * 60))
        strength.isCompleted = true
        strength.actualDurationMinutes = actualDurationMinutes
        recoveryPercent = min(recoveryPercent, 40)
    }

    func snapshot(checkpoint: String, action: String, at now: Date) -> CoachDebugSnapshot {
        let dayActivities = CoachCanonicalDayState.selectedDayActivities(
            from: activities,
            selectedDate: selectedDate,
            calendar: calendar
        )
        let completedMeals = CoachCanonicalDayState.completedMeals(from: dayActivities)
        let drinks = dayActivities.filter(CoachCanonicalDayState.isHydrationLog)
        let waterLiters = drinks.reduce(0.0) { partial, drink in
            partial + (waterLitersByActivityID[drink.id] ?? 0.5)
        }
        let goals = CoachMetricsBuilder.standardGoals
        let calories = Double(completedMeals.reduce(0) { $0 + $1.calories })
        let protein = Double(completedMeals.reduce(0) { $0 + $1.protein })
        let carbs = Double(completedMeals.reduce(0) { $0 + $1.carbs })
        let fats = Double(completedMeals.reduce(0) { $0 + $1.fats })
        let activeCalories = activeCaloriesEstimate(from: dayActivities, now: now)
        let metrics = CoachMetricsBuilder.metrics(
            protein: protein,
            carbs: carbs,
            fats: fats,
            calories: calories,
            waterLiters: waterLiters,
            activeCalories: activeCalories,
            sleepHours: sleepHours ?? 0
        )
        let brain = brainState(
            now: now,
            metrics: metrics,
            goals: goals,
            completedMeals: completedMeals,
            waterLiters: waterLiters,
            activeCalories: activeCalories
        )
        let nutritionContext = CoachNutritionContext(
            caloriesCurrent: calories,
            caloriesGoal: goals.calories,
            proteinCurrent: protein,
            proteinGoal: goals.protein,
            carbsCurrent: carbs,
            carbsGoal: goals.carbs,
            fatsCurrent: fats,
            fatsGoal: goals.fats,
            waterCurrent: waterLiters,
            waterGoal: goals.waterLiters,
            mealsCount: completedMeals.count,
            lastMealTime: completedMeals.last?.date
        )
        let recoveryContext = CoachRecoveryContext(
            recoveryPercent: recoveryPercent,
            sleepHours: sleepHours ?? 0
        )
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: selectedDate,
            now: now
        )
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: selectedDate,
            now: now,
            brain: brain
        )
        let guidance = CoachEngineV3.decide(
            from: brain,
            plannedActivities: activities,
            selectedDate: selectedDate,
            dayContext: dayContext,
            recoveryContext: recoveryContext,
            nutritionContext: nutritionContext
        )
        let plannerTrace = PlannerDebugTrace.make(
            activities: activities,
            selectedDate: selectedDate,
            calendar: calendar
        )
        let story = guidance.screenStory
        let active = activityContext.activeActivity
        let partial = dayContext.partialActivities
        let hydrationPromptVisible = hydrationPromptIsVisible(
            guidance: guidance,
            dayContext: dayContext,
            waterLiters: waterLiters,
            waterGoal: goals.waterLiters
        )
        let resolvedActivityRecommendation = activityRecommendation(
            guidance: guidance,
            activityContext: activityContext,
            dayContext: dayContext,
            partialActivities: partial
        )
        let protectionState = guidance.priority.tomorrowProtection
        let protectionReasons = protectionState.reasons
        let primaryLimiter = snapshotPrimaryLimiter(
            guidance: guidance,
            brain: brain,
            tomorrowProtection: protectionState
        )
        let readinessBreakdown = readinessBreakdown(
            brain: brain,
            dayContext: dayContext,
            nutritionContext: nutritionContext,
            recoveryContext: recoveryContext,
            partialActivities: partial
        )

        return CoachDebugSnapshot(
            checkpoint: checkpoint,
            action: action,
            now: now,
            todayCards: todayCards(
                dayContext: dayContext,
                activityContext: activityContext,
                partialActivities: partial,
                hydrationPromptVisible: hydrationPromptVisible
            ),
            coachHeadline: story?.title ?? guidance.title,
            coachNextAction: story?.primaryActions.first?.title ?? guidance.supportActions.first?.title ?? "",
            coachExplanation: story?.myRead ?? guidance.message,
            readinessScore: readinessBreakdown.final,
            readinessBreakdown: readinessBreakdown,
            recoveryState: brain.recovery,
            primaryLimiter: primaryLimiter,
            confidence: guidance.priority.confidence,
            hasMissingSleepData: brain.sleep == .unknown || recoveryContext.sleepHours <= 0,
            plannedActivities: dayContext.upcomingActivities.map(\.title),
            activeActivity: active?.title,
            completedActivities: dayContext.completedActivities.map(\.title),
            partialActivities: partial.map(\.title),
            cancelledActivities: cancelledActivities.map(\.title),
            meals: completedMeals.map(\.title),
            deletedMealIDs: deletedMealIDs,
            drinks: drinks.map(\.title),
            hydrationPromptVisible: hydrationPromptVisible,
            tomorrowProtection: protectionState.active,
            tomorrowProtectionState: protectionState,
            decisionTrace: decisionTrace(
                guidance: guidance,
                brain: brain,
                activityContext: activityContext,
                tomorrowProtection: protectionState,
                primaryLimiter: primaryLimiter
            ),
            plannerTrace: plannerTrace,
            recommendationTrace: recommendationTrace(guidance: guidance),
            rawStoredRecords: rawStoredRecords(from: dayActivities, now: now),
            activityRecommendation: resolvedActivityRecommendation,
            tomorrowProtectionReasons: protectionReasons,
            decisionAudit: decisionAudit(
                now: now,
                brain: brain,
                dayContext: dayContext,
                activityContext: activityContext,
                nutritionContext: nutritionContext,
                recoveryContext: recoveryContext,
                readinessBreakdown: readinessBreakdown,
                plannerTrace: plannerTrace,
                guidance: guidance,
                primaryLimiter: primaryLimiter,
                activityRecommendation: resolvedActivityRecommendation,
                tomorrowProtectionReasons: protectionReasons,
                partialActivities: partial,
                cancelledActivities: cancelledActivities
            ),
            guidance: guidance,
            dayContext: dayContext,
            activityContext: activityContext,
            nutritionContext: nutritionContext,
            recoveryContext: recoveryContext
        )
    }

    private func brainState(
        now: Date,
        metrics: DailyNutritionMetrics,
        goals: NutritionGoals,
        completedMeals: [PlannedActivity],
        waterLiters: Double,
        activeCalories: Double
    ) -> HumanBrain.State {
        let hour = calendar.component(.hour, from: now)
        let waterRatio = goals.waterLiters > 0 ? waterLiters / goals.waterLiters : 0
        let calorieRatio = goals.calories > 0 ? metrics.calories / goals.calories : 0
        let carbRatio = goals.carbs > 0 ? metrics.carbs / goals.carbs : 0
        var config = HumanBrainStateBuilder.Configuration()
        config.currentHour = hour
        config.hasAnyFoodLogged = !completedMeals.isEmpty
        config.energyCoverage = calorieRatio
        config.caloriesProgress = calorieRatio
        config.carbsProgress = carbRatio
        config.fatsProgress = goals.fats > 0 ? metrics.fats / goals.fats : 0
        config.waterProgress = waterRatio
        config.metrics = metrics
        config.goals = goals
        config.sleep = sleepHours == nil ? .unknown : ((sleepHours ?? 0) < 5 ? .veryShort : .short)
        config.hydration = waterRatio >= 1 ? .completed : (waterRatio < 0.35 ? .depleted : (waterRatio < 0.75 ? .behind : .optimal))
        config.fuel = calorieRatio < 0.30 ? .underfueled : (calorieRatio < 0.60 ? .light : .good)
        config.protein = calorieRatio < 0.30 ? .low : (calorieRatio < 0.60 ? .behind : .good)
        config.strain = activeCalories >= 700 ? .high : (activeCalories >= 300 ? .normal : .low)
        config.recovery = recoveryPercent < 45 ? .compromised : (recoveryPercent < 65 ? .vulnerable : .stable)
        config.readiness = sleepHours == nil || (sleepHours ?? 0) < 5 || recoveryPercent < 45 ? .low : .moderate
        config.completedWorkoutsCount = dayCompletedTrainingCount()
        return HumanBrainStateBuilder.make(config)
    }

    private func activeCaloriesEstimate(from activities: [PlannedActivity], now: Date) -> Double {
        activities.reduce(0.0) { total, activity in
            guard activity.date <= now else { return total }
            switch activity.timelineEventKind {
            case .workout:
                return total + Double(activity.effectiveDurationMinutes) * 8
            case .recovery:
                return total + Double(activity.effectiveDurationMinutes) * 3
            case .sauna:
                return total + Double(activity.effectiveDurationMinutes) * 2
            default:
                return total
            }
        }
    }

    private func dayCompletedTrainingCount() -> Int {
        activities.filter {
            guard $0.terminalState(now: selectedDate) == .completed else { return false }
            return $0.timelineEventKind == .workout || $0.timelineEventKind == .sauna
        }.count
    }

    private func todayCards(
        dayContext: CoachDayContext,
        activityContext: CoachDayActivityContext,
        partialActivities: [PlannedActivity],
        hydrationPromptVisible: Bool
    ) -> [String] {
        var cards: [String] = []
        let activeID = activityContext.activeActivity?.id
        if let active = activityContext.activeActivity {
            cards.append("active:\(active.title)")
        }
        cards += dayContext.upcomingActivities
            .filter { $0.id != activeID }
            .map { "planned:\($0.title)" }
        cards += dayContext.completedActivities.map { "completed:\($0.title)" }
        cards += dayContext.partialActivities.map { "partial:\($0.title)" }
        if dayContext.completedMealsCount == 0 {
            cards.append("mealPrompt:missing")
        }
        if hydrationPromptVisible {
            cards.append("hydrationPrompt")
        }
        return cards
    }

    private func hydrationPromptIsVisible(
        guidance: CoachGuidanceV3,
        dayContext: CoachDayContext,
        waterLiters: Double,
        waterGoal: Double
    ) -> Bool {
        guard waterGoal > 0, waterLiters < waterGoal else { return false }
        let hydrationRatio = waterLiters / waterGoal
        let isPostSaunaRecovery = dayContext.completedActivities.contains {
            $0.timelineEventKind == .sauna
        }
        guard hydrationRatio < 0.75 || isPostSaunaRecovery else {
            return false
        }

        let text = [
            guidance.title,
            guidance.message,
            guidance.screenStory?.myRead,
            guidance.screenStory?.myRecommendation,
            guidance.screenStory?.primaryActions.map(\.title).joined(separator: " "),
            guidance.screenStory?.supportActions.map(\.title).joined(separator: " "),
            guidance.priority.supportBullets.joined(separator: " ")
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
        if isPostSaunaRecovery, hydrationRatio >= 0.75 {
            return text.contains("sauna") ||
                text.contains("heat") ||
                text.contains("fluid") ||
                text.contains("drink") ||
                text.contains("sip")
        }

        return guidance.priority.limiter == .hydration ||
            text.contains("water") ||
            text.contains("fluid") ||
            text.contains("drink") ||
            text.contains("sip")
    }

    private func readinessScore(for readiness: HumanBrain.ReadinessState) -> Int {
        switch readiness {
        case .excellent: return 92
        case .good: return 78
        case .moderate: return 58
        case .low: return 35
        case .compromised: return 18
        }
    }

    private func readinessBreakdown(
        brain: HumanBrain.State,
        dayContext: CoachDayContext,
        nutritionContext: CoachNutritionContext,
        recoveryContext: CoachRecoveryContext,
        partialActivities: [PlannedActivity]
    ) -> CoachReadinessScoreBreakdown {
        var raw = 78
        var contributions: [String] = ["base=78"]

        let recoveryDelta: Int
        switch brain.recovery {
        case .compromised:
            recoveryDelta = -18
        case .vulnerable:
            recoveryDelta = -8
        case .stable:
            recoveryDelta = 0
        case .strong:
            recoveryDelta = 8
        }
        raw += recoveryDelta
        contributions.append("recovery=\(recoveryDelta)")

        let hydrationRatio = nutritionContext.waterGoal > 0 ? nutritionContext.waterCurrent / nutritionContext.waterGoal : 0
        let hydrationDelta: Int
        if hydrationRatio >= 1 {
            hydrationDelta = 5
        } else if hydrationRatio >= 0.75 {
            hydrationDelta = 2
        } else if hydrationRatio >= 0.35 {
            hydrationDelta = -3
        } else {
            hydrationDelta = -8
        }
        raw += hydrationDelta
        contributions.append("hydration=\(hydrationDelta)")

        let nutritionDelta: Int
        if nutritionContext.mealsCount == 0 {
            nutritionDelta = -8
        } else {
            let score = nutritionScore(nutritionContext)
            nutritionDelta = score >= 60 ? 5 : (score >= 30 ? 0 : -5)
        }
        raw += nutritionDelta
        contributions.append("nutrition=\(nutritionDelta)")

        if dayContext.completedRecoveryCount > 0 {
            raw += 4
            contributions.append("recoveryActivity=+4")
        }

        if dayContext.completedActivities.contains(where: { $0.timelineEventKind == .sauna }) {
            raw -= 8
            contributions.append("sauna=-8")
        }

        if !partialActivities.isEmpty {
            raw -= 5
            contributions.append("partialWorkout=-5")
        }

        raw = min(max(raw, 0), 100)

        var caps: [(value: Int, reason: String)] = []
        if brain.sleep == .unknown {
            caps.append((35, "missingSleep"))
        }
        if brain.sleep == .veryShort || recoveryContext.sleepHours > 0 && recoveryContext.sleepHours < 5 {
            caps.append((55, "veryShortSleep"))
        }
        if recoveryContext.recoveryPercent > 0, recoveryContext.recoveryPercent < 45 {
            caps.append((50, "compromisedRecovery"))
        }
        if brain.recovery == .compromised {
            caps.append((50, "compromisedRecovery"))
        }

        let selectedCap = caps.min { $0.value < $1.value }
        let final = selectedCap.map { min(raw, $0.value) } ?? raw

        return CoachReadinessScoreBreakdown(
            raw: raw,
            cap: selectedCap?.value,
            capReason: selectedCap?.reason,
            final: final,
            contributions: contributions
        )
    }

    private func decisionTrace(
        guidance: CoachGuidanceV3,
        brain: HumanBrain.State,
        activityContext: CoachDayActivityContext,
        tomorrowProtection: CoachTomorrowProtectionState,
        primaryLimiter: CoachLimiter
    ) -> String {
        "priority=\(guidance.priority.priority) focus=\(guidance.priority.focus) limiter=\(primaryLimiter) objective=\(guidance.priority.objective) confidence=\(String(format: "%.2f", guidance.priority.confidence)) sleep=\(brain.sleep) recovery=\(brain.recovery) readiness=\(brain.readiness) phase=\(activityContext.phase) tomorrowProtection.recommended=\(tomorrowProtection.recommended) tomorrowProtection.active=\(tomorrowProtection.active) tomorrowProtectionReasons=\(tomorrowProtection.reasons) tomorrowProtectionActiveReason=\(tomorrowProtection.activeReason ?? "nil")"
    }

    private func snapshotPrimaryLimiter(
        guidance: CoachGuidanceV3,
        brain: HumanBrain.State,
        tomorrowProtection: CoachTomorrowProtectionState
    ) -> CoachLimiter {
        guard tomorrowProtection.active else {
            return guidance.priority.limiter
        }

        let hour = brain.currentHour
        guard hour >= 15 else {
            return guidance.priority.limiter
        }

        if hour >= 18, tomorrowProtection.reasons.contains("partial workout") {
            return .accumulatedFatigue
        }

        if tomorrowProtection.reasons.contains("compromised recovery") ||
            tomorrowProtection.reasons.contains("low recovery score") ||
            tomorrowProtection.reasons.contains("sauna impact") {
            return .recovery
        }

        return guidance.priority.limiter
    }

    private func recommendationTrace(guidance: CoachGuidanceV3) -> String {
        let actions = guidance.screenStory?.primaryActions.map(\.title).joined(separator: " | ") ?? ""
        return "headline=\(guidance.screenStory?.title ?? guidance.title) nextAction=\(actions) why=\(guidance.screenStory?.whyThisMatters ?? "nil") support=\(guidance.priority.supportBullets.joined(separator: " | "))"
    }

    private func activityRecommendation(
        guidance: CoachGuidanceV3,
        activityContext: CoachDayActivityContext,
        dayContext: CoachDayContext,
        partialActivities: [PlannedActivity]
    ) -> String {
        if let active = activityContext.activeActivity {
            return active.title
        }

        if guidance.priority.tomorrowProtection.active {
            let hour = calendar.component(.hour, from: dayContext.now)
            let hasCompletedSauna = dayContext.completedActivities.contains {
                $0.timelineEventKind == .sauna
            }
            if hour >= 20 || dayContext.upcomingTrainingActivities.isEmpty {
                return "Wind down"
            }
            if hasCompletedSauna || guidance.priority.limiter == .recovery || guidance.priority.limiter == .accumulatedFatigue {
                return "Recovery"
            }
            if let futureTraining = dayContext.upcomingTrainingActivities.first {
                return "Modified \(futureTraining.title)"
            }
        }

        let currentOrFutureActivity = activityContext.preparingActivity ??
            activityContext.nextUpcomingActivity ??
            activityContext.laterTodayActivity
        if let currentOrFutureActivity {
            return currentOrFutureActivity.title
        }

        guard let activity = guidance.priority.activity else {
            return guidance.priority.objective == .protectTomorrow ? "Wind down" : "none"
        }

        let partialIDs = Set(partialActivities.map(\.id))
        let completedIDs = Set(dayContext.completedActivities.map(\.id))
        if partialIDs.contains(activity.id) {
            return "historical partial: \(activity.title)"
        }
        if completedIDs.contains(activity.id) {
            return "historical completed: \(activity.title)"
        }
        return activity.title
    }

    private func tomorrowProtectionReasons(
        now: Date,
        brain: HumanBrain.State,
        dayContext: CoachDayContext,
        partialActivities: [PlannedActivity],
        waterLiters: Double,
        waterGoal: Double
    ) -> [String] {
        var reasons: [String] = []
        let hour = calendar.component(.hour, from: now)
        if hour >= 22 {
            reasons.append("late evening recovery window")
        }
        if brain.sleep == .veryShort {
            reasons.append("short sleep")
            reasons.append("sleep debt")
        } else if brain.sleep == .unknown {
            reasons.append("missing sleep")
        }
        if brain.recovery == .compromised {
            reasons.append("compromised recovery")
            reasons.append("low recovery score")
        } else if brain.recovery == .vulnerable {
            reasons.append("vulnerable recovery")
        }
        if dayContext.completedActivities.contains(where: { $0.timelineEventKind == .sauna }) {
            reasons.append("sauna completed")
            reasons.append("sauna impact")
        }
        if !partialActivities.isEmpty {
            reasons.append("partial workout")
        }
        if dayContext.totalTrainingStressScore >= 5 {
            reasons.append("heavy training load")
        }
        if waterGoal > 0, waterLiters / waterGoal < 0.5 {
            reasons.append("hydration behind")
        }
        return reasons
    }

    private func decisionAudit(
        now: Date,
        brain: HumanBrain.State,
        dayContext: CoachDayContext,
        activityContext: CoachDayActivityContext,
        nutritionContext: CoachNutritionContext,
        recoveryContext: CoachRecoveryContext,
        readinessBreakdown: CoachReadinessScoreBreakdown,
        plannerTrace: PlannerDebugTrace,
        guidance: CoachGuidanceV3,
        primaryLimiter: CoachLimiter,
        activityRecommendation: String,
        tomorrowProtectionReasons: [String],
        partialActivities: [PlannedActivity],
        cancelledActivities: [PlannedActivity]
    ) -> CoachDecisionAudit {
        let hydrationPercent = nutritionContext.waterGoal > 0
            ? nutritionContext.waterCurrent / nutritionContext.waterGoal
            : 0
        let nutritionScore = nutritionScore(nutritionContext)
        let fatigueScore = fatigueScore(
            brain: brain,
            dayContext: dayContext,
            partialActivities: partialActivities
        )
        let sleepDebt = max(0, 8.0 - recoveryContext.sleepHours)
        let saunaImpact = dayContext.completedActivities.contains { $0.timelineEventKind == .sauna } ? "completed heat load" : "none"
        let plannerLoad = plannerTrace.reservedSlots.reduce(0) { $0 + $1.durationMinutes }

        return CoachDecisionAudit(
            rawInputs: [
                "sleepHours=\(String(format: "%.2f", recoveryContext.sleepHours))",
                "sleepQuality=\(sleepQuality(hours: recoveryContext.sleepHours, missing: brain.sleep == .unknown))",
                "sleepDebt=\(String(format: "%.2f", sleepDebt))h",
                "recoveryPercent=\(recoveryContext.recoveryPercent)",
                "recoveryState=\(brain.recovery)",
                "fatigueScore=\(fatigueScore)",
                "hydrationLiters=\(String(format: "%.2f", nutritionContext.waterCurrent))",
                "hydrationTargetLiters=\(String(format: "%.2f", nutritionContext.waterGoal))",
                "hydrationPercent=\(String(format: "%.0f%%", hydrationPercent * 100))",
                "mealsLogged=\(nutritionContext.mealsCount)",
                "deletedMeals=\(deletedMealIDs.sorted())",
                "nutritionScore=\(nutritionScore)",
                "plannedActivities=\(dayContext.upcomingActivities.map(\.title))",
                "activeActivities=\(activityContext.activeActivity.map { [$0.title] } ?? [])",
                "completedActivities=\(dayContext.completedActivities.filter { !Set(partialActivities.map(\.id)).contains($0.id) }.map(\.title))",
                "cancelledActivities=\(cancelledActivities.map(\.title))",
                "partialActivities=\(partialActivities.map(\.title))",
                "activityLoad=completedTrainingMinutes:\(dayContext.completedTrainingMinutes), upcomingTrainingMinutes:\(dayContext.upcomingTrainingMinutes), stress:\(dayContext.totalTrainingStressScore)",
                "saunaState=\(saunaState(in: dayContext, activityContext: activityContext))",
                "saunaImpact=\(saunaImpact)",
                "plannerLoad=\(plannerLoad)m"
            ],
            normalizedValues: [
                "sleepState=\(brain.sleep)",
                "hydrationState=\(brain.hydration)",
                "recoveryState=\(brain.recovery)",
                "fatigueState=\(fatigueState(score: fatigueScore))",
                "nutritionState=\(brain.fuel)",
                "activityState=\(activityState(dayContext: dayContext, partialActivities: partialActivities))",
                "saunaState=\(saunaState(in: dayContext, activityContext: activityContext))"
            ],
            scoringBreakdown: [
                "sleep contribution=\(sleepContribution(brain.sleep)); veryShort sleep caps readiness at low",
                "recovery contribution=\(recoveryContribution(brain.recovery))",
                "hydration contribution=\(hydrationContribution(brain.hydration))",
                "nutrition contribution=\(nutritionContribution(brain.fuel, nutritionScore: nutritionScore))",
                "activity contribution=\(activityContribution(dayContext: dayContext, partialActivities: partialActivities))",
                "sauna contribution=\(saunaContribution(dayContext: dayContext))",
                "planner contribution=\(plannerContribution(plannerTrace))",
                "readiness raw=\(readinessBreakdown.raw), cap=\(readinessBreakdown.cap.map(String.init) ?? "none"), capReason=\(readinessBreakdown.capReason ?? "none"), final=\(readinessBreakdown.final)"
            ],
            finalDecision: [
                "readiness.raw=\(readinessBreakdown.raw)",
                "readiness.cap=\(readinessBreakdown.cap.map(String.init) ?? "none")",
                "readiness.capReason=\(readinessBreakdown.capReason ?? "none")",
                "readiness.final=\(readinessBreakdown.final)",
                "primaryLimiter=\(primaryLimiter.label)",
                "confidence=\(String(format: "%.2f", guidance.priority.confidence))",
                "todayHeadline=\(guidance.insightTitle)",
                "coachHeadline=\(guidance.screenStory?.title ?? guidance.title)",
                "nextAction=\(guidance.screenStory?.primaryActions.first?.title ?? guidance.supportActions.first?.title ?? "none")",
                "activityRecommendation=\(activityRecommendation)",
                "tomorrowProtection.recommended=\(guidance.priority.tomorrowProtection.recommended)",
                "tomorrowProtection.active=\(guidance.priority.tomorrowProtection.active)",
                "tomorrowProtection.activeReason=\(guidance.priority.tomorrowProtection.activeReason ?? "none")",
                "tomorrowProtectionReasons=\(tomorrowProtectionReasons)"
            ]
        )
    }

    private func rawStoredRecords(from activities: [PlannedActivity], now: Date) -> [String] {
        activities.map { activity in
            let status: String
            switch activity.terminalState(now: now) {
            case .cancelled:
                status = "cancelled"
            case .partial:
                status = "partial \(activity.effectiveDurationMinutes)m/\(activity.durationMinutes)m"
            case .completed:
                status = "completed"
            case .active:
                status = "active"
            case .planned:
                status = "planned"
            }

            let water = waterLitersByActivityID[activity.id].map { " water=\(String(format: "%.2f", $0))L" } ?? ""
            return "\(activity.title) [id=\(activity.id), type=\(activity.type), source=\(activity.source), kind=\(activity.timelineEventKind), status=\(status), start=\(timeString(activity.date)), duration=\(activity.effectiveDurationMinutes)m, blocksPlannerTime=\(activity.blocksPlannerTime)\(water)]"
        }
    }

    private func nutritionScore(_ context: CoachNutritionContext) -> Int {
        guard context.caloriesGoal > 0 else { return 0 }
        let calorieScore = min(1.0, context.caloriesCurrent / context.caloriesGoal) * 50
        let proteinScore = context.proteinGoal > 0 ? min(1.0, context.proteinCurrent / context.proteinGoal) * 30 : 0
        let hydrationScore = context.waterGoal > 0 ? min(1.0, context.waterCurrent / context.waterGoal) * 20 : 0
        return Int((calorieScore + proteinScore + hydrationScore).rounded())
    }

    private func fatigueScore(
        brain: HumanBrain.State,
        dayContext: CoachDayContext,
        partialActivities: [PlannedActivity]
    ) -> Int {
        var score = 0
        if brain.sleep == .veryShort { score += 35 }
        if brain.sleep == .unknown { score += 15 }
        if brain.recovery == .compromised { score += 30 }
        if brain.recovery == .vulnerable { score += 15 }
        score += min(25, dayContext.completedTrainingStressScore * 5)
        score += dayContext.completedActivities.contains { $0.timelineEventKind == .sauna } ? 15 : 0
        score += partialActivities.isEmpty ? 0 : 10
        return min(score, 100)
    }

    private func sleepQuality(hours: Double, missing: Bool) -> String {
        if missing || hours <= 0 { return "missing" }
        if hours < 5 { return "poor" }
        if hours < 6.5 { return "short" }
        return "ok"
    }

    private func fatigueState(score: Int) -> String {
        if score >= 70 { return "high" }
        if score >= 40 { return "elevated" }
        return "low"
    }

    private func activityState(
        dayContext: CoachDayContext,
        partialActivities: [PlannedActivity]
    ) -> String {
        if !partialActivities.isEmpty { return "partialWorkoutCompleted" }
        if dayContext.hasMoreLoadAhead { return "loadAhead" }
        if dayContext.hasMeaningfulLoadCompleted { return "loadCompleted" }
        return "stable"
    }

    private func saunaState(
        in dayContext: CoachDayContext,
        activityContext: CoachDayActivityContext
    ) -> String {
        if dayContext.completedActivities.contains(where: { $0.timelineEventKind == .sauna }) {
            return "completed"
        }
        if activityContext.activeActivity?.timelineEventKind == .sauna {
            return "active"
        }
        if dayContext.upcomingActivities.contains(where: { $0.timelineEventKind == .sauna }) {
            return "planned"
        }
        return "none"
    }

    private func sleepContribution(_ state: HumanBrain.SleepState) -> String {
        switch state {
        case .unknown:
            return "-15 incomplete data"
        case .veryShort:
            return "-35 severe cap"
        case .short:
            return "-20"
        case .okay:
            return "0"
        case .strong:
            return "+10"
        }
    }

    private func recoveryContribution(_ state: HumanBrain.RecoveryState) -> String {
        switch state {
        case .compromised:
            return "-30"
        case .vulnerable:
            return "-15"
        case .stable:
            return "0"
        case .strong:
            return "+10"
        }
    }

    private func hydrationContribution(_ state: HumanBrain.HydrationState) -> String {
        switch state {
        case .depleted:
            return "-20"
        case .behind:
            return "-10"
        case .optimal:
            return "0"
        case .completed:
            return "+5"
        case .excessive:
            return "-5 excessive"
        }
    }

    private func nutritionContribution(_ state: HumanBrain.FuelState, nutritionScore: Int) -> String {
        switch state {
        case .underfueled:
            return "-15 score=\(nutritionScore)"
        case .light:
            return "-5 score=\(nutritionScore)"
        case .good:
            return "+5 score=\(nutritionScore)"
        case .overfueled:
            return "-5 over target score=\(nutritionScore)"
        }
    }

    private func activityContribution(
        dayContext: CoachDayContext,
        partialActivities: [PlannedActivity]
    ) -> String {
        let partial = partialActivities.isEmpty ? "" : ", partial workout reduces full-load credit"
        return "completedStress=\(dayContext.completedTrainingStressScore), upcomingStress=\(dayContext.upcomingTrainingStressScore)\(partial)"
    }

    private func saunaContribution(dayContext: CoachDayContext) -> String {
        dayContext.completedActivities.contains { $0.timelineEventKind == .sauna }
            ? "-15 completed sauna heat load"
            : "0"
    }

    private func plannerContribution(_ plannerTrace: PlannerDebugTrace) -> String {
        let load = plannerTrace.reservedSlots.reduce(0) { $0 + $1.durationMinutes }
        return "reservedMinutes=\(load), ignoredFoodDrinkIDs=\(plannerTrace.ignoredFoodAndDrinkIDs)"
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    private static func date(hour: Int, minute: Int, calendar: Calendar) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 9,
            hour: hour,
            minute: minute
        ).date!
    }
}
