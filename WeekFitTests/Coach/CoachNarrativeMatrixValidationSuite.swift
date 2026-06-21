import XCTest
@testable import WeekFit

@MainActor
final class CoachNarrativeMatrixValidationSuite: XCTestCase {

    private let allScenarios = CoachNarrativeMatrixFactory.allScenarios()

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testNarrativeMatrixMorning() {
        auditAndWrite(batch: .morning, part: "morning")
    }

    func testNarrativeMatrixWorkoutPrep() {
        auditAndWrite(batch: .workoutPrep, part: "workoutPrep")
    }

    func testNarrativeMatrixActive() {
        auditAndWrite(batch: .active, part: "active")
    }

    func testNarrativeMatrixPostWorkout() {
        auditAndWrite(batch: .postWorkout, part: "postWorkout")
    }

    func testNarrativeMatrixNutritionHydration() {
        auditAndWrite(batch: .nutritionHydration, part: "nutritionHydration")
    }

    func testNarrativeMatrixSyncAndPlanner() {
        auditAndWrite(batch: .syncAndPlanner, part: "syncAndPlanner")
    }

    func testNarrativeMatrixReportMerge() throws {
        var merged: [CoachNarrativeMatrixAuditRow] = []
        for batch in CoachNarrativeMatrixRunBatch.allCases {
            let scenarios = CoachNarrativeMatrixFactory.scenarios(for: batch)
            for scenario in scenarios {
                let state = scenario.makeState()
                guard let result = CoachNarrativeContractAuditor.audit(state: state, scenario: scenario) else {
                    XCTFail("Missing audit result for \(scenario.name)")
                    continue
                }
                merged.append(CoachNarrativeMatrixAuditRow(scenario: scenario, result: result))
            }
            let batchRows = merged.filter { $0.scenario.runBatch == batch }
            if let data = CoachNarrativeMatrixReportBuilder.encodeRows(batchRows) {
                let url = partialURL(part: batch.rawValue)
                try? data.write(to: url, options: .atomic)
            }
        }
        merged.sort { $0.scenario.id < $1.scenario.id }
        XCTAssertEqual(merged.count, allScenarios.count, "Expected \(allScenarios.count) scenarios, got \(merged.count)")
        let report = CoachNarrativeMatrixReportBuilder.buildReport(rows: merged)
        CoachNarrativeMatrixReportBuilder.writeReport(report)
    }

    func testNarrativeMatrixQualityGateFail() {
        let blockers = allScenarios.compactMap { scenario -> String? in
            let state = scenario.makeState()
            guard let result = CoachNarrativeContractAuditor.audit(state: state, scenario: scenario) else {
                return "Missing audit for \(scenario.name)"
            }
            guard result.severity == .fail else { return nil }
            let flags = result.findings
                .filter { $0.severity == .fail }
                .map { "\($0.flag.rawValue) [\($0.issueClass.rawValue)]: \($0.detail)" }
                .joined(separator: "; ")
            return "\(scenario.id). \(scenario.name): \(flags)"
        }
        XCTAssertTrue(
            blockers.isEmpty,
            blockers.joined(separator: "\n")
        )
    }

    func testNarrativeMatrixQualityGateWarnBudget() {
        let warned = allScenarios.compactMap { scenario -> (Int, CoachNarrativeContractAuditResult)? in
            let state = scenario.makeState()
            guard let result = CoachNarrativeContractAuditor.audit(state: state, scenario: scenario) else { return nil }
            return result.severity == .warn ? (scenario.id, result) : nil
        }
        // Informational guardrail: warn count is tracked in the merged report.
        XCTAssertLessThan(warned.count, allScenarios.count, "All scenarios warned — audit heuristics may be miscalibrated")
    }

    func testNarrativeMatrixScenarioCountMeetsPhase3Minimum() {
        XCTAssertGreaterThanOrEqual(allScenarios.count, 80, "Phase 3 requires at least 80 scenarios")
    }

    // MARK: - Helpers

    private func auditAndWrite(batch: CoachNarrativeMatrixRunBatch, part: String) {
        let scenarios = CoachNarrativeMatrixFactory.scenarios(for: batch)
        XCTAssertFalse(scenarios.isEmpty, "No scenarios for batch \(part)")
        var rows: [CoachNarrativeMatrixAuditRow] = []
        for scenario in scenarios {
            XCTContext.runActivity(named: scenario.name) { _ in
                let state = scenario.makeState()
                guard let result = CoachNarrativeContractAuditor.audit(state: state, scenario: scenario) else {
                    XCTFail("Missing audit result for \(scenario.name)")
                    return
                }
                rows.append(CoachNarrativeMatrixAuditRow(scenario: scenario, result: result))
            }
        }
        guard let data = CoachNarrativeMatrixReportBuilder.encodeRows(rows) else {
            XCTFail("Could not encode partial report for \(part)")
            return
        }
        let url = partialURL(part: part)
        try? data.write(to: url, options: .atomic)
    }

    private func partialURL(part: String) -> URL {
        URL(fileURLWithPath: "/tmp/WeekFitCoachNarrativePhase3Audit.part.\(part).json")
    }
}
