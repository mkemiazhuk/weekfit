internal import Combine
import Foundation
import HealthKit
import WeekFitPlanner

@MainActor
final class CoachFeelingViewModel: ObservableObject {

    enum Phase: Equatable {
        case feeling
        case clarification
        case result
    }

    enum Launch: Equatable {
        case fresh(CoachFeelingKind?)
        case continueLatest
        case feelingDifferent
        case reviewFocus
    }

    @Published private(set) var phase: Phase = .feeling
    @Published private(set) var selectedFeeling: CoachFeelingKind?
    @Published private(set) var clarification: CoachFeelingClarification?
    @Published private(set) var activeCheckIn: CoachFeelingCheckIn?
    @Published private(set) var comparison: CoachFeelingComparisonResult?
    @Published private(set) var turns: [CoachFeelingConversationTurn] = []
    @Published private(set) var followUps: [CoachFeelingFollowUp] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?

    private let healthManager: HealthManager
    private var plannedActivities: [PlannedActivity]
    private var loadTask: Task<Void, Never>?
    private let launch: Launch
    private var editingCheckInID: String?

    init(
        healthManager: HealthManager,
        plannedActivities: [PlannedActivity] = [],
        launch: Launch = .fresh(nil)
    ) {
        self.healthManager = healthManager
        self.plannedActivities = plannedActivities
        self.launch = launch
    }

    func start() {
        switch launch {
        case .fresh(let feeling):
            if let feeling {
                selectFeeling(feeling)
            } else {
                phase = .feeling
            }
        case .continueLatest:
            if let latest = CoachFeelingCheckInStore.latest() {
                activeCheckIn = latest
                selectedFeeling = latest.feeling
                clarification = latest.clarification
                phase = .result
                rebuildComparison(from: latest)
            }
        case .feelingDifferent:
            phase = .feeling
            selectedFeeling = nil
            clarification = nil
            activeCheckIn = nil
            comparison = nil
            turns = []
            editingCheckInID = nil
            followUps = []
        case .reviewFocus:
            phase = .result
            appendFocusReview()
        }
    }

    func updatePlannedActivities(_ activities: [PlannedActivity]) {
        plannedActivities = activities
    }

    func selectFeeling(_ feeling: CoachFeelingKind) {
        selectedFeeling = feeling
        clarification = nil
        if feeling.suggestsFatigueFollowUp {
            phase = .clarification
            turns = [
                CoachFeelingConversationTurn(
                    id: UUID(),
                    userPrompt: feeling.bilingualTitle,
                    answerHeadline: CoachFeelingCopy.bi(
                        "What are you noticing?",
                        "Что вы замечаете?"
                    ),
                    answerExplanation: CoachFeelingCopy.bi(
                        "Optional — skip if you’d rather go straight to the comparison.",
                        "По желанию — можно пропустить и сразу перейти к сравнению."
                    ),
                    supportingFacts: [],
                    detailFacts: [],
                    isLoading: false,
                    detailsExpanded: false
                )
            ]
        } else {
            runComparison(feeling: feeling, clarification: nil)
        }
    }

    func selectClarification(_ value: CoachFeelingClarification?) {
        clarification = value
        guard let feeling = selectedFeeling else { return }
        runComparison(feeling: feeling, clarification: value)
    }

    func skipClarification() {
        selectClarification(nil)
    }

    func selectFollowUp(_ followUp: CoachFeelingFollowUp) {
        switch followUp {
        case .feelingDuration:
            appendDurationPrompt()
        case .tryToday:
            appendTryToday()
        case .last7Days, .reviewWeek:
            appendWeekReview()
        }
    }

    func answerDuration(startedToday: Bool) {
        guard var checkIn = activeCheckIn else { return }
        let answer = startedToday ? "started_today" : "lasted_few_days"
        checkIn.followUpAnswers.append(answer)
        checkIn.updatedAt = Date()
        CoachFeelingCheckInStore.upsert(checkIn)
        activeCheckIn = checkIn

        let turnID = UUID()
        turns.append(
            CoachFeelingConversationTurn(
                id: turnID,
                userPrompt: startedToday
                    ? CoachFeelingCopy.bi("It started today", "Началось сегодня")
                    : CoachFeelingCopy.bi("It’s lasted a few days", "Длится несколько дней"),
                answerHeadline: CoachFeelingCopy.bi(
                    "Thanks — noted for your timeline.",
                    "Спасибо — записали в историю."
                ),
                answerExplanation: CoachFeelingCopy.bi(
                    "We won’t claim a personal pattern from one or two check-ins. Over time, your timeline can show feelings next to relevant measurements.",
                    "Мы не будем утверждать личный паттерн по одному-двум чек-инам. Со временем таймлайн покажет ощущения рядом с релевантными измерениями."
                ),
                supportingFacts: [],
                detailFacts: [],
                isLoading: false,
                detailsExpanded: false
            )
        )
        followUps = followUps.filter { $0 != .feelingDuration }
    }

    func toggleDetails(for turnID: UUID) {
        guard let index = turns.firstIndex(where: { $0.id == turnID }) else { return }
        turns[index].detailsExpanded.toggle()
    }

    func deleteActiveCheckIn() {
        guard let id = activeCheckIn?.id else { return }
        _ = CoachFeelingCheckInStore.delete(id: id)
        activeCheckIn = nil
        comparison = nil
        turns = []
        phase = .feeling
        selectedFeeling = nil
        clarification = nil
        followUps = []
        editingCheckInID = nil
    }

    /// Re-run the guided flow while replacing the active check-in in place.
    func editActiveCheckIn() {
        editingCheckInID = activeCheckIn?.id
        selectedFeeling = nil
        clarification = nil
        comparison = nil
        turns = []
        followUps = []
        phase = .feeling
    }

    // MARK: - Private

    private func runComparison(
        feeling: CoachFeelingKind,
        clarification: CoachFeelingClarification?
    ) {
        isLoading = true
        loadError = nil
        phase = .result
        let turnID = UUID()
        let prompt: CoachBilingualText = {
            if let clarification {
                return .en(
                    "\(feeling.bilingualTitle.english) · \(clarification.bilingualTitle.english)",
                    "\(feeling.bilingualTitle.russian) · \(clarification.bilingualTitle.russian)"
                )
            }
            return feeling.bilingualTitle
        }()
        turns = [
            CoachFeelingConversationTurn(
                id: turnID,
                userPrompt: prompt,
                answerHeadline: nil,
                answerExplanation: nil,
                supportingFacts: [],
                detailFacts: [],
                isLoading: true,
                detailsExpanded: false
            )
        ]

        let activities = plannedActivities
        let checkInAt = Date()
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let activityContext = await self.loadRecentActivityContext(
                checkInAt: checkInAt,
                plannedActivities: activities
            )
            let observations = CoachObservationStore.allObservations()
            let result = CoachFeelingComparator.compare(
                .init(
                    feeling: feeling,
                    clarification: clarification,
                    checkInAt: checkInAt,
                    observations: observations,
                    recentActivityDayKeys: activityContext.dayKeys,
                    recentActivityCount: activityContext.count
                )
            )
            guard !Task.isCancelled else { return }

            let existingID = self.editingCheckInID
            let existingCreatedAt = existingID.flatMap { CoachFeelingCheckInStore.checkIn(id: $0)?.createdAt }
            var checkIn = CoachFeelingCheckIn(
                id: existingID ?? UUID().uuidString,
                createdAt: existingCreatedAt ?? checkInAt,
                updatedAt: checkInAt,
                feeling: feeling,
                clarification: clarification,
                outcome: result.outcome,
                evidence: result.evidence,
                analysisVersion: result.analysisVersion,
                followUpAnswers: []
            )
            CoachFeelingCheckInStore.upsert(checkIn)
            self.editingCheckInID = nil
            self.activeCheckIn = checkIn
            self.comparison = result
            self.isLoading = false

            if let index = self.turns.firstIndex(where: { $0.id == turnID }) {
                self.turns[index].isLoading = false
                self.turns[index].answerHeadline = result.headline
                self.turns[index].answerExplanation = result.explanation
                self.turns[index].supportingFacts = result.supportingFacts
                self.turns[index].detailFacts = result.detailFacts
            }
            self.followUps = self.defaultFollowUps(for: result.outcome)
        }
    }

    private func rebuildComparison(from checkIn: CoachFeelingCheckIn) {
        let result = CoachFeelingComparator.compare(
            .init(
                feeling: checkIn.feeling,
                clarification: checkIn.clarification,
                checkInAt: checkIn.createdAt,
                observations: CoachObservationStore.allObservations(),
                recentActivityDayKeys: checkIn.evidence.recentActivityDayKeys,
                recentActivityCount: checkIn.evidence.recentActivityCount
            )
        )
        comparison = result
        turns = [
            CoachFeelingConversationTurn(
                id: UUID(),
                userPrompt: checkIn.feeling.bilingualTitle,
                answerHeadline: result.headline,
                answerExplanation: result.explanation,
                supportingFacts: result.supportingFacts,
                detailFacts: result.detailFacts,
                isLoading: false,
                detailsExpanded: false
            )
        ]
        followUps = defaultFollowUps(for: result.outcome)
    }

    private func defaultFollowUps(for outcome: CoachFeelingComparisonKind) -> [CoachFeelingFollowUp] {
        switch outcome {
        case .supporting:
            return [.last7Days, .tryToday]
        case .mixed:
            return [.feelingDuration, .tryToday]
        case .insufficient:
            return [.tryToday, .reviewWeek]
        }
    }

    private func appendTryToday() {
        guard let feeling = selectedFeeling, let comparison else { return }
        let suggestion = CoachFeelingCopy.tryTodaySuggestion(
            feeling: feeling,
            outcome: comparison.outcome,
            evidence: comparison.evidence
        )
        turns.append(
            CoachFeelingConversationTurn(
                id: UUID(),
                userPrompt: CoachFeelingFollowUp.tryToday.prompt,
                answerHeadline: suggestion.headline,
                answerExplanation: suggestion.explanation,
                supportingFacts: suggestion.facts,
                detailFacts: [
                    CoachFeelingCopy.bi(
                        "This doesn’t change your Plan or today’s Coach recommendation.",
                        "Это не меняет План и сегодняшнюю рекомендацию Coach."
                    )
                ],
                isLoading: false,
                detailsExpanded: false
            )
        )
        followUps = followUps.filter { $0 != .tryToday }
    }

    private func appendDurationPrompt() {
        turns.append(
            CoachFeelingConversationTurn(
                id: UUID(),
                userPrompt: CoachFeelingFollowUp.feelingDuration.prompt,
                answerHeadline: CoachFeelingCopy.bi(
                    "Quick check",
                    "Короткий вопрос"
                ),
                answerExplanation: CoachFeelingCopy.bi(
                    "Choose whichever fits — there’s no wrong answer.",
                    "Выберите подходящий вариант — неправильного ответа нет."
                ),
                supportingFacts: [],
                detailFacts: [],
                isLoading: false,
                detailsExpanded: false
            )
        )
        // Duration answers are handled via dedicated buttons in the view when this follow-up is active.
    }

    private func appendWeekReview() {
        let turnID = UUID()
        turns.append(
            CoachFeelingConversationTurn(
                id: turnID,
                userPrompt: CoachFeelingFollowUp.last7Days.prompt,
                answerHeadline: nil,
                answerExplanation: nil,
                supportingFacts: [],
                detailFacts: [],
                isLoading: true,
                detailsExpanded: false
            )
        )
        let activities = plannedActivities
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let bundle = await AskCoachDataService.load(
                period: .last7Days,
                question: .weeklyOverview,
                healthManager: healthManager,
                plannedActivities: activities,
                includeVitals: false
            )
            guard !Task.isCancelled else { return }
            let answer = AskCoachAnalyzer.analyze(
                .init(
                    question: .weeklyOverview,
                    period: .last7Days,
                    currentDays: bundle.currentDays,
                    previousDays: bundle.previousDays,
                    range: bundle.range,
                    previousRange: bundle.previousRange,
                    healthAccessGranted: bundle.healthAccessGranted,
                    followUp: nil
                )
            )
            if let index = self.turns.firstIndex(where: { $0.id == turnID }) {
                self.turns[index].isLoading = false
                self.turns[index].answerHeadline = answer.headline
                self.turns[index].answerExplanation = answer.explanation
                self.turns[index].supportingFacts = answer.supportingFacts
                self.turns[index].detailFacts = answer.detailFacts
            }
            self.followUps = self.followUps.filter { $0 != .last7Days && $0 != .reviewWeek }
        }
    }

    private func appendFocusReview() {
        guard let focus = AskCoachFocusStore.reviewableFocus() else {
            appendWeekReview()
            return
        }
        let turnID = UUID()
        turns = [
            CoachFeelingConversationTurn(
                id: turnID,
                userPrompt: CoachFeelingCopy.bi("Review my focus", "Обзор фокуса"),
                answerHeadline: nil,
                answerExplanation: nil,
                supportingFacts: [],
                detailFacts: [],
                isLoading: true,
                detailsExpanded: false
            )
        ]
        let activities = plannedActivities
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let bundle = await AskCoachDataService.load(
                period: .last7Days,
                question: .weeklyOverview,
                healthManager: healthManager,
                plannedActivities: activities,
                includeVitals: false
            )
            guard !Task.isCancelled else { return }
            let answer = AskCoachFocusReview.makeAnswer(focus: focus, bundle: bundle)
            if let index = self.turns.firstIndex(where: { $0.id == turnID }) {
                self.turns[index].isLoading = false
                self.turns[index].answerHeadline = answer.headline
                self.turns[index].answerExplanation = answer.explanation
                self.turns[index].supportingFacts = answer.supportingFacts
                self.turns[index].detailFacts = answer.detailFacts
            }
            self.followUps = [.last7Days]
        }
    }

    private func loadRecentActivityContext(
        checkInAt: Date,
        plannedActivities: [PlannedActivity]
    ) async -> (dayKeys: [String], count: Int) {
        let calendar = Calendar.current
        let windowStart = checkInAt.addingTimeInterval(
            -Double(CoachFeelingEvidenceRules.recentActivityHours) * 3600
        )
        var day = calendar.startOfDay(for: windowStart)
        let endDay = calendar.startOfDay(for: checkInAt)
        var hk: [AskCoachSessionAggregator.HealthKitCandidate] = []

        while day <= endDay {
            if Task.isCancelled { break }
            if healthManager.isHealthAccessGranted {
                let workouts = await healthManager.loadWorkoutSamples(for: day)
                for workout in workouts where workout.startDate >= windowStart && workout.startDate <= checkInAt {
                    let imported = ActivityReconciler.importedActivity(for: workout)
                    let snapshot = CoachPlannedActivitySnapshot(from: imported)
                    hk.append(
                        .init(
                            uuid: workout.uuid,
                            startDate: workout.startDate,
                            durationMinutes: max(1, Int((workout.duration / 60.0).rounded())),
                            isRecoveryActivity: CoachActivityClassification.isRecoveryTier(snapshot)
                        )
                    )
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            await Task.yield()
        }

        let locals = plannedActivities.compactMap { activity -> AskCoachSessionAggregator.LocalCompletedCandidate? in
            guard activity.date >= windowStart, activity.date <= checkInAt else { return nil }
            return .init(
                id: activity.id,
                startDate: activity.date,
                durationMinutes: max(1, activity.effectiveDurationMinutes),
                healthKitWorkoutUUID: activity.healthKitWorkoutUUID.flatMap(UUID.init(uuidString:)),
                isCompleted: activity.isCompleted,
                isSkipped: activity.isSkipped,
                source: activity.source,
                type: activity.type
            )
        }

        let sessions = AskCoachSessionAggregator.aggregate(healthKit: hk, local: locals)
        let dayKeys = Array(
            Set(sessions.map { CoachDailyObservation.dayKey(for: $0.startDate) })
        ).sorted()
        return (dayKeys, sessions.count)
    }
}
