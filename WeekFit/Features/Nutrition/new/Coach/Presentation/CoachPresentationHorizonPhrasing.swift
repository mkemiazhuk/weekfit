import Foundation

/// Horizon-aware phrasing helpers — presentation only, no scenario routing.
enum CoachPresentationHorizonPhrasing {

    static func avoidBorrowingEveningEffort(input: CoachCopyBuildInput) -> CoachBilingualText {
        switch input.presentationHorizon {
        case .evening, .tomorrow:
            return .en(
                "Keep spare energy for when it matters tonight.",
                "Сохраните силы на то, что действительно важно вечером."
            )
        case .now, .nextHours, .laterToday:
            return .en(
                "Keep spare energy for when it matters.",
                "Сохраните силы на то, что действительно важно."
            )
        }
    }

    static func avoidExtraIntenseSession(input: CoachCopyBuildInput) -> CoachBilingualText {
        switch input.presentationHorizon {
        case .evening, .tomorrow:
            return .en(
                "Don't jump into another intense session tonight.",
                "Не добавляйте сегодня ещё одну интенсивную тренировку."
            )
        case .now, .nextHours, .laterToday:
            return .en(
                "Don't jump into another intense session later today.",
                "Не добавляйте сегодня ещё одну интенсивную тренировку."
            )
        }
    }

    static func avoidExtraHeavySession(input: CoachCopyBuildInput) -> CoachBilingualText {
        switch input.presentationHorizon {
        case .evening, .tomorrow:
            return .en(
                "Don't pile on another heavy session tonight.",
                "Не добавляйте сегодня ещё одну тяжёлую тренировку."
            )
        case .now, .nextHours, .laterToday:
            return .en(
                "Don't pile on another heavy session later today.",
                "Не добавляйте сегодня ещё одну тяжёлую тренировку."
            )
        }
    }
}
