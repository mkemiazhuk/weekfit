import XCTest
@testable import WeekFit

@MainActor
final class CoachNarrativeValidationSuite: XCTestCase {

    private let now = CoachTestClock.reference
    private var morning: Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
    }

    private struct Scenario {
        let id: Int
        let group: String
        let name: String
        let context: String
        let makeState: () -> CoachState
        let expectation: CoachNarrativeScenarioExpectation
    }

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testAuditScenarios1Through16() {
        let results = auditScenarios(in: 1...16)
        XCTAssertEqual(results.count, 16)
        writePartialReport(results, part: 1)
    }

    func testAuditScenarios17Through32() {
        let results = auditScenarios(in: 17...32)
        XCTAssertEqual(results.count, 16)
        writePartialReport(results, part: 2)
    }

    func testMorningRecoveryLowScoresPassVisibleContract() throws {
        for recoveryPercent in [45, 25] {
            let scenario = morningRecoveryScenario(
                id: recoveryPercent == 45 ? 4 : 5,
                recoveryPercent: recoveryPercent,
                tier: recoveryPercent == 45 ? .low : .depleted
            )
            try XCTContext.runActivity(named: scenario.name) { _ in
                let state = scenario.makeState()
                let story = try XCTUnwrap(state.finalStory)
                if story.owner == .recovery || story.owner == .postActivityRecovery {
                    XCTAssertTrue(
                        story.colorFamily == .recovery || story.colorFamily == .warning,
                        "\(scenario.name) owner=\(story.owner) colorFamily=\(story.colorFamily)"
                    )
                }
                if story.owner == .recovery {
                    XCTAssertEqual(story.primaryFocus, .recoveryNeeded, scenario.name)
                }
                story.validateVisibleContract()
            }
        }
    }

    func testPhase2NarrativeValidationMatrixAuditReportPart1() {
        testAuditScenarios1Through16()
    }

    func testPhase2NarrativeValidationMatrixAuditReportPart2() {
        testAuditScenarios17Through32()
    }

    func testPhase2NarrativeValidationMatrixAuditReportMerge() throws {
        let part1Data = try Data(contentsOf: partialResultsURL(part: 1))
        let part2Data = try Data(contentsOf: partialResultsURL(part: 2))
        let part1 = try decodeStoredResults(from: part1Data)
        let part2 = try decodeStoredResults(from: part2Data)
        let merged = (part1 + part2).sorted { $0.id < $1.id }
        XCTAssertEqual(merged.count, 32)
        appendReportToLog(buildReport(results: merged))
    }

    func testPhase2NarrativeValidationQualityGatePart1() {
        let weakStories = auditScenarios(in: 1...16).filter { $0.result.isWeakStory }
        XCTAssertTrue(
            weakStories.isEmpty,
            weakStories.map { "\($0.id). \($0.name): \($0.result.findings.map(\.flag.rawValue).joined(separator: ", "))" }
                .joined(separator: "\n")
        )
    }

    func testPhase2NarrativeValidationQualityGatePart2() {
        let weakStories = auditScenarios(in: 17...32).filter { $0.result.isWeakStory }
        XCTAssertTrue(
            weakStories.isEmpty,
            weakStories.map { "\($0.id). \($0.name): \($0.result.findings.map(\.flag.rawValue).joined(separator: ", "))" }
                .joined(separator: "\n")
        )
    }

    func testPhase2NarrativeValidationMatrixNoRawLocalizationKeys() {
        for scenario in scenarios() {
            XCTContext.runActivity(named: scenario.name) { _ in
                let state = scenario.makeState()
                guard let snapshot = CoachNarrativeAuditor.snapshot(from: state) else {
                    XCTFail("Missing snapshot for \(scenario.name)")
                    return
                }
                let joined = [
                    snapshot.badge,
                    snapshot.title,
                    snapshot.read,
                    snapshot.recommendation,
                    snapshot.careful
                ].joined(separator: " ")
                XCTAssertFalse(joined.contains("coach.final."), scenario.name)
            }
        }
    }

    // MARK: - Matrix

    @discardableResult
    private func auditScenarios(
        in range: ClosedRange<Int>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [(id: Int, group: String, name: String, context: String, result: CoachNarrativeAuditResult)] {
        var collected: [(id: Int, group: String, name: String, context: String, result: CoachNarrativeAuditResult)] = []
        for scenario in scenarios() where range.contains(scenario.id) {
            XCTContext.runActivity(named: scenario.name) { _ in
                let state = scenario.makeState()
                guard let result = CoachNarrativeAuditor.audit(state: state, expectation: scenario.expectation) else {
                    XCTFail("Missing audit result for \(scenario.name)", file: file, line: line)
                    return
                }
                collected.append((scenario.id, scenario.group, scenario.name, scenario.context, result))
            }
        }
        return collected.sorted { $0.id < $1.id }
    }

    private func runMatrix() -> [(id: Int, group: String, name: String, context: String, result: CoachNarrativeAuditResult)] {
        (auditScenarios(in: 1...16) + auditScenarios(in: 17...32)).sorted { $0.id < $1.id }
    }

    private func partialResultsURL(part: Int) -> URL {
        URL(fileURLWithPath: "/tmp/WeekFitCoachNarrativeValidationAudit.part\(part).json")
    }

    private func writePartialReport(
        _ results: [(id: Int, group: String, name: String, context: String, result: CoachNarrativeAuditResult)],
        part: Int
    ) {
        let payload = results.map { storedPayload(for: $0) }
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else {
            return
        }
        try? data.write(to: partialResultsURL(part: part), options: .atomic)
    }

    private func storedPayload(
        for item: (id: Int, group: String, name: String, context: String, result: CoachNarrativeAuditResult)
    ) -> [String: Any] {
        [
            "id": item.id,
            "group": item.group,
            "name": item.name,
            "context": item.context,
            "snapshot": [
                "owner": item.result.snapshot.owner,
                "priority": item.result.snapshot.priority,
                "badge": item.result.snapshot.badge,
                "title": item.result.snapshot.title,
                "read": item.result.snapshot.read,
                "recommendation": item.result.snapshot.recommendation,
                "careful": item.result.snapshot.careful,
                "why": item.result.snapshot.why,
                "supportReasons": item.result.snapshot.supportReasons
            ],
            "findings": item.result.findings.map {
                [
                    "flag": $0.flag.rawValue,
                    "severity": $0.severity.rawValue,
                    "detail": $0.detail
                ]
            }
        ]
    }

    private func decodeStoredResults(from data: Data) throws -> [(id: Int, group: String, name: String, context: String, result: CoachNarrativeAuditResult)] {
        let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return raw.compactMap { entry in
            guard let id = entry["id"] as? Int,
                  let group = entry["group"] as? String,
                  let name = entry["name"] as? String,
                  let context = entry["context"] as? String,
                  let snapshotRaw = entry["snapshot"] as? [String: Any],
                  let findingsRaw = entry["findings"] as? [[String: Any]] else {
                return nil
            }

            let snapshot = CoachNarrativeStorySnapshot(
                owner: snapshotRaw["owner"] as? String ?? "",
                priority: snapshotRaw["priority"] as? String ?? "",
                badge: snapshotRaw["badge"] as? String ?? "",
                title: snapshotRaw["title"] as? String ?? "",
                read: snapshotRaw["read"] as? String ?? "",
                recommendation: snapshotRaw["recommendation"] as? String ?? "",
                careful: snapshotRaw["careful"] as? String ?? "",
                why: snapshotRaw["why"] as? [String] ?? [],
                supportReasons: snapshotRaw["supportReasons"] as? [String] ?? []
            )

            let findings = findingsRaw.compactMap { finding -> CoachNarrativeAuditFinding? in
                guard let flagRaw = finding["flag"] as? String,
                      let severityRaw = finding["severity"] as? String,
                      let detail = finding["detail"] as? String,
                      let flag = CoachNarrativeAuditFlag.allCases.first(where: { $0.rawValue == flagRaw }),
                      let severity = CoachNarrativeAuditSeverity(rawValue: severityRaw) else {
                    return nil
                }
                return CoachNarrativeAuditFinding(flag: flag, severity: severity, detail: detail)
            }

            return (
                id,
                group,
                name,
                context,
                CoachNarrativeAuditResult(snapshot: snapshot, findings: findings)
            )
        }
    }

    private func buildReport(
        results: [(id: Int, group: String, name: String, context: String, result: CoachNarrativeAuditResult)],
        includeHeader: Bool = true,
        includeSummary: Bool = true
    ) -> String {
        var sections: [String] = []
        if includeHeader {
            sections.append("# Coach Narrative Validation Audit — Phase 2")
            sections.append("")
            sections.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
            sections.append("")
        }
        if includeSummary {
            sections.append("## Summary")
            sections.append("")
            let weak = results.filter { $0.result.isWeakStory }
            sections.append("- Scenarios run: \(results.count)")
            sections.append("- Clean stories: \(results.count - weak.count)")
            sections.append("- Weak stories: \(weak.count)")
            sections.append("")

            if !weak.isEmpty {
                sections.append("### Weak story index")
                sections.append("")
                for item in weak.sorted(by: { $0.id < $1.id }) {
                    sections.append("- **\(item.id). \(item.name)** [\(item.result.severity.rawValue)]: \(item.result.findings.map(\.flag.rawValue).joined(separator: "; "))")
                }
                sections.append("")
            }
        }

        for item in results.sorted(by: { $0.id < $1.id }) {
            sections.append(
                CoachNarrativeAuditor.formatReport(
                    scenarioID: item.id,
                    group: item.group,
                    name: item.name,
                    context: item.context,
                    result: item.result
                )
            )
        }

        return sections.joined(separator: "\n")
    }

    private func appendReportToLog(_ report: String) {
        let urls = [
            URL(fileURLWithPath: "/tmp/WeekFitCoachNarrativeValidationAudit.md"),
            URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("WeekFitCoachNarrativeValidationAudit.md")
        ]
        for url in urls {
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func scenarios() -> [Scenario] {
        let morningTime = morning
        let eveningTime = date(hour: 19)
        let lateEveningTime = date(hour: 21)
        let tomorrowMorning = tomorrow(hour: 9)

        return [
            // MORNING
            morningRecoveryScenario(id: 1, recoveryPercent: 95, tier: .high),
            morningRecoveryScenario(id: 2, recoveryPercent: 80, tier: .moderate),
            morningRecoveryScenario(id: 3, recoveryPercent: 67, tier: .moderate),
            morningRecoveryScenario(id: 4, recoveryPercent: 45, tier: .low),
            morningRecoveryScenario(id: 5, recoveryPercent: 25, tier: .depleted),

            // WORKOUT PREP
            workoutPrepScenario(id: 6, recoveryPercent: 95, tier: .high),
            workoutPrepScenario(id: 7, recoveryPercent: 70, tier: .moderate),
            workoutPrepScenario(id: 8, recoveryPercent: 45, tier: .low),

            // ACTIVE
            Scenario(
                id: 9,
                group: "ACTIVE",
                name: "Easy walk active",
                context: "30 min walk started 5 min ago",
                makeState: {
                    let walk = self.activity(type: "walking", title: "Walk", minutesFromNow: -5, duration: 30, icon: "figure.walk", baseDate: morningTime)
                    walk.source = "today"
                    return self.makeState(
                        activities: [walk],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.4, calories: 900, protein: 45, carbs: 100),
                        activeCalories: 80,
                        recoveryPercent: 88,
                        sleepHours: 7.8
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: true,
                    hasCompletedWorkout: false,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.activeActivity, .pacingExecution, .sustainableExecution]
                )
            ),
            Scenario(
                id: 10,
                group: "ACTIVE",
                name: "Long ride active",
                context: "210 min ride, 55 min elapsed",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Long ride", minutesFromNow: -55, duration: 210, icon: "bicycle", baseDate: morningTime)
                    ride.source = "today"
                    return self.makeState(
                        activities: [ride],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.6, calories: 1_500, protein: 70, carbs: 190),
                        activeCalories: 820,
                        recoveryPercent: 84,
                        sleepHours: 7.5
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: true,
                    hasCompletedWorkout: false,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.sustainableExecution, .pacingExecution, .activeActivity, .fuelingDuringActivity, .hydrationExecution]
                )
            ),
            Scenario(
                id: 11,
                group: "ACTIVE",
                name: "Strength workout active",
                context: "60 min strength, 15 min elapsed",
                makeState: {
                    let strength = self.activity(type: "strength", title: "Strength", minutesFromNow: -15, duration: 60, icon: "dumbbell.fill", baseDate: morningTime)
                    strength.source = "today"
                    return self.makeState(
                        activities: [strength],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.7, calories: 1_300, protein: 90, carbs: 130),
                        activeCalories: 220,
                        recoveryPercent: 86,
                        sleepHours: 7.6
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: true,
                    hasCompletedWorkout: false,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.activeActivity, .pacingExecution, .hydrationExecution, .fuelingDuringActivity]
                )
            ),

            // POST WORKOUT
            Scenario(
                id: 12,
                group: "POST WORKOUT",
                name: "Easy walk completed",
                context: "30 min walk finished 20 min ago",
                makeState: {
                    let walk = self.activity(type: "walking", title: "Walk", minutesFromNow: -50, duration: 30, icon: "figure.walk", completed: true, baseDate: morningTime)
                    return self.makeState(
                        activities: [walk],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.5, calories: 1_200, protein: 60, carbs: 130),
                        activeCalories: 260,
                        completedWorkoutsCount: 1,
                        recoveryPercent: 84,
                        sleepHours: 7.4
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: false,
                    hasCompletedWorkout: true,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.stableOverview, .readiness, .recovery, .postActivityRecovery]
                )
            ),
            Scenario(
                id: 13,
                group: "POST WORKOUT",
                name: "Long ride completed",
                context: "150 min ride finished 90 min ago",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Long ride", minutesFromNow: -240, duration: 150, icon: "bicycle", completed: true, baseDate: morningTime)
                    return self.makeState(
                        activities: [ride],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 2.4, calories: 2_200, protein: 95, carbs: 250),
                        activeCalories: 1_850,
                        completedWorkoutsCount: 1,
                        recoveryPercent: 72,
                        sleepHours: 7.0,
                        exerciseMinutes: 150
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: false,
                    hasCompletedWorkout: true,
                    recoveryTier: .moderate,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.postActivityRecovery, .recovery]
                )
            ),
            Scenario(
                id: 14,
                group: "POST WORKOUT",
                name: "Hard run completed",
                context: "90 min hard run finished 60 min ago",
                makeState: {
                    let run = self.activity(type: "running", title: "Hard run", minutesFromNow: -150, duration: 90, icon: "figure.run", completed: true, baseDate: morningTime)
                    return self.makeState(
                        activities: [run],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.8, calories: 1_400, protein: 70, carbs: 160),
                        activeCalories: 1_100,
                        completedWorkoutsCount: 1,
                        recoveryPercent: 68,
                        sleepHours: 7.1,
                        exerciseMinutes: 90
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: false,
                    hasCompletedWorkout: true,
                    recoveryTier: .moderate,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.postActivityRecovery, .recovery]
                )
            ),

            // RECOVERY DAYS
            Scenario(
                id: 15,
                group: "RECOVERY DAYS",
                name: "Day after long ride",
                context: "Morning after heavy endurance load, recovery 68%",
                makeState: {
                    self.makeState(
                        activities: [],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.5, calories: 900, protein: 50, carbs: 100),
                        sleepState: .okay,
                        recoveryState: .stable,
                        readinessState: .good,
                        activeCalories: 120,
                        completedWorkoutsCount: 1,
                        recoveryPercent: 68,
                        sleepHours: 7.0,
                        exerciseMinutes: 0
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: false,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .moderate,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.recovery, .readiness, .stableOverview, .postActivityRecovery]
                )
            ),
            Scenario(
                id: 16,
                group: "RECOVERY DAYS",
                name: "Day after hard strength session",
                context: "Morning after heavy strength, recovery 62%",
                makeState: {
                    self.makeState(
                        activities: [],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.4, calories: 950, protein: 55, carbs: 95),
                        sleepState: .okay,
                        recoveryState: .compromised,
                        readinessState: .good,
                        activeCalories: 90,
                        completedWorkoutsCount: 1,
                        recoveryPercent: 62,
                        sleepHours: 6.9
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: false,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .moderate,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.recovery, .readiness, .stableOverview, .postActivityRecovery]
                )
            ),
            Scenario(
                id: 17,
                group: "RECOVERY DAYS",
                name: "Day after poor sleep",
                context: "Morning after short sleep, recovery 48%",
                makeState: {
                    self.makeState(
                        activities: [],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.2, calories: 700, protein: 35, carbs: 80),
                        sleepState: .short,
                        recoveryState: .compromised,
                        readinessState: .low,
                        activeCalories: 80,
                        recoveryPercent: 48,
                        sleepHours: 5.3
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: false,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .low,
                    sleepTier: .deficit,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.recovery, .readiness, .stableOverview]
                )
            ),

            // EVENING
            Scenario(
                id: 18,
                group: "EVENING",
                name: "No activities left",
                context: "19:00, no planned or completed load",
                makeState: {
                    self.makeState(
                        activities: [],
                        currentDate: eveningTime,
                        nutrition: self.nutrition(water: 1.8, calories: 1_700, protein: 90, carbs: 170),
                        sleepState: .okay,
                        recoveryState: .stable,
                        readinessState: .good,
                        activeCalories: 180,
                        recoveryPercent: 86,
                        sleepHours: 7.4
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: false,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.stableOverview, .readiness, .recovery]
                )
            ),
            Scenario(
                id: 19,
                group: "EVENING",
                name: "Workout completed",
                context: "19:00 after long ride",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Cycling", minutesFromNow: -240, duration: 190, icon: "bicycle", completed: true, baseDate: eveningTime)
                    return self.makeState(
                        activities: [ride],
                        currentDate: eveningTime,
                        nutrition: self.nutrition(water: 3.0, calories: 2_800, protein: 180, carbs: 280),
                        activeCalories: 2_000,
                        completedWorkoutsCount: 1,
                        recoveryPercent: 78,
                        sleepHours: 7.0,
                        exerciseMinutes: 190
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: false,
                    hasCompletedWorkout: true,
                    recoveryTier: .moderate,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.postActivityRecovery, .recovery]
                )
            ),
            Scenario(
                id: 20,
                group: "EVENING",
                name: "Tomorrow contains long workout",
                context: "21:00 with 150 min ride planned tomorrow",
                makeState: {
                    let tomorrowRide = self.activity(type: "cycling", title: "Tomorrow ride", minutesFromNow: 0, duration: 150, icon: "bicycle", baseDate: tomorrowMorning)
                    return self.makeState(
                        activities: [tomorrowRide],
                        currentDate: lateEveningTime,
                        nutrition: self.nutrition(water: 2.0, calories: 2_000, protein: 110, carbs: 220),
                        recoveryPercent: 80,
                        sleepHours: 7.0
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .moderate,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: true,
                    allowedOwners: [.tomorrowProtection, .readiness, .stableOverview, .activityPreparation]
                )
            ),

            // SLEEP
            Scenario(
                id: 21,
                group: "SLEEP",
                name: "Excellent sleep",
                context: "8.3 h sleep, recovery 93%",
                makeState: {
                    self.makeState(
                        activities: [],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.4, calories: 900, protein: 50, carbs: 90),
                        sleepState: .strong,
                        recoveryState: .strong,
                        readinessState: .good,
                        recoveryPercent: 93,
                        sleepHours: 8.3
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: false,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .high,
                    sleepTier: .excellent,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.readiness, .stableOverview]
                )
            ),
            Scenario(
                id: 22,
                group: "SLEEP",
                name: "Sleep deficit",
                context: "5.0 h sleep, recovery 38%",
                makeState: {
                    self.makeState(
                        activities: [],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.0, calories: 650, protein: 30, carbs: 70),
                        sleepState: .veryShort,
                        recoveryState: .compromised,
                        readinessState: .low,
                        recoveryPercent: 38,
                        sleepHours: 5.0
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: false,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .depleted,
                    sleepTier: .deficit,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.recovery, .readiness, .stableOverview]
                )
            ),
            Scenario(
                id: 23,
                group: "SLEEP",
                name: "Fragmented sleep",
                context: "6.4 h sleep with short sleep state, recovery 58%",
                makeState: {
                    self.makeState(
                        activities: [],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.2, calories: 750, protein: 40, carbs: 85),
                        sleepState: .short,
                        recoveryState: .compromised,
                        readinessState: .low,
                        recoveryPercent: 58,
                        sleepHours: 6.4
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: false,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .low,
                    sleepTier: .fragmented,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.recovery, .readiness, .stableOverview]
                )
            ),

            // NUTRITION
            Scenario(
                id: 24,
                group: "NUTRITION",
                name: "Nutrition empty morning",
                context: "8:00 with zero calories logged",
                makeState: {
                    self.makeState(
                        activities: [],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.2, calories: 0, protein: 0, carbs: 0),
                        sleepState: .strong,
                        recoveryState: .strong,
                        readinessState: .good,
                        recoveryPercent: 88,
                        sleepHours: 7.8
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: false,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: true,
                    hasTomorrowDemand: false,
                    allowedOwners: [.readiness, .stableOverview, .recovery, .fuel]
                )
            ),
            Scenario(
                id: 25,
                group: "NUTRITION",
                name: "Under-fueled after workout",
                context: "Completed strength with only 900 kcal logged",
                makeState: {
                    let strength = self.activity(type: "strength", title: "Strength", minutesFromNow: -90, duration: 70, icon: "dumbbell.fill", completed: true, baseDate: morningTime)
                    return self.makeState(
                        activities: [strength],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.2, calories: 900, protein: 40, carbs: 70),
                        activeCalories: 650,
                        completedWorkoutsCount: 1,
                        recoveryPercent: 76,
                        sleepHours: 7.1
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: false,
                    hasCompletedWorkout: true,
                    recoveryTier: .moderate,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: true,
                    hasTomorrowDemand: false,
                    allowedOwners: [.postActivityRecovery, .recovery, .fuel]
                )
            ),
            Scenario(
                id: 26,
                group: "NUTRITION",
                name: "Strong nutrition adherence",
                context: "Completed strength with protein and calories on target",
                makeState: {
                    let strength = self.activity(type: "strength", title: "Strength", minutesFromNow: -90, duration: 70, icon: "dumbbell.fill", completed: true, baseDate: morningTime)
                    return self.makeState(
                        activities: [strength],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 2.5, calories: 2_700, protein: 220, carbs: 260),
                        activeCalories: 800,
                        completedWorkoutsCount: 1,
                        recoveryPercent: 82,
                        sleepHours: 7.2
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: false,
                    hasCompletedWorkout: true,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.postActivityRecovery, .recovery, .stableOverview]
                )
            ),

            // HYDRATION
            Scenario(
                id: 27,
                group: "HYDRATION",
                name: "Morning no water",
                context: "8:00 with zero water logged",
                makeState: {
                    self.makeState(
                        activities: [],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 0, calories: 700, protein: 35, carbs: 80),
                        sleepState: .strong,
                        recoveryState: .strong,
                        readinessState: .good,
                        recoveryPercent: 88,
                        sleepHours: 7.8
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: false,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: true,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.readiness, .stableOverview, .recovery, .hydration]
                )
            ),
            Scenario(
                id: 28,
                group: "HYDRATION",
                name: "Heat day + low hydration",
                context: "Sauna in 45 min with severe water gap",
                makeState: {
                    let sauna = self.activity(type: "sauna", title: "Sauna", minutesFromNow: 45, duration: 30, icon: "flame.fill", baseDate: morningTime)
                    return self.makeState(
                        activities: [sauna],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 0.05, calories: 1_100, protein: 60, carbs: 120),
                        recoveryPercent: 80,
                        sleepHours: 7.1
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .moderate,
                    sleepTier: .adequate,
                    hasHydrationGap: true,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.hydration, .activityPreparation]
                )
            ),
            Scenario(
                id: 29,
                group: "HYDRATION",
                name: "Normal hydration",
                context: "Midday with water on target",
                makeState: {
                    self.makeState(
                        activities: [],
                        currentDate: self.date(hour: 13),
                        nutrition: self.nutrition(water: 1.6, calories: 1_400, protein: 80, carbs: 150),
                        recoveryPercent: 84,
                        sleepHours: 7.3
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: false,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.readiness, .stableOverview, .recovery]
                )
            ),

            // PLANNER
            Scenario(
                id: 30,
                group: "PLANNER",
                name: "No activities planned",
                context: "Empty planner at 10:00",
                makeState: {
                    self.makeState(
                        activities: [],
                        currentDate: self.date(hour: 10),
                        nutrition: self.nutrition(),
                        recoveryPercent: 86,
                        sleepHours: 7.5
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: false,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.readiness, .stableOverview, .recovery]
                )
            ),
            Scenario(
                id: 31,
                group: "PLANNER",
                name: "One activity planned",
                context: "Run planned in 3 hours",
                makeState: {
                    let run = self.activity(type: "running", title: "Run", minutesFromNow: 180, duration: 60, icon: "figure.run", baseDate: morningTime)
                    return self.makeState(
                        activities: [run],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.4, calories: 900, protein: 50, carbs: 100),
                        recoveryPercent: 86,
                        sleepHours: 7.5
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.activityPreparation, .readiness, .stableOverview]
                )
            ),
            Scenario(
                id: 32,
                group: "PLANNER",
                name: "Full structured day",
                context: "Walk, strength, and sauna planned",
                makeState: {
                    let walk = self.activity(type: "walking", title: "Morning walk", minutesFromNow: 60, duration: 30, icon: "figure.walk", baseDate: morningTime)
                    let strength = self.activity(type: "strength", title: "Strength", minutesFromNow: 300, duration: 60, icon: "dumbbell.fill", baseDate: morningTime)
                    let sauna = self.activity(type: "sauna", title: "Sauna", minutesFromNow: 540, duration: 30, icon: "flame.fill", baseDate: morningTime)
                    return self.makeState(
                        activities: [walk, strength, sauna],
                        currentDate: morningTime,
                        nutrition: self.nutrition(water: 1.3, calories: 850, protein: 45, carbs: 95),
                        recoveryPercent: 86,
                        sleepHours: 7.6
                    )
                },
                expectation: CoachNarrativeScenarioExpectation(
                    hasWorkoutContext: true,
                    hasActiveSession: false,
                    hasCompletedWorkout: false,
                    recoveryTier: .high,
                    sleepTier: .adequate,
                    hasHydrationGap: false,
                    hasFuelGap: false,
                    hasTomorrowDemand: false,
                    allowedOwners: [.activityPreparation, .readiness, .stableOverview]
                )
            )
        ]
    }

    private func morningRecoveryScenario(
        id: Int,
        recoveryPercent: Int,
        tier: CoachNarrativeScenarioExpectation.RecoveryTier
    ) -> Scenario {
        let profile = recoveryProfile(for: recoveryPercent)
        return Scenario(
            id: id,
            group: "MORNING",
            name: "Recovery \(recoveryPercent), no activities",
            context: "8:00, recovery \(recoveryPercent)%, no planned activity",
            makeState: {
                self.makeState(
                    activities: [],
                    currentDate: self.morning,
                    nutrition: self.nutrition(water: 1.4, calories: 900, protein: 50, carbs: 90),
                    sleepState: profile.sleep,
                    recoveryState: profile.recovery,
                    readinessState: profile.readiness,
                    recoveryPercent: recoveryPercent,
                    sleepHours: profile.sleepHours
                )
            },
            expectation: CoachNarrativeScenarioExpectation(
                hasWorkoutContext: false,
                hasActiveSession: false,
                hasCompletedWorkout: false,
                recoveryTier: tier,
                sleepTier: profile.sleepTier,
                hasHydrationGap: false,
                hasFuelGap: false,
                hasTomorrowDemand: false,
                allowedOwners: tier == .high || tier == .moderate
                    ? [.readiness, .stableOverview, .recovery]
                    : [.recovery, .readiness, .stableOverview]
            )
        )
    }

    private func workoutPrepScenario(
        id: Int,
        recoveryPercent: Int,
        tier: CoachNarrativeScenarioExpectation.RecoveryTier
    ) -> Scenario {
        let profile = recoveryProfile(for: recoveryPercent)
        return Scenario(
            id: id,
            group: "WORKOUT PREP",
            name: "Recovery \(recoveryPercent), workout in 2h",
            context: "Ride planned in 120 min, recovery \(recoveryPercent)%",
            makeState: {
                let ride = self.activity(type: "cycling", title: "Ride", minutesFromNow: 120, duration: 90, icon: "bicycle", baseDate: self.morning)
                return self.makeState(
                    activities: [ride],
                    currentDate: self.morning,
                    nutrition: self.nutrition(water: 1.6, calories: 1_000, protein: 55, carbs: 130),
                    sleepState: profile.sleep,
                    recoveryState: profile.recovery,
                    readinessState: profile.readiness,
                    recoveryPercent: recoveryPercent,
                    sleepHours: profile.sleepHours
                )
            },
            expectation: CoachNarrativeScenarioExpectation(
                hasWorkoutContext: true,
                hasActiveSession: false,
                hasCompletedWorkout: false,
                recoveryTier: tier,
                sleepTier: profile.sleepTier,
                hasHydrationGap: false,
                hasFuelGap: false,
                hasTomorrowDemand: false,
                allowedOwners: tier == .low || tier == .depleted
                    ? [.activityPreparation, .readiness, .recovery, .tomorrowProtection]
                    : [.activityPreparation, .readiness, .stableOverview]
            )
        )
    }

    private struct RecoveryProfile {
        let sleep: HumanBrain.SleepState
        let recovery: HumanBrain.RecoveryState
        let readiness: HumanBrain.ReadinessState
        let sleepHours: Double
        let sleepTier: CoachNarrativeScenarioExpectation.SleepTier
    }

    private func recoveryProfile(for percent: Int) -> RecoveryProfile {
        switch percent {
        case 90...:
            return RecoveryProfile(
                sleep: .strong,
                recovery: .strong,
                readiness: .good,
                sleepHours: 8.2,
                sleepTier: .excellent
            )
        case 75..<90:
            return RecoveryProfile(
                sleep: .okay,
                recovery: .stable,
                readiness: .good,
                sleepHours: 7.4,
                sleepTier: .adequate
            )
        case 60..<75:
            return RecoveryProfile(
                sleep: .okay,
                recovery: .stable,
                readiness: .good,
                sleepHours: 7.0,
                sleepTier: .adequate
            )
        case 40..<60:
            return RecoveryProfile(
                sleep: .short,
                recovery: .compromised,
                readiness: .low,
                sleepHours: 5.8,
                sleepTier: .deficit
            )
        default:
            return RecoveryProfile(
                sleep: .veryShort,
                recovery: .compromised,
                readiness: .low,
                sleepHours: 5.0,
                sleepTier: .deficit
            )
        }
    }

    // MARK: - State builder

    private func date(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }

    private func tomorrow(hour: Int, minute: Int = 0) -> Date {
        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrowDate) ?? tomorrowDate
    }

    private func makeState(
        activities: [PlannedActivity],
        currentDate: Date? = nil,
        nutrition providedNutrition: CoachNutritionContext? = nil,
        sleepState: HumanBrain.SleepState = .okay,
        recoveryState: HumanBrain.RecoveryState = .stable,
        readinessState: HumanBrain.ReadinessState = .good,
        activeCalories: Double = 240,
        completedWorkoutsCount: Int? = nil,
        recoveryPercent: Int = 84,
        sleepHours: Double = 7.4,
        exerciseMinutes: Int? = nil,
        activityProgress: Double? = nil
    ) -> CoachState {
        let nutrition = providedNutrition ?? nutrition()
        let decisionDate = currentDate ?? now
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = Calendar.current.component(.hour, from: decisionDate)
        brainConfig.hasAnyFoodLogged = (nutrition.mealsCount ?? 0) > 0
        brainConfig.waterProgress = nutrition.waterGoal > 0 ? nutrition.waterCurrent / nutrition.waterGoal : 1
        brainConfig.hasWorkoutSoon = !activities.isEmpty
        brainConfig.nextWorkout = activities.first { !$0.isCompleted && !$0.isSkipped } ?? activities.first
        brainConfig.hoursToNextWorkout = brainConfig.nextWorkout.map { max(0, $0.date.timeIntervalSince(decisionDate) / 3600) }
        brainConfig.hydration = nutrition.waterCurrent <= 0.1 ? .depleted : (nutrition.waterCurrent < 0.7 ? .behind : .optimal)
        brainConfig.fuel = nutrition.caloriesCurrent < 500 ? .underfueled : .good
        brainConfig.sleep = sleepState
        brainConfig.recovery = recoveryState
        brainConfig.readiness = readinessState
        brainConfig.completedWorkoutsCount = completedWorkoutsCount
        brainConfig.metrics = CoachMetricsBuilder.metrics(
            protein: nutrition.proteinCurrent,
            carbs: nutrition.carbsCurrent,
            calories: nutrition.caloriesCurrent,
            waterLiters: nutrition.waterCurrent,
            activeCalories: activeCalories,
            sleepHours: sleepHours
        )
        let brain = HumanBrainStateBuilder.make(brainConfig)
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: decisionDate,
            now: decisionDate
        )
        let input = CoachInputSnapshot(
            selectedDate: decisionDate,
            now: decisionDate,
            brain: brain,
            plannedActivities: activities,
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: activeCalories,
                exerciseMinutes: exerciseMinutes,
                standHours: nil,
                activityGoalCalories: activityProgress.map { activeCalories / max($0, 0.01) },
                activityProgress: activityProgress
            ),
            dayContext: dayContext,
            recoveryContext: CoachRecoveryContext(recoveryPercent: recoveryPercent, sleepHours: sleepHours),
            nutritionContext: nutrition,
            source: "CoachNarrativeValidationSuite"
        )
        let guidance = CoachEngineV3.decide(
            from: brain.refreshedForCurrentLocalTime(activities: activities),
            plannedActivities: activities,
            selectedDate: now,
            dayContext: dayContext,
            recoveryContext: input.recoveryContext,
            nutritionContext: nutrition
        )

        return CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: guidance,
            createdAt: decisionDate
        )
    }

    private func activity(
        type: String,
        title: String,
        minutesFromNow: Int,
        duration: Int,
        icon: String,
        completed: Bool = false,
        baseDate: Date? = nil,
        source: String = "planner"
    ) -> PlannedActivity {
        PlannedActivity(
            date: CoachTestClock.offset(minutes: minutesFromNow, from: baseDate ?? now),
            type: type,
            title: title,
            durationMinutes: duration,
            icon: icon,
            imageName: icon,
            colorRed: 0.3,
            colorGreen: 0.6,
            colorBlue: 0.9,
            isCompleted: completed,
            source: source
        )
    }

    private func nutrition(
        water: Double = 1.6,
        calories: Double = 1_400,
        protein: Double = 80,
        carbs: Double = 150
    ) -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: calories,
            caloriesGoal: CoachMetricsBuilder.standardGoals.calories,
            proteinCurrent: protein,
            proteinGoal: CoachMetricsBuilder.standardGoals.protein,
            carbsCurrent: carbs,
            carbsGoal: CoachMetricsBuilder.standardGoals.carbs,
            fatsCurrent: 40,
            fatsGoal: CoachMetricsBuilder.standardGoals.fats,
            waterCurrent: water,
            waterGoal: CoachMetricsBuilder.standardGoals.waterLiters,
            mealsCount: calories > 0 ? 1 : 0,
            lastMealTime: now
        )
    }
}
