import XCTest
@testable import WeekFit

final class CoachConversationSemanticTimingAuditTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.russian)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    // MARK: - Unit rules

    func testMorningFlagsDayCompleteTone() {
        let findings = CoachConversationSemanticTimingAudit.audit(
            pack: pack(russian: "Доказывать уже нечего — остаток дня спокойный."),
            context: context(timeOfDay: .morning)
        )
        XCTAssertFalse(findings.isClean)
    }

    func testFastingWindowFlagsEatNowInMainStory() {
        let findings = CoachConversationSemanticTimingAudit.audit(
            pack: pack(russian: "Вода, еда по плану и немного отдыха."),
            context: context(timeOfDay: .midday, mealWindowOpen: false)
        )
        XCTAssertTrue(findings.findings.contains { $0.reason.contains("first meal window") })
    }

    func testFastingWindowAllowsNeutralFirstMealAheadSignal() {
        let findings = CoachConversationSemanticTimingAudit.audit(
            pack: pack(
                russian: "Спокойный день.",
                supportingRussian: "Первая еда ещё впереди."
            ),
            context: context(timeOfDay: .midday, mealWindowOpen: false)
        )
        XCTAssertTrue(findings.isClean)
    }

    func testFastingWindowFlagsFuelBehindWhyRow() {
        let findings = CoachConversationSemanticTimingAudit.audit(
            pack: pack(
                russian: "Спокойный день.",
                supportingRussian: "Еды пока меньше, чем требует день."
            ),
            context: context(timeOfDay: .midday, mealWindowOpen: false)
        )
        XCTAssertTrue(findings.findings.contains { $0.reason.contains("fasting window") })
    }

    func testGroundedCompletionPassesAudit() {
        let findings = CoachConversationSemanticTimingAudit.audit(
            pack: pack(russian: "Прогулка уже была — дальше держите обычный спокойный ритм."),
            context: context(
                timeOfDay: .midday,
                completedRecoveryWalkToday: true,
                mealWindowOpen: false
            )
        )
        XCTAssertTrue(findings.isClean)
    }

    func testEveningAllowsRestOfDayTone() {
        let findings = CoachConversationSemanticTimingAudit.audit(
            pack: pack(russian: "Остаток дня спокойный — без нового тяжёлого блока."),
            context: context(timeOfDay: .evening, completedSeriousWorkToday: true)
        )
        XCTAssertTrue(findings.isClean)
    }

    func testWindDownAllowsClosureTone() {
        let findings = CoachConversationSemanticTimingAudit.audit(
            pack: pack(russian: "На сегодня достаточно — день можно завершить спокойно."),
            context: context(timeOfDay: .lateEvening, completedSeriousWorkToday: true)
        )
        XCTAssertTrue(findings.isClean)
    }

    // MARK: - Snapshot cases

    func test0830RecoveryDayAfterHeavyYesterday() throws {
        let input = recoveryDayInput(
            timeOfDay: .morning,
            hadHeavyYesterday: true,
            completedWalk: false,
            mealWindowOpen: false
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        assertSemanticAuditClean(pack: pack, input: input, label: "08:30")

        let russian = joinedRussian(pack)
        XCTAssertTrue(
            russian.contains("вчерашн") || russian.contains("восстановлен"),
            "08:30 should frame recovery after yesterday"
        )
        assertForbiddenAtMiddayRecovery(russian, label: "08:30")
    }

    func test1047RecoveryDayWithCompletedWalkAndFasting() throws {
        let input = recoveryDayInput(
            timeOfDay: .midday,
            hadHeavyYesterday: true,
            completedWalk: true,
            mealWindowOpen: false
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        assertSemanticAuditClean(pack: pack, input: input, label: "10:47")

        XCTAssertEqual(
            CoachStableDayPresentation.todayTitle(
                for: .lowRecoveryRest,
                hadHeavyYesterday: true,
                russian: true
            ),
            "После вчерашней нагрузки"
        )

        XCTAssertEqual(
            pack.assessment.lines.first?.russian,
            "После вчерашней нагрузки сегодня лучше не форсировать."
        )
        XCTAssertEqual(
            pack.recommendation.lines.first?.russian,
            "Прогулка уже была — дальше держите обычный спокойный ритм."
        )
        XCTAssertEqual(
            pack.avoid.lines.first?.russian,
            "Не добирайте шаги или калории только ради цифр."
        )
        XCTAssertEqual(
            pack.nextAction.lines.first?.russian,
            "Вода по самочувствию, а еда — в привычное время."
        )

        let russian = joinedRussian(pack)
        let english = joinedEnglish(pack)
        assertForbiddenAtMiddayRecovery(russian, label: "10:47")
        assertForbiddenAtMiddayRecovery(english, label: "10:47 EN")
        XCTAssertFalse(pack.supportingSignals.lines.contains { $0.russian.contains("Еды пока меньше") })
    }

    func test1230FastingEmptyDayWithoutEatNowTone() throws {
        let input = fastingEmptyDayInput(timeOfDay: .midday)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        assertSemanticAuditClean(pack: pack, input: input, label: "12:30")

        let russian = joinedRussian(pack)
        XCTAssertFalse(russian.contains("поешьте"))
        XCTAssertFalse(russian.contains("еды пока меньше"))
        XCTAssertFalse(pack.supportingSignals.lines.contains { $0.russian.contains("Еды пока меньше") })
        XCTAssertTrue(pack.supportingSignals.lines.contains { $0.russian.contains("Первая еда ещё впереди") })
    }

    func test1500RecoveryDayLightActivityCompleted() throws {
        let input = lightActivityRecoveryInput(timeOfDay: .afternoon)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        assertSemanticAuditClean(pack: pack, input: input, label: "15:00")

        let russian = joinedRussian(pack)
        XCTAssertFalse(russian.contains("на сегодня достаточно"))
        XCTAssertFalse(russian.contains("доказывать уже нечего"))
    }

    func test1900RestOfDayAllowedClosureForbidden() throws {
        let input = walkCompletedInput(timeOfDay: .evening)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        assertSemanticAuditClean(pack: pack, input: input, label: "19:00")

        let russian = joinedRussian(pack)
        XCTAssertTrue(russian.contains("остаток дня") || russian.contains("вечер"))
        XCTAssertFalse(russian.contains("на сегодня достаточно"))
        XCTAssertFalse(russian.contains("завершить день"))
    }

    func test2200ClosureAllowed() throws {
        let input = walkCompletedInput(timeOfDay: .lateEvening)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        assertSemanticAuditClean(pack: pack, input: input, label: "22:00")

        let russian = joinedRussian(pack)
        XCTAssertTrue(
            russian.contains("завершить") || russian.contains("остаток дня"),
            "22:00 may use closure or rest-of-day phrasing"
        )
    }

    func testBaselinePacksPassSemanticTimingAudit() {
        var failures: [String] = []

        for scenario in CoachScenarioKey.allCases {
            let input = CoachCopyQualityTests.baselineInput(for: scenario)
            guard let pack = CoachCopyRegistry.resolve(input) else { continue }
            let report = CoachConversationSemanticTimingAudit.audit(pack: pack, input: input)
            if !report.isClean {
                let line = "\(scenario.rawValue) @ \(input.timeOfDay.rawValue): " +
                    report.findings.map { "\($0.section) \($0.phrase)" }.joined(separator: ", ")
                failures.append(line)
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    // MARK: - Helpers

    private func recoveryDayInput(
        timeOfDay: CoachTimeOfDay,
        hadHeavyYesterday: Bool,
        completedWalk: Bool,
        mealWindowOpen: Bool
    ) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: 38,
            sleepHours: 5.0,
            recoveryBand: .low,
            hadHeavyYesterday: hadHeavyYesterday,
            sleepIsLow: true
        )
        return CoachCopyBuildInput(
            scenario: .stableDay,
            modifiers: CoachScenarioModifiers(
                dayLoad: .fresh,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: completedWalk ? .walk : .none,
                durationBand: .short,
                completedSeriousActivities: .none,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .none
            ),
            athleteState: CoachAthleteStateResolver.resolve(dayReadiness: readiness),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .recovery,
            alertSeverity: .none,
            tomorrowWorkout: nil,
            dayReadiness: readiness,
            focusSource: completedWalk ? .recentCompleted : .idle,
            sessionPhase: completedWalk ? .settledPost : .idle,
            activityState: completedWalk ? .finished : .none,
            minutesSinceEnd: completedWalk ? 45 : nil,
            mealWindowOpen: mealWindowOpen
        )
    }

    private func fastingEmptyDayInput(timeOfDay: CoachTimeOfDay) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: 82,
            sleepHours: 7.5,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        return CoachCopyBuildInput(
            scenario: .stableDay,
            modifiers: CoachScenarioModifiers(
                dayLoad: .fresh,
                fuelBehind: true,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: .none,
                durationBand: .medium,
                completedSeriousActivities: .none,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .none
            ),
            athleteState: CoachAthleteStateResolver.resolve(dayReadiness: readiness),
            fuelState: .behind,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .stable,
            alertSeverity: .elevated,
            tomorrowWorkout: nil,
            dayReadiness: readiness,
            mealWindowOpen: false
        )
    }

    private func lightActivityRecoveryInput(timeOfDay: CoachTimeOfDay) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: 42,
            sleepHours: 5.5,
            recoveryBand: .low,
            hadHeavyYesterday: true,
            sleepIsLow: true
        )
        return CoachCopyBuildInput(
            scenario: .stableDay,
            modifiers: CoachScenarioModifiers(
                dayLoad: .moderate,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: .walk,
                durationBand: .short,
                completedSeriousActivities: .none,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .walk
            ),
            athleteState: CoachAthleteStateResolver.resolve(dayReadiness: readiness),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .recovery,
            alertSeverity: .none,
            tomorrowWorkout: nil,
            dayReadiness: readiness,
            focusSource: .recentCompleted,
            sessionPhase: .settledPost,
            activityState: .finished,
            minutesSinceEnd: 120,
            mealWindowOpen: true
        )
    }

    private func walkCompletedInput(timeOfDay: CoachTimeOfDay) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: 80,
            sleepHours: 7.0,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        return CoachCopyBuildInput(
            scenario: .walkAfterHeavyLoad,
            modifiers: CoachScenarioModifiers(
                dayLoad: .heavy,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: .walk,
                durationBand: .short,
                completedSeriousActivities: .one,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .fullBody
            ),
            athleteState: CoachAthleteStateResolver.resolve(dayReadiness: readiness),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .recovery,
            alertSeverity: .none,
            tomorrowWorkout: nil,
            dayReadiness: readiness,
            focusSource: .recentCompleted,
            sessionPhase: .settledPost,
            activityState: .finished,
            minutesSinceEnd: 90,
            mealWindowOpen: true
        )
    }

    private func context(
        timeOfDay: CoachTimeOfDay,
        completedSeriousWorkToday: Bool = false,
        completedRecoveryWalkToday: Bool = false,
        mealWindowOpen: Bool = true
    ) -> CoachConversationSemanticTimingAudit.Context {
        CoachConversationSemanticTimingAudit.Context(
            timeOfDay: timeOfDay,
            conversationPhase: .steady,
            scenario: .stableDay,
            hadHeavyYesterday: false,
            isLowRecovery: false,
            completedSeriousWorkToday: completedSeriousWorkToday,
            completedRecoveryWalkToday: completedRecoveryWalkToday,
            isTomorrowProtection: false,
            mealWindowOpen: mealWindowOpen,
            dehydrationRisk: false,
            fuelBehind: false,
            hydrationBehind: false
        )
    }

    private func pack(
        russian: String,
        supportingRussian: String? = nil
    ) -> CoachCopyPack {
        CoachCopyPack(
            scenario: .stableDay,
            assessment: .single(.en("Assessment", russian)),
            recommendation: .single(.en("Recommendation", "Рекомендация.")),
            avoid: .single(.en("Avoid", "Избегайте.")),
            nextAction: .single(.en("Next", "Дальше.")),
            supportingSignals: supportingRussian.map {
                CoachCopySection.single(.en("Signal", $0))
            } ?? CoachCopySection(lines: []),
            warningLayer: nil
        )
    }

    private func assertSemanticAuditClean(
        pack: CoachCopyPack,
        input: CoachCopyBuildInput,
        label: String
    ) {
        let report = CoachConversationSemanticTimingAudit.audit(pack: pack, input: input)
        XCTAssertTrue(
            report.isClean,
            "\(label): \(report.findings.map { "\($0.section): \($0.phrase) (\($0.reason))" }.joined(separator: "; "))"
        )
    }

    private func assertForbiddenAtMiddayRecovery(_ russian: String, label: String) {
        let forbidden = [
            "плотный день позади",
            "остаток дня спокойный",
            "на сегодня достаточно",
            "доказывать уже нечего",
            "вода, еда по плану"
        ]
        for phrase in forbidden {
            XCTAssertFalse(
                russian.contains(phrase),
                "\(label): must not contain «\(phrase)»"
            )
        }
    }

    private func joinedRussian(_ pack: CoachCopyPack) -> String {
        joinedLanguage(pack, \.russian)
    }

    private func joinedEnglish(_ pack: CoachCopyPack) -> String {
        joinedLanguage(pack, \.english)
    }

    private func joinedLanguage(_ pack: CoachCopyPack, _ keyPath: KeyPath<CoachBilingualText, String>) -> String {
        [
            pack.assessment,
            pack.recommendation,
            pack.avoid,
            pack.nextAction,
            pack.supportingSignals
        ]
        .flatMap(\.lines)
        .map { $0[keyPath: keyPath] }
        .joined(separator: " ")
        .lowercased()
    }
}
