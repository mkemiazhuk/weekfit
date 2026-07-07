import Foundation

enum TodayDayBoundaryPolicy {

    struct Input: Equatable {
        var now: Date
        var selectedDate: Date
        var trackedDayStart: Date?
        var calendar: Calendar
    }

    struct Output: Equatable {
        var trackedDayStart: Date
        var selectedDate: Date
        var didCrossBoundary: Bool
        var shouldRefreshHealth: Bool
    }

    static func reconcile(_ input: Input) -> Output {
        let calendar = input.calendar
        let todayStart = calendar.startOfDay(for: input.now)

        guard input.trackedDayStart != todayStart else {
            return Output(
                trackedDayStart: todayStart,
                selectedDate: input.selectedDate,
                didCrossBoundary: false,
                shouldRefreshHealth: false
            )
        }

        let previousTrackedDay = input.trackedDayStart
        var selectedDate = input.selectedDate

        if let previousTrackedDay,
           calendar.isDate(selectedDate, inSameDayAs: previousTrackedDay) {
            selectedDate = input.now
        }

        let didCrossBoundary = previousTrackedDay != nil

        return Output(
            trackedDayStart: todayStart,
            selectedDate: selectedDate,
            didCrossBoundary: didCrossBoundary,
            shouldRefreshHealth: didCrossBoundary
        )
    }

    static func nextBoundary(after now: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: startOfDay)
            ?? now.addingTimeInterval(86_400)
    }
}
