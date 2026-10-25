import Foundation

/// Short neutral answer when sleep and recovery were not recorded.
enum CoachLimitedRecoveryCopyPolicy {

    static func apply(to pack: CoachCopyPack, context: CoachContext) -> CoachCopyPack {
        CoachCopyPack(
            scenario: pack.scenario,
            assessment: CoachCopySection(lines: []),
            recommendation: .single(recommendation(for: context)),
            avoid: CoachCopySection(lines: []),
            nextAction: CoachCopySection(lines: []),
            supportingSignals: CoachCopySection(lines: []),
            warningLayer: pack.warningLayer
        )
    }

    static func teaser(for context: CoachContext) -> CoachTeaserCopy.Content {
        let line = recommendation(for: context)
        let headline = headline(for: context)
        return CoachTeaserCopy.Content(
            todayTitle: watchTitle,
            todayMessage: watchCheck,
            coachHeadline: headline
        )
    }

    private static let watchTitle = CoachBilingualText.en(
        "Check your watch",
        "Проверьте часы",
        chinese: "检查手表"
    )

    private static let watchCheck = CoachBilingualText.en(
        "Either it died, or you didn't have it on.",
        "Либо они разрядились, либо их у вас не было.",
        chinese: "要么没电了，要么你没戴。"
    )

    /// Short headline. The "No sleep data" label stays on the status badge only.
    private static func headline(for context: CoachContext) -> CoachBilingualText {
        if context.hydrationState.isBehind {
            return .en("Drink water", "Попейте воды", chinese: "喝点水")
        }
        if context.fuelState.isBehind {
            return .en("Eat a meal", "Поешьте", chinese: "正常吃饭")
        }
        if shouldSuggestWalk(context) {
            return .en("Easy walk", "Прогулка", chinese: "轻松走走")
        }
        return .en("Keep the plan", "По плану", chinese: "按计划")
    }

    /// Water and food first, then an easy walk on an open day. A planned session stays the plan.
    private static func recommendation(for context: CoachContext) -> CoachBilingualText {
        if context.hydrationState.isBehind {
            return .en(
                "Drink some water and keep the day easy.",
                "Попейте воды и оставьте день лёгким.",
                chinese: "先喝点水，今天保持轻松。"
            )
        }
        if context.fuelState.isBehind {
            return .en(
                "Eat a normal meal and keep the day easy.",
                "Поешьте как обычно и оставьте день лёгким.",
                chinese: "正常吃一餐，今天保持轻松。"
            )
        }
        if shouldSuggestWalk(context) {
            return .en(
                "Take an easy walk. Don't add intensity.",
                "Пройдитесь спокойно. Нагрузку не повышайте.",
                chinese: "轻松走一走，不要再加强度。"
            )
        }
        return .en(
            "Follow the plan. Don't add intensity.",
            "Идите по плану. Нагрузку не повышайте.",
            chinese: "按原计划进行，不要再加强度。"
        )
    }

    private static func shouldSuggestWalk(_ context: CoachContext) -> Bool {
        if context.completedWalkToday { return false }
        if context.timeOfDay == .night { return false }
        if context.activityState == .upcoming { return false }
        return true
    }
}
