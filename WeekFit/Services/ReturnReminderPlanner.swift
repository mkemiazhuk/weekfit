import Foundation

enum ReturnReminderHorizon: String, Codable, Equatable, CaseIterable {
    case day7 = "day_7"
    case day14 = "day_14"

    var dayOffset: Int {
        switch self {
        case .day7: return 7
        case .day14: return 14
        }
    }

    var notificationIdentifier: String {
        switch self {
        case .day7: return "weekfit.return-reminder.day-7"
        case .day14: return "weekfit.return-reminder.day-14"
        }
    }
}

/// Reminders fire 7 and 14 days after the last visit.
enum ReturnReminderRegistration {
    /// A return reminder exists for an absence. It is not registered while WeekFit is on screen.
    static func shouldRegister(isForeground: Bool) -> Bool {
        !isForeground
    }
}

enum ReturnReminderTiming {
    /// Tests can compress 7 and 14 days into minutes. The app itself does not.
    static var usesShortIntervals = false

    static func fireDate(
        from anchor: Date,
        horizon: ReturnReminderHorizon,
        calendar: Calendar
    ) -> Date? {
        if usesShortIntervals {
            let minutes = horizon == .day7 ? 1 : 3
            return calendar.date(byAdding: .minute, value: minutes, to: anchor)
        }
        return calendar.date(byAdding: .day, value: horizon.dayOffset, to: anchor)
    }
}

/// Today’s food form is the direct log sheet. A cover above Today makes that presentation unreliable.
enum ReturnReminderFoodLog {
    static var rootCoverVisible = false

    static func canOpenDirectly(onboardingComplete: Bool, blockingCoverVisible: Bool) -> Bool {
        onboardingComplete && !blockingCoverVisible
    }
}

enum ReturnReminderOfferKind: String, Codable, Equatable {
    case repeatAction = "repeat"
    case firstAction = "first_action"
    case newActivityAward = "new_activity_award"
}

enum ReturnReminderGoal: String, Equatable {
    case fatLoss
    case maintenance
    case muscleGain
    case recovery
    case unavailable

    init(nutritionGoal: NutritionGoal?) {
        switch nutritionGoal {
        case .fatLoss: self = .fatLoss
        case .maintenance: self = .maintenance
        case .muscleGain: self = .muscleGain
        case nil: self = .unavailable
        }
    }
}

struct ReturnReminderOffer: Codable, Equatable {
    var horizon: ReturnReminderHorizon
    var kind: ReturnReminderOfferKind
    var actionID: String
}

struct ReturnReminderCompletion: Equatable {
    var actionID: String
    var completedAt: Date
    var opensDirectly: Bool
}

struct ReturnReminderAward: Equatable {
    var actionID: String
    var opensDirectly: Bool
    var hasPrepScreen: Bool
    var unlocked: Bool
}

struct ReturnReminderSeries: Codable, Equatable {
    var anchor: Date
    var day7: ReturnReminderOffer
    var day14: ReturnReminderOffer?
    var frozen: Bool
    var scheduledActionIDs: [String: String]
    var reportedDeliveries: [String]

    var offers: [ReturnReminderOffer] {
        [day7] + (day14.map { [$0] } ?? [])
    }
}

struct ReturnReminderNotificationDraft: Equatable {
    var identifier: String
    var offer: ReturnReminderOffer
    var fireAt: Date
}

struct ReturnReminderPlan: Equatable {
    var series: ReturnReminderSeries
    var cancelIdentifiers: [String]
    var notifications: [ReturnReminderNotificationDraft]
}

enum ReturnReminderNotificationKey {
    static let type = "returnReminder"
    static let horizon = "horizon"
    static let offer = "offer"
    static let actionID = "actionID"
}

struct ReturnReminderWeather: Equatable {
    var isWinter = false
    var isVeryCold = false
    var isRaining = false
    var isStorm = false

    static let unknown = ReturnReminderWeather()

    var isColdSeason = false
    var isChilly = false
    var isEvening = false
    /// Clock hour used for activity invitations. Midday when the caller did not set a time.
    var hour = 12

    /// A bike is a poor invitation in the cold months, at a chilly temperature,
    /// in the evening, in a storm, or in very cold rain.
    var blocksCycling: Bool {
        isWinter || isColdSeason || isChilly || isEvening || isStorm || (isVeryCold && isRaining)
    }

    /// A walk, run, or open-air court is a poor invitation in a storm or freezing rain.
    var blocksExposedOutdoor: Bool {
        isStorm || (isVeryCold && isRaining)
    }

    func allows(_ actionID: String) -> Bool {
        if actionID == ReturnReminderPlanner.cyclingID, blocksCycling { return false }
        if blocksExposedOutdoor, Self.exposedOutdoor.contains(actionID) { return false }
        if blocksExposedOutdoor, Self.snowSports.contains(actionID) { return false }
        return ActivityInviteTime.allows(actionID: actionID, hour: hour)
    }

    private static let exposedOutdoor: Set<String> = [
        "recovery.walk",
        "activity.running",
        "activity.hiking",
        "activity.tennis",
        "activity.padel"
    ]

    private static let snowSports: Set<String> = [
        "activity.snowboarding",
        "activity.alpine-skiing"
    ]
}

enum ReturnReminderPlanner {
    static let walkID = "recovery.walk"
    static let breathingID = "recovery.breathing"
    static let waterID = "habit.drink-water"
    static let mealID = "food.log-meal"
    static let cyclingID = "activity.cycling"
    static let identifiers = ReturnReminderHorizon.allCases.map(\.notificationIdentifier)

    static func day7(
        completions: [ReturnReminderCompletion],
        goal: ReturnReminderGoal,
        foodLogAvailable: Bool = false,
        weather: ReturnReminderWeather = .unknown
    ) -> ReturnReminderOffer {
        let offer: ReturnReminderOffer
        if completions.contains(where: { $0.actionID == walkID }) {
            offer = ReturnReminderOffer(horizon: .day7, kind: .repeatAction, actionID: walkID)
        } else if let repeated = completions
            .filter({ $0.opensDirectly && $0.actionID != walkID })
            .max(by: { $0.completedAt < $1.completedAt }) {
            offer = ReturnReminderOffer(horizon: .day7, kind: .repeatAction, actionID: repeated.actionID)
        } else {
            offer = ReturnReminderOffer(
                horizon: .day7,
                kind: .firstAction,
                actionID: firstActionID(for: goal, foodLogAvailable: foodLogAvailable)
            )
        }
        guard weather.allows(offer.actionID) else {
            let fallback = weather.allows(walkID) ? walkID : breathingID
            let repeated = completions.contains { $0.actionID == fallback }
            return ReturnReminderOffer(
                horizon: .day7,
                kind: repeated ? .repeatAction : .firstAction,
                actionID: fallback
            )
        }
        return offer
    }

    static func day14(
        completions: [ReturnReminderCompletion],
        awards: [ReturnReminderAward],
        excluding actionID: String,
        weather: ReturnReminderWeather = .unknown
    ) -> ReturnReminderOffer? {
        let completed = Set(completions.map(\.actionID))
        let ranked = awards
            .enumerated()
            .filter { _, award in
                award.hasPrepScreen
                    && !award.unlocked
                    && award.actionID != actionID
                    && !completed.contains(award.actionID)
                    && weather.allows(award.actionID)
            }
            .sorted { lhs, rhs in
                if lhs.element.opensDirectly != rhs.element.opensDirectly {
                    return lhs.element.opensDirectly && !rhs.element.opensDirectly
                }
                return lhs.offset < rhs.offset
            }
        guard let choice = ranked.first?.element else { return nil }
        return ReturnReminderOffer(
            horizon: .day14,
            kind: .newActivityAward,
            actionID: choice.actionID
        )
    }

    static func plan(
        now: Date,
        anchor: Date,
        isNewReturn: Bool,
        existing: ReturnReminderSeries?,
        completions: [ReturnReminderCompletion],
        awards: [ReturnReminderAward],
        goal: ReturnReminderGoal,
        foodLogAvailable: Bool = false,
        weather: ReturnReminderWeather = .unknown,
        enabled: Bool,
        notificationsAuthorized: Bool,
        calendar: Calendar = .current
    ) -> ReturnReminderPlan {
        let cancel = identifiers
        guard enabled, notificationsAuthorized else {
            let kept = existing ?? series(
                anchor: anchor,
                completions: completions,
                awards: awards,
                goal: goal,
                foodLogAvailable: foodLogAvailable,
                weather: weather,
                frozen: false
            )
            return ReturnReminderPlan(series: kept, cancelIdentifiers: cancel, notifications: [])
        }

        let series = resolvedSeries(
            anchor: anchor,
            isNewReturn: isNewReturn,
            existing: existing,
            completions: completions,
            awards: awards,
            goal: goal,
            foodLogAvailable: foodLogAvailable,
            weather: weather
        )
        let notifications = series.offers.compactMap { offer -> ReturnReminderNotificationDraft? in
            guard let fireAt = ReturnReminderTiming.fireDate(from: anchor, horizon: offer.horizon, calendar: calendar),
                  fireAt > now else { return nil }
            return ReturnReminderNotificationDraft(
                identifier: offer.horizon.notificationIdentifier,
                offer: offer,
                fireAt: fireAt
            )
        }
        return ReturnReminderPlan(series: series, cancelIdentifiers: cancel, notifications: notifications)
    }

    static func firstActionID(for goal: ReturnReminderGoal, foodLogAvailable: Bool) -> String {
        switch goal {
        case .recovery:
            return breathingID
        case .fatLoss, .maintenance, .muscleGain:
            return foodLogAvailable ? mealID : walkID
        case .unavailable:
            return walkID
        }
    }

    private static func resolvedSeries(
        anchor: Date,
        isNewReturn: Bool,
        existing: ReturnReminderSeries?,
        completions: [ReturnReminderCompletion],
        awards: [ReturnReminderAward],
        goal: ReturnReminderGoal,
        foodLogAvailable: Bool,
        weather: ReturnReminderWeather
    ) -> ReturnReminderSeries {
        if !isNewReturn, let existing, existing.anchor == anchor, existing.frozen {
            let stillSuitable = existing.offers.allSatisfy { weather.allows($0.actionID) }
            if stillSuitable { return existing }
        }
        if !isNewReturn, let existing, existing.anchor == anchor, !existing.frozen {
            var refreshed = series(
                anchor: anchor,
                completions: completions,
                awards: awards,
                goal: goal,
                foodLogAvailable: foodLogAvailable,
                weather: weather,
                frozen: false
            )
            refreshed.reportedDeliveries = existing.reportedDeliveries
            if refreshed.day7.actionID == existing.day7.actionID,
               refreshed.day14?.actionID == existing.day14?.actionID {
                refreshed.scheduledActionIDs = existing.scheduledActionIDs
            }
            return refreshed
        }
        return series(
            anchor: anchor,
            completions: completions,
            awards: awards,
            goal: goal,
            foodLogAvailable: foodLogAvailable,
            weather: weather,
            frozen: false
        )
    }

    private static func series(
        anchor: Date,
        completions: [ReturnReminderCompletion],
        awards: [ReturnReminderAward],
        goal: ReturnReminderGoal,
        foodLogAvailable: Bool,
        weather: ReturnReminderWeather,
        frozen: Bool
    ) -> ReturnReminderSeries {
        let day7 = day7(
            completions: completions,
            goal: goal,
            foodLogAvailable: foodLogAvailable,
            weather: weather
        )
        return ReturnReminderSeries(
            anchor: anchor,
            day7: day7,
            day14: day14(
                completions: completions,
                awards: awards,
                excluding: day7.actionID,
                weather: weather
            ),
            frozen: frozen,
            scheduledActionIDs: [:],
            reportedDeliveries: []
        )
    }
}
