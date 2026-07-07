import Foundation
import SwiftUI

enum CoachStateStatus: Equatable {
    case ready
    case refreshingPrevious
    case unavailable(reason: String)
    case invalid(reason: String)
}

enum CoachTodayCoachInsightHiddenReason: String, Equatable, Sendable {
    case stateNotReady
    case noTodayPresentation
    case registryGap
    case settling
}

struct CoachState: Identifiable {
    let id: UUID
    let createdAt: Date
    let status: CoachStateStatus
    let input: CoachInputSnapshot?
    let fingerprint: CoachInputFingerprint?
    let coachUIPresentation: CoachUIPresentation?
    let coachIntegrationDebug: CoachIntegrationDebug?
    /// Optional reflection utterance at conversational pause. Nil unless understanding changed.
    let reflectionOffer: ReflectionOffer?

    var hasValidGuidance: Bool {
        coachUIPresentation != nil
    }

    var canRenderTodayCoachInsight: Bool {
        guard status == .ready || status == .refreshingPrevious else { return false }
        guard hasValidTodayPresentationContent else { return false }
        return coachUIPresentation != nil
    }

    var todayCoachInsightHiddenReason: CoachTodayCoachInsightHiddenReason? {
        if canRenderTodayCoachInsight { return nil }
        if isSettlingCoachState { return .settling }
        if status != .ready && status != .refreshingPrevious { return .stateNotReady }
        if coachUIPresentation == nil { return .registryGap }
        if !hasValidTodayPresentationContent { return .noTodayPresentation }
        return .stateNotReady
    }

    private var hasValidTodayPresentationContent: Bool {
        guard let ui = coachUIPresentation else { return false }
        return !ui.todayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isSettlingCoachState: Bool {
        guard case .unavailable = status else { return false }
        return input == nil && coachUIPresentation == nil
    }

    var statusLogLabel: String {
        switch status {
        case .ready:
            return "ready"
        case .refreshingPrevious:
            return "refreshingPrevious"
        case .unavailable(let reason):
            return "unavailable(\(reason))"
        case .invalid(let reason):
            return "invalid(\(reason))"
        }
    }

    static func unavailable(reason: String, createdAt: Date = Date()) -> CoachState {
        CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .unavailable(reason: reason),
            input: nil,
            fingerprint: nil,
            coachUIPresentation: nil,
            coachIntegrationDebug: nil,
            reflectionOffer: nil
        )
    }

    static func settling(reason: String, createdAt: Date = Date()) -> CoachState {
        CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .unavailable(reason: reason),
            input: nil,
            fingerprint: nil,
            coachUIPresentation: nil,
            coachIntegrationDebug: nil,
            reflectionOffer: nil
        )
    }

    static func ready(
        input: CoachInputSnapshot,
        fingerprint: CoachInputFingerprint,
        createdAt: Date = Date(),
        reason: String = "unspecified"
    ) -> CoachState {
        let readiness = CoachInputReadiness.assessment(input)
        guard readiness.allowed else {
            CoachLogger.trace(
                "[CoachInputReadiness]",
                [
                    "outcome=blockedDirectReady",
                    readiness.summary,
                    "rawRecovery=\(input.recoveryContext.recoveryPercent)",
                    "sleepHours=\(String(format: "%.2f", input.recoveryContext.sleepHours))",
                    "brainSleep=\(input.brain.sleep)",
                    "brainReadiness=\(input.brain.readiness)",
                    "source=\(input.source)"
                ].joined(separator: " ")
            )
            return .settling(reason: "Coach inputs are still syncing.", createdAt: createdAt)
        }

        let v6Result = CoachEngine.evaluate(input: input)
        var copyPack = v6Result.copyPack
        if readiness.dataReadinessState == .limitedRecovery, let pack = copyPack {
            copyPack = CoachLimitedRecoveryCopyPolicy.apply(to: pack)
        }
        let engineResultForPresentation = CoachEngine.Result(
            context: v6Result.context,
            resolution: v6Result.resolution,
            todayInsight: v6Result.todayInsight,
            copyPack: copyPack,
            morningBriefFacts: v6Result.morningBriefFacts
        )
        let coachUIPresentation = CoachTabPresentationBridge.build(
            from: engineResultForPresentation,
            showsLimitedConfidenceBadge: readiness.dataReadinessState == .limitedRecovery
        )
        let coachIntegrationDebug = CoachIntegrationDebug.resolve(
            from: v6Result,
            usingCoach: coachUIPresentation != nil
        )
        CoachIntegrationMetrics.record(
            debug: coachIntegrationDebug,
            recomputeReason: reason
        )
        logCoachIntegration(debug: coachIntegrationDebug, reason: reason)

        if coachUIPresentation == nil {
            logCoachRegistryGap(debug: coachIntegrationDebug, reason: reason)
        }

        let reflectionOffer = ReflectionComposer.compose(
            ReflectionComposer.Input(
                snapshot: input,
                context: v6Result.context,
                urgencyLevel: v6Result.todayInsight.urgencyLevel,
                safetyAlert: v6Result.todayInsight.safetyAlert,
                alertSeverity: v6Result.todayInsight.alertSeverity
            )
        )

        return CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .ready,
            input: input,
            fingerprint: fingerprint,
            coachUIPresentation: coachUIPresentation,
            coachIntegrationDebug: coachIntegrationDebug,
            reflectionOffer: reflectionOffer
        )
    }

    func preservingPreviousDuringRefresh(createdAt: Date = Date()) -> CoachState {
        guard hasValidGuidance else { return self }

        return CoachState(
            id: id,
            createdAt: createdAt,
            status: .refreshingPrevious,
            input: input,
            fingerprint: fingerprint,
            coachUIPresentation: coachUIPresentation,
            coachIntegrationDebug: coachIntegrationDebug,
            reflectionOffer: reflectionOffer
        )
    }

    private static func logCoachIntegration(
        debug: CoachIntegrationDebug,
        reason: String
    ) {
        CoachLogger.compact(
            "[CoachIntegration]",
            "\(debug.logSummary) recomputeReason=\(reason)"
        )
    }

    private static func logCoachRegistryGap(debug: CoachIntegrationDebug, reason: String) {
        CoachLogger.warning(
            "Coach registry gap scenario=\(debug.scenario.rawValue) fallbackReason=\(debug.fallbackReason ?? "unknown") recomputeReason=\(reason)"
        )
    }

    static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}

// MARK: - Registry gap chrome

extension CoachState {
    static var registryGapTitle: String {
        localized(english: "Preparing recommendations", russian: "Готовлю рекомендации")
    }

    static var registryGapMessage: String {
        localized(
            english: "Putting together today's guidance.",
            russian: "Собираю рекомендации на сегодня."
        )
    }

    static var registryGapIcon: String { "hourglass" }

    static var registryGapColor: Color { WeekFitTheme.secondaryText }
}
