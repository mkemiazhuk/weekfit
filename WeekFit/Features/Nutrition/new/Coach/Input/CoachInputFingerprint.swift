import Foundation

struct CoachInputFingerprint: Hashable, CustomStringConvertible {
    let rawValue: String

    var description: String {
        rawValue
    }

    var compactLogValue: String {
        rawValue
            .split(separator: "#")
            .filter { !$0.hasPrefix("activities=") }
            .joined(separator: "#")
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(snapshot: CoachInputSnapshot) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: snapshot.selectedDate).timeIntervalSince1970
        let timePhase = Self.timePhase(for: snapshot.now, calendar: calendar)
        let brain = snapshot.brain
        let metrics = brain.metrics
        let goals = brain.fullDayGoals
        let nutrition = snapshot.nutritionContext
        let recovery = snapshot.recoveryContext
        let actualLoad = snapshot.actualLoad

        let activities = snapshot.plannedActivities
            .sorted { $0.id < $1.id }
            .map { activity in
                [
                    activity.id,
                    "\(Int(activity.date.timeIntervalSince1970 / 60))",
                    activity.type,
                    activity.title,
                    activity.imageName,
                    "\(activity.durationMinutes)",
                    "\(activity.actualDurationMinutes ?? -1)",
                    "\(activity.calories)",
                    "\(activity.protein)",
                    "\(activity.carbs)",
                    "\(activity.fats)",
                    "\(activity.fiber)",
                    "\(activity.isCompleted)",
                    "\(activity.isSkipped)",
                    "\(activity.isPartialCompletion)",
                    "\(activity.timelineEventKind)",
                    "\(activity.terminalState(now: snapshot.now))",
                    activity.source
                ].joined(separator: ":")
            }
            .joined(separator: "|")

        rawValue = [
            "v=1",
            "snapshot=\(snapshot.metricsSnapshotID?.uuidString ?? "nil")",
            "day=\(Int(day / 86_400))",
            "lang=\(WeekFitCurrentLanguageCode())",
            "phase=\(timePhase)",
            "sleepHours=\(Self.rounded(metrics.sleepHours))",
            "sleep=\(brain.sleep)",
            "recovery=\(brain.recovery)",
            "readiness=\(brain.readiness)",
            "strain=\(brain.strain)",
            "fuel=\(brain.fuel)",
            "hydration=\(brain.hydration)",
            "activeCalories=\(Self.rounded(metrics.activeCalories))",
            "actualLoadSource=\(actualLoad.source.rawValue)",
            "healthKitSampleActiveCalories=\(Self.rounded(actualLoad.activeCalories))",
            "healthKitSampleExerciseMinutes=\(actualLoad.exerciseMinutes ?? -1)",
            "estimatedActivityProgress=\(Self.rounded(actualLoad.activityProgress ?? -1))",
            "calories=\(Self.rounded(metrics.calories))",
            "protein=\(Self.rounded(metrics.protein))",
            "carbs=\(Self.rounded(metrics.carbs))",
            "fats=\(Self.rounded(metrics.fats))",
            "fiber=\(Self.rounded(metrics.fiber))",
            "water=\(Self.rounded(metrics.waterLiters))",
            "goalCalories=\(Self.rounded(goals.calories))",
            "goalProtein=\(Self.rounded(goals.protein))",
            "goalCarbs=\(Self.rounded(goals.carbs))",
            "goalFats=\(Self.rounded(goals.fats))",
            "goalFiber=\(Self.rounded(goals.fiber))",
            "goalWater=\(Self.rounded(goals.waterLiters))",
            "rawRecovery=\(recovery.recoveryPercent)",
            "recoverySleep=\(Self.rounded(recovery.sleepHours))",
            "nutritionWater=\(Self.rounded(nutrition?.waterCurrent ?? -1))",
            "nutritionWaterGoal=\(Self.rounded(nutrition?.waterGoal ?? -1))",
            "nutritionMeals=\(nutrition?.mealsCount ?? -1)",
            "nutritionLastMeal=\(nutrition?.lastMealTime.map { Int($0.timeIntervalSince1970 / 60) } ?? -1)",
            "activities=\(activities)"
        ].joined(separator: "#")
    }

    private static func rounded(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func timePhase(for date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 6..<11:
            return "morning"
        case 11..<16:
            return "midday"
        default:
            return "evening"
        }
    }
}
