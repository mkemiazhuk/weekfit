import Foundation

// MARK: - Fueling Domain

enum CoachFuelingPhase {
    case before
    case during
    case after
}

enum CoachFuelingActivityProfile: Equatable {
    case endurance(EnduranceKind)
    case racket(RacketKind)
    case strength
    case heat
    case recovery
    case breathing
    case other

    enum EnduranceKind: Equatable {
        case running
        case cycling
        case general
    }

    enum RacketKind: Equatable {
        case tennis
        case squash
        case general
    }
}

enum CoachFuelingNeed: Hashable {
    case waterBefore
    case waterDuring
    case waterAfter

    case portableSnackBefore
    case portableSnackDuring
    case lightFoodBefore

    case electrolytesBefore
    case electrolytesDuring
    case electrolytesAfter

    case proteinAfter
    case recoveryMealAfter
    case normalMealAfter

    case noSpecialFood
    case avoidHeavyFood
}

struct CoachFuelingRuleSet {
    let profile: CoachFuelingActivityProfile
    let phase: CoachFuelingPhase
    let isLong: Bool
    let isHard: Bool
    let isVeryCloseToStart: Bool
    let needsProteinRecovery: Bool
}

enum CoachFuelingRuleResolver {

    static func needs(
        for ruleSet: CoachFuelingRuleSet
    ) -> [CoachFuelingNeed] {

        switch (ruleSet.profile, ruleSet.phase) {

        // MARK: Running

        case (.endurance(.running), .before):
            if ruleSet.isLong || ruleSet.isHard {
                return ruleSet.isVeryCloseToStart
                    ? [.waterBefore, .portableSnackBefore, .electrolytesBefore]
                    : [.waterBefore, .lightFoodBefore, .electrolytesBefore]
            }

            return [.waterBefore, .avoidHeavyFood, .portableSnackBefore]

        case (.endurance(.running), .during):
            if ruleSet.isLong || ruleSet.isHard {
                return [.waterDuring, .portableSnackDuring, .electrolytesDuring]
            }

            return [.waterDuring, .noSpecialFood]

        case (.endurance(.running), .after):
            return [.waterAfter, .proteinAfter, .normalMealAfter]

        // MARK: Cycling

        case (.endurance(.cycling), .before):
            if ruleSet.isLong || ruleSet.isHard {
                return [.waterBefore, .portableSnackBefore, .electrolytesBefore]
            }

            return [.waterBefore, .portableSnackBefore, .avoidHeavyFood]

        case (.endurance(.cycling), .during):
            if ruleSet.isLong || ruleSet.isHard {
                return [.waterDuring, .portableSnackDuring, .electrolytesDuring]
            }

            return [.waterDuring, .noSpecialFood]

        case (.endurance(.cycling), .after):
            return [.waterAfter, .proteinAfter, .recoveryMealAfter]

        // MARK: General endurance

        case (.endurance(.general), .before):
            return ruleSet.isLong || ruleSet.isHard
                ? [.waterBefore, .portableSnackBefore, .electrolytesBefore]
                : [.waterBefore, .avoidHeavyFood]

        case (.endurance(.general), .during):
            return ruleSet.isLong || ruleSet.isHard
                ? [.waterDuring, .portableSnackDuring, .electrolytesDuring]
                : [.waterDuring]

        case (.endurance(.general), .after):
            return [.waterAfter, .proteinAfter, .normalMealAfter]

        // MARK: Tennis

        case (.racket(.tennis), .before):
            return ruleSet.isLong || ruleSet.isHard
                ? [.waterBefore, .portableSnackBefore, .electrolytesBefore]
                : [.waterBefore, .portableSnackBefore]

        case (.racket(.tennis), .during):
            return ruleSet.isLong || ruleSet.isHard
                ? [.waterDuring, .electrolytesDuring, .portableSnackDuring]
                : [.waterDuring, .electrolytesDuring]

        case (.racket(.tennis), .after):
            return [.waterAfter, .proteinAfter, .normalMealAfter]

        // MARK: Squash

        case (.racket(.squash), .before):
            return [.waterBefore, .portableSnackBefore, .electrolytesBefore]

        case (.racket(.squash), .during):
            return [.waterDuring, .electrolytesDuring, .portableSnackDuring]

        case (.racket(.squash), .after):
            return [.waterAfter, .proteinAfter, .electrolytesAfter]

        // MARK: General racket

        case (.racket(.general), .before):
            return [.waterBefore, .portableSnackBefore]

        case (.racket(.general), .during):
            return [.waterDuring, .electrolytesDuring]

        case (.racket(.general), .after):
            return [.waterAfter, .proteinAfter]

        // MARK: Strength

        case (.strength, .before):
            return [.waterBefore, .lightFoodBefore, .avoidHeavyFood]

        case (.strength, .during):
            return [.waterDuring, .noSpecialFood]

        case (.strength, .after):
            return [.proteinAfter, .waterAfter, .normalMealAfter]

        // MARK: Heat

        case (.heat, .before):
            return [.waterBefore, .electrolytesBefore, .avoidHeavyFood]

        case (.heat, .during):
            return [.waterDuring]

        case (.heat, .after):
            return [.waterAfter, .electrolytesAfter]

        // MARK: Recovery

        case (.recovery, .before):
            return [.waterBefore, .noSpecialFood]

        case (.recovery, .during):
            return [.waterDuring]

        case (.recovery, .after):
            return [.waterAfter]

        // MARK: Breathing / Mindfulness

        case (.breathing, .before):
            return []

        case (.breathing, .during):
            return []

        case (.breathing, .after):
            return []

        // MARK: Other

        case (.other, .before):
            return [.waterBefore, .avoidHeavyFood]

        case (.other, .during):
            return [.waterDuring]

        case (.other, .after):
            return [.waterAfter, .normalMealAfter]
        }
    }
}
