import Foundation
import WeekFitPlanner

/// Events the tomorrow sentence was written from, captured at request time.
/// Display compares this with the live plan. It never asks the model again.
struct CoachEveningTomorrowBasis: Codable, Equatable, Sendable {
    static let version = 1

    struct Event: Codable, Equatable, Sendable {
        /// `activity` or `meal` — the two fact groups sent for tomorrow.
        var kind: String
        var id: String
        var type: String
        /// Local `yyyy-MM-dd'T'HH:mm` in the calendar used at capture.
        var localStart: String
        var durationMinutes: Int
        var cancelled: Bool
    }

    var version: Int
    /// Next local calendar day the facts described (`YYYY-MM-DD`).
    var day: String
    var timeZoneIdentifier: String
    /// The model was told there is no tomorrow plan.
    var assertedEmpty: Bool
    var events: [Event]

    struct Selection {
        var basis: CoachEveningTomorrowBasis
        var activities: [PlannedActivity]
        var meals: [PlannedActivity]
    }

    /// Same selection the evening-summary input uses for `tomorrow` facts.
    static func select(
        activities: [PlannedActivity],
        now: Date,
        calendar: Calendar
    ) -> Selection {
        let start = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return select(activities: activities, on: tomorrow, calendar: calendar)
    }

    static func capture(
        activities: [PlannedActivity],
        now: Date,
        calendar: Calendar
    ) -> CoachEveningTomorrowBasis {
        select(activities: activities, now: now, calendar: calendar).basis
    }

    static func capture(
        activities: [PlannedActivity],
        on day: Date,
        calendar: Calendar
    ) -> CoachEveningTomorrowBasis {
        select(activities: activities, on: day, calendar: calendar).basis
    }

    static func select(
        activities: [PlannedActivity],
        on day: Date,
        calendar: Calendar
    ) -> Selection {
        let planned = CoachCanonicalDayState.selectedDayActivities(
            from: activities,
            selectedDate: day,
            calendar: calendar
        )
        .filter { !$0.isCompleted && !$0.isSkipped }
        let relevant = Array(CoachCanonicalDayState.coachRelevantActivities(from: planned).prefix(12))
        let meals = Array(planned.filter {
            CoachCanonicalDayState.isNutritionLog($0) && !CoachCanonicalDayState.isHydrationLog($0)
        }.prefix(8))
        let events = relevant.map { event($0, kind: "activity", calendar: calendar) }
            + meals.map { event($0, kind: "meal", calendar: calendar) }
        let basis = CoachEveningTomorrowBasis(
            version: version,
            day: CoachEveningSummaryPolicy.dayKey(day, calendar: calendar),
            timeZoneIdentifier: calendar.timeZone.identifier,
            assertedEmpty: events.isEmpty,
            events: events
        )
        return Selection(basis: basis, activities: relevant, meals: meals)
    }

    /// True when every event the recommendation depended on is still the same.
    /// Events that were not in the original input do not invalidate it.
    /// An empty input becomes stale as soon as tomorrow gains a plan.
    func stillMatches(activities: [PlannedActivity], calendar: Calendar) -> Bool {
        guard version == Self.version else { return false }
        guard let dayDate = CoachEveningSummaryPolicy.date(fromDayKey: day, calendar: calendar) else {
            return false
        }
        let live = Self.capture(activities: activities, on: dayDate, calendar: calendar)
        if assertedEmpty { return live.events.isEmpty }
        let liveByID = Dictionary(live.events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for stored in events {
            guard let current = liveByID[stored.id] else { return false }
            if current.kind != stored.kind
                || current.type != stored.type
                || current.localStart != stored.localStart
                || current.durationMinutes != stored.durationMinutes
                || current.cancelled != stored.cancelled {
                return false
            }
        }
        return true
    }

    private static func event(_ activity: PlannedActivity, kind: String, calendar: Calendar) -> Event {
        Event(
            kind: kind,
            id: activity.id,
            type: activity.type,
            localStart: localStamp(activity.date, calendar: calendar),
            durationMinutes: activity.durationMinutes,
            cancelled: activity.isSkipped
        )
    }

    private static func localStamp(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.string(from: date)
    }
}

struct CoachEveningResolvedNote: Equatable, Sendable {
    var today: String
    /// Tomorrow recommendation that still matches the plan it was written from.
    var tomorrow: String?
    /// The tomorrow sentence cannot be shown as current.
    var planChanged: Bool
}
