import Foundation

/// Ensures scenario remains the narrative owner — metrics support, never headline.
enum CoachCopySubjectGuard {

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

    private static let walkScenarios: Set<CoachScenarioKey> = [
        .walkLightDay,
        .walkAfterHeavyLoad,
        .walkEveningWindDown,
        .walkRecoveryAction
    ]

    static func requiresScenarioSubject(_ scenario: CoachScenarioKey) -> Bool {
        !subjectTokens(scenario: scenario, activityType: .none).isEmpty
    }

    static func assessmentStartsWithScenarioSubject(
        pack: CoachCopyPack,
        scenario: CoachScenarioKey,
        activityType: CoachActivityType
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

    static func mainSectionsAvoidMetricHero(pack: CoachCopyPack) -> Bool {
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
        scenario: CoachScenarioKey,
        activityType: CoachActivityType
    ) -> Bool {
        let tokens = subjectTokens(scenario: scenario, activityType: activityType)
        return tokens.contains { assessment.contains($0) }
    }

    private static func subjectTokens(
        scenario: CoachScenarioKey,
        activityType: CoachActivityType
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
            return ["tennis", "squash", "racket", "match", "court", "матч", "теннис", "сквош", "игр", "корт"]
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
        case .tomorrowProtection:
            return ["banked", "tonight", "load", "нагрузк", "достаточно", "берег"]
        case .protectTomorrowFresh:
            return ["tomorrow", "recovery", "calendar", "завтра", "восстанов", "календар"]
        case .recoveryAfterHeavyYesterday:
            return ["yesterday", "recovery", "legs", "вчера", "восстанов", "ног"]
        case .lowRecoveryPrep:
            return ["training", "recovery", "endurance", "match", "тренировк", "восстанов", "игр"]
        default:
            return []
        }
    }

    private static func joinedEnglish(_ section: CoachCopySection) -> String {
        section.lines.map(\.english).joined(separator: " ")
    }

    private static func joinedRussian(_ section: CoachCopySection) -> String {
        section.lines.map(\.russian).joined(separator: " ")
    }
}
