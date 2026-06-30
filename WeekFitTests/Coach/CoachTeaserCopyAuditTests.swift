import XCTest
import WeekFitPlanner
@testable import WeekFit

final class CoachTeaserCopyAuditTests: XCTestCase {

    func testBaselineTeasersAvoidRingMetricDuplication() {
        var failures: [String] = []

        for scenario in CoachScenarioKey.allCases {
            let report = auditBaseline(scenario: scenario)
            if !report.isClean {
                failures.append(format(report))
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testMorningBriefTeasersAvoidRingMetricDuplication() {
        var failures: [String] = []

        for variant in morningBriefVariants() {
            let report = auditMorningBrief(variant)
            if !report.isClean {
                failures.append(format(report))
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testDayClosingTeaserOverlayAvoidsRingMetricDuplication() {
        var failures: [String] = []

        for variant in dayClosingVariants() {
            let report = auditDayClosing(variant)
            if !report.isClean {
                failures.append(format(report))
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    // MARK: - Audit helpers

    private func auditBaseline(scenario: CoachScenarioKey) -> CoachTeaserCopyAudit.Report {
        let copyInput = CoachCopyQualityTests.baselineInput(for: scenario)
        let pack = CoachCopyRegistry.resolve(copyInput)!
        let engineResult = CoachTestEngineResultBuilder.make(from: copyInput, pack: pack)
        let teaser = CoachTeaserCopy.resolve(from: engineResult, localizedAssessment: "Assessment")
        return CoachTeaserCopyAudit.Report(
            scenario: scenario,
            variant: "baseline",
            findings: CoachTeaserCopyAudit.audit(teaser)
        )
    }

    private struct MorningBriefVariant {
        let label: String
        let scenario: CoachScenarioKey
        let facts: CoachMorningBriefFacts
    }

    private func morningBriefVariants() -> [MorningBriefVariant] {
        let goodDay = CoachMorningBriefFactsBuilder.synthetic(
            dayReadiness: CoachDayReadiness(
                recoveryPercent: 89,
                sleepHours: 7.8,
                recoveryBand: .good,
                hadHeavyYesterday: false,
                sleepIsLow: false
            )
        )
        let lowRecovery = CoachMorningBriefFactsBuilder.synthetic(
            dayReadiness: CoachDayReadiness(
                recoveryPercent: 38,
                sleepHours: 4.5,
                recoveryBand: .low,
                hadHeavyYesterday: true,
                sleepIsLow: true
            )
        )
        let withRide = CoachMorningBriefFacts(
            recoveryDataAvailable: true,
            sleepHours: 7.5,
            recoveryPercent: 82,
            recoveryBand: .good,
            sleepIsLow: false,
            hadHeavyYesterday: false,
            nextActivity: CoachPlannedActivitySummary(
                title: "Morning Ride",
                startHour: 10,
                startMinute: 30,
                durationMinutes: 90,
                activityType: .cycling
            ),
            todayActivityCount: 1,
            seriousActivityCount: 1,
            tomorrowWorkout: nil,
            minutesUntilNextActivity: 120
        )

        return [
            MorningBriefVariant(label: "morningReadiness.good", scenario: .morningReadiness, facts: goodDay),
            MorningBriefVariant(label: "morningReadiness.lowRecovery", scenario: .morningReadiness, facts: lowRecovery),
            MorningBriefVariant(label: "morningReadiness.withRide", scenario: .morningReadiness, facts: withRide),
            MorningBriefVariant(label: "protectTomorrowFresh.good", scenario: .protectTomorrowFresh, facts: goodDay),
            MorningBriefVariant(label: "recoveryAfterHeavyYesterday.low", scenario: .recoveryAfterHeavyYesterday, facts: lowRecovery)
        ]
    }

    private func auditMorningBrief(_ variant: MorningBriefVariant) -> CoachTeaserCopyAudit.Report {
        let copyInput = CoachCopyQualityTests.baselineInput(for: variant.scenario)
        let pack = CoachCopyRegistry.resolve(copyInput)!
        var engineResult = CoachTestEngineResultBuilder.make(from: copyInput, pack: pack)
        engineResult = CoachEngine.Result(
            context: engineResult.context,
            resolution: engineResult.resolution,
            todayInsight: engineResult.todayInsight,
            copyPack: engineResult.copyPack,
            morningBriefFacts: variant.facts
        )
        let teaser = CoachTeaserCopy.resolve(from: engineResult, localizedAssessment: "Assessment")
        return CoachTeaserCopyAudit.Report(
            scenario: variant.scenario,
            variant: variant.label,
            findings: CoachTeaserCopyAudit.audit(teaser)
        )
    }

    private struct DayClosingVariant {
        let label: String
        let scenario: CoachScenarioKey
        let hour: Int
        let profile: CoachStableDayProfile?
    }

    private func dayClosingVariants() -> [DayClosingVariant] {
        [
            DayClosingVariant(label: "stableDay.empty.windDown", scenario: .stableDay, hour: 22, profile: .emptyDay),
            DayClosingVariant(label: "stableDay.lowRecovery.sleepNow", scenario: .stableDay, hour: 23, profile: .lowRecoveryRest),
            DayClosingVariant(label: "recoveryAfterHeavyYesterday.windDown", scenario: .recoveryAfterHeavyYesterday, hour: 22, profile: nil)
        ]
    }

    private func auditDayClosing(_ variant: DayClosingVariant) -> CoachTeaserCopyAudit.Report {
        let now = dayClosingDate(hour: variant.hour)
        let result = CoachEngine.evaluate(
            input: dayClosingInput(
                now: now,
                scenario: variant.scenario,
                hour: variant.hour
            )
        )

        guard let overlay = CoachDayClosingCopyPolicy.teaserOverlay(for: result) else {
            return CoachTeaserCopyAudit.Report(
                scenario: variant.scenario,
                variant: variant.label,
                findings: [CoachTeaserCopyAudit.Finding(field: .todayTitle, language: "en", reason: "missing overlay")]
            )
        }

        let teaser = CoachTeaserCopy.Content(
            todayTitle: overlay.todayTitle,
            todayMessage: overlay.todayMessage,
            coachHeadline: overlay.coachHeadline
        )
        return CoachTeaserCopyAudit.Report(
            scenario: variant.scenario,
            variant: variant.label,
            findings: CoachTeaserCopyAudit.audit(teaser)
        )
    }

    private func dayClosingDate(hour: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = 30
        return Calendar.current.date(from: components)!
    }

    private func dayClosingInput(
        now: Date,
        scenario: CoachScenarioKey,
        hour: Int
    ) -> CoachInputSnapshot {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = hour

        let recovery = scenario == .recoveryAfterHeavyYesterday
            ? CoachRecoveryContext(recoveryPercent: 55, sleepHours: 6.5)
            : CoachRecoveryContext(recoveryPercent: 72, sleepHours: hour >= 23 ? 5.0 : 7.5)

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: [],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 120,
                exerciseMinutes: 5,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 0.2
            ),
            recoveryContext: recovery,
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 0,
                caloriesGoal: 2_800,
                proteinCurrent: 0,
                proteinGoal: 140,
                waterCurrent: 0,
                waterGoal: 2.5
            ),
            source: "CoachTeaserCopyAuditTests.dayClosing"
        )
    }

    private func format(_ report: CoachTeaserCopyAudit.Report) -> String {
        let details = report.findings
            .map { "\($0.field.rawValue).\($0.language): \($0.reason)" }
            .joined(separator: ", ")
        return "\(report.label): \(details)"
    }
}
