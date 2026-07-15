import Foundation
import SwiftData

enum AppReviewDemoPlannedActivitySeeder {

    static func seed(
        scenario: AppReviewDemoScenario,
        modelContext: ModelContext,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        let today = calendar.startOfDay(for: referenceDate)
        var activities: [PlannedActivity] = []

        activities.append(contentsOf: historicalWorkouts(today: today, calendar: calendar))
        activities.append(contentsOf: todayCompletedWorkout(today: today, calendar: calendar))
        activities.append(contentsOf: todayNutrition(today: today, calendar: calendar))
        activities.append(contentsOf: recentNutrition(today: today, calendar: calendar))
        activities.append(contentsOf: upcomingPlan(today: today, scenario: scenario, calendar: calendar))

        for activity in activities {
            AppReviewDemoPlannedActivityTagger.tagIfNeeded(activity)
            modelContext.insert(activity)
        }

        try modelContext.save()
    }

    static func deleteDemoActivities(modelContext: ModelContext) throws {
        let source = AppReviewDemoStore.sourceIdentifier
        let descriptor = FetchDescriptor<PlannedActivity>(
            predicate: #Predicate { activity in
                activity.source == source
            }
        )
        let activities = try modelContext.fetch(descriptor)
        guard !activities.isEmpty else { return }

        for activity in activities {
            modelContext.delete(activity)
        }
        try modelContext.save()
    }

    // MARK: - Historical workouts

    private static func historicalWorkouts(
        today: Date,
        calendar: Calendar
    ) -> [PlannedActivity] {
        let specs: [(offset: Int, title: String, type: String, icon: String, minutes: Int, calories: Int, hour: Int)] = [
            (1, "Upper Body Strength", "workout", "figure.strengthtraining.traditional", 52, 420, 18),
            (2, "Recovery Walk", "workout", "figure.walk", 32, 180, 8),
            (3, "Easy Run", "workout", "figure.run", 38, 360, 7),
            (4, "Outdoor Cycle", "workout", "figure.outdoor.cycle", 55, 520, 17),
            (5, "Core Training", "workout", "figure.strengthtraining.functional", 28, 210, 19),
            (6, "Long Run", "workout", "figure.run", 74, 680, 8),
            (7, "Morning Walk", "workout", "figure.walk", 45, 240, 8),
            (8, "Tennis", "workout", "figure.tennis", 68, 540, 16),
            (9, "Tempo Run", "workout", "figure.run", 46, 470, 7),
            (10, "Strength Session", "workout", "figure.strengthtraining.traditional", 48, 390, 18),
            (12, "Intervals", "workout", "figure.run", 42, 430, 7),
            (14, "Hike", "workout", "figure.walk", 80, 560, 10)
        ]

        return specs.compactMap { spec in
            guard let day = calendar.date(byAdding: .day, value: -spec.offset, to: today) else { return nil }
            let date = dayAt(hour: spec.hour, on: day, calendar: calendar)
            return makeActivity(
                title: spec.title,
                type: spec.type,
                icon: spec.icon,
                date: date,
                durationMinutes: spec.minutes,
                calories: spec.calories,
                completed: true,
                workoutUUID: AppReviewDemoWorkoutDetailFactory.stableWorkoutID(
                    title: spec.title,
                    date: date
                )
            )
        }
    }

    // MARK: - Today completed showcase workout

    private static func todayCompletedWorkout(
        today: Date,
        calendar: Calendar
    ) -> [PlannedActivity] {
        let date = dayAt(hour: 9, minute: 55, on: today, calendar: calendar)
        return [
            makeActivity(
                title: "Morning Walk",
                type: "workout",
                icon: "figure.walk",
                date: date,
                durationMinutes: 24,
                calories: 128,
                completed: true,
                workoutUUID: AppReviewDemoWorkoutDetailFactory.stableWorkoutID(
                    title: "Morning Walk",
                    date: date
                )
            )
        ]
    }

    // MARK: - Today nutrition

    private static func todayNutrition(
        today: Date,
        calendar: Calendar
    ) -> [PlannedActivity] {
        AppReviewDemoPredefinedMeals.todaySchedule().map { scheduled in
            makeMealActivity(
                scheduled: scheduled,
                date: dayAt(
                    hour: scheduled.hour,
                    minute: scheduled.minute,
                    on: today,
                    calendar: calendar
                )
            )
        } + [
            makeActivity(
                title: "Coffee",
                type: "drink",
                icon: "cup.and.saucer.fill",
                date: dayAt(hour: 8, minute: 35, on: today, calendar: calendar),
                durationMinutes: 1,
                calories: 8,
                completed: true
            ),
            makeActivity(
                title: "Water",
                type: "drink",
                icon: "drop.fill",
                date: dayAt(hour: 10, on: today, calendar: calendar),
                durationMinutes: 1,
                calories: 0,
                completed: true
            ),
            makeActivity(
                title: "Water",
                type: "drink",
                icon: "drop.fill",
                date: dayAt(hour: 15, on: today, calendar: calendar),
                durationMinutes: 1,
                calories: 0,
                completed: true
            )
        ]
    }

    private static func recentNutrition(
        today: Date,
        calendar: Calendar
    ) -> [PlannedActivity] {
        var activities: [PlannedActivity] = []
        for offset in 1...5 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            for scheduled in AppReviewDemoPredefinedMeals.schedule(forDayOffset: offset) {
                activities.append(
                    makeMealActivity(
                        scheduled: scheduled,
                        date: dayAt(
                            hour: scheduled.hour,
                            minute: scheduled.minute,
                            on: day,
                            calendar: calendar
                        )
                    )
                )
            }
        }
        return activities
    }

    // MARK: - Upcoming plan

    private static func upcomingPlan(
        today: Date,
        scenario: AppReviewDemoScenario,
        calendar: Calendar
    ) -> [PlannedActivity] {
        let todayWorkout: (title: String, icon: String, minutes: Int)
        switch scenario {
        case .readyToTrain:
            todayWorkout = ("Strength Session", "figure.strengthtraining.traditional", 50)
        case .keepItModerate:
            todayWorkout = ("Moderate Run", "figure.run", 42)
        case .recoveryFirst:
            todayWorkout = ("Recovery Walk", "figure.walk", 30)
        }

        var activities: [PlannedActivity] = [
            makeActivity(
                title: todayWorkout.title,
                type: "workout",
                icon: todayWorkout.icon,
                date: dayAt(hour: 18, on: today, calendar: calendar),
                durationMinutes: todayWorkout.minutes,
                calories: todayWorkout.minutes * 8,
                completed: false
            )
        ]

        let upcoming: [(offset: Int, title: String, type: String, icon: String, minutes: Int, hour: Int)] = [
            (1, "Recovery Walk", "recovery", "figure.walk", 35, 8),
            (2, "Intervals", "workout", "figure.run", 40, 7),
            (2, "Tennis", "workout", "figure.tennis", 75, 17),
            (3, "Strength Session", "workout", "figure.strengthtraining.traditional", 48, 18),
            (4, "Easy Run", "workout", "figure.run", 36, 7),
            (5, "Long Endurance Ride", "workout", "figure.outdoor.cycle", 95, 9),
            (6, "Mobility Flow", "recovery", "figure.cooldown", 30, 19)
        ]

        for item in upcoming {
            guard let day = calendar.date(byAdding: .day, value: item.offset, to: today) else { continue }
            activities.append(
                makeActivity(
                    title: item.title,
                    type: item.type,
                    icon: item.icon,
                    date: dayAt(hour: item.hour, on: day, calendar: calendar),
                    durationMinutes: item.minutes,
                    calories: item.minutes * 8,
                    completed: false
                )
            )
        }

        return activities
    }

    // MARK: - Helpers

    private static func makeMealActivity(
        scheduled: AppReviewDemoPredefinedMeals.ScheduledMeal,
        date: Date
    ) -> PlannedActivity {
        let meal = scheduled.meal
        return makeActivity(
            title: meal.title,
            type: "meal",
            icon: "fork.knife",
            imageName: meal.imageName,
            date: date,
            durationMinutes: scheduled.durationMinutes,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fats: meal.fats,
            fiber: meal.fiber,
            completed: true
        )
    }

    private static func makeActivity(
        title: String,
        type: String,
        icon: String,
        imageName: String = "",
        date: Date,
        durationMinutes: Int,
        calories: Int = 0,
        protein: Int = 0,
        carbs: Int = 0,
        fats: Int = 0,
        fiber: Int = 0,
        completed: Bool,
        workoutUUID: UUID? = nil
    ) -> PlannedActivity {
        let colors = color(for: type)
        return PlannedActivity(
            id: workoutUUID?.uuidString ?? UUID().uuidString,
            healthKitWorkoutUUID: workoutUUID?.uuidString,
            date: date,
            type: type,
            title: title,
            durationMinutes: durationMinutes,
            icon: icon,
            imageName: imageName,
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            isCompleted: completed,
            source: AppReviewDemoStore.sourceIdentifier
        )
    }

    private static func color(for type: String) -> (r: Double, g: Double, b: Double) {
        switch type {
        case "meal":
            return (0.16, 0.80, 0.43)
        case "drink":
            return (0.20, 0.50, 0.95)
        case "recovery":
            return (0.45, 0.72, 0.58)
        default:
            return (0.20, 0.60, 0.90)
        }
    }

    private static func dayAt(
        hour: Int,
        minute: Int = 0,
        on day: Date,
        calendar: Calendar
    ) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? day
    }
}
