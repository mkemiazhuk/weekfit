import SwiftUI
internal import Combine

@MainActor
final class ActivityIntelligenceViewModel: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    @Published private(set) var selectedDate: Date = Date()
    @Published private(set) var selectedSnapshot: ActivityDaySnapshot = .empty
    @Published private(set) var weekSnapshots: [ActivityDaySnapshot] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshingSelectedDay = false

    private let provider = ActivityIntelligenceSnapshotProvider()
    private var selectionToken = UUID()
    private var loadToken = UUID()

    func load(
        selectedDate: Date,
        healthManager: HealthManager,
        plannedActivities: [PlannedActivity]
    ) async {
        let token = UUID()
        loadToken = token

        let calendar = Self.mondayFirstCalendar

        self.selectedDate = selectedDate
        isLoading = true

        let placeholderWeek = makePlaceholderWeekSnapshots(containing: selectedDate)

        weekSnapshots = placeholderWeek
        selectedSnapshot = placeholderWeek.first {
            calendar.isDate($0.date, inSameDayAs: selectedDate)
        } ?? placeholderWeek.first ?? .empty

        let selected = await provider.buildSnapshot(
            for: selectedDate,
            healthManager: healthManager,
            plannedActivities: plannedActivities
        )

        guard loadToken == token else {
            isLoading = false
            return
        }

        selectedSnapshot = selected

        if let index = weekSnapshots.firstIndex(where: {
            calendar.isDate($0.date, inSameDayAs: selectedDate)
        }) {
            weekSnapshots[index] = selected
        }

        let snapshots = await provider.buildWeekSnapshots(
            endingAt: selectedDate,
            healthManager: healthManager,
            plannedActivities: plannedActivities
        )

        guard loadToken == token else {
            isLoading = false
            return
        }

        weekSnapshots = snapshots.sorted { $0.date < $1.date }

        selectedSnapshot = weekSnapshots.first {
            calendar.isDate($0.date, inSameDayAs: selectedDate)
        } ?? selected

        isLoading = false
    }

    func select(
        _ snapshot: ActivityDaySnapshot,
        healthManager: HealthManager,
        plannedActivities: [PlannedActivity]
    ) async {
        let calendar = Self.mondayFirstCalendar
        let token = UUID()
        selectionToken = token

        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            selectedDate = snapshot.date
            selectedSnapshot = snapshot
        }

        isRefreshingSelectedDay = true

        let refreshed = await provider.buildSnapshot(
            for: snapshot.date,
            healthManager: healthManager,
            plannedActivities: plannedActivities
        )

        guard selectionToken == token else {
            isRefreshingSelectedDay = false
            return
        }

        guard calendar.isDate(refreshed.date, inSameDayAs: selectedDate) else {
            isRefreshingSelectedDay = false
            return
        }

        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            selectedSnapshot = refreshed
        }

        if let index = weekSnapshots.firstIndex(where: {
            calendar.isDate($0.date, inSameDayAs: refreshed.date)
        }) {
            weekSnapshots[index] = refreshed
        }

        isRefreshingSelectedDay = false
    }

    private func makePlaceholderWeekSnapshots(containing date: Date) -> [ActivityDaySnapshot] {
        let calendar = Self.mondayFirstCalendar
        let startOfDay = calendar.startOfDay(for: date)

        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: startOfDay) else {
            return []
        }

        let weekStart = calendar.startOfDay(for: weekInterval.start)

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }

            return ActivityDaySnapshot.empty.withDate(day)
        }
    }

    private static var mondayFirstCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_PL")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}

extension ActivityDaySnapshot {
    func withDate(_ date: Date) -> ActivityDaySnapshot {
        ActivityDaySnapshot(
            date: date,
            activeCalories: activeCalories,
            activityGoal: activityGoal,
            activityPercent: activityPercent,
            exerciseMinutes: exerciseMinutes,
            standHours: standHours,
            steps: steps,
            distanceKm: distanceKm,
            vo2Max: vo2Max,
            recoveryPercent: recoveryPercent,
            sessions: sessions,
            hourlyActivityPoints: hourlyActivityPoints,
            historicalSameWeekdayPoints: historicalSameWeekdayPoints,
            sleepInterval: sleepInterval
        )
    }
}
