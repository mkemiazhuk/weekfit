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

        return Array(unique(items).map(localized).prefix(maxItems))
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
            return String(
                format: WeekFitLocalizedString("coach.fueling.proteinRecommendationFormat"),
                recommendation
            )
        }

        return localized("Add protein (Greek yogurt, eggs, chicken or shake)")
    }

    static func localized(_ text: String) -> String {
        let catalogValue = WeekFitLocalizedString(text)
        if catalogValue != text || !WeekFitCurrentLocale().identifier.hasPrefix("ru") {
            return catalogValue
        }

        return russianFixedMessageTranslations[text] ?? text
    }

    static let russianFixedMessageTranslations: [String: String] = [
        "Add light carbs if energy is low (banana)": "Добавьте легкие углеводы, если мало энергии (банан)",
        "Add protein (Greek yogurt, eggs, chicken or shake)": "Добавьте белок (греческий йогурт, яйца, курица или шейк)",
        "Avoid adding load": "Не добавляйте нагрузку",
        "Avoid all-out rallies every point": "Не играйте каждый розыгрыш на максимуме",
        "Avoid another high-intensity block": "Не добавляйте еще один интенсивный блок",
        "Avoid hard effort after heat": "Избегайте тяжелой нагрузки после тепла",
        "Bring water to court": "Возьмите воду на корт",
        "Cool down gradually": "Остывайте постепенно",
        "Do not turn this into training": "Не превращайте это в тренировку",
        "Drink 300–500 ml water before the run": "Выпейте 300–500 мл воды перед бегом",
        "Drink water before court time": "Выпейте воды перед кортом",
        "Drink water before heat": "Выпейте воды перед теплом",
        "Drink water before the ride": "Выпейте воды перед заездом",
        "Drink water before training": "Выпейте воды перед тренировкой",
        "Drink water before you start": "Выпейте воды перед стартом",
        "Drink water gradually": "Пейте воду постепенно",
        "Eat a protein meal when ready": "Съешьте белковый прием пищи, когда будете готовы",
        "Eat a recovery meal (protein + carbs)": "Съешьте восстановительный прием пищи (белок + углеводы)",
        "Eat a recovery meal if hungry": "Съешьте восстановительный прием пищи, если голодны",
        "Eat carbs every 45–60 min (banana or bar)": "Ешьте углеводы каждые 45–60 мин (банан или батончик)",
        "Eat carbs if session goes long (banana or bar)": "Добавьте углеводы, если тренировка затянется (банан или батончик)",
        "Eat light if hungry (banana or toast)": "Ешьте легко, если голодны (банан или тост)",
        "Eat normally": "Ешьте нормально",
        "Exit if dizzy": "Выходите, если закружится голова",
        "Keep cadence steady": "Держите ровный каденс",
        "Keep effort steady": "Держите ровное усилие",
        "Keep effort sustainable": "Держите устойчивое усилие",
        "Keep energy steady": "Держите энергию ровной",
        "Keep food light": "Держите еду легкой",
        "Keep food light (banana if hungry)": "Держите еду легкой (банан, если голодны)",
        "Keep food light before lifting": "Держите еду легкой перед силовой",
        "Keep food light before play": "Держите еду легкой перед игрой",
        "Keep heat exposure conservative": "Держите тепловой блок консервативным",
        "Keep hydration simple": "Держите гидратацию простой",
        "Keep it easy": "Держите легко",
        "Keep movement light": "Держите движение легким",
        "Keep pace comfortable": "Держите комфортный темп",
        "Keep the day steady": "Держите день ровным",
        "Keep the next block easy": "Держите следующий блок легким",
        "No extra food needed for short lifting": "Для короткой силовой дополнительная еда не нужна",
        "No extra food unless energy drops": "Без дополнительной еды, если энергия не падает",
        "No special food needed": "Специальная еда не нужна",
        "Plan protein after training": "Запланируйте белок после тренировки",
        "Prepare portable carbs (banana or energy bar)": "Подготовьте углеводы с собой (банан или энергетический батончик)",
        "Prepare portable carbs (gel, banana or bar)": "Подготовьте углеводы с собой (гель, банан или батончик)",
        "Rehydrate after the session": "Восполните жидкость после тренировки",
        "Replace fluids after sweating": "Восполните жидкость после потоотделения",
        "Replace fluids and electrolytes": "Восполните жидкость и электролиты",
        "Replace fluids and minerals": "Восполните жидкость и минералы",
        "Return to routine": "Вернитесь к рутине",
        "Sip water as needed": "Пейте воду маленькими глотками по необходимости",
        "Sip water between games": "Пейте воду между геймами",
        "Sip water between sets": "Пейте воду между подходами",
        "Sip water if needed": "Пейте воду маленькими глотками, если нужно",
        "Sip water regularly": "Пейте воду регулярно маленькими глотками",
        "Start below target pace": "Начните ниже целевого темпа",
        "Start the first 10 min easy": "Первые 10 минут начните легко",
        "Stay comfortable": "Оставайтесь в комфорте",
        "Stay relaxed": "Оставайтесь расслабленными",
        "Stay within the plan": "Оставайтесь в рамках плана",
        "Stop before form drops": "Остановитесь до ухудшения техники",
        "Take a banana if energy is low": "Возьмите банан, если мало энергии",
        "Take portable carbs (banana or bar)": "Возьмите углеводы с собой (банан или батончик)",
        "Take portable carbs (banana or energy bar)": "Возьмите углеводы с собой (банан или энергетический батончик)",
        "Take portable carbs if needed (gel or banana)": "Возьмите углеводы с собой при необходимости (гель или банан)",
        "Take water with you": "Возьмите воду с собой",
        "Use carbs after 45–60 min (gel or banana)": "Используйте углеводы после 45–60 мин (гель или банан)",
        "Use electrolytes (mineral water or isotonic drink)": "Используйте электролиты (минеральная вода или изотоник)",
        "Use electrolytes between games": "Используйте электролиты между геймами",
        "Use electrolytes if hot or sweaty": "Используйте электролиты, если жарко или много пота",
        "Use electrolytes if sweating": "Используйте электролиты, если потеете",
        "Use electrolytes if sweating (isotonic drink)": "Используйте электролиты, если потеете (изотоник)",
        "Use electrolytes if sweating heavily": "Используйте электролиты при сильном потоотделении",
        "Use this as recovery support": "Используйте это как поддержку восстановления"
    ]
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
