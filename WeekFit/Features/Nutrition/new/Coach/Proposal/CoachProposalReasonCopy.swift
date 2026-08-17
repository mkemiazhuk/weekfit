import Foundation

/// Maps stable reason / guidance codes to localization keys (presentation only).
enum CoachProposalReasonCopy {

    static func reasonLocalizationKey(_ code: CoachProposalReasonCode) -> String {
        switch code {
        case .lowRecoveryLoadProtection:
            return "coach.proposal.reason.lowRecoveryLoadProtection"
        case .heavyYesterdayProtection:
            return "coach.proposal.reason.heavyYesterdayProtection"
        case .tomorrowDemandProtection:
            return "coach.proposal.reason.tomorrowDemandProtection"
        case .stackedDayRisk:
            return "coach.proposal.reason.stackedDayRisk"
        case .recoveryWalkSupport:
            return "coach.proposal.reason.recoveryWalkSupport"
        case .recoveryStretchSupport:
            return "coach.proposal.reason.recoveryStretchSupport"
        case .insufficientConfidence:
            return "coach.proposal.reason.insufficientConfidence"
        case .planAlreadyAppropriate:
            return "coach.proposal.reason.planAlreadyAppropriate"
        case .openDayMovementSupport:
            return "coach.proposal.reason.openDayMovementSupport"
        case .similarDaySupport:
            return "coach.proposal.reason.similarDaySupport"
        case .libraryMealSupport:
            return "coach.proposal.reason.libraryMealSupport"
        case .libraryMealRecoveryBreakfast:
            return "coach.proposal.reason.libraryMealRecoveryBreakfast"
        case .libraryMealRecoveryLunch:
            return "coach.proposal.reason.libraryMealRecoveryLunch"
        case .libraryMealRecoveryDinner:
            return "coach.proposal.reason.libraryMealRecoveryDinner"
        case .libraryMealSteadyBreakfast:
            return "coach.proposal.reason.libraryMealSteadyBreakfast"
        case .libraryMealSteadyLunch:
            return "coach.proposal.reason.libraryMealSteadyLunch"
        case .libraryMealSteadyDinner:
            return "coach.proposal.reason.libraryMealSteadyDinner"
        case .weatherOutdoorConflict:
            return "coach.proposal.reason.weatherOutdoorConflict"
        case .weatherHeatLoad:
            return "coach.proposal.reason.weatherHeatLoad"
        }
    }

    static func guidanceLocalizationKey(_ code: CoachGuidanceCode) -> String {
        switch code {
        case .easeIntoFirstEffort:
            return "coach.proposal.guidance.easeIntoFirstEffort"
        case .fuelBeforeSession:
            return "coach.proposal.guidance.fuelBeforeSession"
        case .hydrateThroughMorning:
            return "coach.proposal.guidance.hydrateThroughMorning"
        case .protectTomorrowFreshness:
            return "coach.proposal.guidance.protectTomorrowFreshness"
        case .listenToBodyOnLowReadiness:
            return "coach.proposal.guidance.listenToBodyOnLowReadiness"
        case .morningFuelWithoutLibrary:
            return "coach.proposal.guidance.morningFuelWithoutLibrary"
        case .morningFuelGentleRecovery:
            return "coach.proposal.guidance.morningFuelGentleRecovery"
        case .morningFuelSteadyEnergy:
            return "coach.proposal.guidance.morningFuelSteadyEnergy"
        case .preferIndoorOrEarlier:
            return "coach.proposal.guidance.preferIndoorOrEarlier"
        case .easeOutdoorHeat:
            return "coach.proposal.guidance.easeOutdoorHeat"
        case .shelteredRoutesWind:
            return "coach.proposal.guidance.shelteredRoutesWind"
        case .warmUpInCold:
            return "coach.proposal.guidance.warmUpInCold"
        }
    }

    static func localizedReason(_ code: CoachProposalReasonCode) -> String {
        let key = reasonLocalizationKey(code)
        let value = WeekFitLocalizedString(key)
        return value == key ? englishReason(code) : value
    }

    static func localizedGuidance(_ code: CoachGuidanceCode) -> String {
        let key = guidanceLocalizationKey(code)
        let value = WeekFitLocalizedString(key)
        return value == key ? englishGuidance(code) : value
    }

    static func englishReason(_ code: CoachProposalReasonCode) -> String {
        switch code {
        case .lowRecoveryLoadProtection:
            return "Recovery is lower, so today’s load should be protected."
        case .heavyYesterdayProtection:
            return "Yesterday was demanding — keep today lighter."
        case .tomorrowDemandProtection:
            return "Tomorrow already looks demanding."
        case .stackedDayRisk:
            return "Today’s plan is stacked; reduce or redistribute load."
        case .recoveryWalkSupport:
            return "A short easy walk after a hard day helps the legs without stacking more training."
        case .recoveryStretchSupport:
            return "Easy stretching after hard days helps the body settle without more training load."
        case .insufficientConfidence:
            return "Signals are incomplete — move carefully today."
        case .planAlreadyAppropriate:
            return "Today’s plan already looks appropriate."
        case .openDayMovementSupport:
            return "Nothing is planned yet — a light start fits today’s readiness."
        case .similarDaySupport:
            return "A similar past day with matching readiness suggests this shape."
        case .libraryMealSupport:
            return "This meal matches today’s timing and what you usually eat."
        case .libraryMealRecoveryBreakfast:
            return "A gentle protein breakfast gives recovery something to work with after yesterday."
        case .libraryMealRecoveryLunch:
            return "Yesterday was a hard load — lunch refills energy without another training session."
        case .libraryMealRecoveryDinner:
            return "Protein at dinner supports overnight repair after yesterday’s effort."
        case .libraryMealSteadyBreakfast:
            return "A steady breakfast keeps energy even before the day picks up."
        case .libraryMealSteadyLunch:
            return "Lunch holds energy through the afternoon without forcing a heavy session."
        case .libraryMealSteadyDinner:
            return "Dinner closes the day with enough protein so tomorrow doesn’t start depleted."
        case .weatherOutdoorConflict:
            return "Outdoor conditions look rough — shift or ease the outdoor session."
        case .weatherHeatLoad:
            return "Heat raises perceived effort outdoors — shorten or cool the session."
        }
    }

    static func englishGuidance(_ code: CoachGuidanceCode) -> String {
        switch code {
        case .easeIntoFirstEffort:
            return "Ease into the first effort and adjust by feel."
        case .fuelBeforeSession:
            return "Have a small carb snack before training if you feel flat."
        case .hydrateThroughMorning:
            return "Sip water through the morning."
        case .protectTomorrowFreshness:
            return "Protect freshness for tomorrow’s sessions."
        case .listenToBodyOnLowReadiness:
            return "Listen to your body and keep intensity conservative."
        case .morningFuelWithoutLibrary:
            return "No saved meals yet — start with a balanced breakfast this morning to keep energy steady."
        case .morningFuelGentleRecovery:
            return "Recovery is soft — begin with an easy protein-forward breakfast and keep portions gentle."
        case .morningFuelSteadyEnergy:
            return "Before today’s effort, eat a simple carb-and-protein breakfast so energy holds."
        case .preferIndoorOrEarlier:
            return "Rain or storms look likely — prefer an indoor option or an earlier outdoor slot."
        case .easeOutdoorHeat:
            return "It’s hot outside — ease outdoor load and hydrate well."
        case .shelteredRoutesWind:
            return "Strong wind today — choose sheltered routes if you stay outdoors."
        case .warmUpInCold:
            return "Cold conditions — warm up thoroughly and dress in layers."
        }
    }
}
