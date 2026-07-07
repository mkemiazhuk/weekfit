import Foundation
import os

#if DEBUG
enum TabSwitchProfiler {
    private static let log = OSSignposter(subsystem: "WeekFit", category: "TabSwitch")

    @discardableResult
    static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let state = log.beginInterval(name)
        defer { log.endInterval(name, state) }
        let start = CFAbsoluteTimeGetCurrent()
        let result = try work()
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        if ms >= 8, CoachDebugSettings.tabSwitchDiagnosticsEnabled {
            print("[TabSwitchProfile] \(name) ms=\(String(format: "%.1f", ms))")
        }
        return result
    }

    static func mark(_ name: StaticString) {
        log.emitEvent("TabSwitch", "\(name)")
    }

    static func markEvent(_ name: String) {
        guard CoachDebugSettings.tabSwitchDiagnosticsEnabled else { return }
        print("[TabSwitchProfile] event=\(name)")
    }
}
#else
enum TabSwitchProfiler {
    @discardableResult
    static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        try work()
    }

    static func mark(_ name: StaticString) {}
    static func markEvent(_ name: String) {}
}
#endif

extension PlanViewModel {

    func dayKind(for date: Date, plannedActivities: [PlannedActivity], revision: String? = nil) -> PlanDayKind {
        let resolvedRevision = revision ?? PlannedActivityRefreshSignature.make(from: plannedActivities)
        refreshDayKindCacheIfNeeded(plannedActivities: plannedActivities, revision: resolvedRevision)
        let dayStart = calendar.startOfDay(for: date).timeIntervalSince1970
        return dayKindByDayStart[dayStart] ?? .open
    }

    func timelineItems(from plannedActivities: [PlannedActivity], revision: String? = nil) -> [PlanTimelineItem] {
        let resolvedRevision = revision ?? PlannedActivityRefreshSignature.make(from: plannedActivities)
        let cacheKey = "\(Int(calendar.startOfDay(for: selectedDate).timeIntervalSince1970))|\(resolvedRevision)"
        guard cacheKey != timelineItemsCacheKey else {
            return cachedTimelineItems
        }

        timelineItemsCacheKey = cacheKey
        cachedTimelineItems = PlanTimelineItemGrouper.makeItems(
            from: selectedDayActivities(from: plannedActivities)
        )
        return cachedTimelineItems
    }

    func warmDayKindCache(from plannedActivities: [PlannedActivity], revision: String) {
        refreshDayKindCacheIfNeeded(plannedActivities: plannedActivities, revision: revision)
    }

    func warmTimelineCache(from plannedActivities: [PlannedActivity], revision: String) {
        #if DEBUG
        TabSwitchProfiler.measure("PlanViewModel.warmTimelineCache") {
            _ = timelineItems(from: plannedActivities, revision: revision)
        }
        #else
        _ = timelineItems(from: plannedActivities, revision: revision)
        #endif
    }

    private func refreshDayKindCacheIfNeeded(plannedActivities: [PlannedActivity], revision: String) {
        guard revision != dayKindCacheRevision else { return }

        #if DEBUG
        TabSwitchProfiler.measure("PlanViewModel.refreshDayKindCache") {
            rebuildDayKindCache(from: plannedActivities, revision: revision)
        }
        #else
        rebuildDayKindCache(from: plannedActivities, revision: revision)
        #endif
    }

    private func rebuildDayKindCache(from plannedActivities: [PlannedActivity], revision: String) {
        dayKindCacheRevision = revision

        var grouped: [TimeInterval: [PlannedActivity]] = [:]
        grouped.reserveCapacity(14)

        for activity in plannedActivities where !activity.isSkipped {
            let dayStart = calendar.startOfDay(for: activity.date).timeIntervalSince1970
            grouped[dayStart, default: []].append(activity)
        }

        var nextCache: [TimeInterval: PlanDayKind] = [:]
        nextCache.reserveCapacity(grouped.count)

        for (dayStart, activities) in grouped {
            let sorted = activities.sorted { $0.date < $1.date }
            nextCache[dayStart] = PlanDayKindResolver.resolve(activities: sorted)
        }

        dayKindByDayStart = nextCache
    }
}
