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
        if let n = input.nutritionContext {
            nutrition.append(fact(
                "nutrition.totals",
                "Recorded intake today: \(Int(n.caloriesCurrent)) kcal; protein \(Int(n.proteinCurrent)) g; carbs \(Int(n.carbsCurrent)) g; fats \(Int(n.fatsCurrent)) g; water \(formatLiters(n.waterCurrent)) L."
            ))
            nutrition.append(fact(
                "nutrition.goals",
                "Current WeekFit goals: \(Int(n.caloriesGoal)) kcal; protein \(Int(n.proteinGoal)) g; carbs \(Int(n.carbsGoal)) g; fats \(Int(n.fatsGoal)) g; water \(formatLiters(n.waterGoal)) L. Do not invent additional targets."
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
                "No aggregated nutrition totals available for today."
            ))
        }

        if meals.isEmpty {
            nutrition.append(fact(
                "nutrition.meals.none",
                "No completed meal/food logs for today."
            ))
        } else {
            for (i, meal) in meals.prefix(20).enumerated() {
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
            for (i, drink) in drinks.prefix(12).enumerated() {
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
            facts["activity"] = workouts.prefix(20).enumerated().map { i, a in
                let state = a.isSkipped ? "skipped" : a.isCompleted ? "completed" : "planned, not confirmed completed"
                return fact(
                    "activity.item.\(i)",
                    "\(a.title), type \(a.type), status \(state); duration \(a.effectiveDurationMinutes) min. Time: \(timeFormatter.string(from: a.date))."
                )
            }
        }
        if input.isHealthAccessGranted, input.actualLoad.source == .healthKitSamplesWithAppGoalEstimate {
            facts["activity", default: []].append(fact(
                "activity.load",
                "Today's HealthKit active energy: \(Int(input.actualLoad.activeCalories)) kcal. This is energy expenditure, not food intake."
            ))
        }
        if let dayComparisonFact, !dayComparisonFact.isEmpty {
            facts["activity", default: []].append(fact("activity.dayComparison", dayComparisonFact))
        }

        // MARK: Feeling
        if let checkIn = CoachFeelingCheckInStore.latest(on: now, calendar: calendar) {
            facts["feeling"] = [fact(
                "feeling.checkin",
                "User self-report: \(checkIn.feeling.rawValue); clarification: \(checkIn.clarification?.rawValue ?? "none"); at \(timeFormatter.string(from: checkIn.createdAt)). This is subjective, not a measured recovery score."
            )]
        } else {
            facts["feeling"] = [fact(
                "feeling.none",
                "No evening feeling check-in recorded yet."
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
                for (i, a) in relevant.prefix(20).enumerated() {
                    tomorrowFacts.append(fact(
                        "tomorrow.item.\(i)",
                        "Tomorrow's planned activity: \(a.title), type \(a.type), \(a.durationMinutes) min, at \(timeFormatter.string(from: a.date)). Planned, not completed; changes require user confirmation."
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

        if let presentation {
            facts["coachDecision"] = [fact(
                "coach.priority",
                "Canonical Coach scenario: \(presentation.scenario.rawValue). Current priority: \(presentation.recommendation). Preserve this priority. Context: \(presentation.assessment)"
            )]
        }

        let factCount = facts.values.reduce(0) { $0 + $1.count }
        CoachEveningSummaryDiagnostics.event(
            "inputBuilt",
            detail: "day=\(CoachEveningSummaryPolicy.dayKey(now, calendar: calendar)) locale=\(locale) factGroups=\(facts.keys.count) facts=\(factCount) hasPresentation=\(presentation != nil)"
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
