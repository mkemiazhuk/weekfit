internal import Combine
import Foundation
import HealthKit
import WeekFitPlanner

@MainActor
final class CoachAssistantViewModel: ObservableObject {

    enum Launch: Equatable {
        case fresh
        case continueConversation(id: String)
    }

    @Published private(set) var conversation: CoachAssistantConversation?
    @Published private(set) var turns: [CoachAssistantTurn] = []
    @Published private(set) var choices: [CoachAssistantChoice] = []
    @Published private(set) var isProcessingChoice = false
    @Published private(set) var isLoadingAnalysis = false
    @Published private(set) var isCoachTyping = false
    @Published private(set) var pendingAction: CoachAssistantChoiceAction?
    @Published var showHistory = false

    private let healthManager: HealthManager
    private var plannedActivities: [PlannedActivity]
    private var nutritionContext: CoachNutritionContext?
    private let launch: Launch
    private var loadTask: Task<Void, Never>?
    private let givenName: String?
    private var didStart = false
    private var lastNavigationActionID: String?

    init(
        healthManager: HealthManager,
        plannedActivities: [PlannedActivity] = [],
        nutritionContext: CoachNutritionContext? = nil,
        launch: Launch = .fresh,
        givenName: String? = ProfileService.resolvedGivenName()
    ) {
        self.healthManager = healthManager
        self.plannedActivities = plannedActivities
        self.nutritionContext = nutritionContext
        self.launch = launch
        let trimmed = givenName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.givenName = (trimmed?.isEmpty == false) ? trimmed : nil
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        switch launch {
        case .fresh:
            beginNewConversation(intentional: true)
        case .continueConversation(let id):
            if let existing = CoachAssistantConversationStore.conversation(id: id) {
                conversation = existing
                turns = existing.turns
                restoreChoices(for: existing)
            } else if let today = CoachAssistantConversationStore.latest() {
                conversation = today
                turns = today.turns
                restoreChoices(for: today)
            } else {
                beginNewConversation(intentional: false)
            }
        }
    }

    func updatePlannedActivities(_ activities: [PlannedActivity]) {
        plannedActivities = activities
    }

    func updateNutritionContext(_ context: CoachNutritionContext?) {
        nutritionContext = context
    }

    func selectChoice(_ choice: CoachAssistantChoice) {
        guard !isProcessingChoice, !isLoadingAnalysis, !isCoachTyping else { return }
        isProcessingChoice = true

        if choice.action == .startNewConversation {
            beginNewConversation(intentional: true)
            isProcessingChoice = false
            return
        }

        guard var conversation else {
            isProcessingChoice = false
            return
        }

        let fromNode = conversation.currentNodeID

        let userTurn = CoachAssistantTurn(
            role: .user,
            text: choice.title,
            nodeID: fromNode,
            choiceID: choice.id
        )
        conversation.turns.append(userTurn)
        conversation.choiceIDs.append(choice.id)
        conversation.answerTimestamps[choice.id] = Date()
        conversation.updatedAt = Date()
        turns = conversation.turns
        choices = []
        self.conversation = conversation
        persist()

        let navigationCandidate: CoachAssistantChoiceAction? = {
            guard let action = choice.action else { return nil }
            // Weekly focus is retired from Assistant — never set or navigate for it.
            if action == .setWeeklyFocus { return nil }
            if action.resolvesToMealsTab || action == .openGoalSettings || action == .proposePlanEase {
                return action == .openMealBuilder ? .openMealsTab : action
            }
            return nil
        }()

        if navigationCandidate != nil {
            conversation.returnNodeID = fromNode
            self.conversation = conversation
            persist()
        }

        // Topic navigation always runs from mindAsk — never as an answer to a stuck branch node.
        if choice.id == "end.another"
            || choice.id.hasPrefix("mind.nutrition")
            || choice.id.hasPrefix("mind.recovery")
            || choice.id.hasPrefix("mind.activity") {
            if choice.id == "end.another" {
                conversation.previousArea = conversation.area
                conversation.area = nil
                conversation.currentNodeID = .mindAsk
            } else {
                let newTopic: CoachAssistantArea? = {
                    if choice.id.hasPrefix("mind.nutrition") { return .nutrition }
                    if choice.id.hasPrefix("mind.recovery") { return .recovery }
                    if choice.id.hasPrefix("mind.activity") { return .activity }
                    return nil
                }()
                if let newTopic, conversation.area != newTopic {
                    conversation.previousArea = conversation.area
                    conversation.area = newTopic
                }
            }
            self.conversation = conversation
            persist()
            advance(
                from: .mindAsk,
                choiceID: choice.id,
                navigationAction: nil,
                skipTyping: choice.id == "end.another"
            )
            return
        }

        // Ignore retired weekly-focus chip if it appears in an old transcript.
        if choice.id == "recovery.setFocus" || choice.action == .setWeeklyFocus {
            advance(
                from: .mindAsk,
                choiceID: "end.another",
                navigationAction: nil,
                skipTyping: true
            )
            return
        }

        if choice.destination == .end || choice.id.hasPrefix("end.") {
            advance(
                from: .end,
                choiceID: choice.id,
                navigationAction: navigationCandidate,
                skipTyping: true
            )
            return
        }

        advance(
            from: fromNode,
            choiceID: choice.id,
            navigationAction: navigationCandidate,
            skipTyping: navigationCandidate != nil
        )
    }

    /// Free-text path kept for tests/compat — not exposed in chip UI.
    func sendMessage(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isProcessingChoice, !isLoadingAnalysis, !isCoachTyping else { return }
        guard var conversation else { return }

        isProcessingChoice = true
        let fromNode = conversation.currentNodeID
        let userTurn = CoachAssistantTurn(
            role: .user,
            text: .en(trimmed, trimmed),
            nodeID: fromNode
        )
        conversation.turns.append(userTurn)
        conversation.updatedAt = Date()
        turns = conversation.turns
        choices = []
        self.conversation = conversation
        persist()

        let intent = CoachAssistantIntentRouter.route(
            trimmed,
            currentNode: fromNode,
            feeling: conversation.feeling
        )

        switch intent {
        case .feeling(let feeling):
            advance(from: .feelingAsk, choiceID: "feeling.\(feeling.rawValue)")
        case .clarification(let clarification):
            if conversation.feeling == nil {
                conversation.feeling = .tired
                self.conversation = conversation
            }
            advance(from: .tiredClarify, choiceID: "clarify.\(clarification.rawValue)")
        case .area(let area):
            let choiceID: String = {
                switch area {
                case .activity: return "mind.activity"
                case .nutrition: return "mind.nutrition"
                case .recovery: return "mind.recovery"
                }
            }()
            advance(from: .mindAsk, choiceID: choiceID)
        case .activityDetail(let node):
            advance(from: node, choiceID: nil)
        case .nutritionDetail(let node):
            switch node {
            case .nutritionRemaining:
                advance(from: .nutritionGate, choiceID: "nutrition.remaining")
            case .nutritionChooseMeal:
                advance(from: .nutritionGate, choiceID: "nutrition.helpChoose")
            case .nutritionHabits:
                advance(from: .nutritionGate, choiceID: "nutrition.habits")
            default:
                advance(from: .nutritionGate, choiceID: nil)
            }
        case .recoveryDetail(let node):
            advance(from: node, choiceID: nil)
        case .unsupported(let reply):
            let coachTurn = CoachAssistantTurn(role: .coach, text: reply, nodeID: fromNode)
            revealCoachTurns(
                [coachTurn],
                choices: CoachAssistantCopy.areaStarterChoices(),
                updating: { conversation in
                    conversation.turns.append(coachTurn)
                    conversation.updatedAt = Date()
                }
            )
        }
    }

    func clearPendingAction() {
        pendingAction = nil
    }

    func startNewConversation() {
        beginNewConversation(intentional: true)
    }

    func deleteCurrentConversation() {
        guard let id = conversation?.id else { return }
        _ = CoachAssistantConversationStore.delete(id: id)
        beginNewConversation(intentional: true)
    }

    func editFeeling() {
        guard var conversation else { return }
        let keepPrefix = conversation.turns.prefix { turn in
            turn.nodeID == .feelingAsk && turn.role == .coach
        }
        var kept = Array(keepPrefix)
        if kept.isEmpty {
            kept = [
                CoachAssistantTurn(
                    role: .coach,
                    text: CoachAssistantCopy.feelingPrompt(givenName: givenName),
                    nodeID: .feelingAsk
                )
            ]
        }
        // Invalidate feeling-dependent conclusions while keeping the greeting.
        for index in conversation.turns.indices where index >= kept.count {
            conversation.turns[index].isInvalidated = true
        }
        conversation.turns = kept
        conversation.feeling = nil
        conversation.clarification = nil
        conversation.area = nil
        conversation.previousArea = nil
        conversation.currentNodeID = .feelingAsk
        conversation.returnNodeID = nil
        conversation.ended = false
        conversation.updatedAt = Date()
        conversation.evidence = .empty
        conversation.invalidateAnswers(prefix: "feeling.")
        conversation.invalidateAnswers(prefix: "mind.")
        conversation.invalidateAnswers(prefix: "gate.")
        conversation.invalidateAnswers(prefix: "clarify.")
        conversation.invalidateAnswers(prefix: "activity.")
        conversation.invalidateAnswers(prefix: "nutrition.")
        conversation.invalidateAnswers(prefix: "recovery.")
        turns = conversation.turns
        choices = CoachAssistantFlow.feelingChoices()
        self.conversation = conversation
        persist()
    }

    /// Compact menu action — end without a new advice turn.
    func finishConversation() {
        guard !isProcessingChoice, !isLoadingAnalysis, !isCoachTyping else { return }
        guard conversation != nil else { return }
        isProcessingChoice = true
        advance(
            from: .end,
            choiceID: "menu.finish",
            navigationAction: nil,
            skipTyping: true
        )
    }

    // MARK: - Private

    private func beginNewConversation(intentional: Bool) {
        loadTask?.cancel()
        isCoachTyping = false
        isLoadingAnalysis = false

        let memory = CoachAssistantMemoryStore.load()
        let now = Date()
        let signals = CoachAssistantSignalSnapshot.build(
            checkInAt: now,
            observations: CoachObservationStore.allObservations(),
            plannedActivities: plannedActivities,
            nutrition: nutritionContext,
            recentActivityCount: 0,
            // Authorization true is trustworthy; false/unknown must not be narrated as denial.
            healthKitAuthorized: healthManager.isHealthAccessGranted ? true : nil
        )
        let boot = CoachAssistantFlow.bootstrap(
            givenName: givenName,
            memory: memory,
            signals: signals,
            now: now
        )

        let conversation = CoachAssistantConversation(
            id: UUID().uuidString,
            createdAt: now,
            updatedAt: now,
            feeling: nil,
            clarification: nil,
            area: boot.area,
            currentNodeID: boot.coachTurns.last?.nodeID ?? .feelingAsk,
            turns: boot.coachTurns,
            choiceIDs: [],
            evidence: .empty,
            previewEnglish: boot.preview?.english ?? CoachAssistantCopy.invitationBody(givenName: givenName).english,
            previewRussian: boot.preview?.russian ?? CoachAssistantCopy.invitationBody(givenName: givenName).russian,
            ended: false
        )
        self.conversation = conversation
        turns = []
        choices = []
        persist()
        if intentional {
            CoachAssistantConversationStore.supersedeSameDay(keeping: conversation.id, on: now)
        }
        recordMemory(from: boot, conversation: conversation)

        revealCoachTurns(
            boot.coachTurns,
            choices: boot.choices,
            updating: { _ in },
            alreadyPersistedInConversation: true
        )
    }

    private func restoreChoices(for conversation: CoachAssistantConversation) {
        if conversation.ended {
            choices = [
                CoachAssistantChoice(
                    id: "end.new",
                    title: CoachAssistantCopy.bi("Start a new conversation", "Начать новый разговор"),
                    destination: .feelingAsk,
                    action: .startNewConversation
                )
            ]
            return
        }
        if conversation.currentNodeID == .feelingAsk, conversation.feeling == nil {
            // Keep whatever chips the opening used when possible; default to feeling.
            if conversation.choiceIDs.contains(where: { $0.hasPrefix("followup.") }) {
                choices = CoachAssistantCopy.followUpEaseChoices()
            } else {
                choices = CoachAssistantFlow.feelingChoices()
            }
            return
        }

        let context = makeAnalysisContext(checkInAt: conversation.createdAt)
        let memory = CoachAssistantMemoryStore.load()
        let signals = CoachAssistantSignalSnapshot.build(
            checkInAt: conversation.createdAt,
            observations: context.observations,
            plannedActivities: plannedActivities,
            nutrition: nutritionContext,
            recentActivityCount: conversation.evidence.feelingEvidence.recentActivityCount,
            healthKitAuthorized: healthManager.isHealthAccessGranted ? true : nil
        )
        let output = CoachAssistantFlow.advance(
            .init(
                node: conversation.currentNodeID,
                choiceID: nil,
                feeling: conversation.feeling,
                clarification: conversation.clarification,
                evidence: conversation.evidence,
                analysisContext: context,
                weekBundle: nil,
                givenName: givenName,
                answeredChoiceIDs: conversation.choiceIDs,
                memory: memory,
                signals: signals
            )
        )
        choices = output.choices
    }

    private func advance(
        from node: CoachAssistantNodeID,
        choiceID: String?,
        navigationAction: CoachAssistantChoiceAction? = nil,
        skipTyping: Bool = false
    ) {
        guard let conversation else { return }

        let needsRecoveryVitals =
            node == .recoveryToday
            || node == .recoveryGate
            || node == .recoveryPattern
            || node == .recoveryDuration
            || node == .recoveryNextStep
            || choiceID == "mind.recovery"
            || choiceID?.hasPrefix("mind.recovery.") == true
            || choiceID?.hasPrefix("recovery.") == true
            || choiceID == "recovery.nights"

        let needsWeek =
            node == .activityRecent
            || node == .activityConsistency
            || node == .nutritionHabits
            || choiceID == "activity.recent"
            || choiceID == "activity.consistency"
            || choiceID == "nutrition.habits"
            || choiceID == "mind.activity.recent"
            || choiceID == "mind.activity.consistency"
            || choiceID == "mind.nutrition.habits"
            || choiceID == "recovery.nights"
            || needsRecoveryVitals

        let needsActivityContext =
            node == .feelingAsk
            || node == .tiredClarify
            || (choiceID?.hasPrefix("feeling.") == true)
            || (choiceID?.hasPrefix("clarify.") == true)
            || (choiceID?.hasPrefix("followup.") == true)

        isLoadingAnalysis = needsWeek || needsActivityContext || needsRecoveryVitals
        isCoachTyping = !skipTyping
        choices = []

        loadTask?.cancel()
        let activities = plannedActivities
        let nutrition = nutritionContext
        let feeling = conversation.feeling
        let clarification = conversation.clarification
        let evidence = conversation.evidence
        let createdAt = conversation.createdAt
        let conversationID = conversation.id
        let answered = conversation.choiceIDs
        let memory = CoachAssistantMemoryStore.load()
        let deferredNavigation = navigationAction
        let navigationKey = "\(conversationID)|\(choiceID ?? "")|\(deferredNavigation?.rawValue ?? "")"

        loadTask = Task { [weak self] in
            guard let self else { return }
            let started = ContinuousClock.now
            var weekBundle: AskCoachPeriodBundle?
            if needsWeek {
                weekBundle = await AskCoachDataService.load(
                    period: .last7Days,
                    question: needsRecoveryVitals ? .recovery : .weeklyOverview,
                    healthManager: self.healthManager,
                    plannedActivities: activities,
                    includeVitals: needsRecoveryVitals
                )
            }

            let checkInAt = Date()
            // Keep observation store aligned with live Today vitals (recovery can exist before sleep).
            await CoachObservationStore.recordToday(
                from: self.healthManager,
                date: checkInAt,
                plannedActivities: activities,
                calorieTarget: nutrition.flatMap { $0.caloriesGoal > 0 ? Int($0.caloriesGoal) : nil }
            )

            var analysisContext = self.makeAnalysisContext(checkInAt: checkInAt)
            analysisContext.plannedActivities = activities
            analysisContext.nutrition = nutrition
            analysisContext.feeling = feeling
            analysisContext.clarification = clarification

            var recentCount = evidence.feelingEvidence.recentActivityCount
            var recentKeys = evidence.feelingEvidence.recentActivityDayKeys
            if needsActivityContext {
                let activityContext = await self.loadRecentActivityContext(checkInAt: checkInAt)
                recentCount = activityContext.count
                recentKeys = activityContext.dayKeys
                analysisContext.recentActivityCount = recentCount
                analysisContext.recentActivityDayKeys = recentKeys
            }

            if evidence.feelingEvidence.sleepDayKey != nil, !needsActivityContext {
                analysisContext.checkInAt = createdAt
            }

            var signals = CoachAssistantSignalSnapshot.build(
                checkInAt: analysisContext.checkInAt,
                observations: analysisContext.observations,
                plannedActivities: activities,
                nutrition: nutrition,
                recentActivityCount: recentCount,
                healthKitAuthorized: self.healthManager.isHealthAccessGranted ? true : nil
            )

            let recoveryVitals: CoachAssistantRecoveryVitals? = {
                guard needsRecoveryVitals else { return nil }
                return Self.makeRecoveryVitals(
                    healthManager: self.healthManager,
                    weekBundle: weekBundle,
                    sleepMinutesFallback: signals.sleepMinutes
                )
            }()

            if let vitals = recoveryVitals, let sleep = vitals.sleepMinutes, sleep > 0 {
                signals.sleepMinutes = sleep
                signals.sleepIsFresh = true
            }

            // Refresh vitals from the store so Recovery isn’t stuck on empty launch evidence.
            var workingEvidence = evidence
            let freshFeeling = CoachFeelingComparator.gatherEvidence(
                input: .init(
                    feeling: feeling ?? .okay,
                    clarification: clarification,
                    checkInAt: analysisContext.checkInAt,
                    observations: analysisContext.observations,
                    recentActivityDayKeys: recentKeys,
                    recentActivityCount: recentCount
                ),
                calendar: .current
            )
            workingEvidence.feelingEvidence = Self.mergeFeelingEvidence(
                existing: evidence.feelingEvidence,
                fresh: freshFeeling
            )

            let output = CoachAssistantFlow.advance(
                .init(
                    node: node,
                    choiceID: choiceID,
                    feeling: feeling,
                    clarification: clarification,
                    evidence: workingEvidence,
                    analysisContext: analysisContext,
                    weekBundle: weekBundle,
                    recoveryVitals: recoveryVitals,
                    givenName: self.givenName,
                    answeredChoiceIDs: answered,
                    memory: memory,
                    signals: signals
                )
            )
            guard !Task.isCancelled else { return }
            guard self.conversation?.id == conversationID else { return }

            let shouldSkipTyping = skipTyping || output.skipTypingDelay
            if !shouldSkipTyping {
                await self.waitForTypingBeat(for: output.coachTurns, since: started)
            }
            guard !Task.isCancelled else { return }
            guard self.conversation?.id == conversationID else { return }

            self.apply(output: output)
            self.isLoadingAnalysis = false
            self.isCoachTyping = false
            self.isProcessingChoice = false

            let action = deferredNavigation ?? output.navigationAction
            if let action {
                guard self.lastNavigationActionID != navigationKey else { return }
                self.lastNavigationActionID = navigationKey
                self.pendingAction = action
            }
        }
    }

    private func apply(output: CoachAssistantNodeOutput) {
        guard var conversation else { return }

        // Drop exact duplicate coach bubbles (topic switch must not re-show the prior recommendation).
        let recentCoachEnglish: [String] = conversation.turns
            .reversed()
            .prefix(8)
            .compactMap { turn in
                guard turn.role == .coach else { return nil }
                return Self.normalizedCoachText(turn.text.english)
            }
        let newTurns = output.coachTurns.filter { turn in
            guard turn.role == .coach else { return true }
            let normalized = Self.normalizedCoachText(turn.text.english)
            return !recentCoachEnglish.contains(normalized)
        }

        conversation.turns.append(contentsOf: newTurns)
        if let next = output.nextNodeID {
            conversation.currentNodeID = next
        } else if let last = newTurns.last ?? output.coachTurns.last {
            conversation.currentNodeID = last.nodeID
        } else if output.ended {
            conversation.currentNodeID = .end
        }
        if let feeling = output.feeling { conversation.feeling = feeling }
        if output.feeling != nil {
            conversation.clarification = output.clarification
        }
        if output.clearsArea {
            if conversation.area != nil {
                conversation.previousArea = conversation.area
            }
            conversation.area = nil
        } else if let area = output.area, conversation.area != area {
            conversation.previousArea = conversation.area
            conversation.area = area
        }
        if let evidence = output.updatedEvidence { conversation.evidence = evidence }
        if let preview = output.preview {
            conversation.previewEnglish = preview.english
            conversation.previewRussian = preview.russian
        }
        conversation.ended = output.ended
        conversation.updatedAt = Date()
        conversation.dataFingerprint = Self.dataFingerprint(
            evidence: conversation.evidence,
            area: conversation.area,
            feeling: conversation.feeling
        )

        if let feeling = conversation.feeling,
           let evidence = output.updatedEvidence,
           evidence.feelingOutcome != nil {
            let checkIn = CoachFeelingCheckIn(
                id: conversation.id,
                createdAt: conversation.createdAt,
                updatedAt: Date(),
                feeling: feeling,
                clarification: conversation.clarification,
                outcome: evidence.feelingOutcome ?? .insufficient,
                evidence: evidence.feelingEvidence,
                analysisVersion: evidence.analysisVersion,
                followUpAnswers: []
            )
            CoachFeelingCheckInStore.upsert(checkIn)
        }

        self.conversation = conversation
        turns = conversation.turns
        choices = output.choices
        persist()
        recordMemory(from: output, conversation: conversation)
    }

    private static func normalizedCoachText(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Compact version token for resume / refresh — not a cryptographic hash.
    private static func dataFingerprint(
        evidence: CoachAssistantEvidenceBundle,
        area: CoachAssistantArea?,
        feeling: CoachFeelingKind?
    ) -> String {
        let e = evidence.feelingEvidence
        let parts: [String] = [
            "v\(evidence.analysisVersion)",
            "s\(e.sleepMinutes.map(String.init) ?? "-")",
            "sb\(e.sleepBaselineMinutes.map(String.init) ?? "-")",
            "r\(e.recoveryPercent.map(String.init) ?? "-")",
            "rb\(e.recoveryBaselinePercent.map(String.init) ?? "-")",
            "c\(Int(evidence.nutritionCaloriesCurrent ?? -1))",
            "p\(Int(evidence.nutritionProteinCurrent ?? -1))",
            "a\(area?.rawValue ?? "-")",
            "f\(feeling?.rawValue ?? "-")"
        ]
        return parts.joined(separator: "|")
    }

    @MainActor
    private static func makeRecoveryVitals(
        healthManager: HealthManager,
        weekBundle: AskCoachPeriodBundle?,
        sleepMinutesFallback: Int?
    ) -> CoachAssistantRecoveryVitals {
        func positive(_ value: Int) -> Int? { value > 0 ? value : nil }
        func positive(_ value: Double) -> Double? { value > 0 ? value : nil }

        let liveSleep = positive(healthManager.sleepMinutes) ?? sleepMinutesFallback
        let deep = positive(healthManager.deepSleepMinutes)
        let rem = positive(healthManager.remSleepMinutes)
        let core = positive(healthManager.coreSleepMinutes)
        let hrv = positive(healthManager.hrvSDNN)
        let rhr = positive(healthManager.restingHeartRate)

        let hrvSamples = (weekBundle?.currentDays ?? []).compactMap(\.hrvSDNN).filter { $0 > 0 }
        let rhrSamples = (weekBundle?.currentDays ?? []).compactMap(\.restingHeartRate).filter { $0 > 0 }
        let hrvBaseline: Double? = {
            guard hrvSamples.count >= 3 else { return nil }
            let sorted = hrvSamples.sorted()
            return sorted[sorted.count / 2]
        }()
        let rhrBaseline: Double? = {
            guard rhrSamples.count >= 3 else { return nil }
            let sorted = rhrSamples.sorted()
            return sorted[sorted.count / 2]
        }()

        return CoachAssistantRecoveryVitals(
            sleepMinutes: liveSleep,
            deepSleepMinutes: deep,
            remSleepMinutes: rem,
            coreSleepMinutes: core,
            hrvSDNN: hrv,
            restingHeartRate: rhr,
            hrvBaselineSDNN: hrvBaseline,
            restingHeartRateBaseline: rhrBaseline
        )
    }

    private func revealCoachTurns(
        _ coachTurns: [CoachAssistantTurn],
        choices pendingChoices: [CoachAssistantChoice],
        updating: @escaping (inout CoachAssistantConversation) -> Void,
        alreadyPersistedInConversation: Bool = false
    ) {
        loadTask?.cancel()
        isCoachTyping = true
        choices = []
        let conversationID = conversation?.id

        loadTask = Task { [weak self] in
            guard let self else { return }
            let started = ContinuousClock.now
            await self.waitForTypingBeat(for: coachTurns, since: started)
            guard !Task.isCancelled else { return }
            guard self.conversation?.id == conversationID else { return }

            if alreadyPersistedInConversation {
                self.turns = self.conversation?.turns ?? coachTurns
                self.choices = pendingChoices
            } else if var conversation = self.conversation {
                updating(&conversation)
                self.conversation = conversation
                self.turns = conversation.turns
                self.choices = pendingChoices
                self.persist()
            }

            self.isCoachTyping = false
            self.isProcessingChoice = false
            self.isLoadingAnalysis = false
        }
    }

    private func waitForTypingBeat(
        for coachTurns: [CoachAssistantTurn],
        since started: ContinuousClock.Instant
    ) async {
        let characterCount = coachTurns.reduce(0) { partial, turn in
            partial + max(turn.text.english.count, turn.text.russian.count)
        }
        let targetMs = min(1_600, max(550, 380 + characterCount * 14))
        let target = Duration.milliseconds(targetMs)
        let elapsed = ContinuousClock.now - started
        if elapsed < target {
            try? await Task.sleep(for: target - elapsed)
        }
    }

    private func persist() {
        guard let conversation else { return }
        CoachAssistantConversationStore.upsert(conversation)
    }

    private func recordMemory(
        from output: CoachAssistantNodeOutput,
        conversation: CoachAssistantConversation
    ) {
        let dayKey = conversation.dayKey()
        var state = CoachAssistantMemoryStore.load()
        var entry = CoachAssistantMemoryStore.day(dayKey, in: state)
            ?? CoachAssistantDayMemory(
                dayKey: dayKey,
                feeling: nil,
                areasVisited: [],
                questionIDs: [],
                recommendationIDs: [],
                unresolvedFollowUp: nil,
                insightID: nil
            )
        if let feeling = conversation.feeling {
            entry.feeling = feeling
        }
        if let area = conversation.area, !entry.areasVisited.contains(area) {
            entry.areasVisited.append(area)
        }
        if let questionID = output.questionID, !entry.questionIDs.contains(questionID) {
            entry.questionIDs.append(questionID)
        }
        if let recommendationID = output.recommendationID,
           !entry.recommendationIDs.contains(recommendationID) {
            entry.recommendationIDs.append(recommendationID)
        }
        if let recommendationID = output.recommendationID,
           recommendationID.hasPrefix("meal."),
           !state.offeredMealIDs.contains(recommendationID) {
            state.offeredMealIDs.append(recommendationID)
            if state.offeredMealIDs.count > 12 {
                state.offeredMealIDs = Array(state.offeredMealIDs.suffix(12))
            }
        }
        if conversation.choiceIDs.contains("nutrition.diet.vegetarian") {
            state.prefersVegetarian = true
        } else if conversation.choiceIDs.contains("nutrition.diet.regular") {
            state.prefersVegetarian = false
        }
        if output.clearPriorFollowUp {
            // Clear unresolved on prior days.
            for index in state.days.indices where state.days[index].dayKey != dayKey {
                state.days[index].unresolvedFollowUp = nil
            }
            entry.unresolvedFollowUp = nil
        } else if let followUp = output.followUp {
            entry.unresolvedFollowUp = followUp
        }
        if let insight = output.questionID {
            entry.insightID = insight
        }
        if let questionID = output.questionID, questionID.hasPrefix("open.") {
            state.lastOpeningVariantID = questionID
        }
        CoachAssistantMemoryStore.upsertDay(entry, into: &state)
        CoachAssistantMemoryStore.save(state)
    }

    private func makeAnalysisContext(checkInAt: Date) -> CoachAssistantScenarioAnalyzer.Context {
        // Only pass true when sharing is authorized. Never claim denial from empty samples.
        let authorized: Bool? = healthManager.isHealthAccessGranted ? true : nil
        return CoachAssistantScenarioAnalyzer.Context(
            feeling: conversation?.feeling,
            clarification: conversation?.clarification,
            checkInAt: checkInAt,
            observations: CoachObservationStore.allObservations(),
            plannedActivities: plannedActivities,
            recentActivityCount: conversation?.evidence.feelingEvidence.recentActivityCount ?? 0,
            recentActivityDayKeys: conversation?.evidence.feelingEvidence.recentActivityDayKeys ?? [],
            nutrition: nutritionContext,
            healthAccessGranted: authorized
        )
    }

    /// Prefer non-nil / fresher vitals from a new gather without wiping already-useful fields.
    private static func mergeFeelingEvidence(
        existing: CoachFeelingEvidenceSnapshot,
        fresh: CoachFeelingEvidenceSnapshot
    ) -> CoachFeelingEvidenceSnapshot {
        var merged = existing
        if fresh.sleepMinutes != nil {
            merged.sleepMinutes = fresh.sleepMinutes
            merged.sleepDayKey = fresh.sleepDayKey
            merged.sleepIsStale = fresh.sleepIsStale
        } else if existing.sleepMinutes == nil {
            merged.sleepIsStale = fresh.sleepIsStale
        }
        if fresh.sleepBaselineMinutes != nil {
            merged.sleepBaselineMinutes = fresh.sleepBaselineMinutes
            merged.sleepSampleCount = fresh.sleepSampleCount
        }
        if fresh.recoveryPercent != nil {
            merged.recoveryPercent = fresh.recoveryPercent
            merged.recoveryDayKey = fresh.recoveryDayKey
            merged.recoveryIsStale = fresh.recoveryIsStale
        } else if existing.recoveryPercent == nil {
            merged.recoveryIsStale = fresh.recoveryIsStale
        }
        if fresh.recoveryBaselinePercent != nil {
            merged.recoveryBaselinePercent = fresh.recoveryBaselinePercent
            merged.recoverySampleCount = fresh.recoverySampleCount
        }
        if fresh.recentActivityCount > existing.recentActivityCount {
            merged.recentActivityCount = fresh.recentActivityCount
            merged.recentActivityDayKeys = fresh.recentActivityDayKeys
        }
        return merged
    }

    private func loadRecentActivityContext(checkInAt: Date) async -> (dayKeys: [String], count: Int) {
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
        let dayKeys = Array(Set(sessions.map { CoachDailyObservation.dayKey(for: $0.startDate) })).sorted()
        return (dayKeys, sessions.count)
    }
}
