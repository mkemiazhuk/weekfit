import Foundation

/// Which measured recovery factors to surface first.
///
/// Importance uses each factor's weighted contribution points and the points it
/// left on the table. A high 0–10 grade on a small-weight factor does not outrank
/// a larger contribution, and a low grade on a small-weight factor is not the
/// limiter when another factor gave up more points.
struct RecoveryFactorHighlights: Equatable {
    let supporting: RecoveryBreakdownSignal?
    let limiting: RecoveryBreakdownSignal?

    static let none = RecoveryFactorHighlights(supporting: nil, limiting: nil)

    /// Fulfillment at or above this is supportive. Below it, the factor can limit.
    static let supportFulfillment = 0.70
    /// Ignore tiny gaps so a near-full small factor is not called a limiter.
    static let minimumLimitShortfall = 3

    static func select(
        breakdown: RecoveryScoreBreakdown,
        hasSleep: Bool
    ) -> RecoveryFactorHighlights {
        let measured = candidates(breakdown: breakdown, hasSleep: hasSleep)
        guard !measured.isEmpty else { return .none }

        let supporting = measured
            .filter { $0.fulfillment >= supportFulfillment }
            .max(by: isLessImportantSupport)

        let limiting = measured
            .filter { candidate in
                candidate.signal != supporting?.signal
                    && candidate.fulfillment < supportFulfillment
                    && candidate.shortfall >= minimumLimitShortfall
            }
            .max(by: isLessImportantLimit)

        return RecoveryFactorHighlights(
            supporting: supporting?.signal,
            limiting: limiting?.signal
        )
    }

    private struct Candidate {
        let signal: RecoveryBreakdownSignal
        let points: Int
        let maxPoints: Int

        var fulfillment: Double {
            guard maxPoints > 0 else { return 0 }
            return min(1, max(0, Double(points) / Double(maxPoints)))
        }

        var shortfall: Int {
            max(0, maxPoints - points)
        }
    }

    private static func candidates(
        breakdown: RecoveryScoreBreakdown,
        hasSleep: Bool
    ) -> [Candidate] {
        var items: [Candidate] = []
        if hasSleep {
            items.append(
                Candidate(
                    signal: .sleepDuration,
                    points: breakdown.sleepDuration,
                    maxPoints: RecoveryScoreBreakdown.maxSleepDurationContribution
                )
            )
        }
        if breakdown.sleepConsistencyGrade != nil {
            items.append(
                Candidate(
                    signal: .sleepConsistency,
                    points: breakdown.sleepConsistency,
                    maxPoints: RecoveryScoreBreakdown.maxSleepConsistencyContribution
                )
            )
        }
        if breakdown.sleepContinuityGrade != nil {
            items.append(
                Candidate(
                    signal: .sleepContinuity,
                    points: breakdown.sleepContinuity,
                    maxPoints: RecoveryScoreBreakdown.maxSleepContinuityContribution
                )
            )
        }
        if breakdown.sleepArchitectureGrade != nil {
            items.append(
                Candidate(
                    signal: .sleepArchitecture,
                    points: breakdown.sleepArchitecture,
                    maxPoints: RecoveryScoreBreakdown.maxSleepArchitectureContribution
                )
            )
        }
        if breakdown.hrvGrade != nil {
            items.append(
                Candidate(
                    signal: .hrv,
                    points: breakdown.hrv,
                    maxPoints: RecoveryScoreBreakdown.maxHRVContribution
                )
            )
        }
        if breakdown.restingHeartRateGrade != nil {
            items.append(
                Candidate(
                    signal: .restingHeartRate,
                    points: breakdown.restingHeartRate,
                    maxPoints: RecoveryScoreBreakdown.maxRestingHeartRateContribution
                )
            )
        }
        return items
    }

    /// Prefer more retained points, then the heavier factor.
    private static func isLessImportantSupport(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        if lhs.points != rhs.points { return lhs.points < rhs.points }
        if lhs.maxPoints != rhs.maxPoints { return lhs.maxPoints < rhs.maxPoints }
        return lhs.signal.sortIndex > rhs.signal.sortIndex
    }

    /// Prefer the larger lost contribution, then the heavier factor.
    private static func isLessImportantLimit(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        if lhs.shortfall != rhs.shortfall { return lhs.shortfall < rhs.shortfall }
        if lhs.maxPoints != rhs.maxPoints { return lhs.maxPoints < rhs.maxPoints }
        return lhs.signal.sortIndex > rhs.signal.sortIndex
    }
}
