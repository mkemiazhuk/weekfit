import Foundation
@testable import WeekFit

struct CoachDebugSnapshot {
    let checkpoint: String
    let action: String
    let now: Date
    let todayCards: [String]
    let coachHeadline: String
    let coachNextAction: String
    let coachExplanation: String
    let readinessScore: Int
    let readinessBreakdown: CoachReadinessScoreBreakdown
    let recoveryState: HumanBrain.RecoveryState
    let primaryLimiter: CoachLimiter
    let confidence: Double
    let hasMissingSleepData: Bool
    let plannedActivities: [String]
    let activeActivity: String?
    let completedActivities: [String]
    let partialActivities: [String]
    let cancelledActivities: [String]
    let meals: [String]
    let deletedMealIDs: Set<String>
    let drinks: [String]
    let hydrationPromptVisible: Bool
    let tomorrowProtection: Bool
    let tomorrowProtectionState: CoachTomorrowProtectionState
    let decisionTrace: String
    let plannerTrace: PlannerDebugTrace
    let recommendationTrace: String
    let rawStoredRecords: [String]
    let activityRecommendation: String
    let tomorrowProtectionReasons: [String]
    let decisionAudit: CoachDecisionAudit
    let guidance: CoachGuidanceV3
    let dayContext: CoachDayContext
    let activityContext: CoachDayActivityContext
    let nutritionContext: CoachNutritionContext
    let recoveryContext: CoachRecoveryContext

    var debugDescription: String {
        """
        checkpoint=\(checkpoint)
        action=\(action)
        now=\(now)
        todayCards=\(todayCards)
        coachHeadline=\(coachHeadline)
        coachNextAction=\(coachNextAction)
        coachExplanation=\(coachExplanation)
        readinessScore=\(readinessScore)
        readinessBreakdown=\(readinessBreakdown.debugDescription)
        recoveryState=\(recoveryState)
        primaryLimiter=\(primaryLimiter)
        confidence=\(String(format: "%.2f", confidence))
        hasMissingSleepData=\(hasMissingSleepData)
        plannedActivities=\(plannedActivities)
        activeActivity=\(activeActivity ?? "nil")
        completedActivities=\(completedActivities)
        partialActivities=\(partialActivities)
        cancelledActivities=\(cancelledActivities)
        meals=\(meals)
        deletedMealIDs=\(deletedMealIDs.sorted())
        drinks=\(drinks)
        hydrationPromptVisible=\(hydrationPromptVisible)
        tomorrowProtection=\(tomorrowProtection)
        tomorrowProtectionState=recommended:\(tomorrowProtectionState.recommended) active:\(tomorrowProtectionState.active) reasons:\(tomorrowProtectionState.reasons) activeReason:\(tomorrowProtectionState.activeReason ?? "nil")
        rawStoredRecords=\(rawStoredRecords)
        decisionTrace=\(decisionTrace)
        plannerTrace=\(plannerTrace.debugDescription)
        recommendationTrace=\(recommendationTrace)
        activityRecommendation=\(activityRecommendation)
        tomorrowProtectionReasons=\(tomorrowProtectionReasons)
        decisionAudit.rawInputs=\(decisionAudit.rawInputs)
        decisionAudit.normalizedValues=\(decisionAudit.normalizedValues)
        decisionAudit.scoringBreakdown=\(decisionAudit.scoringBreakdown)
        decisionAudit.finalDecision=\(decisionAudit.finalDecision)
        """
    }

    var inputSnapshot: CoachScenarioInputSnapshot {
        CoachScenarioInputSnapshot(
            currentTime: Self.timeString(now),
            sleepInput: hasMissingSleepData
                ? "missing / not synced"
                : "\(sleepLabel(recoveryContext.sleepHours)), \(Self.durationString(hours: recoveryContext.sleepHours))",
            mealsInput: meals,
            drinksInput: drinks,
            plannedActivities: plannedActivities,
            activeActivities: activeActivity.map { [$0] } ?? [],
            completedActivities: completedActivities,
            cancelledActivities: cancelledActivities,
            partialActivities: partialActivities,
            saunaState: saunaState,
            recoveryInputs: "recoveryPercent=\(recoveryContext.recoveryPercent), recoveryState=\(recoveryState)",
            hydrationInputs: "water=\(String(format: "%.2f", nutritionContext.waterCurrent))L / \(String(format: "%.2f", nutritionContext.waterGoal))L, drinks=\(drinks.count)",
            deletedItems: deletedMealIDs.sorted(),
            rawStoredRecords: rawStoredRecords
        )
    }

    var outputSnapshot: CoachScenarioOutputSnapshot {
        CoachScenarioOutputSnapshot(
            todayCards: todayCards,
            todayHeadline: guidance.insightTitle,
            coachHeadline: coachHeadline,
            coachNextAction: coachNextAction.isEmpty ? "none" : coachNextAction,
            coachExplanation: coachExplanation,
            readinessScore: readinessScore,
            readinessBreakdown: readinessBreakdown.debugDescription,
            recoveryState: "\(recoveryState)",
            primaryLimiter: primaryLimiter.label,
            confidenceAndMissingDataState: "confidence=\(String(format: "%.2f", confidence)), missingSleep=\(hasMissingSleepData)",
            hydrationPrompt: hydrationPromptState,
            nutritionPrompt: meals.isEmpty ? "visible: missing meal" : "hidden",
            activityRecommendation: activityRecommendation,
            tomorrowProtection: "recommended=\(tomorrowProtectionState.recommended), active=\(tomorrowProtectionState.active), reasons=\(tomorrowProtectionState.reasons), activeReason=\(tomorrowProtectionState.activeReason ?? "none")",
            plannerReservations: plannerTrace.reservedSlots.map {
                "\($0.title) \(Self.timeString($0.start))-\(Self.timeString($0.end)) duration=\($0.durationMinutes)m"
            },
            decisionTrace: decisionTrace,
            recommendationTrace: recommendationTrace,
            plannerTrace: plannerTrace.debugDescription
        )
    }

    var formattedCheckpointSnapshot: String {
        CoachScenarioSnapshotPrinter.formatCheckpoint(
            name: checkpoint,
            time: now,
            input: inputSnapshot,
            output: outputSnapshot,
            audit: decisionAudit
        )
    }

    private var hydrationPromptState: String {
        guard hydrationPromptVisible else { return "hidden" }

        let hydrationRatio = nutritionContext.waterGoal > 0
            ? nutritionContext.waterCurrent / nutritionContext.waterGoal
            : 1
        let saunaCompleted = dayContext.completedActivities.contains {
            $0.timelineEventKind == .sauna
        }

        if saunaCompleted, hydrationRatio >= 0.75 {
            return "visible: post-sauna recovery"
        }

        return "visible: hydration behind"
    }

    var formattedFailureAudit: String {
        """
        FAILED CHECKPOINT
        time: \(Self.timeString(now))
        user action: \(action)

        raw inputs:
        \(Self.bullets(decisionAudit.rawInputs))

        normalized inputs:
        \(Self.bullets(decisionAudit.normalizedValues))

        scoring breakdown:
        \(Self.bullets(decisionAudit.scoringBreakdown))

        readiness:
        \(readinessBreakdown.debugDescription)

        Today cards:
        \(Self.bullets(todayCards))

        Coach headline: \(coachHeadline)
        Coach next action: \(coachNextAction)
        Coach explanation: \(coachExplanation)

        planner reservations:
        \(Self.bullets(outputSnapshot.plannerReservations))

        decisionTrace:
        \(decisionTrace)

        recommendationTrace:
        \(recommendationTrace)

        plannerTrace:
        \(plannerTrace.debugDescription)
        """
    }

    private var saunaState: String {
        if completedActivities.contains("Sauna") { return "completed" }
        if activeActivity == "Sauna" { return "active" }
        if plannedActivities.contains("Sauna") { return "planned" }
        return "not present"
    }

    private func sleepLabel(_ hours: Double) -> String {
        if hours <= 0 { return "missing" }
        if hours < 5 { return "poor" }
        if hours < 6.5 { return "short" }
        return "available"
    }

    private static func durationString(hours: Double) -> String {
        let totalMinutes = max(0, Int((hours * 60).rounded()))
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private static func bullets(_ values: [String]) -> String {
        guard !values.isEmpty else { return "- none" }
        return values.map { "- \($0)" }.joined(separator: "\n")
    }
}
