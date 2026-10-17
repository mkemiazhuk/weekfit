import XCTest
import HealthKit
import SwiftUI
@testable import WeekFit

final class CoachEveningRecapPlanRecoverySessionsTests: XCTestCase {

    func testSessionsForEveningRecapIncludesCompletedPlanSaunaAndBreathing() {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let saunaDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day)!
        let breathDate = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: day)!
        let now = calendar.date(bySettingHour: 20, minute: 40, second: 0, of: day)!

        let sauna = PlannedActivity(
            date: saunaDate,
            type: "recovery",
            title: "Сауна",
            durationMinutes: 60,
            icon: "flame.fill",
            imageName: "recovery-sauna",
            colorRed: 0.6,
            colorGreen: 0.5,
            colorBlue: 0.9,
            isCompleted: true,
            source: "planner"
        )
        let breathing = PlannedActivity(
            date: breathDate,
            type: "recovery",
            title: "Дыхание",
            durationMinutes: 15,
            icon: "wind",
            imageName: "recovery-breathing",
            colorRed: 0.6,
            colorGreen: 0.5,
            colorBlue: 0.9,
            isCompleted: true,
            source: "planner"
        )
        let coffee = PlannedActivity(
            date: calendar.date(bySettingHour: 10, minute: 59, second: 0, of: day)!,
            type: "drink",
            title: "Кофе",
            durationMinutes: 5,
            icon: "cup.and.saucer.fill",
            colorRed: 0.2,
            colorGreen: 0.5,
            colorBlue: 0.9,
            isCompleted: true,
            source: "today"
        )

        let provider = ActivityIntelligenceSnapshotProvider()
        let merged = provider.sessionsForEveningRecap(
            snapshotSessions: [],
            plannedActivities: [sauna, breathing, coffee],
            day: day,
            now: now
        )

        XCTAssertEqual(Set(merged.map(\.title)), ["Сауна", "Дыхание"])
        XCTAssertFalse(merged.contains { $0.title == "Кофе" })

        let summary = CoachEveningRecapActivityAggregator.build(
            steps: 9_798,
            dayWalkingRunningDistanceKm: 7.8,
            sessions: merged,
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertEqual(summary.hero?.kind, .walking)
        XCTAssertTrue(summary.rows.contains { $0.kind == .recovery && $0.title == "Сауна" })
        XCTAssertTrue(summary.rows.contains { $0.kind == .recovery && $0.title == "Дыхание" })

        let signals = CoachEveningRecapSignalBuilder.build(
            activity: summary,
            sleepHours: 7.4,
            recoveryPercent: 70,
            nutrition: nil,
            unitSystem: .metric
        )
        let recoveryTitles = signals.filter { $0.kind == .recovery }.map(\.title)
        XCTAssertTrue(recoveryTitles.contains("Сауна"))
        XCTAssertTrue(recoveryTitles.contains("Дыхание"))
        XCTAssertTrue(recoveryTitles.contains(WeekFitLocalizedString("coach.eveningRecap.signal.sleep.title")))
    }

    func testDoesNotDuplicateWhenHealthKitSessionAlreadyPresent() {
        let day = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: day)!
        let workoutID = UUID()
        let planned = PlannedActivity(
            healthKitWorkoutUUID: workoutID.uuidString,
            date: start,
            type: "recovery",
            title: "Дыхание",
            durationMinutes: 15,
            icon: "wind",
            imageName: "recovery-breathing",
            colorRed: 0.6,
            colorGreen: 0.5,
            colorBlue: 0.9,
            isCompleted: true,
            source: "planner"
        )
        let existing = ActivitySessionSnapshot(
            workoutID: workoutID,
            title: "Дыхание",
            startDate: start,
            durationMinutes: 15,
            icon: "wind",
            color: .purple,
            detail: ActivitySessionDetailSnapshot(
                title: "Дыхание",
                activityType: .mindAndBody,
                startDate: start,
                endDate: start.addingTimeInterval(15 * 60),
                durationMinutes: 15,
                workoutDurationSeconds: 15 * 60,
                elapsedDurationSeconds: 15 * 60,
                source: "Apple Watch",
                icon: "wind",
                color: .purple,
                activeCalories: nil,
                distanceKm: nil,
                averageHeartRate: nil,
                maxHeartRate: nil,
                heartRateSamples: [],
                routePoints: [],
                elevationGain: nil,
                steps: nil,
                cadence: nil
            ),
            plannedActivityId: planned.id
        )

        let provider = ActivityIntelligenceSnapshotProvider()
        let merged = provider.sessionsForEveningRecap(
            snapshotSessions: [existing],
            plannedActivities: [planned],
            day: day,
            now: start.addingTimeInterval(6 * 3600)
        )
        XCTAssertEqual(merged.count, 1)
    }
}
