import Foundation
import SwiftUI

enum CoachTabPresentationIntent: String, Hashable {
    case statusAction
    case interpretation
}

struct CoachActivityContextChip: Hashable {
    let icon: String
    let label: String
}

struct CoachPresentationWhyRow: Hashable {
    let title: String
    let icon: String
    let color: Color
}

struct CoachPresentationActivityProfile: Hashable {
    enum Family: Hashable {
        case walk
        case cycling
        case strength
        case heat
        case stretching
        case yoga
        case mobility
        case breathing
        case other
    }

    let upcoming: PlannedActivity?
    let upNextTimelineActivity: PlannedActivity?
    let upNextTimelineIsVisible: Bool
    let family: Family
    let isRecoveryModality: Bool
    let minutesUntil: Int?
    let hasSeriousWorkoutPlanned: Bool
    let recoveryPercent: Int

    var allowsCyclingVocabulary: Bool {
        family == .cycling
    }

    var displayName: String {
        let title = upcoming?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? Self.localized(english: "activity", russian: "активность") : title
    }

    var isMorningWalkStartCandidate: Bool {
        guard isRecoveryModality, family == .walk else { return false }
        guard recoveryPercent > 80 else { return false }
        guard let minutesUntil, minutesUntil > 0, minutesUntil < 60 else { return false }
        return !hasSeriousWorkoutPlanned
    }

    static func resolve(input: CoachInputSnapshot, guidance: CoachGuidanceV3, story: CoachFinalStory) -> CoachPresentationActivityProfile {
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: input.plannedActivities,
            selectedDate: input.selectedDate,
            now: input.now
        )
        let upNextTimelineActivity = activityContext.activeActivity
            ?? activityContext.nextUpcomingActivity
            ?? activityContext.preparingActivity
        let upcoming = focusUpcomingActivity(input: input, guidance: guidance, story: story)
        let family = (upNextTimelineActivity ?? upcoming).map(family(for:)) ?? .other
        let isRecovery = (upNextTimelineActivity ?? upcoming).map(CoachLightRecoveryStableDayPolicy.isLightRecoveryModality) ?? false
        let timingActivity = upNextTimelineActivity ?? upcoming
        let minutesUntil = timingActivity.map { activity in
            max(0, Int((activity.date.timeIntervalSince(input.now) / 60).rounded()))
        }
        return CoachPresentationActivityProfile(
            upcoming: upcoming,
            upNextTimelineActivity: upNextTimelineActivity,
            upNextTimelineIsVisible: upNextTimelineActivity != nil,
            family: family,
            isRecoveryModality: isRecovery,
            minutesUntil: minutesUntil,
            hasSeriousWorkoutPlanned: hasSeriousWorkoutPlannedToday(input: input),
            recoveryPercent: input.recoveryContext.recoveryPercent
        )
    }

    private static func focusUpcomingActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        story: CoachFinalStory
    ) -> PlannedActivity? {
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: input.plannedActivities,
            selectedDate: input.selectedDate,
            now: input.now
        )

        if activityContext.activeActivity != nil,
           let next = activityContext.nextUpcomingActivity {
            return next
        }

        if let selected = story.decisionContext.selectedUpNext {
            return selected
        }
        if let activity = guidance.priority.activity,
           !activity.isCompleted,
           !activity.isSkipped,
           activity.date > input.now {
            return activity
        }
        return input.dayContext.upcomingActivities
            .filter { !$0.isCompleted && !$0.isSkipped && $0.date > input.now }
            .sorted { $0.date < $1.date }
            .first
    }

    private static func family(for activity: PlannedActivity) -> Family {
        let text = CoachActivityClassification.tokenText(for: activity)
        if CoachActivityClassification.isWalkLike(activity) { return .walk }
        if CoachActivityClassification.isHikeLike(activity) { return .walk }
        if text.contains("cycl") || text.contains("bike") || text.contains("ride") { return .cycling }
        if text.contains("stretch") { return .stretching }
        if text.contains("yoga") { return .yoga }
        if text.contains("mobility") { return .mobility }
        if text.contains("breath") { return .breathing }
        if CoachActivityContextResolverV3.kind(for: activity) == .heat ||
            text.contains("sauna") { return .heat }
        if CoachActivityClassification.isSignificantWorkout(activity) ||
            CoachActivityContextResolverV3.load(for: activity) == .high ||
            CoachActivityContextResolverV3.load(for: activity) == .extreme {
            return .strength
        }
        return .other
    }

    private static func hasSeriousWorkoutPlannedToday(input: CoachInputSnapshot) -> Bool {
        let calendar = Calendar.current
        return input.plannedActivities.contains { activity in
            guard calendar.isDate(activity.date, inSameDayAs: input.now) else { return false }
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            guard activity.date >= input.now else { return false }
            if CoachLightRecoveryStableDayPolicy.isLightRecoveryModality(activity) { return false }
            if CoachActivityClassification.isSignificantWorkout(activity) { return true }
            let load = CoachActivityContextResolverV3.load(for: activity)
            return load == .high || load == .extreme
        }
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}

/// V5 presentation contract: activity-bound stories defer visible Coach copy to the engine.
enum CoachPresentationNarrativeContract {

    static func defersVisibleCopyToEngine(
        story: CoachFinalStory,
        input: CoachInputSnapshot
    ) -> Bool {
        switch story.owner {
        case .activeActivity, .pacingExecution, .sustainableExecution,
             .fuelingDuringActivity, .hydrationExecution:
            return true
        case .postActivityRecovery, .recovery:
            return isSignificantEnduranceRecovery(story: story, input: input)
        case .activityPreparation, .readiness,
             .tomorrowProtection, .stableOverview, .hydration, .fuel:
            return false
        }
    }

    private static func isSignificantEnduranceRecovery(
        story: CoachFinalStory,
        input: CoachInputSnapshot
    ) -> Bool {
        if input.actualLoad.activeCalories >= 750 { return true }

        guard let activity = focusActivity(story: story, input: input) else {
            return false
        }

        let minutes = max(activity.effectiveDurationMinutes, activity.durationMinutes)
        if minutes >= 120 { return true }

        let text = "\(activity.title) \(activity.type)".lowercased()
        if (text.contains("tennis") || text.contains("squash") || text.contains("racket")) && minutes >= 60 {
            return true
        }

        let kind = CoachActivityContextResolverV3.kind(for: activity)
        return kind == .endurance && minutes >= 60
    }

    static func focusActivity(
        story: CoachFinalStory,
        input: CoachInputSnapshot
    ) -> PlannedActivity? {
        let context = CoachActivityContextResolverV3.resolveDayContext(
            activities: input.plannedActivities,
            selectedDate: input.selectedDate,
            now: input.now
        )

        if let active = context.activeActivity, !active.isCompleted {
            return active
        }

        if let recent = context.recentlyCompletedActivity {
            return recent
        }

        if let selected = story.decisionContext.selectedUpNext {
            return selected
        }

        return input.plannedActivities
            .filter { $0.isCompleted && Calendar.current.isDate($0.date, inSameDayAs: input.now) }
            .sorted { $0.date > $1.date }
            .first
    }
}

/// Contextual Coach-tab copy during live workouts — not tactical pacing (that lives on Today).
enum CoachActiveWorkoutPresentationCopy {

    static func headlineCandidates(
        input: CoachInputSnapshot,
        profile: CoachPresentationActivityProfile,
        guidance: CoachGuidanceV3
    ) -> [String] {
        if input.dayPriorityModel.tomorrowDemand == .hard {
            return [
                localized(
                    english: "Saving reserve matters more today",
                    russian: "Сегодня важнее сохранить запас на завтра"
                ),
                localized(
                    english: "Tomorrow still needs something left in the tank",
                    russian: "Завтра ещё понадобятся силы"
                )
            ]
        }
        if profile.recoveryPercent > 0 && profile.recoveryPercent < 70 {
            return [
                localized(
                    english: "Recovery allows you to continue — just without extra risk",
                    russian: "Восстановление позволяет продолжать, но без лишнего риска"
                ),
                localized(
                    english: "You can keep going — reserve matters more than pace",
                    russian: "Можно продолжать — запас важнее скорости"
                )
            ]
        }
        return [
            localized(
                english: "The workout is going fine — no need to push harder now",
                russian: "Тренировка идёт нормально — сейчас нет смысла ускоряться"
            ),
            localized(
                english: "Quality matters more than speed right now",
                russian: "Сейчас важнее качество, чем скорость"
            ),
            localized(
                english: "Nothing urgent needs fixing in this session",
                russian: "В этой тренировке ничего срочно не нужно менять"
            )
        ]
    }

    static func contextualRead(
        input: CoachInputSnapshot,
        profile: CoachPresentationActivityProfile,
        guidance: CoachGuidanceV3
    ) -> String {
        if input.dayPriorityModel.tomorrowDemand == .hard {
            return localized(
                english: "What you spend now can cost tomorrow's session more than it buys today.",
                russian: "То, что потратите сейчас, может дороже обойтись завтрашней тренировке."
            )
        }
        if profile.recoveryPercent > 0 && profile.recoveryPercent < 70 {
            return localized(
                english: "Recovery is not fully back, so the useful limit is effort you can repeat tomorrow.",
                russian: "Восстановление ещё не полное — полезный предел это нагрузка, которую можно повторить завтра."
            )
        }
        return localized(
            english: "The session is already doing its job — pushing harder now adds little and costs more.",
            russian: "Тренировка уже делает свою работу — ускоряться сейчас мало что даст и много заберёт."
        )
    }

    static func contextualRecommendation(
        input: CoachInputSnapshot,
        profile: CoachPresentationActivityProfile
    ) -> String {
        localized(
            english: "Keep reserve for the rest of today, not just this block.",
            russian: "Берегите запас на весь день, а не только на этот отрезок."
        )
    }

    static func containsTacticalPacingInstruction(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        guard !normalizedText.isEmpty else { return false }

        let markers = [
            "chase the numbers", "dont chase", "don't chase",
            "гонитесь", "цифр",
            "settle in", "adding effort", "держите темп", "легким", "добавляйте",
            "easy minutes", "few easy minutes", "first minutes", "первые минут",
            "start with 10", "10 minutes easy", "minutes easy",
            "pace you can hold", "comfortable pace", "stick with a pace",
            "give yourself a few easy", "keep the pace easy", "с первых минут",
            "control today's", "контролируйте тренировку", "спокойнее", "легче обычного"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
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

enum CoachPresentationSanitizer {

    static func contextChip(
        profile: CoachPresentationActivityProfile,
        input: CoachInputSnapshot
    ) -> CoachActivityContextChip? {
        guard let activity = profile.upcoming else { return nil }
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let icon = activityIcon(for: profile.family, fallback: activity.imageName.isEmpty ? "figure.walk" : activity.imageName)
        let timing = timingLabel(for: activity, now: input.now)
        let label = timing.isEmpty ? title : "\(title) • \(timing)"
        return CoachActivityContextChip(icon: icon, label: label)
    }

    static func sanitizeRecommendation(
        _ text: String,
        profile: CoachPresentationActivityProfile,
        scenario: CoachPresentationScenario,
        story: CoachFinalStory,
        guidance: CoachGuidanceV3,
        input: CoachInputSnapshot
    ) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if CoachPresentationNarrativeContract.defersVisibleCopyToEngine(story: story, input: input) {
            return trimmed
        }
        if scenario == .activeWorkout,
           trimmed.isEmpty || CoachActiveWorkoutPresentationCopy.containsTacticalPacingInstruction(trimmed) {
            return CoachActiveWorkoutPresentationCopy.contextualRecommendation(
                input: input,
                profile: profile
            )
        }
        guard !trimmed.isEmpty else { return trimmed }

        if profile.upNextTimelineIsVisible,
           CoachPresentationScheduleNarrativeGuard.isScheduleNarrative(trimmed, profile: profile) {
            return CoachPresentationScheduleNarrativeGuard.stateFocusedInsightMessage(
                story: story,
                guidance: guidance,
                profile: profile,
                input: input,
                scenario: scenario,
                surface: .coachInterpretation
            )
        }

        if scenario == .stableDayOwnership, containsForbiddenMorningPrepPhrases(trimmed) {
            return localized(
                english: "Keep today's rhythm steady",
                russian: "Сохраняйте обычный ритм"
            )
        }

        if profile.family == .heat || scenario == .heatSafetyPrep,
           CoachPresentationHeatSafetyGuard.isWorkoutLanguage(trimmed) {
            return CoachPresentationHeatSafetyGuard.heatSafeFallback(
                profile: profile,
                surface: .coachInterpretation
            )
        }

        if scenario == .morningWalkStart {
            return localized(
                english: "Take your walk as planned — that's enough to start the day.",
                russian: "Сходите на прогулку как запланировано — для начала дня этого достаточно."
            )
        }

        if scenario == .tomorrowProtection, containsRepeatedEveningSleepAdvice(trimmed) {
            return localized(
                english: "Wind down this evening and try to get to bed a little earlier.",
                russian: "Проведите вечер спокойно и постарайтесь лечь пораньше."
            )
        }

        if scenario == .sessionPrep, containsPrepActionOverlap(trimmed) {
            return localized(
                english: "Start easy and let the first minutes confirm how the body responds.",
                russian: "Начните легко и по первым минутам оцените самочувствие."
            )
        }

        if scenario == .postWorkoutRecovery,
           !CoachPresentationNarrativeContract.defersVisibleCopyToEngine(story: story, input: input),
           containsPostWorkoutActionOverlap(trimmed) {
            return localized(
                english: "Refuel and rehydrate, then keep the rest of the day easy.",
                russian: "Поешьте, попейте воды и держите остаток дня лёгким."
            )
        }

        if !profile.allowsCyclingVocabulary, containsCyclingVocabulary(trimmed) {
            return recoveryRecommendationFallback(profile: profile)
        }

        if profile.isRecoveryModality, containsTrainingHeroVocabulary(trimmed) {
            return recoveryRecommendationFallback(profile: profile)
        }

        if containsForbiddenRoboticPhrases(trimmed) {
            return recoveryRecommendationFallback(profile: profile)
        }

        return trimmed
    }

    static func sanitizeRead(
        _ text: String,
        profile: CoachPresentationActivityProfile,
        scenario: CoachPresentationScenario,
        story: CoachFinalStory,
        guidance: CoachGuidanceV3,
        input: CoachInputSnapshot
    ) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if CoachPresentationNarrativeContract.defersVisibleCopyToEngine(story: story, input: input) {
            return trimmed
        }
        if scenario == .activeWorkout, trimmed.isEmpty {
            return CoachActiveWorkoutPresentationCopy.contextualRead(
                input: input,
                profile: profile,
                guidance: guidance
            )
        }
        guard !trimmed.isEmpty else { return trimmed }

        if profile.upNextTimelineIsVisible,
           CoachPresentationScheduleNarrativeGuard.isScheduleNarrative(trimmed, profile: profile) {
            return CoachPresentationScheduleNarrativeGuard.stateFocusedInsightMessage(
                story: story,
                guidance: guidance,
                profile: profile,
                input: input,
                scenario: scenario,
                surface: .coachInterpretation
            )
        }

        if profile.family == .heat || scenario == .heatSafetyPrep,
           CoachPresentationHeatSafetyGuard.isWorkoutLanguage(trimmed) {
            return CoachPresentationHeatSafetyGuard.heatSafeFallback(
                profile: profile,
                surface: .coachInterpretation
            )
        }

        if scenario == .morningWalkStart {
            return localized(
                english: "You can ease into the day — no need to add load before the walk.",
                russian: "День можно начинать спокойно — до прогулки лишняя нагрузка не нужна."
            )
        }

        if scenario == .tomorrowProtection,
           containsVagueTomorrowProtectionEveningAdvice(trimmed) || containsRepeatedEveningSleepAdvice(trimmed) {
            let copy = CoachTomorrowProtectionActivityPhrase.eveningWhatMatters(
                loadAlreadyHigh: input.actualLoad.activeCalories >= 700
            )
            return localized(english: copy.english, russian: copy.russian)
        }

        if scenario == .activeWorkout,
           trimmed.isEmpty || CoachActiveWorkoutPresentationCopy.containsTacticalPacingInstruction(trimmed) {
            return CoachActiveWorkoutPresentationCopy.contextualRead(
                input: input,
                profile: profile,
                guidance: guidance
            )
        }

        if !profile.allowsCyclingVocabulary, containsCyclingVocabulary(trimmed) {
            return localized(
                english: "Keep the start of the day calm and unhurried.",
                russian: "Начните день спокойно, без спешки."
            )
        }

        if profile.isRecoveryModality, containsTrainingHeroVocabulary(trimmed) {
            return localized(
                english: "A light walk helps you ease into the day.",
                russian: "Небольшая прогулка поможет плавно войти в день."
            )
        }

        if containsForbiddenRoboticPhrases(trimmed) {
            return localized(
                english: "Recovery looks good — move at a normal, easy pace.",
                russian: "Восстановление хорошее — можно двигаться в обычном, спокойном режиме."
            )
        }

        return trimmed
    }

    static func sanitizeAvoid(
        _ text: String,
        profile: CoachPresentationActivityProfile
    ) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if !profile.allowsCyclingVocabulary, containsCyclingVocabulary(trimmed) {
            return localized(
                english: "Don't rush the pace before the walk.",
                russian: "Не форсируйте темп перед прогулкой."
            )
        }

        if containsForbiddenRoboticPhrases(trimmed) {
            return localized(
                english: "No need to add extra load right now.",
                russian: "Сейчас нет причины добавлять нагрузку."
            )
        }

        return trimmed
    }

    static func sanitizeWhyRows(
        _ rows: [CoachFinalStoryRenderedReason],
        profile: CoachPresentationActivityProfile
    ) -> [CoachPresentationWhyRow] {
        var seen = Set<String>()
        var result: [CoachPresentationWhyRow] = []

        for row in rows {
            guard let sanitized = sanitizeWhyRow(row.title, profile: profile) else { continue }
            let key = normalized(sanitized)
            guard seen.insert(key).inserted else { continue }
            result.append(
                CoachPresentationWhyRow(
                    title: sanitized,
                    icon: row.icon,
                    color: row.color
                )
            )
        }

        return Array(result.prefix(3))
    }

    static func resolveScenario(
        profile: CoachPresentationActivityProfile,
        story: CoachFinalStory,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachPresentationScenario {
        if CoachLightRecoveryStableDayPolicy.ownsStableDayAfterCompletedLightActivity(
            input: input,
            guidance: guidance
        ) {
            return .stableDayOwnership
        }
        let hour = Calendar.current.component(.hour, from: input.now)
        if profile.isMorningWalkStartCandidate, (5..<12).contains(hour) {
            return .morningWalkStart
        }
        if CoachPresentationHeatSafetyGuard.shouldUseHeatSafetyNarrative(
            profile: profile,
            input: input,
            guidance: guidance
        ) {
            return .heatSafetyPrep
        }
        if story.owner == .activeActivity || story.owner == .pacingExecution || story.owner == .sustainableExecution {
            return .activeWorkout
        }
        if story.owner == .postActivityRecovery || story.owner == .recovery {
            return .postWorkoutRecovery
        }
        if story.owner == .hydration || story.owner == .hydrationExecution,
           CoachPresentationNutritionGuard.nutritionShouldOwnInsight(
               story: story,
               guidance: guidance,
               profile: profile,
               input: input,
               scenario: .hydrationSupport
           ) {
            return .hydrationSupport
        }
        if story.owner == .fuel || story.owner == .fuelingDuringActivity,
           CoachPresentationNutritionGuard.nutritionShouldOwnInsight(
               story: story,
               guidance: guidance,
               profile: profile,
               input: input,
               scenario: .fuelSupport
           ) {
            return .fuelSupport
        }
        if story.owner == .tomorrowProtection {
            return .tomorrowProtection
        }
        if story.owner == .activityPreparation {
            return .sessionPrep
        }
        if (5..<12).contains(Calendar.current.component(.hour, from: input.now)),
           story.owner == .stableOverview || story.owner == .readiness {
            return .stableMorning
        }
        return .general
    }

    // MARK: - Private

    private static func sanitizeWhyRow(
        _ text: String,
        profile: CoachPresentationActivityProfile
    ) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if !profile.allowsCyclingVocabulary, containsCyclingVocabulary(trimmed) {
            return nil
        }

        if profile.isRecoveryModality, containsTrainingHeroVocabulary(trimmed) {
            return localized(
                english: "Good window for recovery support.",
                russian: "Хорошее окно для восстановления."
            )
        }

        if profile.family == .heat, CoachPresentationHeatSafetyGuard.isWorkoutLanguage(trimmed) {
            return nil
        }

        if containsForbiddenRoboticPhrases(trimmed) {
            return nil
        }

        return trimmed
    }

    private static func recoveryRecommendationFallback(profile: CoachPresentationActivityProfile) -> String {
        if profile.family == .walk {
            return localized(
                english: "Take your walk as planned and keep the pace easy.",
                russian: "Сходите на прогулку как запланировано и держите темп лёгким."
            )
        }
        return localized(
            english: "Start calmly, without pushing the pace.",
            russian: "Начните спокойно, без резкого темпа."
        )
    }

    private static func containsVagueTomorrowProtectionEveningAdvice(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        let markers = [
            "don't add anything extra",
            "recovery comes first tonight",
            "nothing extra",
            "ничего не добавлять",
            "вечером лучше ничего"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
    }

    private static func containsRepeatedEveningSleepAdvice(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        let markers = [
            "sleep is the useful lever",
            "aim for 7 8 hours sleep",
            "make tonight the main recovery",
            "the main job now is not to add more load",
            "главное выспаться",
            "главная задача",
            "не добирать нагрузку",
            "выспаться",
            "сегодня ночью",
            "keep the rest of today quiet",
            "проведите остаток дня спокойно",
            "сделайте вечер спокойным и ложитесь",
            "не превращайте вечер"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
    }

    private static func containsPrepActionOverlap(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        let markers = [
            "begin calmly",
            "confirm the pace",
            "start easy and let your body",
            "начните спокойно",
            "задайте темп",
            "первые минуты"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
    }

    private static func containsPostWorkoutActionOverlap(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        let markers = [
            "food water and an easy evening",
            "easy evening matter",
            "еда вода и спокойный вечер",
            "give your body time to start recovering",
            "дайте телу начать восстановление"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
    }

    private static func containsCyclingVocabulary(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        let markers = [
            "поезжайте", "поездайте", "поездка", "поездку", "поездке",
            "ride", "cycling", "cycle", "pedal", "крутить", "педал"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
    }

    private static func containsTrainingHeroVocabulary(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        let markers = [
            "главная тренировка", "main workout", "key session", "biggest training",
            "hardest workout", "самая тяжелая", "serious session", "hard session"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
    }

    private static func containsForbiddenMorningPrepPhrases(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        let markers = [
            "поесть пока день не разогнался",
            "завтрака для старта",
            "пока день не разогнался",
            "перед тренировкой",
            "следующая тренировка еще впереди",
            "eat something before the day builds",
            "simple breakfast is enough",
            "before the day gets busy"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
    }

    private static func containsForbiddenRoboticPhrases(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        let markers = [
            "запас энергии к сессии",
            "следующая тренировка еще впереди",
            "нагрузку лучше не добавлять только ради цифры",
            "самочувствие нормальное можно спокойно продолжать",
            "energy for the session is not fully",
            "your next session is still ahead"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
    }

    private static func activityIcon(for family: CoachPresentationActivityProfile.Family, fallback: String) -> String {
        switch family {
        case .walk: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .strength: return "dumbbell.fill"
        case .heat: return "flame.fill"
        case .stretching: return "figure.cooldown"
        case .yoga: return "figure.yoga"
        case .mobility: return "figure.cooldown"
        case .breathing: return "wind"
        case .other: return fallback
        }
    }

    private static func timingLabel(for activity: PlannedActivity, now: Date) -> String {
        let minutes = max(0, Int((activity.date.timeIntervalSince(now) / 60).rounded()))
        if minutes <= 0 { return "" }

        let calendar = Calendar.current
        if calendar.isDate(activity.date, inSameDayAs: now), minutes < 180 {
            if minutes < 60 {
                return localized(english: "in \(minutes) min", russian: "через \(minutes) мин")
            }
            let hours = minutes / 60
            let rem = minutes % 60
            if rem == 0 {
                return localized(english: "in \(hours) h", russian: "через \(hours) ч")
            }
            return localized(english: "in \(hours) h \(rem) min", russian: "через \(hours) ч \(rem) мин")
        }

        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: activity.date)
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

enum CoachPresentationScenario: Hashable {
    case general
    case stableDayOwnership
    case stableMorning
    case morningWalkStart
    case sessionPrep
    case activeWorkout
    case postWorkoutRecovery
    case hydrationSupport
    case fuelSupport
    case tomorrowProtection
    case heatSafetyPrep
}

enum CoachPresentationSurface: Hashable {
    case todayInsight
    case coachInterpretation
}

enum CoachPresentationScheduleNarrativeGuard {

    static func isScheduleNarrative(_ text: String, profile: CoachPresentationActivityProfile) -> Bool {
        let normalizedText = normalized(text)
        guard !normalizedText.isEmpty else { return false }

        let markers = [
            "следующая активность", "next activity",
            "позже сегодня", "later today",
            "далее по плану", "next up", "по плану начинается",
            "тренировка позже", "тренировка близко", "session is close",
            "prepare calmly", "готовимся спокойно",
            "prepare for training", "подготовка к тренировке",
            "starts in", "начинается через", "начнется через",
            "главная тренировка", "main workout", "основная тренировка"
        ]
        if markers.contains(where: { normalizedText.contains(normalized($0)) }) {
            return true
        }

        if normalizedText.contains("через") &&
            (normalizedText.contains("мин") || normalizedText.contains("ч") || normalizedText.contains(" h")) {
            return true
        }

        for activity in [profile.upNextTimelineActivity, profile.upcoming].compactMap({ $0 }) {
            let name = normalized(activity.title)
            guard !name.isEmpty else { continue }
            if normalizedText.contains(name) {
                return true
            }
        }

        return false
    }

    static func isStatusCalendarNarrative(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        guard !normalizedText.isEmpty else { return false }

        let markers = [
            "session in progress", "сессия идет", "тренировка идет", "тренировка идёт",
            "activity is running", "активность выполняется",
            "on track", "всё по плану", "все по плану",
            "everything is fine", "everything is on plan",
            "the day is on plan", "день идет по плану", "день идёт по плану",
            "ready for the day", "готов к дню",
            "prepare for training", "подготовка к тренировке",
            "unfolding on plan", "развивается по плану"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
    }

    static func isWeakReadinessStatus(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        let markers = [
            "organism is ready", "организм готов",
            "ready for normal activity", "готов к обычной активности",
            "the day is unfolding", "день развивается"
        ]
        return markers.contains { normalizedText.contains(normalized($0)) }
    }

    static func activityCountdown(for profile: CoachPresentationActivityProfile) -> String? {
        guard let minutes = profile.minutesUntil, minutes > 0, minutes <= 180 else { return nil }
        if minutes < 60 {
            return localized(
                english: "Next activity in \(minutes) min.",
                russian: "Следующая активность через \(minutes) мин."
            )
        }
        let hours = minutes / 60
        return localized(
            english: "Next activity in \(hours) h.",
            russian: "Следующая активность через \(hours) ч."
        )
    }

    static func scheduleDescription(
        for profile: CoachPresentationActivityProfile,
        input: CoachInputSnapshot
    ) -> String? {
        guard let activity = profile.upNextTimelineActivity else { return nil }
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: activity.date)
        return "\(title) \(time)"
    }

    static func stateFocusedInsightMessage(
        story: CoachFinalStory,
        guidance: CoachGuidanceV3,
        profile: CoachPresentationActivityProfile,
        input: CoachInputSnapshot,
        scenario: CoachPresentationScenario,
        surface: CoachPresentationSurface = .todayInsight
    ) -> String {
        if CoachPresentationNutritionGuard.nutritionShouldOwnInsight(
            story: story,
            guidance: guidance,
            profile: profile,
            input: input,
            scenario: scenario
        ) {
            let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
            let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
            let calorieGoal = input.brain.baseDayGoals.calories
            let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters

            if guidance.priority.limiter == .fueling || scenario == .fuelSupport {
                return localized(english: "Energy needs a top-up.", russian: "Силы стоит подпитать.")
            }
            if guidance.priority.limiter == .hydration || scenario == .hydrationSupport {
                return localized(english: "Fluids need attention.", russian: "Сейчас важнее всего вода.")
            }
            if calories <= 0 || (calorieGoal > 0 && calories / calorieGoal < 0.15) {
                return localized(english: "Energy needs a top-up.", russian: "Силы стоит подпитать.")
            }
            if water <= 0.05 || (waterGoal > 0 && water / waterGoal < 0.20) {
                return localized(english: "Fluids need attention.", russian: "Сейчас важнее всего вода.")
            }
        }

        switch scenario {
        case .stableDayOwnership:
            return surface == .todayInsight
                ? localized(english: "No overload signs so far.", russian: "Без признаков перегрузки.")
                : localized(
                    english: "The day is unfolding without overload signs.",
                    russian: "День развивается по плану, без признаков перегрузки."
                )
        case .fuelSupport:
            return localized(english: "Energy needs a top-up.", russian: "Силы стоит подпитать.")
        case .hydrationSupport:
            return localized(english: "Fluids need attention.", russian: "Сейчас важнее всего вода.")
        case .postWorkoutRecovery:
            return localized(english: "Recovery should lead right now.", russian: "Сейчас важнее восстановление.")
        case .heatSafetyPrep:
            return localized(
                english: "Hydration supports heat recovery.",
                russian: "Вода помогает перенести тепло безопаснее."
            )
        default:
            break
        }

        if profile.recoveryPercent >= 85 {
            return surface == .todayInsight
                ? localized(english: "Recovery remains strong.", russian: "Восстановление остаётся высоким.")
                : localized(
                    english: "Recovery remains strong even after this morning's work.",
                    russian: "Восстановление остаётся сильным даже после утренней активности."
                )
        }
        if profile.recoveryPercent >= 75 {
            return surface == .todayInsight
                ? localized(english: "Keep a normal rhythm.", russian: "Держите обычный ритм.")
                : localized(
                    english: "You can keep a normal rhythm for now.",
                    russian: "Можно спокойно держать обычный ритм."
                )
        }

        switch story.owner {
        case .readiness, .stableOverview:
            return localized(english: "Keep the day steady.", russian: "Держите день ровным.")
        case .recovery, .postActivityRecovery:
            return localized(english: "Recovery should lead right now.", russian: "Сейчас важнее восстановление.")
        default:
            return localized(english: "No rush today.", russian: "Сегодня без спешки.")
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

enum CoachPresentationIntentGuard {

    static func sharesSemanticIntent(today: CoachTodayPresentation, coach: CoachScreenPresentation) -> Bool {
        let todayTokens = semanticTokens([today.title, today.message])
        let coachTokens = semanticTokens([coach.title, coach.message, coach.recommendation])
        guard !todayTokens.isEmpty, !coachTokens.isEmpty else { return false }

        let overlap = todayTokens.intersection(coachTokens)
        let ratio = Double(overlap.count) / Double(min(todayTokens.count, coachTokens.count))
        if ratio >= 0.55 { return true }

        let todayNorm = normalized(today.title + " " + today.message)
        let coachHeadlineNorm = normalized(coach.title + " " + coach.message)
        let coachSurfaceNorm = normalized(coach.title + " " + coach.message + " " + coach.recommendation)
        let todayPacing = CoachActiveWorkoutPresentationCopy.containsTacticalPacingInstruction(todayNorm)
        let coachPacing = CoachActiveWorkoutPresentationCopy.containsTacticalPacingInstruction(coachSurfaceNorm)
        if todayPacing && coachPacing { return true }

        if todayNorm == coachHeadlineNorm { return true }

        let statusMarkers = ["идет", "in progress", "session in progress", "сессия идет", "live"]
        let todayStatus = statusMarkers.contains { todayNorm.contains(normalized($0)) }
        let coachStatus = statusMarkers.contains { coachHeadlineNorm.contains(normalized($0)) }
        return todayStatus && coachStatus
    }

    private static func semanticTokens(_ parts: [String]) -> Set<String> {
        Set(
            parts
                .flatMap { normalized($0).split(separator: " ").map(String.init) }
                .filter { $0.count >= 4 }
        )
    }

    private static func normalized(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
