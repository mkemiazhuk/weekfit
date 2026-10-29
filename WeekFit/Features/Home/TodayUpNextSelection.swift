import Foundation

struct TodayUpNextCandidate: Equatable {
    var id: String
    var date: Date
    var isCompleted: Bool
    var isSkipped: Bool
}

enum TodayUpNextSelection {
    /// Nearest still-upcoming event on the same local calendar day as `now`.
    /// Completed, cancelled, and already-started events are excluded.
    /// A later calendar day never qualifies.
    static func nextID(
        among candidates: [TodayUpNextCandidate],
        now: Date,
        calendar: Calendar,
        excludingID: String? = nil
    ) -> String? {
        candidates
            .filter { candidate in
                guard candidate.id != excludingID else { return false }
                guard !candidate.isCompleted, !candidate.isSkipped else { return false }
                guard candidate.date > now else { return false }
                return calendar.isDate(candidate.date, inSameDayAs: now)
            }
            .min { $0.date < $1.date }?
            .id
    }
}
