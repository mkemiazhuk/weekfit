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
        let timeFormatter = ISO8601DateFormatter()
        func fact(_ id: String, _ text: String) -> Fact {
            Fact(id: id, text: String(text.prefix(500)))
        }

        // MARK: Sleep / recovery (today)
        if input.isHealthAccessGranted {
            var sleep: [Fact] = []
            if input.recoveryContext.sleepHours > 0 {
                sleep.append(fact(
                    "sleep.duration",
                    "Sleep recorded for today: \(formatHours(input.recoveryContext.sleepHours)) hours. Source: HealthKit."
                ))
            } else {
                sleep.append(fact(
                    "sleep.duration.unknown",
                    "No sleep duration recorded for today in HealthKit. Treat sleep as unknown, not zero."
                ))
            }
            if input.recoveryContext.recoveryPercent > 0 {
                sleep.append(fact(
                    "sleep.recovery",
                    "Today's WeekFit recovery score: \(input.recoveryContext.recoveryPercent)%. This is today's score, not a forecast."
                ))
            }
            facts["sleep"] = sleep
        } else {
            facts["sleep"] = [fact(
                "sleep.unavailable",
                "Health access not granted. Sleep and recovery metrics are unavailable."
            )]
        }

        // MARK: Nutrition (today) — meals, drinks, totals, goals
        let today = CoachCanonicalDayState.selectedDayActivities(
            from: activities,
            selectedDate: now,
            calendar: calendar
        )
        let meals = CoachCanonicalDayState.completedMeals(from: today)
        let drinks = today.filter {
            CoachCanonicalDayState.isHydrationLog($0) && $0.isCompleted && !$0.isSkipped
        }
        var nutrition: [Fact] = [
            fact(
                "nutrition.completeness",
                "Food log completeness is unknown. Zero logged intake does not prove no food was eaten. Values are journal entries, potentially estimated."
            )
        ]
        let drinkCalories = drinks.reduce(0) { $0 + $1.calories }
        let mealCalories = meals.reduce(0) { $0 + $1.calories }
        if let n = input.nutritionContext {
            nutrition.append(fact(
                "nutrition.totals",
                "Journal intake totals today (meals + caloric drinks): \(Int(n.caloriesCurrent)) kcal; protein \(Int(n.proteinCurrent)) g; carbs \(Int(n.carbsCurrent)) g; fats \(Int(n.fatsCurrent)) g; water \(formatLiters(n.waterCurrent)) L. Meal-only journal kcal=\(mealCalories); drink journal kcal=\(drinkCalories). Incomplete log ≠ zero intake."
            ))
            nutrition.append(fact(
                "nutrition.goals",
                "Current WeekFit goals: \(Int(n.caloriesGoal)) kcal; protein \(Int(n.proteinGoal)) g; carbs \(Int(n.carbsGoal)) g; fats \(Int(n.fatsGoal)) g; water \(formatLiters(n.waterGoal)) L. Do not invent additional targets. Missing food entries are not evidence of inadequate intake."
            ))
            if let mealsCount = n.mealsCount {
                nutrition.append(fact(
                    "nutrition.mealsCount",
                    "Logged meal entries counted for today: \(mealsCount)."
                ))
            }
            if let lastMeal = n.lastMealTime {
                nutrition.append(fact(
                    "nutrition.lastMeal",
                    "Last logged meal time: \(timeFormatter.string(from: lastMeal))."
                ))
            }
        } else {
            nutrition.append(fact(
                "nutrition.totals.unknown",
                "No aggregated nutrition totals available for today. Meal journal kcal=\(mealCalories); drink journal kcal=\(drinkCalories)."
            ))
        }

        if meals.isEmpty {
            nutrition.append(fact(
                "nutrition.meals.none",
                "No completed meal/food logs for today."
            ))
        } else {
            let mealBudget = 12
            let mealSlice = Array(meals.prefix(mealBudget))
            if meals.count > mealBudget {
                nutrition.append(fact(
                    "nutrition.meals.coverage",
                    "Meal logs truncated: total=\(meals.count); included=\(mealSlice.count); selection=earliest_by_time. Do not infer meal frequency from the truncated list."
                ))
            }
            for (i, meal) in mealSlice.enumerated() {
                nutrition.append(fact(
                    "nutrition.meal.\(i)",
                    "Logged meal: \(meal.title); \(meal.calories) kcal, protein \(meal.protein) g, carbs \(meal.carbs) g, fats \(meal.fats) g, fiber \(meal.fiber) g. Time: \(timeFormatter.string(from: meal.date))."
                ))
            }
        }

        if drinks.isEmpty {
            nutrition.append(fact(
                "nutrition.drinks.none",
                "No completed drink/hydration logs for today beyond any water total above."
            ))
        } else {
            let drinkBudget = 10
            let drinkSlice = Array(drinks.prefix(drinkBudget))
            if drinks.count > drinkBudget {
                nutrition.append(fact(
                    "nutrition.drinks.coverage",
                    "Drink logs truncated: total=\(drinks.count); included=\(drinkSlice.count); selection=earliest_by_time."
                ))
            }
            for (i, drink) in drinkSlice.enumerated() {
                let volumeHint = drink.calories == 0 && drink.protein == 0 && drink.carbs == 0 && drink.fats == 0
                    ? "hydration entry"
                    : "\(drink.calories) kcal, protein \(drink.protein) g, carbs \(drink.carbs) g, fats \(drink.fats) g"
                nutrition.append(fact(
                    "nutrition.drink.\(i)",
                    "Logged drink: \(drink.title); \(volumeHint). Time: \(timeFormatter.string(from: drink.date))."
                ))
            }
        }
        facts["nutrition"] = nutrition

        // MARK: Activity (today)
        var seen = Set<String>()
        let workouts = today.coachSnapshots().filter {
            !CoachCanonicalDayState.isNutritionLog($0) && !CoachCanonicalDayState.isHydrationLog($0)
                && seen.insert($0.healthKitWorkoutUUID ?? $0.id).inserted
        }
        if workouts.isEmpty {
            facts["activity"] = [fact(
                "activity.none",
                "No workout, endurance, recovery, or heat activities logged or planned for today."
            )]
        } else {
            let budget = 16
            let slice = Array(workouts.prefix(budget))
            var activityFacts: [Fact] = []
            if workouts.count > budget {
                activityFacts.append(fact(
                    "activity.coverage",
                    "Today's activity list truncated: total=\(workouts.count); included=\(slice.count); selection=first_by_appearance. Do not infer session frequency from the truncated list."
                ))
            }
            for (i, a) in slice.enumerated() {
                let state = a.isSkipped ? "skipped" : a.isCompleted ? "completed" : "planned, not confirmed completed"
                activityFacts.append(fact(
                    "activity.item.\(i)",
                    "\(a.title), type \(a.type), status \(state); duration \(a.effectiveDurationMinutes) min; subjective intensity unknown. Time: \(timeFormatter.string(from: a.date))."
                ))
            }
            facts["activity"] = activityFacts
        }
        if input.isHealthAccessGranted, input.actualLoad.source == .healthKitSamplesWithAppGoalEstimate {
            facts["activity", default: []].append(fact(
                "activity.load",
                "Today's HealthKit active energy: \(Int(input.actualLoad.activeCalories)) kcal. Expenditure estimate only — not training intensity and not food intake. Day still in progress until local midnight."
            ))
        }
        // Distance vs usual is already shown on the evening card. Do not send it to the model —
        // it reliably causes restated km and "deficit" framing of quieter days.
        _ = dayComparisonFact

        // MARK: Feeling (self-report only — do not promote "okay" to recovered)
        if let checkIn = CoachFeelingCheckInStore.latest(on: now, calendar: calendar) {
            let clarification = checkIn.clarification.map { clarification -> String in
                switch clarification {
                case .lowEnergy: return "low_energy"
                case .soreMuscles: return "sore_muscles"
                case .sleepiness: return "sleepiness"
                }
            } ?? "none"
            facts["feeling"] = [fact(
                "feeling.checkin",
                "User self-report for local day \(CoachEveningSummaryPolicy.dayKey(checkIn.createdAt, calendar: calendar)): feeling=\(checkIn.feeling.rawValue); clarification=\(clarification); timestamp=\(timeFormatter.string(from: checkIn.createdAt)). Subjective only — not a physiological recovery score. Do not rewrite feeling=okay as fully recovered."
            )]
        } else {
            facts["feeling"] = [fact(
                "feeling.none",
                "No evening feeling check-in recorded yet for today."
            )]
        }

        // MARK: Tomorrow plans
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            let planned = CoachCanonicalDayState.selectedDayActivities(
                from: activities,
                selectedDate: tomorrow,
                calendar: calendar
            )
            .filter { !$0.isCompleted && !$0.isSkipped }
            let relevant = CoachCanonicalDayState.coachRelevantActivities(from: planned)
            let mealsTomorrow = planned.filter {
                CoachCanonicalDayState.isNutritionLog($0) && !CoachCanonicalDayState.isHydrationLog($0)
            }
            var tomorrowFacts: [Fact] = []
            if relevant.isEmpty && mealsTomorrow.isEmpty {
                tomorrowFacts.append(fact(
                    "tomorrow.none",
                    "No activities or meals planned for tomorrow yet."
                ))
            } else {
                for (i, a) in relevant.prefix(12).enumerated() {
                    tomorrowFacts.append(fact(
                        "tomorrow.item.\(i)",
                        "Tomorrow's planned activity: \(a.title), type \(a.type), duration \(a.durationMinutes) min, at \(timeFormatter.string(from: a.date)). Subjective intensity unknown (not recorded). Planned, not completed; absence of a plan is unknown, not a rest recommendation."
                    ))
                }
                for (i, meal) in mealsTomorrow.prefix(8).enumerated() {
                    tomorrowFacts.append(fact(
                        "tomorrow.meal.\(i)",
                        "Tomorrow's planned meal: \(meal.title) at \(timeFormatter.string(from: meal.date)). Planned, not logged yet."
                    ))
                }
            }
            facts["tomorrow"] = tomorrowFacts
        }

        var coachDecision: [Fact] = []
        if let presentation {
            coachDecision.append(fact(
                "coach.priority",
                "Canonical Coach scenario: \(presentation.scenario.rawValue). Current priority: \(presentation.recommendation). Preserve this priority. Context: \(presentation.assessment)"
            ))
        }
        // Explicit nutrition goal only — never invent experience, diagnoses, or restrictions.
        if let goal = ProfileService().loadManualNutritionGoal() {
            coachDecision.append(fact(
                "profile.nutritionGoal",
                "User-selected nutrition goal: \(goal.rawValue). Training experience, habitual schedule preferences, and medical restrictions are unknown in-app unless explicitly recorded elsewhere."
            ))
        } else {
            coachDecision.append(fact(
                "profile.nutritionGoal.unknown",
                "No explicit user-selected nutrition goal stored. Do not infer goal, experience level, or restrictions from activity."
            ))
        }
        facts["coachDecision"] = coachDecision

        // Today coverage / freshness for on-device domains (honest unknowns).
        var coverage: [Fact] = []
        coverage.append(fact(
            "coverage.today",
            "Local day \(CoachEveningSummaryPolicy.dayKey(now, calendar: calendar)) still in progress until local midnight. Health access granted=\(input.isHealthAccessGranted). Assembled wall time=\(timeFormatter.string(from: now)). A completed calendar day later does not prove full watch wear."
        ))
        if input.isHealthAccessGranted {
            if input.recoveryContext.sleepHours > 0 {
                coverage.append(fact(
                    "coverage.sleep",
                    "Last-night sleep: samples_present for wake-day. Duration hours=\(formatHours(input.recoveryContext.sleepHours))."
                ))
            } else {
                coverage.append(fact(
                    "coverage.sleep",
                    "Last-night sleep: no_samples_for_wake_day in HealthKit (not asserted as permission denied; query may also be empty before sync)."
                ))
            }
        } else {
            coverage.append(fact(
                "coverage.sleep",
                "Last-night sleep: permission_unavailable_or_health_access_not_granted."
            ))
        }
        // Attach coverage into sleep group to stay within known server groups.
        facts["sleep", default: []].append(contentsOf: coverage)

        let factCount = facts.values.reduce(0) { $0 + $1.count }
        let oversizedGroups = facts.filter { $0.value.count > 40 }.map(\.key).sorted()
        CoachEveningSummaryDiagnostics.event(
            "inputBuilt",
            detail: "day=\(CoachEveningSummaryPolicy.dayKey(now, calendar: calendar)) locale=\(locale) factGroups=\(facts.keys.count) facts=\(factCount) hasPresentation=\(presentation != nil) oversizedGroups=\(oversizedGroups.joined(separator: ","))"
        )
        return CoachEveningSummaryInput(
            schemaVersion: 1,
            day: CoachEveningSummaryPolicy.dayKey(now, calendar: calendar),
            timezone: calendar.timeZone.identifier,
            locale: locale,
            phase: "evening",
            facts: facts
        )
    }

    private static func formatHours(_ value: Double) -> String {
        String(format: value == floor(value) ? "%.0f" : "%.1f", value)
    }

    private static func formatLiters(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
