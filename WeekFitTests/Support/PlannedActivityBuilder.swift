import Foundation
@testable import WeekFit

enum PlannedActivityBuilder {

    private static let defaultColors = (r: 0.2, g: 0.6, b: 0.9)

    static func workout(
        title: String = "Run",
        at date: Date,
        durationMinutes: Int = 45,
        completed: Bool = false,
        skipped: Bool = false
    ) -> PlannedActivity {
        PlannedActivity(
            date: date,
            type: "workout",
            title: title,
            durationMinutes: durationMinutes,
            icon: "figure.run",
            colorRed: defaultColors.r,
            colorGreen: defaultColors.g,
            colorBlue: defaultColors.b,
            isCompleted: completed,
            isSkipped: skipped
        )
    }

    static func meal(
        title: String = "Lunch",
        at date: Date = CoachTestClock.reference,
        calories: Int = 500,
        protein: Int = 35,
        carbs: Int = 50,
        fats: Int = 15,
        completed: Bool = true
    ) -> PlannedActivity {
        PlannedActivity(
            date: date,
            type: "meal",
            title: title,
            durationMinutes: 20,
            icon: "fork.knife",
            imageName: "fork.knife",
            colorRed: 0.16,
            colorGreen: 0.80,
            colorBlue: 0.43,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            isCompleted: completed
        )
    }

    static func hydrationLog(at date: Date = CoachTestClock.reference) -> PlannedActivity {
        PlannedActivity(
            date: date,
            type: "meal",
            title: "Water",
            durationMinutes: 1,
            icon: "drop.fill",
            imageName: "hydration",
            colorRed: 0.2,
            colorGreen: 0.5,
            colorBlue: 0.95,
            isCompleted: true
        )
    }

    /// Workout starting `hoursFromNow` relative to `now` (defaults to real `Date()` for integration tests).
    static func upcomingWorkout(
        title: String = "Evening Run",
        hoursFromNow: Double,
        now: Date = Date()
    ) -> PlannedActivity {
        workout(
            title: title,
            at: now.addingTimeInterval(hoursFromNow * 3600),
            completed: false
        )
    }

    /// Event that already ended but was never marked complete/skipped.
    static func missedEvent(
        title: String = "Strength",
        endedHoursAgo: Double = 2,
        now: Date = Date(),
        durationMinutes: Int = 60
    ) -> PlannedActivity {
        let start = now.addingTimeInterval(-endedHoursAgo * 3600 - TimeInterval(durationMinutes * 60))
        return workout(title: title, at: start, durationMinutes: durationMinutes, completed: false, skipped: false)
    }

    static func completedWorkout(
        title: String = "Morning Ride",
        completedHoursAgo: Double = 3,
        now: Date = Date()
    ) -> PlannedActivity {
        workout(
            title: title,
            at: now.addingTimeInterval(-completedHoursAgo * 3600),
            completed: true
        )
    }
}
