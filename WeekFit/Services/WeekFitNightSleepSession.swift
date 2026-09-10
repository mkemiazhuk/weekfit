import Foundation

/// Canonical night sleep window and primary-session assembly for Today + Recovery.
///
/// Night for calendar wake-day `D` is local **21:00 on D−1 → 09:00 on D**.
/// Daytime sleep outside that window is ignored. Within the window, all overlapping
/// in-bed (preferred) or asleep spans form **one** night — long awakenings do not
/// drop the morning bout.
enum WeekFitNightSleepSession {
    /// Hours before local midnight → 21:00 previous evening.
    static let nightStartHoursBeforeMidnight = 3
    /// Hours after local midnight → 09:00 wake morning.
    static let nightEndHoursAfterMidnight = 9

    static func nightWindow(
        for date: Date,
        calendar: Calendar = .current
    ) -> DateInterval {
        let dayStart = calendar.startOfDay(for: date)
        let start = calendar.date(
            byAdding: .hour,
            value: -nightStartHoursBeforeMidnight,
            to: dayStart
        ) ?? dayStart
        let end = calendar.date(
            byAdding: .hour,
            value: nightEndHoursAfterMidnight,
            to: dayStart
        ) ?? dayStart
        return DateInterval(start: start, end: end)
    }

    /// Union of spans that overlap `night`, clipped to `night`.
    /// Prefers `inBedSpans` when non-empty after filtering; otherwise `asleepSpans`.
    static func primarySession(
        inBedSpans: [(start: Date, end: Date)],
        asleepSpans: [(start: Date, end: Date)],
        night: DateInterval
    ) -> DateInterval? {
        let inBed = clippedOverlappingSpans(inBedSpans, night: night)
        let source = inBed.isEmpty
            ? clippedOverlappingSpans(asleepSpans, night: night)
            : inBed
        guard !source.isEmpty else { return nil }

        let start = source.map(\.start).min()!
        let end = source.map(\.end).max()!
        guard end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    private static func clippedOverlappingSpans(
        _ spans: [(start: Date, end: Date)],
        night: DateInterval
    ) -> [(start: Date, end: Date)] {
        spans.compactMap { span in
            let start = max(span.start, night.start)
            let end = min(span.end, night.end)
            guard end > start else { return nil }
            return (start, end)
        }
    }
}
