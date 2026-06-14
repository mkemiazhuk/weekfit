import XCTest
@testable import WeekFit

final class CoachStateNarrativeContractTests: XCTestCase {

    private let now = CoachTestClock.reference
    private var morning: Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testTodayAndCoachShareSelectedStoryColorAndIcon() throws {
        WeekFitSetCurrentLanguage(.english)
        let run = activity(
            type: "running",
            title: "Running",
            minutesFromNow: 45,
            duration: 60,
            icon: "figure.run"
        )

        let state = makeState(activities: [run])
        let coach = try XCTUnwrap(state.coachPresentation)
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertEqual(state.todayPresentation.title, story.title.resolved)
        XCTAssertEqual(coach.title, story.title.resolved)
        XCTAssertEqual(state.todayPresentation.icon, coach.icon)
        XCTAssertEqual(String(describing: state.todayPresentation.color), String(describing: coach.color))
        XCTAssertEqual(String(describing: coach.color), String(describing: story.color))
        XCTAssertNoDuplicateActions(coach.supportActions)
    }

    func testFinalStoryRenderModelMatchesTodayAndCoachVisibleContract() throws {
        WeekFitSetCurrentLanguage(.english)
        let run = activity(
            type: "running",
            title: "Running",
            minutesFromNow: 45,
            duration: 60,
            icon: "figure.run"
        )

        let state = makeState(activities: [run])
        let story = try XCTUnwrap(state.finalStory)
        let coach = try XCTUnwrap(state.coachPresentation)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertEqual(renderModel.owner, story.owner)
        XCTAssertEqual(renderModel.colorFamily, story.colorFamily)
        XCTAssertEqual(renderModel.badge, story.badgeState.resolved)
        XCTAssertEqual(renderModel.title, story.title.resolved)
        XCTAssertEqual(renderModel.subtitle, story.subtitle.resolved)
        XCTAssertEqual(renderModel.icon, story.icon)
        XCTAssertEqual(state.todayPresentation.title, renderModel.title)
        XCTAssertEqual(state.todayPresentation.message, renderModel.subtitle)
        XCTAssertEqual(state.todayPresentation.icon, renderModel.icon)
        XCTAssertEqual(coach.stateLabel, renderModel.badge)
        XCTAssertEqual(coach.title, renderModel.title)
        XCTAssertEqual(coach.message, renderModel.subtitle)
        XCTAssertEqual(coach.supportActions.map(\.title), renderModel.supportActions.map(\.title))
        XCTAssertEqual(String(describing: state.todayPresentation.color), String(describing: renderModel.color))
        XCTAssertEqual(String(describing: coach.color), String(describing: renderModel.color))
    }

    func testFinalStorySupportSignalsDoNotDuplicateHeroText() throws {
        WeekFitSetCurrentLanguage(.english)
        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0.5, calories: 700, protein: 20, carbs: 50)
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let heroTexts = [
            renderModel.title,
            renderModel.subtitle,
            renderModel.primaryRecommendation,
            renderModel.avoidRecommendation,
            renderModel.primaryActionTitle
        ].map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        XCTAssertFalse(renderModel.supportSignals.contains { signal in
            heroTexts.contains(signal.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        })
    }

    func testFinalStorySupportSignalsAreSpecificNotGeneric() throws {
        WeekFitSetCurrentLanguage(.english)
        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0.5, calories: 700, protein: 20, carbs: 50)
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertFalse(renderModel.supportSignals.isEmpty)
        XCTAssertFalse(renderModel.supportSignals.contains { signal in
            let title = signal.title.lowercased()
            return title.contains("supports this story") ||
                title.contains("supports this conclusion") ||
                title.contains("is part of the decision") ||
                title.contains("supports workout preparation") ||
                title.contains("supports preparation")
        })
        XCTAssertFalse(renderModel.supportSignals.contains { $0.title.count > 80 })
    }

    func testFinalStorySupportSignalsProvideDistinctEvidenceDomains() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: 60,
            duration: 120,
            icon: "bicycle"
        )

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 0.2, calories: 250, protein: 10, carbs: 20)
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let titles = renderModel.supportSignals.map { $0.title.lowercased() }

        XCTAssertEqual(Set(renderModel.supportSignals.map(\.kind)).count, renderModel.supportSignals.count)
        XCTAssertFalse(titles.contains { $0.contains("workout preparation") || $0.contains("recommendation") })
        if renderModel.supportSignals.contains(where: { $0.kind == .hydration }) {
            XCTAssertTrue(titles.contains { $0.contains("hydration") })
        }
        if renderModel.supportSignals.contains(where: { $0.kind == .fuel }) {
            XCTAssertTrue(titles.contains { $0.contains("nutrition") })
        }
    }

    func testHeavyWorkoutCompletedUsesConcreteRecoveryAction() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(
            type: "cycling",
            title: "Long cycling",
            minutesFromNow: -240,
            duration: 180,
            icon: "bicycle",
            completed: true
        )

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 0.4, calories: 900, protein: 20, carbs: 80),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 2_415,
            completedWorkoutsCount: 2,
            recoveryPercent: 90,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let next = story.whatToDoNext.resolved.lowercased()

        XCTAssertTrue(story.owner == .postActivityRecovery || story.owner == .recovery, "\(story.owner)")
        XCTAssertTrue(next.contains("protein") || next.contains("carbs") || next.contains("meal"), story.whatToDoNext.resolved)
        XCTAssertFalse(next.contains("rebuild the basics"), story.whatToDoNext.resolved)
    }

    func testSuccessfulCompletedEnduranceRecoveryPrioritizesTrainingLoad() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: -240,
            duration: 190,
            icon: "bicycle",
            completed: true
        )

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 3.75, calories: 3_257, protein: 232, carbs: 320),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 2_415,
            completedWorkoutsCount: 1,
            recoveryPercent: 90,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertEqual(story.title.resolved, "Protect today's work")
        XCTAssertEqual(story.whatHappened.resolved, "Today's main training work is complete.")
        XCTAssertEqual(story.whatMattersNow.resolved, "Recovery now depends mostly on the evening and sleep.")
        XCTAssertEqual(story.whatToDoNext.resolved, "Keep the evening easy, finish hydration gradually, and protect sleep.")
        XCTAssertEqual(story.whatToAvoid.resolved, "Do not turn the evening into another hard effort.")
        XCTAssertFalse((state.guidance?.screenStory?.primaryActions ?? []).contains { action in
            action.title.localizedCaseInsensitiveContains("Eat a normal meal with carbs and protein")
        })
        XCTAssertTrue(state.guidance?.priority.reasons.contains("RecoveryContributorDebug.activeContributors=[]") == true)
        XCTAssertTrue(state.guidance?.priority.reasons.contains("RecoveryContributorDebug.resolvedContributors=[]") == true)
        XCTAssertFalse(renderModel.supportSignals.contains { $0.kind == .hydration })
        XCTAssertFalse(renderModel.supportSignals.contains { $0.kind == .fuel })
        XCTAssertGreaterThanOrEqual(state.coachPresentation?.supportActions.count ?? 0, 2)
        XCTAssertFalse((state.coachPresentation?.supportActions ?? []).contains { action in
            action.title.localizedCaseInsensitiveContains("protein") ||
                action.title.localizedCaseInsensitiveContains("meal")
        })
    }

    func testRussianCompletedEnduranceRecoveryNarrativeIsWholeSentenceLocalized() throws {
        WeekFitSetCurrentLanguage(.russian)
        let ride = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: -240,
            duration: 190,
            icon: "bicycle",
            completed: true
        )

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 3.75, calories: 3_257, protein: 232, carbs: 320),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 2_415,
            completedWorkoutsCount: 1,
            recoveryPercent: 90,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let read = story.whatHappened.resolved

        XCTAssertNil(read.range(of: "[A-Za-z]", options: .regularExpression), read)
        XCTAssertTrue(read.contains("Главная тренировочная работа"), read)
        XCTAssertFalse(read.contains("session"), read)
        XCTAssertFalse(read.contains("main training load"), read)
    }

    func testCompletedLoadNoRemainingTrainingUsesEveningSleepRecoveryAction() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: -240,
            duration: 190,
            icon: "bicycle",
            completed: true
        )

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 3.75, calories: 3_257, protein: 232, carbs: 320),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 2_415,
            completedWorkoutsCount: 1,
            recoveryPercent: 90,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let primaryActionText = (state.guidance?.screenStory?.primaryActions.map(\.title).joined(separator: " ") ?? "")

        XCTAssertEqual(story.owner, .postActivityRecovery)
        XCTAssertEqual(story.whatHappened.resolved, "Today's main training work is complete.")
        XCTAssertEqual(story.whatMattersNow.resolved, "Recovery now depends mostly on the evening and sleep.")
        XCTAssertEqual(story.whatToDoNext.resolved, "Keep the evening easy, finish hydration gradually, and protect sleep.")
        XCTAssertEqual(story.whatToAvoid.resolved, "Do not turn the evening into another hard effort.")
        XCTAssertGreaterThanOrEqual(state.coachPresentation?.supportActions.count ?? 0, 2)
        XCTAssertTrue((state.coachPresentation?.supportActions ?? []).contains { action in
            action.type == .cooldown ||
                action.type == .lightRecoveryMovement ||
                action.type == .mobilityPrep ||
                action.type == .sleepPriority
        })
        XCTAssertFalse(primaryActionText.localizedCaseInsensitiveContains("skip extra training"), primaryActionText)
        XCTAssertTrue(
            primaryActionText.localizedCaseInsensitiveContains("evening") ||
                primaryActionText.localizedCaseInsensitiveContains("sleep") ||
                primaryActionText.localizedCaseInsensitiveContains("wind down"),
            primaryActionText
        )
    }

    func testPostWorkoutHydrationSupportIsConcreteWhenShown() throws {
        WeekFitSetCurrentLanguage(.english)
        let run = activity(
            type: "running",
            title: "Long run",
            minutesFromNow: -180,
            duration: 120,
            icon: "figure.run",
            completed: true
        )

        let state = makeState(
            activities: [run],
            nutrition: nutrition(water: 0.2, calories: 900, protein: 30, carbs: 90),
            activeCalories: 1_200,
            completedWorkoutsCount: 1,
            recoveryPercent: 88,
            sleepHours: 7.5
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        if let hydration = renderModel.supportSignals.first(where: { $0.kind == .hydration }) {
            let title = hydration.title.lowercased()
            XCTAssertTrue(title.contains("300") || title.contains("500") || title.contains("next hour"), hydration.title)
        }
    }

    func testUpcomingEnduranceWorkoutUsesConcreteHumanPrepStory() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(
            type: "cycling",
            title: "Ride",
            minutesFromNow: 16,
            duration: 120,
            icon: "bicycle"
        )

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 0, calories: 0, protein: 0, carbs: 0),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 90,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let next = story.whatToDoNext.resolved.lowercased()

        XCTAssertEqual(story.owner, .activityPreparation)
        XCTAssertTrue(story.whatHappened.resolved.lowercased().contains("long") || story.whatHappened.resolved.lowercased().contains("ride"), story.whatHappened.resolved)
        XCTAssertTrue(next.contains("carbs"), story.whatToDoNext.resolved)
        XCTAssertTrue(next.contains("drink") || next.contains("water"), story.whatToDoNext.resolved)
        XCTAssertTrue(next.contains("first 15 minutes"), story.whatToDoNext.resolved)
        XCTAssertTrue(story.whatToAvoid.resolved.lowercased().contains("first 15 minutes"), story.whatToAvoid.resolved)
    }

    func testStableDayDoesNotShowMildFoodWaterSupportRows() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 1.2, calories: 900, protein: 45, carbs: 85),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 90,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview || story.owner == .recovery, "\(story.owner)")
        XCTAssertFalse(renderModel.supportSignals.contains { $0.kind == .hydration })
        XCTAssertFalse(renderModel.supportSignals.contains { $0.kind == .fuel })
        XCTAssertEqual(story.whatToDoNext.resolved, "Stay with the plan.")
    }

    func testHumanizedSupportSignalsDoNotRepeatHeroOrGenericConclusion() throws {
        WeekFitSetCurrentLanguage(.english)
        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0, calories: 0, protein: 0, carbs: 0),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 90,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let heroTexts = [
            renderModel.title,
            renderModel.whatHappened,
            renderModel.whatMattersNow,
            renderModel.whatToDoNext,
            renderModel.whatToAvoid
        ].map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        XCTAssertEqual(Set(renderModel.supportSignals.map(\.kind)).count, renderModel.supportSignals.count)
        XCTAssertFalse(renderModel.supportSignals.contains { signal in
            let title = signal.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return heroTexts.contains(title) ||
                title.contains("supports this story") ||
                title.contains("supports this conclusion")
        })
    }

    func testMorningGoodSleepRecoveryNoWorkoutRendersStableReadiness() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 1.4, calories: 900, protein: 50, carbs: 90)
        )
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview, "\(story.owner)")
        XCTAssertTrue(story.colorFamily == .stable || story.colorFamily == .ready, "\(story.colorFamily)")
        XCTAssertNotEqual(story.colorFamily, .warning)
        XCTAssertFalse(story.supportSignals.contains { $0.kind == .hydration && story.owner == .hydration })
        XCTAssertFalse(story.supportSignals.contains { $0.kind == .fuel && story.owner == .fuel })
    }

    func testStrongRecoverySleepNoUpcomingWorkoutDoesNotPrepareForTraining() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 1.8, calories: 1_400, protein: 80, carbs: 150),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 90,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview || story.owner == .recovery, "\(story.owner)")
        XCTAssertNotEqual(story.owner, .activityPreparation)
        XCTAssertNotEqual(renderModel.badge, WeekFitLocalizedString("coach.final.badge.prepare"))
        XCTAssertNotEqual(renderModel.icon, "figure.cooldown")
        XCTAssertFalse(renderModel.title.localizedCaseInsensitiveContains("prepare"), renderModel.title)
        XCTAssertFalse(renderModel.title.localizedCaseInsensitiveContains("training"), renderModel.title)
        XCTAssertNotEqual(state.guidance?.priority.opportunity, .trainingOpportunity)
    }

    func testStrongRecoverySleepUpcomingWorkoutMayUsePreparationStory() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: 90,
            duration: 90,
            icon: "bicycle"
        )

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 1.8, calories: 1_400, protein: 80, carbs: 150),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 90,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertTrue(story.owner == .activityPreparation || story.owner == .readiness, "\(story.owner) \(story.primaryFocus)")
    }

    func testRecentLoadNoUpcomingWorkoutStaysReadinessNotPreparation() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 1.8, calories: 1_400, protein: 80, carbs: 150),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 320,
            completedWorkoutsCount: 2,
            recoveryPercent: 90,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview || story.owner == .recovery, "\(story.owner)")
        XCTAssertNotEqual(story.owner, .activityPreparation)
        XCTAssertFalse(renderModel.title.localizedCaseInsensitiveContains("prepare"), renderModel.title)
        XCTAssertFalse(renderModel.title.localizedCaseInsensitiveContains("training"), renderModel.title)
    }

    func testNoUpcomingWorkoutSupportSignalsDoNotImplyWorkoutPreparation() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0.5, calories: 700, protein: 20, carbs: 50),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 90,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertFalse(renderModel.supportSignals.contains { signal in
            let title = signal.title.lowercased()
            return title.contains("workout") || title.contains("training") || title.contains("preparation")
        })
    }

    func testNoUpcomingWorkoutWaterAndFoodBehindStaySupportOnly() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0, calories: 0, protein: 0, carbs: 0),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 90,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview || story.owner == .recovery, "\(story.owner)")
        XCTAssertNotEqual(story.owner, .hydration)
        XCTAssertNotEqual(story.owner, .fuel)
        XCTAssertNotEqual(story.owner, .activityPreparation)
        XCTAssertTrue(renderModel.supportSignals.contains { $0.kind == .hydration })
        XCTAssertTrue(renderModel.supportSignals.contains { $0.kind == .fuel })
        XCTAssertFalse(renderModel.title.localizedCaseInsensitiveContains("prepare"), renderModel.title)
    }

    func testUpcomingEnduranceWorkoutTimingOwnsWhileWaterAndFoodSupport() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: 16,
            duration: 120,
            icon: "bicycle"
        )

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 0, calories: 0, protein: 0, carbs: 0),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 90,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let priority = try XCTUnwrap(state.guidance?.priority)

        XCTAssertEqual(story.owner, .activityPreparation)
        XCTAssertEqual(priority.focus, .prepareForActivity)
        XCTAssertTrue(priority.reason.localizedCaseInsensitiveContains("preparation window"), priority.reason)
        XCTAssertFalse(priority.reason.localizedCaseInsensitiveContains("fuel"), priority.reason)
        XCTAssertFalse(priority.reason.localizedCaseInsensitiveContains("hydration"), priority.reason)
        XCTAssertTrue(renderModel.supportSignals.contains { $0.kind == .hydration })
        XCTAssertTrue(renderModel.supportSignals.contains { $0.kind == .fuel })
    }

    func testSaunaSoonWithSevereHydrationMayInfluenceOwner() throws {
        WeekFitSetCurrentLanguage(.english)
        let sauna = activity(
            type: "sauna",
            title: "Sauna",
            minutesFromNow: 16,
            duration: 30,
            icon: "flame.fill"
        )

        let state = makeState(
            activities: [sauna],
            nutrition: nutrition(water: 0, calories: 1_200, protein: 60, carbs: 120),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 90,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertTrue(story.owner == .hydration || story.owner == .activityPreparation, "\(story.owner)")
    }

    func testStableDayMildHydrationFuelGapDoesNotChangeOwner() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 1.2, calories: 900, protein: 45, carbs: 85),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 90,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview || story.owner == .recovery, "\(story.owner)")
        XCTAssertNotEqual(story.owner, .hydration)
        XCTAssertNotEqual(story.owner, .fuel)
        XCTAssertNotEqual(story.owner, .activityPreparation)
        XCTAssertNotEqual(story.colorFamily, .warning)
        XCTAssertFalse(renderModel.title.localizedCaseInsensitiveContains("prepare"), renderModel.title)
    }

    func testLowMorningHydrationDoesNotHijackMainStoryWithoutActivity() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0, calories: 900, protein: 40, carbs: 90)
        )
        let coach = try XCTUnwrap(state.coachPresentation)
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertNotEqual(story.owner, .hydration)
        XCTAssertFalse(coach.title.localizedCaseInsensitiveContains("hydration"), coach.title)
        XCTAssertFalse(coach.title.localizedCaseInsensitiveContains("water"), coach.title)
        XCTAssertFalse(state.todayPresentation.title.localizedCaseInsensitiveContains("hydration"), state.todayPresentation.title)
        XCTAssertNoDuplicateActions(coach.supportActions)
    }

    func testHydrationSupportSignalUsesHydrationStyleWithoutOwningHero() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0.5, calories: 900, protein: 40, carbs: 90)
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let hydrationSignal = try XCTUnwrap(renderModel.supportSignals.first { $0.kind == .hydration })

        XCTAssertNotEqual(renderModel.owner, .hydration)
        XCTAssertEqual(renderModel.colorFamily, story.colorFamily)
        XCTAssertEqual(hydrationSignal.colorFamily, .hydration)
    }

    func testFuelSupportSignalUsesFuelStyleWithoutOwningHero() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: 60,
            duration: 120,
            icon: "bicycle"
        )

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 1.8, calories: 600, protein: 20, carbs: 45)
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let fuelSignal = try XCTUnwrap(renderModel.supportSignals.first { $0.kind == .fuel })

        XCTAssertNotEqual(renderModel.owner, .fuel)
        XCTAssertEqual(renderModel.colorFamily, story.colorFamily)
        XCTAssertEqual(fuelSignal.colorFamily, .fuel)
    }

    func testSevereHydrationWithSaunaSoonCanOwnHeroConsistently() throws {
        WeekFitSetCurrentLanguage(.english)
        let sauna = activity(
            type: "sauna",
            title: "Sauna",
            minutesFromNow: 45,
            duration: 30,
            icon: "flame.fill"
        )

        let state = makeState(
            activities: [sauna],
            nutrition: nutrition(water: 0, calories: 1_100, protein: 60, carbs: 120)
        )
        let story = try XCTUnwrap(state.finalStory)
        let coach = try XCTUnwrap(state.coachPresentation)

        XCTAssertTrue(story.owner == .hydration || story.owner == .activityPreparation, "\(story.owner)")
        XCTAssertTrue(story.colorFamily == .hydration || story.colorFamily == .warning || story.colorFamily == .activity, "\(story.colorFamily)")
        XCTAssertEqual(String(describing: state.todayPresentation.color), String(describing: story.color))
        XCTAssertEqual(String(describing: coach.color), String(describing: story.color))
    }

    func testUpcomingWorkoutOwnsStoryWhileFoodAndWaterStaySupport() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: 60,
            duration: 120,
            icon: "bicycle"
        )

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 0.2, calories: 250, protein: 10, carbs: 20)
        )
        let coach = try XCTUnwrap(state.coachPresentation)
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertEqual(coach.title, renderModel.title)
        XCTAssertEqual(coach.message, renderModel.subtitle)
        XCTAssertFalse(coach.title.localizedCaseInsensitiveContains("water"), coach.title)
        XCTAssertFalse(coach.title.localizedCaseInsensitiveContains("food"), coach.title)
        if story.owner != .hydration {
            XCTAssertTrue(renderModel.supportSignals.contains { $0.kind == .hydration })
        }
        if story.owner != .fuel {
            XCTAssertTrue(renderModel.supportSignals.contains { $0.kind == .fuel })
        }
        XCTAssertNoDuplicateActions(coach.supportActions)
    }

    func testActiveWorkoutOverridesSupportSignals() throws {
        WeekFitSetCurrentLanguage(.english)
        let strength = activity(
            type: "strength",
            title: "Strength",
            minutesFromNow: -10,
            duration: 60,
            icon: "dumbbell.fill"
        )
        strength.source = "today"

        let state = makeState(
            activities: [strength],
            nutrition: nutrition(water: 0, calories: 250, protein: 10, carbs: 20)
        )
        let coach = try XCTUnwrap(state.coachPresentation)

        XCTAssertFalse(coach.title.localizedCaseInsensitiveContains("water"), coach.title)
        XCTAssertFalse(coach.title.localizedCaseInsensitiveContains("food"), coach.title)
        XCTAssertNoDuplicateActions(coach.supportActions)
    }

    func testManualCyclingFreshDayUsesNormalActiveGuidance() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: -5,
            duration: 60,
            icon: "bicycle"
        )
        ride.source = "today"

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 1.8, calories: 1_400, protein: 80, carbs: 150),
            activeCalories: 180,
            completedWorkoutsCount: 0,
            recoveryPercent: 86,
            sleepHours: 7.6
        )
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertEqual(story.owner, .activeActivity)
        XCTAssertEqual(story.whatToDoNext.resolved, "Start easy, control effort, and stay aware.")
        XCTAssertFalse(story.whatHappened.resolved.localizedCaseInsensitiveContains("already did enough"), story.whatHappened.resolved)
        XCTAssertFalse(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("stop"), story.whatToDoNext.resolved)
    }

    func testManualCyclingAfterHugeDayPushesBack() throws {
        WeekFitSetCurrentLanguage(.english)
        let completedRide = activity(
            type: "cycling",
            title: "Long cycling",
            minutesFromNow: -240,
            duration: 190,
            icon: "bicycle",
            completed: true
        )
        let activeRide = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: -5,
            duration: 60,
            icon: "bicycle"
        )
        activeRide.source = "today"

        let state = makeState(
            activities: [completedRide, activeRide],
            nutrition: nutrition(water: 3.75, calories: 3_257, protein: 232, carbs: 320),
            activeCalories: 2_415,
            completedWorkoutsCount: 1,
            recoveryPercent: 90,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertEqual(story.owner, .activeActivity)
        XCTAssertEqual(story.title.resolved, "I would not continue today.")
        XCTAssertTrue(story.whatHappened.resolved.localizedCaseInsensitiveContains("already did enough"), story.whatHappened.resolved)
        XCTAssertTrue(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("end it") || story.whatToDoNext.resolved.localizedCaseInsensitiveContains("very easy"), story.whatToDoNext.resolved)
    }

    func testManualWalkAfterHeavyDayIsRecoveryOnly() throws {
        WeekFitSetCurrentLanguage(.english)
        let completedRide = activity(
            type: "cycling",
            title: "Long cycling",
            minutesFromNow: -240,
            duration: 190,
            icon: "bicycle",
            completed: true
        )
        let walk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: -5,
            duration: 30,
            icon: "figure.walk"
        )
        walk.source = "today"

        let state = makeState(
            activities: [completedRide, walk],
            nutrition: nutrition(water: 3.75, calories: 3_257, protein: 232, carbs: 320),
            activeCalories: 2_415,
            completedWorkoutsCount: 1,
            recoveryPercent: 90,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertEqual(story.owner, .activeActivity)
        XCTAssertEqual(story.title.resolved, "Use this only to cool down.")
        XCTAssertTrue(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("recovery"), story.whatToDoNext.resolved)
        XCTAssertTrue(story.whatToAvoid.resolved.localizedCaseInsensitiveContains("training"), story.whatToAvoid.resolved)
    }

    func testManualLateEveningActivityAfterHeavyDayProtectsSleep() throws {
        WeekFitSetCurrentLanguage(.english)
        let late = Calendar.current.date(bySettingHour: 21, minute: 30, second: 0, of: now) ?? now
        let completedRide = activity(
            type: "cycling",
            title: "Long cycling",
            minutesFromNow: -240,
            duration: 190,
            icon: "bicycle",
            completed: true,
            baseDate: late
        )
        let activeRide = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: -5,
            duration: 60,
            icon: "bicycle",
            baseDate: late
        )
        activeRide.source = "today"

        let state = makeState(
            activities: [completedRide, activeRide],
            currentDate: late,
            nutrition: nutrition(water: 3.75, calories: 3_257, protein: 232, carbs: 320),
            activeCalories: 2_415,
            completedWorkoutsCount: 1,
            recoveryPercent: 90,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertEqual(story.owner, .activeActivity)
        XCTAssertTrue(story.whatMattersNow.resolved.localizedCaseInsensitiveContains("sleep"), story.whatMattersNow.resolved)
        XCTAssertTrue(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("short") || story.whatToDoNext.resolved.localizedCaseInsensitiveContains("stop"), story.whatToDoNext.resolved)
        XCTAssertTrue(story.whatToAvoid.resolved.localizedCaseInsensitiveContains("late evening"), story.whatToAvoid.resolved)
    }

    func testActivePhaseCriticalReadinessOverrideChangesFinalVisibleStory() throws {
        WeekFitSetCurrentLanguage(.english)
        let completedRide = activity(
            type: "cycling",
            title: "Long cycling",
            minutesFromNow: -240,
            duration: 190,
            icon: "bicycle",
            completed: true
        )
        let activeStrength = activity(
            type: "strength",
            title: "Upper body",
            minutesFromNow: -5,
            duration: 60,
            icon: "dumbbell.fill"
        )
        activeStrength.source = "today"

        let nutrition = nutrition(water: 3.75, calories: 3_257, protein: 232, carbs: 320)
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = Calendar.current.component(.hour, from: now)
        brainConfig.hasAnyFoodLogged = true
        brainConfig.hydration = .optimal
        brainConfig.fuel = .good
        brainConfig.sleep = .okay
        brainConfig.recovery = .compromised
        brainConfig.readiness = .low
        brainConfig.completedWorkoutsCount = 1
        brainConfig.metrics = CoachMetricsBuilder.metrics(
            protein: nutrition.proteinCurrent,
            carbs: nutrition.carbsCurrent,
            calories: nutrition.caloriesCurrent,
            waterLiters: nutrition.waterCurrent,
            activeCalories: 1_650,
            sleepHours: 7.5
        )
        let brain = HumanBrainStateBuilder.make(brainConfig)
        let dayContext = CoachDayContextBuilder.build(
            activities: [completedRide],
            selectedDate: now,
            now: now
        )
        let input = CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: brain,
            plannedActivities: [completedRide],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 1_650,
                exerciseMinutes: 160,
                standHours: nil,
                activityGoalCalories: 1_000,
                activityProgress: 1.65
            ),
            dayContext: dayContext,
            recoveryContext: CoachRecoveryContext(recoveryPercent: 48, sleepHours: 7.5),
            nutritionContext: nutrition,
            source: "CoachStateNarrativeContractTests"
        )
        let priority = CoachDayPriorityResult(
            focus: .trainingReadinessWarning,
            level: .high,
            reason: "Recovery/readiness is low relative to the training demand today.",
            activity: activeStrength,
            overridesTimingFocus: true,
            priority: .planChallenge,
            strength: .critical,
            confidence: 0.92,
            mode: .warning,
            limiter: .trainingReadiness,
            todayTitle: "Control the session",
            todayMessage: "Use body feedback now",
            detailTitle: "Control the session",
            detailMessage: "Use body feedback now",
            reasons: ["trainingReadinessScore=164"]
        )
        let guidance = CoachGuidanceV3(
            phase: .active(activity: activeStrength, kind: .workout),
            opportunity: CoachSupportOpportunityV3(
                type: .activeWorkoutSupport,
                importance: .high,
                reason: "Active overload warning"
            ),
            priority: priority,
            shouldSurface: true,
            stateLabel: "LIVE",
            title: "Control the session",
            message: "Use body feedback now",
            insightTitle: "Control the session",
            insightSubtitle: "Use body feedback now",
            supportActions: [],
            avoidNotes: [],
            icon: "dumbbell.fill",
            color: WeekFitTheme.workout,
            importance: .high,
            tone: .supportive
        )

        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: guidance,
            createdAt: now
        )
        let story: CoachFinalStory = try XCTUnwrap(state.finalStory)
        let coach: CoachScreenPresentation = try XCTUnwrap(state.coachPresentation)

        XCTAssertEqual(story.owner, .activeActivity)
        XCTAssertEqual(story.colorFamily, .stress)
        XCTAssertEqual(coach.title, "I would not continue today.")
        XCTAssertEqual(story.whatToDoNext.resolved, "End it or keep it very easy.")
        XCTAssertFalse(coach.title.localizedCaseInsensitiveContains("control"), coach.title)
        XCTAssertFalse(visibleText(state).localizedCaseInsensitiveContains("use body feedback now"), visibleText(state))
    }

    func testDuplicateActiveCompletedStrengthResolvesToRecoveryWithSpecificActions() throws {
        WeekFitSetCurrentLanguage(.english)
        let completedStrength = activity(
            type: "strength",
            title: "Upper Body",
            minutesFromNow: -70,
            duration: 60,
            icon: "dumbbell.fill",
            completed: true
        )
        let duplicateActiveStrength = activity(
            type: "strength",
            title: "Upper Body",
            minutesFromNow: -70,
            duration: 60,
            icon: "dumbbell.fill"
        )
        duplicateActiveStrength.source = "today"

        let state = makeState(
            activities: [completedStrength, duplicateActiveStrength],
            nutrition: nutrition(water: 1.2, calories: 1_100, protein: 45, carbs: 120),
            sleepState: .short,
            recoveryState: .compromised,
            readinessState: .low,
            activeCalories: 1_650,
            completedWorkoutsCount: 2,
            recoveryPercent: 48,
            sleepHours: 6.0,
            exerciseMinutes: 150,
            activityProgress: 1.55
        )
        let story = try XCTUnwrap(state.finalStory)
        let actionTitles = (state.coachPresentation?.supportActions ?? []).map(\.title)
        let visibleActions = actionTitles.joined(separator: " | ")

        XCTAssertNotEqual(story.owner, .activeActivity)
        XCTAssertTrue(story.owner == .postActivityRecovery || story.owner == .recovery, "\(story.owner)")
        XCTAssertGreaterThanOrEqual(actionTitles.count, 3, visibleActions)
        XCTAssertTrue(visibleActions.localizedCaseInsensitiveContains("Protein feeding"), visibleActions)
        XCTAssertTrue(visibleActions.localizedCaseInsensitiveContains("Mobility"), visibleActions)
        XCTAssertTrue(visibleActions.localizedCaseInsensitiveContains("Cooldown"), visibleActions)
        XCTAssertFalse(visibleActions.localizedCaseInsensitiveContains("Stay relaxed"), visibleActions)
        XCTAssertFalse(visibleActions.localizedCaseInsensitiveContains("Slow down"), visibleActions)
        XCTAssertFalse(visibleActions.localizedCaseInsensitiveContains("Prepare for sleep"), visibleActions)
    }

    func testCoachHeroSemanticColorMatrix() throws {
        WeekFitSetCurrentLanguage(.english)
        let morning = date(hour: 8)
        let evening = date(hour: 19)
        let late = date(hour: 22)
        let upcomingStrength = activity(type: "strength", title: "Strength", minutesFromNow: 45, duration: 60, icon: "dumbbell.fill", baseDate: morning)
        let laterRun = activity(type: "running", title: "Run", minutesFromNow: 240, duration: 50, icon: "figure.run", baseDate: morning)
        let completedRide = activity(type: "cycling", title: "Long cycling", minutesFromNow: -240, duration: 190, icon: "bicycle", completed: true, baseDate: evening)
        let activeStrength = activity(type: "strength", title: "Upper body", minutesFromNow: -5, duration: 60, icon: "dumbbell.fill", baseDate: evening)
        activeStrength.source = "today"

        struct HeroColorCase {
            let name: String
            let state: CoachState
            let allowedFamilies: [CoachFinalStoryColorFamily]
            let forbiddenFamilies: [CoachFinalStoryColorFamily]
        }

        let cases: [HeroColorCase] = [
            HeroColorCase(
                name: "stable day",
                state: stateForHeroColor(
                    focus: .dailyOverview,
                    priority: .stable,
                    strength: .low,
                    mode: .reinforcement,
                    limiter: CoachLimiter.none,
                    date: morning
                ),
                allowedFamilies: [.stable],
                forbiddenFamilies: [.hydration, .fuel, .warning, .stress]
            ),
            HeroColorCase(
                name: "recovery needed",
                state: stateForHeroColor(
                    focus: .recoveryNeeded,
                    priority: .recovery,
                    strength: .high,
                    mode: .recovery,
                    limiter: .recovery,
                    date: evening,
                    recoveryPercent: 58
                ),
                allowedFamilies: [.recovery],
                forbiddenFamilies: [.stable, .activity, .hydration, .fuel]
            ),
            HeroColorCase(
                name: "post activity recovery",
                state: stateForHeroColor(
                    focus: .postActivityRecovery,
                    priority: .recovery,
                    strength: .high,
                    mode: .recovery,
                    limiter: .insufficientRecoveryTime,
                    date: evening,
                    activities: [completedRide],
                    activeCalories: 1_250,
                    exerciseMinutes: 160,
                    activityProgress: 1.35
                ),
                allowedFamilies: [.recovery],
                forbiddenFamilies: [.stable, .activity, .hydration, .fuel]
            ),
            HeroColorCase(
                name: "active workout",
                state: stateForHeroColor(
                    focus: .activeActivity,
                    priority: .activeSession,
                    strength: .medium,
                    mode: .execution,
                    limiter: .timing,
                    date: morning,
                    phase: .active(activity: upcomingStrength, kind: .workout),
                    activities: [upcomingStrength]
                ),
                allowedFamilies: [.activity],
                forbiddenFamilies: [.stable, .hydration, .fuel, .warning, .stress]
            ),
            HeroColorCase(
                name: "prepare for workout",
                state: stateForHeroColor(
                    focus: .prepareForActivity,
                    priority: .performance,
                    strength: .medium,
                    mode: .opportunity,
                    limiter: .timing,
                    date: morning,
                    activities: [upcomingStrength]
                ),
                allowedFamilies: [.activity],
                forbiddenFamilies: [.stable, .hydration, .fuel, .warning, .stress]
            ),
            HeroColorCase(
                name: "next activity later",
                state: stateForHeroColor(
                    focus: .nextActivityLater,
                    priority: .performance,
                    strength: .low,
                    mode: .opportunity,
                    limiter: .timing,
                    date: morning,
                    activities: [laterRun]
                ),
                allowedFamilies: [.activity],
                forbiddenFamilies: [.hydration, .fuel, .warning, .stress]
            ),
            HeroColorCase(
                name: "performance readiness",
                state: stateForHeroColor(
                    focus: .performanceReadiness,
                    priority: .performance,
                    strength: .medium,
                    mode: .opportunity,
                    limiter: .none,
                    date: morning
                ),
                allowedFamilies: [.ready],
                forbiddenFamilies: [.hydration, .fuel, .warning, .stress]
            ),
            HeroColorCase(
                name: "training readiness warning",
                state: stateForHeroColor(
                    focus: .trainingReadinessWarning,
                    priority: .planChallenge,
                    strength: .high,
                    mode: .warning,
                    limiter: .trainingReadiness,
                    date: morning,
                    activities: [upcomingStrength],
                    recoveryPercent: 52
                ),
                allowedFamilies: [.warning],
                forbiddenFamilies: [.stable, .activity, .hydration, .fuel]
            ),
            HeroColorCase(
                name: "tomorrow plan risk",
                state: stateForHeroColor(
                    focus: .tomorrowPlanRisk,
                    priority: .planChallenge,
                    strength: .high,
                    mode: .adjustment,
                    limiter: .upcomingTraining,
                    date: evening
                ),
                allowedFamilies: [.warning],
                forbiddenFamilies: [.stable, .activity, .hydration, .fuel]
            ),
            HeroColorCase(
                name: "hydration behind support only",
                state: stateForHeroColor(
                    focus: .hydrationBehind,
                    priority: .hydration,
                    strength: .medium,
                    mode: .reinforcement,
                    limiter: .hydration,
                    date: morning,
                    nutrition: nutrition(water: 0.55, calories: 900, protein: 50, carbs: 90)
                ),
                allowedFamilies: [.stable, .ready, .recovery],
                forbiddenFamilies: [.hydration, .fuel, .warning, .stress]
            ),
            HeroColorCase(
                name: "fuel behind support only",
                state: stateForHeroColor(
                    focus: .fuelBehind,
                    priority: .fueling,
                    strength: .medium,
                    mode: .reinforcement,
                    limiter: .fueling,
                    date: morning,
                    nutrition: nutrition(water: 1.5, calories: 380, protein: 18, carbs: 42)
                ),
                allowedFamilies: [.stable, .ready, .recovery],
                forbiddenFamilies: [.hydration, .fuel, .warning, .stress]
            ),
            HeroColorCase(
                name: "evening wind down",
                state: stateForHeroColor(
                    focus: .eveningWindDown,
                    priority: .sleepPreparation,
                    strength: .high,
                    mode: .recovery,
                    limiter: .sleep,
                    date: late,
                    recoveryPercent: 62,
                    sleepHours: 6.2
                ),
                allowedFamilies: [.recovery],
                forbiddenFamilies: [.stable, .activity, .hydration, .fuel]
            ),
            HeroColorCase(
                name: "high stress stop state",
                state: stateForHeroColor(
                    focus: .trainingReadinessWarning,
                    priority: .planChallenge,
                    strength: .critical,
                    mode: .warning,
                    limiter: .trainingReadiness,
                    date: evening,
                    phase: .active(activity: activeStrength, kind: .workout),
                    activities: [completedRide, activeStrength],
                    activeCalories: 1_650,
                    exerciseMinutes: 160,
                    activityProgress: 1.65,
                    recoveryPercent: 42
                ),
                allowedFamilies: [.stress],
                forbiddenFamilies: [.stable, .activity, .hydration, .fuel, .warning]
            )
        ]

        for scenario in cases {
            try XCTContext.runActivity(named: scenario.name) { _ in
                let story = try XCTUnwrap(scenario.state.finalStory)
                let renderModel = CoachFinalStoryRenderModel(story: story)
                let coach = try XCTUnwrap(scenario.state.coachPresentation)

                XCTAssertTrue(
                    scenario.allowedFamilies.contains(story.colorFamily),
                    "\(scenario.name) colorFamily=\(story.colorFamily)"
                )
                XCTAssertFalse(
                    scenario.forbiddenFamilies.contains(story.colorFamily),
                    "\(scenario.name) colorFamily=\(story.colorFamily)"
                )
                XCTAssertEqual(renderModel.colorFamily, story.colorFamily)
                XCTAssertEqual(String(describing: coach.color), String(describing: story.color))
                XCTAssertEqual(String(describing: renderModel.color), String(describing: story.color))
            }
        }
    }

    func testFullCoachEngineScenarioMatrixEnglish() throws {
        WeekFitSetCurrentLanguage(.english)

        for scenario in fullScenarioMatrix() {
            try XCTContext.runActivity(named: scenario.name) { _ in
                let state = scenario.makeState()
                try assertScenario(state, matches: scenario, language: .english)
                print(debugSnapshot(for: scenario.name, state: state))
            }
        }
    }

    func testFullCoachEngineScenarioMatrixRussianCopyDoesNotLeakRawEnglish() throws {
        WeekFitSetCurrentLanguage(.russian)

        for scenario in fullScenarioMatrix() {
            try XCTContext.runActivity(named: "\(scenario.name) RU") { _ in
                let state = scenario.makeState()
                try assertScenario(state, matches: scenario, language: .russian)
                let visible = visibleText(state).lowercased()
                XCTAssertFalse(visible.contains("today's"), visible)
                XCTAssertFalse(visible.contains("use body feedback"), visible)
                XCTAssertFalse(visible.contains("control the session"), visible)
                XCTAssertFalse(visible.contains("coach.final."), visible)
                print(debugSnapshot(for: "\(scenario.name) RU", state: state))
            }
        }
    }

    func testGoodRecoveryWithRecentLoadHasNoBadgeTitleActionColorMismatch() throws {
        WeekFitSetCurrentLanguage(.english)
        let completed = activity(
            type: "running",
            title: "Long run",
            minutesFromNow: -90,
            duration: 80,
            icon: "figure.run",
            completed: true
        )

        let state = makeState(activities: [completed])
        let story = try XCTUnwrap(state.finalStory)
        let coach = try XCTUnwrap(state.coachPresentation)

        XCTAssertEqual(coach.stateLabel, story.badgeState.resolved)
        XCTAssertEqual(coach.title, story.title.resolved)
        XCTAssertEqual(coach.supportActions.first?.title, story.primaryAction.title.resolved)
        XCTAssertEqual(String(describing: coach.color), String(describing: story.color))
        story.validateVisibleContract()
    }

    func testRussianCoachCopyDoesNotMixEnglishInPrimaryPresentation() throws {
        WeekFitSetCurrentLanguage(.russian)
        let sauna = activity(
            type: "sauna",
            title: "Sauna",
            minutesFromNow: 30,
            duration: 25,
            icon: "flame.fill"
        )

        let state = makeState(activities: [sauna])
        let story = try XCTUnwrap(state.finalStory)
        let visible = visibleText(state)

        XCTAssertNil(story.title.resolved.range(of: "[A-Za-z]", options: .regularExpression), story.title.resolved)
        XCTAssertNil(story.subtitle.resolved.range(of: "[A-Za-z]", options: .regularExpression), story.subtitle.resolved)
        XCTAssertNil(story.primaryRecommendation.resolved.range(of: "[A-Za-z]", options: .regularExpression), story.primaryRecommendation.resolved)
        XCTAssertNil(visible.range(of: "[A-Za-z]", options: .regularExpression), visible)
    }

    func testRussianFinalStoryAvoidAndSupportCopyDoesNotMixEnglish() throws {
        WeekFitSetCurrentLanguage(.russian)
        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0.5, calories: 700, protein: 20, carbs: 50)
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let visible = ([renderModel.avoidRecommendation] + renderModel.supportSignals.map(\.title))
            .joined(separator: " ")

        XCTAssertFalse(renderModel.supportSignals.isEmpty)
        XCTAssertNil(visible.range(of: "[A-Za-z]", options: .regularExpression), visible)
        XCTAssertFalse(visible.contains("coach.final."), visible)
    }

    private struct CoachScenarioFixture {
        let name: String
        let makeState: () -> CoachState
        let allowedOwners: [CoachFinalStoryOwner]
        let allowedFocuses: [CoachDayFocus]
        let requiredAnyText: [String]
        let forbiddenText: [String]
        let hydrationFuelMayOwn: Bool
    }

    private func fullScenarioMatrix() -> [CoachScenarioFixture] {
        let morningTime = date(hour: 8)
        let eveningTime = date(hour: 19)
        let lateTime = date(hour: 22)
        let tomorrowMorning = tomorrow(hour: 9)

        return [
            CoachScenarioFixture(
                name: "A1 morning good recovery no workout",
                makeState: { self.makeState(activities: [], currentDate: morningTime, nutrition: self.nutrition(water: 1.4, calories: 900, protein: 50, carbs: 90), sleepState: .strong, recoveryState: .strong, readinessState: .good, recoveryPercent: 92, sleepHours: 8.1) },
                allowedOwners: [.readiness, .stableOverview],
                allowedFocuses: [.dailyOverview, .performanceReadiness],
                requiredAnyText: ["body", "consistent", "plan", "calm"],
                forbiddenText: ["hydration first", "food first", "prepare for training"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "A2 morning low water no heat",
                makeState: { self.makeState(activities: [], currentDate: morningTime, nutrition: self.nutrition(water: 0.35, calories: 450, protein: 25, carbs: 55), sleepState: .strong, recoveryState: .strong, readinessState: .good, recoveryPercent: 90, sleepHours: 7.9) },
                allowedOwners: [.readiness, .stableOverview, .recovery],
                allowedFocuses: [.dailyOverview, .hydrationBehind, .performanceReadiness, .recoveryNeeded],
                requiredAnyText: [],
                forbiddenText: ["severe", "urgent", "danger"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "A3 morning poor sleep workout later",
                makeState: {
                    let run = self.activity(type: "running", title: "Run", minutesFromNow: 240, duration: 60, icon: "figure.run", baseDate: morningTime)
                    return self.makeState(activities: [run], currentDate: morningTime, nutrition: self.nutrition(water: 1.2, calories: 650, protein: 40, carbs: 90), sleepState: .short, recoveryState: .compromised, readinessState: .low, recoveryPercent: 55, sleepHours: 5.4)
                },
                allowedOwners: [.readiness, .activityPreparation, .tomorrowProtection],
                allowedFocuses: [.trainingReadinessWarning, .prepareForActivity, .nextActivityLater, .tomorrowPlanRisk],
                requiredAnyText: ["easy", "intensity", "readiness", "start"],
                forbiddenText: ["go harder", "push intensity"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "A4 morning long endurance later",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Long ride", minutesFromNow: 210, duration: 150, icon: "bicycle", baseDate: morningTime)
                    return self.makeState(activities: [ride], currentDate: morningTime, nutrition: self.nutrition(water: 1.3, calories: 700, protein: 35, carbs: 120), sleepState: .okay, recoveryState: .stable, readinessState: .good, recoveryPercent: 78, sleepHours: 7.1)
                },
                allowedOwners: [.activityPreparation, .readiness, .stableOverview],
                allowedFocuses: [.prepareForActivity, .nextActivityLater, .performanceReadiness, .dailyOverview],
                requiredAnyText: ["start", "easy", "controlled", "coming"],
                forbiddenText: ["hydration first", "food first"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "B1 endurance workout in 100 minutes",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Ride", minutesFromNow: 100, duration: 120, icon: "bicycle")
                    return self.makeState(activities: [ride], nutrition: self.nutrition(water: 1.7, calories: 1_000, protein: 55, carbs: 145), recoveryPercent: 82, sleepHours: 7.4)
                },
                allowedOwners: [.activityPreparation],
                allowedFocuses: [.prepareForActivity, .nextActivityLater],
                requiredAnyText: ["carbs", "drink", "start", "easy"],
                forbiddenText: [],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "B2 strength workout soon good recovery",
                makeState: {
                    let strength = self.activity(type: "strength", title: "Strength", minutesFromNow: 45, duration: 60, icon: "dumbbell.fill")
                    return self.makeState(activities: [strength], nutrition: self.nutrition(water: 1.8, calories: 1_300, protein: 90, carbs: 140), sleepState: .strong, recoveryState: .strong, readinessState: .good, recoveryPercent: 90, sleepHours: 8.0)
                },
                allowedOwners: [.activityPreparation],
                allowedFocuses: [.prepareForActivity, .nextActivityLater],
                requiredAnyText: ["start", "easy", "warm", "controlled"],
                forbiddenText: ["eat food", "drink water now"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "B3 workout soon severe hydration",
                makeState: {
                    let run = self.activity(type: "running", title: "Run", minutesFromNow: 45, duration: 75, icon: "figure.run")
                    return self.makeState(activities: [run], nutrition: self.nutrition(water: 0.05, calories: 1_200, protein: 70, carbs: 140), recoveryPercent: 80, sleepHours: 7.1)
                },
                allowedOwners: [.hydration, .activityPreparation],
                allowedFocuses: [.hydrationBehind, .prepareForActivity, .nextActivityLater],
                requiredAnyText: ["drink", "hydration", "water", "sip"],
                forbiddenText: ["catch up all at once"],
                hydrationFuelMayOwn: true
            ),
            CoachScenarioFixture(
                name: "B4 hard workout soon no food",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Ride", minutesFromNow: 50, duration: 120, icon: "bicycle")
                    return self.makeState(activities: [ride], nutrition: self.nutrition(water: 1.8, calories: 0, protein: 0, carbs: 0), recoveryPercent: 78, sleepHours: 7.0)
                },
                allowedOwners: [.fuel, .activityPreparation],
                allowedFocuses: [.fuelBehind, .prepareForActivity, .nextActivityLater],
                requiredAnyText: ["carbs", "fuel", "snack", "start"],
                forbiddenText: ["generic nutrition"],
                hydrationFuelMayOwn: true
            ),
            CoachScenarioFixture(
                name: "C1 fresh manual workout",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Cycling", minutesFromNow: -5, duration: 60, icon: "bicycle")
                    ride.source = "today"
                    return self.makeState(activities: [ride], nutrition: self.nutrition(water: 1.8, calories: 1_400, protein: 80, carbs: 150), activeCalories: 180, recoveryPercent: 86, sleepHours: 7.6)
                },
                allowedOwners: [.activeActivity],
                allowedFocuses: [.activeActivity],
                requiredAnyText: ["start easy", "control effort", "stay aware"],
                forbiddenText: ["i would not continue", "already did enough"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "C2 overload manual workout",
                makeState: {
                    let completed = self.activity(type: "cycling", title: "Long cycling", minutesFromNow: -240, duration: 190, icon: "bicycle", completed: true)
                    let active = self.activity(type: "cycling", title: "Cycling", minutesFromNow: -5, duration: 60, icon: "bicycle")
                    active.source = "today"
                    return self.makeState(activities: [completed, active], nutrition: self.nutrition(water: 3.7, calories: 3_200, protein: 210, carbs: 320), sleepState: .short, recoveryState: .compromised, readinessState: .low, activeCalories: 2_000, completedWorkoutsCount: 1, recoveryPercent: 50, sleepHours: 6.0, exerciseMinutes: 165, activityProgress: 1.65)
                },
                allowedOwners: [.activeActivity],
                allowedFocuses: [.activeActivity, .trainingReadinessWarning, .recoveryNeeded],
                requiredAnyText: ["not continue", "already did enough", "end it", "very easy"],
                forbiddenText: ["control the session", "use body feedback now"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "C3 recovery walk after heavy day",
                makeState: {
                    let completed = self.activity(type: "cycling", title: "Long cycling", minutesFromNow: -240, duration: 190, icon: "bicycle", completed: true)
                    let walk = self.activity(type: "walking", title: "Walk", minutesFromNow: -5, duration: 30, icon: "figure.walk")
                    walk.source = "today"
                    return self.makeState(activities: [completed, walk], nutrition: self.nutrition(water: 3.7, calories: 3_200, protein: 210, carbs: 320), activeCalories: 2_000, completedWorkoutsCount: 1, recoveryPercent: 75, sleepHours: 7.2, exerciseMinutes: 165, activityProgress: 1.65)
                },
                allowedOwners: [.activeActivity],
                allowedFocuses: [.activeActivity, .recoveryNeeded],
                requiredAnyText: ["cool down", "recovery", "easy"],
                forbiddenText: ["i would not continue"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "C4 late activity after high load",
                makeState: {
                    let completed = self.activity(type: "cycling", title: "Long cycling", minutesFromNow: -240, duration: 190, icon: "bicycle", completed: true, baseDate: lateTime)
                    let active = self.activity(type: "cycling", title: "Cycling", minutesFromNow: -5, duration: 60, icon: "bicycle", baseDate: lateTime)
                    active.source = "today"
                    return self.makeState(activities: [completed, active], currentDate: lateTime, nutrition: self.nutrition(water: 3.7, calories: 3_200, protein: 210, carbs: 320), activeCalories: 2_000, completedWorkoutsCount: 1, recoveryPercent: 75, sleepHours: 7.0, exerciseMinutes: 165, activityProgress: 1.65)
                },
                allowedOwners: [.activeActivity],
                allowedFocuses: [.activeActivity, .recoveryNeeded, .trainingReadinessWarning],
                requiredAnyText: ["sleep", "short", "stop"],
                forbiddenText: ["control the session"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "D1 long endurance just completed",
                makeState: {
                    let run = self.activity(type: "running", title: "Long run", minutesFromNow: -100, duration: 95, icon: "figure.run", completed: true)
                    return self.makeState(activities: [run], nutrition: self.nutrition(water: 1.0, calories: 1_200, protein: 45, carbs: 140), activeCalories: 1_100, completedWorkoutsCount: 1, recoveryPercent: 72, sleepHours: 7.0)
                },
                allowedOwners: [.postActivityRecovery, .recovery],
                allowedFocuses: [.postActivityRecovery, .recoveryNeeded, .eveningWindDown],
                requiredAnyText: ["recovery", "protein", "hydration", "sleep"],
                forbiddenText: ["prepare for training"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "D2 strength completed",
                makeState: {
                    let strength = self.activity(type: "strength", title: "Strength", minutesFromNow: -90, duration: 70, icon: "dumbbell.fill", completed: true)
                    return self.makeState(activities: [strength], nutrition: self.nutrition(water: 1.8, calories: 1_300, protein: 70, carbs: 120), activeCalories: 650, completedWorkoutsCount: 1, recoveryPercent: 80, sleepHours: 7.2)
                },
                allowedOwners: [.postActivityRecovery, .recovery],
                allowedFocuses: [.postActivityRecovery, .recoveryNeeded, .eveningWindDown],
                requiredAnyText: ["recovery", "protein", "mobility", "sleep"],
                forbiddenText: ["another hard strength"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "D3 easy walk completed",
                makeState: {
                    let walk = self.activity(type: "walking", title: "Walk", minutesFromNow: -50, duration: 30, icon: "figure.walk", completed: true)
                    return self.makeState(activities: [walk], nutrition: self.nutrition(water: 1.6, calories: 1_400, protein: 80, carbs: 150), activeCalories: 260, recoveryPercent: 82, sleepHours: 7.4)
                },
                allowedOwners: [.stableOverview, .readiness, .recovery, .postActivityRecovery],
                allowedFocuses: [.dailyOverview, .performanceReadiness, .postActivityRecovery, .recoveryNeeded],
                requiredAnyText: ["plan", "routine", "consistent", "recovery"],
                forbiddenText: ["i would not continue", "main training load"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "D4 heavy workout completed nutrition satisfied",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Cycling", minutesFromNow: -240, duration: 190, icon: "bicycle", completed: true)
                    return self.makeState(activities: [ride], nutrition: self.nutrition(water: 3.75, calories: 3_257, protein: 232, carbs: 320), sleepState: .strong, recoveryState: .strong, readinessState: .good, activeCalories: 2_415, completedWorkoutsCount: 1, recoveryPercent: 90, sleepHours: 8.0)
                },
                allowedOwners: [.postActivityRecovery, .recovery],
                allowedFocuses: [.postActivityRecovery, .recoveryNeeded, .eveningWindDown],
                requiredAnyText: ["evening", "sleep", "easy"],
                forbiddenText: ["eat a normal meal", "protein target"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "E1 evening heavy day complete no more activities",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Cycling", minutesFromNow: -240, duration: 190, icon: "bicycle", completed: true, baseDate: eveningTime)
                    return self.makeState(activities: [ride], currentDate: eveningTime, nutrition: self.nutrition(water: 3.0, calories: 2_800, protein: 180, carbs: 280), activeCalories: 2_000, completedWorkoutsCount: 1, recoveryPercent: 80, sleepHours: 7.0)
                },
                allowedOwners: [.postActivityRecovery, .recovery],
                allowedFocuses: [.postActivityRecovery, .recoveryNeeded, .eveningWindDown],
                requiredAnyText: ["evening", "sleep", "complete"],
                forbiddenText: ["prepare for training"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "E2 heavy day complete hard tomorrow",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Cycling", minutesFromNow: -240, duration: 190, icon: "bicycle", completed: true, baseDate: eveningTime)
                    let tomorrowRun = self.activity(type: "running", title: "Tomorrow run", minutesFromNow: 0, duration: 90, icon: "figure.run", baseDate: tomorrowMorning)
                    return self.makeState(activities: [ride, tomorrowRun], currentDate: eveningTime, nutrition: self.nutrition(water: 3.0, calories: 2_800, protein: 180, carbs: 280), activeCalories: 2_000, completedWorkoutsCount: 1, recoveryPercent: 75, sleepHours: 7.0)
                },
                allowedOwners: [.tomorrowProtection, .recovery, .postActivityRecovery],
                allowedFocuses: [.tomorrowPlanRisk, .recoveryNeeded, .postActivityRecovery, .eveningWindDown],
                requiredAnyText: ["sleep", "tomorrow", "evening", "recovery"],
                forbiddenText: ["go harder"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "E3 easy day complete",
                makeState: {
                    let walk = self.activity(type: "walking", title: "Walk", minutesFromNow: -80, duration: 25, icon: "figure.walk", completed: true, baseDate: eveningTime)
                    return self.makeState(activities: [walk], currentDate: eveningTime, nutrition: self.nutrition(water: 1.8, calories: 1_700, protein: 90, carbs: 170), activeCalories: 300, recoveryPercent: 84, sleepHours: 7.4)
                },
                allowedOwners: [.stableOverview, .readiness, .recovery],
                allowedFocuses: [.dailyOverview, .performanceReadiness, .recoveryNeeded, .eveningWindDown],
                requiredAnyText: ["routine", "calm", "consistent", "plan"],
                forbiddenText: ["critical", "i would not continue"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "E4 late night food water low no safety",
                makeState: { self.makeState(activities: [], currentDate: lateTime, nutrition: self.nutrition(water: 0.8, calories: 700, protein: 25, carbs: 70), recoveryPercent: 75, sleepHours: 7.0) },
                allowedOwners: [.stableOverview, .readiness, .recovery],
                allowedFocuses: [.dailyOverview, .recoveryNeeded, .eveningWindDown, .hydrationBehind, .fuelBehind],
                requiredAnyText: ["sleep", "evening", "calm", "routine"],
                forbiddenText: ["eat now", "drink 300"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "F1 high recovery no training",
                makeState: { self.makeState(activities: [], currentDate: morningTime, sleepState: .strong, recoveryState: .strong, readinessState: .good, recoveryPercent: 94, sleepHours: 8.2) },
                allowedOwners: [.readiness, .stableOverview],
                allowedFocuses: [.dailyOverview, .performanceReadiness],
                requiredAnyText: ["plan", "body", "consistent"],
                forbiddenText: ["prepare for training"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "F2 low recovery no training",
                makeState: { self.makeState(activities: [], currentDate: morningTime, nutrition: self.nutrition(water: 1.5, calories: 1_000, protein: 60, carbs: 110), sleepState: .short, recoveryState: .compromised, readinessState: .low, recoveryPercent: 42, sleepHours: 5.2) },
                allowedOwners: [.recovery, .readiness, .stableOverview],
                allowedFocuses: [.recoveryNeeded, .trainingReadinessWarning, .dailyOverview],
                requiredAnyText: ["recovery", "easy", "sleep", "stress"],
                forbiddenText: ["go harder"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "F3 good recovery high recent load",
                makeState: { self.makeState(activities: [], currentDate: morningTime, sleepState: .strong, recoveryState: .strong, readinessState: .good, activeCalories: 900, completedWorkoutsCount: 2, recoveryPercent: 90, sleepHours: 8.0) },
                allowedOwners: [.readiness, .recovery, .postActivityRecovery],
                allowedFocuses: [.performanceReadiness, .recoveryNeeded, .postActivityRecovery, .dailyOverview],
                requiredAnyText: ["controlled", "recovery", "plan", "intensity"],
                forbiddenText: ["go harder"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "F4 high recovery after heavy load",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Cycling", minutesFromNow: -240, duration: 190, icon: "bicycle", completed: true)
                    return self.makeState(activities: [ride], nutrition: self.nutrition(water: 3.0, calories: 2_900, protein: 190, carbs: 300), sleepState: .strong, recoveryState: .strong, readinessState: .good, activeCalories: 2_000, completedWorkoutsCount: 1, recoveryPercent: 92, sleepHours: 8.1)
                },
                allowedOwners: [.postActivityRecovery, .recovery],
                allowedFocuses: [.postActivityRecovery, .recoveryNeeded, .eveningWindDown],
                requiredAnyText: ["protect", "recovery", "sleep", "adaptation"],
                forbiddenText: ["go harder"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "G1 mild hydration stable day",
                makeState: { self.makeState(activities: [], currentDate: morningTime, nutrition: self.nutrition(water: 1.1, calories: 1_200, protein: 70, carbs: 130), recoveryPercent: 84, sleepHours: 7.3) },
                allowedOwners: [.readiness, .stableOverview, .recovery],
                allowedFocuses: [.dailyOverview, .performanceReadiness, .recoveryNeeded, .hydrationBehind],
                requiredAnyText: [],
                forbiddenText: ["hydration first", "urgent"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "G2 severe hydration sauna soon",
                makeState: {
                    let sauna = self.activity(type: "sauna", title: "Sauna", minutesFromNow: 45, duration: 30, icon: "flame.fill")
                    return self.makeState(activities: [sauna], nutrition: self.nutrition(water: 0, calories: 1_100, protein: 60, carbs: 120), recoveryPercent: 80, sleepHours: 7.1)
                },
                allowedOwners: [.hydration, .activityPreparation],
                allowedFocuses: [.hydrationBehind, .prepareForActivity, .nextActivityLater],
                requiredAnyText: ["water", "hydrate", "sauna", "heat"],
                forbiddenText: ["catch up all at once"],
                hydrationFuelMayOwn: true
            ),
            CoachScenarioFixture(
                name: "G3 food low morning no workout",
                makeState: { self.makeState(activities: [], currentDate: morningTime, nutrition: self.nutrition(water: 1.2, calories: 0, protein: 0, carbs: 0), recoveryPercent: 84, sleepHours: 7.4) },
                allowedOwners: [.readiness, .stableOverview, .recovery],
                allowedFocuses: [.dailyOverview, .fuelBehind, .performanceReadiness, .recoveryNeeded],
                requiredAnyText: [],
                forbiddenText: ["breakfast", "eat now", "food first"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "G4 hard workout soon no fuel",
                makeState: {
                    let run = self.activity(type: "running", title: "Long run", minutesFromNow: 45, duration: 100, icon: "figure.run")
                    return self.makeState(activities: [run], nutrition: self.nutrition(water: 1.8, calories: 0, protein: 0, carbs: 0), recoveryPercent: 80, sleepHours: 7.3)
                },
                allowedOwners: [.fuel, .activityPreparation],
                allowedFocuses: [.fuelBehind, .prepareForActivity, .nextActivityLater],
                requiredAnyText: ["carbs", "fuel", "light", "start"],
                forbiddenText: ["eat food"],
                hydrationFuelMayOwn: true
            ),
            CoachScenarioFixture(
                name: "G5 protein above target after workout",
                makeState: {
                    let strength = self.activity(type: "strength", title: "Strength", minutesFromNow: -90, duration: 70, icon: "dumbbell.fill", completed: true)
                    return self.makeState(activities: [strength], nutrition: self.nutrition(water: 2.5, calories: 2_700, protein: 220, carbs: 260), activeCalories: 800, completedWorkoutsCount: 1, recoveryPercent: 82, sleepHours: 7.2)
                },
                allowedOwners: [.postActivityRecovery, .recovery],
                allowedFocuses: [.postActivityRecovery, .recoveryNeeded, .eveningWindDown],
                requiredAnyText: ["sleep", "mobility", "recovery", "easy"],
                forbiddenText: ["protein target", "eat a normal meal"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "H1 no more today long ride tomorrow",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Tomorrow ride", minutesFromNow: 0, duration: 150, icon: "bicycle", baseDate: tomorrowMorning)
                    return self.makeState(activities: [ride], currentDate: eveningTime, nutrition: self.nutrition(water: 2.0, calories: 2_000, protein: 110, carbs: 220), recoveryPercent: 80, sleepHours: 7.0)
                },
                allowedOwners: [.tomorrowProtection, .readiness, .stableOverview, .activityPreparation],
                allowedFocuses: [.tomorrowPlanRisk, .dailyOverview, .nextActivityLater, .performanceReadiness],
                requiredAnyText: ["tomorrow", "sleep", "prepare", "plan"],
                forbiddenText: ["hydration first", "food first"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "H2 tomorrow sauna only",
                makeState: {
                    let sauna = self.activity(type: "sauna", title: "Tomorrow sauna", minutesFromNow: 0, duration: 30, icon: "flame.fill", baseDate: tomorrowMorning)
                    return self.makeState(activities: [sauna], currentDate: eveningTime, nutrition: self.nutrition(water: 2.0, calories: 2_000, protein: 110, carbs: 220), recoveryPercent: 80, sleepHours: 7.0)
                },
                allowedOwners: [.readiness, .stableOverview, .activityPreparation, .recovery],
                allowedFocuses: [.dailyOverview, .nextActivityLater, .performanceReadiness, .recoveryNeeded],
                requiredAnyText: ["plan", "sauna", "routine", "calm"],
                forbiddenText: ["hard workout", "training protection"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "H3 hard tomorrow plus today high load",
                makeState: {
                    let completed = self.activity(type: "cycling", title: "Cycling", minutesFromNow: -240, duration: 160, icon: "bicycle", completed: true, baseDate: eveningTime)
                    let tomorrowRun = self.activity(type: "running", title: "Tomorrow run", minutesFromNow: 0, duration: 100, icon: "figure.run", baseDate: tomorrowMorning)
                    return self.makeState(activities: [completed, tomorrowRun], currentDate: eveningTime, nutrition: self.nutrition(water: 2.5, calories: 2_600, protein: 160, carbs: 260), activeCalories: 1_500, completedWorkoutsCount: 1, recoveryPercent: 70, sleepHours: 6.8)
                },
                allowedOwners: [.tomorrowProtection, .recovery, .postActivityRecovery],
                allowedFocuses: [.tomorrowPlanRisk, .recoveryNeeded, .postActivityRecovery, .eveningWindDown],
                requiredAnyText: ["tomorrow", "sleep", "recovery", "extra"],
                forbiddenText: ["go harder"],
                hydrationFuelMayOwn: false
            )
        ]
    }

    private func assertScenario(
        _ state: CoachState,
        matches scenario: CoachScenarioFixture,
        language: AppLanguage
    ) throws {
        let story: CoachFinalStory = try XCTUnwrap(state.finalStory, scenario.name)
        let coach: CoachScreenPresentation = try XCTUnwrap(state.coachPresentation, scenario.name)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(state)
        let lowerVisible = visible.lowercased()

        XCTAssertTrue(scenario.allowedOwners.contains(story.owner), "\(scenario.name) owner=\(story.owner)")
        if !scenario.allowedFocuses.isEmpty {
            XCTAssertTrue(scenario.allowedFocuses.contains(story.primaryFocus), "\(scenario.name) focus=\(story.primaryFocus)")
        }

        XCTAssertEqual(state.todayPresentation.title, story.title.resolved, scenario.name)
        XCTAssertEqual(state.todayPresentation.message, story.subtitle.resolved, scenario.name)
        XCTAssertEqual(coach.title, story.title.resolved, scenario.name)
        XCTAssertEqual(coach.message, story.subtitle.resolved, scenario.name)
        XCTAssertEqual(coach.recommendation, story.primaryRecommendation.resolved, scenario.name)
        XCTAssertEqual(coach.supportActions.map(\.title), story.supportActions.map(\.title), scenario.name)
        XCTAssertEqual(renderModel.owner, story.owner, scenario.name)
        XCTAssertEqual(renderModel.colorFamily, story.colorFamily, scenario.name)
        XCTAssertEqual(renderModel.badge, story.badgeState.resolved, scenario.name)
        XCTAssertFalse(story.badgeState.resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, scenario.name)

        for field in [
            story.title.resolved,
            story.whatHappened.resolved,
            story.whatMattersNow.resolved,
            story.whatToDoNext.resolved,
            story.whatToAvoid.resolved
        ] {
            XCTAssertFalse(field.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, scenario.name)
            XCTAssertLessThanOrEqual(field.count, 180, "\(scenario.name) field too long: \(field)")
            XCTAssertFalse(field.contains("coach.final."), "\(scenario.name) raw key: \(field)")
        }

        XCTAssertFalse(coach.supportActions.isEmpty, "\(scenario.name) should have a useful primary support action")
        XCTAssertNoDuplicateActions(coach.supportActions)
        assertNoDuplicateHeroOrSupportCopy(story, scenarioName: scenario.name)
        assertSupportSignalsDoNotRepeatHero(story, scenarioName: scenario.name)

        if !scenario.hydrationFuelMayOwn {
            XCTAssertNotEqual(story.owner, .hydration, scenario.name)
            XCTAssertNotEqual(story.owner, .fuel, scenario.name)
        }

        if language == .english && !scenario.requiredAnyText.isEmpty {
            XCTAssertTrue(
                scenario.requiredAnyText.contains { lowerVisible.contains($0.lowercased()) },
                "\(scenario.name) missing one of \(scenario.requiredAnyText). Visible: \(visible)"
            )
        }

        if language == .english {
            for forbidden in scenario.forbiddenText {
                XCTAssertFalse(lowerVisible.contains(forbidden.lowercased()), "\(scenario.name) contains forbidden text '\(forbidden)': \(visible)")
            }
        }

        XCTAssertFalse(lowerVisible.contains("hydration supports this story"), scenario.name)
        XCTAssertFalse(lowerVisible.contains("fuel supports this story"), scenario.name)
        XCTAssertFalse(lowerVisible.contains("nutrition supports this story"), scenario.name)
        XCTAssertFalse(lowerVisible.contains("rebuild the basics"), scenario.name)

        if language == .russian {
            XCTAssertFalse(lowerVisible.contains("today's"), scenario.name)
            XCTAssertFalse(lowerVisible.contains(" session "), scenario.name)
            XCTAssertFalse(lowerVisible.contains(" workout "), scenario.name)
        }
    }

    private func assertNoDuplicateHeroOrSupportCopy(
        _ story: CoachFinalStory,
        scenarioName: String
    ) {
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let rows = [
            renderModel.title,
            renderModel.subtitle,
            renderModel.whatMattersNow,
            renderModel.primaryRecommendation,
            renderModel.avoidRecommendation
        ] + renderModel.supportSignals.map(\.title)

        let normalized = rows
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        XCTAssertEqual(Set(normalized).count, normalized.count, "\(scenarioName) duplicate copy rows: \(normalized)")
    }

    private func assertSupportSignalsDoNotRepeatHero(
        _ story: CoachFinalStory,
        scenarioName: String
    ) {
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let heroTexts = [
            renderModel.title,
            renderModel.subtitle,
            renderModel.whatMattersNow,
            renderModel.primaryRecommendation,
            renderModel.avoidRecommendation,
            renderModel.primaryActionTitle
        ].map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        XCTAssertFalse(renderModel.supportSignals.contains { signal in
            heroTexts.contains(signal.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }, "\(scenarioName) support signal repeats hero")
    }

    private func debugSnapshot(for scenarioName: String, state: CoachState) -> String {
        guard let story = state.finalStory else {
            return "[CoachScenario] \(scenarioName) finalStory=nil"
        }

        let input = state.input
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let activeContributors = state.guidance?.priority.reasons
            .first { $0.hasPrefix("RecoveryContributorDebug.activeContributors=") } ?? "RecoveryContributorDebug.activeContributors=[]"
        let resolvedContributors = state.guidance?.priority.reasons
            .first { $0.hasPrefix("RecoveryContributorDebug.resolvedContributors=") } ?? "RecoveryContributorDebug.resolvedContributors=[]"

        return """
        [CoachScenario] \(scenarioName)
        owner=\(story.owner) primaryFocus=\(story.primaryFocus) colorFamily=\(story.colorFamily) badge=\(story.badgeState.resolved)
        selectedActivity=\(state.guidance?.priority.activity?.title ?? "none")
        completedLoad=minutes:\(input?.dayContext.completedActivityVolumeMinutes ?? 0) stress:\(input?.dayContext.completedTrainingStressScore ?? 0) activeCalories:\(Int(input?.actualLoad.activeCalories ?? input?.brain.metrics.activeCalories ?? 0))
        upcoming=\(input?.dayContext.upcomingActivities.map(\.title).joined(separator: "|") ?? "none")
        recovery=\(input?.recoveryContext.recoveryPercent ?? 0) sleep=\(String(format: "%.1f", input?.recoveryContext.sleepHours ?? 0)) readiness=\(String(describing: input?.brain.readiness))
        hydration=\(String(format: "%.2f", input?.nutritionContext?.waterCurrent ?? 0))/\(String(format: "%.2f", input?.nutritionContext?.waterGoal ?? 0)) nutrition=cal:\(Int(input?.nutritionContext?.caloriesCurrent ?? 0)) protein:\(Int(input?.nutritionContext?.proteinCurrent ?? 0))
        \(activeContributors)
        \(resolvedContributors)
        supportActions=\(state.coachPresentation?.supportActions.map(\.title).joined(separator: "|") ?? "none")
        supportSignals=\(renderModel.supportSignals.map { "\($0.kind):\($0.title)" }.joined(separator: "|"))
        title=\(story.title.resolved)
        whatHappened=\(story.whatHappened.resolved)
        whatMattersNow=\(story.whatMattersNow.resolved)
        whatToDoNext=\(story.whatToDoNext.resolved)
        whatToAvoid=\(story.whatToAvoid.resolved)
        """
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }

    private func tomorrow(hour: Int, minute: Int = 0) -> Date {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow) ?? tomorrow
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
        brainConfig.nextWorkout = activities.first
        brainConfig.hoursToNextWorkout = activities.first.map { max(0, $0.date.timeIntervalSince(decisionDate) / 3600) }
        brainConfig.hydration = nutrition.waterCurrent <= 0.1 ? .depleted : .optimal
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
            source: "CoachStateNarrativeContractTests"
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

    private func stateForHeroColor(
        focus: CoachDayFocus,
        priority: CoachDayPriority,
        strength: CoachPriorityStrength,
        mode: CoachingMode,
        limiter: CoachLimiter,
        date: Date,
        phase: CoachActivityPhaseV3? = nil,
        activities: [PlannedActivity] = [],
        nutrition: CoachNutritionContext? = nil,
        activeCalories: Double = 180,
        exerciseMinutes: Int? = nil,
        activityProgress: Double? = nil,
        recoveryPercent: Int = 82,
        sleepHours: Double = 7.4
    ) -> CoachState {
        let resolvedNutrition = nutrition ?? self.nutrition(water: 1.6, calories: 1_400, protein: 80, carbs: 150)
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = Calendar.current.component(.hour, from: date)
        brainConfig.hasAnyFoodLogged = resolvedNutrition.caloriesCurrent > 0
        brainConfig.hydration = resolvedNutrition.waterCurrent < 0.7 ? .behind : .optimal
        brainConfig.fuel = resolvedNutrition.caloriesCurrent < 500 ? .underfueled : .good
        brainConfig.sleep = sleepHours < 6.5 ? .short : .strong
        brainConfig.recovery = recoveryPercent < 55 ? .compromised : .strong
        brainConfig.readiness = recoveryPercent < 55 ? .low : .good
        brainConfig.completedWorkoutsCount = activities.filter(\.isCompleted).count
        brainConfig.metrics = CoachMetricsBuilder.metrics(
            protein: resolvedNutrition.proteinCurrent,
            carbs: resolvedNutrition.carbsCurrent,
            calories: resolvedNutrition.caloriesCurrent,
            waterLiters: resolvedNutrition.waterCurrent,
            activeCalories: activeCalories,
            sleepHours: sleepHours
        )
        let brain = HumanBrainStateBuilder.make(brainConfig)
        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: date,
            now: date
        )
        let input = CoachInputSnapshot(
            selectedDate: date,
            now: date,
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
            nutritionContext: resolvedNutrition,
            source: "CoachHeroSemanticColorMatrix"
        )
        let activity = activityForPriority(focus: focus, phase: phase, activities: activities)
        let priorityResult = CoachDayPriorityResult(
            focus: focus,
            level: strength.level,
            reason: "Hero semantic color matrix",
            activity: activity,
            overridesTimingFocus: true,
            priority: priority,
            strength: strength,
            confidence: 0.90,
            mode: mode,
            limiter: limiter,
            todayTitle: "Hero color matrix",
            todayMessage: "Hero color matrix message",
            detailTitle: "Hero color matrix",
            detailMessage: "Hero color matrix message",
            reasons: ["heroColorMatrix"]
        )
        let resolvedPhase = phase ?? CoachActivityContextResolverV3.resolve(
            brain: brain,
            activities: activities,
            selectedDate: date,
            now: date
        )
        let guidance = CoachGuidanceV3(
            phase: resolvedPhase,
            opportunity: CoachSupportOpportunityV3(
                type: focus == .activeActivity ? .activeWorkoutSupport : .stable,
                importance: strength == .critical ? .high : .important,
                reason: "Hero semantic color matrix"
            ),
            priority: priorityResult,
            shouldSurface: true,
            stateLabel: "MATRIX",
            title: "Hero color matrix",
            message: "Hero color matrix message",
            insightTitle: "Hero color matrix",
            insightSubtitle: "Hero color matrix message",
            supportActions: [],
            avoidNotes: [],
            icon: activity?.icon ?? "sparkles",
            color: CoachPalette.accent(for: priorityResult),
            importance: strength == .critical ? .high : .important,
            tone: mode == .warning ? .supportive : .calm
        )

        return CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: guidance,
            createdAt: date
        )
    }

    private func activityForPriority(
        focus: CoachDayFocus,
        phase: CoachActivityPhaseV3?,
        activities: [PlannedActivity]
    ) -> PlannedActivity? {
        if case .active(let activity, _) = phase {
            return activity
        }
        return activities.first { !$0.isCompleted && !$0.isSkipped } ?? activities.first
    }

    private func activity(
        type: String,
        title: String,
        minutesFromNow: Int,
        duration: Int,
        icon: String,
        completed: Bool = false,
        baseDate: Date? = nil
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
            source: "planner"
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

    private func visibleText(_ state: CoachState) -> String {
        let coach = state.coachPresentation
        return ([
            state.todayPresentation.title,
            state.todayPresentation.message,
            coach?.stateLabel,
            coach?.title,
            coach?.message,
            coach?.recommendation
        ] + (coach?.supportActions.flatMap { [$0.title, $0.subtitle] } ?? []) + (coach?.avoidNotes ?? []))
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private func XCTAssertNoDuplicateActions(
        _ actions: [CoachSupportActionV3],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let keys = actions.map { "\($0.type)-\($0.title.lowercased())" }
        XCTAssertEqual(Set(keys).count, keys.count, "actions=\(actions.map(\.title))", file: file, line: line)
    }
}
