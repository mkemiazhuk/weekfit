import Foundation

enum MorningProposalAssembler {

    static let scorerVersion = 2

    static func assemble(
        validated: ValidatedPlan,
        context: DailyContext
    ) -> MorningPlanProposal {
        if validated.aborted {
            return MorningPlanProposal(
                id: UUID().uuidString,
                dayKey: context.dayKey,
                generatedAt: context.now,
                status: .noChangesNeeded,
                fingerprint: context.fingerprint,
                changes: [],
                appliedAt: nil,
                dismissedAt: nil,
                lastErrorCode: validated.abortReason,
                schemaVersion: MorningPlanProposal.currentSchemaVersion,
                strategy: validated.strategy,
                contextConfidence: context.contextFreshness,
                scorerVersion: scorerVersion
            )
        }

        let changes: [CoachProposedChange] = validated.candidates.map { scored in
            let selected = CandidateScorer.shouldDefaultSelect(
                scored,
                context: context,
                strategy: validated.strategy
            )
            return CoachProposedChange(
                id: scored.candidate.id,
                kind: scored.candidate.kind,
                reasonCode: scored.candidate.reasonCodes.first ?? .planAlreadyAppropriate,
                payload: scored.candidate.payload,
                defaultSelected: selected,
                isSelected: selected,
                sortTime: scored.candidate.sortTime,
                evidenceScenarioKey: scored.candidate.evidenceScenarioKey,
                candidateSource: scored.candidate.source,
                scoreTotal: scored.score
            )
        }

        let mutating = changes.filter { $0.kind != CoachChangeKind.guidanceOnly }
        let fuelGuidance = changes.filter { change in
            guard change.kind == .guidanceOnly,
                  case .guidanceOnly(let payload) = change.payload else { return false }
            switch payload.guidanceCode {
            case .morningFuelWithoutLibrary, .morningFuelGentleRecovery, .morningFuelSteadyEnergy:
                return true
            default:
                return false
            }
        }
        let weatherGuidance = changes.filter { change in
            guard change.kind == .guidanceOnly,
                  case .guidanceOnly(let payload) = change.payload else { return false }
            switch payload.guidanceCode {
            case .preferIndoorOrEarlier, .easeOutdoorHeat, .shelteredRoutesWind, .warmUpInCold:
                return true
            default:
                return false
            }
        }

        // Guidance-only payloads are normally dropped (no Apply chrome). Exceptions:
        // 1) empty meal library → morning fuel tips
        // 2) adverse weather → outdoor caution tips
        // Soft cold-start body tips stay out of Review even when Walk/meals mutate.
        if mutating.isEmpty {
            var guidanceOnly: [CoachProposedChange] = []
            if context.mealLibrary.isEmpty {
                guidanceOnly.append(contentsOf: fuelGuidance)
            }
            for tip in weatherGuidance where !guidanceOnly.contains(where: { $0.id == tip.id }) {
                guidanceOnly.append(tip)
            }
            if !guidanceOnly.isEmpty {
                return MorningPlanProposal(
                    id: UUID().uuidString,
                    dayKey: context.dayKey,
                    generatedAt: context.now,
                    status: .proposalReady,
                    fingerprint: context.fingerprint,
                    changes: Array(guidanceOnly.prefix(2)),
                    appliedAt: nil,
                    dismissedAt: nil,
                    lastErrorCode: nil,
                    schemaVersion: MorningPlanProposal.currentSchemaVersion,
                    strategy: validated.strategy,
                    contextConfidence: context.contextFreshness,
                    scorerVersion: scorerVersion
                )
            }
            return MorningPlanProposal(
                id: UUID().uuidString,
                dayKey: context.dayKey,
                generatedAt: context.now,
                status: .noChangesNeeded,
                fingerprint: context.fingerprint,
                changes: [],
                appliedAt: nil,
                dismissedAt: nil,
                lastErrorCode: validated.abortReason,
                schemaVersion: MorningPlanProposal.currentSchemaVersion,
                strategy: validated.strategy,
                contextConfidence: context.contextFreshness,
                scorerVersion: scorerVersion
            )
        }

        let reviewChanges: [CoachProposedChange]
        if context.isColdStart {
            reviewChanges = changes.filter { change in
                guard change.kind == .guidanceOnly,
                      case .guidanceOnly(let payload) = change.payload else { return true }
                switch payload.guidanceCode {
                case .listenToBodyOnLowReadiness,
                     .easeIntoFirstEffort,
                     .hydrateThroughMorning,
                     .fuelBeforeSession,
                     .protectTomorrowFreshness:
                    return false
                default:
                    return true
                }
            }
        } else {
            reviewChanges = changes
        }

        return MorningPlanProposal(
            id: UUID().uuidString,
            dayKey: context.dayKey,
            generatedAt: context.now,
            status: .proposalReady,
            fingerprint: context.fingerprint,
            changes: reviewChanges,
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            schemaVersion: MorningPlanProposal.currentSchemaVersion,
            strategy: validated.strategy,
            contextConfidence: context.contextFreshness,
            scorerVersion: scorerVersion
        )
    }
}
