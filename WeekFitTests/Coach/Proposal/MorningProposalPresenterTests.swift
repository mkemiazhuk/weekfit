import Foundation
import XCTest
@testable import WeekFit

final class MorningProposalPresenterTests: XCTestCase {

    func testShouldPresentReviewRequiresConfidentReadyProposal() {
        XCTAssertFalse(MorningProposalPresenter.shouldPresentReview(nil))

        let emptyReady = proposal(status: .proposalReady, changes: [])
        XCTAssertFalse(MorningProposalPresenter.hasConfidentProposal(emptyReady))
        XCTAssertFalse(MorningProposalPresenter.shouldPresentReview(emptyReady))

        let noChanges = proposal(status: .noChangesNeeded, changes: [])
        XCTAssertFalse(MorningProposalPresenter.shouldPresentReview(noChanges))

        let softOnly = proposal(
            status: .proposalReady,
            changes: [
                CoachProposedChange(
                    id: "soft",
                    kind: .guidanceOnly,
                    reasonCode: .planAlreadyAppropriate,
                    payload: .guidanceOnly(
                        GuidanceOnlyPayload(
                            guidanceCode: .listenToBodyOnLowReadiness,
                            relatedActivityId: nil
                        )
                    ),
                    defaultSelected: false,
                    isSelected: false,
                    sortTime: Date(),
                    evidenceScenarioKey: nil
                )
            ]
        )
        XCTAssertFalse(MorningProposalPresenter.shouldPresentReview(softOnly))

        let mutating = proposal(
            status: .proposalReady,
            changes: [
                CoachProposedChange(
                    id: "cut",
                    kind: .modifyDuration,
                    reasonCode: .lowRecoveryLoadProtection,
                    payload: .modifyDuration(
                        ModifyDurationPayload(
                            activityId: "run-1",
                            originalDurationMinutes: 60,
                            proposedDurationMinutes: 40,
                            activityTitle: "Run"
                        )
                    ),
                    defaultSelected: true,
                    isSelected: true,
                    sortTime: Date(),
                    evidenceScenarioKey: "lowRecoveryPrep"
                )
            ]
        )
        XCTAssertTrue(MorningProposalPresenter.shouldPresentReview(mutating))
    }

    private func proposal(
        status: CoachProposalStatus,
        changes: [CoachProposedChange]
    ) -> MorningPlanProposal {
        MorningPlanProposal(
            id: "p-1",
            dayKey: "2026-09-10",
            generatedAt: Date(),
            status: status,
            fingerprint: ProposalInputFingerprint(
                dayKey: "2026-09-10",
                planSignature: "sig",
                tomorrowPlanSignature: "",
                recoveryBand: .low,
                sleepPresence: .present,
                scenarioKey: "lowRecoveryPrep",
                yesterdayHeavy: true,
                schemaVersion: ProposalInputFingerprint.currentSchemaVersion
            ),
            changes: changes,
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            schemaVersion: MorningPlanProposal.currentSchemaVersion
        )
    }
}
