import Foundation

/// Compares a self-reported feeling with timestamp-relevant sleep / recovery / activity signals.
///
/// Evidence rules (v1) — see `CoachFeelingEvidenceRules`:
/// - Use observations available at or before the check-in timestamp’s calendar day.
/// - Sleep/recovery older than freshness windows are marked stale and cannot support “current” claims.
/// - Baselines need minimum sample counts; missing baselines → insufficient for that metric.
/// - Activity counts are descriptive only; never treated as training-load intensity.
/// - Never claims causation or diagnoses overtraining.
enum CoachFeelingComparator {

    struct Input: Equatable, Sendable {
        let feeling: CoachFeelingKind
        let clarification: CoachFeelingClarification?
        let checkInAt: Date
        let observations: [CoachDailyObservation]
        /// Completed session day keys + counts within the activity window (pre-aggregated).
        let recentActivityDayKeys: [String]
        let recentActivityCount: Int
    }

    static func compare(_ input: Input, calendar: Calendar = .current) -> CoachFeelingComparisonResult {
        var calendar = calendar
        calendar.timeZone = TimeZone.current

        let evidence = gatherEvidence(input: input, calendar: calendar)
        let outcome = resolveOutcome(feeling: input.feeling, evidence: evidence)
        let copy = CoachFeelingCopy.comparison(
            feeling: input.feeling,
            clarification: input.clarification,
            outcome: outcome,
            evidence: evidence
        )

        return CoachFeelingComparisonResult(
            outcome: outcome,
            headline: copy.headline,
            explanation: copy.explanation,
            supportingFacts: Array(copy.facts.prefix(2)),
            detailFacts: copy.details,
            evidence: evidence,
            analysisVersion: CoachFeelingEvidenceRules.analysisVersion
        )
    }

    // MARK: - Evidence gathering

    static func gatherEvidence(
        input: Input,
        calendar: Calendar
    ) -> CoachFeelingEvidenceSnapshot {
        let checkInDay = calendar.startOfDay(for: input.checkInAt)
        let checkInDayKey = CoachDailyObservation.dayKey(for: checkInDay, calendar: calendar)

        let usable = input.observations.filter { observation in
            observation.dayKey <= checkInDayKey
        }

        let sleepCandidate = usable
            .filter(\.hasSleepSignal)
            .sorted { $0.dayKey > $1.dayKey }
            .first

        let recoveryCandidate = usable
            .filter(\.hasRecoverySignal)
            .sorted { $0.dayKey > $1.dayKey }
            .first

        let sleepStale = isStale(
            dayKey: sleepCandidate?.dayKey,
            checkInAt: input.checkInAt,
            maxAgeHours: CoachFeelingEvidenceRules.sleepFreshnessHours,
            calendar: calendar
        )
        let recoveryStale = isStale(
            dayKey: recoveryCandidate?.dayKey,
            checkInAt: input.checkInAt,
            maxAgeHours: CoachFeelingEvidenceRules.recoveryFreshnessHours,
            calendar: calendar
        )

        let baselinePool = usable
            .filter { $0.dayKey < checkInDayKey }
            .sorted { $0.dayKey < $1.dayKey }
        let sleepBaselineValues = baselinePool
            .filter(\.hasSleepSignal)
            .suffix(CoachFeelingEvidenceRules.baselineLookbackDays)
            .map(\.sleepMinutes)
        let recoveryBaselineValues = baselinePool
            .filter(\.hasRecoverySignal)
            .suffix(CoachFeelingEvidenceRules.baselineLookbackDays)
            .map(\.recoveryPercent)

        let sleepBaseline: Int? = {
            guard sleepBaselineValues.count >= CoachFeelingEvidenceRules.minimumSleepBaselineSamples else {
                return nil
            }
            return median(sleepBaselineValues)
        }()
        let recoveryBaseline: Int? = {
            guard recoveryBaselineValues.count >= CoachFeelingEvidenceRules.minimumRecoveryBaselineSamples else {
                return nil
            }
            return median(recoveryBaselineValues)
        }()

        return CoachFeelingEvidenceSnapshot(
            sleepMinutes: sleepStale ? nil : sleepCandidate?.sleepMinutes,
            sleepBaselineMinutes: sleepBaseline,
            sleepDayKey: sleepCandidate?.dayKey,
            sleepIsStale: sleepStale,
            sleepSampleCount: sleepBaselineValues.count,
            recoveryPercent: recoveryStale ? nil : recoveryCandidate?.recoveryPercent,
            recoveryBaselinePercent: recoveryBaseline,
            recoveryDayKey: recoveryCandidate?.dayKey,
            recoveryIsStale: recoveryStale,
            recoverySampleCount: recoveryBaselineValues.count,
            recentActivityCount: input.recentActivityCount,
            recentActivityDayKeys: input.recentActivityDayKeys,
            activityWindowHours: CoachFeelingEvidenceRules.recentActivityHours
        )
    }

    // MARK: - Outcome

    static func resolveOutcome(
        feeling: CoachFeelingKind,
        evidence: CoachFeelingEvidenceSnapshot
    ) -> CoachFeelingComparisonKind {
        let hasSleepCompare = evidence.sleepMinutes != nil && evidence.sleepBaselineMinutes != nil
        let hasRecoveryCompare = evidence.recoveryPercent != nil && evidence.recoveryBaselinePercent != nil

        if !hasSleepCompare && !hasRecoveryCompare {
            return .insufficient
        }

        let sleepDelta: Int? = {
            guard let sleep = evidence.sleepMinutes, let baseline = evidence.sleepBaselineMinutes else {
                return nil
            }
            return sleep - baseline
        }()
        let recoveryDelta: Int? = {
            guard let recovery = evidence.recoveryPercent, let baseline = evidence.recoveryBaselinePercent else {
                return nil
            }
            return recovery - baseline
        }()

        switch feeling {
        case .tired, .low:
            let sleepSupports = (sleepDelta ?? 0) <= -CoachFeelingEvidenceRules.tiredSleepShortfallMinutes
            let recoverySupports = (recoveryDelta ?? 0) <= -CoachFeelingEvidenceRules.tiredRecoveryShortfallPoints
            if sleepSupports || recoverySupports { return .supporting }
            if hasSleepCompare || hasRecoveryCompare { return .mixed }
            return .insufficient

        case .energized:
            let sleepOk = sleepDelta.map { $0 >= -CoachFeelingEvidenceRules.sleepNearBaselineMinutes } ?? false
            let recoveryOk = recoveryDelta.map { $0 >= -CoachFeelingEvidenceRules.recoveryNearBaselinePoints } ?? false
            let sleepSupports = sleepDelta.map { $0 >= 0 } ?? false
            let recoverySupports = recoveryDelta.map { $0 >= 0 } ?? false
            if (sleepSupports || recoverySupports) && (sleepOk || !hasSleepCompare) && (recoveryOk || !hasRecoveryCompare) {
                return .supporting
            }
            if sleepDelta.map({ $0 <= -CoachFeelingEvidenceRules.tiredSleepShortfallMinutes }) == true
                || recoveryDelta.map({ $0 <= -CoachFeelingEvidenceRules.tiredRecoveryShortfallPoints }) == true {
                return .mixed
            }
            if hasSleepCompare || hasRecoveryCompare { return .mixed }
            return .insufficient

        case .okay:
            let sleepNear = sleepDelta.map { abs($0) <= CoachFeelingEvidenceRules.sleepNearBaselineMinutes } ?? true
            let recoveryNear = recoveryDelta.map { abs($0) <= CoachFeelingEvidenceRules.recoveryNearBaselinePoints } ?? true
            if sleepNear && recoveryNear, hasSleepCompare || hasRecoveryCompare {
                return .supporting
            }
            return .mixed
        }
    }

    // MARK: - Helpers

    static func isStale(
        dayKey: String?,
        checkInAt: Date,
        maxAgeHours: Double,
        calendar: Calendar
    ) -> Bool {
        guard let dayKey,
              let day = CoachDailyObservation.date(fromDayKey: dayKey, calendar: calendar) else {
            return false
        }
        // Treat observation as belonging to end-of-day for freshness (conservative).
        let observationInstant = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
        let age = checkInAt.timeIntervalSince(observationInstant)
        if age < 0 { return false }
        return age > maxAgeHours * 3600
    }

    static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return Int((Double(sorted[mid - 1] + sorted[mid]) / 2.0).rounded())
        }
        return sorted[mid]
    }
}
