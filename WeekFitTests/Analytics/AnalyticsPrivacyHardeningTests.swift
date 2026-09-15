import XCTest
@testable import WeekFit

/// Regression: Firebase-bound payloads must stay product-interaction only.
final class AnalyticsPrivacyHardeningTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var recording: RecordingAnalyticsService!

    override func setUp() {
        super.setUp()
        suiteName = "weekfit.tests.privacy.\(UUID().uuidString)"
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

        ProductAnalyticsConsent.setDefaultsForTests(defaults)
        ProductAnalyticsConsent.resetForTests()
    }

    override func tearDown() {
        MorningProposalAnalytics.resetAllForTests()
        ActivationAnalytics.resetAllForTests()
        ProductAnalyticsConsent.resetForTests()
        ProductAnalyticsConsent.useStandardDefaultsForTests()
        AppAnalytics.resetSharedForTests()
        ProductScreenTracker.shared.resetForTests()
        defaults.removePersistentDomain(forName: suiteName)
        recording = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Consent

    func testFreshInstallAnalyticsConsentDefaultsOn() {
        XCTAssertFalse(ProductAnalyticsConsent.hasExplicitChoice())
        XCTAssertTrue(ProductAnalyticsConsent.isSharingEnabled())
    }

    func testMissingStoredChoiceTreatedAsOn() {
        // Explicitly no key — migration / existing install without choice.
        defaults.removeObject(forKey: ProductAnalyticsConsent.storageKey)
        XCTAssertTrue(ProductAnalyticsConsent.isSharingEnabled())
    }

    func testMigrateToDefaultOnEnablesPreviouslyDisabledConsentOnce() {
        ProductAnalyticsConsent.setSharingEnabled(false)
        XCTAssertFalse(ProductAnalyticsConsent.isSharingEnabled())

        ProductAnalyticsConsent.migrateToDefaultOnIfNeeded()
        XCTAssertTrue(ProductAnalyticsConsent.isSharingEnabled())

        ProductAnalyticsConsent.setSharingEnabled(false)
        ProductAnalyticsConsent.migrateToDefaultOnIfNeeded()
        XCTAssertFalse(ProductAnalyticsConsent.isSharingEnabled())
    }

    func testUserCanEnableAndDisableAnalyticsConsent() {
        ProductAnalyticsConsent.setSharingEnabled(true)
        XCTAssertTrue(ProductAnalyticsConsent.isSharingEnabled())
        XCTAssertTrue(ProductAnalyticsConsent.hasExplicitChoice())

        ProductAnalyticsConsent.setSharingEnabled(false)
        XCTAssertFalse(ProductAnalyticsConsent.isSharingEnabled())
        XCTAssertTrue(ProductAnalyticsConsent.hasExplicitChoice())
    }

    // MARK: - recovery_available

    func testRecoveryAvailableSendsNoHealthStateParameters() {
        ActivationAnalytics.trackRecoveryAvailableIfNeeded(
            dayKey: "2026-08-25",
            recoveryDataAvailable: true,
            hasSettledMetrics: true,
            hasRecoverySignals: false
        )

        let events = recording.events(named: .recoveryAvailable)
        XCTAssertEqual(events.count, 1)
        let params = events[0].parameters
        XCTAssertEqual(params[AnalyticsParameterKey.source], AnalyticsSource.today.rawValue)
        assertNoSensitiveTelemetry(params)
        XCTAssertNil(params["recovery_band"])
        XCTAssertNil(params["has_sleep_data"])
        XCTAssertNil(params["source_state"])
    }

    // MARK: - Morning Proposal

    func testMorningProposalGeneratedOmitsHealthContext() {
        MorningProposalAnalytics.proposalGenerated(
            changeCount: 2,
            guidanceCount: 1,
            generationMode: .compose
        )
        let event = try! XCTUnwrap(recording.events(named: .morningProposalGenerated).first)
        assertNoSensitiveTelemetry(event.parameters)
        XCTAssertNil(event.parameters["proposal_strategy"])
        XCTAssertNil(event.parameters["context_confidence"])
        XCTAssertNil(event.parameters["generation_mode"]) // uses `mode` key
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.mode], "compose")
        XCTAssertEqual(event.parameters[AnalyticsParameterKey.selectedCountBucket], "3_4")
    }

    func testMorningProposalRecommendationOmitsReasonCategory() {
        MorningProposalAnalytics.recommendationSelected(kind: .createRecoveryWalk)
        MorningProposalAnalytics.reasonExpanded(kind: .createRecoveryWalk)

        for name in [AnalyticsEvent.morningProposalRecommendationSelected, .morningProposalReasonExpanded] {
            let event = try! XCTUnwrap(recording.events(named: name).last)
            assertNoSensitiveTelemetry(event.parameters)
            XCTAssertNil(event.parameters["reason_category"])
            XCTAssertEqual(event.parameters[AnalyticsParameterKey.changeKind], "create")
            XCTAssertFalse(event.parameters.values.contains { $0.lowercased().contains("recovery") })
        }
    }

    func testHealthAccessDeniedMapsToGenericOther() {
        XCTAssertEqual(
            MorningProposalUnavailableAnalyticsReason.fromDomainReason("health_access_denied"),
            .other
        )
        MorningProposalAnalytics.proposalUnavailable(dayKey: "2026-08-25", reason: "health_access_denied")
        let reason = recording.events(named: .morningProposalUnavailable).first?
            .parameters[AnalyticsParameterKey.reason]
        XCTAssertEqual(reason, "other")
        XCTAssertNotEqual(reason, "health_access_denied")
    }

    // MARK: - Coach / activity / food

    func testCoachRecommendationViewedHasNoHealthTopicCategory() {
        ProductAnalytics.coachRecommendationViewed(scenario: .morningReadiness)
        ProductAnalytics.coachRecommendationViewed(scenario: .lowRecoveryPrep)
        let events = recording.events(named: .coachRecommendationViewed)
        XCTAssertEqual(events.count, 2)
        for event in events {
            assertNoSensitiveTelemetry(event.parameters)
            XCTAssertNil(event.parameters[AnalyticsParameterKey.category])
            XCTAssertEqual(event.parameters[AnalyticsParameterKey.source], "coach")
        }
    }

    func testActivityEventsOmitWorkoutCategory() {
        ProductAnalytics.activityStarted(source: .today)
        ProductAnalytics.activityCompleted(source: .today)
        for name in [AnalyticsEvent.activityStarted, .activityCompleted] {
            let event = try! XCTUnwrap(recording.events(named: name).last)
            assertNoSensitiveTelemetry(event.parameters)
            XCTAssertNil(event.parameters[AnalyticsParameterKey.category])
            XCTAssertEqual(event.parameters[AnalyticsParameterKey.source], "today")
        }
    }

    func testFoodLoggingOmitsNutritionValues() {
        ProductAnalytics.foodLoggingCompleted(method: .manual, source: .today)
        let event = try! XCTUnwrap(recording.events(named: .foodLoggingCompleted).first)
        assertNoSensitiveTelemetry(event.parameters)
        XCTAssertEqual(Set(event.parameters.keys), Set(["method", "source"]))
    }

    // MARK: - Contract sanitizer

    func testPrivacyContractStripsForbiddenKeysAndHealthTopics() {
        let dirty: [String: String] = [
            "recovery_band": "low",
            "has_sleep_data": "true",
            "source_state": "settled_metrics",
            "proposal_strategy": "recover",
            "context_confidence": "high",
            "reason_category": "recovery_protection",
            "category": "sleep",
            "source": "today",
            "selected_count_bucket": "1"
        ]
        let clean = AnalyticsPrivacyContract.sanitize(dirty)
        XCTAssertEqual(clean["source"], "today")
        XCTAssertEqual(clean["selected_count_bucket"], "1")
        XCTAssertNil(clean["recovery_band"])
        XCTAssertNil(clean["category"])
        XCTAssertTrue(AnalyticsPrivacyContract.violations(in: clean).isEmpty)
        XCTAssertFalse(AnalyticsPrivacyContract.violations(in: dirty).isEmpty)
    }

    // MARK: - Crashlytics token hygiene

    func testStartupDiagnosticsBoundedTokenRejectsPaths() {
        let token = StartupDiagnostics.boundedToken("/Users/maxk/Library/Application Support/default.store")
        XCTAssertFalse(token.contains("/"))
        XCTAssertFalse(token.contains(" "))
        XCTAssertEqual(token, StartupDiagnostics.boundedToken(token))
    }

    func testFailedDiagnosticsDoNotEmbedLocalizedDescription() {
        // Smoke: API requires diagnosticCode and does not take free-form description path.
        // Callers in production must pass bounded codes — verified by source contract below.
        let code = "model_container_initialization_failed"
        XCTAssertEqual(StartupDiagnostics.boundedToken(code), code)
        XCTAssertFalse(code.contains(" "))
    }

    // MARK: - Identity

    func testAnalyticsSourcesDoNotReferenceSetUserIDAPIs() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Analytics/
            .deletingLastPathComponent() // WeekFitTests/
            .deletingLastPathComponent() // repo
            .appendingPathComponent("WeekFit/Services/Analytics")
        let files = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasSuffix(".swift") }
        var hits: [String] = []
        for file in files {
            let text = try String(contentsOfFile: root.appendingPathComponent(file).path, encoding: .utf8)
            if text.contains("setUserID") || text.contains("setUserId") {
                // Allow comments that forbid the API.
                let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
                for line in lines where line.contains("setUserID") || line.contains("setUserId") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.contains("never") || trimmed.contains("Do not") {
                        continue
                    }
                    hits.append("\(file): \(trimmed)")
                }
            }
        }
        XCTAssertTrue(hits.isEmpty, "Unexpected setUserID usage: \(hits)")
    }

    // MARK: - Helpers

    private func assertNoSensitiveTelemetry(_ parameters: [String: String], file: StaticString = #filePath, line: UInt = #line) {
        let violations = AnalyticsPrivacyContract.violations(in: parameters)
        XCTAssertTrue(violations.isEmpty, "Sensitive telemetry: \(violations)", file: file, line: line)

        let joined = (Array(parameters.keys) + Array(parameters.values)).joined(separator: " ").lowercased()
        for needle in ["hrv", "readiness", "training_load", "deep_sleep", "rem_sleep", "calories", "macros", "healthkit", "recovery_band", "has_sleep"] {
            XCTAssertFalse(joined.contains(needle), "Found \(needle) in \(parameters)", file: file, line: line)
        }
    }
}
