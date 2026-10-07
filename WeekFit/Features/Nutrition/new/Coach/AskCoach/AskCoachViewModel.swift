internal import Combine
import Foundation
import WeekFitPlanner

@MainActor
final class AskCoachViewModel: ObservableObject {

    enum Phase: Equatable {
        case chooseQuestion
        case answering
    }

    @Published private(set) var phase: Phase = .chooseQuestion
    @Published private(set) var selectedQuestion: AskCoachQuestion?
    @Published var selectedPeriod: AskCoachPeriodLength = .last7Days
    @Published private(set) var turns: [AskCoachConversationTurn] = []
    @Published private(set) var loadState: AskCoachLoadState = .idle
    @Published private(set) var weeklyFocus: AskCoachWeeklyFocus?
    @Published private(set) var reviewableFocus: AskCoachWeeklyFocus?

    private let healthManager: HealthManager
    private var plannedActivities: [PlannedActivity]
    private var loadTask: Task<Void, Never>?
    private var cachedBundle: AskCoachPeriodBundle?
    private var cachedPeriod: AskCoachPeriodLength?
    private var cachedIncludeVitals = false

    init(
        healthManager: HealthManager,
        plannedActivities: [PlannedActivity] = []
    ) {
        self.healthManager = healthManager
        self.plannedActivities = plannedActivities
        refreshFocusState()
    }

    var rangeLabel: String {
        if let range = turns.last?.answer?.range {
            return AskCoachPeriodCalculator.formattedRangeLabel(range)
        }
        let range = AskCoachPeriodCalculator.range(length: selectedPeriod, endingOn: Date())
        return AskCoachPeriodCalculator.formattedRangeLabel(range)
    }

    var navigationTitle: String {
        if let question = selectedQuestion {
            return WeekFitLocalizedString(question.titleKey)
        }
        return WeekFitLocalizedString("coach.askCoach")
    }

    var latestFollowUps: [AskCoachFollowUp] {
        guard let answer = turns.last(where: { $0.answer != nil })?.answer else { return [] }
        return answer.followUps.filter { $0 != .backToQuestions }
    }

    var latestSuggestedFocus: AskCoachSuggestedFocus? {
        turns.last(where: { $0.answer?.suggestedFocus != nil })?.answer?.suggestedFocus
    }

    func updatePlannedActivities(_ activities: [PlannedActivity]) {
        plannedActivities = activities
    }

    func refreshFocusState() {
        weeklyFocus = AskCoachFocusStore.activeFocus()
        reviewableFocus = AskCoachFocusStore.reviewableFocus()
    }

    func selectQuestion(_ question: AskCoachQuestion) {
        selectedQuestion = question
        selectedPeriod = question.defaultPeriod
        phase = .answering
        turns = []
        cachedBundle = nil
        cachedPeriod = nil
        cachedIncludeVitals = false
        appendRootTurn(for: question)
    }

    func changePeriod(_ period: AskCoachPeriodLength) {
        guard selectedPeriod != period else { return }
        selectedPeriod = period
        cachedBundle = nil
        cachedPeriod = nil
        cachedIncludeVitals = false
        guard let question = selectedQuestion else { return }
        turns = []
        appendRootTurn(for: question)
    }

    func selectFollowUp(_ followUp: AskCoachFollowUp) {
        if followUp == .backToQuestions {
            resetToQuestions()
            return
        }
        let turnID = UUID()
        turns.append(
            AskCoachConversationTurn(
                id: turnID,
                userPrompt: followUp.promptText,
                answer: nil,
                isLoading: true,
                detailsExpanded: false
            )
        )
        loadTurn(turnID: turnID, question: selectedQuestion ?? .weeklyOverview, followUp: followUp)
    }

    func toggleDetails(for turnID: UUID) {
        guard let index = turns.firstIndex(where: { $0.id == turnID }) else { return }
        turns[index].detailsExpanded.toggle()
    }

    func retry() {
        cachedBundle = nil
        cachedPeriod = nil
        cachedIncludeVitals = false
        guard let question = selectedQuestion else { return }
        if turns.count <= 1 {
            turns = []
            appendRootTurn(for: question)
        } else if let last = turns.last {
            turns[turns.count - 1].isLoading = true
            turns[turns.count - 1].answer = nil
            loadTurn(turnID: last.id, question: question, followUp: nil)
        }
    }

    func resetToQuestions() {
        loadTask?.cancel()
        phase = .chooseQuestion
        selectedQuestion = nil
        turns = []
        loadState = .idle
        refreshFocusState()
    }

    func setWeeklyFocus(_ kind: AskCoachFocusKind) {
        weeklyFocus = AskCoachFocusStore.setFocus(kind: kind)
        reviewableFocus = nil
    }

    func dismissWeeklyFocus() {
        _ = AskCoachFocusStore.dismiss()
        weeklyFocus = nil
        reviewableFocus = nil
    }

    func reviewFocus() {
        guard let focus = reviewableFocus ?? AskCoachFocusStore.reviewableFocus() else { return }
        phase = .answering
        selectedQuestion = .weeklyOverview
        selectedPeriod = .last7Days
        let turnID = UUID()
        turns = [
            AskCoachConversationTurn(
                id: turnID,
                userPrompt: .en("Review my focus", "Обзор фокуса"),
                answer: nil,
                isLoading: true,
                detailsExpanded: false
            )
        ]
        loadFocusReview(for: focus, turnID: turnID)
    }

    // MARK: - Private

    private func appendRootTurn(for question: AskCoachQuestion) {
        let turnID = UUID()
        turns = [
            AskCoachConversationTurn(
                id: turnID,
                userPrompt: Self.prompt(for: question),
                answer: nil,
                isLoading: true,
                detailsExpanded: false
            )
        ]
        loadTurn(turnID: turnID, question: question, followUp: nil)
    }

    private static func prompt(for question: AskCoachQuestion) -> CoachBilingualText {
        switch question {
        case .weeklyOverview:
            return .en("How was my week?", "Как прошла моя неделя?")
        case .recovery:
            return .en("How am I recovering?", "Как я восстанавливаюсь?")
        case .consistency:
            return .en("How consistent am I?", "Насколько я последователен?")
        }
    }

    private func loadTurn(
        turnID: UUID,
        question: AskCoachQuestion,
        followUp: AskCoachFollowUp?
    ) {
        loadTask?.cancel()
        loadState = .loading
        let period = selectedPeriod
        let activities = plannedActivities
        let needsVitals = question == .recovery || followUp == .myRecovery

        loadTask = Task { [weak self] in
            guard let self else { return }
            let bundle: AskCoachPeriodBundle
            if let cachedBundle,
               cachedPeriod == period,
               cachedIncludeVitals || !needsVitals {
                bundle = cachedBundle
            } else {
                let analysisQuestion: AskCoachQuestion = (followUp == .myRecovery) ? .recovery : question
                let loaded = await AskCoachDataService.load(
                    period: period,
                    question: analysisQuestion,
                    healthManager: healthManager,
                    plannedActivities: activities,
                    includeVitals: needsVitals
                )
                guard !Task.isCancelled else { return }
                self.cachedBundle = loaded
                self.cachedPeriod = period
                self.cachedIncludeVitals = needsVitals || self.cachedIncludeVitals
                bundle = loaded
            }

            let analyzedQuestion: AskCoachQuestion = {
                if followUp == .myRecovery { return .recovery }
                return question
            }()

            let analyzed = AskCoachAnalyzer.analyze(
                AskCoachAnalyzer.Input(
                    question: analyzedQuestion,
                    period: period,
                    currentDays: bundle.currentDays,
                    previousDays: bundle.previousDays,
                    range: bundle.range,
                    previousRange: bundle.previousRange,
                    healthAccessGranted: bundle.healthAccessGranted,
                    followUp: followUp == .myRecovery ? .myRecovery : followUp
                )
            )
            guard !Task.isCancelled else { return }
            if let index = self.turns.firstIndex(where: { $0.id == turnID }) {
                self.turns[index].answer = analyzed
                self.turns[index].isLoading = false
            }
            self.loadState = analyzed.loadState
            self.refreshFocusState()
        }
    }

    private func loadFocusReview(for focus: AskCoachWeeklyFocus, turnID: UUID) {
        loadTask?.cancel()
        loadState = .loading
        let activities = plannedActivities

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
            let review = AskCoachFocusReview.makeAnswer(focus: focus, bundle: bundle)
            if let index = self.turns.firstIndex(where: { $0.id == turnID }) {
                self.turns[index].answer = review
                self.turns[index].isLoading = false
            }
            self.loadState = review.loadState
        }
    }
}
