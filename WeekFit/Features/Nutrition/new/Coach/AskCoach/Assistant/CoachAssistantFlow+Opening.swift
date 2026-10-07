import Foundation
import WeekFitPlanner

extension CoachAssistantFlow {

    /// Memory-aware open. Fresh daily check-ins use a short greeting only.
    static func bootstrap(
        givenName: String?,
        memory: CoachAssistantMemoryState = .empty,
        signals: CoachAssistantSignalSnapshot? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CoachAssistantNodeOutput {
        var calendar = calendar
        calendar.timeZone = TimeZone.current
        let todayKey = CoachDailyObservation.dayKey(for: now, calendar: calendar)
        let resolvedSignals = signals ?? .build(
            checkInAt: now,
            observations: [],
            plannedActivities: [],
            nutrition: nil,
            recentActivityCount: 0,
            healthKitAuthorized: nil,
            calendar: calendar
        )
        let recentQuestions = CoachAssistantMemoryStore.recentQuestionIDs(memory, excludingDayKey: todayKey)
        let opening = CoachAssistantInsightBuilder.openingInsight(
            signals: resolvedSignals,
            memory: memory,
            todayKey: todayKey,
            recentQuestionIDs: recentQuestions
        )

        let openingLine = CoachAssistantCopy.checkInOpening(
            givenName: givenName,
            memory: memory,
            todayKey: todayKey,
            date: now,
            calendar: calendar
        )
        let greeting = openingLine.text

        switch opening.mode {
        case .askFollowUp:
            guard let insight = opening.insight else { break }
            // Every new conversation today starts with a greeting, then the follow-up question.
            return CoachAssistantNodeOutput(
                coachTurns: [
                    .init(role: .coach, text: greeting, nodeID: .feelingAsk),
                    .init(role: .coach, text: insight.text, nodeID: .feelingAsk)
                ],
                choices: insight.choices ?? followUpChoices(for: insight.followUp),
                updatedEvidence: nil,
                feeling: nil,
                clarification: nil,
                area: insight.preferArea,
                nextNodeID: .feelingAsk,
                ended: false,
                preview: insight.text,
                questionID: insight.insightID,
                recommendationID: insight.recommendationID,
                followUp: insight.followUp
            )

        case .acknowledgeFollowUp:
            guard let insight = opening.insight else { break }
            return CoachAssistantNodeOutput(
                coachTurns: [
                    .init(role: .coach, text: greeting, nodeID: .feelingAsk),
                    .init(role: .coach, text: insight.text, nodeID: .feelingAsk)
                ],
                choices: insight.choices ?? orderedAreaChoices(
                    feeling: nil,
                    signals: resolvedSignals
                ),
                updatedEvidence: nil,
                feeling: nil,
                clarification: nil,
                area: insight.preferArea,
                nextNodeID: .feelingAsk,
                ended: false,
                preview: insight.text,
                questionID: insight.insightID,
                clearPriorFollowUp: true
            )

        case .quietReturn, .signalLed, .standardFeeling:
            break
        }

        return CoachAssistantNodeOutput(
            coachTurns: [.init(role: .coach, text: greeting, nodeID: .feelingAsk)],
            choices: feelingChoices(),
            updatedEvidence: nil,
            feeling: nil,
            clarification: nil,
            area: nil,
            nextNodeID: .feelingAsk,
            ended: false,
            preview: greeting,
            questionID: openingLine.id
        )
    }

    private static func orderedAreaChoices(
        feeling: CoachFeelingKind?,
        signals: CoachAssistantSignalSnapshot
    ) -> [CoachAssistantChoice] {
        let order = CoachAssistantInsightBuilder.orderedAreas(
            feeling: feeling,
            signals: signals,
            prefer: CoachAssistantInsightBuilder.preferArea(feeling: feeling, signals: signals)
        )
        return CoachAssistantCopy.areaStarterChoices(order: order)
    }

    private static func followUpChoices(for kind: CoachAssistantFollowUpKind?) -> [CoachAssistantChoice] {
        switch kind {
        case .easierSession:
            return [
                .init(
                    id: "followup.ease.wentWell",
                    title: CoachAssistantCopy.bi("Yes", "Да"),
                    destination: .activityToday
                ),
                .init(
                    id: "followup.ease.skipped",
                    title: CoachAssistantCopy.bi("No", "Нет"),
                    destination: .mindAsk
                ),
                .init(
                    id: "followup.ease.stillDeciding",
                    title: CoachAssistantCopy.bi("Changed plans", "Планы изменились"),
                    destination: .activityGate
                )
            ]
        case .nutritionProtein:
            return [
                .init(
                    id: "followup.nutrition.yes",
                    title: CoachAssistantCopy.bi("Yes", "Да"),
                    destination: .nutritionChooseMeal
                ),
                .init(
                    id: "followup.nutrition.no",
                    title: CoachAssistantCopy.bi("No", "Нет"),
                    destination: .mindAsk
                )
            ]
        case .recoveryFocus:
            // Retired weekly-focus follow-up — fall back to a normal feeling check-in.
            return feelingChoices()
        case nil:
            return feelingChoices()
        }
    }
}
