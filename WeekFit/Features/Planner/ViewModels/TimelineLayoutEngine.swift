import SwiftUI

struct TimelineLayoutEngine {
    static let timelineStartHour = 5
    static let timelineHourHeight: CGFloat = 64
    static let timelineThirtyMinuteHeight: CGFloat = 32
    
    static func yPosition(for date: Date, calendar: Calendar) -> CGFloat {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let totalMinutes = ((hour - timelineStartHour) * 60) + minute
        let clampedMinutes = max(0, min(totalMinutes, (24 - timelineStartHour) * 60))
        return CGFloat(clampedMinutes) / 30 * timelineThirtyMinuteHeight
    }
    
    static func dateForTimelinePosition(_ y: CGFloat, selectedDate: Date, calendar: Calendar) -> Date {
        let rawMinutes = y / timelineThirtyMinuteHeight * 30
        let snappedMinutes = Int((rawMinutes / 15.0).rounded()) * 15
        let clampedMinutes = max(0, min(snappedMinutes, (24 - timelineStartHour) * 60))
        
        let timelineStart = calendar.date(bySettingHour: timelineStartHour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        return calendar.date(byAdding: .minute, value: clampedMinutes, to: timelineStart) ?? timelineStart
    }
    
    static func hasTimeConflict(
        newStart: Date,
        durationMinutes: Int,
        activities: [PlannedActivity],
        excluding: PlannedActivity?,
        calendar: Calendar,
        newEventBlocksPlannerTime: Bool = true
    ) -> Bool {
        guard newEventBlocksPlannerTime else { return false }

        return activities.contains { existing in
            if let excluding, existing === excluding { return false }
            guard calendar.isDate(existing.date, inSameDayAs: newStart),
                  !existing.isSkipped,
                  existing.blocksPlannerTime else {
                return false
            }
            
            let aEnd = calendar.date(byAdding: .minute, value: max(durationMinutes, 15), to: newStart) ?? newStart
            let bEnd = calendar.date(byAdding: .minute, value: max(existing.durationMinutes, 15), to: existing.date) ?? existing.date
            
            return newStart < bEnd && aEnd > existing.date
        }
    }
}
