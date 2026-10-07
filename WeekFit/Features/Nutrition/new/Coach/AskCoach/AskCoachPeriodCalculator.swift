import Foundation

enum AskCoachPeriodCalculator {

    /// Builds an inclusive date range ending on `referenceDate`'s calendar day.
    static func range(
        length: AskCoachPeriodLength,
        endingOn referenceDate: Date,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> AskCoachDateRange {
        var calendar = calendar
        calendar.timeZone = timeZone
        let endInclusive = calendar.startOfDay(for: referenceDate)
        let dayCount = length.dayCount
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endInclusive) ?? endInclusive
        return AskCoachDateRange(start: start, endInclusive: endInclusive, dayCount: dayCount)
    }

    /// Immediately preceding equal-length period (no gap, no overlap).
    static func previousRange(
        for current: AskCoachDateRange,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> AskCoachDateRange {
        var calendar = calendar
        calendar.timeZone = timeZone
        let previousEnd = calendar.date(byAdding: .day, value: -1, to: current.start) ?? current.start
        let previousStart = calendar.date(byAdding: .day, value: -(current.dayCount - 1), to: previousEnd)
            ?? previousEnd
        return AskCoachDateRange(
            start: previousStart,
            endInclusive: previousEnd,
            dayCount: current.dayCount
        )
    }

    static func formattedRangeLabel(
        _ range: AskCoachDateRange,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        let start = formatter.string(from: range.start)
        let end = formatter.string(from: range.endInclusive)
        if start == end { return start }
        return "\(start) – \(end)"
    }
}
