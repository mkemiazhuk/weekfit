#if DEBUG
import Foundation
import SwiftData
import WeekFitPlanner

/// Deterministic Today hierarchy fixtures for screenshot / UI harnesses.
enum TodayHierarchyScreenshotFixtures {
    static let liveSessionArgument = "-seed-today-live-session"
    static let upcomingArgument = "-seed-today-upcoming"
    static let completedArgument = "-seed-today-completed-session"

    private static let liveID = "today-hierarchy-live-breath"
    private static let upcomingID = "today-hierarchy-upcoming-run"
    private static let completedID = "today-hierarchy-completed-walk"
    private static let fixtureIDs = [liveID, upcomingID, completedID]

    static var shouldSeedLiveSession: Bool {
        ProcessInfo.processInfo.arguments.contains(liveSessionArgument)
    }

    static var shouldSeedUpcoming: Bool {
        ProcessInfo.processInfo.arguments.contains(upcomingArgument)
    }

    static var shouldSeedCompleted: Bool {
        ProcessInfo.processInfo.arguments.contains(completedArgument)
    }

    static var shouldSeedAny: Bool {
        shouldSeedLiveSession || shouldSeedUpcoming || shouldSeedCompleted
    }

    /// Clear fixture rows whenever UI tests run so prior seeds do not leak across cases.
    @MainActor
    static func prepareIfNeeded(modelContext: ModelContext, now: Date = Date()) {
        guard WeekFitUITestSupport.isActive || shouldSeedAny else { return }
        clearFixtures(modelContext: modelContext)
        guard shouldSeedAny else {
            try? modelContext.save()
            return
        }

        if shouldSeedLiveSession {
            insertLiveBreathWork(modelContext: modelContext, now: now)
            // Next plan under Quick Log while a session is running.
            insertUpcomingRun(modelContext: modelContext, now: now)
        }
        if shouldSeedUpcoming {
            insertUpcomingRun(modelContext: modelContext, now: now)
        }
        if shouldSeedCompleted {
            insertCompletedWalk(modelContext: modelContext, now: now)
        }
        try? modelContext.save()
    }

    @MainActor
    private static func clearFixtures(modelContext: ModelContext) {
        let ids = Set(fixtureIDs)
        let descriptor = FetchDescriptor<PlannedActivity>()
        guard let all = try? modelContext.fetch(descriptor) else { return }
        for activity in all where ids.contains(activity.id) {
            modelContext.delete(activity)
        }
    }

    @MainActor
    private static func insertLiveBreathWork(modelContext: ModelContext, now: Date) {
        let started = now.addingTimeInterval(-7 * 60)
        modelContext.insert(
            PlannedActivity(
                id: liveID,
                date: started,
                type: "recovery",
                title: "Breath Work",
                durationMinutes: 10,
                icon: "wind",
                imageName: "breath",
                colorRed: 0.50,
                colorGreen: 0.62,
                colorBlue: 0.92,
                isCompleted: false,
                isSkipped: false,
                source: "today"
            )
        )
    }

    @MainActor
    private static func insertUpcomingRun(modelContext: ModelContext, now: Date) {
        let calendar = Calendar.current
        // Prefer later today; if that would be in the past, schedule tomorrow morning.
        let todayEvening = calendar.date(
            bySettingHour: 18,
            minute: 30,
            second: 0,
            of: calendar.startOfDay(for: now)
        )
        let date: Date
        if let todayEvening, todayEvening > now.addingTimeInterval(15 * 60) {
            date = todayEvening
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
                  let tomorrowMorning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) {
            date = tomorrowMorning
        } else {
            date = now.addingTimeInterval(2 * 60 * 60)
        }

        modelContext.insert(
            PlannedActivity(
                id: upcomingID,
                date: date,
                type: "workout",
                title: "Easy Run",
                durationMinutes: 40,
                icon: "figure.run",
                imageName: "run",
                colorRed: 0.35,
                colorGreen: 0.78,
                colorBlue: 0.55,
                isCompleted: false,
                isSkipped: false,
                source: "planner"
            )
        )
    }

    @MainActor
    private static func insertCompletedWalk(modelContext: ModelContext, now: Date) {
        let started = now.addingTimeInterval(-35 * 60)
        let activity = PlannedActivity(
            id: completedID,
            date: started,
            type: "workout",
            title: "Recovery Walk",
            durationMinutes: 30,
            icon: "figure.walk",
            imageName: "walk",
            colorRed: 0.35,
            colorGreen: 0.78,
            colorBlue: 0.55,
            isCompleted: true,
            isSkipped: false,
            source: "today"
        )
        activity.actualDurationMinutes = 28
        modelContext.insert(activity)
    }
}
#endif
