import WidgetKit
import SwiftUI
import WeekFitWidgetShared

struct WeekFitHomeWidget: Widget {
    let kind = WidgetSnapshotPublisherKind.id

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeekFitWidgetTimelineProvider()) { entry in
            WeekFitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("WeekFit Today")
        .description("See how your day is going and what to do next.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

/// Keeps widget kind in sync with the main-app publisher without importing app code.
enum WidgetSnapshotPublisherKind {
    static let id = "WeekFitHomeWidget"
}

struct WeekFitWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WeekFitWidgetSnapshot

    static func sample(
        mode: WeekFitWidgetSnapshot.DayMode = .goodToGo,
        recovery: Int? = 78,
        now: Date = Date()
    ) -> WeekFitWidgetEntry {
        .smallGoodToGo(recovery: recovery ?? 78, now: now)
    }

    /// A — normal / good readiness
    static func smallGoodToGo(recovery: Int = 82, now: Date = Date()) -> WeekFitWidgetEntry {
        WeekFitWidgetEntry(
            date: now,
            snapshot: baseSnapshot(
                mode: .goodToGo,
                state: "Good to go",
                hero: "You're on track",
                support: "",
                nextTitle: "Strength",
                nextTime: "18:00",
                nextKind: .strength,
                recovery: recovery,
                activity: 0.42,
                fuel: 0.36,
                now: now
            )
        )
    }

    /// B — contextual upcoming event with Coach recommendation
    static func smallBeforeSauna(recovery: Int = 89, now: Date = Date()) -> WeekFitWidgetEntry {
        WeekFitWidgetEntry(
            date: now,
            snapshot: baseSnapshot(
                mode: .goodToGo,
                state: "Before sauna",
                hero: "Hydrate first",
                support: "",
                nextTitle: "Sauna",
                nextTime: "18:00",
                nextKind: .sauna,
                recovery: recovery,
                activity: 0.12,
                fuel: 0.28,
                now: now
            )
        )
    }

    /// C — low recovery
    static func smallTakeItEasy(recovery: Int = 48, now: Date = Date()) -> WeekFitWidgetEntry {
        WeekFitWidgetEntry(
            date: now,
            snapshot: baseSnapshot(
                mode: .takeItEasy,
                state: "Take it easy",
                hero: "Keep today light",
                support: "",
                nextTitle: "Easy walk",
                nextTime: "18:00",
                nextKind: .walk,
                recovery: recovery,
                activity: 0.18,
                fuel: 0.40,
                now: now
            )
        )
    }

    /// D — no next action
    static func smallAllClear(recovery: Int = 76, now: Date = Date()) -> WeekFitWidgetEntry {
        WeekFitWidgetEntry(
            date: now,
            snapshot: baseSnapshot(
                mode: .goodToGo,
                state: "All clear",
                hero: "Nothing urgent now",
                support: "",
                nextTitle: "",
                nextTime: nil,
                nextKind: .none,
                recovery: recovery,
                activity: 0.55,
                fuel: 0.48,
                now: now,
                totalItems: 0,
                completedItems: 0
            )
        )
    }

    private static func baseSnapshot(
        mode: WeekFitWidgetSnapshot.DayMode,
        state: String,
        hero: String,
        support: String,
        nextTitle: String,
        nextTime: String?,
        nextKind: WeekFitWidgetSnapshot.NextActionKind,
        recovery: Int?,
        activity: Double,
        fuel: Double,
        now: Date,
        totalItems: Int = 2,
        completedItems: Int = 0
    ) -> WeekFitWidgetSnapshot {
        WeekFitWidgetSnapshot(
            dateKey: WeekFitWidgetSnapshot.dayKey(for: now),
            activityProgress: activity,
            activityCalories: Int((activity * 500).rounded()),
            activityGoal: 500,
            hasActivitySignal: true,
            nutritionProgress: fuel,
            consumedCalories: Int((fuel * 2000).rounded()),
            remainingCalories: Int(((1 - fuel) * 2000).rounded()),
            hasNutritionSignal: true,
            recoveryScore: recovery,
            sleepHours: 7.2,
            recoveryLabel: recovery.map { $0 >= 70 ? "Ready" : "Protect" },
            hasRecoverySignal: recovery != nil,
            dayMode: mode,
            dayStateLabel: state,
            dayGuidance: hero,
            dayGuidanceDetail: support,
            nextActionTitle: nextTitle,
            nextActionSubtitle: "",
            nextActionTime: nextTime,
            nextActionKind: nextKind,
            nextActionPhase: nextKind == .none ? .none : .upcoming,
            completedItems: completedItems,
            totalItems: totalItems,
            updatedAt: now
        )
    }
}

struct WeekFitWidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekFitWidgetEntry {
        .smallGoodToGo()
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekFitWidgetEntry) -> Void) {
        completion(makeEntry(now: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekFitWidgetEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(now: now)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry(now: Date) -> WeekFitWidgetEntry {
        let snapshot = (try? WidgetSnapshotStore.load()) ?? .placeholderEmpty(now: now)
        return WeekFitWidgetEntry(date: now, snapshot: snapshot)
    }
}
