import Foundation
import SwiftUI

struct CoachTodayPresentation {
    let intent: CoachTabPresentationIntent
    let statusLabel: String
    let title: String
    let message: String
    let icon: String
    let color: Color

    init(
        intent: CoachTabPresentationIntent = .statusAction,
        statusLabel: String,
        title: String,
        message: String,
        icon: String,
        color: Color
    ) {
        self.intent = intent
        self.statusLabel = statusLabel
        self.title = title
        self.message = message
        self.icon = icon
        self.color = color
    }
}

struct CoachScreenPresentation {
    let intent: CoachTabPresentationIntent
    let stateLabel: String
    let title: String
    let message: String
    let recommendation: String
    let icon: String
    let color: Color
    let contextChip: CoachActivityContextChip?
    let whyRows: [CoachPresentationWhyRow]
    let supportActions: [CoachSupportAction]
    let avoidNotes: [String]

    init(
        intent: CoachTabPresentationIntent = .interpretation,
        stateLabel: String,
        title: String,
        message: String,
        recommendation: String,
        icon: String,
        color: Color,
        contextChip: CoachActivityContextChip? = nil,
        whyRows: [CoachPresentationWhyRow] = [],
        supportActions: [CoachSupportAction] = [],
        avoidNotes: [String] = []
    ) {
        self.intent = intent
        self.stateLabel = stateLabel
        self.title = title
        self.message = message
        self.recommendation = recommendation
        self.icon = icon
        self.color = color
        self.contextChip = contextChip
        self.whyRows = whyRows
        self.supportActions = supportActions
        self.avoidNotes = avoidNotes
    }
}

typealias CoachFullPresentation = CoachScreenPresentation

struct CoachRationalePresentation {
    let title: String
    let message: String
    let icon: String
    let color: Color
    let sourceActivityID: String
}

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
    let todayPresentation: CoachTodayPresentation
    let coachPresentation: CoachScreenPresentation?
    let rationalePresentation: CoachRationalePresentation?
    let coachUIPresentation: CoachUIPresentation?
    let coachIntegrationDebug: CoachIntegrationDebug?

    var hasValidGuidance: Bool {
        coachUIPresentation != nil && coachPresentation != nil
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
        if !hasValidTodayPresentationContent { return .noTodayPresentation }
        if coachUIPresentation == nil { return .registryGap }
        return .stateNotReady
    }

    private var hasValidTodayPresentationContent: Bool {
        !todayPresentation.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            todayPresentation: CoachTodayPresentation(
                statusLabel: "OVERVIEW",
                title: WeekFitLocalizedString("coach.unavailable.title"),
                message: WeekFitLocalizedString("coach.unavailable.message"),
                icon: "sparkles",
                color: WeekFitTheme.secondaryText
            ),
            coachPresentation: nil,
            rationalePresentation: nil,
            coachUIPresentation: nil,
            coachIntegrationDebug: nil
        )
    }

    static func settling(reason: String, createdAt: Date = Date()) -> CoachState {
        CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .unavailable(reason: reason),
            input: nil,
            fingerprint: nil,
            todayPresentation: CoachTodayPresentation(
                statusLabel: localized(english: "REFINING", russian: "УТОЧНЯЮ"),
                title: localized(english: "Recommendations refining", russian: "Рекомендации уточняются"),
                message: localized(
                    english: "Coach is assembling today's picture. Recommendations will sharpen as your data comes in.",
                    russian: "Собираю полную картину вашего дня. Рекомендации станут точнее, когда появятся данные."
                ),
                icon: "hourglass",
                color: WeekFitTheme.secondaryText
            ),
            coachPresentation: nil,
            rationalePresentation: nil,
            coachUIPresentation: nil,
            coachIntegrationDebug: nil
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
        let presentationBridge = CoachTabPresentationBridge.build(from: v6Result)
        let coachIntegrationDebug = CoachIntegrationDebug.resolve(
            from: v6Result,
            usingCoach: presentationBridge != nil
        )
        CoachIntegrationMetrics.record(
            debug: coachIntegrationDebug,
            recomputeReason: reason
        )
        logCoachIntegration(debug: coachIntegrationDebug, reason: reason)

        let todayPresentation: CoachTodayPresentation
        let coachPresentation: CoachScreenPresentation?
        let coachUIPresentation: CoachUIPresentation?

        if let presentationBridge {
            todayPresentation = presentationBridge.today
            coachPresentation = presentationBridge.coach
            coachUIPresentation = presentationBridge.ui
        } else {
            todayPresentation = registryGapTodayPresentation(scenario: v6Result.scenario)
            coachPresentation = nil
            coachUIPresentation = nil
            logCoachRegistryGap(debug: coachIntegrationDebug, reason: reason)
        }

        return CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .ready,
            input: input,
            fingerprint: fingerprint,
            todayPresentation: todayPresentation,
            coachPresentation: coachPresentation,
            rationalePresentation: CoachRationalePresentation.resolve(from: input),
            coachUIPresentation: coachUIPresentation,
            coachIntegrationDebug: coachIntegrationDebug
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
            todayPresentation: todayPresentation,
            coachPresentation: coachPresentation,
            rationalePresentation: rationalePresentation,
            coachUIPresentation: coachUIPresentation,
            coachIntegrationDebug: coachIntegrationDebug
        )
    }

    private static func logCoachIntegration(
        debug: CoachIntegrationDebug,
        reason: String
    ) {
        #if DEBUG
        CoachLogger.compact(
            "[CoachIntegration]",
            "\(debug.logSummary) recomputeReason=\(reason)"
        )
        #endif
    }

    private static func logCoachRegistryGap(debug: CoachIntegrationDebug, reason: String) {
        CoachLogger.warning(
            "Coach registry gap scenario=\(debug.scenario.rawValue) fallbackReason=\(debug.fallbackReason ?? "unknown") recomputeReason=\(reason)"
        )
    }

    private static func registryGapTodayPresentation(scenario: CoachScenarioKey) -> CoachTodayPresentation {
        CoachTodayPresentation(
            statusLabel: localized(english: "PREPARING", russian: "ПОДГОТОВКА"),
            title: localized(english: "Preparing recommendations", russian: "Готовлю рекомендации"),
            message: localized(
                english: "Putting together today's guidance.",
                russian: "Собираю рекомендации на сегодня."
            ),
            icon: "hourglass",
            color: WeekFitTheme.secondaryText
        )
    }

    static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}
