import Foundation

/// Ensures scenario remains the narrative owner — metrics support, never headline.
enum CoachV6CopySubjectGuard {

    private static let forbiddenAssessmentOpeners = [
        "recovery is low",
        "recovery is very low",
        "your recovery is low",
        "sleep was",
        "short sleep leaves",
        "hydration is low",
        "water intake is behind",
        "calories are behind",
        "calories are missing",
        "fuel intake is lagging",
        "protein is behind"
    ]

    private static let forbiddenRussianAssessmentOpeners = [
        "сон был",
        "восстановление снижено",
        "воды мало",
        "вода ",
        "еда ",
        "калории ",
        "калорий "
    ]

    private static let walkScenarios: Set<CoachV6ScenarioKey> = [
        .walkLightDay,
        .walkAfterHeavyLoad,
        .walkEveningWindDown,
        .walkRecoveryAction
    ]

    static func assessmentStartsWithScenarioSubject(
        pack: CoachV6CopyPack,
        scenario: CoachV6ScenarioKey,
        activityType: CoachV6ActivityType
    ) -> Bool {
        let english = joinedEnglish(pack.assessment).lowercased()
        guard !english.isEmpty else { return false }

        if leadsWithForbiddenMetricOpener(english) {
            return false
        }

        if walkScenarios.contains(scenario) {
            let russian = joinedRussian(pack.assessment).lowercased()
            if leadsWithForbiddenRussianMetricOpener(russian) {
                return false
            }
            return containsScenarioSubject(english, scenario: scenario, activityType: activityType)
                && containsScenarioSubject(russian, scenario: scenario, activityType: activityType)
        }

        return containsScenarioSubject(english, scenario: scenario, activityType: activityType)
    }

    static func mainSectionsAvoidMetricHero(pack: CoachV6CopyPack) -> Bool {
        let mainEnglish = [
            joinedEnglish(pack.assessment),
            joinedEnglish(pack.recommendation),
            joinedEnglish(pack.avoid)
        ]
        .joined(separator: " ")
        .lowercased()

        if leadsWithForbiddenMetricOpener(mainEnglish) {
            return false
        }

        let mainRussian = [
            joinedRussian(pack.assessment),
            joinedRussian(pack.recommendation),
            joinedRussian(pack.avoid)
        ]
        .joined(separator: " ")
        .lowercased()

        return !leadsWithForbiddenRussianMetricOpener(mainRussian)
    }

    private static func leadsWithForbiddenMetricOpener(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return forbiddenAssessmentOpeners.contains { trimmed.hasPrefix($0) }
    }

    private static func leadsWithForbiddenRussianMetricOpener(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return forbiddenRussianAssessmentOpeners.contains { trimmed.hasPrefix($0) }
    }

    private static func containsScenarioSubject(
        _ assessment: String,
        scenario: CoachV6ScenarioKey,
        activityType: CoachV6ActivityType
    ) -> Bool {
        let tokens = subjectTokens(scenario: scenario, activityType: activityType)
        return tokens.contains { assessment.contains($0) }
    }

    private static func subjectTokens(
        scenario: CoachV6ScenarioKey,
        activityType: CoachV6ActivityType
    ) -> [String] {
        switch scenario {
        case .morningReadiness:
            return ["morning", "утро"]
        case .stableDay:
            return ["urgent", "day", "день", "спокойно"]
        case .activeEndurance:
            switch activityType {
            case .cycling:
                return ["ride", "заезд", "велосипед"]
            case .running:
                return ["run", "пробеж", "бег"]
            default:
                return ["session", "тренировк"]
            }
        case .duringEndurance:
            switch activityType {
            case .cycling:
                return ["bike", "pedal", "ride", "велосипед", "заезд", "крут"]
            case .running:
                return ["run", "miles", "legs", "пробеж", "бег", "ног"]
            default:
                return ["session", "live", "тренировк", "процесс"]
            }
        case .postEnduranceImmediate:
            switch activityType {
            case .cycling:
                return ["ride", "legs", "заезд", "ног"]
            case .running:
                return ["run", "heart", "пробеж", "пульс"]
            default:
                return ["session", "ended", "тренировк", "законч"]
            }
        case .activeStrength, .duringStrength:
            switch activityType {
            case .core:
                return ["core", "кор", "силов"]
            case .upperBody:
                return ["upper", "верх", "силов"]
            case .lowerBody:
                return ["lower", "ног", "силов"]
            default:
                return ["strength", "workout", "силов", "тренировк"]
            }
        case .postStrengthImmediate, .postStrengthSettled, .eveningAfterStrength:
            switch activityType {
            case .core:
                return ["core", "set", "кор", "подход", "силов"]
            default:
                return ["strength", "set", "силов", "подход", "мышц"]
            }
        case .activeRacket, .duringRacket, .postRacketImmediate, .postRacketSettled, .eveningAfterRacket:
            return ["tennis", "squash", "racket", "матч", "теннис", "сквош"]
        case .activeRecovery, .duringRecovery, .postRecoveryImmediate, .postRecoverySettled, .eveningAfterRecovery:
            switch activityType {
            case .yoga:
                return ["yoga", "йог"]
            case .stretching:
                return ["stretch", "растяж"]
            case .breathing:
                return ["breath", "дыхан"]
            default:
                return ["recovery", "восстанов"]
            }
        case .saunaPreparation, .saunaActive, .saunaRecovery:
            return ["sauna", "heat", "саун", "жар", "тепл"]
        case .walkLightDay:
            return ["easy walk", "walk", "прогулк", "лёгк"]
        case .walkAfterHeavyLoad:
            return ["recovery walk", "walk", "прогулк", "восстановительн", "settling"]
        case .walkEveningWindDown:
            return ["evening walk", "walk", "прогулк", "вечерн"]
        case .walkRecoveryAction:
            return ["recovery walk", "walk", "прогулк", "восстанов"]
        default:
            return []
        }
    }

    private static func joinedEnglish(_ section: CoachV6CopySection) -> String {
        section.lines.map(\.english).joined(separator: " ")
    }

    private static func joinedRussian(_ section: CoachV6CopySection) -> String {
        section.lines.map(\.russian).joined(separator: " ")
    }
}
