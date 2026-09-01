import XCTest
@testable import WeekFit

/// Broader than baseline quality: key activities × phases, human language, phase tone.
final class CoachHumanLanguagePhaseMatrixTests: XCTestCase {

    private struct Case {
        let name: String
        let scenario: CoachScenarioKey
        let activityType: CoachActivityType
        let sessionPhase: CoachSessionPhase
        let activityState: CoachActivityState
        let timeOfDay: CoachTimeOfDay
        let durationBand: CoachDurationBand
        let isFocusHikeLike: Bool
        let focusDurationMinutes: Int
        let mustContainAnyEN: [String]
        let mustContainAnyRU: [String]
        let forbiddenEN: [String]
        let forbiddenRU: [String]
    }

    func testActivityPhaseMatrixQualityAndHumanLanguage() throws {
        for item in matrixCases() {
            let input = makeInput(for: item)
            let pack = try XCTUnwrap(
                CoachCopyRegistry.resolve(input),
                "Missing pack for \(item.name)"
            )

            let quality = CoachCopyQualityAudit.audit(pack: pack, input: input)
            XCTAssertTrue(
                quality.isClean,
                "\(item.name) quality: \(quality.violations.joined(separator: "; "))"
            )

            let language = CoachCopyLanguageAudit.audit(pack: pack)
            XCTAssertTrue(
                language.isClean,
                "\(item.name) language: \(language.findings.map { "\($0.section)/\($0.language): \($0.reason)" }.joined(separator: "; "))"
            )

            let english = joinedEnglish(pack).lowercased()
            let russian = joinedRussian(pack).lowercased()

            if !item.mustContainAnyEN.isEmpty {
                XCTAssertTrue(
                    item.mustContainAnyEN.contains { english.contains($0.lowercased()) },
                    "\(item.name) missing expected EN cue from \(item.mustContainAnyEN); got: \(english)"
                )
            }
            if !item.mustContainAnyRU.isEmpty {
                XCTAssertTrue(
                    item.mustContainAnyRU.contains { russian.contains($0.lowercased()) },
                    "\(item.name) missing expected RU cue from \(item.mustContainAnyRU); got: \(russian)"
                )
            }

            for phrase in item.forbiddenEN {
                XCTAssertFalse(
                    english.contains(phrase.lowercased()),
                    "\(item.name) unexpected EN '\(phrase)' in: \(english)"
                )
            }
            for phrase in item.forbiddenRU {
                XCTAssertFalse(
                    russian.contains(phrase.lowercased()),
                    "\(item.name) unexpected RU '\(phrase)' in: \(russian)"
                )
            }

            assertHumanRussian(russian, caseName: item.name)
        }
    }

    func testAllBaselinePacksUseHumanRussianVoice() throws {
        for scenario in CoachScenarioKey.allCases {
            let input = CoachCopyQualityTests.baselineInput(for: scenario)
            let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input), scenario.rawValue)
            assertHumanRussian(joinedRussian(pack).lowercased(), caseName: scenario.rawValue)
        }
    }

    // MARK: - Matrix

    private func matrixCases() -> [Case] {
        [
            // Swim
            Case(
                name: "swim.pre",
                scenario: .activeEndurance,
                activityType: .swimming,
                sessionPhase: .pre,
                activityState: .upcoming,
                timeOfDay: .morning,
                durationBand: .medium,
                isFocusHikeLike: false,
                focusDurationMinutes: 45,
                mustContainAnyEN: ["swim is ahead", "swim is coming"],
                mustContainAnyRU: ["заплыв впереди"],
                forbiddenEN: ["swim is done", "swim is banked"],
                forbiddenRU: ["заплыв позади", "заплыв сделан"]
            ),
            Case(
                name: "swim.during",
                scenario: .duringEndurance,
                activityType: .swimming,
                sessionPhase: .during,
                activityState: .active,
                timeOfDay: .morning,
                durationBand: .medium,
                isFocusHikeLike: false,
                focusDurationMinutes: 45,
                mustContainAnyEN: ["swim", "water", "stroke", "lap"],
                mustContainAnyRU: ["плав", "заплыв", "воде", "греб", "бассейн"],
                forbiddenEN: ["swim is ahead", "swim is done", "soft start after short sleep"],
                forbiddenRU: ["заплыв впереди", "заплыв позади", "мягкий вход"]
            ),
            Case(
                name: "swim.post",
                scenario: .postEnduranceImmediate,
                activityType: .swimming,
                sessionPhase: .immediatePost,
                activityState: .justFinished,
                timeOfDay: .afternoon,
                durationBand: .medium,
                isFocusHikeLike: false,
                focusDurationMinutes: 45,
                mustContainAnyEN: ["swim is done"],
                mustContainAnyRU: ["заплыв позади"],
                forbiddenEN: ["swim is ahead", "ease in"],
                forbiddenRU: ["заплыв впереди"]
            ),

            // Tennis
            Case(
                name: "tennis.pre",
                scenario: .activeRacket,
                activityType: .tennis,
                sessionPhase: .pre,
                activityState: .upcoming,
                timeOfDay: .afternoon,
                durationBand: .medium,
                isFocusHikeLike: false,
                focusDurationMinutes: 60,
                mustContainAnyEN: ["match is close", "court"],
                mustContainAnyRU: ["игра", "корт"],
                forbiddenEN: ["match over", "court work is done"],
                forbiddenRU: ["игра позади", "корт позади"]
            ),
            Case(
                name: "tennis.during",
                scenario: .duringRacket,
                activityType: .tennis,
                sessionPhase: .during,
                activityState: .active,
                timeOfDay: .afternoon,
                durationBand: .medium,
                isFocusHikeLike: false,
                focusDurationMinutes: 60,
                mustContainAnyEN: ["point", "rally", "match", "court"],
                mustContainAnyRU: ["очк", "розыгрыш", "игр", "корт"],
                forbiddenEN: ["match is close", "match over", "first games at half speed"],
                forbiddenRU: ["игра скоро", "игра позади"]
            ),
            Case(
                name: "tennis.post",
                scenario: .postRacketImmediate,
                activityType: .tennis,
                sessionPhase: .immediatePost,
                activityState: .justFinished,
                timeOfDay: .afternoon,
                durationBand: .medium,
                isFocusHikeLike: false,
                focusDurationMinutes: 60,
                mustContainAnyEN: ["match over"],
                mustContainAnyRU: ["игра позади"],
                forbiddenEN: ["match is close", "extra five minutes warm-up"],
                forbiddenRU: ["игра скоро"]
            ),

            // Easy walk
            Case(
                name: "walk.pre",
                scenario: .walkLightDay,
                activityType: .walk,
                sessionPhase: .pre,
                activityState: .upcoming,
                timeOfDay: .morning,
                durationBand: .short,
                isFocusHikeLike: false,
                focusDurationMinutes: 25,
                mustContainAnyEN: ["walk", "easy"],
                mustContainAnyRU: ["прогулк"],
                forbiddenEN: ["walk completed", "walk has already", "long hike done"],
                forbiddenRU: ["прогулка завершена", "прогулка уже", "хайкинг позади"]
            ),
            Case(
                name: "walk.during",
                scenario: .walkLightDay,
                activityType: .walk,
                sessionPhase: .during,
                activityState: .active,
                timeOfDay: .morning,
                durationBand: .short,
                isFocusHikeLike: false,
                focusDurationMinutes: 25,
                mustContainAnyEN: ["walk"],
                mustContainAnyRU: ["прогулк"],
                forbiddenEN: ["soft start after short sleep", "twenty easy minutes", "walk is ahead"],
                forbiddenRU: ["мягкий вход", "двадцать минут легко", "прогулка впереди"]
            ),
            Case(
                name: "walk.post",
                scenario: .walkLightDay,
                activityType: .walk,
                sessionPhase: .immediatePost,
                activityState: .justFinished,
                timeOfDay: .afternoon,
                durationBand: .short,
                isFocusHikeLike: false,
                focusDurationMinutes: 25,
                mustContainAnyEN: ["walk has already", "already helped"],
                mustContainAnyRU: ["прогулка уже"],
                forbiddenEN: ["soft start after short sleep", "twenty easy minutes", "keep it conversational"],
                forbiddenRU: ["мягкий вход", "двадцать минут", "разговорным"]
            ),

            // Substantial hike
            Case(
                name: "hike.pre",
                scenario: .walkLightDay,
                activityType: .walk,
                sessionPhase: .pre,
                activityState: .upcoming,
                timeOfDay: .morning,
                durationBand: .extended,
                isFocusHikeLike: true,
                focusDurationMinutes: 180,
                mustContainAnyEN: ["hike"],
                mustContainAnyRU: ["хайкинг"],
                forbiddenEN: ["long hike done", "protect the second half now"],
                forbiddenRU: ["хайкинг позади", "берегите вторую половину"]
            ),
            Case(
                name: "hike.during",
                scenario: .walkLightDay,
                activityType: .walk,
                sessionPhase: .during,
                activityState: .active,
                timeOfDay: .morning,
                durationBand: .extended,
                isFocusHikeLike: true,
                focusDurationMinutes: 180,
                mustContainAnyEN: ["hike"],
                mustContainAnyRU: ["хайкинг"],
                forbiddenEN: ["long hike done", "soft start after short sleep", "start even more conservatively"],
                forbiddenRU: ["хайкинг позади", "мягкий вход", "начните ещё консервативнее"]
            ),
            Case(
                name: "hike.post",
                scenario: .walkLightDay,
                activityType: .walk,
                sessionPhase: .immediatePost,
                activityState: .justFinished,
                timeOfDay: .afternoon,
                durationBand: .extended,
                isFocusHikeLike: true,
                focusDurationMinutes: 180,
                mustContainAnyEN: ["long hike done"],
                mustContainAnyRU: ["хайкинг позади"],
                forbiddenEN: ["start even more conservatively", "protect the second half", "soft start"],
                forbiddenRU: ["начните ещё консервативнее", "берегите вторую половину", "мягкий вход"]
            ),

            // Run (spot-check endurance family beyond swim)
            Case(
                name: "run.post",
                scenario: .postEnduranceImmediate,
                activityType: .running,
                sessionPhase: .immediatePost,
                activityState: .justFinished,
                timeOfDay: .afternoon,
                durationBand: .long,
                isFocusHikeLike: false,
                focusDurationMinutes: 50,
                mustContainAnyEN: ["run is done"],
                mustContainAnyRU: ["пробежка позади"],
                forbiddenEN: ["run is ahead"],
                forbiddenRU: ["пробежка впереди"]
            )
        ]
    }

    // MARK: - Human language

    private func assertHumanRussian(_ russian: String, caseName: String) {
        XCTAssertFalse(
            russian.contains("\\("),
            "\(caseName): unbroken string interpolation leak in: \(russian)"
        )
        XCTAssertFalse(
            russian.contains("завершён сделан"),
            "\(caseName): doubled completion verb in: \(russian)"
        )
        XCTAssertFalse(
            russian.contains("long бег") || russian.contains("long Бег"),
            "\(caseName): untranslated Long Run fragment in: \(russian)"
        )

        let informal = try! NSRegularExpression(
            pattern: #"(?<![А-Яа-яЁё])(ты|тебе|тебя|твой|твоя|твоё|твои)(?![А-Яа-яЁё])"#
        )
        let range = NSRange(russian.startIndex..., in: russian)
        XCTAssertEqual(
            informal.numberOfMatches(in: russian, range: range),
            0,
            "\(caseName): informal ты in rendered pack: \(russian)"
        )

        let calques = [
            "в приоритете",
            "восстановление отстаёт",
            "инсайт коуча",
            "коуч говорит",
            "жидкость",
            "потолок",
            "оставьте необязательную интенсивность"
        ]
        for phrase in calques {
            XCTAssertFalse(
                russian.contains(phrase),
                "\(caseName): calque/machine phrase '\(phrase)' in: \(russian)"
            )
        }
    }

    // MARK: - Helpers

    private func makeInput(for item: Case) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: 78,
            sleepHours: 6.5,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        return CoachCopyBuildInput(
            scenario: item.scenario,
            modifiers: CoachScenarioModifiers(
                dayLoad: item.sessionPhase == .pre ? .fresh : .moderate,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: item.activityType,
                durationBand: item.durationBand,
                completedSeriousActivities: item.sessionPhase == .immediatePost ? .one : .none,
                timeOfDay: item.timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .none
            ),
            athleteState: CoachAthleteStateResolver.resolve(dayReadiness: readiness),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: CoachPresentationResolver.semanticColor(for: item.scenario),
            alertSeverity: .none,
            tomorrowWorkout: nil,
            dayReadiness: readiness,
            focusSource: item.sessionPhase == .immediatePost ? .recentCompleted : .upcoming,
            sessionPhase: item.sessionPhase,
            activityState: item.activityState,
            isFocusHikeLike: item.isFocusHikeLike,
            focusDurationMinutes: item.focusDurationMinutes
        )
    }

    private func joinedEnglish(_ pack: CoachCopyPack) -> String {
        [pack.assessment, pack.recommendation, pack.avoid, pack.nextAction]
            .flatMap(\.lines)
            .map(\.english)
            .joined(separator: " ")
    }

    private func joinedRussian(_ pack: CoachCopyPack) -> String {
        [pack.assessment, pack.recommendation, pack.avoid, pack.nextAction]
            .flatMap(\.lines)
            .map(\.russian)
            .joined(separator: " ")
    }
}
