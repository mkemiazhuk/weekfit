import Foundation

/// Horizon-aware phrasing helpers — presentation only, no scenario routing.
enum CoachPresentationHorizonPhrasing {

    static func avoidBorrowingEveningEffort(input: CoachCopyBuildInput) -> CoachBilingualText {
        switch input.presentationHorizon {
        case .evening, .tomorrow:
            return .en(
                "Don't borrow effort from tonight without a reason.",
                "Не тратьте силы без необходимости."
            )
        case .now, .nextHours, .laterToday:
            return .en(
                "Don't spend spare energy without a reason.",
                "Не тратьте силы без необходимости."
            )
        }
    }

    static func avoidExtraIntenseSession(input: CoachCopyBuildInput) -> CoachBilingualText {
        switch input.presentationHorizon {
        case .evening, .tomorrow:
            return .en(
                "Don't jump into another intense session tonight.",
                "Не прыгайте сегодня в ещё одну интенсивную сессию."
            )
        case .now, .nextHours, .laterToday:
            return .en(
                "Don't jump into another intense session later today.",
                "Не добавляйте ещё одну интенсивную сессию сегодня."
            )
        }
    }

    static func avoidExtraHeavySession(input: CoachCopyBuildInput) -> CoachBilingualText {
        switch input.presentationHorizon {
        case .evening, .tomorrow:
            return .en(
                "Don't pile on another heavy session tonight.",
                "Не накладывайте сегодня ещё одну тяжёлую сессию."
            )
        case .now, .nextHours, .laterToday:
            return .en(
                "Don't pile on another heavy session later today.",
                "Не добавляйте сегодня ещё одну тяжёлую сессию."
            )
        }
    }
}
