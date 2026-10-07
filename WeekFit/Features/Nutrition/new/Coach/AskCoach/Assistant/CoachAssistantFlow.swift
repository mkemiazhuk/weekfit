import Foundation
import WeekFitPlanner

/// Deterministic branching flow. Domain analysis stays in `CoachAssistantScenarioAnalyzer`.
enum CoachAssistantFlow {

    struct Input {
        var node: CoachAssistantNodeID
        var choiceID: String?
        var feeling: CoachFeelingKind?
        var clarification: CoachFeelingClarification?
        var evidence: CoachAssistantEvidenceBundle
        var analysisContext: CoachAssistantScenarioAnalyzer.Context
        var weekBundle: AskCoachPeriodBundle?
        var recoveryVitals: CoachAssistantRecoveryVitals? = nil
        var givenName: String?
        var answeredChoiceIDs: [String] = []
        var memory: CoachAssistantMemoryState = .empty
        var signals: CoachAssistantSignalSnapshot? = nil
    }

    static func advance(_ input: Input) -> CoachAssistantNodeOutput {
        // Topic navigation is never “an answer” to the current branch.
        // Route it from mindAsk even if the view model still has a stuck branch nodeID.
        if input.node != .mindAsk, let choiceID = input.choiceID {
            if choiceID == "end.another" {
                return mindAsk(from: input, includePrompt: false)
            }
            if isTopicChoiceID(choiceID) {
                var routed = input
                routed.node = .mindAsk
                return handleMindChoice(routed)
            }
        }

        switch input.node {
        case .feelingAsk:
            return handleFeelingSelection(input)
        case .tiredClarify:
            return handleTiredClarify(input)
        case .feelingReflect:
            return mindAsk(from: input)
        case .mindAsk:
            return handleMindChoice(input)
        case .activityGate:
            return activityGate(input)
        case .activityToday:
            return activityToday(input)
        case .activityRecent:
            return activityRecent(input)
        case .activityConsistency:
            return activityConsistency(input)
        case .activityPlanConfirm:
            return activityPlanConfirm(input)
        case .nutritionGate:
            return nutritionGate(input)
        case .nutritionMenu:
            return nutritionMenu(input)
        case .nutritionRemaining:
            return nutritionRemaining(input)
        case .nutritionChooseMeal:
            return nutritionChooseMeal(input)
        case .nutritionHabits:
            return nutritionHabits(input)
        case .recoveryGate:
            return recoveryGate(input)
        case .recoveryToday:
            return recoveryToday(input)
        case .recoveryDuration:
            return recoveryDurationPrompt(input)
        case .recoveryPattern:
            return recoveryPattern(input)
        case .recoveryNextStep:
            return recoveryNextStep(input)
        case .end:
            return endedOutput(input)
        }
    }

    // MARK: - Feeling

    static func feelingChoices() -> [CoachAssistantChoice] {
        CoachFeelingKind.allCases.map { feeling in
            CoachAssistantChoice(
                id: "feeling.\(feeling.rawValue)",
                title: feeling.bilingualTitle,
                destination: .feelingReflect
            )
        }
    }

    private static func handleFeelingSelection(_ input: Input) -> CoachAssistantNodeOutput {
        if let choiceID = input.choiceID,
           choiceID.hasPrefix("followup.")
            || choiceID.hasPrefix("recovery.energy.")
            || choiceID.hasPrefix("nutrition.log.")
            || choiceID == "nutrition.mealIdea" {
            return handleFollowUpChoice(input)
        }
        if input.choiceID == "open.signal.ease" || input.choiceID == "activity.proposeEase" {
            return activityPlanConfirm(input)
        }

        // Restore / reopen with no new choice — re-offer feeling chips only.
        if input.choiceID == nil, input.feeling == nil {
            return CoachAssistantNodeOutput(
                coachTurns: [],
                choices: feelingChoices(),
                updatedEvidence: nil,
                feeling: nil,
                clarification: nil,
                area: nil,
                ended: false,
                preview: nil
            )
        }

        let feeling: CoachFeelingKind = {
            switch input.choiceID {
            case "feeling.energized": return .energized
            case "feeling.okay": return .okay
            case "feeling.tired": return .tired
            case "feeling.low": return .low
            default: return input.feeling ?? .okay
            }
        }()

        return buildReflection(feeling: feeling, clarification: nil, input: input)
    }

    private static func handleFollowUpChoice(_ input: Input) -> CoachAssistantNodeOutput {
        switch input.choiceID {
        case "followup.ease.wentWell", "followup.ease.feltGood":
            return CoachAssistantNodeOutput(
                coachTurns: [
                    .init(
                        role: .coach,
                        text: CoachAssistantCopy.bi(
                            "Good to hear. What would help next?",
                            "Хорошо слышать. Что дальше будет полезно?"
                        ),
                        nodeID: .mindAsk
                    )
                ],
                choices: orderedAreaChoices(input),
                updatedEvidence: nil,
                feeling: input.feeling,
                clarification: input.clarification,
                area: .activity,
                ended: false,
                preview: nil,
                questionID: "followup.ease.wentWell",
                clearPriorFollowUp: true
            )
        case "followup.ease.skipped", "followup.ease.feltHard":
            return CoachAssistantNodeOutput(
                coachTurns: [
                    .init(
                        role: .coach,
                        text: CoachAssistantCopy.bi(
                            "Understood. Recovery or today’s plan — what should we look at?",
                            "Понял. Восстановление или сегодняшний план — что смотрим?"
                        ),
                        nodeID: .mindAsk
                    )
                ],
                choices: orderedAreaChoices(input),
                updatedEvidence: nil,
                feeling: input.feeling,
                clarification: input.clarification,
                area: .recovery,
                ended: false,
                preview: nil,
                questionID: "followup.ease.skipped",
                clearPriorFollowUp: true
            )
        case "followup.ease.stillDeciding":
            return activityGate(input)
        case "followup.nutrition.yes", "nutrition.mealIdea":
            return nutritionChooseMeal(input)
        case "followup.nutrition.no", "followup.nutrition.other", "followup.recovery.other", "recovery.energy.notStarted":
            return mindAsk(from: input, includePrompt: false)
        case "recovery.energy.lower":
            return recoveryEnergyLowerFollowUp(input)
        case "recovery.energy.normal":
            return recoveryEnergyNormalFollowUp(input)
        case "followup.recovery.yes":
            // Retired weekly-focus path — open Recovery today instead of a focus review.
            return recoveryToday(input)
        case "nutrition.log.complete.yes":
            return nutritionChooseMeal(input)
        case "nutrition.log.complete.no":
            return CoachAssistantNodeOutput(
                coachTurns: [
                    .init(
                        role: .coach,
                        text: CoachAssistantCopy.bi(
                            "Got it. Want a simple meal idea anyway?",
                            "Понял. Нужна простая идея еды всё равно?"
                        ),
                        nodeID: .nutritionChooseMeal
                    )
                ],
                choices: [
                    .init(
                        id: "nutrition.mealIdea",
                        title: CoachAssistantCopy.bi("Yes", "Да"),
                        destination: .nutritionChooseMeal
                    ),
                    .init(
                        id: "end.another",
                        title: CoachAssistantCopy.bi("No", "Нет"),
                        destination: .mindAsk
                    )
                ],
                updatedEvidence: nil,
                feeling: input.feeling,
                clarification: input.clarification,
                area: .nutrition,
                ended: false,
                preview: nil,
                questionID: "nutrition.log.incomplete"
            )
        default:
            return mindAsk(from: input, includePrompt: false)
        }
    }

    private static func orderedAreaChoices(_ input: Input) -> [CoachAssistantChoice] {
        let signals = input.signals ?? signalSnapshot(from: input)
        let order = CoachAssistantInsightBuilder.orderedAreas(
            feeling: input.feeling,
            signals: signals,
            prefer: CoachAssistantInsightBuilder.preferArea(feeling: input.feeling, signals: signals)
        )
        return CoachAssistantCopy.areaStarterChoices(order: order)
    }

    private static func signalSnapshot(from input: Input) -> CoachAssistantSignalSnapshot {
        CoachAssistantSignalSnapshot.build(
            checkInAt: input.analysisContext.checkInAt,
            observations: input.analysisContext.observations,
            plannedActivities: input.analysisContext.plannedActivities,
            nutrition: input.analysisContext.nutrition,
            recentActivityCount: input.analysisContext.recentActivityCount,
            healthKitAuthorized: input.analysisContext.healthAccessGranted
        )
    }

    private static func tiredClarifyChoices() -> [CoachAssistantChoice] {
        CoachFeelingClarification.allCases.map { item in
            CoachAssistantChoice(
                id: "clarify.\(item.rawValue)",
                title: item.bilingualTitle,
                destination: .feelingReflect
            )
        } + [
            CoachAssistantChoice(
                id: "clarify.skip",
                title: CoachAssistantCopy.bi("Skip", "Пропустить"),
                destination: .feelingReflect,
                action: .skipCheckIn
            )
        ]
    }

    private static func handleTiredClarify(_ input: Input) -> CoachAssistantNodeOutput {
        let clarification: CoachFeelingClarification? = {
            switch input.choiceID {
            case "clarify.lowEnergy": return .lowEnergy
            case "clarify.soreMuscles": return .soreMuscles
            case "clarify.sleepiness": return .sleepiness
            default: return nil
            }
        }()
        let feeling = input.feeling ?? .tired
        return buildReflection(feeling: feeling, clarification: clarification, input: input)
    }

    private static func buildReflection(
        feeling: CoachFeelingKind,
        clarification: CoachFeelingClarification?,
        input: Input
    ) -> CoachAssistantNodeOutput {
        var context = input.analysisContext
        context.feeling = feeling
        context.clarification = clarification
        let reflected = CoachAssistantScenarioAnalyzer.reflect(context)
        var evidence = input.evidence
        evidence.feelingOutcome = reflected.outcome
        evidence.feelingEvidence = reflected.evidence
        evidence.reflectionHeadline = reflected.text
        evidence.reflectionExplanation = reflected.text
        evidence.reflectionFacts = reflected.facts
        evidence.analysisVersion = CoachFeelingEvidenceRules.analysisVersion

        if let nutrition = context.nutrition {
            evidence.nutritionCaloriesCurrent = nutrition.caloriesCurrent
            evidence.nutritionCaloriesGoal = nutrition.caloriesGoal
            evidence.nutritionProteinCurrent = nutrition.proteinCurrent
            evidence.nutritionProteinGoal = nutrition.proteinGoal
            evidence.nutritionMealsLogged = nutrition.mealsCount ?? 0
        }

        let flags = CoachAssistantScenarioAnalyzer.todayActivityFlags(
            plannedActivities: context.plannedActivities,
            now: context.checkInAt
        )
        evidence.hasPlannedWorkoutToday = flags.hasPlannedWorkout
        evidence.hasCompletedActivityToday = flags.hasCompletedActivity

        let todayKey = CoachDailyObservation.dayKey(for: context.checkInAt)
        let signals = input.signals ?? signalSnapshot(from: input)
        let insight = CoachAssistantInsightBuilder.afterFeeling(
            feeling: feeling,
            signals: signals,
            memory: input.memory,
            todayKey: todayKey
        )
        let choices = insight.choices
            ?? CoachAssistantCopy.areaStarterChoices(
                order: CoachAssistantInsightBuilder.orderedAreas(
                    feeling: feeling,
                    signals: signals,
                    prefer: insight.preferArea
                )
            )

        let turn = CoachAssistantTurn(
            role: .coach,
            text: insight.text,
            nodeID: .mindAsk
        )

        return CoachAssistantNodeOutput(
            coachTurns: [turn],
            choices: Array(choices.prefix(3)),
            updatedEvidence: evidence,
            feeling: feeling,
            clarification: clarification,
            area: insight.preferArea,
            ended: false,
            preview: insight.text,
            questionID: insight.insightID,
            recommendationID: insight.recommendationID,
            followUp: insight.followUp
        )
    }

    private static func isTopicChoiceID(_ choiceID: String) -> Bool {
        choiceID == "mind.nutrition"
            || choiceID.hasPrefix("mind.nutrition.")
            || choiceID == "mind.recovery"
            || choiceID.hasPrefix("mind.recovery.")
            || choiceID == "mind.activity"
            || choiceID.hasPrefix("mind.activity.")
    }

    /// True when the latest choice is an explicit topic pick / Other topic — gates must not replay.
    private static func isFreshTopicEntry(_ input: Input) -> Bool {
        guard let last = input.answeredChoiceIDs.last else { return false }
        return last == "end.another" || isTopicChoiceID(last)
    }

    private static func mindAsk(from input: Input, includePrompt: Bool = true) -> CoachAssistantNodeOutput {
        // “Other topic” — show topic chips only. Navigation, not a semantic answer.
        let turns: [CoachAssistantTurn] = includePrompt
            ? [.init(role: .coach, text: CoachAssistantCopy.topicPickPrompt(), nodeID: .mindAsk)]
            : []
        return CoachAssistantNodeOutput(
            coachTurns: turns,
            choices: orderedAreaChoices(input),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: nil,
            clearsArea: true,
            nextNodeID: .mindAsk,
            ended: false,
            preview: nil,
            questionID: includePrompt ? "mind.topicPick" : "mind.topicPick.silent"
        )
    }

    private static func handleMindChoice(_ input: Input) -> CoachAssistantNodeOutput {
        // Intent chips from the feeling turn — go straight to the useful next step.
        switch input.choiceID {
        case "nutrition.mealIdea", "followup.nutrition.yes":
            return nutritionChooseMeal(input)
        case "nutrition.remaining":
            return nutritionRemaining(input)
        case "mind.recovery":
            // Fresh Recovery topic entry — never resume a prior recovery.idea recommendation.
            return recoveryToday(input)
        case "activity.decideTrain", "activity.howHard", "activity.todayBrief",
             "activity.reviewIntensity":
            return activityToday(input)
        case "activity.recent":
            return activityRecent(input)
        case "activity.consistency":
            return activityConsistency(input)
        case "activity.effort.easy", "activity.effort.moderate", "activity.effort.hard", "activity.effort.unsure":
            // Legacy chips — redirect to past-focused trend brief.
            return activityCompletedBranch(input)
        case "activity.reviewTomorrow", "activity.proposeEase":
            return activityPlanConfirm(input)
        case "recovery.energy.normal":
            return recoveryEnergyNormalFollowUp(input)
        case "recovery.energy.lower":
            return recoveryEnergyLowerFollowUp(input)
        case "recovery.idea", "recovery.next":
            var routed = input
            routed.node = .recoveryToday
            routed.choiceID = nil
            return recoveryToday(routed)
        case "end.done", "activity.keepEffort":
            return endedOutput(input)
        case "end.another":
            return mindAsk(from: input, includePrompt: false)
        default:
            break
        }
        if let choiceID = input.choiceID, choiceID.hasPrefix("activity.select.") {
            return activityAlreadyLoggedAsk(input, forceQuestionOnly: false)
        }

        let destination: CoachAssistantNodeID = {
            switch input.choiceID {
            case "mind.nutrition", "mind.nutrition.enough", "mind.nutrition.around", "mind.nutrition.habits":
                return .nutritionGate
            case "mind.recovery", "mind.recovery.pattern", "mind.recovery.working", "mind.recovery.today":
                return .recoveryGate
            case "mind.activity", "mind.activity.easy", "mind.activity.approach",
                 "mind.activity.recent", "mind.activity.working", "mind.activity.consistency":
                return .activityGate
            default:
                return input.node
            }
        }()
        if destination == .mindAsk {
            return mindAsk(from: input, includePrompt: false)
        }
        var next = input
        next.node = destination
        // Clear choiceID so gates run their entry path. Freshness comes from answeredChoiceIDs
        // (last id is still mind.* / end.another from the view model).
        next.choiceID = nil
        return advance(next)
    }

    // MARK: - Activity

    private static func activityGate(_ input: Input) -> CoachAssistantNodeOutput {
        switch input.choiceID {
        case "activity.todayBrief", "activity.decideTrain", "activity.howHard", "activity.reviewIntensity":
            return activityToday(input)
        case "activity.recent":
            return activityRecent(input)
        case "activity.consistency":
            return activityConsistency(input)
        case "activity.effort.easy", "activity.effort.moderate", "activity.effort.hard", "activity.effort.unsure":
            return activityCompletedBranch(input)
        default:
            break
        }
        if let choiceID = input.choiceID, choiceID.hasPrefix("activity.select.") {
            return activityCompletedBranch(input)
        }

        // After an explicit topic switch, never replay a prior Activity answer.
        if !isFreshTopicEntry(input) {
            let answered = Set(input.answeredChoiceIDs)
            if answered.contains("activity.todayTrend")
                || answered.contains(where: { $0.hasPrefix("activity.effort.") })
                || answered.contains("activity.todayBrief") {
                return activityCompletedBranch(input)
            }
            if answered.contains("activity.recent") {
                return activityRecent(input)
            }
            if answered.contains("activity.consistency") {
                return activityConsistency(input)
            }
        }

        let signals = input.signals ?? signalSnapshot(from: input)
        if signals.todayCompletedSignificant
            || !todayCompletedSignificantActivities(from: input).isEmpty {
            return activityCompletedBranch(input)
        }
        return activityTrendGate(input)
    }

    private static func activityToday(_ input: Input) -> CoachAssistantNodeOutput {
        if input.choiceID == "activity.proposeEase" || input.choiceID == "activity.reviewTomorrow" {
            // Legacy forward actions — keep available if an old chip fires, but Activity entry itself stays past-focused.
            return activityPlanConfirm(input)
        }
        if input.choiceID == "activity.recent" {
            return activityRecent(input)
        }
        if input.choiceID == "activity.consistency" {
            return activityConsistency(input)
        }
        switch input.choiceID {
        case "activity.effort.easy", "activity.effort.moderate", "activity.effort.hard", "activity.effort.unsure":
            return activityCompletedBranch(input)
        default:
            break
        }

        let signals = input.signals ?? signalSnapshot(from: input)
        if signals.todayCompletedSignificant
            || !todayCompletedSignificantActivities(from: input).isEmpty {
            return activityCompletedBranch(input)
        }

        let result = CoachAssistantScenarioAnalyzer.activityToday(
            feeling: input.feeling,
            context: input.analysisContext
        )
        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: result.text,
                    nodeID: .activityToday
                )
            ],
            choices: CoachAssistantCopy.activityTrendFollowUpChoices(),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .activity,
            ended: false,
            preview: result.text,
            questionID: "activity.todayTrend"
        )
    }

    private static func hasShownActivityLogged(_ input: Input) -> Bool {
        let todayKey = CoachDailyObservation.dayKey(for: input.analysisContext.checkInAt)
        let day = CoachAssistantMemoryStore.day(todayKey, in: input.memory)
        let questions = Set(day?.questionIDs ?? [])
        let recs = Set(day?.recommendationIDs ?? [])
        return questions.contains("activity.alreadyLogged")
            || questions.contains("activity.effort.ask")
            || questions.contains("activity.todayTrend")
            || recs.contains("data.activity.loggedToday")
    }

    private static func todayCompletedSignificantActivities(
        from input: Input
    ) -> [CoachPlannedActivitySnapshot] {
        let calendar = Calendar.current
        let checkIn = input.analysisContext.checkInAt
        return input.analysisContext.plannedActivities
            .map(CoachPlannedActivitySnapshot.init)
            .filter {
                calendar.isDate($0.date, inSameDayAs: checkIn)
                    && $0.isCompleted
                    && !$0.isSkipped
                    && CoachActivityClassification.isLoggedMovement($0)
            }
            .sorted { $0.date > $1.date }
    }

    private static func selectedCompletedActivityID(from input: Input) -> String? {
        let ids = input.answeredChoiceIDs + [input.choiceID].compactMap { $0 }
        guard let raw = ids.last(where: { $0.hasPrefix("activity.select.") }) else { return nil }
        let id = String(raw.dropFirst("activity.select.".count))
        return id.isEmpty ? nil : id
    }

    private static func resolvedCompletedActivity(
        from input: Input
    ) -> CoachPlannedActivitySnapshot? {
        let completed = todayCompletedSignificantActivities(from: input)
        guard !completed.isEmpty else { return nil }
        if let selectedID = selectedCompletedActivityID(from: input),
           let match = completed.first(where: { $0.id == selectedID }) {
            return match
        }
        return completed.count == 1 ? completed[0] : nil
    }

    /// Completed movement: past-focused trend brief — no effort questionnaire.
    private static func activityCompletedBranch(_ input: Input) -> CoachAssistantNodeOutput {
        let completed = todayCompletedSignificantActivities(from: input)
        if completed.isEmpty {
            return activityTrendGate(input)
        }

        let calendar = Calendar.current
        let plannedRemaining = input.analysisContext.plannedActivities.filter {
            calendar.isDate($0.date, inSameDayAs: input.analysisContext.checkInAt)
                && !$0.isCompleted && !$0.isSkipped
                && CoachActivityClassification.isLoggedMovement(
                    CoachPlannedActivitySnapshot(from: $0)
                )
        }
        let trend = CoachAssistantScenarioAnalyzer.activityTodayTrend(
            completed: completed,
            plannedRemaining: plannedRemaining,
            observations: input.analysisContext.observations,
            checkInAt: input.analysisContext.checkInAt
        )
        return CoachAssistantNodeOutput(
            coachTurns: [.init(role: .coach, text: trend.text, nodeID: .activityToday)],
            choices: CoachAssistantCopy.activityTrendFollowUpChoices(),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .activity,
            ended: false,
            preview: trend.text,
            questionID: "activity.todayTrend",
            recommendationID: "data.activity.loggedToday"
        )
    }

    private static func activityTrendGate(_ input: Input) -> CoachAssistantNodeOutput {
        let result = CoachAssistantScenarioAnalyzer.activityToday(
            feeling: input.feeling,
            context: input.analysisContext
        )
        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: result.text,
                    nodeID: .activityGate
                )
            ],
            choices: CoachAssistantCopy.activityGateChoices(),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .activity,
            ended: false,
            preview: result.text,
            questionID: "gate.activity"
        )
    }

    private static func activityPickSession(
        _ input: Input,
        activities: [CoachPlannedActivitySnapshot]
    ) -> CoachAssistantNodeOutput {
        _ = activities
        return activityCompletedBranch(input)
    }

    /// Effort questionnaire retired — stay on past trends.
    private static func activityAlreadyLoggedAsk(
        _ input: Input,
        forceQuestionOnly: Bool
    ) -> CoachAssistantNodeOutput {
        _ = forceQuestionOnly
        return activityCompletedBranch(input)
    }

    private static func activityRecent(_ input: Input) -> CoachAssistantNodeOutput {
        let summary: (text: CoachBilingualText, facts: [CoachBilingualText])
        if let bundle = input.weekBundle {
            summary = CoachAssistantScenarioAnalyzer.activityRecentSummary(bundle: bundle)
        } else {
            summary = CoachAssistantScenarioAnalyzer.activityRecentSummaryFromPlanner(
                plannedActivities: input.analysisContext.plannedActivities,
                checkInAt: input.analysisContext.checkInAt
            )
        }
        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: CoachAssistantCopy.bubbleText(summary.text, detail: summary.facts.first),
                    nodeID: .activityRecent
                )
            ],
            choices: CoachAssistantCopy.activityHistoryFollowUpChoices(),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .activity,
            ended: false,
            preview: summary.text,
            questionID: "activity.recent"
        )
    }

    private static func activityConsistency(_ input: Input) -> CoachAssistantNodeOutput {
        let summary: (text: CoachBilingualText, facts: [CoachBilingualText])
        if let bundle = input.weekBundle {
            summary = CoachAssistantScenarioAnalyzer.activityConsistencySummary(bundle: bundle)
        } else {
            summary = CoachAssistantScenarioAnalyzer.activityConsistencySummaryFromPlanner(
                plannedActivities: input.analysisContext.plannedActivities,
                checkInAt: input.analysisContext.checkInAt
            )
        }
        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: CoachAssistantCopy.bubbleText(summary.text, detail: summary.facts.first),
                    nodeID: .activityConsistency
                )
            ],
            choices: CoachAssistantCopy.activityHistoryFollowUpChoices(),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .activity,
            ended: false,
            preview: summary.text,
            questionID: "activity.consistency"
        )
    }

    private static func activityPlanConfirm(_ input: Input) -> CoachAssistantNodeOutput {
        let confirm = input.choiceID == "activity.confirmEase"
        let text: CoachBilingualText
        if confirm {
            text = CoachAssistantCopy.bi(
                "Got it — open today’s Plan review to confirm any change. Coach won’t alter your Plan by itself.",
                "Хорошо — откройте просмотр Плана на сегодня, чтобы подтвердить изменение. Coach сам План не меняет."
            )
        } else if input.choiceID == "activity.proposeEase"
                    || input.choiceID == "open.signal.ease"
                    || input.choiceID == nil {
            text = CoachAssistantCopy.bi(
                "A lighter day can be reasonable given today’s signals. Confirm if you want a Plan suggestion — Coach won’t change your Plan without that review.",
                "Более лёгкий день может быть уместен с учётом сегодняшних сигналов. Подтвердите идею для Плана — без этого просмотра Coach План не меняет."
            )
            return CoachAssistantNodeOutput(
                coachTurns: [
                    .init(role: .coach, text: text, nodeID: .activityPlanConfirm)
                ],
                choices: [
                    CoachAssistantChoice(
                        id: "activity.confirmEase",
                        title: CoachAssistantCopy.reviewPlanSuggestionTitle(),
                        destination: .end,
                        action: .proposePlanEase
                    ),
                    CoachAssistantChoice(
                        id: "activity.keepPlan",
                        title: CoachAssistantCopy.bi("Keep my Plan", "Оставить мой План"),
                        destination: .end
                    )
                ],
                updatedEvidence: nil,
                feeling: input.feeling,
                clarification: input.clarification,
                area: .activity,
                ended: false,
                preview: text,
                recommendationID: "rec.easePlan",
                followUp: .easierSession
            )
        } else {
            text = CoachAssistantCopy.bi(
                "Keeping your Plan as is. You can always revisit Coach later.",
                "Оставляем План как есть. К Coach можно вернуться позже."
            )
        }
        return CoachAssistantNodeOutput(
            coachTurns: [.init(role: .coach, text: text, nodeID: .activityPlanConfirm)],
            choices: CoachAssistantCopy.closingChoices(includeOtherArea: true),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .activity,
            ended: false,
            preview: text
        )
    }

    // MARK: - Nutrition

    private static func nutritionGate(_ input: Input) -> CoachAssistantNodeOutput {
        switch input.choiceID {
        case "nutrition.helpChoose", "nutrition.mealIdea":
            return nutritionChooseMeal(input)
        case "nutrition.remaining":
            return nutritionRemaining(input)
        case "nutrition.habits":
            return nutritionHabits(input)
        default:
            break
        }
        // Fresh Nutrition topic entry after Other topic / mind.nutrition — always start clean.
        if !isFreshTopicEntry(input) {
            let answered = Set(input.answeredChoiceIDs)
            if answered.contains("nutrition.helpChoose") || answered.contains("nutrition.mealIdea") {
                return nutritionChooseMeal(input)
            }
            if answered.contains("nutrition.remaining") {
                return nutritionRemaining(input)
            }
        }
        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: CoachAssistantCopy.nutritionGateQuestion(),
                    nodeID: .nutritionGate
                )
            ],
            choices: CoachAssistantCopy.nutritionGateChoices(),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .nutrition,
            nextNodeID: .nutritionGate,
            ended: false,
            preview: nil,
            questionID: "gate.nutrition"
        )
    }

    private static func nutritionMenu(_ input: Input) -> CoachAssistantNodeOutput {
        // Legacy entry — same gate question, then area-specific follow-ups.
        return nutritionGate(input)
    }

    private static func nutritionRemaining(_ input: Input) -> CoachAssistantNodeOutput {
        let result = CoachAssistantScenarioAnalyzer.nutritionRemaining(
            nutrition: input.analysisContext.nutrition
        )
        var choices = CoachAssistantCopy.closingChoices()
        if result.needsGoals {
            choices.insert(
                CoachAssistantChoice(
                    id: "nutrition.openGoals",
                    title: CoachAssistantCopy.openProfileGoalsChoiceTitle(),
                    destination: .end,
                    action: .openGoalSettings
                ),
                at: 0
            )
        } else {
            choices.insert(
                CoachAssistantChoice(
                    id: "nutrition.openMeals",
                    title: CoachAssistantCopy.openMealsChoiceTitle(),
                    destination: .end,
                    action: .openMealsTab
                ),
                at: 0
            )
        }
        // Live nutrition snapshot for this answer only — do not mix with frozen reflection totals.
        let text: CoachBilingualText = {
            // Prefer the mid-day / near-goal summary when it carries concrete figures.
            let summary = result.text
            if summary.english.contains("So far")
                || summary.english.contains("close to your targets")
                || summary.russian.contains("Пока:")
                || summary.russian.contains("К этому моменту")
                || summary.russian.contains("близко к ориентирам")
                || summary.russian.contains("близок к вашим ориентирам") {
                return summary
            }
            if let fact = result.facts.first,
               fact.english.contains("left") || fact.english.contains("over") || fact.english.contains("of")
                || fact.russian.contains("остал") || fact.russian.contains("выше") || fact.russian.contains("из") {
                return fact
            }
            return summary
        }()
        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: text,
                    nodeID: .nutritionRemaining
                )
            ],
            choices: choices,
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .nutrition,
            ended: false,
            preview: text,
            followUp: .nutritionProtein,
            skipTypingDelay: false,
            navigationAction: nil
        )
    }

    private static func nutritionChooseMeal(_ input: Input) -> CoachAssistantNodeOutput {
        let signals = input.signals ?? signalSnapshot(from: input)
        var memory = input.memory
        let answered = Set(input.answeredChoiceIDs)
        let choiceID = input.choiceID

        // Scenario E — incomplete log: ask a clear yes/no before suggesting food.
        if choiceID == "nutrition.log.complete.no" {
            return CoachAssistantNodeOutput(
                coachTurns: [
                    .init(
                        role: .coach,
                        text: CoachAssistantCopy.bi(
                            "Got it. Want a simple meal idea anyway?",
                            "Понял. Нужна простая идея еды всё равно?"
                        ),
                        nodeID: .nutritionChooseMeal
                    )
                ],
                choices: [
                    .init(
                        id: "nutrition.mealIdea",
                        title: CoachAssistantCopy.bi("Yes", "Да"),
                        destination: .nutritionChooseMeal
                    ),
                    .init(
                        id: "end.another",
                        title: CoachAssistantCopy.bi("No", "Нет"),
                        destination: .mindAsk
                    )
                ],
                updatedEvidence: nil,
                feeling: input.feeling,
                clarification: input.clarification,
                area: .nutrition,
                ended: false,
                preview: nil,
                questionID: "nutrition.log.incomplete"
            )
        }

        // Scenario E — ask once when completeness would change the advice.
        let needsCompletenessCheck =
            signals.nutritionKnown
            && signals.proteinBelowGoal
            && !signals.isEarlyDayNutrition
            && signals.nutritionMealsLogged <= 1
            && !answered.contains("nutrition.log.complete.yes")
            && !answered.contains("nutrition.log.complete.no")
            && choiceID != "nutrition.meal.another"
            && choiceID != "nutrition.diet.regular"
            && choiceID != "nutrition.diet.vegetarian"

        if needsCompletenessCheck {
            return CoachAssistantNodeOutput(
                coachTurns: [
                    .init(
                        role: .coach,
                        text: CoachAssistantCopy.bi(
                            "Is today’s food log up to date?",
                            "Дневник еды за сегодня уже актуален?"
                        ),
                        nodeID: .nutritionChooseMeal
                    )
                ],
                choices: [
                    .init(
                        id: "nutrition.log.complete.yes",
                        title: CoachAssistantCopy.bi("Yes", "Да"),
                        destination: .nutritionChooseMeal
                    ),
                    .init(
                        id: "nutrition.log.complete.no",
                        title: CoachAssistantCopy.bi("No", "Нет"),
                        destination: .nutritionChooseMeal
                    )
                ],
                updatedEvidence: nil,
                feeling: input.feeling,
                clarification: input.clarification,
                area: .nutrition,
                ended: false,
                preview: nil,
                questionID: "nutrition.log.completeness"
            )
        }

        if choiceID == "nutrition.diet.regular" {
            memory.prefersVegetarian = false
        } else if choiceID == "nutrition.diet.vegetarian" {
            memory.prefersVegetarian = true
        }

        let skipDietAsk =
            choiceID == "nutrition.meal.another"
            || choiceID == "nutrition.diet.regular"
            || choiceID == "nutrition.diet.vegetarian"
            || answered.contains("nutrition.diet.regular")
            || answered.contains("nutrition.diet.vegetarian")
            || answered.contains("nutrition.log.complete.no")
            || memory.prefersVegetarian != nil

        if !skipDietAsk {
            return CoachAssistantNodeOutput(
                coachTurns: [
                    .init(
                        role: .coach,
                        text: CoachAssistantCopy.bi(
                            "Any preference for the suggestion?",
                            "Какой стиль блюда предпочтительнее?"
                        ),
                        nodeID: .nutritionChooseMeal
                    )
                ],
                choices: CoachAssistantMealAdvisor.dietPreferenceChoices(),
                updatedEvidence: nil,
                feeling: input.feeling,
                clarification: input.clarification,
                area: .nutrition,
                ended: false,
                preview: nil,
                questionID: "nutrition.diet.preference"
            )
        }

        let trustProteinGap = !answered.contains("nutrition.log.complete.no")
        let proteinLeft: Int? = {
            guard trustProteinGap,
                  let goal = signals.nutritionProteinGoal,
                  let current = signals.nutritionProteinCurrent else { return nil }
            return max(0, Int((goal - current).rounded()))
        }()

        var excluding = memory.offeredMealIDs
        if choiceID != "nutrition.meal.another" {
            // First suggestion in this turn may still avoid recently offered meals.
            excluding = Array(memory.offeredMealIDs.suffix(3))
        }

        let option = CoachAssistantMealAdvisor.suggest(
            preferVegetarian: memory.prefersVegetarian,
            excludingIDs: excluding,
            proteinRemaining: proteinLeft,
            hour: signals.hour
        )

        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: option.text,
                    nodeID: .nutritionChooseMeal
                )
            ],
            choices: CoachAssistantMealAdvisor.afterSuggestionChoices(),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .nutrition,
            ended: false,
            preview: option.text,
            questionID: option.id,
            recommendationID: option.id,
            followUp: .nutritionProtein
        )
    }

    private static func nutritionHabits(_ input: Input) -> CoachAssistantNodeOutput {
        let result = CoachAssistantScenarioAnalyzer.nutritionHabits(
            observations: input.analysisContext.observations,
            checkInAt: input.analysisContext.checkInAt
        )
        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: CoachAssistantCopy.bubbleText(result.text, detail: result.facts.first),
                    nodeID: .nutritionHabits
                )
            ],
            choices: CoachAssistantCopy.closingChoices(),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .nutrition,
            ended: false,
            preview: result.text
        )
    }

    // MARK: - Recovery

    /// After recovery-conflict: user said energy is lower — advance without restating the score.
    private static func recoveryEnergyLowerFollowUp(_ input: Input) -> CoachAssistantNodeOutput {
        let signals = input.signals ?? signalSnapshot(from: input)
        let hasPlan = signals.todayPlannedSignificant && !signals.todayCompletedSignificant
        let text = CoachAssistantMessageFormatter.compose(
            CoachAssistantCopy.bi(
                "Got it — thanks for saying that.",
                "Понял — спасибо, что сказали."
            ),
            CoachAssistantCopy.bi(
                hasPlan
                    ? "We can look at sleep and recovery, or review today’s plan."
                    : "Shall we look at sleep and recovery next?",
                hasPlan
                    ? "Можно посмотреть сон и восстановление или сегодняшний план."
                    : "Посмотрим сон и восстановление?"
            )
        )

        var choices: [CoachAssistantChoice] = [
            .init(
                id: "mind.recovery",
                title: CoachAssistantCopy.bi("Recovery", "Восстановление"),
                destination: .recoveryGate
            )
        ]
        if hasPlan {
            choices.insert(
                .init(
                    id: "activity.proposeEase",
                    title: CoachAssistantCopy.bi("Review plan", "Смотреть план"),
                    destination: .activityPlanConfirm
                ),
                at: 0
            )
        } else {
            choices.append(
                .init(
                    id: "end.another",
                    title: CoachAssistantCopy.bi("Other topic", "Другая тема"),
                    destination: .mindAsk
                )
            )
        }
        if choices.count < 3 {
            choices.append(
                .init(
                    id: "end.done",
                    title: CoachAssistantCopy.bi("Done", "Готово"),
                    destination: .end
                )
            )
        }

        return CoachAssistantNodeOutput(
            coachTurns: [.init(role: .coach, text: text, nodeID: .recoveryToday)],
            choices: Array(choices.prefix(3)),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .recovery,
            ended: false,
            preview: text,
            questionID: "recovery.energy.lower.ack",
            recommendationID: "data.recovery.belowBaseline"
        )
    }

    /// Energy feels normal despite lower recovery — don’t dismiss the score or invent readiness.
    private static func recoveryEnergyNormalFollowUp(_ input: Input) -> CoachAssistantNodeOutput {
        let signals = input.signals ?? signalSnapshot(from: input)
        let hasPlan = signals.todayPlannedSignificant && !signals.todayCompletedSignificant
        let text = CoachAssistantMessageFormatter.compose(
            CoachAssistantCopy.bi(
                "Got it — energy feels normal so far.",
                "Понял — энергия пока ощущается обычной."
            ),
            CoachAssistantCopy.bi(
                hasPlan
                    ? "Keep today’s plan if it still feels right once you start, or review it first."
                    : "No need to invent extra work. Want another topic, or are you set?",
                hasPlan
                    ? "Можно оставить сегодняшний план, если при старте всё нормально, или сначала посмотреть его."
                    : "Лишнюю нагрузку придумывать не нужно. Другая тема или на этом всё?"
            )
        )
        var choices: [CoachAssistantChoice] = []
        if hasPlan {
            choices.append(
                .init(
                    id: "activity.decideTrain",
                    title: CoachAssistantCopy.bi("Review session", "Смотреть сессию"),
                    destination: .activityToday
                )
            )
        }
        choices.append(
            .init(
                id: "end.another",
                title: CoachAssistantCopy.bi("Other topic", "Другая тема"),
                destination: .mindAsk
            )
        )
        choices.append(
            .init(
                id: "end.done",
                title: CoachAssistantCopy.bi("Done", "Готово"),
                destination: .end
            )
        )
        return CoachAssistantNodeOutput(
            coachTurns: [.init(role: .coach, text: text, nodeID: .activityToday)],
            choices: Array(choices.prefix(3)),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .activity,
            ended: false,
            preview: text,
            questionID: "recovery.energy.normal.ack",
            recommendationID: "data.recovery.belowBaseline"
        )
    }

    private static func recoveryGate(_ input: Input) -> CoachAssistantNodeOutput {
        switch input.choiceID {
        case "recovery.justToday", "recovery.nights":
            return recoveryToday(input)
        case "recovery.fewDays":
            return recoveryPattern(input)
        default:
            break
        }
        // Fresh Recovery entry goes straight to sleep / HRV / RHR brief.
        return recoveryToday(input)
    }

    private static func hasShownRecoveryBelowBaseline(_ input: Input) -> Bool {
        let answered = Set(input.answeredChoiceIDs)
        if answered.contains("recovery.energy.lower")
            || answered.contains("recovery.energy.normal")
            || answered.contains("recovery.energy.notStarted") {
            return true
        }
        let todayKey = CoachDailyObservation.dayKey(for: input.analysisContext.checkInAt)
        let day = CoachAssistantMemoryStore.day(todayKey, in: input.memory)
        let questions = Set(day?.questionIDs ?? [])
        let recs = Set(day?.recommendationIDs ?? [])
        return questions.contains("insight.recovery.conflict")
            || questions.contains("recovery.energy.lower.ack")
            || recs.contains("data.recovery.belowBaseline")
    }

    private static func recoveryToday(_ input: Input) -> CoachAssistantNodeOutput {
        // Legacy “Recovery idea” chip → sleep / HRV brief (not walk suggestions).
        if input.choiceID == "recovery.next" || input.choiceID == "recovery.idea" {
            var routed = input
            routed.choiceID = nil
            return recoveryToday(routed)
        }
        if input.choiceID == "recovery.nights" {
            return recoveryNights(input)
        }
        if input.choiceID == "recovery.duration" {
            return recoveryDurationPrompt(input)
        }
        // Energy answers must not fall through into a score restatement.
        if input.choiceID == "recovery.energy.lower" {
            return recoveryEnergyLowerFollowUp(input)
        }
        if input.choiceID == "recovery.energy.normal" {
            return recoveryEnergyNormalFollowUp(input)
        }

        let signals = input.signals ?? signalSnapshot(from: input)
        var evidence = input.evidence.feelingEvidence
        let vitals = input.recoveryVitals
        // Prefer live signal snapshot when conversation evidence was empty at launch.
        if (evidence.recoveryPercent == nil || evidence.recoveryIsStale), signals.recoveryIsFresh {
            evidence.recoveryPercent = signals.recoveryPercent
            evidence.recoveryBaselinePercent = signals.recoveryBaselinePercent
                ?? evidence.recoveryBaselinePercent
            evidence.recoveryIsStale = false
        }
        if (evidence.sleepMinutes == nil || evidence.sleepIsStale), signals.sleepIsFresh {
            evidence.sleepMinutes = signals.sleepMinutes
            evidence.sleepBaselineMinutes = signals.sleepBaselineMinutes
                ?? evidence.sleepBaselineMinutes
            evidence.sleepIsStale = false
        }
        if let liveSleep = vitals?.sleepMinutes, liveSleep > 0 {
            evidence.sleepMinutes = liveSleep
            evidence.sleepIsStale = false
        }

        let hasSignals = (evidence.sleepMinutes != nil && !evidence.sleepIsStale)
            || (evidence.recoveryPercent != nil && !evidence.recoveryIsStale)
            || signals.sleepIsFresh
            || signals.recoveryIsFresh
            || (vitals?.hasAnySleepOrAutonomicSignal == true)
        if !hasSignals {
            let text = CoachAssistantCopy.unavailableHealthDataCopy(
                authorized: input.analysisContext.healthAccessGranted
            )
            return CoachAssistantNodeOutput(
                coachTurns: [.init(role: .coach, text: text, nodeID: .recoveryToday)],
                choices: CoachAssistantCopy.closingChoices(),
                updatedEvidence: nil,
                feeling: input.feeling,
                clarification: input.clarification,
                area: .recovery,
                ended: false,
                preview: text,
                questionID: "recovery.unavailable"
            )
        }

        let result = CoachAssistantScenarioAnalyzer.recoveryToday(
            evidence: evidence,
            vitals: vitals,
            preferSleep: true
        )
        let feeling = input.feeling
        let alreadyNotedConflict = hasShownRecoveryBelowBaseline(input)
        // Soft mismatch note only when derived score conflicts with feeling — keep sleep facts primary.
        // Skip if this conflict was already surfaced earlier today (anti-replay).
        let mismatchNote: CoachBilingualText? = {
            guard !alreadyNotedConflict,
                  signals.recoveryLowVsUsual,
                  feeling == .energized || feeling == .okay,
                  let recovery = evidence.recoveryPercent ?? signals.recoveryPercent,
                  let baseline = evidence.recoveryBaselinePercent ?? signals.recoveryBaselinePercent
            else { return nil }
            return CoachAssistantCopy.bi(
                "App recovery reading \(recovery)% is below your usual ~\(baseline)%, while you feel okay — we’ll note the gap without overriding how you feel.",
                "Показатель восстановления \(recovery)% ниже обычного ~\(baseline)%, при нормальном самочувствии — заметим расхождение, не споря с ощущением."
            )
        }()
        let text = CoachAssistantMessageFormatter.compose(
            [result.text, mismatchNote].compactMap { $0 }
        )
        var choices: [CoachAssistantChoice] = [
            .init(
                id: "recovery.nights",
                title: CoachAssistantCopy.bi("Last 7 nights", "7 ночей"),
                destination: .recoveryToday
            ),
            .init(
                id: "end.another",
                title: CoachAssistantCopy.bi("Other topic", "Другая тема"),
                destination: .mindAsk
            ),
            .init(
                id: "end.done",
                title: CoachAssistantCopy.bi("Done", "Готово"),
                destination: .end
            )
        ]
        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: text,
                    nodeID: .recoveryToday
                )
            ],
            choices: Array(choices.prefix(3)),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .recovery,
            ended: false,
            preview: text,
            questionID: alreadyNotedConflict ? "recovery.today.deduped" : "recovery.today.sleep",
            recommendationID: alreadyNotedConflict
                ? "data.recovery.sleepAutonomic.deduped"
                : "data.recovery.sleepAutonomic"
        )
    }

    private static func recoveryNights(_ input: Input) -> CoachAssistantNodeOutput {
        let summary: (text: CoachBilingualText, facts: [CoachBilingualText])
        if let bundle = input.weekBundle {
            summary = CoachAssistantScenarioAnalyzer.recoveryNightsSummary(bundle: bundle)
        } else {
            summary = (
                CoachAssistantCopy.bi(
                    "There isn’t enough sleep or HRV logged across the last 7 days to summarize yet.",
                    "За последние 7 дней пока мало записей сна или HRV для сводки."
                ),
                []
            )
        }
        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: CoachAssistantCopy.bubbleText(summary.text, detail: summary.facts.first),
                    nodeID: .recoveryToday
                )
            ],
            choices: CoachAssistantCopy.closingChoices(),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .recovery,
            ended: false,
            preview: summary.text,
            questionID: "recovery.nights"
        )
    }

    private static func recoveryDurationPrompt(_ input: Input) -> CoachAssistantNodeOutput {
        if input.choiceID == "recovery.justToday" || input.choiceID == "recovery.fewDays" {
            return recoveryPattern(input)
        }

        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: CoachAssistantCopy.bi(
                        "Does this feel new today, or has it been building?",
                        "Это новое сегодня или накапливалось?"
                    ),
                    nodeID: .recoveryDuration
                )
            ],
            choices: [
                CoachAssistantChoice(
                    id: "recovery.justToday",
                    title: CoachAssistantCopy.bi("Just today", "Только сегодня"),
                    destination: .recoveryPattern
                ),
                CoachAssistantChoice(
                    id: "recovery.fewDays",
                    title: CoachAssistantCopy.bi("For a few days", "Несколько дней"),
                    destination: .recoveryPattern
                )
            ],
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .recovery,
            ended: false,
            preview: nil
        )
    }

    private static func recoveryPattern(_ input: Input) -> CoachAssistantNodeOutput {
        if input.choiceID == "recovery.next" {
            return recoveryNextStep(input)
        }

        let justToday = input.choiceID == "recovery.justToday"
        let text: CoachBilingualText
        if justToday {
            text = CoachAssistantCopy.bi(
                "Treating this as mainly last night — I’ll stick to today’s recovery signals.",
                "Считаем, что дело в прошлой ночи — смотрю на сегодняшние сигналы восстановления."
            )
        } else {
            text = CoachAssistantCopy.bi(
                "If it’s been a few days, one night isn’t the whole story. Keep the next sessions lighter until sleep looks steadier.",
                "Если так уже несколько дней, одной ночи мало. Держите следующие сессии легче, пока сон не станет ровнее."
            )
        }
        let today = CoachAssistantScenarioAnalyzer.recoveryToday(
            evidence: input.evidence.feelingEvidence,
            vitals: input.recoveryVitals,
            preferSleep: true
        )
        // Prefer sleep / HRV facts when available.
        let combined = justToday ? today.text : CoachAssistantMessageFormatter.compose(text, today.text)
        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: combined,
                    nodeID: .recoveryPattern
                )
            ],
            choices: [
                CoachAssistantChoice(
                    id: "recovery.nights",
                    title: CoachAssistantCopy.bi("Last 7 nights", "7 ночей"),
                    destination: .recoveryToday
                )
            ] + CoachAssistantCopy.closingChoices(),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .recovery,
            ended: false,
            preview: combined
        )
    }

    private static func recoveryNextStep(_ input: Input) -> CoachAssistantNodeOutput {
        // Never treat a topic switch as “ask for another recovery idea.”
        if let choiceID = input.choiceID, choiceID == "end.another" || isTopicChoiceID(choiceID) {
            var routed = input
            routed.node = .mindAsk
            return advance(routed)
        }

        // Prefer the sleep / HRV brief over walk-oriented “ideas.”
        if input.choiceID == "recovery.idea" || input.choiceID == "recovery.next" {
            var routed = input
            routed.node = .recoveryToday
            routed.choiceID = nil
            return recoveryToday(routed)
        }

        let answered = Set(input.answeredChoiceIDs)
        let reportedLowerEnergy = answered.contains("recovery.energy.lower")
        let signals = input.signals ?? signalSnapshot(from: input)
        let hasPlan = signals.todayPlannedSignificant && !signals.todayCompletedSignificant

        if reportedLowerEnergy && input.choiceID == nil && !isFreshTopicEntry(input) {
            return recoveryIdeaSuggestion(
                input: input,
                hasPlan: hasPlan,
                energyLower: true
            )
        }

        let suggestion = CoachFeelingCopy.tryTodaySuggestion(
            feeling: input.feeling ?? .okay,
            outcome: input.evidence.feelingOutcome ?? .insufficient,
            evidence: input.evidence.feelingEvidence
        )
        let text = CoachAssistantMessageFormatter.compose(suggestion.explanation)
        return CoachAssistantNodeOutput(
            coachTurns: [
                .init(
                    role: .coach,
                    text: text,
                    nodeID: .recoveryNextStep
                )
            ],
            choices: CoachAssistantCopy.closingChoices(includeOtherArea: true),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .recovery,
            ended: false,
            preview: suggestion.explanation
        )
    }

    private static func recoveryIdeaSuggestion(
        input: Input,
        hasPlan: Bool,
        energyLower: Bool
    ) -> CoachAssistantNodeOutput {
        let completed = todayCompletedSignificantActivities(from: input)
        let walkMinutes = completed
            .filter { CoachActivityClassification.isWalkLike($0) || CoachActivityClassification.isHikeLike($0) }
            .reduce(0) { $0 + max(1, $1.effectiveDurationMinutes) }
        let alreadyWalkedALot = walkMinutes >= 45

        let text: CoachBilingualText
        var choices: [CoachAssistantChoice] = []

        if alreadyWalkedALot {
            text = CoachAssistantMessageFormatter.compose(
                CoachAssistantCopy.bi(
                    "You’ve already walked about \(walkMinutes) minutes today — another short walk probably isn’t what you need.",
                    "Сегодня уже около \(walkMinutes) минут ходьбы — ещё одна короткая прогулка вряд ли нужна."
                ),
                CoachAssistantCopy.bi(
                    energyLower
                        ? "Sleep and recovery readings are a better next look."
                        : "Want to check sleep and recovery instead?",
                    energyLower
                        ? "Лучше дальше посмотреть сон и восстановление."
                        : "Может, лучше посмотрим сон и восстановление?"
                )
            )
            choices.append(
                .init(
                    id: "mind.recovery",
                    title: CoachAssistantCopy.bi("Recovery", "Восстановление"),
                    destination: .recoveryGate
                )
            )
        } else if hasPlan {
            text = CoachAssistantMessageFormatter.compose(
                CoachAssistantCopy.bi(
                    energyLower
                        ? "There’s still a session on today’s plan. With lower energy, you might want to review it first — nothing changes until you confirm."
                        : "There’s still a session on today’s plan. You can review it if you want — nothing changes until you confirm.",
                    energyLower
                        ? "В плане на сегодня ещё есть сессия. При более низкой энергии можно сначала посмотреть план — ничего не меняется без подтверждения."
                        : "В плане на сегодня ещё есть сессия. Можно посмотреть план — ничего не меняется без подтверждения."
                )
            )
            choices.append(
                .init(
                    id: "activity.proposeEase",
                    title: CoachAssistantCopy.bi("Review plan", "Смотреть план"),
                    destination: .activityPlanConfirm
                )
            )
        } else {
            text = CoachAssistantMessageFormatter.compose(
                CoachAssistantCopy.bi(
                    "A slightly earlier wind-down tonight is a gentle option — no need for another workout.",
                    "Чуть более раннее вечернее затихание — мягкий вариант, без ещё одной тренировки."
                )
            )
            choices.append(
                .init(
                    id: "mind.recovery",
                    title: CoachAssistantCopy.bi("Recovery", "Восстановление"),
                    destination: .recoveryGate
                )
            )
        }

        choices.append(
            .init(
                id: "end.another",
                title: CoachAssistantCopy.bi("Other topic", "Другая тема"),
                destination: .mindAsk
            )
        )
        choices.append(
            .init(
                id: "end.done",
                title: CoachAssistantCopy.bi("Done", "Готово"),
                destination: .end
            )
        )

        return CoachAssistantNodeOutput(
            coachTurns: [.init(role: .coach, text: text, nodeID: .recoveryNextStep)],
            choices: Array(choices.prefix(3)),
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: .recovery,
            ended: false,
            preview: text,
            questionID: "recovery.idea.suggestion",
            recommendationID: alreadyWalkedALot
                ? "data.recovery.walkAlreadyLogged"
                : "rec.recoveryIdea"
        )
    }

    private static func endedOutput(_ input: Input) -> CoachAssistantNodeOutput {
        let text = CoachAssistantCopy.bi(
            "You’re all set.",
            "На этом всё."
        )
        return CoachAssistantNodeOutput(
            coachTurns: [.init(role: .coach, text: text, nodeID: .end)],
            choices: [
                CoachAssistantChoice(
                    id: "end.new",
                    title: CoachAssistantCopy.bi("Start a new conversation", "Начать новый разговор"),
                    destination: .feelingAsk,
                    action: .startNewConversation
                )
            ],
            updatedEvidence: nil,
            feeling: input.feeling,
            clarification: input.clarification,
            area: nil,
            ended: true,
            preview: text,
            skipTypingDelay: true
        )
    }
}
