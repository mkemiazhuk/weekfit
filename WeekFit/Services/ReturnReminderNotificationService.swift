import Foundation
import UserNotifications
internal import Combine

struct ReturnReminderRoute: Codable, Equatable {
    var actionID: String
    var horizon: ReturnReminderHorizon
    var offerKind: ReturnReminderOfferKind
    var showsAward: Bool
    var openedAt: Date
}

@MainActor
final class PendingReturnReminderOpen: ObservableObject {
    static let shared = PendingReturnReminderOpen()

    @Published private(set) var route: ReturnReminderRoute?

    private init() {}

    func publish(_ route: ReturnReminderRoute) {
        self.route = route
    }

    func clear() {
        route = nil
    }

    func resetForTests() {
        route = nil
    }
}

enum ReturnReminderCopy {
    static func title(for offer: ReturnReminderOffer) -> String {
        switch (offer.horizon, offer.actionID) {
        case (.day7, ReturnReminderPlanner.walkID):
            return WeekFitLocalizedString("returnReminder.day7.walk.title")
        case (.day7, ReturnReminderPlanner.breathingID):
            return WeekFitLocalizedString("returnReminder.day7.breathing.title")
        case (.day7, ReturnReminderPlanner.waterID):
            return WeekFitLocalizedString("returnReminder.day7.water.title")
        case (.day7, ReturnReminderPlanner.mealID):
            return WeekFitLocalizedString("returnReminder.day7.meal.title")
        case (.day7, _):
            return String(
                format: WeekFitLocalizedString("returnReminder.day7.generic.title"),
                activityName(offer.actionID)
            )
        case (.day14, _):
            return String(
                format: WeekFitLocalizedString("returnReminder.day14.title"),
                activityName(offer.actionID)
            )
        }
    }

    static func body(for offer: ReturnReminderOffer) -> String {
        switch (offer.horizon, offer.actionID) {
        case (.day7, ReturnReminderPlanner.walkID):
            return WeekFitLocalizedString("returnReminder.day7.walk.body")
        case (.day7, ReturnReminderPlanner.breathingID):
            return WeekFitLocalizedString("returnReminder.day7.breathing.body")
        case (.day7, ReturnReminderPlanner.waterID):
            return WeekFitLocalizedString("returnReminder.day7.water.body")
        case (.day7, ReturnReminderPlanner.mealID):
            return WeekFitLocalizedString("returnReminder.day7.meal.body")
        case (.day7, _):
            return WeekFitLocalizedString("returnReminder.day7.generic.body")
        case (.day14, _):
            return WeekFitLocalizedString("returnReminder.day14.body")
        }
    }

    static func activityName(_ actionID: String) -> String {
        let title = ActivityBadgeCatalog.definition(id: actionID)?.catalogTitle ?? actionID
        return PlannerOptionLocalization.localizedTitle(for: title)
    }

    static func openCategory(for actionID: String) -> NotificationOpenCategory {
        if actionID == ReturnReminderPlanner.waterID { return .hydration }
        if actionID == ReturnReminderPlanner.mealID { return .meal }
        if ActivityBadgeCatalog.definition(id: actionID)?.category == .recovery { return .recovery }
        return .activity
    }
}

enum ReturnReminderWeatherResolver {
    static func current(now: Date = Date(), calendar: Calendar = .current) async -> ReturnReminderWeather {
        let (summary, _) = await WeekFitWeatherProvider.shared.cachedSummaryAndFreshness()
        return make(summary: summary, now: now, calendar: calendar)
    }

    static func make(
        summary: WeekFitWeatherSummary?,
        now: Date,
        calendar: Calendar = .current
    ) -> ReturnReminderWeather {
        let month = calendar.component(.month, from: now)
        let hour = calendar.component(.hour, from: now)
        let isWinter = month == 12 || month == 1 || month == 2
        let isColdSeason = [11, 12, 1, 2, 3].contains(month)
        let isEvening = hour >= 18 || hour < 6
        guard let summary else {
            return ReturnReminderWeather(
                isWinter: isWinter,
                isColdSeason: isColdSeason,
                isEvening: isEvening,
                hour: hour
            )
        }
        let temp = summary.temperature.value
        let feels = summary.feelsLike.value
        let precip = summary.precipitationChance ?? 0
        return ReturnReminderWeather(
            isWinter: isWinter,
            isVeryCold: temp <= 0 || feels <= 2,
            isRaining: summary.condition == .rain || precip >= 55,
            isStorm: summary.condition == .storm || precip >= 70,
            isColdSeason: isColdSeason,
            isChilly: temp <= CyclingInvitePolicy.chillyCelsius || feels <= CyclingInvitePolicy.chillyFeelsLikeCelsius,
            isEvening: isEvening,
            hour: hour
        )
    }
}

enum ReturnReminderHistory {
    static func completions(
        activities: [(title: String, isCompleted: Bool, isSkipped: Bool, at: Date)],
        unlocks: [String: Date]
    ) -> [ReturnReminderCompletion] {
        var byID: [String: ReturnReminderCompletion] = [:]
        for activity in activities where activity.isCompleted && !activity.isSkipped {
            guard let definition = definition(forTitle: activity.title) else { continue }
            insert(
                ReturnReminderCompletion(
                    actionID: definition.id,
                    completedAt: activity.at,
                    opensDirectly: definition.startsImmediately
                ),
                into: &byID
            )
        }
        for (id, date) in unlocks {
            guard let definition = ActivityBadgeCatalog.definition(id: id) else { continue }
            insert(
                ReturnReminderCompletion(
                    actionID: definition.id,
                    completedAt: date,
                    opensDirectly: definition.startsImmediately
                ),
                into: &byID
            )
        }
        return Array(byID.values)
    }

    static func awards(unlocks: [String: Date]) -> [ReturnReminderAward] {
        let prepTitles = Set(
            (PlannerType.workout.options + PlannerType.recovery.options).map(\.title)
        )
        return ActivityBadgeCatalog.definitions
            .filter { $0.category == .activity || $0.category == .recovery }
            .map { definition in
                ReturnReminderAward(
                    actionID: definition.id,
                    opensDirectly: definition.startsImmediately,
                    hasPrepScreen: prepTitles.contains(definition.catalogTitle),
                    unlocked: unlocks[definition.id] != nil
                )
            }
    }

    private static func definition(forTitle title: String) -> ActivityBadgeDefinition? {
        if let canonical = ActivityBadgeCatalog.canonicalCatalogTitle(title) {
            return ActivityBadgeCatalog.definition(catalogTitle: canonical)
        }
        return ActivityBadgeCatalog.definition(catalogTitle: title)
    }

    private static func insert(
        _ completion: ReturnReminderCompletion,
        into byID: inout [String: ReturnReminderCompletion]
    ) {
        if let existing = byID[completion.actionID], existing.completedAt >= completion.completedAt {
            return
        }
        byID[completion.actionID] = completion
    }
}

@MainActor
final class ReturnReminderNotificationService {
    static let shared = ReturnReminderNotificationService()

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let seriesKey = "weekfit.returnReminder.series"
    private let anchorKey = "weekfit.returnReminder.anchor"
    private let routeKey = "weekfit.returnReminder.route"
    private var isForeground = false
    private var returnTask: Task<Void, Never>?
    private var scheduleTask: Task<Void, Never>?

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    func noteReturned(now: Date = Date()) {
        guard !isForeground else { return }
        isForeground = true
        defaults.set(now.timeIntervalSince1970, forKey: anchorKey)
        defaults.removeObject(forKey: seriesKey)
        returnTask = Task { await acknowledgeDeliveriesAndCancel() }
    }

    func noteBackgrounded() {
        isForeground = false
        guard var series = storedSeries() else { return }
        series.frozen = true
        store(series)
        let frozen = series
        Task { await register(frozen) }
    }

    /// The app is on screen, so a return reminder must not appear.
    func holdWhileForeground() {
        center.removePendingNotificationRequests(withIdentifiers: ReturnReminderPlanner.identifiers)
        center.removeDeliveredNotifications(withIdentifiers: ReturnReminderPlanner.identifiers)
    }

    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: ReturnReminderPlanner.identifiers)
        center.removeDeliveredNotifications(withIdentifiers: ReturnReminderPlanner.identifiers)
    }

    func refreshLocalizedContent(now: Date = Date()) {
        Task {
            guard let series = storedSeries() else { return }
            let drafts = series.offers.compactMap { offer -> ReturnReminderNotificationDraft? in
                guard let fireAt = ReturnReminderTiming.fireDate(
                    from: series.anchor,
                    horizon: offer.horizon,
                    calendar: .current
                ),
                      fireAt > now else { return nil }
                return ReturnReminderNotificationDraft(
                    identifier: offer.horizon.notificationIdentifier,
                    offer: offer,
                    fireAt: fireAt
                )
            }
            center.removePendingNotificationRequests(withIdentifiers: ReturnReminderPlanner.identifiers)
            guard ReturnReminderRegistration.shouldRegister(isForeground: isForeground) else { return }
            for draft in drafts {
                await add(draft)
            }
        }
    }

    func schedule(
        activities: [(title: String, isCompleted: Bool, isSkipped: Bool, at: Date)],
        unlocks: [String: Date],
        goal: ReturnReminderGoal,
        foodLogAvailable: Bool,
        enabled: Bool,
        now: Date = Date()
    ) {
        let previous = scheduleTask
        let task = Task {
            await previous?.value
            await scheduleNow(
                activities: activities,
                unlocks: unlocks,
                goal: goal,
                foodLogAvailable: foodLogAvailable,
                enabled: enabled,
                now: now
            )
        }
        scheduleTask = task
    }

    func storeRoute(_ route: ReturnReminderRoute) {
        if let data = try? JSONEncoder().encode(route) {
            defaults.set(data, forKey: routeKey)
        }
        PendingReturnReminderOpen.shared.publish(route)
    }

    func restoreRouteIfNeeded() {
        guard PendingReturnReminderOpen.shared.route == nil,
              let data = defaults.data(forKey: routeKey),
              let route = try? JSONDecoder().decode(ReturnReminderRoute.self, from: data) else { return }
        PendingReturnReminderOpen.shared.publish(route)
    }

    func consumeRoute() -> ReturnReminderRoute? {
        let route = PendingReturnReminderOpen.shared.route
        PendingReturnReminderOpen.shared.clear()
        defaults.removeObject(forKey: routeKey)
        return route
    }

    private func scheduleNow(
        activities: [(title: String, isCompleted: Bool, isSkipped: Bool, at: Date)],
        unlocks: [String: Date],
        goal: ReturnReminderGoal,
        foodLogAvailable: Bool,
        enabled: Bool,
        now: Date
    ) async {
        await returnTask?.value
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        let anchor = Date(timeIntervalSince1970: defaults.double(forKey: anchorKey))
        let resolvedAnchor = defaults.object(forKey: anchorKey) == nil ? now : anchor
        let existing = storedSeries()
        let weather = await ReturnReminderWeatherResolver.current(now: now)
        let plan = ReturnReminderPlanner.plan(
            now: now,
            anchor: resolvedAnchor,
            isNewReturn: existing == nil || existing?.anchor != resolvedAnchor,
            existing: existing,
            completions: ReturnReminderHistory.completions(activities: activities, unlocks: unlocks),
            awards: ReturnReminderHistory.awards(unlocks: unlocks),
            goal: goal,
            foodLogAvailable: foodLogAvailable,
            weather: weather,
            enabled: enabled,
            notificationsAuthorized: authorized
        )
        var series = plan.series
        center.removePendingNotificationRequests(withIdentifiers: plan.cancelIdentifiers)
        guard ReturnReminderRegistration.shouldRegister(isForeground: isForeground) else {
            store(series)
            return
        }
        await register(series, drafts: plan.notifications)
    }

    private func register(_ series: ReturnReminderSeries, drafts: [ReturnReminderNotificationDraft]? = nil) async {
        guard NotificationPreferencesReader.activitySuggestionsEnabled else {
            cancelPending()
            return
        }
        let now = Date()
        let resolved = drafts ?? series.offers.compactMap { offer -> ReturnReminderNotificationDraft? in
            guard let fireAt = ReturnReminderTiming.fireDate(
                from: series.anchor,
                horizon: offer.horizon,
                calendar: .current
            ),
                  fireAt > now else { return nil }
            return ReturnReminderNotificationDraft(
                identifier: offer.horizon.notificationIdentifier,
                offer: offer,
                fireAt: fireAt
            )
        }
        var updated = series
        for draft in resolved {
            await add(draft)
            let previous = updated.scheduledActionIDs[draft.identifier]
            if previous != draft.offer.actionID {
                updated.scheduledActionIDs[draft.identifier] = draft.offer.actionID
                ProductAnalytics.notificationScheduled(
                    category: ReturnReminderCopy.openCategory(for: draft.offer.actionID),
                    horizon: draft.offer.horizon.rawValue,
                    offer: draft.offer.kind.rawValue,
                    actionID: draft.offer.actionID
                )
            }
        }
        store(updated)
    }

    private func add(_ draft: ReturnReminderNotificationDraft) async {
        let content = UNMutableNotificationContent()
        content.title = ReturnReminderCopy.title(for: draft.offer)
        content.body = ReturnReminderCopy.body(for: draft.offer)
        content.sound = .default
        content.userInfo = [
            "notificationType": ReturnReminderNotificationKey.type,
            ReturnReminderNotificationKey.horizon: draft.offer.horizon.rawValue,
            ReturnReminderNotificationKey.offer: draft.offer.kind.rawValue,
            ReturnReminderNotificationKey.actionID: draft.offer.actionID
        ]
        let trigger: UNNotificationTrigger
        if ReturnReminderTiming.usesShortIntervals {
            let interval = max(draft.fireAt.timeIntervalSinceNow, 1)
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        } else {
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: draft.fireAt
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }
        let request = UNNotificationRequest(identifier: draft.identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func acknowledgeDeliveriesAndCancel() async {
        let delivered = await center.deliveredNotifications()
        var series = storedSeries() ?? ReturnReminderSeries(
            anchor: Date(),
            day7: ReturnReminderOffer(horizon: .day7, kind: .firstAction, actionID: ReturnReminderPlanner.walkID),
            day14: nil,
            frozen: false,
            scheduledActionIDs: [:],
            reportedDeliveries: []
        )
        for notification in delivered {
            let info = notification.request.content.userInfo
            guard (info["notificationType"] as? String) == ReturnReminderNotificationKey.type,
                  let horizon = info[ReturnReminderNotificationKey.horizon] as? String,
                  let offer = info[ReturnReminderNotificationKey.offer] as? String,
                  let actionID = info[ReturnReminderNotificationKey.actionID] as? String,
                  !series.reportedDeliveries.contains(horizon) else { continue }
            series.reportedDeliveries.append(horizon)
            ProductAnalytics.notificationDelivered(
                category: ReturnReminderCopy.openCategory(for: actionID),
                horizon: horizon,
                offer: offer,
                actionID: actionID
            )
        }
        if storedSeries() != nil {
            store(series)
        }
        center.removePendingNotificationRequests(withIdentifiers: ReturnReminderPlanner.identifiers)
        center.removeDeliveredNotifications(withIdentifiers: ReturnReminderPlanner.identifiers)
    }

    private func storedSeries() -> ReturnReminderSeries? {
        guard let data = defaults.data(forKey: seriesKey) else { return nil }
        return try? JSONDecoder().decode(ReturnReminderSeries.self, from: data)
    }

    private func store(_ series: ReturnReminderSeries) {
        guard let data = try? JSONEncoder().encode(series) else { return }
        defaults.set(data, forKey: seriesKey)
    }
}
