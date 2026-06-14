import Foundation
import SwiftUI

enum CoachFinalStoryOwner: String, Hashable {
    case activeActivity
    case activityPreparation
    case postActivityRecovery
    case recovery
    case readiness
    case tomorrowProtection
    case stableOverview
    case hydration
    case fuel
}

enum CoachFinalStoryColorFamily: String, Hashable {
    case stable
    case ready
    case recovery
    case activity
    case hydration
    case fuel
    case warning
    case stress
    case live

    var color: Color {
        switch self {
        case .stable:
            return Color(red: 0.42, green: 0.52, blue: 0.66)
        case .ready:
            return CoachPalette.stable
        case .recovery:
            return CoachPalette.recovery
        case .activity:
            return CoachPalette.activity
        case .hydration:
            return CoachPalette.hydration
        case .fuel:
            return CoachPalette.fueling
        case .warning:
            return CoachPalette.warning
        case .stress:
            return CoachPalette.stress
        case .live:
            return CoachPalette.activity
        }
    }
}

enum CoachFinalStoryDataReadinessState: String, Hashable {
    case coherent
    case settling
}

struct CoachFinalStoryReadinessAssessment {
    let allowed: Bool
    let dataReadinessState: CoachFinalStoryDataReadinessState
    let satisfiedConditions: [String]
    let blockingReasons: [String]

    var summary: String {
        [
            "allowed=\(allowed)",
            "state=\(dataReadinessState.rawValue)",
            "satisfied=\(satisfiedConditions.joined(separator: ","))",
            "blocked=\(blockingReasons.joined(separator: ","))"
        ].joined(separator: " ")
    }
}

struct CoachFinalStoryText: Hashable {
    let key: String
    let fallback: String
    let russianFallback: String
    let parameters: [String]
    let russianParameters: [String]

    var resolved: String {
        if key.hasPrefix("coach.") || key.hasPrefix("common.") || key.hasPrefix("today.") {
            let localized = WeekFitLocalizedString(key)
            if localized != key {
                return String(
                    format: localized,
                    arguments: WeekFitCurrentLocale().identifier.hasPrefix("ru")
                        ? russianParameters.map { $0 as CVarArg }
                        : parameters.map { $0 as CVarArg }
                )
            }
        }

        let runtime = WeekFitCoachRuntimeLocalizedString(fallback)
        if runtime != fallback || !WeekFitCurrentLocale().identifier.hasPrefix("ru") {
            return runtime
        }

        return russianFallback
    }
}

struct CoachFinalStoryAction: Hashable {
    let title: CoachFinalStoryText
    let icon: String
}

struct CoachFinalStorySupportSignal: Hashable {
    enum Kind: String, Hashable {
        case hydration
        case fuel
        case recovery
        case sleep
        case activity
    }

    let kind: Kind
    let title: CoachFinalStoryText
    let icon: String
}

struct CoachFinalStoryUpNextContext: Hashable {
    let activityID: String?
    let title: String?
}

struct CoachFinalStory {
    let owner: CoachFinalStoryOwner
    let primaryFocus: CoachDayFocus
    let titleKey: String
    let subtitleKey: String
    let badgeState: CoachFinalStoryText
    let heroState: CoachFinalStoryText
    let colorFamily: CoachFinalStoryColorFamily
    let icon: String
    let primaryRecommendationKey: String
    let avoidRecommendationKey: String
    let title: CoachFinalStoryText
    let subtitle: CoachFinalStoryText
    let primaryRecommendation: CoachFinalStoryText
    let avoidRecommendation: CoachFinalStoryText
    let whatHappened: CoachFinalStoryText
    let whatMattersNow: CoachFinalStoryText
    let whatToDoNext: CoachFinalStoryText
    let whatToAvoid: CoachFinalStoryText
    let supportSignals: [CoachFinalStorySupportSignal]
    let upNextContext: CoachFinalStoryUpNextContext?
    let confidence: Double
    let dataReadinessState: CoachFinalStoryDataReadinessState
    let primaryAction: CoachFinalStoryAction
    let supportActions: [CoachSupportActionV3]

    var color: Color { colorFamily.color }

    func validateVisibleContract(file: StaticString = #file, line: UInt = #line) {
        #if DEBUG
        if owner == .hydration {
            assert(colorFamily == .hydration || colorFamily == .warning, "Hydration story must use hydration or warning color.", file: file, line: line)
        }
        if owner == .fuel {
            assert(colorFamily == .fuel || colorFamily == .warning, "Fuel story must use fuel or warning color.", file: file, line: line)
        }
        if owner == .recovery || owner == .postActivityRecovery {
            assert(colorFamily == .recovery || colorFamily == .warning, "Recovery story must use recovery or warning color.", file: file, line: line)
        }
        if owner == .activeActivity {
            assert(
                colorFamily == .live || colorFamily == .activity || colorFamily == .warning || colorFamily == .stress || colorFamily == .recovery,
                "Active activity story must use a semantic active-session color.",
                file: file,
                line: line
            )
        }
        #endif
    }
}

struct CoachTodayPresentation {
    let title: String
    let message: String
    let icon: String
    let color: Color
}

struct CoachScreenPresentation {
    let stateLabel: String
    let title: String
    let message: String
    let recommendation: String
    let icon: String
    let color: Color
    let supportActions: [CoachSupportActionV3]
    let avoidNotes: [String]
}

struct CoachRationalePresentation {
    let title: String
    let message: String
    let icon: String
    let color: Color
    let sourceActivityID: String
}

enum CoachStateStatus: Equatable {
    case ready
    case refreshingPrevious
    case unavailable(reason: String)
    case invalid(reason: String)
}

struct CoachState: Identifiable {
    let id: UUID
    let createdAt: Date
    let status: CoachStateStatus
    let input: CoachInputSnapshot?
    let fingerprint: CoachInputFingerprint?
    let guidance: CoachGuidanceV3?
    let finalStory: CoachFinalStory?
    let todayPresentation: CoachTodayPresentation
    let coachPresentation: CoachScreenPresentation?
    let rationalePresentation: CoachRationalePresentation?

    var hasValidGuidance: Bool {
        guidance != nil && coachPresentation != nil && finalStory != nil
    }

    static func unavailable(reason: String, createdAt: Date = Date()) -> CoachState {
        CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .unavailable(reason: reason),
            input: nil,
            fingerprint: nil,
            guidance: nil,
            finalStory: nil,
            todayPresentation: CoachTodayPresentation(
                title: WeekFitLocalizedString("coach.unavailable.title"),
                message: WeekFitLocalizedString("coach.unavailable.message"),
                icon: "sparkles",
                color: WeekFitTheme.secondaryText
            ),
            coachPresentation: nil,
            rationalePresentation: nil
        )
    }

    static func settling(reason: String, createdAt: Date = Date()) -> CoachState {
        CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .unavailable(reason: reason),
            input: nil,
            fingerprint: nil,
            guidance: nil,
            finalStory: nil,
            todayPresentation: CoachTodayPresentation(
                title: CoachState.localized(english: "Coach is settling", russian: "Коуч обновляется"),
                message: CoachState.localized(english: "Waiting for recovery, sleep, and activity data.", russian: "Ждем данные восстановления, сна и активности."),
                icon: "hourglass",
                color: WeekFitTheme.secondaryText
            ),
            coachPresentation: nil,
            rationalePresentation: nil
        )
    }

    static func ready(
        input: CoachInputSnapshot,
        fingerprint: CoachInputFingerprint,
        guidance: CoachGuidanceV3,
        createdAt: Date = Date()
    ) -> CoachState {
        let readiness = CoachFinalStoryBuilder.readinessAssessment(input)
        guard readiness.allowed else {
            CoachLogger.compact(
                "[CoachFinalStoryReadiness]",
                [
                    "outcome=blockedDirectReady",
                    readiness.summary,
                    "rawRecovery=\(input.recoveryContext.recoveryPercent)",
                    "sleepHours=\(String(format: "%.2f", input.recoveryContext.sleepHours))",
                    "brainSleep=\(input.brain.sleep)",
                    "brainReadiness=\(input.brain.readiness)",
                    "source=\(input.source)"
                ].joined(separator: " ")
            )
            return .settling(reason: "Coach inputs are still syncing.", createdAt: createdAt)
        }

        let dayNarrative = CoachDayNarrativePresentation.resolve(
            input: input,
            guidance: guidance
        )
        let frame = guidance.dayDecisionFrame
        let frameOwnsNarrative = frame?.shouldOwnNarrative == true
        let frameStory = frameOwnsNarrative ? guidance.screenStory : nil
        let stateLabel = frameOwnsNarrative ? frame?.stateLabel ?? guidance.stateLabel : dayNarrative?.stateLabel ?? guidance.screenStory?.stateLabel ?? guidance.stateLabel
        let title = frameOwnsNarrative ? frameStory?.title ?? frame?.title ?? guidance.title : dayNarrative?.title ?? validTitle(guidance.title) ?? guidance.screenStory?.title ?? guidance.priority.detailTitle
        let message = frameOwnsNarrative ? frameStory?.myRead ?? frame?.diagnosisText ?? guidance.message : dayNarrative?.message ?? guidance.screenStory?.myRead ?? guidance.message
        let icon = dayNarrative?.icon ?? guidance.screenStory?.icon ?? guidance.icon
        let color = dayNarrative?.color ?? guidance.screenStory?.color ?? guidance.color
        let recommendation = frameOwnsNarrative ? frameStory?.myRecommendation ?? guidance.insightSubtitle ?? WeekFitLocalizedString("coach.fallback.keepNextStepSimple") : guidance.screenStory?.myRecommendation ?? guidance.insightSubtitle ?? WeekFitLocalizedString("coach.fallback.keepNextStepSimple")
        let display = CoachPresentationCopy.normalize(
            stateLabel: stateLabel,
            title: title,
            message: message,
            recommendation: recommendation,
            icon: icon,
            color: color,
            input: input,
            guidance: guidance
        )
        let finalStory = CoachFinalStoryBuilder.build(
            input: input,
            guidance: guidance,
            display: display
        )
        finalStory.validateVisibleContract()

        return CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .ready,
            input: input,
            fingerprint: fingerprint,
            guidance: guidance,
            finalStory: finalStory,
            todayPresentation: CoachTodayPresentation(
                title: finalStory.title.resolved,
                message: finalStory.subtitle.resolved,
                icon: finalStory.icon,
                color: finalStory.color
            ),
            coachPresentation: CoachScreenPresentation(
                stateLabel: finalStory.badgeState.resolved,
                title: finalStory.title.resolved,
                message: finalStory.subtitle.resolved,
                recommendation: finalStory.primaryRecommendation.resolved,
                icon: finalStory.icon,
                color: finalStory.color,
                supportActions: finalStory.supportActions,
                avoidNotes: [finalStory.avoidRecommendation.resolved]
            ),
            rationalePresentation: CoachRationalePresentation.resolve(from: input)
        )
    }

    func preservingPreviousDuringRefresh(createdAt: Date = Date()) -> CoachState {
        guard hasValidGuidance else { return self }

        return CoachState(
            id: id,
            createdAt: createdAt,
            status: .refreshingPrevious,
            input: input,
            fingerprint: fingerprint,
            guidance: guidance,
            finalStory: finalStory,
            todayPresentation: todayPresentation,
            coachPresentation: coachPresentation,
            rationalePresentation: rationalePresentation
        )
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}

enum CoachFinalStoryBuilder {
    typealias Display = (stateLabel: String, title: String, message: String, recommendation: String, icon: String, color: Color)

    private struct HumanStory {
        let title: CoachFinalStoryText
        let whatHappened: CoachFinalStoryText
        let whatMattersNow: CoachFinalStoryText
        let whatToDoNext: CoachFinalStoryText
        let whatToAvoid: CoachFinalStoryText
    }

    private enum ActiveSessionAssessment {
        case normalActive
        case activeWithCaution
        case activeAfterOverload
        case activeRecoveryOnly
        case activeSleepRisk
    }

    private static func humanStory(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        titleFallback: CoachFinalStoryText,
        whatHappenedFallback: CoachFinalStoryText,
        whatToDoNextFallback: CoachFinalStoryText,
        whatToAvoidFallback: CoachFinalStoryText
    ) -> HumanStory {
        let title = humanTitle(owner: owner, input: input, guidance: guidance, fallback: titleFallback)
        let happened = whatHappenedText(owner: owner, input: input, guidance: guidance, fallback: whatHappenedFallback)
        let matters = whatMattersNowText(owner: owner, input: input, guidance: guidance, fallback: happened)
        let next = whatToDoNextText(owner: owner, input: input, guidance: guidance, fallback: whatToDoNextFallback)
        let avoid = whatToAvoidText(owner: owner, input: input, guidance: guidance, fallback: whatToAvoidFallback)

        return HumanStory(
            title: title,
            whatHappened: happened,
            whatMattersNow: matters,
            whatToDoNext: next,
            whatToAvoid: avoid
        )
    }

    private static func humanTitle(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeAfterOverload, .activeSleepRisk:
                return dynamicText("I would not continue today.", russian: "Я бы сегодня не продолжал.")
            case .activeRecoveryOnly:
                return dynamicText("Use this only to cool down.", russian: "Используйте это только как заминку.")
            case .activeWithCaution:
                return dynamicText("Keep this session controlled.", russian: "Держите эту сессию под контролем.")
            case .normalActive:
                return dynamicText("Stay aware and start easy.", russian: "Будьте внимательны и начните спокойно.")
            }
        }

        if owner == .postActivityRecovery || completedLoadShouldDriveRecovery(input: input, guidance: guidance) {
            return dynamicText("Protect today's work", russian: "Закрепите результат дня")
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance) {
            return dynamicText(
                "Prepare for \(displayName(activity).lowercased())",
                russian: "Подготовьтесь к следующей нагрузке"
            )
        }

        return fallback
    }

    private static func whatHappenedText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeAfterOverload, .activeSleepRisk, .activeRecoveryOnly:
                return dynamicText(
                    "You already did enough today.",
                    russian: "Сегодня вы уже сделали достаточно."
                )
            case .activeWithCaution:
                return dynamicText(
                    "\(displayName(activity)) is active, but today's context lowers the ceiling.",
                    russian: "Активность уже началась, но сегодняшний контекст снижает потолок."
                )
            case .normalActive:
                return dynamicText(
                    "\(displayName(activity)) is active now.",
                    russian: "Активность уже началась."
                )
            }
        }

        if owner == .postActivityRecovery || completedLoadShouldDriveRecovery(input: input, guidance: guidance) {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Today's main training work is complete.",
                    russian: "Главная тренировка на сегодня завершена."
                )
            }
            if let activity = completedActivity(input: input, guidance: guidance) {
                return completedLoadText(activity: activity, input: input)
            }
            return dynamicText(
                "Today's training already delivered the main load.",
                russian: "Главная тренировка на сегодня уже выполнена."
            )
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance) {
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            let isLong = kind == .endurance || activity.effectiveDurationMinutes >= 75
            let name = displayName(activity).lowercased()
            return dynamicText(
                isLong ? "A long \(name) is coming soon." : "\(displayName(activity)) is coming soon.",
                russian: "Скоро начнется главная тренировка дня."
            )
        }

        if (owner == .readiness || owner == .stableOverview) && recoveryLooksStrong(input) {
            return dynamicText(
                "Your body is in a good place today.",
                russian: "Сегодня организм в хорошем состоянии."
            )
        }

        if let read = specificText(guidance.screenStory?.myRead) {
            return dynamicText(read, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func whatMattersNowText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeSleepRisk:
                return dynamicText(
                    "This is not the moment to add intensity; sleep is the useful lever now.",
                    russian: "Сейчас не время добавлять интенсивность; главное — сон."
                )
            case .activeAfterOverload:
                return dynamicText(
                    "The training load is already high; more work will cost more than it gives.",
                    russian: "Нагрузка уже высокая; дополнительная тренировка даст меньше, чем заберет."
                )
            case .activeRecoveryOnly:
                return dynamicText(
                    "This can help recovery only if it stays very easy.",
                    russian: "Для восстановления нагрузка должна оставаться лёгкой."
                )
            case .activeWithCaution:
                return dynamicText(
                    "Use the first minutes to check readiness, not to chase intensity.",
                    russian: "Начните плавно и оцените свои ощущения."
                )
            case .normalActive:
                return dynamicText(
                    "Execution quality matters more than adding extra goals.",
                    russian: "Сегодня качество важнее количества."
                )
            }
        }

        if owner == .postActivityRecovery || completedLoadShouldDriveRecovery(input: input, guidance: guidance) {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Recovery now depends mostly on the evening and sleep.",
                    russian: "Сейчас главный приоритет — сон и восстановление"
                )
            }
            return dynamicText(
                "Recovery is the objective now: absorb the load and keep the benefit.",
                russian: "Тренировка сделала своё дело, восстановление завершит работу."
            )
        }

        if owner == .activityPreparation {
            return dynamicText(
                "Start controlled so the session stays useful.",
                russian: "Начните спокойно, чтобы нагрузка осталась полезной."
            )
        }

        if owner == .readiness || owner == .stableOverview {
            return dynamicText(
                "Keep the day consistent.",
                russian: "Держите ровный ритм до конца дня."
            )
        }

        if let why = specificText(guidance.screenStory?.whyThisMatters ?? guidance.priority.whyThisMatters) {
            return dynamicText(why, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func whatToDoNextText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeSleepRisk:
                return dynamicText(
                    "Keep it short or stop, then protect sleep.",
                    russian: "Сейчас сон важнее нагрузки."
                )
            case .activeAfterOverload:
                return dynamicText(
                    "End it or keep it very easy.",
                    russian: "Завершайте или сбавьте темп."
                )
            case .activeRecoveryOnly:
                return dynamicText(
                    "Keep it easy and use it only as recovery.",
                    russian: "Не ускоряйтесь — сейчас восстановление."
                )
            case .activeWithCaution:
                return dynamicText(
                    "Start easy and keep effort flexible.",
                    russian: "Начните легко и оставьте усилие гибким."
                )
            case .normalActive:
                return dynamicText(
                    "Start easy, control effort, and stay aware.",
                    russian: "Начните легко, контролируйте усилие и следите за состоянием."
                )
            }
        }

        if owner == .postActivityRecovery || completedLoadShouldDriveRecovery(input: input, guidance: guidance) {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Keep the evening easy, finish hydration gradually, and protect sleep.",
                    russian: "Проведите вечер спокойно, допейте воду постепенно и защитите сон."
                )
            }
            return dynamicText(
                "Focus on recovery: normal dinner, protein, hydration, and sleep.",
                russian: "Сфокусируйтесь на восстановлении: обычный ужин, белок, вода и сон."
            )
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance) {
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            if kind == .endurance || activity.effectiveDurationMinutes >= 75 {
                return dynamicText(
                    "Take quick carbs and drink a small amount before the start, then keep the first 15 minutes easy.",
                    russian: "Добавьте быстрые углеводы и немного воды перед стартом, затем первые 15 минут держите легко."
                )
            }
            return dynamicText(
                "Start easy for the first 10 minutes, then let the warm-up set the ceiling.",
                russian: "Первые 10 минут начните легко, затем пусть разминка задаст потолок."
            )
        }

        if owner == .stableOverview || owner == .readiness ||
            owner == .recovery && !completedLoadShouldDriveRecovery(input: input, guidance: guidance) && recoveryLooksStrong(input) {
            return dynamicText("Stay with the plan.", russian: "Держитесь текущего плана.")
        }

        if let action = concreteActionText(guidance) {
            return dynamicText(action, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func whatToAvoidText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeSleepRisk:
                return dynamicText(
                    "Do not turn a late evening into another hard session.",
                    russian: "Не превращайте поздний вечер в еще одну тяжелую сессию."
                )
            case .activeAfterOverload:
                return dynamicText(
                    "Do not continue building load today.",
                    russian: "Не продолжайте наращивать нагрузку сегодня."
                )
            case .activeRecoveryOnly:
                return dynamicText(
                    "Do not turn this into training.",
                    russian: "Не превращайте это в тренировку."
                )
            case .activeWithCaution:
                return dynamicText(
                    "Do not chase intensity if readiness feels off.",
                    russian: "Не гонитесь за интенсивностью, если готовность не ощущается надежной."
                )
            case .normalActive:
                return dynamicText(
                    "Do not rush the opening minutes.",
                    russian: "Не спешите в первые минуты."
                )
            }
        }

        if owner == .postActivityRecovery || completedLoadShouldDriveRecovery(input: input, guidance: guidance) {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Do not turn the evening into another hard effort.",
                    russian: "Не превращайте вечер в еще одну тяжелую тренировку."
                )
            }
            return dynamicText(
                "Do not add another hard session today.",
                russian: "Не добавляйте сегодня еще одну тяжелую сессию."
            )
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance),
           CoachActivityContextResolverV3.kind(for: activity) == .endurance || activity.effectiveDurationMinutes >= 75 {
            return dynamicText(
                "Do not chase intensity in the first 15 minutes.",
                russian: "Не гонитесь за интенсивностью в первые 15 минут."
            )
        }

        if owner == .stableOverview || owner == .readiness ||
            owner == .recovery && !completedLoadShouldDriveRecovery(input: input, guidance: guidance) && recoveryLooksStrong(input) {
            return dynamicText(
                "Do not add intensity just because the day looks easy.",
                russian: "Не добавляйте интенсивность только потому, что день выглядит легким."
            )
        }

        if let avoid = specificText(guidance.avoidNotes.first ?? guidance.screenStory?.beCarefulWith) {
            return dynamicText(avoid, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func concreteActionText(_ guidance: CoachGuidanceV3) -> String? {
        let screenTitles = guidance.screenStory?.primaryActions.map(\.title) ?? []
        let supportTitles = guidance.supportActions.map(\.title)
        let titles = (screenTitles.isEmpty ? supportTitles : screenTitles)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isGenericActionText($0) }

        guard let first = titles.first else { return nil }
        if let second = titles.dropFirst().first, !isDuplicateAction(first, second) {
            return "\(first), then \(lowercasedFirst(second))."
        }
        return first
    }

    private static func finalStorySupportActions(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        humanStory: HumanStory,
        colorFamily: CoachFinalStoryColorFamily
    ) -> [CoachSupportActionV3] {
        let heroTexts = [
            humanStory.title.resolved,
            humanStory.whatHappened.resolved,
            humanStory.whatMattersNow.resolved,
            humanStory.whatToDoNext.resolved,
            humanStory.whatToAvoid.resolved
        ]

        let upstream = (
            guidance.screenStory?.primaryActions.map { action in
                CoachSupportActionV3(
                    type: action.type,
                    icon: action.icon,
                    title: action.title,
                    subtitle: action.subtitle,
                    color: action.color,
                    actionProvenance: action.actionProvenance
                )
            } ?? []
        ) + guidance.supportActions

        if owner == .postActivityRecovery || owner == .recovery || completedLoadShouldDriveRecovery(input: input, guidance: guidance) {
            let recoveryActions = recoverySupportActions(input: input, guidance: guidance, colorFamily: colorFamily)
            let upstreamRecoveryActions = upstream.filter { !isGenericRecoveryFallbackAction($0) }
            let actions = mergeActions(recoveryActions, upstreamRecoveryActions, avoiding: heroTexts)
            if !actions.isEmpty {
                return Array(actions.prefix(5))
            }
            return Array(recoveryActions.prefix(5))
        }

        var actions = dedupedActions(upstream, avoiding: heroTexts)

        if actions.isEmpty {
            actions.append(
                supportAction(
                    .stayConsistent,
                    title: localizedAction(english: "Stay with the plan", russian: "Держитесь плана"),
                    subtitle: localizedAction(english: "No extra fix is needed", russian: "Дополнительных исправлений не нужно"),
                    colorFamily: colorFamily
                )
            )
        }

        return Array(actions.prefix(5))
    }

    private static func mergeActions(
        _ primary: [CoachSupportActionV3],
        _ secondary: [CoachSupportActionV3],
        avoiding heroTexts: [String]
    ) -> [CoachSupportActionV3] {
        dedupedActions(primary + secondary, avoiding: heroTexts)
    }

    private static func dedupedActions(
        _ actions: [CoachSupportActionV3],
        avoiding heroTexts: [String]
    ) -> [CoachSupportActionV3] {
        let normalizedHero = Set(heroTexts.map(normalizedActionText))
        var seen = Set<String>()
        var result: [CoachSupportActionV3] = []

        for action in actions {
            let titleKey = normalizedActionText(action.title)
            guard !titleKey.isEmpty else { continue }
            guard !normalizedHero.contains(titleKey) else { continue }
            guard seen.insert("\(action.type)-\(titleKey)").inserted else { continue }
            guard !result.contains(where: { normalizedActionText($0.title) == titleKey }) else { continue }
            result.append(action)
        }

        return result
    }

    private static func recoverySupportActions(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        colorFamily: CoachFinalStoryColorFamily
    ) -> [CoachSupportActionV3] {
        guard completedLoadShouldDriveRecovery(input: input, guidance: guidance) else { return [] }

        let activity = completedActivity(input: input, guidance: guidance)
        let kind = activity.map { CoachActivityContextResolverV3.kind(for: $0) }
        let duration = activity?.effectiveDurationMinutes ?? input.dayContext.completedActivityVolumeMinutes
        let highLoad = duration >= 75 ||
            input.dayContext.completedTrainingStressScore >= 2 ||
            input.actualLoad.activeCalories >= 750
        let veryHighLoad = duration >= 150 ||
            input.dayContext.completedTrainingStressScore >= 4 ||
            input.actualLoad.activeCalories >= 1_200 ||
            (input.actualLoad.activityProgress ?? 0) >= 1.5
        let evening = localHour(input.now) >= 18
        let nutritionNeedsAction = recoveryNutritionNeedsSupport(input)
        let hydrationNeedsAction = recoveryHydrationNeedsSupport(input) ||
            kind == .some(.endurance) && highLoad

        var actions: [CoachSupportActionV3] = []

        let completedName = activity.map { recoveryActivityName($0).english } ?? "training"
        let isRide = activity.map { activity in
            let text = "\(activity.title) \(activity.type)".lowercased()
            return text.contains("ride") || text.contains("cycl") || text.contains("bike")
        } == true
        let isStrength = kind == .some(.workout) && activity.map { activity in
            let text = "\(activity.title) \(activity.type)".lowercased()
            return text.contains("strength") || text.contains("upper") || text.contains("gym") || text.contains("lift")
        } == true

        actions.append(
            supportAction(
                .cooldown,
                title: localizedAction(english: isStrength ? "Easy cooldown walk" : "Cooldown walk", russian: "Спокойная заминка"),
                subtitle: localizedAction(english: "Keep it easy and let the body downshift", russian: "Держите легко и дайте телу замедлиться"),
                colorFamily: colorFamily
            )
        )

        actions.append(
            supportAction(
                kind == .some(.workout) ? .mobilityPrep : .lightRecoveryMovement,
                title: localizedAction(english: isStrength ? "Mobility work" : "Light stretching", russian: isStrength ? "Мобильность" : "Легкая растяжка"),
                subtitle: localizedAction(english: "Restore range without adding load", russian: "Верните подвижность без новой нагрузки"),
                colorFamily: colorFamily
            )
        )

        if nutritionNeedsAction && highLoad {
            actions.append(
                supportAction(
                    .recoveryMeal,
                    title: localizedAction(english: isStrength ? "Protein feeding" : "Recovery meal with protein and carbs", russian: isStrength ? "Белковый прием пищи" : "Восстановительный прием пищи"),
                    subtitle: localizedAction(english: "Help absorb the completed \(completedName)", russian: "Помогите организму усвоить выполненную нагрузку"),
                    colorFamily: .fuel
                )
            )
        }

        if hydrationNeedsAction {
            actions.append(
                supportAction(
                    .rehydrateGradually,
                    title: localizedAction(english: isRide || kind == .some(.endurance) ? "500 ml hydration" : "Hydrate gradually", russian: "Пейте постепенно"),
                    subtitle: localizedAction(english: "Sip over the next hour instead of catching up fast", russian: "Пейте в течение часа, без резкой компенсации"),
                    colorFamily: .hydration
                )
            )
        }

        if evening || veryHighLoad || noRemainingTrainingToday(input) {
            actions.append(
                supportAction(
                    .sleepPriority,
                    title: localizedAction(english: "Protect sleep", russian: "Защитите сон"),
                    subtitle: localizedAction(english: "Keep the evening easy so recovery can land", russian: "Сделайте вечер спокойным, чтобы восстановление сработало"),
                    colorFamily: colorFamily
                )
            )
        }

        if veryHighLoad {
            actions.append(
                supportAction(
                    .controlIntensity,
                    title: localizedAction(english: "No extra hard block", russian: "Без еще одного тяжелого блока"),
                    subtitle: localizedAction(english: "Do not stack more intensity onto today", russian: "Не добавляйте сегодня еще интенсивности"),
                    colorFamily: .warning
                )
            )
        }

        return actions
    }

    private static func isGenericRecoveryFallbackAction(_ action: CoachSupportActionV3) -> Bool {
        let title = normalizedActionText(action.title)
        return title == "stay relaxed" ||
            title == "slow down" ||
            title == "prepare for sleep" ||
            title == "keep the evening calm" ||
            title == "wind down now" ||
            title == "settle down"
    }

    private static func recoveryNutritionNeedsSupport(_ input: CoachInputSnapshot) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieGoal = input.nutritionContext?.caloriesGoal ?? input.brain.fullDayGoals.calories
        let protein = input.nutritionContext?.proteinCurrent ?? input.brain.metrics.protein
        let proteinGoal = input.nutritionContext?.proteinGoal ?? input.brain.fullDayGoals.protein

        return ratio(current: calories, goal: calorieGoal) < 0.95 ||
            ratio(current: protein, goal: proteinGoal) < 0.95
    }

    private static func recoveryHydrationNeedsSupport(_ input: CoachInputSnapshot) -> Bool {
        let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
        let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters

        return ratio(current: water, goal: waterGoal) < 0.85 ||
            input.brain.hydration == .depleted ||
            input.brain.hydration == .behind
    }

    private static func supportAction(
        _ type: CoachSupportActionTypeV3,
        title: String,
        subtitle: String,
        colorFamily: CoachFinalStoryColorFamily
    ) -> CoachSupportActionV3 {
        CoachSupportActionV3(
            type: type,
            icon: supportActionIcon(for: type),
            title: title,
            subtitle: subtitle,
            color: supportActionColor(for: type, fallback: colorFamily.color),
            actionProvenance: .recoveryPolicy
        )
    }

    private static func supportActionIcon(for type: CoachSupportActionTypeV3) -> String {
        switch type {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return "drop.fill"
        case .startRecoveryNutrition, .recoveryMeal, .lightFueling, .sustainEnergy, .keepDigestionLight:
            return "fork.knife"
        case .sleepPriority:
            return "moon.fill"
        case .cooldown, .mobilityPrep, .lightRecoveryMovement:
            return "figure.cooldown"
        case .breathingReset, .downshiftNervousSystem:
            return "wind"
        case .controlIntensity:
            return "speedometer"
        case .stayConsistent:
            return "checkmark.circle.fill"
        }
    }

    private static func supportActionColor(
        for type: CoachSupportActionTypeV3,
        fallback: Color
    ) -> Color {
        switch type {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return CoachPalette.hydration
        case .startRecoveryNutrition, .recoveryMeal, .lightFueling, .sustainEnergy, .keepDigestionLight:
            return CoachPalette.fueling
        case .controlIntensity:
            return CoachPalette.warning
        default:
            return fallback
        }
    }

    private static func localizedAction(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }

    private static func normalizedActionText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func completedLoadShouldDriveRecovery(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guidance.priority.focus == .postActivityRecovery ||
            input.dayContext.hasMeaningfulLoadCompleted ||
            input.dayContext.completedTrainingStressScore >= 2 ||
            input.brain.metrics.activeCalories >= 750 ||
            input.brain.past.hasHighActivityLoad
    }

    private static func activeActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if case .active(let activity, _) = guidance.phase,
           !isCompletedDuplicate(activity, in: input) {
            return activity
        }

        if let activity = guidance.priority.activity,
           isActive(activity, now: input.now),
           !isCompletedDuplicate(activity, in: input) {
            return activity
        }

        return input.dayContext.allActivities.first { activity in
            isActive(activity, now: input.now) && !isCompletedDuplicate(activity, in: input)
        } ?? input.plannedActivities.first { activity in
            isActive(activity, now: input.now) && !isCompletedDuplicate(activity, in: input)
        }
    }

    private static func isActive(_ activity: PlannedActivity, now: Date) -> Bool {
        guard !activity.isCompleted, !activity.isSkipped else { return false }
        let end = Calendar.current.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date
        return activity.date <= now && now <= end
    }

    private static func isCompletedDuplicate(
        _ activity: PlannedActivity,
        in input: CoachInputSnapshot
    ) -> Bool {
        input.dayContext.completedActivities.contains { completed in
            guard completed.id != activity.id else { return false }
            let sameTitle = completed.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(activity.title.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            let sameType = completed.type.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(activity.type.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            let startDelta = abs(completed.date.timeIntervalSince(activity.date))
            let durationDelta = abs(completed.effectiveDurationMinutes - activity.effectiveDurationMinutes)

            return sameTitle && sameType && startDelta <= 15 * 60 && durationDelta <= 10
        }
    }

    private static func activeSessionAssessment(
        activity: PlannedActivity,
        guidance: CoachGuidanceV3,
        input: CoachInputSnapshot
    ) -> ActiveSessionAssessment {
        let highLoad = dayAlreadyHasHighLoad(input)
        let criticalReadiness = criticalActiveReadinessWarning(guidance)
        let lateEvening = localHour(input.now) >= 20
        let lightRecovery = isLightRecoveryActivity(activity)
        let compromised = input.brain.readiness == .low ||
            input.brain.readiness == .compromised ||
            input.brain.recovery == .compromised ||
            input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 60 ||
            input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 6.5

        if (highLoad || criticalReadiness) && lateEvening {
            return .activeSleepRisk
        }
        if (highLoad || criticalReadiness) && lightRecovery {
            return .activeRecoveryOnly
        }
        if highLoad || criticalReadiness {
            return .activeAfterOverload
        }
        if compromised || input.dayContext.completedTrainingStressScore >= 2 {
            return .activeWithCaution
        }
        return .normalActive
    }

    private static func dayAlreadyHasHighLoad(_ input: CoachInputSnapshot) -> Bool {
        input.dayContext.hasMeaningfulLoadCompleted ||
            input.dayContext.completedActivityVolumeMinutes >= 150 ||
            input.dayContext.completedTrainingStressScore >= 4 ||
            input.actualLoad.activeCalories >= 1_200 ||
            (input.actualLoad.exerciseMinutes ?? 0) >= 150 ||
            (input.actualLoad.activityProgress ?? 0) >= 1.5
    }

    private static func criticalActiveReadinessWarning(_ guidance: CoachGuidanceV3) -> Bool {
        guidance.priority.focus == .trainingReadinessWarning &&
            guidance.priority.strength == .critical
    }

    private static func isLightRecoveryActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if type.contains("walk") ||
            type.contains("stretch") ||
            type.contains("mobility") ||
            type.contains("yoga") ||
            type.contains("recovery") {
            return true
        }

        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
        return kind == .recovery || load == .low
    }

    private static func eveningSleepRecoveryShouldLead(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        completedLoadShouldDriveRecovery(input: input, guidance: guidance) &&
            noRemainingTrainingToday(input)
    }

    private static func noRemainingTrainingToday(_ input: CoachInputSnapshot) -> Bool {
        let remainingContextActivity = input.dayContext.upcomingActivities.contains { activity in
            !activity.isCompleted &&
                !activity.isSkipped &&
                CoachDayActivityContextResolver.isCoachRelevant(activity)
        }

        return input.dayContext.upcomingTrainingActivities.allSatisfy { $0.isCompleted || $0.isSkipped } &&
            !remainingContextActivity
    }

    private static func completedActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if let activity = guidance.priority.activity, activity.isCompleted {
            return activity
        }
        return input.dayContext.lastCompletedActivity ??
            input.dayContext.completedActivities
            .filter { CoachDayActivityContextResolver.isCoachRelevant($0) }
            .sorted { $0.date > $1.date }
            .first
    }

    private static func completedLoadText(
        activity: PlannedActivity,
        input: CoachInputSnapshot
    ) -> CoachFinalStoryText {
        let activityName = recoveryActivityName(activity).english.lowercased()
        let russianActivityName = recoveryActivityName(activity).russian
        let duration = durationLoadDescription(minutes: activity.effectiveDurationMinutes).english
        let russianDuration = durationLoadDescription(minutes: activity.effectiveDurationMinutes).russian
        let load = input.brain.metrics.activeCalories >= 1_200 ||
            activity.effectiveDurationMinutes >= 150 ||
            CoachActivityContextResolverV3.kind(for: activity) == .endurance && activity.effectiveDurationMinutes >= 120 ||
            input.dayContext.completedTrainingStressScore >= 4
            ? "main training load"
            : "main training stimulus"
        let russianLoad = load == "main training load" ? "основную тренировочную нагрузку" : "основной тренировочный стимул"

        return formattedText(
            "coach.final.human.recovery.completedLoad",
            fallback: "Today's %@ %@ already delivered the %@.",
            russianFallback: "Сегодняшняя %@ %@ уже дала %@.",
            parameters: [duration, activityName, load],
            russianParameters: [russianDuration, russianActivityName, russianLoad]
        )
    }

    private static func recoveryActivityName(_ activity: PlannedActivity) -> (english: String, russian: String) {
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch type {
        case "cycling", "bike", "biking", "ride":
            return ("cycling session", "велотренировка")
        case "running", "run":
            return ("running session", "беговая тренировка")
        case "walking", "walk":
            return ("walk", "прогулка")
        case "strength", "gym", "lifting":
            return ("strength session", "силовая тренировка")
        default:
            let title = displayName(activity).trimmingCharacters(in: .whitespacesAndNewlines)
            let english = title.localizedCaseInsensitiveContains("session") ? title : "\(title) session"
            return (english, "тренировка")
        }
    }

    private static func durationLoadDescription(minutes: Int) -> (english: String, russian: String) {
        if minutes >= 180 {
            return ("\(minutes / 60)+ hour", "\(minutes / 60)+ часа")
        }
        if minutes >= 120 {
            return ("\(minutes / 60) hour", "\(minutes / 60) часа")
        }
        if minutes >= 75 {
            return ("\(minutes) minute", "\(minutes)-минутная")
        }
        return ("completed", "завершенная")
    }

    private static func upcomingActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if let activity = guidance.priority.activity, !activity.isCompleted, !activity.isSkipped {
            return activity
        }
        return input.dayContext.upcomingActivities
            .filter { !$0.isCompleted && !$0.isSkipped && CoachDayActivityContextResolver.isCoachRelevant($0) }
            .sorted { $0.date < $1.date }
            .first
    }

    private static func recoveryLooksStrong(_ input: CoachInputSnapshot) -> Bool {
        input.recoveryContext.recoveryPercent >= 85 &&
            input.recoveryContext.sleepHours >= 7.0 &&
            (input.brain.recovery == .strong || input.brain.readiness == .good)
    }

    private static func displayName(_ activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines)
        return type.isEmpty ? "training" : type
    }

    private static func specificText(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }
        guard !isGenericActionText(text) else { return nil }
        return text
    }

    private static func isGenericActionText(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }
        return normalized == "rebuild the basics" ||
            normalized.contains("rebuild the basics") ||
            normalized == "support recovery" ||
            normalized == "support the next block" ||
            normalized == "hydration supports this story" ||
            normalized == "fuel supports this story" ||
            normalized == "nutrition supports this story" ||
            normalized == "sleep is part of the decision" ||
            normalized == "keep the routine" ||
            normalized == "stay consistent"
    }

    private static func isDuplicateAction(_ first: String, _ second: String) -> Bool {
        let lhs = first.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rhs = second.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }

    private static func lowercasedFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
    }

    private static func dynamicText(_ english: String, russian: String) -> CoachFinalStoryText {
        text("", english, russian)
    }

    private static func formattedText(
        _ key: String,
        fallback: String,
        russianFallback: String,
        parameters: [String],
        russianParameters: [String]
    ) -> CoachFinalStoryText {
        CoachFinalStoryText(
            key: key,
            fallback: String(format: fallback, arguments: parameters.map { $0 as CVarArg }),
            russianFallback: String(format: russianFallback, arguments: russianParameters.map { $0 as CVarArg }),
            parameters: parameters,
            russianParameters: russianParameters
        )
    }

    static func build(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        display: Display
    ) -> CoachFinalStory {
        let owner = resolvedOwner(input: input, guidance: guidance)
        let colorFamily = resolvedColorFamily(owner: owner, input: input, guidance: guidance)
        let badge = badgeText(owner: owner, fallback: display.stateLabel)
        let title = titleText(owner: owner, fallback: display.title)
        let subtitle = subtitleText(owner: owner, fallback: display.message)
        let recommendation = recommendationText(owner: owner, fallback: display.recommendation)
        let avoid = avoidText(owner: owner, guidance: guidance)
        let humanStory = humanStory(
            owner: owner,
            input: input,
            guidance: guidance,
            titleFallback: title,
            whatHappenedFallback: subtitle,
            whatToDoNextFallback: recommendation,
            whatToAvoidFallback: avoid
        )
        let icon = resolvedIcon(owner: owner, fallback: display.icon)

        let assessment = readinessAssessment(input)

        let supportActions = finalStorySupportActions(
            owner: owner,
            input: input,
            guidance: guidance,
            humanStory: humanStory,
            colorFamily: colorFamily
        )

        return CoachFinalStory(
            owner: owner,
            primaryFocus: guidance.priority.focus,
            titleKey: humanStory.title.key,
            subtitleKey: humanStory.whatHappened.key,
            badgeState: badge,
            heroState: humanStory.whatMattersNow,
            colorFamily: colorFamily,
            icon: icon,
            primaryRecommendationKey: humanStory.whatToDoNext.key,
            avoidRecommendationKey: humanStory.whatToAvoid.key,
            title: humanStory.title,
            subtitle: humanStory.whatHappened,
            primaryRecommendation: humanStory.whatToDoNext,
            avoidRecommendation: humanStory.whatToAvoid,
            whatHappened: humanStory.whatHappened,
            whatMattersNow: humanStory.whatMattersNow,
            whatToDoNext: humanStory.whatToDoNext,
            whatToAvoid: humanStory.whatToAvoid,
            supportSignals: supportSignals(input: input, guidance: guidance),
            upNextContext: upNextContext(input: input, guidance: guidance),
            confidence: guidance.priority.confidence,
            dataReadinessState: assessment.dataReadinessState,
            primaryAction: CoachFinalStoryAction(title: humanStory.whatToDoNext, icon: actionIcon(owner: owner)),
            supportActions: supportActions
        )
    }

    static func inputIsCoherent(_ input: CoachInputSnapshot) -> Bool {
        readinessAssessment(input).allowed
    }

    static func readinessAssessment(_ input: CoachInputSnapshot) -> CoachFinalStoryReadinessAssessment {
        var satisfied: [String] = []
        var blocked: [String] = []

        if input.nutritionContext != nil {
            satisfied.append("nutrition")
        } else {
            blocked.append("nutritionMissing")
        }

        if input.recoveryContext.recoveryPercent > 0 {
            satisfied.append("recoveryPercent")
        } else {
            blocked.append("recoveryPlaceholder")
        }

        if input.recoveryContext.sleepHours > 0 && input.brain.metrics.sleepHours > 0 {
            satisfied.append("sleepHours")
        } else {
            blocked.append("sleepPlaceholder")
        }

        if input.brain.sleep != .unknown {
            satisfied.append("sleepState")
        } else {
            blocked.append("sleepUnknown")
        }

        let readinessLooksPlaceholder = input.brain.sleep == .unknown &&
            input.recoveryContext.recoveryPercent <= 0 &&
            (input.brain.readiness == .low || input.brain.readiness == .compromised)
        if readinessLooksPlaceholder {
            blocked.append("readinessPlaceholder:\(input.brain.readiness)")
        } else {
            satisfied.append("readinessState")
        }

        let dayContextMatchesSelectedDate = Calendar.current.isDate(input.dayContext.date, inSameDayAs: input.selectedDate)
        let dayContextClockIsCurrent = abs(input.dayContext.now.timeIntervalSince(input.now)) < 2
        if dayContextMatchesSelectedDate && dayContextClockIsCurrent {
            satisfied.append("activityContext")
        } else {
            blocked.append("activityContextStale")
        }

        let allowed = blocked.isEmpty
        return CoachFinalStoryReadinessAssessment(
            allowed: allowed,
            dataReadinessState: allowed ? .coherent : .settling,
            satisfiedConditions: satisfied,
            blockingReasons: blocked
        )
    }

    private static func resolvedOwner(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryOwner {
        if guidance.priority.focus == .activeActivity ||
            activeActivity(input: input, guidance: guidance) != nil {
            return .activeActivity
        }

        if guidance.priority.focus == .prepareForActivity ||
            guidance.priority.focus == .nextActivityLater {
            if hydrationMayOwnHero(input: input, guidance: guidance),
               hasSevereHydrationOrHeatContext(input: input),
               activitySoon(in: input, matching: { CoachActivityContextResolverV3.kind(for: $0) == .heat }) {
                return .hydration
            }
            return .activityPreparation
        }

        if completedLoadShouldDriveRecovery(input: input, guidance: guidance) {
            return .postActivityRecovery
        }

        if guidance.priority.focus != .activeActivity,
           guidance.priority.focus != .postActivityRecovery,
           hydrationMayOwnHero(input: input, guidance: guidance),
           hasSevereHydrationOrHeatContext(input: input) {
            return .hydration
        }

        if guidance.priority.focus != .activeActivity,
           guidance.priority.focus != .postActivityRecovery,
           fuelMayOwnHero(input: input, guidance: guidance),
           hasSevereFuelOrHardTrainingContext(input: input, guidance: guidance) {
            return .fuel
        }

        switch guidance.priority.focus {
        case .activeActivity:
            return .activeActivity
        case .prepareForActivity, .nextActivityLater:
            return .activityPreparation
        case .postActivityRecovery:
            return .postActivityRecovery
        case .recoveryNeeded, .eveningWindDown:
            return .recovery
        case .trainingReadinessWarning:
            return .readiness
        case .tomorrowPlanRisk:
            return .tomorrowProtection
        case .hydrationBehind:
            return hydrationMayOwnHero(input: input, guidance: guidance) ? .hydration : fallbackOwner(input: input, guidance: guidance)
        case .fuelBehind:
            return fuelMayOwnHero(input: input, guidance: guidance) ? .fuel : fallbackOwner(input: input, guidance: guidance)
        case .performanceReadiness:
            return .readiness
        case .dailyOverview:
            return .stableOverview
        }
    }

    private static func fallbackOwner(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryOwner {
        if input.dayContext.completedTrainingStressScore > 0 ||
            input.dayContext.hasMeaningfulLoadCompleted ||
            guidance.priority.priority == .recovery {
            return .recovery
        }

        if input.dayContext.upcomingTrainingActivities.isEmpty {
            return .readiness
        }

        return .activityPreparation
    }

    private static func hydrationMayOwnHero(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        let waterRatio = ratio(
            current: input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )
        let severeGap = waterRatio < 0.20 || input.brain.hydration == .depleted
        let heatSoon = activitySoon(in: input) { CoachActivityContextResolverV3.kind(for: $0) == .heat }
        let hardSoon = activitySoon(in: input) { activity in
            let load = CoachActivityContextResolverV3.load(for: activity)
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            return kind == .endurance || load == .high || load == .extreme
        }
        let safetyRisk = guidance.priority.strength == .critical || guidance.priority.limiter == .hydration && guidance.priority.strength == .critical
        let morning = localHour(input.now) < 12

        if morning && !heatSoon && !hardSoon && !safetyRisk {
            return false
        }

        return severeGap || heatSoon || hardSoon || safetyRisk
    }

    private static func hasSevereHydrationOrHeatContext(input: CoachInputSnapshot) -> Bool {
        let waterRatio = ratio(
            current: input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )
        return waterRatio < 0.20 ||
            input.brain.hydration == .depleted ||
            activitySoon(in: input) { CoachActivityContextResolverV3.kind(for: $0) == .heat }
    }

    private static func fuelMayOwnHero(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieRatio = ratio(current: calories, goal: input.brain.baseDayGoals.calories)
        let noFuel = calories < 120 || calorieRatio < 0.10
        let severeEnergyGap = calorieRatio < 0.20 || input.brain.fuel == .underfueled && calories < 300
        let hardSoon = activitySoon(in: input) { activity in
            let load = CoachActivityContextResolverV3.load(for: activity)
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            return kind == .endurance || load == .high || load == .extreme
        }
        let postWorkoutRefuel = input.dayContext.hasMeaningfulLoadCompleted &&
            (input.nutritionContext?.needsProteinRecovery == true || severeEnergyGap)
        let readinessRisk = guidance.priority.strength == .critical && guidance.priority.limiter == .fueling
        let morning = localHour(input.now) < 12

        if morning && !hardSoon && !postWorkoutRefuel && !readinessRisk {
            return false
        }

        return (hardSoon && noFuel) || postWorkoutRefuel || severeEnergyGap || readinessRisk
    }

    private static func hasSevereFuelOrHardTrainingContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieRatio = ratio(current: calories, goal: input.brain.baseDayGoals.calories)
        return calorieRatio < 0.20 ||
            input.brain.fuel == .underfueled && calories < 300 ||
            guidance.priority.limiter == .fueling && guidance.priority.strength == .critical ||
            activitySoon(in: input) { activity in
                let load = CoachActivityContextResolverV3.load(for: activity)
                let kind = CoachActivityContextResolverV3.kind(for: activity)
                return kind == .endurance || load == .high || load == .extreme
            }
    }

    private static func resolvedColorFamily(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryColorFamily {
        if guidance.priority.strength == .critical &&
            owner != .activeActivity &&
            owner != .hydration &&
            owner != .fuel {
            switch guidance.priority.limiter {
            case .trainingReadiness, .recovery, .accumulatedFatigue, .excessivePlannedLoad, .insufficientRecoveryTime:
                return .stress
            case .sleep:
                return input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 45 ? .stress : .warning
            case .hydration, .fueling, .upcomingTraining, .timing, .none:
                return .warning
            }
        }

        switch owner {
        case .activeActivity:
            if let activity = activeActivity(input: input, guidance: guidance) {
                switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
                case .activeSleepRisk, .activeAfterOverload:
                    return .stress
                case .activeWithCaution:
                    return .warning
                case .activeRecoveryOnly:
                    return .recovery
                case .normalActive:
                    return .activity
                }
            }
            return .activity
        case .activityPreparation:
            return .activity
        case .postActivityRecovery, .recovery:
            return guidance.priority.severity == .critical ? .stress : .recovery
        case .readiness:
            if guidance.priority.focus == .trainingReadinessWarning {
                return guidance.priority.strength == .critical ? .stress : .warning
            }
            return guidance.priority.focus == .performanceReadiness ? .ready : .stable
        case .stableOverview:
            return .stable
        case .tomorrowProtection:
            return .warning
        case .hydration:
            return guidance.priority.strength == .critical ? .warning : .hydration
        case .fuel:
            return guidance.priority.strength == .critical ? .warning : .fuel
        }
    }

    private static func badgeText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity:
            return text("coach.final.badge.live", "LIVE", "СЕЙЧАС")
        case .activityPreparation:
            return text("coach.final.badge.prepare", "PREPARE", "ПОДГОТОВКА")
        case .postActivityRecovery, .recovery:
            return text("coach.final.badge.recovery", "RECOVERY", "ВОССТАНОВЛЕНИЕ")
        case .readiness:
            return text("coach.final.badge.readiness", "READINESS", "ГОТОВНОСТЬ")
        case .tomorrowProtection:
            return text("coach.final.badge.tomorrow", "PROTECT TOMORROW", "ЗАЩИТИТЬ ЗАВТРА")
        case .stableOverview:
            return text("coach.final.badge.stable", "ON TRACK", "ВСЁ ПО ПЛАНУ")
        case .hydration:
            return text("coach.final.badge.hydration", "HYDRATION", "ВОДА")
        case .fuel:
            return text("coach.final.badge.fuel", "FUEL", "ПИТАНИЕ")
        }
    }

    private static func titleText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity:
            return text("coach.final.title.live", fallback, "Держите сессию под контролем")
        case .activityPreparation:
            return text("coach.final.title.prepare", fallback, "Подготовьтесь к тренировке")
        case .postActivityRecovery, .recovery:
            return text("coach.final.title.recovery", fallback, "Сейчас важнее восстановиться")
        case .readiness:
            return text("coach.final.title.readiness", fallback, "Держите день спокойным")
        case .tomorrowProtection:
            return text("coach.final.title.tomorrow", fallback, "Сохраните силы на завтра")
        case .stableOverview:
            return text("coach.final.title.stable", fallback, "Сегодня нет причин менять план")
        case .hydration:
            return text("coach.final.title.hydration", fallback, "Подготовьте воду")
        case .fuel:
            return text("coach.final.title.fuel", fallback, "Подготовьте питание")
        }
    }

    private static func subtitleText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity:
            return text("coach.final.subtitle.live", fallback, "Сейчас важнее качество выполнения, а не дополнительные цели.")
        case .activityPreparation:
            return text("coach.final.subtitle.prepare", fallback, "Следующая нагрузка важнее напоминаний о воде или еде.")
        case .postActivityRecovery, .recovery:
            return text("coach.final.subtitle.recovery", fallback, "Полезная работа уже учтена. Остаток дня должен поддержать восстановление.")
        case .readiness:
            return text("coach.final.subtitle.readiness", fallback, "Состояние тела сейчас важнее отдельных напоминаний.")
        case .tomorrowProtection:
            return text("coach.final.subtitle.tomorrow", fallback, "Сегодняшний выбор должен помочь завтрашней нагрузке.")
        case .stableOverview:
            return text("coach.final.subtitle.stable", fallback, "День выглядит стабильным и не требует срочных исправлений.")
        case .hydration:
            return text("coach.final.subtitle.hydration", fallback, "Вода сейчас влияет на безопасность и качество следующего блока.")
        case .fuel:
            return text("coach.final.subtitle.fuel", fallback, "Еда сейчас влияет на готовность к следующей нагрузке.")
        }
    }

    private static func recommendationText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity:
            return text("coach.final.recommendation.live", fallback, "Держите усилие ровным и завершите с запасом.")
        case .activityPreparation:
            return text("coach.final.recommendation.prepare", fallback, "Начните легче обычного и оставьте интенсивность гибкой.")
        case .postActivityRecovery, .recovery:
            return text("coach.final.recommendation.recovery", fallback, "Восстановите базу: вода, нормальная еда и без лишней интенсивности.")
        case .readiness:
            return text("coach.final.recommendation.readiness", fallback, "Выберите один легкий блок и не превращайте день в новую нагрузку.")
        case .tomorrowProtection:
            return text("coach.final.recommendation.tomorrow", fallback, "Снизьте остаток дня и защитите сон.")
        case .stableOverview:
            return text("coach.final.recommendation.stable", fallback, "Продолжайте в привычном ритме.")
        case .hydration:
            return text("coach.final.recommendation.hydration", fallback, "Пейте постепенно и не начинайте следующий блок сухим.")
        case .fuel:
            return text("coach.final.recommendation.fuel", fallback, "Добавьте простую еду, которую легко переварить.")
        }
    }

    private static func avoidText(owner: CoachFinalStoryOwner, guidance: CoachGuidanceV3) -> CoachFinalStoryText {
        let fallback = guidance.avoidNotes.first ?? guidance.screenStory?.beCarefulWith ?? "Do not add unnecessary intensity."
        switch owner {
        case .activeActivity:
            return text("coach.final.avoid.live", fallback, "Не превращайте текущую сессию в лишний стресс.")
        case .activityPreparation:
            return text("coach.final.avoid.prepare", fallback, "Не тратьте силы до начала основной нагрузки.")
        case .postActivityRecovery, .recovery:
            return text("coach.final.avoid.recovery", fallback, "Не добавляйте нагрузку, когда восстановление уже важнее.")
        case .readiness:
            return text("coach.final.avoid.readiness", fallback, "Не используйте хорошую готовность как повод добавлять лишнее.")
        case .tomorrowProtection:
            return text("coach.final.avoid.tomorrow", fallback, "Не занимайте силы у завтрашней тренировки.")
        case .stableOverview:
            return text("coach.final.avoid.stable", fallback, "Не добавляйте задачи там, где день уже идет нормально.")
        case .hydration:
            return text("coach.final.avoid.hydration", fallback, "Не догоняйте воду одним большим объемом.")
        case .fuel:
            return text("coach.final.avoid.fuel", fallback, "Не откладывайте еду до момента, когда энергия уже провалится.")
        }
    }

    private static func supportSignals(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> [CoachFinalStorySupportSignal] {
        var signals: [CoachFinalStorySupportSignal] = []
        let owner = resolvedOwner(input: input, guidance: guidance)
        let nutrition = input.nutritionContext
        let waterRatio = ratio(
            current: nutrition?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: nutrition?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )
        let waterCurrent = nutrition?.waterCurrent ?? input.brain.metrics.waterLiters
        let caloriesCurrent = nutrition?.caloriesCurrent ?? input.brain.metrics.calories
        let proteinCurrent = nutrition?.proteinCurrent ?? input.brain.metrics.protein
        let calorieRatio = ratio(
            current: caloriesCurrent,
            goal: input.brain.baseDayGoals.calories
        )
        let proteinRatio = ratio(
            current: proteinCurrent,
            goal: nutrition?.proteinGoal ?? input.brain.baseDayGoals.protein
        )

        let completedLoadRecovery = owner == .postActivityRecovery ||
            input.dayContext.hasMeaningfulLoadCompleted ||
            input.brain.metrics.activeCalories >= 750
        let hydrationIsMeaningful = owner == .activityPreparation ||
            owner == .activeActivity ||
            completedLoadRecovery
            ? (waterRatio < 0.45 && waterCurrent < 1.5 || input.brain.hydration == .depleted)
            : (waterRatio < 0.35 || input.brain.hydration == .depleted)
        if guidance.priority.focus != .hydrationBehind && hydrationIsMeaningful {
            signals.append(
                CoachFinalStorySupportSignal(
                    kind: .hydration,
                    title: hydrationSupportText(owner: owner, input: input, waterRatio: waterRatio),
                    icon: "drop.fill"
                )
            )
        }

        let fuelIsMeaningful = owner == .activityPreparation ||
            owner == .activeActivity ||
            completedLoadRecovery
            ? (calorieRatio < 0.45 && caloriesCurrent < 1_200 ||
                proteinRatio < 0.50 && proteinCurrent < 50 ||
                nutrition?.needsProteinRecovery == true && proteinRatio < 0.75 && proteinCurrent < 70)
            : (calorieRatio < 0.35 || input.brain.fuel == .underfueled)
        if guidance.priority.focus != .fuelBehind && fuelIsMeaningful {
            signals.append(
                CoachFinalStorySupportSignal(
                    kind: .fuel,
                    title: fuelSupportText(owner: owner, input: input, calorieRatio: calorieRatio),
                    icon: "bolt.fill"
                )
            )
        }

        if guidance.priority.limiter == .sleep {
            signals.append(
                CoachFinalStorySupportSignal(
                    kind: .sleep,
                    title: text("coach.final.signal.sleep", "Sleep is the limiter.", "Сон сейчас ограничивает готовность."),
                    icon: "moon.fill"
                )
            )
        }

        return Array(signals.prefix(3))
    }

    private static func hydrationSupportText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        waterRatio: Double
    ) -> CoachFinalStoryText {
        if owner == .postActivityRecovery || owner == .recovery || input.dayContext.hasMeaningfulLoadCompleted {
            return dynamicText(
                "Drink 300-500 ml over the next hour.",
                russian: "Выпейте 300-500 мл в течение следующего часа."
            )
        }

        if owner == .activityPreparation || owner == .activeActivity {
            return dynamicText(
                "Drink a small amount before the start.",
                russian: "Сделайте несколько глотков перед стартом."
            )
        }

        if waterRatio < 0.20 || input.brain.hydration == .depleted {
            return dynamicText(
                "Hydration has not really started.",
                russian: "Вода почти не начата."
            )
        }

        return dynamicText("Hydration is behind.", russian: "Вода отстает.")
    }

    private static func fuelSupportText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        calorieRatio: Double
    ) -> CoachFinalStoryText {
        if owner == .postActivityRecovery || owner == .recovery || input.dayContext.hasMeaningfulLoadCompleted {
            return dynamicText(
                "Protein and carbs help absorb the work.",
                russian: "Белок и углеводы помогают усвоить нагрузку."
            )
        }

        if owner == .activityPreparation || owner == .activeActivity {
            return dynamicText(
                "Quick carbs make the start easier.",
                russian: "Быстрые углеводы облегчат старт."
            )
        }

        if calorieRatio < 0.20 || input.brain.fuel == .underfueled {
            return dynamicText(
                "Nutrition is materially behind.",
                russian: "Питание заметно отстает."
            )
        }

        return dynamicText("Nutrition is behind.", russian: "Питание отстает.")
    }

    private static func upNextContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryUpNextContext? {
        guard let activity = guidance.priority.activity ??
                input.dayContext.upcomingActivities.first(where: { !$0.isCompleted && !$0.isSkipped }) else {
            return nil
        }

        return CoachFinalStoryUpNextContext(
            activityID: activity.id,
            title: WeekFitCoachRuntimeLocalizedString(activity.title)
        )
    }

    private static func resolvedIcon(owner: CoachFinalStoryOwner, fallback: String) -> String {
        switch owner {
        case .activeActivity:
            return fallback
        case .activityPreparation:
            return fallback.isEmpty ? "figure.run" : fallback
        case .postActivityRecovery, .recovery:
            return "heart.fill"
        case .readiness:
            return "checkmark.seal.fill"
        case .tomorrowProtection:
            return "moon.stars.fill"
        case .stableOverview:
            return "waveform.path.ecg.rectangle.fill"
        case .hydration:
            return "drop.fill"
        case .fuel:
            return "bolt.fill"
        }
    }

    private static func actionIcon(owner: CoachFinalStoryOwner) -> String {
        switch owner {
        case .hydration:
            return "drop.fill"
        case .fuel:
            return "fork.knife"
        case .activeActivity:
            return "speedometer"
        case .activityPreparation:
            return "figure.cooldown"
        case .postActivityRecovery, .recovery:
            return "heart.fill"
        case .tomorrowProtection:
            return "moon.fill"
        case .readiness, .stableOverview:
            return "checkmark"
        }
    }

    private static func activitySoon(
        in input: CoachInputSnapshot,
        matching predicate: (PlannedActivity) -> Bool
    ) -> Bool {
        input.dayContext.upcomingActivities.contains { activity in
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            let minutes = activity.date.timeIntervalSince(input.now) / 60
            return minutes >= 0 && minutes <= 180 && predicate(activity)
        } || input.dayContext.allActivities.contains { activity in
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            let end = Calendar.current.date(byAdding: .minute, value: activity.effectiveDurationMinutes, to: activity.date) ?? activity.date
            return activity.date <= input.now && input.now <= end && predicate(activity)
        }
    }

    private static func localHour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    private static func ratio(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 1 }
        return max(0, current / goal)
    }

    private static func text(
        _ key: String,
        _ fallback: String,
        _ russianFallback: String
    ) -> CoachFinalStoryText {
        CoachFinalStoryText(
            key: key,
            fallback: fallback.trimmingCharacters(in: .whitespacesAndNewlines),
            russianFallback: russianFallback,
            parameters: [],
            russianParameters: []
        )
    }
}

private struct CoachDayNarrativePresentation {
    let stateLabel: String
    let title: String
    let message: String
    let todayTitle: String
    let todayMessage: String
    let icon: String
    let color: Color

    static func resolve(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachDayNarrativePresentation? {
        let model = input.dayPriorityModel
        let nutrition = input.nutritionContext
        let constraints = DayConstraints(input: input)
        let isDemandingDay = model.dayGoal == .overload ||
            model.dayStressLevel == .overload ||
            model.dayStressLevel == .high
        let isRecoveryPriority = guidance.priority.focus == .recoveryNeeded ||
            guidance.priority.focus == .postActivityRecovery ||
            guidance.priority.priority == .recovery
        let visualStateIsMisleading = guidance.stateLabel == "GOOD TO GO" ||
            guidance.screenStory?.stateLabel == "GOOD TO GO" ||
            guidance.screenStory?.stateLabel == "ON TRACK"
        let isRecoveryPhase: Bool
        switch guidance.phase {
        case .recovering, .stable:
            isRecoveryPhase = true
        case .active, .preparing:
            isRecoveryPhase = false
        }

        guard isDemandingDay || isRecoveryPriority else { return nil }
        guard isRecoveryPhase || isRecoveryPriority || visualStateIsMisleading else { return nil }
        guard constraints.hasMeaningfulLimiter || visualStateIsMisleading || isRecoveryPriority else {
            return nil
        }

        let completedLine = accomplishmentLine(model: model, input: input)
        let limiterLine = constraints.limiterLine
        let protectionLine = protectionLine(model: model)
        let message = [
            completedLine,
            limiterLine,
            protectionLine
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        return CoachDayNarrativePresentation(
            stateLabel: "RECOVERY PRIORITY",
            title: "Recovery is now the priority",
            message: message,
            todayTitle: "Recovery now leads the day",
            todayMessage: todayMessage(
                model: model,
                constraints: constraints,
                nutrition: nutrition
            ),
            icon: "bolt.shield.fill",
            color: WeekFitTheme.purple
        )
    }

    private static func accomplishmentLine(
        model: DayPriorityModel,
        input: CoachInputSnapshot
    ) -> String {
        if let primary = model.primarySession, primary.isCompleted {
            return "You completed the key workload today."
        }

        if input.dayContext.completedTrainingMinutes > 0 || input.dayContext.completedTrainingStressScore > 0 {
            return "Training work is complete for now."
        }

        return "Today has carried a demanding training load."
    }

    private static func protectionLine(model: DayPriorityModel) -> String? {
        switch model.protectionTarget {
        case .tomorrow:
            return "Protect tomorrow by keeping the rest of today easy."
        case .recovery:
            return "Protect recovery before adding more stress."
        case .primarySession:
            return "Protect the work by letting adaptation start now."
        case .consistency:
            return "Protect consistency by not adding extra fatigue."
        }
    }

    private static func todayMessage(
        model: DayPriorityModel,
        constraints: DayConstraints,
        nutrition: CoachNutritionContext?
    ) -> String {
        if constraints.hasFuelLimiter && constraints.hasHydrationLimiter {
            return "The day was demanding, and fuel plus hydration are now behind. Start recovery before adding more stress."
        }

        if constraints.hasFuelLimiter {
            return "The day was demanding, and fueling is now the limiter. Eat enough to support recovery."
        }

        if constraints.hasHydrationLimiter {
            return "The day was demanding, and hydration is now the limiter. Rehydrate steadily before the next block."
        }

        if model.protectionTarget == .tomorrow {
            return "The day was demanding. Downshift now so tomorrow's training is not compromised."
        }

        if nutrition?.needsProteinRecovery == true {
            return "The key work is done. Protein and recovery now matter more than adding load."
        }

        return "The key work is done. Recovery now matters more than adding load."
    }
}

private enum CoachPresentationCopy {
    static func normalize(
        stateLabel: String,
        title: String,
        message: String,
        recommendation: String,
        icon: String,
        color: Color,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> (stateLabel: String, title: String, message: String, recommendation: String, icon: String, color: Color) {
        let noUpcomingActivity = input.dayContext.upcomingTrainingActivities.isEmpty &&
            input.dayContext.upcomingActivities.filter { !$0.isCompleted && !$0.isSkipped }.isEmpty

        if guidance.priority.focus == .performanceReadiness && noUpcomingActivity {
            return (
                stateLabel: localized(english: "READINESS", russian: "ГОТОВНОСТЬ"),
                title: localized(english: "Keep today light", russian: "Держите день лёгким"),
                message: localized(
                    english: "Recovery looks good, but recent load still matters. Use easy movement and avoid turning the morning into another hard session.",
                    russian: "Восстановление выглядит хорошо, но недавняя нагрузка всё ещё важна. Двигайтесь легко и не превращайте утро в ещё одну тяжёлую тренировку."
                ),
                recommendation: localized(
                    english: "Choose one easy block, keep heat conservative, and let food and water support the day.",
                    russian: "Выберите один лёгкий блок, держите сауну спокойной, а еду и воду оставьте поддержкой дня."
                ),
                icon: "heart.fill",
                color: CoachPalette.stable
            )
        }

        if WeekFitCurrentLocale().identifier.hasPrefix("ru") {
            return (
                stateLabel: runtimeLocalized(stateLabel, fallback: stateLabel),
                title: runtimeLocalized(title, fallback: title),
                message: runtimeLocalized(message, fallback: message),
                recommendation: runtimeLocalized(recommendation, fallback: recommendation),
                icon: icon,
                color: color
            )
        }

        return (stateLabel, title, message, recommendation, icon, color)
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }

    private static func runtimeLocalized(_ value: String, fallback: String) -> String {
        let localized = WeekFitCoachRuntimeLocalizedString(value)
        guard localized != value else { return fallback }
        return localized
    }
}

private struct DayConstraints {
    let hasFuelLimiter: Bool
    let hasHydrationLimiter: Bool
    let hasProteinLimiter: Bool

    init(input: CoachInputSnapshot) {
        let nutrition = input.nutritionContext
        let calorieRatio = Self.ratio(
            current: nutrition?.caloriesCurrent ?? input.brain.metrics.calories,
            goal: input.brain.baseDayGoals.calories
        )
        let proteinRatio = Self.ratio(
            current: nutrition?.proteinCurrent ?? input.brain.metrics.protein,
            goal: input.brain.baseDayGoals.protein
        )
        let waterRatio = Self.ratio(
            current: nutrition?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: nutrition?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )

        hasFuelLimiter = calorieRatio < 0.45 ||
            proteinRatio < 0.35
        hasHydrationLimiter = input.brain.hydration == .depleted ||
            input.brain.hydration == .behind ||
            waterRatio < 0.60
        hasProteinLimiter = proteinRatio < 0.50
    }

    var hasMeaningfulLimiter: Bool {
        hasFuelLimiter || hasHydrationLimiter || hasProteinLimiter
    }

    var limiterLine: String? {
        switch (hasFuelLimiter, hasHydrationLimiter, hasProteinLimiter) {
        case (true, true, true):
            return "Recovery, hydration and fueling are now the limiting factors, with protein still behind."
        case (true, true, false):
            return "Recovery, hydration and fueling are now the limiting factors."
        case (true, false, true):
            return "Recovery and fueling are now the limiting factors, with protein still behind."
        case (true, false, false):
            return "Recovery and fueling are now the limiting factors."
        case (false, true, true):
            return "Recovery and hydration are now the limiting factors, with protein still behind."
        case (false, true, false):
            return "Recovery and hydration are now the limiting factors."
        case (false, false, true):
            return "Recovery and protein are now the limiting factors."
        case (false, false, false):
            return nil
        }
    }

    private static func ratio(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 1 }
        return current / goal
    }
}

extension CoachRationalePresentation {
    static func resolve(from input: CoachInputSnapshot) -> CoachRationalePresentation? {
        guard let active = input.dayContext.allActivities.first(where: { isActiveActivity($0, now: input.now) }) ??
                input.brain.activities.first(where: { isActiveActivity($0, now: input.now) }) else {
            return nil
        }

        let model = input.dayPriorityModel
        let target = rationaleTarget(
            active: active,
            model: model
        )
        guard let target else { return nil }

        let rationale = rationaleCopy(
            active: active,
            target: target,
            model: model
        )

        return CoachRationalePresentation(
            title: rationale.title,
            message: rationale.message,
            icon: icon(for: target),
            color: WeekFitTheme.meal,
            sourceActivityID: target.id
        )
    }

    private static func isActiveActivity(_ activity: PlannedActivity, now: Date) -> Bool {
        guard !activity.isCompleted, !activity.isSkipped else { return false }
        let end = Calendar.current.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date

        return activity.date <= now && now <= end
    }

    private static func cleanTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Training" : trimmed
    }

    private static func activeActivityName(_ activity: PlannedActivity) -> String {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()
        if title.contains("walk") || type.contains("walk") {
            return "walk"
        }
        return "session"
    }

    private static func rationaleTarget(
        active: PlannedActivity,
        model: DayPriorityModel
    ) -> PlannedActivity? {
        if let primary = model.primarySession, primary.id != active.id {
            return primary
        }

        if let secondary = model.secondarySession, secondary.id != active.id {
            return secondary
        }

        return nil
    }

    private static func rationaleCopy(
        active: PlannedActivity,
        target: PlannedActivity,
        model: DayPriorityModel
    ) -> (title: String, message: String) {
        let targetName = cleanTitle(target.title)
        let activeName = activeActivityName(active)
        let kind = CoachActivityContextResolverV3.kind(for: target)
        let load = CoachActivityContextResolverV3.load(for: target)

        if model.protectionTarget == .tomorrow {
            return (
                title: "Protect tomorrow",
                message: "Tomorrow carries real demand. Keep this \(activeName) easy so today supports recovery instead of borrowing from the next training day."
            )
        }

        switch kind {
        case .endurance:
            return (
                title: "Protect the main effort",
                message: "\(targetName) is the key workload today. Keep this \(activeName) relaxed so you preserve legs and fueling for the main effort."
            )

        case .workout:
            let loadPhrase = load == .high || load == .extreme
                ? "the highest-value training block"
                : "the priority training block"
            return (
                title: "Save quality for training",
                message: "\(targetName) is \(loadPhrase) today. Use this \(activeName) to stay loose, not to add fatigue before loading."
            )

        case .heat:
            return (
                title: "Arrive settled for heat",
                message: "\(targetName) will add heat stress. Keep this \(activeName) easy so you start hydrated, calm, and not already taxed."
            )

        case .recovery:
            return (
                title: "Keep the day restorative",
                message: "\(targetName) is meant to support recovery. Keep this \(activeName) easy so the day stays restorative, not draining."
            )

        case .meal:
            return (
                title: "Keep digestion easy",
                message: "\(targetName) is the next useful reset. Keep this \(activeName) easy so appetite and digestion stay steady."
            )

        case .other:
            return (
                title: "Protect what comes next",
                message: "\(targetName) is the next meaningful block. Keep this \(activeName) easy so you arrive fresh instead of carrying extra fatigue."
            )
        }
    }

    private static func icon(for activity: PlannedActivity) -> String {
        let text = "\(activity.title) \(activity.type)".lowercased()
        if text.contains("core") || text.contains("strength") || text.contains("gym") {
            return "figure.core.training"
        }
        if text.contains("run") {
            return "figure.run"
        }
        if text.contains("ride") || text.contains("bike") || text.contains("cycle") {
            return "bicycle"
        }
        return "figure.strengthtraining.traditional"
    }
}

private func validTitle(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return trimmed
}
