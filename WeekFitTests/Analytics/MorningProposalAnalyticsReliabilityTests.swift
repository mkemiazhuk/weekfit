import XCTest
@testable import WeekFit

final class MorningProposalAnalyticsReliabilityTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var recording: RecordingAnalyticsService!

    override func setUp() {
        super.setUp()
        suiteName = "weekfit.tests.mp.analytics.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        recording = RecordingAnalyticsService()
        AppAnalytics.setSharedForTests(recording)
        ProductScreenTracker.shared.resetForTests()

        MorningProposalAnalytics.resetAllForTests()
        MorningProposalAnalytics.setDefaultsForTests(defaults)
        MorningProposalAnalytics.setAnalyticsForTests { AppAnalytics.shared }

        ActivationAnalytics.resetAllForTests()
        ActivationAnalytics.setDefaultsForTests(defaults)
        ActivationAnalytics.setAnalyticsForTests { AppAnalytics.shared }
    }

    override func tearDown() {
        MorningProposalAnalytics.resetAllForTests()
        ActivationAnalytics.resetAllForTests()
        AppAnalytics.resetSharedForTests()
        ProductScreenTracker.shared.resetForTests()
        defaults.removePersistentDomain(forName: suiteName)
        recording = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Unavailable dedupe

    func testUnavailableSameDaySameReasonEmitsOnce() {
        let day = "2026-08-24"
        MorningProposalAnalytics.proposalUnavailable(dayKey: day, reason: "outside_window")
        MorningProposalAnalytics.proposalUnavailable(dayKey: day, reason: "outside_window")
        MorningProposalAnalytics.proposalUnavailable(dayKey: day, reason: "outside_morning_window")

        let events = recording.events(named: .morningProposalUnavailable)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(
            events.first?.parameters[AnalyticsParameterKey.reason],
            MorningProposalUnavailableAnalyticsReason.outsideMorningWindow.rawValue
        )
    }

    func testUnavailableSameDayDifferentReasonsEmitTwice() {
        let day = "2026-08-24"
        MorningProposalAnalytics.proposalUnavailable(dayKey: day, reason: "missing_inputs")
        MorningProposalAnalytics.proposalUnavailable(dayKey: day, reason: "outside_window")

        let events = recording.events(named: .morningProposalUnavailable)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(
            Set(events.compactMap { $0.parameters[AnalyticsParameterKey.reason] }),
            Set([
                MorningProposalUnavailableAnalyticsReason.missingInputs.rawValue,
                MorningProposalUnavailableAnalyticsReason.outsideMorningWindow.rawValue
            ])
        )
    }

    func testUnavailableNextDayReEmits() {
        MorningProposalAnalytics.proposalUnavailable(dayKey: "2026-08-24", reason: "outside_window")
        MorningProposalAnalytics.proposalUnavailable(dayKey: "2026-08-25", reason: "outside_window")

        XCTAssertEqual(recording.events(named: .morningProposalUnavailable).count, 2)
    }

    func testRepeatedLifecycleRefreshesDoNotDuplicateUnavailable() {
        let day = "2026-08-24"
        // Simulate Today appear + settled metrics + scene active + coordinator refresh.
        for _ in 0..<8 {
            MorningProposalAnalytics.proposalUnavailable(dayKey: day, reason: "day_started")
        }
        XCTAssertEqual(recording.events(named: .morningProposalUnavailable).count, 1)
    }

    // MARK: - Reason mapping

    func testKnownGateReasonsDoNotCollapseToOther() {
        let pairs: [(String, MorningProposalUnavailableAnalyticsReason)] = [
            ("outside_window", .outsideMorningWindow),
            ("outside_morning_window", .outsideMorningWindow),
            ("day_started", .dayStarted),
            ("day_expired", .dayExpired),
            ("expired", .dayExpired),
            ("health_access_denied", .other),
            ("timeout", .timeout),
            ("missing_inputs", .missingInputs)
        ]
        for (domain, expected) in pairs {
            XCTAssertEqual(
                MorningProposalUnavailableAnalyticsReason.fromDomainReason(domain),
                expected,
                "domain reason \(domain)"
            )
        }
        XCTAssertEqual(
            MorningProposalUnavailableAnalyticsReason.fromDomainReason("totally_unknown_xyz"),
            .other
        )
    }

    func testUnavailableEmitsCanonicalReasonStrings() {
        MorningProposalAnalytics.proposalUnavailable(dayKey: "2026-08-24", reason: "outside_window")
        MorningProposalAnalytics.proposalUnavailable(dayKey: "2026-08-24", reason: "day_started")

        let reasons = recording.parameterValues(
            for: .morningProposalUnavailable,
            key: AnalyticsParameterKey.reason
        )
        XCTAssertEqual(
            Set(reasons),
            Set([
                MorningProposalUnavailableAnalyticsReason.outsideMorningWindow.rawValue,
                MorningProposalUnavailableAnalyticsReason.dayStarted.rawValue
            ])
        )
        XCTAssertFalse(reasons.contains("other"))
        XCTAssertFalse(reasons.contains("outside_window"))
    }

    // MARK: - No-change dedupe

    func testNoChangesSameDayEmitsOnce() {
        let day = "2026-08-24"
        MorningProposalAnalytics.proposalNoChanges(dayKey: day)
        MorningProposalAnalytics.proposalNoChanges(dayKey: day)
        MorningProposalAnalytics.proposalNoChanges(dayKey: day)

        XCTAssertEqual(recording.events(named: .morningProposalNoChanges).count, 1)
    }

    func testNoChangesNextDayReEmits() {
        MorningProposalAnalytics.proposalNoChanges(dayKey: "2026-08-24")
        MorningProposalAnalytics.proposalNoChanges(dayKey: "2026-08-25")
        XCTAssertEqual(recording.events(named: .morningProposalNoChanges).count, 2)
    }

    // MARK: - Activation milestones

    func testTodayFirstViewEmitsOnce() {
        ActivationAnalytics.trackTodayFirstViewIfNeeded()
        ActivationAnalytics.trackTodayFirstViewIfNeeded()
        ProductAnalytics.trackTab(.today)
        ProductAnalytics.trackTab(.today)

        XCTAssertEqual(recording.events(named: .todayFirstView).count, 1)
    }

    func testRecoveryAvailableEmitsOncePerDay() {
        ActivationAnalytics.trackRecoveryAvailableIfNeeded(
            dayKey: "2026-08-24",
            recoveryDataAvailable: true,
            hasSettledMetrics: true,
            hasRecoverySignals: false
        )
        ActivationAnalytics.trackRecoveryAvailableIfNeeded(
            dayKey: "2026-08-24",
            recoveryDataAvailable: true,
            hasSettledMetrics: true,
            hasRecoverySignals: true
        )

        let events = recording.events(named: .recoveryAvailable)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.parameters[AnalyticsParameterKey.source], "today")
        XCTAssertNil(events.first?.parameters["recovery_band"])
        XCTAssertNil(events.first?.parameters["has_sleep_data"])
        XCTAssertNil(events.first?.parameters["source_state"])
    }

    func testRecoveryAvailableSkippedWhenNotUsable() {
        ActivationAnalytics.trackRecoveryAvailableIfNeeded(
            dayKey: "2026-08-24",
            recoveryDataAvailable: false,
            hasSettledMetrics: true,
            hasRecoverySignals: true
        )
        ActivationAnalytics.trackRecoveryAvailableIfNeeded(
            dayKey: "2026-08-24",
            recoveryDataAvailable: true,
            hasSettledMetrics: false,
            hasRecoverySignals: false
        )
        XCTAssertEqual(recording.events(named: .recoveryAvailable).count, 0)
    }

    // MARK: - Environment policy

    func testDistributionPolicyMatchesAudit() {
        XCTAssertEqual(
            AppDistribution.resolve(isDebugBuild: true, receiptURL: nil),
            .debug
        )
        XCTAssertEqual(
            AppDistribution.resolve(
                isDebugBuild: false,
                receiptURL: URL(fileURLWithPath: "/receipts/sandboxReceipt")
            ),
            .testFlight
        )
        XCTAssertEqual(
            AppDistribution.resolve(
                isDebugBuild: false,
                receiptURL: URL(fileURLWithPath: "/receipts/receipt")
            ),
            .appStore
        )
        #if DEBUG
        XCTAssertEqual(AppDistribution.current, .debug)
        #endif
    }
}
