import XCTest
@testable import WeekFit

final class TodayCoachInsightResolverTests: XCTestCase {

    func testReadyCoachStateShowsInsight() {
        let state = makeReadyState(title: "Recovering")
        let phase = TodayCoachInsightResolver.resolve(
            TodayCoachInsightResolver.Input(
                coachState: state,
                cachedPresentation: nil,
                shouldShowHealthConnectPrompt: false,
                hasRecoverySignals: true,
                isHealthMetricsSettled: true
            )
        )

        guard case .insight(let presentation, let isRefreshing) = phase else {
            return XCTFail("Expected insight phase")
        }
        XCTAssertEqual(presentation.todayTitle, "Recovering")
        XCTAssertFalse(isRefreshing)
    }

    func testRefreshingPreviousShowsInsightWithoutFallbackCard() {
        let presentation = samplePresentation
        let state = CoachState(
            id: UUID(),
            createdAt: Date(),
            status: .refreshingPrevious,
            input: nil,
            fingerprint: nil,
            coachUIPresentation: presentation,
            coachIntegrationDebug: nil,
            reflectionOffer: nil
        )

        let phase = TodayCoachInsightResolver.resolve(
            TodayCoachInsightResolver.Input(
                coachState: state,
                cachedPresentation: nil,
                shouldShowHealthConnectPrompt: false,
                hasRecoverySignals: false,
                isHealthMetricsSettled: false
            )
        )

        guard case .insight(let resolved, let isRefreshing) = phase else {
            return XCTFail("Expected insight phase")
        }
        XCTAssertEqual(resolved.todayTitle, presentation.todayTitle)
        XCTAssertTrue(isRefreshing)
    }

    func testCachedPresentationUsedDuringColdStart() {
        let cached = samplePresentation
        let phase = TodayCoachInsightResolver.resolve(
            TodayCoachInsightResolver.Input(
                coachState: .unavailable(reason: "Coach inputs have not been collected yet."),
                cachedPresentation: cached,
                shouldShowHealthConnectPrompt: false,
                hasRecoverySignals: true,
                isHealthMetricsSettled: false
            )
        )

        guard case .insight(let presentation, let isRefreshing) = phase else {
            return XCTFail("Expected cached insight phase")
        }
        XCTAssertEqual(presentation.todayTitle, cached.todayTitle)
        XCTAssertTrue(isRefreshing)
    }

    func testAwaitingMorningSyncWhenNoRecoverySignalsAndNoCache() {
        let phase = TodayCoachInsightResolver.resolve(
            TodayCoachInsightResolver.Input(
                coachState: .unavailable(reason: "Coach inputs have not been collected yet."),
                cachedPresentation: nil,
                shouldShowHealthConnectPrompt: false,
                hasRecoverySignals: false,
                isHealthMetricsSettled: false
            )
        )

        XCTAssertEqual(phase, .awaitingMorningSync)
    }

    func testPreparingWhenRecoveryExistsButCoachNotReady() {
        let phase = TodayCoachInsightResolver.resolve(
            TodayCoachInsightResolver.Input(
                coachState: .unavailable(reason: "Coach inputs have not been collected yet."),
                cachedPresentation: nil,
                shouldShowHealthConnectPrompt: false,
                hasRecoverySignals: true,
                isHealthMetricsSettled: true
            )
        )

        XCTAssertEqual(phase, .preparing)
    }

    private func makeReadyState(title: String) -> CoachState {
        var presentation = samplePresentation
        presentation = CoachUIPresentation(
            scenario: presentation.scenario,
            assessment: presentation.assessment,
            recommendation: presentation.recommendation,
            avoid: presentation.avoid,
            nextAction: presentation.nextAction,
            supportingSignals: presentation.supportingSignals,
            warningMessage: presentation.warningMessage,
            warningAlert: presentation.warningAlert,
            semanticColor: presentation.semanticColor,
            alertSeverity: presentation.alertSeverity,
            icon: presentation.icon,
            urgencyLevel: presentation.urgencyLevel,
            statusLabel: presentation.statusLabel,
            coachTitle: presentation.coachTitle,
            todayTitle: title,
            todayMessage: presentation.todayMessage,
            whyRows: presentation.whyRows,
            showsLimitedConfidenceBadge: presentation.showsLimitedConfidenceBadge
        )

        return CoachState(
            id: UUID(),
            createdAt: Date(),
            status: .ready,
            input: nil,
            fingerprint: nil,
            coachUIPresentation: presentation,
            coachIntegrationDebug: nil,
            reflectionOffer: nil
        )
    }

    private var samplePresentation: CoachUIPresentation {
        CoachUIPresentation(
            scenario: .walkAfterHeavyLoad,
            assessment: "Assessment",
            recommendation: "Recommendation",
            avoid: "Avoid",
            nextAction: "Next",
            supportingSignals: [],
            warningMessage: nil,
            warningAlert: nil,
            semanticColor: .recovery,
            alertSeverity: .none,
            icon: "figure.walk",
            urgencyLevel: .calm,
            statusLabel: "Recovering",
            coachTitle: "Recovering",
            todayTitle: "Recovering",
            todayMessage: "Take it easy today.",
            whyRows: [],
            showsLimitedConfidenceBadge: false
        )
    }
}
