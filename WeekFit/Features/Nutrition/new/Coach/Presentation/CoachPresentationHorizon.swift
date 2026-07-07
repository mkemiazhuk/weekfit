import Foundation

/// Presentation-only time horizon — how far ahead Coach copy should speak.
enum CoachPresentationHorizon: String, Equatable, Sendable, CaseIterable {
    case now
    case nextHours
    case laterToday
    case evening
    case tomorrow
}

/// Derives conversational horizon from clock and context — no scenario routing.
enum CoachPresentationHorizonPolicy {

    struct Input: Equatable, Sendable {
        let timeOfDay: CoachTimeOfDay
        let conversationPhase: CoachConversationPhase
        let activityState: CoachActivityState
        let sessionPhase: CoachSessionPhase
        let minutesUntilStart: Int?
        let tomorrowDemand: CoachTomorrowDemand
        let hasTomorrowWorkout: Bool
        let isLowRecovery: Bool

        static func from(context: CoachContext) -> Input {
            Input(
                timeOfDay: context.timeOfDay,
                conversationPhase: context.conversationPhase,
                activityState: context.activityState,
                sessionPhase: context.sessionPhase,
                minutesUntilStart: context.minutesUntilStart,
                tomorrowDemand: context.tomorrowDemand,
                hasTomorrowWorkout: context.tomorrowWorkout != nil,
                isLowRecovery: context.dayReadiness.isLowRecovery || context.dayReadiness.sleepIsLow
            )
        }

        static func from(_ input: CoachCopyBuildInput) -> Input {
            Input(
                timeOfDay: input.timeOfDay,
                conversationPhase: input.conversationPhase,
                activityState: input.activityState,
                sessionPhase: input.sessionPhase,
                minutesUntilStart: input.minutesUntilStart,
                tomorrowDemand: input.modifiers.tomorrowDemand,
                hasTomorrowWorkout: input.tomorrowWorkout != nil,
                isLowRecovery: input.dayReadiness.isLowRecovery || input.dayReadiness.sleepIsLow
            )
        }
    }

    static func resolve(_ input: Input) -> CoachPresentationHorizon {
        if input.activityState == .active || input.sessionPhase == .during {
            return .now
        }
        if let minutes = input.minutesUntilStart, minutes >= 0, minutes <= 90 {
            return .now
        }

        if input.conversationPhase == .dayClosing {
            return input.tomorrowDemand != .none || input.hasTomorrowWorkout ? .tomorrow : .evening
        }

        switch input.timeOfDay {
        case .morning, .midday:
            return .nextHours
        case .afternoon:
            return .laterToday
        case .evening:
            return .evening
        case .lateEvening, .night:
            return .tomorrow
        }
    }

    static func resolve(context: CoachContext) -> CoachPresentationHorizon {
        resolve(Input.from(context: context))
    }

    static func resolve(input: CoachCopyBuildInput) -> CoachPresentationHorizon {
        resolve(Input.from(input))
    }
}
