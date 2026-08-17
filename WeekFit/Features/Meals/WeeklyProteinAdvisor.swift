import Foundation

/// Protein guidance for the next meal: remaining today, week-to-date gap,
/// and upcoming / completed training — without changing calorie `activityCredit`.
struct WeeklyProteinAdvice: Equatable {
    enum Urgency: String, Equatable {
        case none
        case catchUp
        case postSession
        case preSessionSoft
        case protectTomorrow
    }

    let proteinRemainingToday: Int
    let targetProteinGrams: Int
    let bandLow: Int
    let bandHigh: Int
    let urgency: Urgency
    let prefersProteinCatchUp: Bool
    /// Scales `proteinFitBonus` in meal scoring.
    let proteinFitWeight: Double
    let weekToDateProteinGrams: Int
    let weekElapsedDays: Int
    let weekDeficitGrams: Int
    let upcomingSeriousSessionCount: Int
}

enum WeeklyProteinAdvisor {

    static func advise(from input: CoachInputSnapshot) -> WeeklyProteinAdvice {
        advise(
            nutrition: input.nutritionContext,
            plannedActivities: input.plannedActivities,
            selectedDate: input.selectedDate,
            now: input.now,
            tomorrowDemand: input.dayPriorityModel.tomorrowDemand,
            focus: CoachFocusResolver.resolve(input: input)
        )
    }

    static func advise(
        nutrition: CoachNutritionContext?,
        plannedActivities: [CoachPlannedActivitySnapshot],
        selectedDate: Date,
        now: Date,
        tomorrowDemand: CoachTomorrowDemand,
        focus: CoachFocusSelection
    ) -> WeeklyProteinAdvice {
        let calendar = Calendar.current
        let proteinGoal = nutrition?.proteinGoal ?? 0
        let proteinCurrent = nutrition?.proteinCurrent ?? 0
        let remaining = max(0, Int((proteinGoal - proteinCurrent).rounded()))

        let hour = calendar.component(.hour, from: now)
        let expectedProgress = CoachNutritionPace.expectedProteinProgress(hour: hour)
        let expectedEaten = proteinGoal * expectedProgress
        let behindPace = proteinCurrent + 15 < expectedEaten

        let week = weekToDateProtein(
            plannedActivities: plannedActivities,
            selectedDate: selectedDate,
            todayProtein: proteinCurrent,
            calendar: calendar
        )
        let weekGoalSoFar = proteinGoal * Double(week.elapsedDays)
        let weekDeficit = max(0, Int((weekGoalSoFar - Double(week.grams)).rounded()))

        let upcomingSerious = plannedActivities.filter { activity in
            calendar.isDate(activity.date, inSameDayAs: selectedDate)
                && !activity.isCompleted
                && !activity.isSkipped
                && activity.date >= now
                && CoachActivityClassifier.isElevatedTrainingLoad(activity)
        }.count

        let completedSeriousToday = plannedActivities.contains { activity in
            calendar.isDate(activity.date, inSameDayAs: selectedDate)
                && activity.isCompleted
                && !activity.isSkipped
                && CoachActivityClassifier.isElevatedTrainingLoad(activity)
        }

        let urgency = resolveUrgency(
            remaining: remaining,
            behindPace: behindPace,
            weekDeficit: weekDeficit,
            hour: hour,
            tomorrowDemand: tomorrowDemand,
            focus: focus,
            completedSeriousToday: completedSeriousToday,
            upcomingSeriousCount: upcomingSerious
        )

        let band = targetBand(remaining: remaining, urgency: urgency)
        let prefersCatchUp =
            remaining >= 25
            && (urgency == .catchUp || urgency == .postSession || urgency == .protectTomorrow)

        let weight: Double
        switch urgency {
        case .catchUp, .protectTomorrow:
            weight = remaining >= 25 ? 2.2 : 0.6
        case .postSession:
            weight = remaining >= 20 ? 1.8 : 0.8
        case .preSessionSoft:
            weight = 0.35
        case .none:
            weight = remaining >= 25 ? 0.85 : 0
        }

        return WeeklyProteinAdvice(
            proteinRemainingToday: remaining,
            targetProteinGrams: band.target,
            bandLow: band.low,
            bandHigh: band.high,
            urgency: urgency,
            prefersProteinCatchUp: prefersCatchUp,
            proteinFitWeight: weight,
            weekToDateProteinGrams: week.grams,
            weekElapsedDays: week.elapsedDays,
            weekDeficitGrams: weekDeficit,
            upcomingSeriousSessionCount: upcomingSerious
        )
    }

    /// Score delta that pulls meal library picks toward the protein band.
    static func proteinFitBonus(mealProtein: Int, advice: WeeklyProteinAdvice) -> Double {
        guard advice.proteinFitWeight > 0 else { return 0 }

        let distance = abs(mealProtein - advice.targetProteinGrams)
        var bonus = advice.proteinFitWeight * (36 - Double(distance))

        if mealProtein >= advice.bandLow && mealProtein <= advice.bandHigh {
            bonus += advice.proteinFitWeight * 14
        }

        if mealProtein < advice.bandLow {
            bonus -= advice.proteinFitWeight * Double(advice.bandLow - mealProtein) * 1.25
        }

        if advice.prefersProteinCatchUp && mealProtein >= advice.targetProteinGrams {
            bonus += advice.proteinFitWeight * 8
        }

        if advice.urgency == .preSessionSoft && mealProtein > 40 {
            bonus -= advice.proteinFitWeight * Double(mealProtein - 40) * 0.8
        }

        return bonus
    }

    // MARK: - Internals

    private static func resolveUrgency(
        remaining: Int,
        behindPace: Bool,
        weekDeficit: Int,
        hour: Int,
        tomorrowDemand: CoachTomorrowDemand,
        focus: CoachFocusSelection,
        completedSeriousToday: Bool,
        upcomingSeriousCount: Int
    ) -> WeeklyProteinAdvice.Urgency {
        if case .upcoming = focus.source,
           let minutes = focus.minutesUntilStart,
           minutes <= 150,
           focus.family != .heat {
            return .preSessionSoft
        }

        if focus.source == .active || focus.source == .recentCompleted {
            if focus.family != .heat {
                return .postSession
            }
        }

        if completedSeriousToday && remaining >= 25 {
            return .postSession
        }

        if hour >= 17 && tomorrowDemand == .hard && remaining >= 25 {
            return .protectTomorrow
        }

        if remaining >= 35 && (behindPace || weekDeficit >= 40 || upcomingSeriousCount > 0) {
            return .catchUp
        }

        if remaining >= 50 {
            return .catchUp
        }

        if hour >= 14 && weekDeficit >= 50 && remaining >= 25 {
            return .catchUp
        }

        return .none
    }

    private static func targetBand(
        remaining: Int,
        urgency: WeeklyProteinAdvice.Urgency
    ) -> (low: Int, high: Int, target: Int) {
        var target: Int
        switch remaining {
        case 60...:
            target = 45
        case 40..<60:
            target = 38
        case 25..<40:
            target = 30
        case 15..<25:
            target = 22
        default:
            target = min(18, max(remaining, 12))
        }

        switch urgency {
        case .preSessionSoft:
            target = min(target, 28)
        case .postSession:
            target = min(max(remaining, 0), target + 8)
        case .catchUp, .protectTomorrow:
            target = min(max(remaining, 0), max(target, min(40, remaining)))
        case .none:
            break
        }

        if remaining > 0 {
            target = min(target, remaining)
        }

        let low = max(12, target - 8)
        let high = target + 12
        return (low, high, max(target, low))
    }

    private static func weekToDateProtein(
        plannedActivities: [CoachPlannedActivitySnapshot],
        selectedDate: Date,
        todayProtein: Double,
        calendar: Calendar
    ) -> (grams: Int, elapsedDays: Int) {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return (Int(todayProtein.rounded()), 1)
        }

        let todayStart = calendar.startOfDay(for: selectedDate)
        var day = calendar.startOfDay(for: weekInterval.start)
        var total = 0.0
        var elapsed = 0

        while day <= todayStart {
            elapsed += 1
            if calendar.isDate(day, inSameDayAs: selectedDate) {
                total += todayProtein
            } else {
                let dayProtein = plannedActivities
                    .filter { activity in
                        calendar.isDate(activity.date, inSameDayAs: day)
                            && activity.timelineEventKind == .food
                            && activity.isCompleted
                            && !activity.isSkipped
                    }
                    .reduce(0) { $0 + $1.protein }
                total += Double(dayProtein)
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return (Int(total.rounded()), max(elapsed, 1))
    }
}
