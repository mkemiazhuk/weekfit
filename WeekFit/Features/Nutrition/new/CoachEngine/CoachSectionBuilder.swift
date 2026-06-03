import SwiftUI

enum CoachSectionBuilder {

    static func build(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext,
        trainingFallback: [String],
        coachAccentColor: Color
    ) -> [CoachSection] {

        let profile = CoachActivityProfileResolver.resolve(scenario: scenario)

        let sections: [CoachSection]

        switch profile {

        case .breathing:
            sections = breathingSections(
                scenario: scenario
            )

        case .recovery:
            sections = recoverySections(
                scenario: scenario,
                nutrition: nutrition
            )

        case .heat:
            sections = heatSections(
                scenario: scenario,
                nutrition: nutrition
            )

        default:
            sections = workoutSections(
                scenario: scenario,
                nutrition: nutrition,
                trainingFallback: trainingFallback,
                coachAccentColor: coachAccentColor
            )
        }

        return sections.filter { !$0.isEmpty }
    }
}

// MARK: - Workout / Performance

private extension CoachSectionBuilder {

    static func workoutSections(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext,
        trainingFallback: [String],
        coachAccentColor: Color
    ) -> [CoachSection] {

        let fuelItems = CoachFuelingMessageBuilder.messages(
            scenario: scenario,
            nutrition: nutrition,
            maxItems: 3
        )

        let sessionItems = CoachSessionMessageBuilder.messages(
            scenario: scenario,
            fallback: trainingFallback,
            maxItems: 3
        )

        return [
            CoachSection(
                title: "Fuel & Hydration",
                subtitle: fuelSubtitle(for: scenario),
                icon: "fork.knife",
                color: WeekFitTheme.meal,
                style: .compact,
                items: fuelItems
            ),

            CoachSection(
                title: "Session Focus",
                subtitle: sessionSubtitle(for: scenario),
                icon: "checkmark",
                color: coachAccentColor,
                style: .cards,
                items: sessionItems
            )
        ]
    }
}

// MARK: - Breathing / Mindfulness

private extension CoachSectionBuilder {

    static func breathingSections(
        scenario: CoachActivityScenario
    ) -> [CoachSection] {

        switch scenario.stage {

        case .before:
            return [
                CoachSection(
                    title: "Settle In",
                    subtitle: "How to enter the session calmly.",
                    icon: "wind",
                    color: CoachPalette.recovery,
                    style: .cards,
                    items: [
                        "Sit or lie down comfortably",
                        "Let the exhale become slower",
                        "Do not force the breath"
                    ]
                ),

                CoachSection(
                    title: "Coach Insight",
                    subtitle: "What to keep in mind.",
                    icon: "leaf.fill",
                    color: CoachPalette.recovery,
                    style: .info,
                    informationalText: "This is not a performance block. The goal is to create a calmer state and let the body downshift."
                )
            ]

        case .during:
            return [
                CoachSection(
                    title: "Stay With It",
                    subtitle: "What matters during this session.",
                    icon: "wind",
                    color: CoachPalette.recovery,
                    style: .cards,
                    items: [
                        "Keep the breath comfortable",
                        "Make the exhale gentle",
                        "Return calmly if your mind wanders"
                    ]
                )
            ]

        case .after:
            return [
                CoachSection(
                    title: "Recovery Effect",
                    subtitle: "What changed during the session.",
                    icon: "leaf.fill",
                    color: CoachPalette.recovery,
                    style: .cards,
                    items: [
                        "Heart rate begins to settle",
                        "Stress may feel lower",
                        "Recovery mode is easier to maintain"
                    ]
                ),

                CoachSection(
                    title: "What To Do Next",
                    subtitle: "How to protect the downshift.",
                    icon: "moon.stars.fill",
                    color: CoachPalette.recovery,
                    style: .cards,
                    items: [
                        "Keep screens low for the next hour",
                        "Continue into your evening routine",
                        "Avoid jumping back into stress"
                    ]
                ),

                CoachSection(
                    title: "Coach Insight",
                    subtitle: "The effect continues afterwards.",
                    icon: "sparkles",
                    color: CoachPalette.recovery,
                    style: .info,
                    informationalText: "The goal now is simple: protect the relaxed state you just created."
                )
            ]

        case .stable:
            return []
        }
    }
}

// MARK: - Recovery

private extension CoachSectionBuilder {

    static func recoverySections(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext
    ) -> [CoachSection] {

        let supportItems = recoverySupportItems(
            scenario: scenario,
            nutrition: nutrition
        )

        return [
            CoachSection(
                title: "Recovery Support",
                subtitle: recoverySupportSubtitle(for: scenario),
                icon: "drop.fill",
                color: WeekFitTheme.meal,
                style: .compact,
                items: supportItems
            ),

            CoachSection(
                title: "Why This Matters",
                subtitle: "How this recovery block helps your body.",
                icon: "leaf.fill",
                color: CoachPalette.recovery,
                style: .info,
                informationalText: recoveryWhyText(scenario: scenario)
            )
        ]
    }

    static func recoverySupportItems(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext
    ) -> [String] {

        let text = activityText(scenario)

        if isWalk(text) {
            if scenario.dayTime == .evening ||
                scenario.dayTime == .lateEvening ||
                scenario.dayTime == .night {
                return [
                    "Drink 300–500 ml water",
                    "Keep dinner protein-focused",
                    "Avoid heavy food right before sleep"
                ]
            }

            return [
                "Drink water if needed",
                "Walk at a comfortable pace",
                "Keep breathing relaxed"
            ]
        }

        if isStretching(text) {
            return [
                "Move slowly",
                "Avoid painful positions",
                "Focus on range of motion"
            ]
        }

        if isYoga(text) {
            return [
                "Keep the flow gentle",
                "Avoid forcing deep positions",
                "Finish calmer than you started"
            ]
        }

        return [
            "Keep hydration simple",
            "Move gently",
            "Avoid adding load"
        ]
    }
}

// MARK: - Heat / Sauna

private extension CoachSectionBuilder {

    static func heatSections(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext
    ) -> [CoachSection] {

        [
            CoachSection(
                title: "Recovery Support",
                subtitle: heatSupportSubtitle(for: scenario),
                icon: "drop.fill",
                color: WeekFitTheme.meal,
                style: .compact,
                items: heatSupportItems(scenario: scenario)
            ),

            CoachSection(
                title: "Why This Matters",
                subtitle: "How heat supports recovery.",
                icon: "flame.fill",
                color: CoachPalette.warning,
                style: .info,
                informationalText: "Heat can help circulation, muscle relaxation and the transition into recovery mode. Hydration afterwards is what turns the session into recovery support rather than extra stress."
            )
        ]
    }

    static func heatSupportItems(
        scenario: CoachActivityScenario
    ) -> [String] {

        switch scenario.stage {
        case .before:
            return [
                "Drink water before heat",
                "Have mineral water or electrolytes",
                "Keep food light"
            ]

        case .during:
            return [
                "Keep the session comfortable",
                "Exit if dizzy",
                "Do not push through stress"
            ]

        case .after:
            return [
                "Drink water slowly",
                "Have mineral water or electrolytes",
                "Keep the evening calm"
            ]

        case .stable:
            return []
        }
    }
}

// MARK: - Subtitles

private extension CoachSectionBuilder {

    static func fuelSubtitle(
        for scenario: CoachActivityScenario
    ) -> String {
        switch scenario.stage {
        case .before:
            return "What to eat, drink or take before starting."
        case .during:
            return "What to use during the session."
        case .after:
            return "What supports recovery after training."
        case .stable:
            return "Useful nutrition and hydration support."
        }
    }

    static func sessionSubtitle(
        for scenario: CoachActivityScenario
    ) -> String {
        switch scenario.stage {
        case .before:
            return "How to approach the upcoming session."
        case .during:
            return "What matters while the session is happening."
        case .after:
            return "How to recover from the completed session."
        case .stable:
            return "Training guidance for the current context."
        }
    }

    static func recoverySupportSubtitle(
        for scenario: CoachActivityScenario
    ) -> String {
        switch scenario.stage {
        case .before:
            return "What helps recovery around this activity."
        case .during:
            return "What to keep in mind while doing it."
        case .after:
            return "What to do over the next 1–2 hours."
        case .stable:
            return "Simple recovery support for now."
        }
    }

    static func heatSupportSubtitle(
        for scenario: CoachActivityScenario
    ) -> String {
        switch scenario.stage {
        case .before:
            return "What to do before heat exposure."
        case .during:
            return "How to keep the heat block safe."
        case .after:
            return "What to do over the next 1–2 hours."
        case .stable:
            return "Simple heat recovery support."
        }
    }

    static func recoveryWhyText(
        scenario: CoachActivityScenario
    ) -> String {

        let text = activityText(scenario)

        if isWalk(text) {
            return "Easy walking supports circulation and recovery without adding meaningful fatigue. The goal is to feel better afterwards, not more tired."
        }

        if isStretching(text) {
            return "Mobility work can reduce stiffness and maintain movement quality between training sessions. Move slowly and avoid forcing painful positions."
        }

        if isYoga(text) {
            return "Gentle yoga can release tension, improve mobility and help the body downshift. Keep the session calm enough to support recovery."
        }

        return "Recovery work helps the body settle after load. The goal is to reduce tension, support sleep and avoid adding more stress."
    }
}

// MARK: - Helpers

private extension CoachSectionBuilder {

    static func activityText(
        _ scenario: CoachActivityScenario
    ) -> String {
        "\(scenario.activity?.title ?? "") \(scenario.activity?.type ?? "")"
            .lowercased()
    }

    static func isWalk(_ text: String) -> Bool {
        text.contains("walk") ||
        text.contains("walking") ||
        text.contains("hike")
    }

    static func isStretching(_ text: String) -> Bool {
        text.contains("stretch") ||
        text.contains("mobility")
    }

    static func isYoga(_ text: String) -> Bool {
        text.contains("yoga")
    }
}
