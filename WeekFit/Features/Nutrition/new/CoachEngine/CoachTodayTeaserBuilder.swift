import Foundation
import SwiftUI

/// Semantic coaching signal for presentation surfaces — not raw data source.
enum CoachPresentationSemanticColor: Hashable {
    case green
    case yellow
    case red
    case purple

    var color: Color {
        switch self {
        case .green:
            return CoachPalette.stable
        case .yellow:
            return CoachPalette.warning
        case .red:
            return CoachPalette.stress
        case .purple:
            return CoachPalette.recovery
        }
    }
}

/// Compressed Today card: one coaching idea + one action. Not a calendar/status card.
struct CoachTodayTeaserPresentation: Hashable {
    let idea: String
    let action: String
    let semanticColor: CoachPresentationSemanticColor
}

enum CoachPresentationSemanticColorResolver {

    static func resolve(
        story: CoachFinalStory,
        guidance: CoachGuidanceV3,
        profile: CoachPresentationActivityProfile,
        scenario: CoachPresentationScenario,
        input: CoachInputSnapshot
    ) -> CoachPresentationSemanticColor {
        if guidance.priority.severity == .critical {
            switch guidance.priority.limiter {
            case .recovery, .trainingReadiness, .accumulatedFatigue, .excessivePlannedLoad, .insufficientRecoveryTime:
                if input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 50 {
                    return .red
                }
                return .purple
            case .sleep:
                if input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 45 {
                    return .red
                }
                return .yellow
            case .hydration, .fueling:
                return .yellow
            case .upcomingTraining, .timing, .none:
                return .yellow
            }
        }

        switch scenario {
        case .fuelSupport, .hydrationSupport, .sessionPrep, .tomorrowProtection, .heatSafetyPrep:
            if scenario == .heatSafetyPrep {
                return CoachPresentationHeatSafetyGuard.semanticColor(input: input, guidance: guidance)
            }
            if scenario == .sessionPrep, profile.family == .heat {
                return .purple
            }
            return .yellow
        case .postWorkoutRecovery:
            return .purple
        case .activeWorkout:
            if profile.family == .heat {
                return .purple
            }
            if story.title.resolved.localizedCaseInsensitiveContains("would not continue") ||
                story.title.resolved.localizedCaseInsensitiveContains("лучше не продолжать") {
                return .red
            }
            return .green
        case .stableDayOwnership, .stableMorning, .morningWalkStart:
            return .green
        case .general:
            break
        }

        switch story.owner {
        case .recovery, .postActivityRecovery:
            return .purple
        case .tomorrowProtection:
            return .yellow
        case .hydration, .hydrationExecution, .fuel, .fuelingDuringActivity:
            return .yellow
        case .activityPreparation:
            return .yellow
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return .green
        case .readiness, .stableOverview:
            return .green
        }
    }
}

enum CoachTodayTeaserBuilder {

    static func build(
        story: CoachFinalStory,
        guidance: CoachGuidanceV3,
        profile: CoachPresentationActivityProfile,
        scenario: CoachPresentationScenario,
        renderModel: CoachFinalStoryRenderModel,
        input: CoachInputSnapshot
    ) -> CoachTodayTeaserPresentation {
        let semanticColor = CoachPresentationSemanticColorResolver.resolve(
            story: story,
            guidance: guidance,
            profile: profile,
            scenario: scenario,
            input: input
        )

        if let teaser = scenarioTeaser(
            story: story,
            guidance: guidance,
            profile: profile,
            scenario: scenario,
            renderModel: renderModel,
            input: input
        ) {
            return CoachTodayTeaserPresentation(
                idea: teaser.idea,
                action: teaser.action,
                semanticColor: semanticColor
            )
        }

        let idea = sanitizedIdea(from: renderModel.title, profile: profile)
            ?? localized(english: "Stay with the plan", russian: "Оставайтесь в своём ритме")
        let action = sanitizedAction(
            from: renderModel.primaryRecommendation.isEmpty ? renderModel.subtitle : renderModel.primaryRecommendation,
            profile: profile,
            story: story,
            guidance: guidance,
            input: input,
            scenario: scenario
        ) ?? localized(english: "Keep the next step simple.", russian: "Следующий шаг держите простым.")

        return CoachTodayTeaserPresentation(
            idea: idea,
            action: action,
            semanticColor: semanticColor
        )
    }

    private static func scenarioTeaser(
        story: CoachFinalStory,
        guidance: CoachGuidanceV3,
        profile: CoachPresentationActivityProfile,
        scenario: CoachPresentationScenario,
        renderModel: CoachFinalStoryRenderModel,
        input: CoachInputSnapshot
    ) -> (idea: String, action: String)? {
        if let endurance = CoachEnduranceTodayTeaserCopy.teaser(
            story: story,
            input: input,
            scenario: scenario
        ) {
            return endurance
        }

        switch scenario {
        case .stableDayOwnership:
            return (
                localized(english: "Nothing needs fixing", russian: "Ничего исправлять не нужно"),
                localized(english: "The day is unfolding calmly.", russian: "День развивается спокойно.")
            )

        case .activeWorkout:
            if guidance.priority.strength == .critical &&
                (guidance.priority.limiter == .trainingReadiness ||
                 guidance.priority.focus == .trainingReadinessWarning) {
                return (
                    localized(english: "Ease up now", russian: "Сейчас лучше сбавить"),
                    localized(english: "Keep the next block lighter than usual.", russian: "Следующий блок держите легче обычного.")
                )
            }
            if profile.family == .heat {
                return (
                    localized(english: "Keep the heat moderate", russian: "Держите тепло умеренным"),
                    localized(english: "Leave before fatigue shows.", russian: "Выйдите до появления усталости.")
                )
            }
            return (
                localized(english: "Don't chase the numbers", russian: "Не гонитесь за цифрами"),
                localized(english: "Settle in before adding effort.", russian: "Сначала держите темп лёгким, потом добавляйте.")
            )

        case .sessionPrep:
            if profile.family == .heat {
                return (
                    localized(english: "Good window for recovery", russian: "Хорошее окно для восстановления"),
                    localized(english: "Keep heat moderate and the rest calm.", russian: "Держите тепло умеренным, остаток дня — спокойно.")
                )
            }
            if profile.isRecoveryModality {
                return (
                    localized(english: "Start calmly", russian: "Начните спокойно"),
                    localized(english: "Keep the pace easy from the first minutes.", russian: "С первых минут держите темп лёгким.")
                )
            }
            if CoachPresentationNutritionGuard.shouldSurfaceFuelPrep(profile: profile, input: input, guidance: guidance) {
                return (
                    localized(english: "Prepare for the start", russian: "Подготовьтесь к старту"),
                    localized(english: "Eat a little and hydrate before you go.", russian: "Поешьте немного и попейте воды перед стартом.")
                )
            }
            return (
                localized(english: "Prepare for the start", russian: "Подготовьтесь к старту"),
                localized(english: "Eat lightly and hydrate before you go.", russian: "Поешьте немного и попейте воды перед стартом.")
            )

        case .postWorkoutRecovery:
            return (
                localized(english: "Recovery leads now", russian: "Сейчас важнее восстановление"),
                localized(english: "Take the next hour easy — no extra load.", russian: "Следующий час проведите легко — без лишней нагрузки.")
            )

        case .fuelSupport:
            guard CoachPresentationNutritionGuard.nutritionShouldOwnInsight(
                story: story,
                guidance: guidance,
                profile: profile,
                input: input,
                scenario: scenario
            ) else { return nil }
            return (
                localized(english: "Energy needs a top-up", russian: "Силы стоит подпитать"),
                localized(english: "Eat before you ask for more effort.", russian: "Поешьте, прежде чем требовать от себя больше.")
            )

        case .hydrationSupport:
            guard CoachPresentationNutritionGuard.nutritionShouldOwnInsight(
                story: story,
                guidance: guidance,
                profile: profile,
                input: input,
                scenario: scenario
            ) else { return nil }
            return (
                localized(english: "Fluids need attention", russian: "Сейчас важнее всего вода"),
                localized(english: "Sip steadily through the rest of the day.", russian: "Пейте понемногу в течение дня.")
            )

        case .heatSafetyPrep:
            let severe = CoachPresentationHeatSafetyGuard.hydrationRiskLevel(input: input, guidance: guidance) == .severe
            if severe {
                return (
                    localized(english: "Hydration matters before heat", russian: "Перед теплом важна вода"),
                    localized(english: "Drink calmly before sauna — no intensity after.", russian: "Пейте спокойно до сауны — интенсивность после не добавляйте.")
                )
            }
            return (
                localized(english: "Top up water before heat", russian: "Перед сауной лучше спокойно добрать воду"),
                localized(english: "Sauna is recovery heat, not training.", russian: "Сауна — восстановление, а не тренировка.")
            )

        case .tomorrowProtection:
            return (
                localized(english: "Protect tomorrow", russian: "Берегите завтра"),
                localized(english: "Wind down — no extra load tonight.", russian: "Замедляйтесь — вечером без лишней нагрузки.")
            )

        case .morningWalkStart:
            return (
                localized(english: "Good start to the day", russian: "Хорошее начало дня"),
                localized(english: "Take the walk easy — that is enough for now.", russian: "Прогуляетсь — этого достаточно.")
            )

        case .stableMorning:
            if profile.recoveryPercent >= 85 {
                return (
                    localized(english: "Recovery remains strong", russian: "Восстановление остаётся высоким"),
                    localized(english: "You can keep a normal rhythm for now.", russian: "Можно спокойно держать обычный ритм.")
                )
            }
            return (
                localized(english: "A calm day is unfolding", russian: "Хороший спокойный день"),
                localized(english: "Keep the day steady.", russian: "Не спешите и не перегружайте себя.")
            )

        case .general:
            if CoachLightRecoveryStableDayPolicy.ownsStableDayAfterCompletedLightActivity(
                input: input,
                guidance: guidance
            ) {
                return (
                    localized(english: "Nothing needs fixing", russian: "Ничего исправлять не нужно"),
                    localized(english: "The day is unfolding calmly.", russian: "День развивается спокойно.")
                )
            }
            if story.owner == .stableOverview || story.owner == .readiness,
               guidance.priority.strength != .critical {
                return (
                    localized(english: "No changes needed", russian: "Изменений не нужно"),
                    localized(english: "Keep moving at your usual rhythm.", russian: "Двигайтесь в привычном ритме.")
                )
            }
            return nil
        }
    }

    private static func sanitizedIdea(from text: String, profile: CoachPresentationActivityProfile) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !CoachPresentationScheduleNarrativeGuard.isScheduleNarrative(trimmed, profile: profile) else { return nil }
        guard !CoachPresentationScheduleNarrativeGuard.isStatusCalendarNarrative(trimmed) else { return nil }
        if profile.family == .heat, CoachPresentationHeatSafetyGuard.isWorkoutLanguage(trimmed) { return nil }
        return trimmed
    }

    private static func sanitizedAction(
        from text: String,
        profile: CoachPresentationActivityProfile,
        story: CoachFinalStory,
        guidance: CoachGuidanceV3,
        input: CoachInputSnapshot,
        scenario: CoachPresentationScenario
    ) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !CoachPresentationScheduleNarrativeGuard.isScheduleNarrative(trimmed, profile: profile) else {
            return CoachPresentationScheduleNarrativeGuard.stateFocusedInsightMessage(
                story: story,
                guidance: guidance,
                profile: profile,
                input: input,
                scenario: scenario,
                surface: .todayInsight
            )
        }
        guard !CoachPresentationScheduleNarrativeGuard.isStatusCalendarNarrative(trimmed) else { return nil }
        if profile.family == .heat, CoachPresentationHeatSafetyGuard.isWorkoutLanguage(trimmed) { return nil }
        return trimmed
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}

enum CoachPresentationNutritionGuard {

    static func nutritionShouldOwnInsight(
        story: CoachFinalStory,
        guidance: CoachGuidanceV3,
        profile: CoachPresentationActivityProfile,
        input: CoachInputSnapshot,
        scenario: CoachPresentationScenario
    ) -> Bool {
        switch scenario {
        case .fuelSupport, .hydrationSupport:
            return true
        case .heatSafetyPrep:
            return true
        default:
            break
        }

        switch story.owner {
        case .fuel, .fuelingDuringActivity:
            return meaningfulUnderfueling(input) || story.owner == .fuelingDuringActivity
        case .hydration, .hydrationExecution:
            return safetyHydrationRisk(input, guidance: guidance)
        default:
            break
        }

        if scenario == .sessionPrep, shouldSurfaceFuelPrep(profile: profile, input: input, guidance: guidance) {
            return true
        }

        if guidance.priority.limiter == .fueling, meaningfulUnderfueling(input) {
            return true
        }

        if guidance.priority.limiter == .hydration, safetyHydrationRisk(input, guidance: guidance) {
            return true
        }

        return false
    }

    static func shouldSurfaceFuelPrep(
        profile: CoachPresentationActivityProfile,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guard profile.hasSeriousWorkoutPlanned || guidance.priority.focus == .prepareForActivity else {
            return false
        }
        return meaningfulUnderfueling(input)
    }

    static func meaningfulUnderfueling(_ input: CoachInputSnapshot) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieGoal = input.brain.baseDayGoals.calories
        let ratio = calorieGoal > 0 ? calories / calorieGoal : 1
        return ratio < 0.25 || (input.brain.fuel == .underfueled && calories < 400)
    }

    static func safetyHydrationRisk(_ input: CoachInputSnapshot, guidance: CoachGuidanceV3) -> Bool {
        CoachPresentationHeatSafetyGuard.hydrationRiskLevel(input: input, guidance: guidance) != .none
    }
}

enum CoachPresentationHeatSafetyGuard {

    enum HydrationRiskLevel: Hashable {
        case none
        case moderate
        case severe
    }

    static func shouldUseHeatSafetyNarrative(
        profile: CoachPresentationActivityProfile,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guard profile.family == .heat else { return false }
        guard let minutes = profile.minutesUntil, minutes >= 0, minutes <= 180 else { return false }
        return hydrationRiskLevel(input: input, guidance: guidance) != .none
    }

    static func hydrationRiskLevel(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> HydrationRiskLevel {
        let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
        let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        let ratio = waterGoal > 0 ? water / waterGoal : 1

        if input.brain.hydration == .depleted || ratio < 0.10 || water <= 0.05 {
            return .severe
        }
        if ratio < 0.25 {
            return .moderate
        }
        if guidance.priority.limiter == .hydration, ratio < 0.50 {
            return .moderate
        }
        return .none
    }

    static func semanticColor(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachPresentationSemanticColor {
        hydrationRiskLevel(input: input, guidance: guidance) == .severe ? .red : .yellow
    }

    static func isWorkoutLanguage(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        guard !normalizedText.isEmpty else { return false }

        let markers = [
            "main workout", "главная тренировка", "основная тренировка",
            "prepare for training", "подготовка к тренировке", "подготовьтесь к тренировке",
            "training prep", "workout prep", "key session", "hard session",
            "strength", "endurance", "силов", "вынослив",
            "session is close", "тренировка близко", "тренировка идет", "тренировка идёт",
            "intensity", "интенсив", "нагрузк", "tempo", "pace to chase"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
    }

    static func heatSafeFallback(
        profile: CoachPresentationActivityProfile,
        surface: CoachPresentationSurface
    ) -> String {
        switch surface {
        case .todayInsight:
            return localized(
                english: "Sauna is recovery heat, not training.",
                russian: "Сауна — восстановление, а не тренировка."
            )
        case .coachInterpretation:
            return localized(
                english: "Keep heat moderate and hydration steady before sauna.",
                russian: "Перед сауной держите тепло умеренным и пополняйте воду."
            )
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}
