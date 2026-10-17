import Foundation
import WeekFitPlanner

enum CoachEveningSummaryBuildBlock: String, Sendable {
    case selectedDateNotToday
    case snapshotStale
    case outsideEveningWindow
}

@MainActor
enum CoachEveningSummaryInputBuilder {
    /// Why `build` returned nil — for diagnostics only (no personal data).
    static func buildBlockReason(input: CoachInputSnapshot?, now: Date,
                                 calendar: Calendar = .current) -> CoachEveningSummaryBuildBlock? {
        guard let input else { return .snapshotStale }
        guard calendar.isDate(input.selectedDate, inSameDayAs: now) else {
            return .selectedDateNotToday
        }
        if CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow {
            // Evening recap auto path: require local evening; allow slightly stale snapshots.
            guard CoachEveningSummaryPolicy.isEvening(now, calendar: calendar) else {
                return .outsideEveningWindow
            }
            guard abs(input.now.timeIntervalSince(now)) < 30 * 60 else { return .snapshotStale }
        }
        return nil
    }

    static func build(input: CoachInputSnapshot, presentation: CoachUIPresentation?,
                      activities: [PlannedActivity], locale: String, now: Date,
                      calendar: Calendar = .current,
                      dayComparisonFact: String? = nil) -> CoachEveningSummaryInput? {
        if buildBlockReason(input: input, now: now, calendar: calendar) != nil { return nil }
        typealias Fact = CoachEveningSummaryInput.Fact
        var facts: [String: [Fact]] = [:]
        func fact(_ id: String, _ text: String) -> Fact {
            Fact(id: id, text: String(text.prefix(500)))
        }
        if input.isHealthAccessGranted {
            var sleep: [Fact] = []
            if input.recoveryContext.sleepHours > 0 {
                sleep.append(fact("sleep.duration", "Sleep recorded for today: \(input.recoveryContext.sleepHours) hours. Source: HealthKit."))
            }
            if input.recoveryContext.recoveryPercent > 0 {
                sleep.append(fact("sleep.recovery", "Today's WeekFit recovery score: \(input.recoveryContext.recoveryPercent)%. This is today's score, not a forecast."))
            }
            facts["sleep"] = sleep
        }
        let today = CoachCanonicalDayState.selectedDayActivities(from: activities, selectedDate: now, calendar: calendar)
        let meals = CoachCanonicalDayState.completedMeals(from: today)
        var nutrition = [fact("nutrition.completeness", "Food log completeness is unknown. Zero logged intake does not prove no food was eaten. Values are journal entries, potentially estimated.")]
        if let n = input.nutritionContext {
            nutrition.append(fact("nutrition.totals", "Recorded intake: \(Int(n.caloriesCurrent)) kcal; protein \(Int(n.proteinCurrent)) g; carbs \(Int(n.carbsCurrent)) g; fats \(Int(n.fatsCurrent)) g; water \(n.waterCurrent) L."))
            nutrition.append(fact("nutrition.goals", "Current WeekFit goals: \(Int(n.caloriesGoal)) kcal; protein \(Int(n.proteinGoal)) g; water \(n.waterGoal) L. Do not invent additional targets."))
        }
        for (i, meal) in meals.prefix(16).enumerated() {
            nutrition.append(fact("nutrition.meal.\(i)", "Logged meal: \(meal.title); \(meal.calories) kcal, protein \(meal.protein) g. Time: \(ISO8601DateFormatter().string(from: meal.date))."))
        }
        facts["nutrition"] = nutrition
        var seen = Set<String>()
        let workouts = today.coachSnapshots().filter {
            !CoachCanonicalDayState.isNutritionLog($0) && !CoachCanonicalDayState.isHydrationLog($0)
                && seen.insert($0.healthKitWorkoutUUID ?? $0.id).inserted
        }
        facts["activity"] = workouts.prefix(18).enumerated().map { i, a in
            let state = a.isSkipped ? "skipped" : a.isCompleted ? "completed" : "planned, not confirmed completed"
            return fact("activity.item.\(i)", "\(a.title), type \(a.type), status \(state); duration \(a.effectiveDurationMinutes) min. Time: \(ISO8601DateFormatter().string(from: a.date)).")
        }
        if input.isHealthAccessGranted, input.actualLoad.source == .healthKitSamplesWithAppGoalEstimate {
            facts["activity", default: []].append(fact("activity.load", "Today's HealthKit active energy: \(Int(input.actualLoad.activeCalories)) kcal. This is energy expenditure, not food intake."))
        }
        if let dayComparisonFact, !dayComparisonFact.isEmpty {
            facts["activity", default: []].append(fact("activity.dayComparison", dayComparisonFact))
        }
        if let checkIn = CoachFeelingCheckInStore.latest(on: now, calendar: calendar) {
            facts["feeling"] = [fact("feeling.checkin", "User self-report: \(checkIn.feeling.rawValue); clarification: \(checkIn.clarification?.rawValue ?? "none"); at \(ISO8601DateFormatter().string(from: checkIn.createdAt)). This is subjective, not a measured recovery score.")]
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            let planned = CoachCanonicalDayState.selectedDayActivities(from: activities, selectedDate: tomorrow, calendar: calendar)
                .filter { !$0.isCompleted && !$0.isSkipped }
            facts["tomorrow"] = CoachCanonicalDayState.coachRelevantActivities(from: planned).prefix(20).enumerated().map { i, a in
                fact("tomorrow.item.\(i)", "Tomorrow's planned activity: \(a.title), \(a.durationMinutes) min, at \(ISO8601DateFormatter().string(from: a.date)). Planned, not completed; changes require user confirmation.")
            }
        }
        if let presentation {
            facts["coachDecision"] = [fact("coach.priority", "Canonical Coach scenario: \(presentation.scenario.rawValue). Current priority: \(presentation.recommendation). Preserve this priority. Context: \(presentation.assessment)")]
        }
        let factCount = facts.values.reduce(0) { $0 + $1.count }
        CoachEveningSummaryDiagnostics.event(
            "inputBuilt",
            detail: "day=\(CoachEveningSummaryPolicy.dayKey(now, calendar: calendar)) locale=\(locale) factGroups=\(facts.keys.count) facts=\(factCount) hasPresentation=\(presentation != nil)"
        )
        return CoachEveningSummaryInput(schemaVersion: 1,
                                       day: CoachEveningSummaryPolicy.dayKey(now, calendar: calendar),
                                       timezone: calendar.timeZone.identifier, locale: locale,
                                       phase: "evening", facts: facts)
    }
}
