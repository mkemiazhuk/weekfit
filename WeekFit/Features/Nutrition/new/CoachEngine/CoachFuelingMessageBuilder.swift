import Foundation

enum CoachFuelingMessageBuilder {

    static func messages(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext,
        maxItems: Int = 3
    ) -> [String] {

        let items: [String]

        switch scenario.stage {
        case .before:
            items = beforeMessages(
                scenario: scenario,
                nutrition: nutrition
            )

        case .during:
            items = duringMessages(
                scenario: scenario,
                nutrition: nutrition
            )

        case .after:
            items = afterMessages(
                scenario: scenario,
                nutrition: nutrition
            )

        case .stable:
            items = []
        }

        return Array(unique(items).prefix(maxItems))
    }
}

// MARK: - Stage Messages

private extension CoachFuelingMessageBuilder {

    static func beforeMessages(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext
    ) -> [String] {

        let type = activityType(scenario)
        let long = isLong(scenario)
        let hard = isHard(scenario)
        let veryClose = isVeryCloseToStart(scenario)

        switch type {

        case .cycling:
            if long || hard {
                if veryClose {
                    return [
                        "Take water with you",
                        "Take portable carbs (banana or energy bar)",
                        "Use electrolytes if sweating (isotonic drink)"
                    ]
                }

                return [
                    "Drink water before the ride",
                    "Prepare portable carbs (banana or energy bar)",
                    "Use electrolytes if sweating (isotonic drink)"
                ]
            }

            return [
                "Drink water before the ride",
                "Add light carbs if energy is low (banana)",
                "Start the first 10 min easy"
            ]

        case .running:
            if long || hard {
                if veryClose {
                    return [
                        "Drink water before you start",
                        "Take portable carbs if needed (gel or banana)",
                        "Use electrolytes if hot or sweaty"
                    ]
                }

                return [
                    "Drink 300–500 ml water before the run",
                    "Prepare portable carbs (gel, banana or bar)",
                    "Use electrolytes if hot or sweaty"
                ]
            }

            return [
                "Drink water before you start",
                "Keep food light (banana if hungry)",
                "Start below target pace"
            ]

        case .tennis:
            if long || hard {
                return [
                    "Bring water to court",
                    "Take portable carbs (banana or bar)",
                    "Use electrolytes between games"
                ]
            }

            return [
                "Drink water before court time",
                "Take a banana if energy is low",
                "Use electrolytes if sweating"
            ]

        case .squash:
            return [
                "Drink water before court time",
                "Use electrolytes if sweating heavily",
                "Keep food light before play"
            ]

        case .strength:
            if veryClose {
                return [
                    "Drink water before training",
                    "Keep food light before lifting",
                    "Plan protein after training"
                ]
            }

            return [
                "Drink water before training",
                "Eat light if hungry (banana or toast)",
                "Plan protein after training"
            ]

        case .heat:
            return [
                "Drink water before heat",
                "Use electrolytes (mineral water or isotonic drink)",
                "Keep food light"
            ]

        case .recovery:
            return [
                "Keep hydration simple",
                "No special food needed",
                "Use this as recovery support"
            ]

        case .other:
            return [
                "Drink water before you start",
                "Keep food light",
                "Stay within the plan"
            ]
        }
    }

    static func duringMessages(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext
    ) -> [String] {

        let type = activityType(scenario)
        let long = isLong(scenario)
        let hard = isHard(scenario)

        switch type {

        case .cycling:
            if long || hard {
                return [
                    "Sip water regularly",
                    "Eat carbs every 45–60 min (banana or bar)",
                    "Use electrolytes if sweating (isotonic drink)"
                ]
            }

            return [
                "Sip water as needed",
                "No extra food unless energy drops",
                "Keep cadence steady"
            ]

        case .running:
            if long || hard {
                return [
                    "Sip water regularly",
                    "Use carbs after 45–60 min (gel or banana)",
                    "Keep effort sustainable"
                ]
            }

            return [
                "Stay relaxed",
                "Sip water if needed",
                "Keep pace comfortable"
            ]

        case .tennis:
            if long || hard {
                return [
                    "Sip water between games",
                    "Use electrolytes if sweating",
                    "Eat carbs if session goes long (banana or bar)"
                ]
            }

            return [
                "Sip water between games",
                "Use electrolytes if sweating",
                "Keep energy steady"
            ]

        case .squash:
            return [
                "Sip water between games",
                "Use electrolytes if sweating heavily",
                "Avoid all-out rallies every point"
            ]

        case .strength:
            return [
                "Sip water between sets",
                "No extra food needed for short lifting",
                "Stop before form drops"
            ]

        case .heat:
            return [
                "Keep heat exposure conservative",
                "Exit if dizzy",
                "Rehydrate after the session"
            ]

        case .recovery:
            return [
                "Keep it easy",
                "Sip water if needed",
                "Do not turn this into training"
            ]

        case .other:
            return [
                "Sip water if needed",
                "Keep effort steady",
                "Stay comfortable"
            ]
        }
    }

    static func afterMessages(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext
    ) -> [String] {

        let type = activityType(scenario)
        let hard = isHard(scenario)
        let long = isLong(scenario)

        switch type {

        case .cycling, .running:
            var items: [String] = []

            if nutrition.needsProteinRecovery {
                items.append(proteinRecoveryMessage(nutrition))
            } else {
                items.append("Eat a recovery meal (protein + carbs)")
            }

            if hard || long {
                items.append("Replace fluids and electrolytes")
            } else {
                items.append("Drink water gradually")
            }

            items.append("Keep the next block easy")

            return items

        case .tennis, .squash:
            var items: [String] = []

            if nutrition.needsProteinRecovery {
                items.append(proteinRecoveryMessage(nutrition))
            } else {
                items.append("Eat a recovery meal if hungry")
            }

            items.append("Replace fluids after sweating")
            items.append("Avoid another high-intensity block")

            return items

        case .strength:
            var items: [String] = []

            if nutrition.needsProteinRecovery {
                items.append(proteinRecoveryMessage(nutrition))
            } else {
                items.append("Eat a protein meal when ready")
            }

            items.append("Drink water gradually")
            items.append("Keep movement light")

            return items

        case .heat:
            return [
                "Cool down gradually",
                "Replace fluids and minerals",
                "Avoid hard effort after heat"
            ]

        case .recovery:
            return [
                "Return to routine",
                "Keep hydration simple",
                "Avoid adding load"
            ]

        case .other:
            return [
                "Drink water gradually",
                "Eat normally",
                "Keep the day steady"
            ]
        }
    }
}

// MARK: - Message Helpers

private extension CoachFuelingMessageBuilder {

    static func proteinRecoveryMessage(
        _ nutrition: CoachNutritionContext
    ) -> String {

        if let recommendation = nutrition.recommendedProteinText {
            return "\(recommendation) (Greek yogurt, eggs, chicken or shake)"
        }

        return "Add protein (Greek yogurt, eggs, chicken or shake)"
    }
}

// MARK: - Helpers

private extension CoachFuelingMessageBuilder {

    enum FuelActivityType {
        case cycling
        case running
        case tennis
        case squash
        case strength
        case heat
        case recovery
        case other
    }

    static func activityType(_ scenario: CoachActivityScenario) -> FuelActivityType {
        let text = "\(scenario.activity?.title ?? "") \(scenario.activity?.type ?? "")"
            .lowercased()

        if text.contains("cycling") ||
            text.contains("cycle") ||
            text.contains("bike") ||
            text.contains("ride") {
            return .cycling
        }

        if text.contains("running") ||
            text.contains("run") {
            return .running
        }

        if text.contains("tennis") {
            return .tennis
        }

        if text.contains("squash") {
            return .squash
        }

        if text.contains("upper body") ||
            text.contains("strength") ||
            text.contains("gym") ||
            text.contains("workout") ||
            text.contains("training") {
            return .strength
        }

        if text.contains("sauna") ||
            text.contains("heat") ||
            text.contains("hot yoga") {
            return .heat
        }

        if text.contains("walk") ||
            text.contains("stretch") ||
            text.contains("mobility") ||
            text.contains("yoga") ||
            text.contains("breathing") {
            return .recovery
        }

        return .other
    }

    static func isLong(_ scenario: CoachActivityScenario) -> Bool {
        scenario.durationBucket == .sixtyTo90 ||
        scenario.durationBucket == .over90
    }

    static func isHard(_ scenario: CoachActivityScenario) -> Bool {
        scenario.load == .high ||
        scenario.load == .extreme
    }

    static func isVeryCloseToStart(_ scenario: CoachActivityScenario) -> Bool {
        guard let minutes = scenario.minutesUntilStart else {
            return false
        }

        return minutes <= 15
    }

    static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }

            let key = clean.lowercased()
            guard !seen.contains(key) else { continue }

            seen.insert(key)
            result.append(clean)
        }

        return result
    }
}
