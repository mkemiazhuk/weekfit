import Foundation

/// Routes free-text user messages into existing guided branches or a clear fallback.
enum CoachAssistantIntentRouter {

    enum Intent: Equatable, Sendable {
        case feeling(CoachFeelingKind)
        case clarification(CoachFeelingClarification)
        case area(CoachAssistantArea)
        case activityDetail(CoachAssistantNodeID)
        case nutritionDetail(CoachAssistantNodeID)
        case recoveryDetail(CoachAssistantNodeID)
        case unsupported(reply: CoachBilingualText)
    }

    static func route(
        _ raw: String,
        currentNode: CoachAssistantNodeID,
        feeling: CoachFeelingKind?
    ) -> Intent {
        let text = normalize(raw)

        if let feelingIntent = detectFeeling(text) {
            return .feeling(feelingIntent)
        }
        if let clarification = detectClarification(text) {
            return .clarification(clarification)
        }
        if let area = detectArea(text) {
            return .area(area)
        }

        // Context-sensitive follow-ups while already in an area.
        if currentNode == .nutritionMenu || currentNode == .nutritionGate || feeling != nil {
            if matches(text, ["protein", "белок", "left", "остал", "calories", "калор", "what's left", "что осталось"]) {
                return .nutritionDetail(.nutritionRemaining)
            }
            if matches(text, ["meal", "еда", "eat", "есть", "food", "блюдо", "choose"]) {
                return .nutritionDetail(.nutritionChooseMeal)
            }
            if matches(text, ["habit", "pattern", "привыч", "паттерн"]) {
                return .nutritionDetail(.nutritionHabits)
            }
        }

        if matches(text, ["train today", "тренироваться сегодня", "take it easy", "полегче", "session", "сесси", "how hard", "интенсив"]) {
            return .activityDetail(.activityToday)
        }
        if matches(text, ["building", "recent training", "недавн", "last 7", "недел"]) {
            return .activityDetail(.activityRecent)
        }
        if matches(text, ["consistent", "последоват"]) {
            return .activityDetail(.activityConsistency)
        }

        if matches(text, ["last night", "прошл", "sleep", "сон", "rough night"]) {
            return .recoveryDetail(.recoveryToday)
        }
        if matches(text, ["few days", "несколько дней", "building up", "накапл"]) {
            return .recoveryDetail(.recoveryPattern)
        }

        return .unsupported(reply: fallbackReply(for: text, feeling: feeling))
    }

    // MARK: - Detection

    private static func detectFeeling(_ text: String) -> CoachFeelingKind? {
        if matches(text, ["not great", "не очень", "low", "плохо", "meh"]) {
            return .low
        }
        if matches(text, ["tired", "устал", "exhausted", "drained", "измож", "fatigued", "sleepy", "сонлив"]) {
            return .tired
        }
        if matches(text, ["energized", "энерг", "great", "отлично", "feeling good", "хорошо", "strong", "бодр", "good"]) {
            return .energized
        }
        if matches(text, ["okay", "ok", "fine", "нормальн", "alright", "so-so", "средне"]) {
            return .okay
        }
        return nil
    }

    private static func detectClarification(_ text: String) -> CoachFeelingClarification? {
        if matches(text, ["sore", "мышц", "muscle", "ache", "болит"]) {
            return .soreMuscles
        }
        if matches(text, ["low energy", "мало энергии", "no energy", "нет сил"]) {
            return .lowEnergy
        }
        if matches(text, ["sleepiness", "сонливость", "drowsy", "want to sleep"]) {
            return .sleepiness
        }
        return nil
    }

    private static func detectArea(_ text: String) -> CoachAssistantArea? {
        if matches(text, ["my activity", "activity", "активност", "training", "тренир", "workout", "план"]) {
            return .activity
        }
        if matches(text, ["my nutrition", "nutrition", "питан", "food", "еда", "meal", "eat", "protein", "белок"]) {
            return .nutrition
        }
        if matches(text, ["my recovery", "recovery", "восстанов", "sleep", "сон", "hrv"]) {
            return .recovery
        }
        return nil
    }

    private static func fallbackReply(
        for text: String,
        feeling: CoachFeelingKind?
    ) -> CoachBilingualText {
        if feeling == nil {
            return CoachAssistantCopy.bi(
                "I can help with how you feel, your activity, nutrition, or recovery. How are you feeling today — or what would you like to look at?",
                "Могу помочь с самочувствием, активностью, питанием или восстановлением. Как вы себя чувствуете сегодня — или что хотите разобрать?"
            )
        }
        return CoachAssistantCopy.bi(
            "I can look at your activity, nutrition, or recovery next — or tell me more about how you feel.",
            "Дальше могу разобрать активность, питание или восстановление — или расскажите подробнее о самочувствии."
        )
    }

    private static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func matches(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }
}
