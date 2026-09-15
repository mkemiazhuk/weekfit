import Foundation
import XCTest
@testable import WeekFit

final class RecoveryChallengeStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "weekfit.tests.recoveryChallenge.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        RecoveryChallengeStore.setDefaultsForTests(defaults)
        RecoveryChallengeStore.resetAllForTests()
        #if DEBUG
        UserDefaults.standard.set(true, forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey)
        #endif
    }

    override func tearDown() {
        RecoveryChallengeStore.resetAllForTests()
        RecoveryChallengeStore.useStandardDefaultsForTests()
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: RecoveryChallengeConfig.debugPreviewDefaultsKey)
        #endif
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPersistenceSurvivesReload() throws {
        let enrolled = try XCTUnwrap(
            {
                switch RecoveryChallengeStore.enroll(timeZone: TimeZone(secondsFromGMT: 0)!) {
                case .success(let p): return p
                case .failure(let e):
                    XCTFail("enroll failed: \(e)")
                    return nil
                }
            }()
        )
        XCTAssertEqual(enrolled.completedCount, 0)

        let reloaded = try XCTUnwrap(RecoveryChallengeStore.load())
        XCTAssertEqual(reloaded.eventID, enrolled.eventID)
        XCTAssertEqual(reloaded.startDayKey, enrolled.startDayKey)
        XCTAssertEqual(reloaded.timeZoneIdentifier, enrolled.timeZoneIdentifier)
    }

    func testDuplicateEnrollmentRejected() throws {
        _ = try XCTUnwrap(success(RecoveryChallengeStore.enroll(timeZone: TimeZone(secondsFromGMT: 0)!)))
        let second = RecoveryChallengeStore.enroll(timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertEqual(second, .failure(.alreadyEnrolled))
    }

    func testPlanDoesNotCompleteAndExplicitCompletePersists() throws {
        let enrolled = try XCTUnwrap(success(RecoveryChallengeStore.enroll(timeZone: TimeZone(secondsFromGMT: 0)!)))
        XCTAssertEqual(enrolled.resolvedTaskVersion, .v2)

        let planned = RecoveryChallengeStore.savePlan(minuteOfDay: 21 * 60, targetDayKey: enrolled.startDayKey)
        guard case .success(let afterPlan) = planned else {
            return XCTFail("plan failed: \(planned)")
        }
        XCTAssertEqual(afterPlan.plannedMinuteOfDay, 21 * 60)
        XCTAssertTrue(afterPlan.completedDayIndices.isEmpty)

        let first = RecoveryChallengeStore.completeCurrentDay()
        guard case .success(let updated) = first else {
            return XCTFail("complete failed: \(first)")
        }
        XCTAssertEqual(updated.completedDayIndices, [1])
        XCTAssertEqual(updated.plannedMinuteOfDay, 21 * 60)

        let dup = RecoveryChallengeStore.completeCurrentDay()
        XCTAssertEqual(dup, .failure(.alreadyCompleted))
    }

    func testDebugFreshV2EnrollmentReplacesParticipation() throws {
        #if DEBUG
        _ = try XCTUnwrap(success(RecoveryChallengeStore.enroll(taskDefinitionVersion: .v1)))
        let reset = RecoveryChallengeStore.debugResetToFreshV2Enrollment(
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        guard case .success(let fresh) = reset else {
            return XCTFail("debug reset failed: \(reset)")
        }
        XCTAssertEqual(fresh.resolvedTaskVersion, .v2)
        XCTAssertTrue(fresh.completedDayIndices.isEmpty)
        #endif
    }

    func testIntroShownPersistenceAndClear() {
        XCTAssertNil(RecoveryChallengeStore.introShownEventID())
        RecoveryChallengeStore.markIntroShown()
        XCTAssertEqual(RecoveryChallengeStore.introShownEventID(), RecoveryChallengeConfig.eventID)
        RecoveryChallengeStore.clearIntroShown()
        XCTAssertNil(RecoveryChallengeStore.introShownEventID())
    }

    private func success<T, E: Error>(_ result: Result<T, E>) -> T? {
        switch result {
        case .success(let value): return value
        case .failure: return nil
        }
    }
}
