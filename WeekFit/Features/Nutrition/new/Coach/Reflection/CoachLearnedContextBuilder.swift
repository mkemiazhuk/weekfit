import Foundation

enum CoachLearnedNudgeKind: String, Equatable, Sendable {
    case proteinGapOnTrainingDay
    case postWorkoutProteinGap
    case hardTrainingOnLowRecovery
}

struct CoachLearnedNudge: Equatable, Sendable {
    let kind: CoachLearnedNudgeKind
    let discoveryID: String
    let beliefID: CoachBeliefID
    let message: CoachBilingualText
    let currentProteinGrams: Int?
    let learnedRangeLowGrams: Int?
    let learnedRangeHighGrams: Int?
    let gapGrams: Int?
}

struct CoachLearnedContext: Equatable, Sendable {
    let activeDiscoveries: [CoachDiscovery]
    let relevantToday: [CoachLearnedNudge]

    static let empty = CoachLearnedContext(activeDiscoveries: [], relevantToday: [])

    var primaryNudge: CoachLearnedNudge? { relevantToday.first }
}

/// Builds today's Adapt nudges from learned discoveries + live Coach input.
/// Presentation-only — never changes scenario routing.
enum CoachLearnedContextBuilder {

    private static let minimumProteinGapGrams = 20
    private static let lowRecoveryThreshold = 60
    private static let postWorkoutProteinFloorGrams = 30

    static func build(
        input: CoachInputSnapshot,
        context: CoachContext,
        discoveries: [CoachDiscovery] = CoachDiscoveryStore.activeDiscoveries(),
        observations: [CoachDailyObservation] = CoachObservationStore.allObservations()
    ) -> CoachLearnedContext {
        let active = discoveries.filter { $0.status == .active }
        var nudges: [CoachLearnedNudge] = []

        if let protein = proteinGapNudge(
            input: input,
            context: context,
            discoveries: active,
            observations: observations
        ) {
            nudges.append(protein)
        }

        if let postWorkout = postWorkoutProteinNudge(
            input: input,
            context: context,
            discoveries: active,
            observations: observations
        ) {
            nudges.append(postWorkout)
        }

        if let hardLoad = hardTrainingLowRecoveryNudge(
            input: input,
            context: context,
            discoveries: active
        ) {
            nudges.append(hardLoad)
        }

        return CoachLearnedContext(activeDiscoveries: active, relevantToday: nudges)
    }

    // MARK: - Protein on training days

    private static func proteinGapNudge(
        input: CoachInputSnapshot,
        context: CoachContext,
        discoveries: [CoachDiscovery],
        observations: [CoachDailyObservation]
    ) -> CoachLearnedNudge? {
        guard let discovery = discoveries.first(where: { $0.beliefID == .proteinTrainingDayRecovery }) else {
            return nil
        }
        guard isTrainingDay(input: input, context: context) else { return nil }
        guard let nutrition = input.nutritionContext else { return nil }

        let current = Int(nutrition.proteinCurrent.rounded())
        guard let evaluation = ProteinTrainingDayRecoveryBeliefEvaluator.analyze(observations: observations),
              evaluation.recoveryDelta > 0 else {
            return nil
        }

        let rangeLow = max(
            evaluation.lowProteinMedianGrams + 10,
            Int(((Double(evaluation.lowProteinMedianGrams) + Double(evaluation.highProteinMedianGrams)) / 2.0).rounded())
        )
        let rangeHigh = evaluation.highProteinMedianGrams + 10
        guard current < rangeLow else { return nil }

        let gap = rangeLow - current
        guard gap >= minimumProteinGapGrams else { return nil }

        return CoachLearnedNudge(
            kind: .proteinGapOnTrainingDay,
            discoveryID: discovery.id,
            beliefID: discovery.beliefID,
            message: .en(
                "\(current) g protein today — your recovery is usually better on training days around \(rangeLow)–\(rangeHigh) g. You're about \(gap) g below that range.",
                "Сегодня \(current) г белка — восстановление у вас обычно лучше в тренировочные дни около \(rangeLow)–\(rangeHigh) г. Вы примерно на \(gap) г ниже этого диапазона."
            ),
            currentProteinGrams: current,
            learnedRangeLowGrams: rangeLow,
            learnedRangeHighGrams: rangeHigh,
            gapGrams: gap
        )
    }

    // MARK: - Post-workout protein

    private static func postWorkoutProteinNudge(
        input: CoachInputSnapshot,
        context: CoachContext,
        discoveries: [CoachDiscovery],
        observations: [CoachDailyObservation]
    ) -> CoachLearnedNudge? {
        guard let discovery = discoveries.first(where: { $0.beliefID == .postWorkoutProteinRecovery }) else {
            return nil
        }
        guard context.completedSeriousActivities != .none else { return nil }

        let todayKey = CoachDailyObservation.dayKey(for: Date())
        let todayObservation = observations.first { $0.dayKey == todayKey }
        let windowProtein = todayObservation?.proteinWithinPostWorkoutWindowGrams
            ?? Int(input.nutritionContext?.proteinCurrent.rounded() ?? 0)

        guard windowProtein < postWorkoutProteinFloorGrams else { return nil }

        guard let evaluation = PostWorkoutProteinRecoveryBeliefEvaluator.analyze(observations: observations),
              evaluation.recoveryDelta > 0 else {
            return nil
        }

        let target = max(evaluation.splitThresholdGrams, postWorkoutProteinFloorGrams)
        let gap = max(0, target - windowProtein)
        guard gap >= 15 else { return nil }

        return CoachLearnedNudge(
            kind: .postWorkoutProteinGap,
            discoveryID: discovery.id,
            beliefID: discovery.beliefID,
            message: .en(
                "After harder sessions, your recovery tends to be better when you get enough protein afterward. You're still short of the range that usually works for you.",
                "После более тяжёлых тренировок восстановление у вас обычно лучше, если после них достаточно белка. Сейчас вы ещё не в диапазоне, который обычно вам подходит."
            ),
            currentProteinGrams: windowProtein,
            learnedRangeLowGrams: target,
            learnedRangeHighGrams: target + 20,
            gapGrams: gap
        )
    }

    // MARK: - Hard training while poorly recovered

    private static func hardTrainingLowRecoveryNudge(
        input: CoachInputSnapshot,
        context: CoachContext,
        discoveries: [CoachDiscovery]
    ) -> CoachLearnedNudge? {
        guard let discovery = discoveries.first(where: { $0.beliefID == .hardTrainingLowRecoveryCost }) else {
            return nil
        }

        let recovery = input.recoveryContext.recoveryPercent
        guard recovery > 0, recovery < lowRecoveryThreshold else { return nil }

        let hardStillAhead = input.dayContext.upcomingTrainingActivities.contains {
            CoachActivityClassifier.isSeriousTraining($0)
        }
        let hardAlreadyDone = context.completedSeriousActivities != .none
            || context.dayLoadBand == .heavy
            || context.dayLoadBand == .extreme

        // Prefer caution before stacking more hard work; also relevant mid-day after a hard session on low recovery.
        guard hardStillAhead || hardAlreadyDone else { return nil }

        return CoachLearnedNudge(
            kind: .hardTrainingOnLowRecovery,
            discoveryID: discovery.id,
            beliefID: discovery.beliefID,
            message: .en(
                "Hard sessions on your lower-recovery days tend to make the following morning harder. Today's recovery is still low — keep that pattern in mind.",
                "Тяжёлые тренировки в дни с низким восстановлением у вас обычно делают следующее утро тяжелее. Сегодня восстановление ещё низкое — стоит помнить об этом паттерне."
            ),
            currentProteinGrams: nil,
            learnedRangeLowGrams: nil,
            learnedRangeHighGrams: nil,
            gapGrams: nil
        )
    }

    // MARK: - Helpers

    /// Soft Morning Adjustments preference — never a hard routing block by itself.
    static func preferAvoidHardLoadOnLowRecovery(
        recoveryPercent: Int?,
        discoveries: [CoachDiscovery] = CoachDiscoveryStore.activeDiscoveries()
    ) -> Bool {
        guard discoveries.contains(where: {
            $0.beliefID == .hardTrainingLowRecoveryCost && $0.status == .active
        }) else {
            return false
        }
        guard let recovery = recoveryPercent, recovery > 0, recovery < lowRecoveryThreshold else {
            return false
        }
        return true
    }

    static func isTrainingDay(input: CoachInputSnapshot, context: CoachContext) -> Bool {
        if input.dayContext.hasMeaningfulLoadCompleted { return true }
        if context.completedSeriousActivities != .none { return true }
        if !input.dayContext.upcomingTrainingActivities.isEmpty { return true }
        switch context.dayLoadBand {
        case .moderate, .heavy, .extreme:
            return true
        case .fresh:
            return false
        }
    }
}
