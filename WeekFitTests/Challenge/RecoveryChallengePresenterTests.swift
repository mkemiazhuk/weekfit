import XCTest
@testable import WeekFit

final class RecoveryChallengePresenterTests: XCTestCase {

    private var utc: TimeZone { TimeZone(secondsFromGMT: 0)! }

    func testAutoIntroRequiresEligibilityAndOnboarding() {
        XCTAssertFalse(
            RecoveryChallengePresenter.shouldOfferAutoIntroOverlay(
                participation: nil,
                introShownForEventID: nil,
                featureAvailable: true,
                onboardingComplete: false,
                todayVisible: true,
                morningAdjustmentsVisible: false,
                otherModalVisible: false,
                deferredThisVisit: false
            )
        )
    }

    func testAutoIntroRequiresTodayVisible() {
        XCTAssertFalse(
            RecoveryChallengePresenter.shouldOfferAutoIntroOverlay(
                participation: nil,
                introShownForEventID: nil,
                featureAvailable: true,
                onboardingComplete: true,
                todayVisible: false,
                morningAdjustmentsVisible: false,
                otherModalVisible: false,
                deferredThisVisit: false
            )
        )
    }

    func testAutoIntroDefersWhenMorningAdjustmentsVisible() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey) }
        #endif

        XCTAssertFalse(
            RecoveryChallengePresenter.shouldOfferAutoIntroOverlay(
                participation: nil,
                introShownForEventID: nil,
                featureAvailable: true,
                onboardingComplete: true,
                todayVisible: true,
                morningAdjustmentsVisible: true,
                otherModalVisible: false,
                deferredThisVisit: false
            )
        )
    }

    func testAutoIntroHiddenAfterShownForEvent() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey) }
        #endif

        let decision = RecoveryChallengePresenter.autoIntroDecision(
            participation: nil,
            introShownForEventID: RecoveryChallengeConfig.eventID,
            featureAvailable: true,
            onboardingComplete: true,
            todayVisible: true,
            morningAdjustmentsVisible: false,
            otherModalVisible: false,
            deferredThisVisit: false,
            timeZone: utc
        )
        XCTAssertFalse(decision.shouldShow)
        XCTAssertTrue(decision.suppressionReasons.contains("intro_already_shown_for_event"))
    }

    func testAutoIntroAllowedWhenEligible() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey) }
        #endif

        XCTAssertTrue(
            RecoveryChallengePresenter.shouldOfferAutoIntroOverlay(
                participation: nil,
                introShownForEventID: nil,
                featureAvailable: true,
                onboardingComplete: true,
                todayVisible: true,
                morningAdjustmentsVisible: false,
                otherModalVisible: false,
                deferredThisVisit: false
            )
        )
    }

    func testManualInviteEntryIgnoresIntroShownAndMorningAdjustmentsFlags() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey) }
        #endif

        // Auto intro is suppressed…
        XCTAssertFalse(
            RecoveryChallengePresenter.shouldOfferAutoIntroOverlay(
                participation: nil,
                introShownForEventID: RecoveryChallengeConfig.eventID,
                featureAvailable: true,
                onboardingComplete: true,
                todayVisible: true,
                morningAdjustmentsVisible: true,
                otherModalVisible: false,
                deferredThisVisit: true
            )
        )

        // …but manual compact entry stays available while enrollment is open.
        XCTAssertEqual(
            RecoveryChallengePresenter.headerEntry(
                participation: nil,
                featureAvailable: true,
                timeZone: utc
            ),
            .invite
        )
    }

    func testManualEntryHiddenWhenFeatureUnavailable() {
        XCTAssertEqual(
            RecoveryChallengePresenter.headerEntry(
                participation: nil,
                featureAvailable: false,
                timeZone: utc
            ),
            .hidden
        )
        XCTAssertFalse(
            RecoveryChallengePresenter.availability(
                participation: nil,
                featureAvailable: false,
                timeZone: utc
            ).isChallengeAccessible
        )
    }

    func testHeaderEntryInviteAndParticipating() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey) }
        #endif

        XCTAssertEqual(
            RecoveryChallengePresenter.headerEntry(
                participation: nil,
                featureAvailable: true,
                timeZone: utc
            ),
            .invite
        )

        let now = Date()
        let participation = RecoveryChallengeParticipation(
            eventID: RecoveryChallengeConfig.eventID,
            enrolledAt: now,
            timeZoneIdentifier: utc.identifier,
            startDayKey: RecoveryChallengeEngine.dayKey(for: now, timeZone: utc),
            completedDayIndices: [1]
        )
        let entry = RecoveryChallengePresenter.headerEntry(
            now: now,
            participation: participation,
            featureAvailable: true,
            timeZone: utc
        )
        guard case .participating(let active) = entry else {
            return XCTFail("expected participating, got \(entry)")
        }
        XCTAssertEqual(active.dayIndex, 1)
        XCTAssertTrue(active.todayCompleted)
        XCTAssertEqual(active.completedCount, 1)
        XCTAssertFalse(active.taskTitleKey.isEmpty)
        XCTAssertEqual(active.nodeStates.count, RecoveryChallengeConfig.dayCount)
        XCTAssertEqual(active.nodeStates.first, .completed)
    }

    func testHeaderEntryExposesTodayTaskAndProgressNodes() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey) }
        #endif

        let now = Date()
        let participation = RecoveryChallengeParticipation(
            eventID: RecoveryChallengeConfig.eventID,
            enrolledAt: now,
            timeZoneIdentifier: utc.identifier,
            startDayKey: RecoveryChallengeEngine.dayKey(for: now, timeZone: utc),
            completedDayIndices: [],
            taskDefinitionVersion: 2
        )
        let entry = RecoveryChallengePresenter.headerEntry(
            now: now,
            participation: participation,
            featureAvailable: true,
            timeZone: utc
        )
        guard case .participating(let active) = entry else {
            return XCTFail("expected participating, got \(entry)")
        }
        XCTAssertEqual(active.dayIndex, 1)
        XCTAssertFalse(active.todayCompleted)
        XCTAssertEqual(active.taskTitleKey, "challenge.recovery7.v2.task.1.title")
        XCTAssertEqual(active.nodeStates.first, .current)
        XCTAssertTrue(active.nodeStates.dropFirst().allSatisfy { $0 == .future })
    }

    func testHeaderEntryHidesPerfectFinishAfterCalendarEnds() {
        let enrolled = Date(timeIntervalSince1970: 1_777_600_000) // fixed instant
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let start = calendar.startOfDay(for: enrolled)
        let day8 = calendar.date(byAdding: .day, value: 7, to: start)!
        let participation = RecoveryChallengeParticipation(
            eventID: RecoveryChallengeConfig.eventID,
            enrolledAt: enrolled,
            timeZoneIdentifier: utc.identifier,
            startDayKey: RecoveryChallengeEngine.dayKey(for: enrolled, timeZone: utc),
            completedDayIndices: [1, 2, 3, 4, 5, 6, 7],
            todaySummaryCardDismissed: false
        )
        let entry = RecoveryChallengePresenter.headerEntry(
            now: day8,
            participation: participation,
            featureAvailable: true,
            timeZone: utc
        )
        XCTAssertEqual(entry, .hidden)
    }

    func testHeaderEntryKeepsPartialSummaryUntilDismissed() {
        let enrolled = Date(timeIntervalSince1970: 1_777_600_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let start = calendar.startOfDay(for: enrolled)
        let day8 = calendar.date(byAdding: .day, value: 7, to: start)!
        let participation = RecoveryChallengeParticipation(
            eventID: RecoveryChallengeConfig.eventID,
            enrolledAt: enrolled,
            timeZoneIdentifier: utc.identifier,
            startDayKey: RecoveryChallengeEngine.dayKey(for: enrolled, timeZone: utc),
            completedDayIndices: [1, 3, 5],
            todaySummaryCardDismissed: false
        )
        let entry = RecoveryChallengePresenter.headerEntry(
            now: day8,
            participation: participation,
            featureAvailable: true,
            timeZone: utc
        )
        guard case .summary(let summary) = entry else {
            return XCTFail("expected summary, got \(entry)")
        }
        XCTAssertEqual(summary.completedCount, 3)
        XCTAssertFalse(summary.isPerfect)
    }

    func testAutoIntroDecisionReportsSuppressionReasons() {
        let decision = RecoveryChallengePresenter.autoIntroDecision(
            participation: nil,
            introShownForEventID: RecoveryChallengeConfig.eventID,
            featureAvailable: true,
            onboardingComplete: true,
            todayVisible: true,
            morningAdjustmentsVisible: false,
            otherModalVisible: false,
            deferredThisVisit: false,
            timeZone: utc
        )
        XCTAssertFalse(decision.shouldShow)
        XCTAssertTrue(decision.suppressionReasons.contains("intro_already_shown_for_event"))
    }
}
