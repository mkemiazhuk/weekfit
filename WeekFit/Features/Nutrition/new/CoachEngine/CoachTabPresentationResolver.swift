import Foundation
import SwiftUI

/// Splits visible copy between Today (compressed teaser) and Coach (interpretation + reasons).
enum CoachTabPresentationResolver {

    static func resolveToday(
        story: CoachFinalStory,
        guidance: CoachGuidanceV3,
        input: CoachInputSnapshot
    ) -> CoachTodayPresentation {
        let profile = CoachPresentationActivityProfile.resolve(input: input, guidance: guidance, story: story)
        let scenario = CoachPresentationSanitizer.resolveScenario(
            profile: profile,
            story: story,
            input: input,
            guidance: guidance
        )
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let teaser = CoachTodayTeaserBuilder.build(
            story: story,
            guidance: guidance,
            profile: profile,
            scenario: scenario,
            renderModel: renderModel,
            input: input
        )

        return CoachTodayPresentation(
            intent: .statusAction,
            statusLabel: renderModel.badge,
            title: conciseLine(teaser.idea, maxLength: 44),
            message: conciseLine(teaser.action, maxLength: 88),
            icon: story.icon,
            color: teaser.semanticColor.color
        )
    }

    static func resolveCoach(
        story: CoachFinalStory,
        guidance: CoachGuidanceV3,
        input: CoachInputSnapshot
    ) -> CoachScreenPresentation {
        let profile = CoachPresentationActivityProfile.resolve(input: input, guidance: guidance, story: story)
        let scenario = CoachPresentationSanitizer.resolveScenario(
            profile: profile,
            story: story,
            input: input,
            guidance: guidance
        )
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let today = resolveToday(story: story, guidance: guidance, input: input)
        let title = resolveCoachHeadline(
            story: story,
            profile: profile,
            scenario: scenario,
            guidance: guidance,
            input: input,
            renderModel: renderModel,
            avoiding: [today.title, today.message]
        )
        let rawRead = renderModel.whatMattersNow.isEmpty
            ? (renderModel.displaySubtitle.isEmpty ? renderModel.subtitle : renderModel.displaySubtitle)
            : renderModel.whatMattersNow
        let message = CoachPresentationSanitizer.sanitizeRead(
            rawRead,
            profile: profile,
            scenario: scenario,
            story: story,
            guidance: guidance,
            input: input
        )
        let recommendation = CoachPresentationSanitizer.sanitizeRecommendation(
            renderModel.primaryRecommendation,
            profile: profile,
            scenario: scenario,
            story: story,
            guidance: guidance,
            input: input
        )
        let avoidRaw = renderModel.displayAvoid.isEmpty
            ? renderModel.avoidRecommendation
            : renderModel.displayAvoid
        let avoid = CoachPresentationSanitizer.sanitizeAvoid(avoidRaw, profile: profile)
        let whyRows = CoachPresentationSanitizer.sanitizeWhyRows(renderModel.whyRows, profile: profile)
        let contextChip = CoachPresentationSanitizer.contextChip(profile: profile, input: input)

        return CoachScreenPresentation(
            intent: .interpretation,
            stateLabel: story.badgeState.resolved,
            title: title,
            message: message,
            recommendation: recommendation,
            icon: story.icon,
            color: today.color,
            contextChip: contextChip,
            whyRows: whyRows,
            supportActions: story.supportActions,
            avoidNotes: avoid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [avoid]
        )
    }

    // MARK: - Coach

    private static func resolveCoachHeadline(
        story: CoachFinalStory,
        profile: CoachPresentationActivityProfile,
        scenario: CoachPresentationScenario,
        guidance: CoachGuidanceV3,
        input: CoachInputSnapshot,
        renderModel: CoachFinalStoryRenderModel,
        avoiding: [String]
    ) -> String {
        if CoachPresentationNarrativeContract.defersVisibleCopyToEngine(story: story, input: input) {
            let engineTitle = renderModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !engineTitle.isEmpty {
                return engineTitle
            }
            return story.title.resolved
        }

        let candidates: [String]
        switch scenario {
        case .stableDayOwnership:
            candidates = [
                localized(english: "Nothing needs fixing", russian: "Ничего исправлять не нужно"),
                localized(english: "The day is unfolding smoothly", russian: "Сегодня всё идёт спокойно"),
                localized(english: "Recovery looks solid", russian: "Восстановление выглядит неплохо")
            ]
        case .morningWalkStart:
            candidates = [
                localized(english: "Good start to the day", russian: "Хорошее начало дня"),
                localized(english: "You can ease into the day", russian: "День можно начинать спокойно")
            ]
        case .stableMorning:
            if profile.isRecoveryModality {
                candidates = [
                    localized(english: "Good moment for light movement", russian: "Хороший момент для лёгкого движения"),
                    localized(english: "The day is unfolding smoothly", russian: "Сегодня всё идёт спокойно")
                ]
            } else {
                candidates = [
                    localized(english: "You are ready for a normal day", russian: "Сегодня можно двигаться в обычном режиме"),
                    localized(english: "The day is unfolding smoothly", russian: "Сегодня всё идёт спокойно")
                ]
            }
        case .sessionPrep:
            if profile.family == .heat {
                candidates = [
                    localized(english: "Good moment for recovery", russian: "Хороший момент для восстановления"),
                    localized(english: "Keep the rest of the day easy", russian: "Остаток дня лучше провести спокойно")
                ]
            } else if profile.isRecoveryModality {
                candidates = [
                    localized(english: "No need to rush the start", russian: "Сейчас нет смысла спешить"),
                    localized(english: "You can move without rushing", russian: "Сейчас можно двигаться без спешки")
                ]
            } else if CoachPresentationNutritionGuard.shouldSurfaceFuelPrep(
                profile: profile,
                input: input,
                guidance: guidance
            ) {
                candidates = [
                    localized(english: "A little fuel now will help later", russian: "Перед нагрузкой лучше немного подкрепиться"),
                    localized(english: "There is time to prepare properly", russian: "Сейчас хорошее время спокойно подготовиться")
                ]
            } else {
                candidates = [
                    localized(english: "You can move without rushing", russian: "Сейчас можно двигаться без спешки"),
                    localized(english: "Start easy and build gradually", russian: "Начните спокойно и постепенно добавляйте")
                ]
            }
        case .activeWorkout:
            if guidance.priority.strength == .critical &&
                (guidance.priority.limiter == .trainingReadiness ||
                 guidance.priority.focus == .trainingReadinessWarning) {
                candidates = [
                    localized(english: "This is not the day to push.", russian: "Сегодня лучше не загонять себя"),
                    localized(english: "Keep the rest of the day easy", russian: "Остаток дня лучше провести спокойно")
                ]
            } else if profile.family == .heat {
                candidates = [
                    localized(english: "Keep the heat moderate", russian: "С теплом лучше без перегиба"),
                    localized(english: "Let recovery lead right now", russian: "Сейчас лучше дать восстановлению вести")
                ]
            } else {
                candidates = CoachActiveWorkoutPresentationCopy.headlineCandidates(
                    input: input,
                    profile: profile,
                    guidance: guidance
                )
            }
        case .postWorkoutRecovery:
            candidates = [
                localized(english: "You can move without rushing", russian: "Сейчас можно двигаться без спешки"),
                localized(english: "Recovery should lead the rest of today", russian: "Дальше важнее восстановление")
            ]
        case .tomorrowProtection:
            candidates = [
                localized(english: "Tonight sets up tomorrow", russian: "Сегодня вечером закладывается завтра"),
                localized(english: "Protect what comes next", russian: "Сохраните силы на завтра")
            ]
        case .hydrationSupport:
            candidates = [
                localized(english: "Do not fall behind on fluids", russian: "С водой сейчас лучше не затягивать"),
                localized(english: "Everything feels harder when fluids are low", russian: "Без воды дальше будет тяжелее")
            ]
        case .fuelSupport:
            candidates = [
                localized(english: "A little food would help right now", russian: "Немного еды сейчас будет кстати"),
                localized(english: "Running on empty will catch up with you", russian: "На пустом баке далеко не уедешь")
            ]
        case .heatSafetyPrep:
            if CoachPresentationHeatSafetyGuard.hydrationRiskLevel(input: input, guidance: guidance) == .severe {
                candidates = [
                    localized(english: "Water comes first before heat", russian: "Перед сауной сначала разберитесь с водой"),
                    localized(english: "Low fluids make heat harder", russian: "С малым количеством воды жара даётся тяжелее")
                ]
            } else {
                candidates = [
                    localized(english: "Top up water before sauna", russian: "Перед сауной спокойно доберите воду"),
                    localized(english: "Sauna is recovery heat, not training", russian: "Сауна — восстановление, а не тренировка")
                ]
            }
        case .general:
            candidates = generalHeadlineCandidates(
                story: story,
                profile: profile,
                input: input,
                guidance: guidance
            )
        }

        let eligible = candidates.filter { candidate in
            !CoachPresentationScheduleNarrativeGuard.isScheduleNarrative(candidate, profile: profile) &&
            !CoachPresentationScheduleNarrativeGuard.isStatusCalendarNarrative(candidate) &&
            !(profile.upNextTimelineIsVisible && CoachPresentationScheduleNarrativeGuard.isWeakReadinessStatus(candidate))
        }

        let blocked = Set(avoiding.map(normalizedCopy).filter { !$0.isEmpty })
        if let chosen = eligible.first(where: { !blocked.contains(normalizedCopy($0)) }) {
            return chosen
        }
        if let fallback = eligible.first {
            return fallback
        }
        if scenario == .activeWorkout {
            let contextual = CoachActiveWorkoutPresentationCopy.headlineCandidates(
                input: input,
                profile: profile,
                guidance: guidance
            )
            return contextual.first(where: { !blocked.contains(normalizedCopy($0)) })
                ?? contextual.first
                ?? story.title.resolved
        }
        return story.title.resolved
    }

    private static func generalHeadlineCandidates(
        story: CoachFinalStory,
        profile: CoachPresentationActivityProfile,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> [String] {
        switch story.owner {
        case .stableOverview, .readiness:
            if profile.recoveryPercent >= 75 {
                return [
                    localized(english: "You are ready for a normal day", russian: "Сегодня можно двигаться в обычном режиме"),
                    localized(english: "The day is unfolding smoothly", russian: "Сегодня всё идёт спокойно")
                ]
            }
            return [
                localized(english: "You can move without rushing", russian: "Сейчас можно двигаться без спешки"),
                localized(english: "The day is unfolding smoothly", russian: "Сегодня всё идёт спокойно")
            ]
        case .activityPreparation:
            return [
                localized(english: "You are ready for a normal day", russian: "Сегодня можно двигаться в обычном режиме"),
                localized(english: "You can move without rushing", russian: "Сейчас можно двигаться без спешки")
            ]
        case .recovery, .postActivityRecovery:
            return [
                localized(english: "You can move without rushing", russian: "Сейчас можно двигаться без спешки"),
                localized(english: "Recovery should lead the rest of today", russian: "Дальше важнее восстановление")
            ]
        case .activeActivity, .pacingExecution, .sustainableExecution:
            if story.title.resolved.localizedCaseInsensitiveContains("would not continue") ||
                story.title.resolved.localizedCaseInsensitiveContains("лучше не продолжать") {
                return [
                    localized(english: "This is not the day to push.", russian: "Сегодня лучше не загонять себя"),
                    localized(english: "Keep the rest of the day easy", russian: "Остаток дня лучше провести спокойно")
                ]
            }
            return CoachActiveWorkoutPresentationCopy.headlineCandidates(
                input: input,
                profile: profile,
                guidance: guidance
            )
        case .tomorrowProtection:
            return [
                localized(english: "Tonight sets up tomorrow", russian: "Сегодня вечером закладывается завтра"),
                localized(english: "Protect what comes next", russian: "Сохраните силы на завтра")
            ]
        case .hydration, .hydrationExecution:
            return [
                localized(english: "Do not fall behind on fluids", russian: "С водой сейчас лучше не затягивать"),
                localized(english: "Everything feels harder when fluids are low", russian: "Без воды дальше будет тяжелее")
            ]
        case .fuel, .fuelingDuringActivity:
            return [
                localized(english: "A little food would help right now", russian: "Немного еды сейчас будет кстати"),
                localized(english: "Running on empty will catch up with you", russian: "На пустом баке далеко не уедешь")
            ]
        }
    }

    // MARK: - Helpers

    private static func looksLikeCoachInterpretationHeadline(_ text: String) -> Bool {
        let normalized = normalizedCopy(text)
        let interpretationMarkers = [
            "organism", "организм",
            "unfolding on plan", "развивается по плану",
            "without rushing", "без спешки",
            "light activity", "легкой активности",
            "window for", "окно для",
            "good start", "начало дня"
        ]
        return interpretationMarkers.contains { normalized.contains(normalizedCopy($0)) }
    }

    private static func containsCyclingVocabulary(_ text: String, profile: CoachPresentationActivityProfile) -> Bool {
        guard !profile.allowsCyclingVocabulary else { return false }
        let normalized = normalizedCopy(text)
        let markers = ["поезжайте", "поездайте", "поездка", "ride", "cycling", "pedal", "крутить"]
        return markers.contains { normalized.contains(normalizedCopy($0)) }
    }

    private static func containsTrainingHeroVocabulary(_ text: String, profile: CoachPresentationActivityProfile) -> Bool {
        guard profile.isRecoveryModality else { return false }
        let normalized = normalizedCopy(text)
        let markers = ["главная тренировка", "main workout", "key session", "hardest workout"]
        return markers.contains { normalized.contains(normalizedCopy($0)) }
    }

    private static func conciseLine(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func normalizedCopy(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func localizedPriorityText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let runtime = WeekFitCoachRuntimeLocalizedString(trimmed)
        if runtime != trimmed {
            return runtime
        }

        guard WeekFitCurrentLocale().identifier.hasPrefix("ru"),
              trimmed.range(of: "[A-Za-z]", options: .regularExpression) != nil else {
            return trimmed
        }

        switch trimmed.lowercased() {
        case "on track":
            return "Всё по плану"
        case "protect tonight":
            return "Берегите сон"
        case "fuel before training":
            return "Перед тренировкой лучше немного подкрепиться"
        case "bring fluids up":
            return "Доберите воду"
        case "ready to train":
            return "Можно спокойно тренироваться"
        case "stay steady":
            return "Держите ровный ритм"
        case "let recovery lead":
            return "Важнее восстановление"
        case "protect tomorrow":
            return "Сохраните силы на завтра"
        case "no urgent move needed.":
            return "Срочных действий нет."
        case "keep the evening calm.":
            return "Вечер лучше спокойный."
        case "start easy.":
            return "Начните спокойно."
        case "keep effort smooth.":
            return "Держите темп ровно."
        case "keep the day simple":
            return "Не усложняйте день"
        case "nothing needs fixing.":
            return "Ничего исправлять не нужно"
        case "the day is on plan":
            return "День идёт по плану"
        case "protect the work already done.":
            return "Сохраните уже сделанное"
        case "recovery day is on track":
            return "День восстановления идёт по плану"
        case "build the day gradually.":
            return "Добавляйте нагрузку постепенно"
        case "keep the rest easy.":
            return "Дальше лучше спокойно"
        default:
            return trimmed
        }
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}
