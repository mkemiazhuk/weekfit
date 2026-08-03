import Foundation

/// Builds the daily plan consultation from existing Coach state and planned activities.
/// Presentation-only: does not change the recommendation engine or invent health signals.
enum CoachTodayPlanConsultationBuilder {

    // MARK: - Eligibility

    static func canPresent(from state: CoachState) -> Bool {
        build(from: state) != nil
    }

    static func build(from state: CoachState) -> CoachTodayPlanConsultationPresentation? {
        guard let ui = state.coachUIPresentation else { return nil }
        guard let input = state.input else { return nil }
        guard isAdjustScenario(ui.scenario) else { return nil }

        let readiness = CoachDayReadinessResolver.resolve(from: input)
        let upcoming = upcomingTraining(from: input)
        guard !upcoming.isEmpty else { return nil }

        let russian = WeekFitUsesRussianLanguage()
        let primary = upcoming[0]
        let secondaryHeavy = upcoming.dropFirst().first(where: isSeriousTraining)

        let reason = primaryReason(readiness: readiness, input: input, russian: russian)
        let changeItems = buildChangeItems(
            primary: primary,
            secondaryHeavy: secondaryHeavy,
            russian: russian
        )
        let timeline = buildTimelineItems(
            primary: primary,
            secondaryHeavy: secondaryHeavy,
            readiness: readiness,
            input: input,
            russian: russian
        )
        let note = coachingNote(for: primary, russian: russian)
        let summary = summaryCopy(
            primary: primary,
            readiness: readiness,
            input: input,
            russian: russian
        )

        return CoachTodayPlanConsultationPresentation(
            eyebrow: WeekFitLocalizedString("coach.todayPlan.eyebrow"),
            headline: WeekFitLocalizedString("coach.todayPlan.headline.reduceLoad"),
            summary: summary,
            reasonLabel: WeekFitLocalizedString("coach.todayPlan.reasonLabel"),
            reasonValue: reason,
            changesLabel: WeekFitLocalizedString("coach.todayPlan.changesLabel"),
            changesValue: changesCountValue(changeItems.count, russian: russian),
            changesSectionTitle: WeekFitLocalizedString("coach.todayPlan.changesSection"),
            changeItems: changeItems,
            timelineSectionTitle: WeekFitLocalizedString("coach.todayPlan.timelineSection"),
            timelineItems: timeline,
            noteSectionTitle: WeekFitLocalizedString("coach.todayPlan.noteSection"),
            noteHeadline: note.headline,
            noteBody: note.body,
            primaryCTATitle: WeekFitLocalizedString("coach.todayPlan.cta.apply"),
            secondaryCTATitle: WeekFitLocalizedString("coach.todayPlan.cta.keepCurrent"),
            scenario: ui.scenario
        )
    }

    // MARK: - Scenario gate

    private static func isAdjustScenario(_ scenario: CoachScenarioKey) -> Bool {
        scenario == .lowRecoveryPrep
    }

    // MARK: - Activities

    private static func upcomingTraining(from input: CoachInputSnapshot) -> [CoachPlannedActivitySnapshot] {
        let calendar = Calendar.current
        return input.plannedActivities
            .filter { calendar.isDate($0.date, inSameDayAs: input.selectedDate) }
            .filter { !$0.isSkipped && !$0.isCompleted }
            .filter { isTrainingCandidate($0) }
            .sorted { $0.date < $1.date }
    }

    private static func isTrainingCandidate(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        switch CoachActivityClassifier.type(for: activity) {
        case .none:
            return CoachActivityClassification.isSignificantWorkout(activity)
                || CoachActivityClassification.isWalkLike(activity)
                || CoachActivityClassification.isRecoveryTier(activity)
        case .cycling, .running, .swimming, .tennis, .squash,
             .upperBody, .lowerBody, .core, .fullBody,
             .walk, .stretching, .yoga, .breathing, .sauna:
            return true
        }
    }

    private static func isSeriousTraining(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        CoachActivityClassifier.isSeriousTraining(activity)
            || CoachActivityClassification.isSignificantWorkout(activity)
    }

    // MARK: - Copy

    private static func primaryReason(
        readiness: CoachDayReadiness,
        input: CoachInputSnapshot,
        russian: Bool
    ) -> String {
        if readiness.recoveryDataAvailable, readiness.isLowRecovery {
            return WeekFitLocalizedString("coach.todayPlan.reason.recoveryBelowUsual")
        }
        if readiness.recoveryDataAvailable, readiness.sleepIsLow {
            return WeekFitLocalizedString("coach.todayPlan.reason.sleepWorse")
        }
        if input.brain.past.hasHighActivityLoad || input.brain.past.completedWorkoutsCount >= 1 {
            return WeekFitLocalizedString("coach.todayPlan.reason.recentLoad")
        }
        if DayPriorityModel.build(from: input).tomorrowDemand == .hard
            || DayPriorityModel.build(from: input).tomorrowDemand == .moderate {
            return WeekFitLocalizedString("coach.todayPlan.reason.tomorrowLoad")
        }
        // Fallback still grounded in the adjust scenario itself.
        return WeekFitLocalizedString("coach.todayPlan.reason.recoveryBelowUsual")
    }

    private static func summaryCopy(
        primary: CoachPlannedActivitySnapshot,
        readiness: CoachDayReadiness,
        input: CoachInputSnapshot,
        russian: Bool
    ) -> String {
        let title = CoachWorkoutTitleLocalization.displayTitle(primary.title, russian: russian)
        let phraseTitle = russian
            ? CoachWorkoutTitleLocalization.russianPhraseTitle(primary.title)
            : title

        let tomorrow = DayPriorityModel.build(from: input).tomorrowDemand
        if tomorrow == .hard || tomorrow == .moderate {
            return russian
                ? "Восстановление ниже обычного, поэтому оставим \(phraseTitle) и сохраним умеренную интенсивность — это поможет не перегружать день перед завтрашней нагрузкой."
                : "Recovery is below usual, so we’ll keep \(title) and hold a moderate intensity — that helps avoid overloading the day before tomorrow’s work."
        }

        if readiness.sleepIsLow, readiness.recoveryDataAvailable {
            return russian
                ? "Сон был хуже обычного, поэтому оставим \(phraseTitle) и сохраним умеренную интенсивность."
                : "Sleep was worse than usual, so we’ll keep \(title) and hold a moderate intensity."
        }

        return russian
            ? "Восстановление ниже обычного, поэтому оставим \(phraseTitle) и сохраним умеренную интенсивность."
            : "Recovery is below usual, so we’ll keep \(title) and hold a moderate intensity."
    }

    private static func buildChangeItems(
        primary: CoachPlannedActivitySnapshot,
        secondaryHeavy: CoachPlannedActivitySnapshot?,
        russian: Bool
    ) -> [CoachTodayPlanChangeItem] {
        let primaryTitle = CoachWorkoutTitleLocalization.displayTitle(primary.title, russian: russian)
        var items: [CoachTodayPlanChangeItem] = [
            CoachTodayPlanChangeItem(
                id: "keep-\(primary.id)",
                kind: .keep,
                title: russian
                    ? "\(primaryTitle) оставить"
                    : "Keep \(primaryTitle)"
            ),
            CoachTodayPlanChangeItem(
                id: "adjust-intensity-\(primary.id)",
                kind: .adjust,
                title: WeekFitLocalizedString("coach.todayPlan.change.reduceIntensity")
            )
        ]

        if let secondaryHeavy {
            let secondaryTitle = CoachWorkoutTitleLocalization.displayTitle(
                secondaryHeavy.title,
                russian: russian
            )
            items.append(
                CoachTodayPlanChangeItem(
                    id: "remove-\(secondaryHeavy.id)",
                    kind: .remove,
                    title: russian
                        ? "\(secondaryTitle) убрать"
                        : "Remove \(secondaryTitle)"
                )
            )
        } else {
            items.append(
                CoachTodayPlanChangeItem(
                    id: "remove-extra-load",
                    kind: .remove,
                    title: WeekFitLocalizedString("coach.todayPlan.change.removeExtraLoad")
                )
            )
        }

        return items
    }

    private static func buildTimelineItems(
        primary: CoachPlannedActivitySnapshot,
        secondaryHeavy: CoachPlannedActivitySnapshot?,
        readiness: CoachDayReadiness,
        input: CoachInputSnapshot,
        russian: Bool
    ) -> [CoachTodayPlanTimelineItem] {
        var items: [CoachTodayPlanTimelineItem] = [
            CoachTodayPlanTimelineItem(
                id: "timeline-\(primary.id)",
                activityID: primary.id,
                timeLabel: timeLabel(for: primary.date),
                activityTitle: CoachWorkoutTitleLocalization.displayTitle(primary.title, russian: russian),
                actionLabel: WeekFitLocalizedString("coach.todayPlan.action.keepAsIs"),
                rationale: primaryRationale(readiness: readiness, input: input),
                kind: .keep,
                isSelectedByDefault: true
            )
        ]

        if let secondaryHeavy {
            items.append(
                CoachTodayPlanTimelineItem(
                    id: "timeline-\(secondaryHeavy.id)",
                    activityID: secondaryHeavy.id,
                    timeLabel: timeLabel(for: secondaryHeavy.date),
                    activityTitle: CoachWorkoutTitleLocalization.displayTitle(
                        secondaryHeavy.title,
                        russian: russian
                    ),
                    actionLabel: WeekFitLocalizedString("coach.todayPlan.action.remove"),
                    rationale: WeekFitLocalizedString("coach.todayPlan.rationale.removeExtra"),
                    kind: .remove,
                    isSelectedByDefault: true
                )
            )
        }

        return items
    }

    private static func primaryRationale(
        readiness: CoachDayReadiness,
        input: CoachInputSnapshot
    ) -> String {
        let tomorrow = DayPriorityModel.build(from: input).tomorrowDemand
        if tomorrow == .hard || tomorrow == .moderate {
            return WeekFitLocalizedString("coach.todayPlan.rationale.keepBeforeTomorrow")
        }
        if readiness.sleepIsLow {
            return WeekFitLocalizedString("coach.todayPlan.rationale.keepAfterSleep")
        }
        return WeekFitLocalizedString("coach.todayPlan.rationale.keepLowRecovery")
    }

    private static func coachingNote(
        for primary: CoachPlannedActivitySnapshot,
        russian: Bool
    ) -> (headline: String, body: String) {
        let title = CoachWorkoutTitleLocalization.displayTitle(primary.title, russian: russian)
        let phrase = russian
            ? CoachWorkoutTitleLocalization.russianPhraseTitle(primary.title)
            : title
        let headline = WeekFitLocalizedString("coach.todayPlan.note.headline")
        let body = russian
            ? "Во время \(phrase) ориентируйтесь на комфортный разговорный темп."
            : "During \(title), aim for a comfortable conversational pace."
        return (headline, body)
    }

    private static func changesCountValue(_ count: Int, russian: Bool) -> String {
        if russian {
            switch WeekFitCountPluralization.russianForm(for: count) {
            case .one:
                return "\(count) корректировка"
            case .few:
                return "\(count) корректировки"
            case .many:
                return "\(count) корректировок"
            }
        }
        return count == 1 ? "1 adjustment" : "\(count) adjustments"
    }

    private static func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
