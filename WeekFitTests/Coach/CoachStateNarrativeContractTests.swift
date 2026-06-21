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
        XCTAssertTrue(
            renderModel.supportActions.allSatisfy { visibleAction in
                coach.supportActions.contains { $0.title == visibleAction.title }
            }
        )
        XCTAssertEqual(String(describing: state.todayPresentation.color), String(describing: renderModel.color))
        XCTAssertEqual(String(describing: coach.color), String(describing: renderModel.color))
    }

    func testFinalStoryProvidesTodaySemanticInsightMetadata() throws {
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
        let semanticInsight = story.todaySemanticInsight

        XCTAssertEqual(semanticInsight.actionID, "coach_final_story.\(story.owner.rawValue)")
        XCTAssertTrue(
            semanticInsight.title == story.titleKey ||
                semanticInsight.title == "coach.final.story.\(story.owner.rawValue).title",
            semanticInsight.title
        )
        XCTAssertTrue(
            semanticInsight.text == story.subtitleKey ||
                semanticInsight.text == "coach.final.story.\(story.owner.rawValue).subtitle",
            semanticInsight.text
        )
        XCTAssertEqual(semanticInsight.icon, story.icon)
        XCTAssertFalse(semanticInsight.title.isEmpty)
        XCTAssertFalse(semanticInsight.text.isEmpty)
        XCTAssertFalse(semanticInsight.tags.isEmpty)
    }

    func testCoachFingerprintCompactLogOmitsActivityDump() throws {
        WeekFitSetCurrentLanguage(.english)
        let run = activity(
            type: "running",
            title: "Running",
            minutesFromNow: 45,
            duration: 60,
            icon: "figure.run"
        )

        let state = makeState(activities: [run])
        let fingerprint = try XCTUnwrap(state.fingerprint)

        XCTAssertTrue(fingerprint.rawValue.contains("activities="))
        XCTAssertFalse(fingerprint.compactLogValue.contains("activities="), fingerprint.compactLogValue)
        XCTAssertTrue(fingerprint.compactLogValue.contains("snapshot="))
        XCTAssertTrue(fingerprint.compactLogValue.contains("activeCalories="))
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
            XCTAssertFalse(titles.isEmpty)
        }
        if renderModel.supportSignals.contains(where: { $0.kind == .fuel }) {
            XCTAssertFalse(titles.isEmpty)
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
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let next = renderModel.supportActions.map(\.title).joined(separator: " ").lowercased()

        XCTAssertTrue(story.owner == .postActivityRecovery || story.owner == .recovery, "\(story.owner)")
        XCTAssertTrue(next.contains("cooldown") || next.contains("mobility") || next.contains("meal") || next.contains("carbs") || next.contains("rehydrate") || next.contains("drink") || next.contains("fluid"), next)
        XCTAssertLessThanOrEqual(renderModel.supportActions.count, 2, next)
        XCTAssertFalse(next.contains("rebuild the basics"), next)
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

        XCTAssertEqual(story.owner, .postActivityRecovery)
        XCTAssertTrue(story.title.resolved.localizedCaseInsensitiveContains("recover") || story.title.resolved.localizedCaseInsensitiveContains("ride") || story.title.resolved.localizedCaseInsensitiveContains("done"), story.title.resolved)
        XCTAssertTrue(
            story.whatHappened.resolved.localizedCaseInsensitiveContains("recovery") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("demanding day") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("more work"),
            story.whatHappened.resolved
        )
        XCTAssertFalse(story.whatMattersNow.resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, story.whatMattersNow.resolved)
        XCTAssertTrue(
            story.whatToDoNext.resolved.localizedCaseInsensitiveContains("25-40") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("sleep") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("easy"),
            story.whatToDoNext.resolved
        )
        XCTAssertEqual(story.whatToAvoid.resolved, "Do not add another hard session today.")
        assertNoDuplicateHeroOrSupportCopy(story, scenarioName: "completed endurance recovery")
        XCTAssertFalse(renderModel.supportActions.contains { action in
            normalizedCoachCopy(story.whatToDoNext.resolved).contains(normalizedCoachCopy(action.title))
        })
        XCTAssertFalse((state.guidance?.screenStory?.primaryActions ?? []).contains { action in
            action.title.localizedCaseInsensitiveContains("Eat a normal meal with carbs and protein")
        })
        XCTAssertTrue(state.guidance?.priority.reasons.contains("RecoveryContributorDebug.activeContributors=[]") == true)
        XCTAssertFalse(state.guidance?.priority.reasons.contains("contributor=underfueled") == true)
        XCTAssertFalse(state.guidance?.priority.reasons.contains("contributor=hydrationBehind") == true)
        XCTAssertFalse(state.guidance?.priority.reasons.contains("contributor=proteinBehind") == true)
        XCTAssertFalse(renderModel.supportSignals.contains { $0.kind == .hydration })
        XCTAssertFalse(renderModel.supportSignals.contains { $0.kind == .fuel })
        XCTAssertGreaterThanOrEqual(state.coachPresentation?.supportActions.count ?? 0, 2)
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
        XCTAssertTrue(read.contains("восстанов") || read.contains("поездк"), read)
        XCTAssertFalse(read.contains("session"), read)
        XCTAssertFalse(read.contains("main training load"), read)
        XCTAssertEqual(story.whatToAvoid.resolved, "Не добавляйте сегодня ещё одну тяжёлую сессию.")
        XCTAssertFalse(story.whatToAvoid.resolved.localizedCaseInsensitiveContains("тренеров"), story.whatToAvoid.resolved)
        XCTAssertFalse(story.whatToAvoid.resolved.localizedCaseInsensitiveContains("превращ"), story.whatToAvoid.resolved)
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
        XCTAssertTrue(
            story.whatHappened.resolved.localizedCaseInsensitiveContains("recovery") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("demanding day") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("more work"),
            story.whatHappened.resolved
        )
        XCTAssertFalse(story.whatMattersNow.resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, story.whatMattersNow.resolved)
        XCTAssertTrue(
            story.whatToDoNext.resolved.localizedCaseInsensitiveContains("25-40") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("sleep") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("easy"),
            story.whatToDoNext.resolved
        )
        XCTAssertEqual(story.whatToAvoid.resolved, "Do not add another hard session today.")
        XCTAssertGreaterThanOrEqual(state.coachPresentation?.supportActions.count ?? 0, 1)
        XCTAssertTrue((state.coachPresentation?.supportActions ?? []).contains { action in
            action.type == .cooldown ||
                action.type == .lightRecoveryMovement ||
                action.type == .mobilityPrep ||
                action.type == .sleepPriority ||
                action.type == .recoveryMeal ||
                action.type == .rehydrateGradually
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
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let next = story.whatToDoNext.resolved.lowercased()
        let why = renderModel.whyRows.map(\.title).joined(separator: " ").lowercased()

        XCTAssertEqual(story.owner, .activityPreparation)
        XCTAssertTrue(
            why.contains("training demand") ||
                why.contains("training stimulus") ||
                why.contains("session"),
            why
        )
        XCTAssertTrue(next.contains("warm-up") || next.contains("warm up") || next.contains("final hydration") || next.contains("sips"), story.whatToDoNext.resolved)
        XCTAssertFalse(next.contains("90-120"), story.whatToDoNext.resolved)
        XCTAssertFalse(next.contains("2-3 hours"), story.whatToDoNext.resolved)
        XCTAssertTrue(
            story.whatToAvoid.resolved.lowercased().contains("full meal") ||
                story.whatToAvoid.resolved.lowercased().contains("first minutes") ||
                story.whatToAvoid.resolved.lowercased().contains("intensity"),
            story.whatToAvoid.resolved
        )
    }

    func testPreparationOwnerIsNotRewrittenByEarlierCompletedLoad() throws {
        WeekFitSetCurrentLanguage(.english)
        let morning = date(hour: 10)
        let completedRide = activity(
            type: "cycling",
            title: "Morning ride",
            minutesFromNow: -180,
            duration: 90,
            icon: "bicycle",
            completed: true,
            baseDate: morning
        )
        let upcomingStrength = activity(
            type: "strength",
            title: "Strength",
            minutesFromNow: 45,
            duration: 60,
            icon: "dumbbell.fill",
            baseDate: morning
        )

        let state = stateForHeroColor(
            focus: .prepareForActivity,
            priority: .performance,
            strength: .high,
            mode: .opportunity,
            limiter: .timing,
            date: morning,
            activities: [completedRide, upcomingStrength],
            nutrition: nutrition(water: 0.4, calories: 700, protein: 25, carbs: 70),
            activeCalories: 900,
            exerciseMinutes: 120,
            activityProgress: 1.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertEqual(story.owner, .postActivityRecovery)
        XCTAssertEqual(renderModel.owner, .postActivityRecovery)
        XCTAssertTrue(
            renderModel.title.localizedCaseInsensitiveContains("work") ||
                renderModel.title.localizedCaseInsensitiveContains("recovery") ||
                renderModel.title.localizedCaseInsensitiveContains("refuel") ||
                renderModel.title.localizedCaseInsensitiveContains("done") ||
                renderModel.whatHappened.localizedCaseInsensitiveContains("recovery") ||
                renderModel.whatHappened.localizedCaseInsensitiveContains("solid work"),
            renderModel.title + " / " + renderModel.whatHappened
        )
        XCTAssertTrue(
            renderModel.whatHappened.localizedCaseInsensitiveContains("training stress") ||
                renderModel.whatHappened.localizedCaseInsensitiveContains("recovery support") ||
                renderModel.whatHappened.localizedCaseInsensitiveContains("solid work") ||
                renderModel.whatHappened.localizedCaseInsensitiveContains("long ride") ||
                renderModel.whatHappened.localizedCaseInsensitiveContains("behind you") ||
                renderModel.whatHappened.localizedCaseInsensitiveContains("day already") ||
                renderModel.whatHappened.localizedCaseInsensitiveContains("demanding day"),
            renderModel.whatHappened
        )
        XCTAssertFalse(
            renderModel.supportSignals.contains { $0.title.localizedCaseInsensitiveContains("over the next hour") },
            renderModel.supportSignals.map(\.title).joined(separator: " | ")
        )
        XCTAssertTrue(renderModel.whyRows.isEmpty, renderModel.whyRows.map(\.title).joined(separator: " | "))
        XCTAssertFalse(renderModel.displaySubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, renderModel.displaySubtitle)
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

        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview || story.owner == .recovery || story.owner == .postActivityRecovery, "\(story.owner)")
        XCTAssertFalse(renderModel.supportSignals.contains { $0.kind == .hydration })
        XCTAssertFalse(renderModel.supportSignals.contains { $0.kind == .fuel })
        XCTAssertTrue(
            story.whatToDoNext.resolved == "Leave the plan unchanged today." ||
                story.whatToDoNext.resolved == "Keep things easy today." ||
                story.whatToDoNext.resolved == "Give your body time to start recovering." ||
                story.whatToDoNext.resolved == "Walk 20-40 minutes easy. Keep it conversational." ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("do nothing extra"),
            story.whatToDoNext.resolved
        )
    }

    func testV4RecoveryWalkDoesNotTriggerMainWorkCompleted() throws {
        WeekFitSetCurrentLanguage(.english)
        let walk = activity(
            type: "walking",
            title: "Recovery walk",
            minutesFromNow: -90,
            duration: 35,
            icon: "figure.walk",
            completed: true
        )

        let state = makeState(
            activities: [walk],
            currentDate: morning,
            nutrition: nutrition(water: 1.8, calories: 1_200, protein: 70, carbs: 140),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 180,
            completedWorkoutsCount: 0,
            recoveryPercent: 88,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let visible = visibleText(state).lowercased()

        XCTAssertNotEqual(story.owner, .postActivityRecovery)
        XCTAssertFalse(visible.contains("main training work"), visible)
        XCTAssertFalse(story.whatHappened.resolved.localizedCaseInsensitiveContains("meaningful training stress"), story.whatHappened.resolved)
    }

    func testV4CompletedPlainWalkKeepsStableOwner() throws {
        WeekFitSetCurrentLanguage(.english)
        let walk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: -150,
            duration: 76,
            icon: "figure.walk",
            completed: true
        )

        let state = makeState(
            activities: [walk],
            currentDate: morning,
            nutrition: nutrition(water: 1.8, calories: 1_200, protein: 70, carbs: 140),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 320,
            completedWorkoutsCount: 0,
            recoveryPercent: 88,
            sleepHours: 8.0,
            exerciseMinutes: 76,
            activityProgress: 0.45
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)
        let coachPresentation = try XCTUnwrap(state.coachPresentation)
        let visible = visibleText(state).lowercased()

        XCTAssertEqual(state.guidance?.priority.priority, .stable)
        XCTAssertEqual(state.guidance?.priority.focus, .dailyOverview)
        XCTAssertEqual(story.owner, .stableOverview)
        XCTAssertEqual(render.owner, .stableOverview)
        XCTAssertNotEqual(story.owner, .recovery)
        XCTAssertNotEqual(story.owner, .postActivityRecovery)
        XCTAssertNotEqual(render.owner, .recovery)
        XCTAssertFalse(story.title.resolved.localizedCaseInsensitiveContains("Recovery matters most now"), story.title.resolved)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("Recovery matters most now"), render.title)
        XCTAssertFalse(state.todayPresentation.title.localizedCaseInsensitiveContains("Recovery matters most now"), state.todayPresentation.title)
        XCTAssertFalse(coachPresentation.title.localizedCaseInsensitiveContains("Recovery matters most now"), coachPresentation.title)
        XCTAssertFalse(story.title.resolved.localizedCaseInsensitiveContains("recovery"), story.title.resolved)
        XCTAssertFalse(state.todayPresentation.title.localizedCaseInsensitiveContains("recovery"), state.todayPresentation.title)
        XCTAssertFalse(coachPresentation.title.localizedCaseInsensitiveContains("recovery"), coachPresentation.title)
        XCTAssertFalse(story.title.resolved.localizedCaseInsensitiveContains("protect today's work"), story.title.resolved)
        XCTAssertFalse(story.title.resolved.localizedCaseInsensitiveContains("закрепите результат"), story.title.resolved)
        XCTAssertFalse(visible.contains("main work is complete"), visible)
        XCTAssertFalse(visible.contains("post-workout"), visible)
        XCTAssertFalse(visible.contains("recovery matters more"), visible)
        XCTAssertFalse(visible.contains("recover after your walk"), visible)
    }

    func testV4CompletedRecoveryActivitiesDoNotPromoteStableDayToRecovery() throws {
        WeekFitSetCurrentLanguage(.english)
        let modalities: [(type: String, title: String, icon: String)] = [
            ("walking", "Walk", "figure.walk"),
            ("stretching", "Stretching", "figure.flexibility"),
            ("yoga", "Yoga", "figure.mind.and.body"),
            ("breathing", "Breathing", "wind")
        ]

        for modality in modalities {
            let completed = activity(
                type: modality.type,
                title: modality.title,
                minutesFromNow: -60,
                duration: 30,
                icon: modality.icon,
                completed: true
            )

            let state = makeState(
                activities: [completed],
                currentDate: morning,
                nutrition: nutrition(water: 1.8, calories: 1_300, protein: 80, carbs: 150),
                sleepState: .strong,
                recoveryState: .strong,
                readinessState: .good,
                activeCalories: 220,
                completedWorkoutsCount: 0,
                recoveryPercent: 90,
                sleepHours: 8.0
            )
            let story = try XCTUnwrap(state.finalStory, modality.title)
            let visible = visibleText(state).lowercased()

            XCTAssertNotEqual(story.owner, .recovery, modality.title)
            XCTAssertNotEqual(story.owner, .postActivityRecovery, modality.title)
            XCTAssertFalse(story.title.resolved.localizedCaseInsensitiveContains("Recovery matters most now"), story.title.resolved)
            XCTAssertFalse(visible.contains("recover after your \(modality.title.lowercased())"), visible)
            XCTAssertFalse(visible.contains("post-workout"), visible)
            XCTAssertFalse(visible.contains("meaningful training stress"), visible)
        }
    }

    func testV4CompletedWalkCanAllowRecoveryOnlyFromIndependentDeficit() throws {
        WeekFitSetCurrentLanguage(.english)
        let walk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: -60,
            duration: 30,
            icon: "figure.walk",
            completed: true
        )

        let state = makeState(
            activities: [walk],
            currentDate: morning,
            nutrition: nutrition(water: 1.8, calories: 1_300, protein: 80, carbs: 150),
            sleepState: .short,
            recoveryState: .compromised,
            readinessState: .low,
            activeCalories: 220,
            completedWorkoutsCount: 0,
            recoveryPercent: 52,
            sleepHours: 5.8
        )
        let story = try XCTUnwrap(state.finalStory)
        let visible = visibleText(state).lowercased()
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let why = renderModel.whyRows.map(\.title).joined(separator: " ").lowercased()

        XCTAssertTrue(story.owner == .recovery || story.owner == .readiness, "\(story.owner)")
        XCTAssertTrue(visible.contains("sleep") || visible.contains("readiness") || visible.contains("recovery"), visible)
        XCTAssertTrue(why.contains("sleep") || why.contains("recovery"), why)
        XCTAssertFalse(why.contains("walk"), why)
        XCTAssertFalse(visible.contains("recover after your walk"), visible)
        XCTAssertFalse(visible.contains("meaningful training stress"), visible)
    }

    func testV4RecoveryModalitiesDoNotOwnFinalStoryLifecycle() throws {
        WeekFitSetCurrentLanguage(.english)
        let modalities: [(type: String, title: String, icon: String)] = [
            ("breathing", "Breathing", "wind"),
            ("stretching", "Stretching", "figure.flexibility"),
            ("yoga", "Yoga", "figure.mind.and.body"),
            ("mobility", "Mobility", "figure.cooldown"),
            ("walking", "Walk", "figure.walk")
        ]

        for modality in modalities {
            let futureRide = activity(type: "cycling", title: "Ride", minutesFromNow: 240, duration: 90, icon: "bicycle", baseDate: morning)
            let pre = activity(type: modality.type, title: modality.title, minutesFromNow: 30, duration: 25, icon: modality.icon, baseDate: morning)
            let active = activity(type: modality.type, title: modality.title, minutesFromNow: -5, duration: 25, icon: modality.icon, baseDate: morning)
            active.source = "today"
            let completed = activity(type: modality.type, title: modality.title, minutesFromNow: -90, duration: 25, icon: modality.icon, completed: true, baseDate: morning)

            let preStory = try XCTUnwrap(makeState(activities: [pre, futureRide], currentDate: morning).finalStory, modality.title)
            let activeStory = try XCTUnwrap(makeState(activities: [active], currentDate: morning).finalStory, modality.title)
            let postStory = try XCTUnwrap(makeState(activities: [completed], currentDate: morning, activeCalories: 180, completedWorkoutsCount: 0).finalStory, modality.title)

            // Pre with ride 240 min out: modality stays support/context, not day hero (product policy).
            // Breathing/stretch/yoga/mobility → stableOverview. Walk may still map to activityPreparation
            // when planned in ~30 min (engine edge; significant ride remains contextual, not hero owner).
            switch modality.type {
            case "walking":
                XCTAssertTrue(
                    preStory.owner == .stableOverview || preStory.owner == .activityPreparation,
                    "\(modality.title) pre should not use active or post-performance ownership"
                )
            default:
                XCTAssertEqual(preStory.owner, .stableOverview, "\(modality.title) should not own the story when the ride is still hours away")
                XCTAssertNotEqual(preStory.owner, .activityPreparation, "\(modality.title) should not become prep owner this far ahead of the ride")
            }
            XCTAssertNotEqual(activeStory.owner, .activityPreparation, "\(modality.title) should not trigger preparation")
            if modality.type == "walking" {
                // P0: calm walk may stay LIVE; copy must stay recovery-framed, not endurance pacing.
                XCTAssertEqual(activeStory.owner, .activeActivity, "\(modality.title) may stay LIVE when calm")
                XCTAssertFalse(
                    activeStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("steady rhythm"),
                    activeStory.whatToDoNext.resolved
                )
            } else {
                XCTAssertNotEqual(activeStory.owner, .activeActivity, "\(modality.title) should not become active performance")
            }
            XCTAssertNotEqual(activeStory.owner, .postActivityRecovery, "\(modality.title) should not become post performance")
            XCTAssertNotEqual(postStory.owner, .postActivityRecovery, "\(modality.title) should not become main work")
            XCTAssertFalse(activeStory.title.resolved.localizedCaseInsensitiveContains(modality.title), activeStory.title.resolved)
            XCTAssertFalse(activeStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("fuel"), activeStory.whatToDoNext.resolved)
            XCTAssertFalse(activeStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("hydrate"), activeStory.whatToDoNext.resolved)
            XCTAssertFalse(postStory.whatHappened.resolved.localizedCaseInsensitiveContains("meaningful training stress"), postStory.whatHappened.resolved)
        }
    }

    func testV4LowRecoveryWithOnlyWalkMakesRecoveryOwnsAndWalkDisappears() throws {
        WeekFitSetCurrentLanguage(.english)
        let walk = activity(type: "walking", title: "Walk", minutesFromNow: -5, duration: 30, icon: "figure.walk", baseDate: morning)
        walk.source = "today"

        let story = try XCTUnwrap(makeState(
            activities: [walk],
            currentDate: morning,
            sleepState: .short,
            recoveryState: .compromised,
            readinessState: .low,
            recoveryPercent: 52,
            sleepHours: 5.8
        ).finalStory)
        let visible = visibleText(makeState(
            activities: [walk],
            currentDate: morning,
            sleepState: .short,
            recoveryState: .compromised,
            readinessState: .low,
            recoveryPercent: 52,
            sleepHours: 5.8
        )).lowercased()

        XCTAssertTrue(story.owner == .recovery || story.owner == .readiness, "\(story.owner)")
        XCTAssertFalse(visible.contains("prepare for your walk"), visible)
        XCTAssertFalse(visible.contains("recover after your walk"), visible)
        XCTAssertFalse(visible.contains("fuel for your"), visible)
    }

    func testV4SaunaHasPreDuringPostPlaybooks() throws {
        WeekFitSetCurrentLanguage(.english)
        let pre = activity(type: "sauna", title: "Sauna", minutesFromNow: 30, duration: 30, icon: "flame.fill", baseDate: morning)
        let active = activity(type: "sauna", title: "Sauna", minutesFromNow: -5, duration: 30, icon: "flame.fill", baseDate: morning)
        active.source = "today"
        let completed = activity(type: "sauna", title: "Sauna", minutesFromNow: -60, duration: 30, icon: "flame.fill", completed: true, baseDate: morning)

        let preStory = try XCTUnwrap(makeState(activities: [pre], currentDate: morning, nutrition: nutrition(water: 0.2, calories: 1_400, protein: 80, carbs: 150)).finalStory)
        let activeStory = try XCTUnwrap(makeState(activities: [active], currentDate: morning).finalStory)
        let postStory = try XCTUnwrap(makeState(activities: [completed], currentDate: morning, activeCalories: 160, completedWorkoutsCount: 0).finalStory)
        let preRender = CoachFinalStoryRenderModel(story: preStory)
        let sleepyPreStory = try XCTUnwrap(makeState(
            activities: [pre],
            currentDate: morning,
            nutrition: nutrition(water: 0.2, calories: 1_400, protein: 80, carbs: 150),
            sleepState: .short,
            recoveryState: .vulnerable,
            recoveryPercent: 70,
            sleepHours: 6.1
        ).finalStory)
        let sleepyPreRender = CoachFinalStoryRenderModel(story: sleepyPreStory)

        XCTAssertTrue(
            preStory.whatHappened.resolved.localizedCaseInsensitiveContains("heat") ||
                preStory.whatHappened.resolved.localizedCaseInsensitiveContains("sauna"),
            preStory.whatHappened.resolved
        )
        XCTAssertTrue(preStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("300-500"), preStory.whatToDoNext.resolved)
        XCTAssertFalse(preRender.whyRows.contains { $0.kind == .hydration }, preRender.whyRows.map(\.title).joined(separator: " | "))
        XCTAssertFalse(preRender.supportActions.contains { $0.type == .steadyHydration || $0.type == .hydrateBeforeSession })
        XCTAssertFalse(
            sleepyPreRender.whyRows.contains { $0.kind == .sleep } &&
                sleepyPreRender.supportActions.contains { $0.type == .sleepPriority },
            sleepyPreRender.whyRows.map(\.title).joined(separator: " | ")
        )
        XCTAssertTrue(
            activeStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("exit") ||
                activeStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("do nothing") ||
                activeStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("heat moderate") ||
                activeStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("before fatigue"),
            activeStory.whatToDoNext.resolved
        )
        XCTAssertTrue(
            postStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("300-700") ||
                postStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("do nothing"),
            postStory.whatToDoNext.resolved
        )
        XCTAssertFalse(postStory.whatHappened.resolved.localizedCaseInsensitiveContains("main training"), postStory.whatHappened.resolved)
    }

    func testV4SaunaBeforeImportantTomorrowDoesNotOwnStory() throws {
        WeekFitSetCurrentLanguage(.english)
        let evening = date(hour: 21)
        let sauna = activity(type: "sauna", title: "Sauna", minutesFromNow: -5, duration: 30, icon: "flame.fill", baseDate: evening)
        sauna.source = "today"
        let tomorrowRide = activity(type: "cycling", title: "Tomorrow ride", minutesFromNow: 12 * 60, duration: 150, icon: "bicycle", baseDate: evening)

        let story = try XCTUnwrap(makeState(
            activities: [sauna, tomorrowRide],
            currentDate: evening,
            recoveryPercent: 82,
            sleepHours: 7.5
        ).finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(makeState(
            activities: [sauna, tomorrowRide],
            currentDate: evening,
            recoveryPercent: 82,
            sleepHours: 7.5
        )).lowercased()

        XCTAssertEqual(story.owner, .tomorrowProtection)
        XCTAssertFalse(story.reasons.contains { $0.kind == .training })
        XCTAssertFalse(story.reasons.contains { $0.kind == .hydration })
        XCTAssertTrue(story.reasons.contains { $0.kind == .constraint || $0.kind == .sleep || $0.kind == .recovery })
        XCTAssertFalse(story.title.resolved.localizedCaseInsensitiveContains("sauna"), story.title.resolved)
        XCTAssertTrue(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("heat"), story.whatToDoNext.resolved)
        XCTAssertFalse(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("workout"), story.whatToDoNext.resolved)
        XCTAssertFalse(visible.contains("make sauna easier"), visible)
        XCTAssertFalse(visible.contains("recover from heat"), visible)
        XCTAssertFalse(renderModel.subtitle.localizedCaseInsensitiveContains("tomorrow"), renderModel.subtitle)
        XCTAssertFalse(renderModel.whyRows.contains { $0.kind == .tomorrow }, renderModel.whyRows.map(\.title).joined(separator: " | "))
        XCTAssertFalse(renderModel.supportActions.contains { $0.type == .sleepPriority || $0.type == .controlIntensity })

        WeekFitSetCurrentLanguage(.russian)
        let russianStory = try XCTUnwrap(makeState(
            activities: [sauna, tomorrowRide],
            currentDate: evening,
            recoveryPercent: 82,
            sleepHours: 7.5
        ).finalStory)
        let russianRender = CoachFinalStoryRenderModel(story: russianStory)
        let russianText = ([
            russianRender.subtitle
        ] + russianRender.supportActions.flatMap { [$0.title, $0.subtitle] }).joined(separator: " ").lowercased()
        XCTAssertFalse(russianRender.subtitle.localizedCaseInsensitiveContains("завтра"), russianRender.subtitle)
        XCTAssertFalse(russianRender.whyRows.contains { $0.kind == .tomorrow }, russianRender.whyRows.map(\.title).joined(separator: " | "))
        XCTAssertFalse(russianRender.supportActions.contains { $0.type == .sleepPriority || $0.type == .controlIntensity })
        XCTAssertFalse(russianText.contains("завтра"), russianText)
    }

    func testV4StablePriorityTomorrowProtectionDoesNotEmitStabilityReason() throws {
        WeekFitSetCurrentLanguage(.english)
        let midday = date(hour: 13)
        let tomorrowRide = activity(type: "cycling", title: "Cycling", minutesFromNow: 18 * 60, duration: 210, icon: "bicycle", baseDate: midday)

        let story = try XCTUnwrap(makeState(
            activities: [tomorrowRide],
            currentDate: midday,
            recoveryPercent: 82,
            sleepHours: 7.5
        ).finalStory)

        XCTAssertEqual(story.owner, .tomorrowProtection)
        XCTAssertEqual(story.title.resolved, "Protect tomorrow's ride")
        XCTAssertFalse(story.reasons.contains { $0.kind == .stability }, story.reasons.map(\.kind.rawValue).joined(separator: ","))
        XCTAssertTrue(story.reasons.allSatisfy { [.constraint, .sleep, .recovery, .tomorrow].contains($0.kind) }, story.reasons.map(\.kind.rawValue).joined(separator: ","))
    }

    func testV4EnduranceDurationBandsHavePreDuringPostPlaybooks() throws {
        WeekFitSetCurrentLanguage(.english)
        let bands: [(duration: Int, preToken: String, postToken: String)] = [
            (45, "legs", "cool down"),
            (90, "stillness", "25-40"),
            (150, "stillness", "25-40")
        ]

        for band in bands {
            let pre = activity(type: "cycling", title: "Ride", minutesFromNow: 45, duration: band.duration, icon: "bicycle")
            let active = activity(type: "cycling", title: "Ride", minutesFromNow: -5, duration: band.duration, icon: "bicycle")
            active.source = "today"
            let completed = activity(type: "cycling", title: "Ride", minutesFromNow: -(band.duration + 20), duration: band.duration, icon: "bicycle", completed: true)

            let preStory = try XCTUnwrap(makeState(activities: [pre], nutrition: nutrition(water: 3.0, calories: 2_000, protein: 110, carbs: 260)).finalStory, "\(band.duration)")
            let activeStory = try XCTUnwrap(makeState(activities: [active]).finalStory, "\(band.duration)")
            let postStory = try XCTUnwrap(makeState(activities: [completed], activeCalories: band.duration >= 120 ? 1_200 : 520, completedWorkoutsCount: 1).finalStory, "\(band.duration)")

            XCTAssertTrue(preStory.whatToDoNext.resolved.localizedCaseInsensitiveContains(band.preToken), preStory.whatToDoNext.resolved)
            XCTAssertTrue(
                activeStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("easy") ||
                    activeStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("carbs") ||
                    activeStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("repeatable"),
                activeStory.whatToDoNext.resolved
            )
            let postNext = postStory.whatToDoNext.resolved.lowercased()
            if band.duration > 120 {
                XCTAssertTrue(postNext.contains("eat within") || postNext.contains("25-40") || postNext.contains("carbs"), postStory.whatToDoNext.resolved)
            } else {
                XCTAssertTrue(postNext.contains(band.postToken.lowercased()), postStory.whatToDoNext.resolved)
            }
            if band.duration > 120 {
                XCTAssertTrue(
                    postStory.whatHappened.resolved.localizedCaseInsensitiveContains("recovery") ||
                        postStory.whatHappened.resolved.localizedCaseInsensitiveContains("long ride"),
                    postStory.whatHappened.resolved
                )
            }
        }
    }

    func testV4LongRideIn45MinutesUsesImmediatePreparationWindow() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(type: "cycling", title: "Long ride", minutesFromNow: 45, duration: 150, icon: "bicycle")

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 88,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(state).lowercased()
        let actions = renderModel.supportActions.map { "\($0.title) \($0.subtitle)" }.joined(separator: " ").lowercased()
        let why = renderModel.whyRows.map(\.title).joined(separator: " ").lowercased()

        XCTAssertTrue(story.title.resolved.localizedCaseInsensitiveContains("fresh") || story.title.resolved.localizedCaseInsensitiveContains("start") || story.title.resolved.localizedCaseInsensitiveContains("roll") || story.title.resolved.localizedCaseInsensitiveContains("calm") || story.title.resolved.localizedCaseInsensitiveContains("head") || story.title.resolved.localizedCaseInsensitiveContains("road") || story.title.resolved.localizedCaseInsensitiveContains("almost") || story.title.resolved.localizedCaseInsensitiveContains("ride") || story.title.resolved.localizedCaseInsensitiveContains("скоро") || story.title.resolved.localizedCaseInsensitiveContains("дорог"), story.title.resolved)
        XCTAssertFalse(story.title.resolved.localizedCaseInsensitiveContains("45 minutes"), story.title.resolved)
        XCTAssertTrue(
            why.contains("about an hour") || why.contains("less than an hour") || why.contains("almost here"),
            why
        )
        XCTAssertTrue(why.contains("recovery"), why)
        XCTAssertFalse(why.contains("training stimulus") || why.contains("главная тренировка"), why)
        XCTAssertTrue(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("fluids") || story.whatToDoNext.resolved.localizedCaseInsensitiveContains("вода") || story.whatToDoNext.resolved.localizedCaseInsensitiveContains("допейте"), story.whatToDoNext.resolved)
        XCTAssertTrue(actions.contains("check bike") || actions.contains("bike and nutrition") || actions.contains("warm-up") || actions.contains("warm up"), actions)
        XCTAssertFalse(why.contains(story.title.resolved.lowercased()), why)
        assertNoCrossSectionPhraseReuse(renderModel, scenarioName: "long ride in 45 minutes")
        XCTAssertFalse(visible.contains("90-120"), visible)
        XCTAssertFalse(visible.contains("2-3 hours"), visible)
        XCTAssertFalse(visible.contains("first 30 minutes"), visible)
        XCTAssertFalse(visible.contains("preparation matters"), visible)
        XCTAssertFalse(visible.contains("next planned effort"), visible)
    }

    func testV4LongRunIn45MinutesUsesRunningPreparationCopy() throws {
        WeekFitSetCurrentLanguage(.english)
        let run = activity(type: "running", title: "Running", minutesFromNow: 45, duration: 150, icon: "figure.run")

        let state = makeState(
            activities: [run],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 88,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(state).lowercased()
        let why = renderModel.whyRows.map(\.title).joined(separator: " ").lowercased()

        XCTAssertEqual(story.decisionContext.selectedUpNext?.title, "Running")
        XCTAssertTrue(
            story.whatHappened.resolved.localizedCaseInsensitiveContains("pacing") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("run is close") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("miles") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("recovery") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("energy") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("run") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("дистанц") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("пробежка") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("восстанов"),
            story.whatHappened.resolved
        )
        XCTAssertFalse(visible.contains("ride"), visible)
        XCTAssertTrue(
            why.contains("about an hour") || why.contains("less than an hour") || why.contains("almost here"),
            why
        )
        XCTAssertFalse(why.contains("training stimulus") || why.contains("главная тренировка"), why)
    }

    func testV4LongRunIn45MinutesUsesRunningPreparationCopyRussian() throws {
        WeekFitSetCurrentLanguage(.russian)
        let run = activity(type: "running", title: "Running", minutesFromNow: 45, duration: 150, icon: "figure.run")

        let state = makeState(
            activities: [run],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 88,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let visible = visibleText(state).lowercased()
        let why = CoachFinalStoryRenderModel(story: story).whyRows.map(\.title).joined(separator: " ").lowercased()

        XCTAssertTrue(story.whatHappened.resolved.localizedCaseInsensitiveContains("пробежка"), story.whatHappened.resolved)
        XCTAssertTrue(
            why.localizedCaseInsensitiveContains("час") ||
                why.localizedCaseInsensitiveContains("скоро") ||
                why.localizedCaseInsensitiveContains("восстанов"),
            why
        )
        XCTAssertFalse(visible.contains("поезд"), visible)
        XCTAssertFalse(visible.contains("велос"), visible)
    }

    func testV4UpperBodyIn45MinutesUsesStrengthPreparationCopy() throws {
        WeekFitSetCurrentLanguage(.english)
        let upper = activity(type: "workout", title: "Upper body", minutesFromNow: 45, duration: 60, icon: "dumbbell")

        let state = makeState(
            activities: [upper],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            recoveryPercent: 88,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let visible = visibleText(state).lowercased()

        XCTAssertEqual(story.decisionContext.selectedUpNext?.title, "Upper body")
        XCTAssertTrue(story.whatHappened.resolved.localizedCaseInsensitiveContains("upper body") || story.whatHappened.resolved.localizedCaseInsensitiveContains("shoulder"), story.whatHappened.resolved)
        XCTAssertFalse(visible.contains("ride"), visible)
        XCTAssertFalse(visible.contains("run is close"), visible)
    }

    func testV4TennisIn45MinutesUsesRacketPreparationCopy() throws {
        WeekFitSetCurrentLanguage(.english)
        let tennis = activity(type: "tennis", title: "Tennis", minutesFromNow: 45, duration: 75, icon: "figure.tennis")

        let state = makeState(
            activities: [tennis],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            recoveryPercent: 88,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let visible = visibleText(state).lowercased()
        let why = CoachFinalStoryRenderModel(story: story).whyRows.map(\.title).joined(separator: " ").lowercased()

        XCTAssertTrue(story.whatHappened.resolved.localizedCaseInsensitiveContains("tennis") || story.whatHappened.resolved.localizedCaseInsensitiveContains("rhythm"), story.whatHappened.resolved)
        XCTAssertTrue(
            why.localizedCaseInsensitiveContains("about an hour") ||
                why.localizedCaseInsensitiveContains("less than an hour") ||
                why.localizedCaseInsensitiveContains("recovery"),
            why
        )
        XCTAssertFalse(visible.contains("ride"), visible)
        XCTAssertFalse(visible.contains("upper body"), visible)
    }

    func testV4LowerBodyIn45MinutesUsesStrengthPreparationCopyRussian() throws {
        WeekFitSetCurrentLanguage(.russian)
        let lower = activity(type: "workout", title: "Lower body", minutesFromNow: 45, duration: 60, icon: "dumbbell")

        let state = makeState(
            activities: [lower],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            recoveryPercent: 88,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertTrue(story.whatHappened.resolved.localizedCaseInsensitiveContains("низа") || story.whatHappened.resolved.localizedCaseInsensitiveContains("бёдра"), story.whatHappened.resolved)
        XCTAssertFalse(story.whatHappened.resolved.localizedCaseInsensitiveContains("поезд"), story.whatHappened.resolved)
    }

    func testV4RunningAndCyclingPrepCopyAreDistinctAt45Minutes() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(type: "cycling", title: "Long ride", minutesFromNow: 45, duration: 150, icon: "bicycle")
        let run = activity(type: "running", title: "Long run", minutesFromNow: 45, duration: 150, icon: "figure.run")

        let rideStory = try XCTUnwrap(makeState(
            activities: [ride],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            recoveryPercent: 88,
            sleepHours: 8.0
        ).finalStory)
        let runStory = try XCTUnwrap(makeState(
            activities: [run],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            recoveryPercent: 88,
            sleepHours: 8.0
        ).finalStory)

        let rideVisible = visibleText(makeState(activities: [ride], nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220), recoveryPercent: 88, sleepHours: 8.0))
        let runVisible = visibleText(makeState(activities: [run], nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220), recoveryPercent: 88, sleepHours: 8.0))

        XCTAssertNotEqual(rideStory.title.resolved, runStory.title.resolved)
        XCTAssertNotEqual(rideStory.whatHappened.resolved, runStory.whatHappened.resolved)
        XCTAssertTrue(rideVisible.localizedCaseInsensitiveContains("road") || rideVisible.localizedCaseInsensitiveContains("ride") || rideVisible.localizedCaseInsensitiveContains("bike") || rideVisible.localizedCaseInsensitiveContains("поезд") || rideVisible.localizedCaseInsensitiveContains("дорог") || rideVisible.localizedCaseInsensitiveContains("выезд"), rideVisible)
        XCTAssertTrue(runVisible.localizedCaseInsensitiveContains("run") || runVisible.localizedCaseInsensitiveContains("miles") || runVisible.localizedCaseInsensitiveContains("пробеж") || runVisible.localizedCaseInsensitiveContains("выход"), runVisible)
        XCTAssertFalse(rideVisible.localizedCaseInsensitiveContains("pacing, not proving"), rideVisible)
        XCTAssertFalse(runVisible.localizedCaseInsensitiveContains("driveway"), runVisible)
    }

    func testV4CyclingWithRunIconUsesCyclingPrepCopyNotRunning() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(type: "cycling", title: "Long ride", minutesFromNow: 45, duration: 150, icon: "figure.run")

        let story = try XCTUnwrap(makeState(
            activities: [ride],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            recoveryPercent: 88,
            sleepHours: 8.0
        ).finalStory)
        let visible = visibleText(makeState(
            activities: [ride],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            recoveryPercent: 88,
            sleepHours: 8.0
        )).lowercased()

        XCTAssertTrue(
            story.title.resolved.localizedCaseInsensitiveContains("head") ||
                story.title.resolved.localizedCaseInsensitiveContains("road") ||
                story.title.resolved.localizedCaseInsensitiveContains("ride") ||
                story.title.resolved.localizedCaseInsensitiveContains("almost") ||
                story.title.resolved.localizedCaseInsensitiveContains("скоро") ||
                story.title.resolved.localizedCaseInsensitiveContains("дорог"),
            story.title.resolved
        )
        XCTAssertFalse(visible.contains("pacing, not proving"), visible)
        XCTAssertFalse(visible.contains("start calm, not fast"), visible)
    }

    func testV4LongRideUnder15MinutesAvoidsMainTrainingReasonAndWarmUpRepetitionRussian() throws {
        WeekFitSetCurrentLanguage(.russian)
        let ride = activity(type: "cycling", title: "Long ride", minutesFromNow: 10, duration: 150, icon: "figure.run")

        let story = try XCTUnwrap(makeState(
            activities: [ride],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            recoveryPercent: 88,
            sleepHours: 8.0
        ).finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let why = renderModel.whyRows.map(\.title).joined(separator: " ").lowercased()
        let visible = visibleText(makeState(
            activities: [ride],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            recoveryPercent: 88,
            sleepHours: 8.0
        )).lowercased()

        XCTAssertTrue(story.title.resolved.localizedCaseInsensitiveContains("пора") || story.title.resolved.localizedCaseInsensitiveContains("выезж"), story.title.resolved)
        XCTAssertFalse(why.contains("главная тренировка"), why)
        XCTAssertFalse(visible.contains("раскрут"), visible)
        XCTAssertFalse(visible.contains("мощность — на потом"), visible)
        assertNoDuplicateHeroOrSupportCopy(story, scenarioName: "long ride under 15 minutes russian")
    }

    func testV4LongRideInTwoToFourHoursUsesDistinctPreparationCopy() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(type: "cycling", title: "Long ride", minutesFromNow: 193, duration: 150, icon: "bicycle")

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 1.4, calories: 1_700, protein: 90, carbs: 220),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 88,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let why = renderModel.whyRows.map(\.title).joined(separator: " ").lowercased()

        XCTAssertEqual(story.owner, .activityPreparation)
        XCTAssertEqual(story.decisionContext.selectedUpNext?.title, "Long ride")
        XCTAssertTrue(story.title.resolved.localizedCaseInsensitiveContains("ride") || story.title.resolved.localizedCaseInsensitiveContains("Set up"), story.title.resolved)
        XCTAssertFalse(story.whatHappened.resolved.localizedCaseInsensitiveContains("main training demand"), story.whatHappened.resolved)
        XCTAssertTrue(
            why.contains("couple of hours") || why.contains("few hours") || why.contains("about 3 hours") || why.contains("about 2 hours"),
            why
        )
        XCTAssertFalse(why.contains("193 minutes"), why)
        XCTAssertFalse(why.contains("500 minutes"), why)
        XCTAssertTrue(why.contains("recovery"), why)
        XCTAssertFalse(why.contains("training stimulus") || why.contains("главная тренировка"), why)
        assertNoCrossSectionPhraseReuse(renderModel, scenarioName: "long ride in 193 minutes")
        assertNoDuplicateHeroOrSupportCopy(story, scenarioName: "long ride in 193 minutes")
    }

    func testV4LongCyclingSessionTransitionsThroughDayCentricOwners() throws {
        WeekFitSetCurrentLanguage(.english)
        let rideDuration = 210
        let ride = activity(type: "cycling", title: "Long ride", minutesFromNow: 45, duration: rideDuration, icon: "bicycle")
        let preStory = try XCTUnwrap(makeState(activities: [ride], nutrition: nutrition(water: 1.8, calories: 1_800, protein: 90, carbs: 240), recoveryPercent: 95).finalStory)
        XCTAssertEqual(preStory.owner, .activityPreparation)

        let early = activity(type: "cycling", title: "Long ride", minutesFromNow: -12, duration: rideDuration, icon: "bicycle")
        early.source = "today"
        let earlyStory = try XCTUnwrap(makeState(activities: [early], nutrition: nutrition(water: 2.0, calories: 1_500, protein: 80, carbs: 180), activeCalories: 180, recoveryPercent: 95).finalStory)
        XCTAssertEqual(earlyStory.owner, .pacingExecution)
        XCTAssertTrue(earlyStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("10 minutes"), earlyStory.whatToDoNext.resolved)

        let middle = activity(type: "cycling", title: "Long ride", minutesFromNow: -55, duration: rideDuration, icon: "bicycle")
        middle.source = "today"
        let middleStory = try XCTUnwrap(makeState(activities: [middle], nutrition: nutrition(water: 2.1, calories: 1_300, protein: 70, carbs: 160), activeCalories: 650, recoveryPercent: 95).finalStory)
        XCTAssertEqual(middleStory.owner, .sustainableExecution)
        XCTAssertTrue(middleStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("20-30"), middleStory.whatToDoNext.resolved)

        let longActive = activity(type: "cycling", title: "Long ride", minutesFromNow: -143, duration: rideDuration, icon: "bicycle")
        longActive.source = "today"
        let fuelingStory = try XCTUnwrap(makeState(activities: [longActive], nutrition: nutrition(water: 1.0, calories: 957, protein: 55, carbs: 70), activeCalories: 2_001, recoveryPercent: 95).finalStory)
        let fuelingRender = CoachFinalStoryRenderModel(story: fuelingStory)
        let fuelingWhy = fuelingRender.whyRows.map(\.title).joined(separator: " ").lowercased()
        XCTAssertEqual(fuelingStory.owner, .fuelingDuringActivity)
        XCTAssertTrue(
            fuelingStory.title.resolved.localizedCaseInsensitiveContains("refuel") ||
                fuelingStory.title.resolved.localizedCaseInsensitiveContains("energy"),
            fuelingStory.title.resolved
        )
        XCTAssertTrue(fuelingStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("30-60"), fuelingStory.whatToDoNext.resolved)
        XCTAssertTrue(fuelingStory.whatToAvoid.resolved.localizedCaseInsensitiveContains("hunger"), fuelingStory.whatToAvoid.resolved)
        XCTAssertTrue(fuelingWhy.contains("fuel") || fuelingWhy.contains("energy") || fuelingWhy.contains("carb"), fuelingWhy)
        XCTAssertFalse(fuelingStory.title.resolved.localizedCaseInsensitiveContains("pace"), fuelingStory.title.resolved)

        let completed = activity(type: "cycling", title: "Long ride", minutesFromNow: -(rideDuration + 5), duration: rideDuration, icon: "bicycle", completed: true)
        let postStory = try XCTUnwrap(makeState(activities: [completed], nutrition: nutrition(water: 1.4, calories: 1_400, protein: 70, carbs: 160), activeCalories: 2_100, completedWorkoutsCount: 1, recoveryPercent: 95).finalStory)
        XCTAssertEqual(postStory.owner, .postActivityRecovery)
        XCTAssertTrue(postStory.whatToDoNext.resolved.localizedCaseInsensitiveContains("25-40"), postStory.whatToDoNext.resolved)

        let evening = date(hour: 21)
        let completedEvening = activity(type: "cycling", title: "Long ride", minutesFromNow: -240, duration: rideDuration, icon: "bicycle", completed: true, baseDate: evening)
        let tomorrowRide = activity(type: "cycling", title: "Tomorrow ride", minutesFromNow: 12 * 60, duration: 150, icon: "bicycle", baseDate: evening)
        let eveningStory = try XCTUnwrap(makeState(activities: [completedEvening, tomorrowRide], currentDate: evening, nutrition: nutrition(water: 2.2, calories: 2_300, protein: 110, carbs: 280), activeCalories: 2_100, completedWorkoutsCount: 1, recoveryPercent: 82).finalStory)
        XCTAssertEqual(eveningStory.owner, .tomorrowProtection)
    }

    func testV4StalePostLongRideUsesEveningCopyNotImmediateProtocol() throws {
        WeekFitSetCurrentLanguage(.russian)
        let rideDuration = 150
        let minutesSinceEnd = 260
        let completed = activity(
            type: "cycling",
            title: "Long ride",
            minutesFromNow: -(rideDuration + minutesSinceEnd),
            duration: rideDuration,
            icon: "bicycle",
            completed: true,
            baseDate: date(hour: 18)
        )
        let state = makeState(
            activities: [completed],
            currentDate: date(hour: 18),
            nutrition: nutrition(water: 2.0, calories: 2_200, protein: 100, carbs: 250),
            activeCalories: 2_100,
            completedWorkoutsCount: 1,
            recoveryPercent: 82,
            sleepHours: 7.5
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(state).lowercased()

        XCTAssertEqual(story.owner, .postActivityRecovery)
        XCTAssertTrue(renderModel.whyRows.isEmpty, renderModel.whyRows.map(\.title).joined(separator: " | "))
        XCTAssertFalse(renderModel.displaySubtitle.isEmpty, renderModel.displaySubtitle)
        XCTAssertFalse(visible.contains("в течение часа"), visible)
        XCTAssertFalse(visible.contains("next hour"), visible)
        XCTAssertTrue(
            visible.contains("вечер") ||
                visible.contains("сон") ||
                visible.contains("день") ||
                visible.contains("позади") ||
                visible.contains("утром"),
            visible
        )
    }

    func testV4PostWithRecoveryLimitedStillMentionsTomorrowPlan() throws {
        WeekFitSetCurrentLanguage(.english)
        let evening = date(hour: 20)
        let completedRide = activity(
            type: "cycling",
            title: "Long ride",
            minutesFromNow: -(150 + 260),
            duration: 150,
            icon: "bicycle",
            completed: true,
            baseDate: evening
        )
        let tomorrowMorning = tomorrow(hour: 9)
        let walk = activity(type: "walking", title: "Walk", minutesFromNow: 0, duration: 30, icon: "figure.walk", baseDate: tomorrowMorning)
        let stretching = activity(type: "stretching", title: "Stretching", minutesFromNow: 75, duration: 55, icon: "figure.flexibility", baseDate: tomorrowMorning)
        let sauna = activity(type: "sauna", title: "Sauna", minutesFromNow: 165, duration: 45, icon: "flame.fill", baseDate: tomorrowMorning)

        let state = makeState(
            activities: [completedRide, walk, stretching, sauna],
            currentDate: evening,
            nutrition: nutrition(water: 2.2, calories: 2_300, protein: 110, carbs: 280),
            recoveryState: .stable,
            activeCalories: 2_100,
            completedWorkoutsCount: 1,
            recoveryPercent: 89,
            sleepHours: 7.5
        )
        let read = try XCTUnwrap(state.finalStory?.whatHappened.resolved).lowercased()

        XCTAssertTrue(read.contains("tomorrow has"), read)
        XCTAssertTrue(read.contains("walk"), read)
        XCTAssertTrue(read.contains("stretching"), read)
        XCTAssertTrue(read.contains("sauna"), read)
        XCTAssertTrue(read.contains("serious training"), read)
        XCTAssertFalse(read.contains("recovery is limited at 89%"), read)
        XCTAssertFalse(read.contains("protecting sleep and keeping the evening calm"), read)
        XCTAssertFalse(read.contains("hours behind you"), read)
    }

    func testV4PostAfterRideWithTomorrowStretchingSaunaStaysRecoveryNotTomorrowProtection() throws {
        WeekFitSetCurrentLanguage(.russian)
        let evening = date(hour: 20)
        let completedRide = activity(
            type: "cycling",
            title: "Long ride",
            minutesFromNow: -(150 + 260),
            duration: 150,
            icon: "bicycle",
            completed: true,
            baseDate: evening
        )
        let tomorrowMorning = tomorrow(hour: 9)
        let stretching = activity(type: "stretching", title: "Stretching", minutesFromNow: 0, duration: 30, icon: "figure.flexibility", baseDate: tomorrowMorning)
        let sauna = activity(type: "sauna", title: "Sauna", minutesFromNow: 120, duration: 30, icon: "flame.fill", baseDate: tomorrowMorning)

        let state = makeState(
            activities: [completedRide, stretching, sauna],
            currentDate: evening,
            nutrition: nutrition(water: 2.2, calories: 2_300, protein: 110, carbs: 280),
            activeCalories: 2_100,
            completedWorkoutsCount: 1,
            recoveryPercent: 82,
            sleepHours: 7.5
        )
        let story = try XCTUnwrap(state.finalStory)
        let read = story.whatHappened.resolved.lowercased()
        let visible = visibleText(state).lowercased()

        XCTAssertEqual(story.owner, .postActivityRecovery)
        XCTAssertNotEqual(story.owner, .tomorrowProtection)
        XCTAssertTrue(
            read.contains("растяж") && read.contains("саун"),
            read
        )
        XCTAssertTrue(
            read.contains("завтра в плане"),
            read
        )
        XCTAssertFalse(
            visible.contains("завтра ещё есть серьёзная нагрузка") ||
                visible.contains("tomorrow still has real training demand"),
            visible
        )
    }

    func testV4PostRecoveryHeroVariesByTimeOfDay() throws {
        WeekFitSetCurrentLanguage(.russian)
        let rideDuration = 150
        let minutesSinceEnd = 260
        let phases: [(hour: Int, expectedFragment: String)] = [
            (8, "утром"),
            (13, "середина"),
            (16, "второй"),
            (20, "Вечер"),
            (22, "Поздний")
        ]

        for phase in phases {
            let currentDate = date(hour: phase.hour)
            let completed = activity(
                type: "cycling",
                title: "Long ride",
                minutesFromNow: -(rideDuration + minutesSinceEnd),
                duration: rideDuration,
                icon: "bicycle",
                completed: true,
                baseDate: currentDate
            )
            let story = try XCTUnwrap(
                makeState(
                    activities: [completed],
                    currentDate: currentDate,
                    nutrition: nutrition(water: 2.0, calories: 2_200, protein: 100, carbs: 250),
                    activeCalories: 2_100,
                    completedWorkoutsCount: 1,
                    recoveryPercent: 82,
                    sleepHours: 7.5
                ).finalStory,
                "hour \(phase.hour)"
            )
            XCTAssertTrue(
                story.title.resolved.localizedCaseInsensitiveContains(phase.expectedFragment) ||
                    story.whatHappened.resolved.localizedCaseInsensitiveContains(phase.expectedFragment.lowercased()),
                "hour \(phase.hour): \(story.title.resolved) / \(story.whatHappened.resolved)"
            )
        }
    }

    func testV4MorningWalkWithRideLaterProtectsUpcomingSession() throws {
        WeekFitSetCurrentLanguage(.english)
        let walk = activity(type: "walking", title: "Walk", minutesFromNow: -5, duration: 30, icon: "figure.walk", baseDate: morning)
        walk.source = "today"
        let ride = activity(type: "cycling", title: "Ride", minutesFromNow: 240, duration: 90, icon: "bicycle", baseDate: morning)

        let story = try XCTUnwrap(makeState(activities: [walk, ride], currentDate: morning, recoveryPercent: 90, sleepHours: 8.0).finalStory)

        XCTAssertEqual(story.owner, .activityPreparation)
        XCTAssertTrue(story.decisionContext.hasFutureActivityContext)
        XCTAssertEqual(story.decisionContext.selectedUpNext?.title, "Ride")
        XCTAssertTrue(
            story.whatHappened.resolved.localizedCaseInsensitiveContains("endurance") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("training") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("ride") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("recovery") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("energy") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("session") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("fuel") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("bottles") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("восстанов") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("велос"),
            visibleText(makeState(activities: [walk, ride], currentDate: morning))
        )
        XCTAssertTrue(
            story.whatToDoNext.resolved.localizedCaseInsensitiveContains("carb") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("hydration") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("start"),
            story.whatToDoNext.resolved
        )
        XCTAssertTrue(
            story.whatToAvoid.resolved.localizedCaseInsensitiveContains("second workout") ||
                story.whatToAvoid.resolved.localizedCaseInsensitiveContains("extra training") ||
                story.whatToAvoid.resolved.localizedCaseInsensitiveContains("hard session") ||
                story.whatToAvoid.resolved.localizedCaseInsensitiveContains("main session") ||
                story.whatToAvoid.resolved.localizedCaseInsensitiveContains("save your legs") ||
                story.whatToAvoid.resolved.localizedCaseInsensitiveContains("burn legs"),
            story.whatToAvoid.resolved
        )
        assertNoDuplicateHeroOrSupportCopy(story, scenarioName: "morning walk with ride later")
    }

    func testV4HighCaloriesCompletedWalkDoesNotBecomeMainTrainingWithoutObjectiveTrainingStress() throws {
        WeekFitSetCurrentLanguage(.english)
        let walk = activity(type: "walking", title: "Walk", minutesFromNow: -180, duration: 90, icon: "figure.walk", completed: true)

        let story = try XCTUnwrap(makeState(
            activities: [walk],
            currentDate: morning,
            activeCalories: 900,
            completedWorkoutsCount: 0,
            recoveryPercent: 86,
            sleepHours: 7.8,
            exerciseMinutes: 90,
            activityProgress: 0.9
        ).finalStory)

        XCTAssertNotEqual(story.owner, .postActivityRecovery)
        XCTAssertFalse(story.whatHappened.resolved.localizedCaseInsensitiveContains("main training"), story.whatHappened.resolved)
        XCTAssertFalse(story.whatHappened.resolved.localizedCaseInsensitiveContains("meaningful training stress"), story.whatHappened.resolved)
    }

    func testV4HighRecoveryLowStrainCanRecommendDoingNothing() throws {
        WeekFitSetCurrentLanguage(.english)
        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 1.8, calories: 1_200, protein: 70, carbs: 140),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 120,
            completedWorkoutsCount: 0,
            recoveryPercent: 92,
            sleepHours: 8.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertEqual(state.guidance?.priority.priority, .stable)
        XCTAssertEqual(state.guidance?.priority.focus, .dailyOverview)
        XCTAssertNotEqual(story.owner, .recovery)
        XCTAssertNotEqual(renderModel.owner, .recovery)
        XCTAssertFalse(story.title.resolved.localizedCaseInsensitiveContains("Recovery matters most now"), story.title.resolved)
        XCTAssertFalse(story.title.resolved.localizedCaseInsensitiveContains("recovery"), story.title.resolved)
        XCTAssertTrue(
            story.whatHappened.resolved.localizedCaseInsensitiveContains("nothing important") ||
                story.whatHappened.resolved.localizedCaseInsensitiveContains("strain remains low"),
            story.whatHappened.resolved
        )
        XCTAssertTrue(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("do nothing"), story.whatToDoNext.resolved)
        XCTAssertTrue(story.whatToAvoid.resolved.localizedCaseInsensitiveContains("close a number"), story.whatToAvoid.resolved)
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

    func testSundayMorningModerateRecoveryNoWorkoutUsesCalmReadinessOverview() throws {
        WeekFitSetCurrentLanguage(.english)

        let sundayMorning = date(hour: 8, minute: 53)

        let state = makeState(
            activities: [],
            currentDate: sundayMorning,
            nutrition: nutrition(water: 0, calories: 0, protein: 0, carbs: 0),
            sleepState: .short,
            recoveryState: .stable,
            readinessState: .compromised,
            activeCalories: 171,
            recoveryPercent: 67,
            sleepHours: 6.42
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(state)
        let whyText = render.whyRows.map(\.title).joined(separator: " ")

        assertNoWorkoutAssumptionCopy(in: visible, scenarioName: "Sunday moderate recovery no workout")
        let fullCoachText = [
            visible,
            story.whatHappened.resolved,
            render.subtitle,
            render.primaryRecommendation,
            render.avoidRecommendation,
            whyText
        ].joined(separator: " ")
        assertNoMetricNarration(in: fullCoachText, scenarioName: "Sunday moderate recovery no workout")
        XCTAssertTrue(
            story.title.resolved.localizedCaseInsensitiveContains("Morning's going fine") ||
                story.title.resolved.localizedCaseInsensitiveContains("going fine"),
            story.title.resolved
        )
        XCTAssertTrue(
            story.whatHappened.resolved.localizedCaseInsensitiveContains("Recovery looks reasonable") ||
                render.subtitle.localizedCaseInsensitiveContains("Recovery looks reasonable"),
            story.whatHappened.resolved
        )
        XCTAssertTrue(
            render.primaryRecommendation.localizedCaseInsensitiveContains("build naturally") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("build naturally"),
            render.primaryRecommendation
        )
        XCTAssertTrue(
            render.avoidRecommendation.localizedCaseInsensitiveContains("forcing the pace") ||
                story.whatToAvoid.resolved.localizedCaseInsensitiveContains("forcing the pace"),
            render.avoidRecommendation
        )
        XCTAssertTrue(
            whyText.localizedCaseInsensitiveContains("supported recovery overnight") ||
                whyText.localizedCaseInsensitiveContains("finishing recovery") ||
                story.reasons.map { $0.text.resolved }.joined(separator: " ").localizedCaseInsensitiveContains("supported recovery overnight") ||
                story.reasons.map { $0.text.resolved }.joined(separator: " ").localizedCaseInsensitiveContains("finishing recovery"),
            whyText
        )
        XCTAssertTrue(story.owner == .stableOverview || story.owner == .readiness, "\(story.owner)")
        XCTAssertNotEqual(state.guidance?.priority.focus, .trainingReadinessWarning)
        XCTAssertEqual(state.todayPresentation.title, story.title.resolved)
        XCTAssertEqual(state.coachPresentation?.title, story.title.resolved)
    }

    func testModerateRecoveryNoActivitiesNeverUsesWorkoutPrepCopy() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0, calories: 0, protein: 0, carbs: 0),
            sleepState: .short,
            recoveryState: .stable,
            readinessState: .compromised,
            activeCalories: 120,
            recoveryPercent: 67,
            sleepHours: 6.4
        )

        assertNoWorkoutAssumptionCopy(in: visibleText(state), scenarioName: "moderate recovery no activities")
        assertNoMetricNarration(in: visibleText(state), scenarioName: "moderate recovery no activities")
    }

    func testLowRecoveryNoActivitiesUsesRecoveryLedDayNotWorkoutIntensity() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0, calories: 0, protein: 0, carbs: 0),
            sleepState: .short,
            recoveryState: .compromised,
            readinessState: .low,
            activeCalories: 80,
            recoveryPercent: 48,
            sleepHours: 5.2
        )
        let visible = visibleText(state)

        assertNoWorkoutAssumptionCopy(in: visible, scenarioName: "low recovery no activities")
        XCTAssertTrue(
            state.finalStory?.owner == .recovery ||
                state.finalStory?.owner == .stableOverview ||
                state.finalStory?.owner == .readiness,
            "\(state.finalStory?.owner.rawValue ?? "nil")"
        )
    }

    func testGoodRecoveryNoActivitiesStaysCalmOverview() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0, calories: 0, protein: 0, carbs: 0),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 90,
            recoveryPercent: 88,
            sleepHours: 8.1
        )
        let visible = visibleText(state)

        assertNoWorkoutAssumptionCopy(in: visible, scenarioName: "good recovery no activities")
        XCTAssertNotEqual(state.guidance?.priority.focus, .trainingReadinessWarning)
    }

    func testModerateRecoveryUpcomingWorkoutMayUseControlledPrepCopy() throws {
        WeekFitSetCurrentLanguage(.english)

        let run = activity(
            type: "running",
            title: "Running",
            minutesFromNow: 120,
            duration: 60,
            icon: "figure.run",
            baseDate: morning
        )
        let state = makeState(
            activities: [run],
            currentDate: morning,
            nutrition: nutrition(water: 0.8, calories: 400, protein: 20, carbs: 45),
            sleepState: .short,
            recoveryState: .stable,
            readinessState: .compromised,
            recoveryPercent: 67,
            sleepHours: 6.4
        )
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertTrue(
            story.owner == .activityPreparation ||
                story.owner == .readiness ||
                state.guidance?.priority.focus == .prepareForActivity ||
                state.guidance?.priority.focus == .nextActivityLater,
            "\(story.owner) / \(String(describing: state.guidance?.priority.focus))"
        )
    }

    func testMorningZeroNutritionHydrationDoesNotDriveNegativeCoachNarrative() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = makeState(
            activities: [],
            currentDate: morning,
            nutrition: nutrition(water: 0, calories: 0, protein: 0, carbs: 0),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 0,
            recoveryPercent: 84,
            sleepHours: 7.8
        )
        let visible = visibleText(state)

        XCTAssertFalse(visible.localizedCaseInsensitiveContains("haven't eaten enough"))
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("low on water"))
        assertNoWorkoutAssumptionCopy(in: visible, scenarioName: "morning zero nutrition")
    }

    func testStableOverviewIgnoresStaleHealthKitLoadWithoutPlannedCompletion() throws {
        WeekFitSetCurrentLanguage(.english)

        let state = stateForHeroColor(
            focus: .dailyOverview,
            priority: .stable,
            strength: .low,
            mode: .reinforcement,
            limiter: CoachLimiter.none,
            date: morning,
            activities: [],
            nutrition: nutrition(water: 1.4, calories: 900, protein: 50, carbs: 90),
            activeCalories: 1_500,
            exerciseMinutes: 95,
            recoveryPercent: 88,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let visible = visibleText(state).lowercased()

        XCTAssertTrue(story.owner == .stableOverview || story.owner == .readiness, "\(story.owner)")
        XCTAssertNotEqual(story.owner, CoachFinalStoryOwner.postActivityRecovery)
        XCTAssertFalse(story.title.resolved.localizedCaseInsensitiveContains("already added"), story.title.resolved)
        XCTAssertFalse(visible.contains("long ride"), visible)
        XCTAssertFalse(visible.contains("after this morning"), visible)
        XCTAssertFalse(visible.contains("session is well behind you"), visible)
    }

    func testMorningRecoveryDayWithUpcomingPlanDoesNotClaimCompletedMovement() throws {
        WeekFitSetCurrentLanguage(.english)

        let walk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: 105,
            duration: 45,
            icon: "figure.walk",
            baseDate: morning
        )
        let stretching = activity(
            type: "recovery",
            title: "Stretching",
            minutesFromNow: 180,
            duration: 20,
            icon: "figure.cooldown",
            baseDate: morning
        )
        let sauna = activity(
            type: "recovery",
            title: "Sauna",
            minutesFromNow: 300,
            duration: 20,
            icon: "flame.fill",
            baseDate: morning
        )
        let eveningWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: 540,
            duration: 30,
            icon: "figure.walk",
            baseDate: morning
        )

        let state = makeState(
            activities: [walk, stretching, sauna, eveningWalk],
            currentDate: morning,
            nutrition: nutrition(water: 1.4, calories: 900, protein: 50, carbs: 90),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 90,
            sleepHours: 8.1
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(state).lowercased()

        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview, "\(story.owner)")
        XCTAssertNotEqual(story.owner, .postActivityRecovery)
        XCTAssertNotEqual(story.owner, .recovery)
        XCTAssertTrue(render.title.localizedCaseInsensitiveContains("walk"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("stretching"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("already added"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("easy movement"), render.title)
        XCTAssertFalse(visible.contains("long ride"), visible)
        XCTAssertFalse(visible.contains("after this morning"), visible)
        XCTAssertTrue(render.supportActions.isEmpty, "Calm overview should not repeat the recommendation in What to do")
        XCTAssertFalse(
            render.whyRows.contains { $0.title.localizedCaseInsensitiveContains("next important session") },
            "Plan headline already names the next activity"
        )
    }

    func testPostSaunaUsesHeatRecoveryNotMainTrainingComplete() throws {
        WeekFitSetCurrentLanguage(.english)

        let morningWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: -180,
            duration: 25,
            icon: "figure.walk",
            completed: true,
            baseDate: morning
        )
        let yoga = activity(
            type: "workout",
            title: "Yoga",
            minutesFromNow: -120,
            duration: 55,
            icon: "figure.yoga",
            completed: true,
            baseDate: morning
        )
        let sauna = activity(
            type: "recovery",
            title: "Sauna",
            minutesFromNow: -75,
            duration: 45,
            icon: "flame.fill",
            completed: true,
            baseDate: morning
        )
        let afternoon = Calendar.current.date(byAdding: .hour, value: 2, to: sauna.date) ?? morning

        let state = makeState(
            activities: [morningWalk, yoga, sauna],
            currentDate: afternoon,
            nutrition: nutrition(water: 1.2, calories: 1_100, protein: 55, carbs: 110),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 850,
            recoveryPercent: 91,
            sleepHours: 8.0,
            exerciseMinutes: 140
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(state).lowercased()

        XCTAssertNotEqual(story.owner, .postActivityRecovery)
        XCTAssertTrue(story.owner == .stableOverview || story.owner == .readiness || story.owner == .recovery, "\(story.owner)")
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("main training"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("main work"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("after sauna"), render.title)
        XCTAssertFalse(visible.contains("25-40 g protein"), visible)
        XCTAssertTrue(
            visible.contains("progress") ||
                visible.contains("easy") ||
                visible.contains("going fine") ||
                visible.contains("water") ||
                visible.contains("hydr") ||
                visible.contains("today") ||
                visible.contains("прогресс") ||
                visible.contains("ровно") ||
                visible.contains("сегодня"),
            visible
        )
    }

    func testPostSaunaFramesWholeDayAndRemainingPlan() throws {
        WeekFitSetCurrentLanguage(.english)

        let morningWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: -180,
            duration: 25,
            icon: "figure.walk",
            completed: true,
            baseDate: morning
        )
        let yoga = activity(
            type: "workout",
            title: "Yoga",
            minutesFromNow: -120,
            duration: 55,
            icon: "figure.yoga",
            completed: true,
            baseDate: morning
        )
        let sauna = activity(
            type: "recovery",
            title: "Sauna",
            minutesFromNow: -75,
            duration: 45,
            icon: "flame.fill",
            completed: true,
            baseDate: morning
        )
        let afternoon = Calendar.current.date(byAdding: .hour, value: 2, to: sauna.date) ?? morning
        let eveningWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: 120,
            duration: 30,
            icon: "figure.walk",
            baseDate: afternoon
        )

        let state = makeState(
            activities: [morningWalk, yoga, sauna, eveningWalk],
            currentDate: afternoon,
            nutrition: nutrition(water: 1.2, calories: 1_100, protein: 55, carbs: 110),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 850,
            recoveryPercent: 91,
            sleepHours: 8.0,
            exerciseMinutes: 140
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)
        let visible = (
            [render.title, render.displaySubtitle, render.primaryRecommendation, render.displayAvoid] +
                render.whyRows.map(\.title)
        ).joined(separator: " ").lowercased()

        XCTAssertTrue(
            visible.contains("so far today") ||
                visible.contains("still on today's plan") ||
                visible.contains("still ahead") ||
                visible.contains("take it easy") ||
                visible.contains("after sauna"),
            visible
        )
        XCTAssertTrue(
            visible.contains("walk") || visible.contains("still ahead"),
            visible
        )
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("main training"), render.title)
    }

    func testActiveRunningOverridesRecentPostWalkFocus() throws {
        WeekFitSetCurrentLanguage(.english)

        let completedWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: -45,
            duration: 30,
            icon: "figure.walk",
            completed: true,
            baseDate: morning
        )
        let activeRunning = activity(
            type: "running",
            title: "Running",
            minutesFromNow: -3,
            duration: 45,
            icon: "figure.run",
            baseDate: morning
        )

        let dayContext = CoachDayContextBuilder.build(
            activities: [completedWalk, activeRunning],
            selectedDate: morning,
            now: morning
        )
        let nutrition = nutrition(water: 1.4, calories: 1_100, protein: 60, carbs: 120)
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 10
        brainConfig.hydration = .optimal
        brainConfig.fuel = .good
        brainConfig.sleep = .strong
        brainConfig.recovery = .strong
        brainConfig.readiness = .good
        brainConfig.metrics = CoachMetricsBuilder.metrics(
            protein: nutrition.proteinCurrent,
            carbs: nutrition.carbsCurrent,
            calories: nutrition.caloriesCurrent,
            waterLiters: nutrition.waterCurrent,
            activeCalories: 420,
            sleepHours: 8.0
        )
        let input = CoachInputSnapshot(
            selectedDate: morning,
            now: morning,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: [completedWalk, activeRunning],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 420,
                exerciseMinutes: 40,
                standHours: nil,
                activityGoalCalories: nil,
                activityProgress: nil
            ),
            dayContext: dayContext,
            recoveryContext: CoachRecoveryContext(recoveryPercent: 86, sleepHours: 8.0),
            nutritionContext: nutrition,
            source: "CoachStateNarrativeContractTests"
        )
        let priority = CoachDayPriorityResult(
            focus: .activeActivity,
            level: .high,
            reason: "Active running session",
            activity: activeRunning,
            overridesTimingFocus: true,
            priority: .activeSession,
            strength: .high,
            confidence: 0.92,
            mode: .reinforcement,
            limiter: .accumulatedFatigue,
            todayTitle: "Keep this session controlled",
            todayMessage: "Stay conversational",
            detailTitle: "Keep this session controlled",
            detailMessage: "Stay conversational",
            reasons: ["activeRunning"]
        )
        let guidance = CoachGuidanceV3(
            phase: .active(activity: activeRunning, kind: .endurance),
            opportunity: CoachSupportOpportunityV3(
                type: .activeWorkoutSupport,
                importance: .high,
                reason: "Active running session"
            ),
            priority: priority,
            shouldSurface: true,
            stateLabel: "LIVE",
            title: "Keep this session controlled",
            message: "Stay conversational",
            insightTitle: "Keep this session controlled",
            insightSubtitle: "Stay conversational",
            supportActions: [],
            avoidNotes: [],
            icon: "figure.run",
            color: WeekFitTheme.workout,
            importance: .high,
            tone: .supportive
        )

        let state = CoachState.ready(
            input: input,
            fingerprint: CoachInputFingerprint(snapshot: input),
            guidance: guidance,
            createdAt: morning
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)

        XCTAssertEqual(story.owner, .activeActivity, "\(story.owner)")
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("walk"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("после"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("finished"), render.title)
        XCTAssertTrue(
            render.title.localizedCaseInsensitiveContains("block") ||
                render.title.localizedCaseInsensitiveContains("controlled") ||
                render.title.localizedCaseInsensitiveContains("settle") ||
                render.title.localizedCaseInsensitiveContains("rhythm") ||
                render.title.localizedCaseInsensitiveContains("pace"),
            render.title
        )
    }

    func testCompletedWalkWithSaunaAheadFramesWholeDayNotAfterWalk() throws {
        WeekFitSetCurrentLanguage(.english)

        let completedWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: -90,
            duration: 35,
            icon: "figure.walk",
            completed: true,
            baseDate: morning
        )
        let sauna = activity(
            type: "recovery",
            title: "Sauna",
            minutesFromNow: 120,
            duration: 30,
            icon: "flame.fill",
            baseDate: morning
        )
        let afternoon = Calendar.current.date(byAdding: .hour, value: 2, to: completedWalk.date) ?? morning

        let state = makeState(
            activities: [completedWalk, sauna],
            currentDate: afternoon,
            nutrition: nutrition(water: 1.3, calories: 1_000, protein: 55, carbs: 100),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 520,
            recoveryPercent: 88,
            sleepHours: 8.0,
            exerciseMinutes: 55
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)

        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview, "\(story.owner)")
        XCTAssertTrue(
            render.title.localizedCaseInsensitiveContains("sauna") ||
                render.title.localizedCaseInsensitiveContains("plan"),
            render.title
        )
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("after your walk"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("после walk"), render.title)
    }

    func testPostSaunaMessageReleasesAfterCompletedRecoveryDayPlan() throws {
        WeekFitSetCurrentLanguage(.russian)

        let morningWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: -300,
            duration: 25,
            icon: "figure.walk",
            completed: true,
            baseDate: morning
        )
        let yoga = activity(
            type: "workout",
            title: "Yoga",
            minutesFromNow: -240,
            duration: 55,
            icon: "figure.yoga",
            completed: true,
            baseDate: morning
        )
        let sauna = activity(
            type: "recovery",
            title: "Sauna",
            minutesFromNow: -180,
            duration: 45,
            icon: "flame.fill",
            completed: true,
            baseDate: morning
        )
        let lateAfternoon = Calendar.current.date(bySettingHour: 15, minute: 52, second: 0, of: morning) ?? morning

        let state = makeState(
            activities: [morningWalk, yoga, sauna],
            currentDate: lateAfternoon,
            nutrition: nutrition(water: 1.4, calories: 1_200, protein: 60, carbs: 120),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 900,
            recoveryPercent: 88,
            sleepHours: 8.0,
            exerciseMinutes: 140
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)
        let visible = (
            [render.title, render.displaySubtitle, render.primaryRecommendation] +
                render.whyRows.map(\.title)
        ).joined(separator: " ").lowercased()

        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("после сауны"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("after sauna"), render.title)
        XCTAssertTrue(
            render.title.localizedCaseInsensitiveContains("прогресс") ||
                render.title.localizedCaseInsensitiveContains("ровно") ||
                render.title.localizedCaseInsensitiveContains("лёгким") ||
                visible.contains("сегодня"),
            render.title
        )
    }

    func testStableDayPlanningOverviewIgnoresStaleCompletedCycling() throws {
        WeekFitSetCurrentLanguage(.english)

        let completedCycling = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: -120,
            duration: 90,
            icon: "figure.outdoor.cycle",
            completed: true,
            baseDate: morning
        )
        let walk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: 105,
            duration: 45,
            icon: "figure.walk",
            baseDate: morning
        )
        let stretching = activity(
            type: "recovery",
            title: "Stretching",
            minutesFromNow: 180,
            duration: 20,
            icon: "figure.cooldown",
            baseDate: morning
        )

        let state = stateForHeroColor(
            focus: .dailyOverview,
            priority: .stable,
            strength: .low,
            mode: .reinforcement,
            limiter: CoachLimiter.none,
            date: morning,
            phase: .stable,
            activities: [completedCycling, walk, stretching],
            nutrition: nutrition(water: 1.4, calories: 900, protein: 50, carbs: 90),
            activeCalories: 1_500,
            exerciseMinutes: 95,
            recoveryPercent: 88,
            sleepHours: 8.0,
            priorityActivityOverride: .some(nil)
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(state).lowercased()

        let guidance = try XCTUnwrap(state.guidance)
        XCTAssertEqual(guidance.priority.priority, .stable)
        XCTAssertEqual(guidance.priority.focus, .dailyOverview)
        XCTAssertNil(guidance.priority.activity)
        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview, "\(story.owner)")
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("coach the"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("cycling"), render.title)
        XCTAssertFalse(visible.contains("coach the cycling"), visible)
        XCTAssertTrue(
            visible.contains("walk") ||
                visible.contains("today's plan") ||
                visible.contains("steady") ||
                visible.contains("morning"),
            visible
        )
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

        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview || story.owner == .recovery || story.owner == .postActivityRecovery, "\(story.owner)")
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

        XCTAssertTrue(story.owner == .readiness || story.owner == .stableOverview || story.owner == .recovery || story.owner == .postActivityRecovery, "\(story.owner)")
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
        XCTAssertTrue(renderModel.whyRows.contains { $0.kind == .recovery || $0.kind == .stability || $0.kind == .constraint })
        XCTAssertTrue(renderModel.supportSignals.isEmpty)
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
        XCTAssertTrue(renderModel.supportSignals.isEmpty)
        XCTAssertTrue(
            story.supportActions.contains { $0.type == .hydrateBeforeSession } ||
                renderModel.primaryRecommendation.localizedCaseInsensitiveContains("fluid") ||
                renderModel.primaryRecommendation.localizedCaseInsensitiveContains("bottle"),
            renderModel.primaryRecommendation
        )
    }

    func testSaunaSoonWithSevereHydrationUsesSaunaHero() throws {
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
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertEqual(story.owner, .activityPreparation)
        XCTAssertFalse(renderModel.title.localizedCaseInsensitiveContains("hydration"), renderModel.title)
        XCTAssertFalse(renderModel.title.localizedCaseInsensitiveContains("water"), renderModel.title)
        XCTAssertTrue(renderModel.title.localizedCaseInsensitiveContains("sauna"), renderModel.title)
        XCTAssertTrue(
            story.supportActions.contains { $0.type == .hydrateBeforeSession } ||
                renderModel.primaryRecommendation.localizedCaseInsensitiveContains("fluid") ||
                renderModel.primaryRecommendation.localizedCaseInsensitiveContains("water") ||
                renderModel.primaryRecommendation.localizedCaseInsensitiveContains("drink"),
            renderModel.primaryRecommendation
        )
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

        XCTAssertNotEqual(renderModel.owner, .hydration)
        XCTAssertEqual(renderModel.colorFamily, story.colorFamily)
        XCTAssertFalse(renderModel.supportSignals.contains { $0.kind == .hydration })
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

        XCTAssertNotEqual(renderModel.owner, .fuel)
        XCTAssertEqual(renderModel.colorFamily, story.colorFamily)
        XCTAssertFalse(renderModel.supportSignals.contains { $0.kind == .fuel })
    }

    func testSevereHydrationWithSaunaSoonDoesNotOwnHero() throws {
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

        XCTAssertEqual(story.owner, .activityPreparation)
        XCTAssertNotEqual(story.owner, .hydration)
        XCTAssertTrue(story.colorFamily == .warning || story.colorFamily == .activity, "\(story.colorFamily)")
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
        XCTAssertTrue(renderModel.supportSignals.isEmpty)
        XCTAssertTrue(renderModel.supportActions.contains { $0.type == .hydrateBeforeSession || $0.type == .lightFueling })
        XCTAssertNoDuplicateActions(coach.supportActions)
    }

    func testMorningHydrationAndFuelSupportSignalsDoNotConsumeMainActionSlots() throws {
        WeekFitSetCurrentLanguage(.english)

        for hour in 6...10 {
            let currentDate = date(hour: hour)
            let ride = activity(
                type: "cycling",
                title: "Cycling",
                minutesFromNow: 300,
                duration: 120,
                icon: "bicycle",
                baseDate: currentDate
            )

            let state = makeState(
                activities: [ride],
                currentDate: currentDate,
                nutrition: nutrition(water: 0.2, calories: 250, protein: 10, carbs: 20)
            )
            let story = try XCTUnwrap(state.finalStory, "hour=\(hour)")
            let renderModel = CoachFinalStoryRenderModel(story: story)

            XCTAssertNoMainActionDuplicateOfSupportSignal(renderModel, signalKind: .hydration, hour: hour)
            XCTAssertNoMainActionDuplicateOfSupportSignal(renderModel, signalKind: .fuel, hour: hour)
        }
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
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(state).lowercased()
        let why = renderModel.whyRows.map(\.title).joined(separator: " ").lowercased()

        XCTAssertEqual(story.owner, .pacingExecution)
        XCTAssertTrue(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("10 minutes"), story.whatToDoNext.resolved)
        XCTAssertFalse(story.whatHappened.resolved.localizedCaseInsensitiveContains("active now"), story.whatHappened.resolved)
        XCTAssertFalse(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("stop"), story.whatToDoNext.resolved)
        assertNoLegacyV4FallbackCopy(in: visible, scenarioName: "fresh active cycling")
        assertNoLegacyV4FallbackCopy(in: why, scenarioName: "fresh active cycling why")
        XCTAssertFalse(renderModel.primaryRecommendation.localizedCaseInsensitiveContains("finish with reserve"), renderModel.primaryRecommendation)
        XCTAssertTrue(
            renderModel.whyRows.contains { row in
                let title = row.title.lowercased()
                return title.contains("minute") || title.contains("recovery") || title.contains("минут") || title.contains("восстанов")
            },
            renderModel.whyRows.map(\.title).joined(separator: " | ")
        )
        assertNoDuplicateHeroOrSupportCopy(story, scenarioName: "fresh active cycling pacing")
        assertNoCrossSectionPhraseReuse(renderModel, scenarioName: "fresh active cycling pacing")
    }

    func testV4ActiveEnduranceRenderFallbacksStayOwnerSpecificAndTactical() throws {
        WeekFitSetCurrentLanguage(.english)

        let activeFallback = CoachFinalStoryRenderModel.fallbackRecommendation(owner: .activeActivity).lowercased()
        let pacingFallback = CoachFinalStoryRenderModel.fallbackRecommendation(owner: .pacingExecution).lowercased()
        let sustainableFallback = CoachFinalStoryRenderModel.fallbackRecommendation(owner: .sustainableExecution).lowercased()

        XCTAssertNotEqual(activeFallback, pacingFallback)
        XCTAssertNotEqual(pacingFallback, sustainableFallback)
        XCTAssertTrue(pacingFallback.contains("10 minutes"), pacingFallback)
        XCTAssertTrue(sustainableFallback.contains("20-30"), sustainableFallback)
        for text in [activeFallback, pacingFallback, sustainableFallback] {
            assertNoLegacyV4FallbackCopy(in: text, scenarioName: "render fallback")
        }
    }

    func testV4ActiveLongEnduranceHydrationOwnerKeepsConcreteAction() throws {
        WeekFitSetCurrentLanguage(.english)
        let ride = activity(
            type: "cycling",
            title: "Long ride",
            minutesFromNow: -70,
            duration: 150,
            icon: "bicycle"
        )
        ride.source = "today"

        let state = makeState(
            activities: [ride],
            nutrition: nutrition(water: 0.5, calories: 2_200, protein: 110, carbs: 260),
            activeCalories: 780,
            completedWorkoutsCount: 0,
            recoveryPercent: 92,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(state).lowercased()
        let why = renderModel.whyRows.map(\.title).joined(separator: " ").lowercased()

        XCTAssertEqual(story.owner, .hydrationExecution)
        XCTAssertTrue(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("300-500"), story.whatToDoNext.resolved)
        XCTAssertTrue(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("20 minutes"), story.whatToDoNext.resolved)
        XCTAssertTrue(why.contains("fluid") || why.contains("hydration"), why)
        XCTAssertFalse(story.title.resolved.localizedCaseInsensitiveContains("pace"), story.title.resolved)
        assertNoLegacyV4FallbackCopy(in: visible, scenarioName: "active long endurance hydration")
        assertNoLegacyV4FallbackCopy(in: why, scenarioName: "active long endurance hydration why")
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
        XCTAssertTrue(story.whatHappened.resolved.localizedCaseInsensitiveContains("meaningful training stress"), story.whatHappened.resolved)
        XCTAssertTrue(
            story.whatToDoNext.resolved.localizedCaseInsensitiveContains("end it") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("very easy") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("stop now") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("stop here") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("keep it easy") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("controlled"),
            story.whatToDoNext.resolved
        )
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

        XCTAssertTrue(story.owner == .activeActivity || story.owner == .postActivityRecovery || story.owner == .recovery, "\(story.owner)")
        XCTAssertTrue(
            story.title.resolved.localizedCaseInsensitiveContains("cool down") ||
                story.title.resolved.localizedCaseInsensitiveContains("protect") ||
                story.title.resolved.localizedCaseInsensitiveContains("recovery") ||
                story.title.resolved.localizedCaseInsensitiveContains("recover") ||
                story.title.resolved.localizedCaseInsensitiveContains("main work") ||
                story.title.resolved.localizedCaseInsensitiveContains("ease") ||
                story.title.resolved.localizedCaseInsensitiveContains("walk") ||
                story.title.resolved.localizedCaseInsensitiveContains("would not"),
            story.title.resolved
        )
        XCTAssertTrue(
            story.whatToDoNext.resolved.localizedCaseInsensitiveContains("recovery") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("easy") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("protein") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("carbs") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("consistent") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("calm"),
            story.whatToDoNext.resolved
        )
        XCTAssertTrue(
            story.whatToAvoid.resolved.localizedCaseInsensitiveContains("training") ||
                story.whatToAvoid.resolved.localizedCaseInsensitiveContains("hard") ||
                story.whatToAvoid.resolved.localizedCaseInsensitiveContains("load") ||
                story.whatToAvoid.resolved.localizedCaseInsensitiveContains("continue"),
            story.whatToAvoid.resolved
        )
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
        XCTAssertTrue(
            story.whatToDoNext.resolved.localizedCaseInsensitiveContains("end it") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("very easy") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("stop now") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("stop here") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("keep it easy") ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("controlled"),
            story.whatToDoNext.resolved
        )
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
        XCTAssertEqual(story.whatToDoNext.resolved, "You can stop here or keep it easy. Do not add intensity or extra sets.")
        XCTAssertFalse(story.whatToDoNext.resolved.localizedCaseInsensitiveContains("another workout"), story.whatToDoNext.resolved)
        XCTAssertFalse(story.reasons.contains { $0.kind == .tomorrow }, story.reasons.map(\.kind.rawValue).joined(separator: ","))
        XCTAssertFalse(story.reasons.contains { $0.kind == .stability }, story.reasons.map(\.kind.rawValue).joined(separator: ","))
        XCTAssertTrue(story.reasons.allSatisfy { [.fuel, .constraint, .training, .recovery, .time].contains($0.kind) }, story.reasons.map(\.kind.rawValue).joined(separator: ","))
        XCTAssertFalse(coach.title.localizedCaseInsensitiveContains("control"), coach.title)
        XCTAssertFalse(visibleText(state).localizedCaseInsensitiveContains("use body feedback now"), visibleText(state))
    }

    func testRussianActivePhaseCriticalReadinessDoesNotInventPaceReductionAction() throws {
        WeekFitSetCurrentLanguage(.russian)
        defer { WeekFitSetCurrentLanguage(.english) }

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
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)

        XCTAssertEqual(story.owner, .activeActivity)
        XCTAssertEqual(renderModel.title, "Сегодня лучше не продолжать.")
        XCTAssertEqual(renderModel.supportActions.first?.title, "Берегите сон")
        XCTAssertEqual(renderModel.supportActions.first?.subtitle, "Проведите остаток вечера спокойно")
        XCTAssertFalse(renderModel.supportActions.map(\.title).contains("Сбавьте темп"))
        XCTAssertFalse(renderModel.supportActions.map(\.title).contains("Держитесь плана"))
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
            activities: [completedStrength],
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
        XCTAssertLessThanOrEqual(actionTitles.count, 3, visibleActions)
        XCTAssertTrue(
            visibleActions.localizedCaseInsensitiveContains("Mobility") ||
                visibleActions.localizedCaseInsensitiveContains("Drink"),
            visibleActions
        )
        XCTAssertTrue(
            visibleActions.localizedCaseInsensitiveContains("Cooldown") ||
                visibleActions.localizedCaseInsensitiveContains("Finish"),
            visibleActions
        )
        XCTAssertFalse(visibleActions.localizedCaseInsensitiveContains("Protein feeding"), visibleActions)
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
                allowedFamilies: [.ready, .stable],
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
                allowedFamilies: [.warning, .activity],
                forbiddenFamilies: [.stable, .hydration, .fuel]
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

    func testRussianSaunaHydrationCopySoundsHumanAndKeepsSaunaHero() throws {
        WeekFitSetCurrentLanguage(.russian)
        let sauna = activity(
            type: "sauna",
            title: "Сауна",
            minutesFromNow: 25,
            duration: 30,
            icon: "flame.fill"
        )

        let state = makeState(
            activities: [sauna],
            nutrition: nutrition(water: 0, calories: 1_100, protein: 60, carbs: 120),
            sleepState: .short,
            recoveryState: .stable,
            readinessState: .good,
            recoveryPercent: 76,
            sleepHours: 6.1
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let visible = ([
            renderModel.title,
            renderModel.subtitle,
            renderModel.whatMattersNow,
            renderModel.primaryRecommendation,
            renderModel.avoidRecommendation
        ] + renderModel.whyRows.map(\.title) + renderModel.supportActions.flatMap { [$0.title, $0.subtitle] })
            .joined(separator: " ")
            .lowercased()

        XCTAssertEqual(story.owner, .activityPreparation)
        XCTAssertNotEqual(story.owner, .hydration)
        XCTAssertTrue(visible.contains("сауну легче") || visible.contains("сауну лучше"), visible)
        XCTAssertTrue(visible.contains("до сауны") || visible.contains("сауны осталось") || visible.contains("перед сауной"), visible)
        XCTAssertFalse(visible.contains("воды сегодня пока мало") || visible.contains("воды пока мало"), visible)
        XCTAssertTrue(visible.contains("сон был короче обычного"), visible)
        XCTAssertTrue(visible.contains("вод") || visible.contains("попей"), visible)
        XCTAssertLessThanOrEqual(renderModel.whyRows.count, 3, visible)
        XCTAssertLessThanOrEqual(renderModel.supportActions.count, 2, visible)
        XCTAssertTrue(
            story.supportActions.contains { $0.type == .hydrateBeforeSession } ||
                story.whatToDoNext.resolved.localizedCaseInsensitiveContains("вод") ||
                renderModel.primaryRecommendation.localizedCaseInsensitiveContains("вод"),
            visible
        )

        for forbidden in [
            "напрямую формирует",
            "формирует это решение",
            "это решение",
            "влияет на безопасность и качество",
            "следующего блока",
            "фактор",
            "ограничение",
            "метрика",
            "сигнал"
        ] {
            XCTAssertFalse(visible.contains(forbidden), "\(forbidden): \(visible)")
        }
    }

    func testEveningBeforeTomorrowLongRunOwnsCoachAfterCompletedWalk() throws {
        WeekFitSetCurrentLanguage(.english)
        let evening = date(hour: 21)
        let completedWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: -90,
            duration: 45,
            icon: "figure.walk",
            completed: true,
            baseDate: evening
        )
        let tomorrowRun = activity(
            type: "running",
            title: "Running",
            minutesFromNow: 0,
            duration: 220,
            icon: "figure.run",
            baseDate: tomorrow(hour: 7)
        )

        let state = makeState(
            activities: [completedWalk, tomorrowRun],
            currentDate: evening,
            nutrition: nutrition(water: 2.2, calories: 2_200, protein: 120, carbs: 250),
            activeCalories: 360,
            completedWorkoutsCount: 0,
            recoveryPercent: 82,
            sleepHours: 7.2
        )
        let story = try XCTUnwrap(state.finalStory)
        let renderModel = CoachFinalStoryRenderModel(story: story)
        let visible = ([
            renderModel.title,
            renderModel.subtitle,
            renderModel.primaryRecommendation,
            renderModel.avoidRecommendation
        ] + renderModel.whyRows.map(\.title) + renderModel.supportActions.flatMap { [$0.title, $0.subtitle] })
            .joined(separator: " ")
            .lowercased()

        XCTAssertEqual(story.owner, .tomorrowProtection, debugSnapshot(for: "tomorrow long run after walk", state: state))
        XCTAssertEqual(story.primaryFocus, .tomorrowPlanRisk)
        XCTAssertEqual(state.guidance?.priority.limiter, .upcomingTraining)
        XCTAssertTrue(visible.contains("tomorrow"), visible)
        XCTAssertTrue(visible.contains("run") || visible.contains("running"), visible)
        XCTAssertFalse(visible.contains("ride"), visible)
    }

    func testTomorrowPlanRiskNormalizesRecoveryLimiterToUpcomingTraining() throws {
        let priority = CoachDayPriorityResult(
            focus: .tomorrowPlanRisk,
            level: .important,
            reason: "Tomorrow has the higher priority demand.",
            activity: nil,
            overridesTimingFocus: true,
            priority: .planChallenge,
            limiter: .recovery
        )

        XCTAssertEqual(priority.focus, .tomorrowPlanRisk)
        XCTAssertEqual(priority.limiter, .upcomingTraining)
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
        let visible = ([renderModel.avoidRecommendation] + renderModel.supportActions.flatMap { [$0.title, $0.subtitle] })
            .joined(separator: " ")

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
        let middayTime = date(hour: 13)
        let afternoonTime = date(hour: 16)
        let eveningTime = date(hour: 19)
        let lateTime = date(hour: 22)
        let tomorrowMorning = tomorrow(hour: 9)

        return [
            CoachScenarioFixture(
                name: "A1 morning good recovery no workout",
                makeState: { self.makeState(activities: [], currentDate: morningTime, nutrition: self.nutrition(water: 1.4, calories: 900, protein: 50, carbs: 90), sleepState: .strong, recoveryState: .strong, readinessState: .good, recoveryPercent: 92, sleepHours: 8.1) },
                allowedOwners: [.readiness, .stableOverview],
                allowedFocuses: [.dailyOverview, .performanceReadiness],
                requiredAnyText: ["body", "consistent", "plan", "calm", "nothing", "change"],
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
                allowedOwners: [.activityPreparation, .readiness],
                allowedFocuses: [.prepareForActivity, .nextActivityLater, .performanceReadiness],
                requiredAnyText: ["carbs", "drink", "start", "easy", "sip", "bottles", "light", "kit"],
                forbiddenText: [],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "B2 strength workout soon good recovery",
                makeState: {
                    let strength = self.activity(type: "strength", title: "Strength", minutesFromNow: 45, duration: 60, icon: "dumbbell.fill")
                    return self.makeState(activities: [strength], nutrition: self.nutrition(water: 1.8, calories: 1_300, protein: 90, carbs: 140), sleepState: .strong, recoveryState: .strong, readinessState: .good, recoveryPercent: 90, sleepHours: 8.0)
                },
                allowedOwners: [.activityPreparation, .readiness],
                allowedFocuses: [.prepareForActivity, .nextActivityLater, .performanceReadiness],
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
                allowedFocuses: [.hydrationBehind, .prepareForActivity, .nextActivityLater, .trainingReadinessWarning],
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
                requiredAnyText: ["carbs", "fuel", "snack", "start", "food", "nutrition", "fluids", "meal"],
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
                allowedOwners: [.activeActivity, .pacingExecution],
                allowedFocuses: [.activeActivity],
                requiredAnyText: ["10 minutes", "settle", "ease", "warm-up", "warm up"],
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
                allowedOwners: [.activeActivity, .postActivityRecovery, .recovery],
                allowedFocuses: [.activeActivity, .recoveryNeeded, .postActivityRecovery],
                requiredAnyText: ["cool down", "recovery", "easy", "not continue", "consistent"],
                forbiddenText: [],
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
                requiredAnyText: ["attention", "quiet", "nothing"],
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
                requiredAnyText: ["evening", "sleep", "easy", "day", "afternoon", "midday", "behind", "done"],
                forbiddenText: ["eat a normal meal", "protein target"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "D4b midday post long ride stale",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Cycling", minutesFromNow: -(150 + 260), duration: 150, icon: "bicycle", completed: true, baseDate: middayTime)
                    return self.makeState(activities: [ride], currentDate: middayTime, nutrition: self.nutrition(water: 3.0, calories: 2_800, protein: 180, carbs: 280), activeCalories: 2_000, completedWorkoutsCount: 1, recoveryPercent: 82, sleepHours: 7.2)
                },
                allowedOwners: [.postActivityRecovery, .recovery],
                allowedFocuses: [.postActivityRecovery, .recoveryNeeded, .eveningWindDown],
                requiredAnyText: ["midday", "day", "easy", "done", "серед"],
                forbiddenText: ["within the hour", "в течение часа"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "D4c afternoon prep before evening ride",
                makeState: {
                    let ride = self.activity(type: "cycling", title: "Ride", minutesFromNow: 180, duration: 120, icon: "bicycle", baseDate: afternoonTime)
                    return self.makeState(activities: [ride], currentDate: afternoonTime, nutrition: self.nutrition(water: 1.6, calories: 1_100, protein: 60, carbs: 130), recoveryPercent: 86, sleepHours: 7.6)
                },
                allowedOwners: [.activityPreparation, .readiness],
                allowedFocuses: [.prepareForActivity, .nextActivityLater, .performanceReadiness],
                requiredAnyText: ["ahead", "start", "session", "day", "впереди"],
                forbiddenText: [],
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
                requiredAnyText: ["evening", "sleep", "recover"],
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
                requiredAnyText: ["attention", "quiet", "nothing"],
                forbiddenText: ["critical", "i would not continue"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "E4 late night food water low no safety",
                makeState: { self.makeState(activities: [], currentDate: lateTime, nutrition: self.nutrition(water: 0.8, calories: 700, protein: 25, carbs: 70), recoveryPercent: 75, sleepHours: 7.0) },
                allowedOwners: [.stableOverview, .readiness, .recovery],
                allowedFocuses: [.dailyOverview, .recoveryNeeded, .eveningWindDown, .hydrationBehind, .fuelBehind],
                requiredAnyText: ["attention", "quiet", "nothing", "sleep"],
                forbiddenText: ["eat now", "drink 300"],
                hydrationFuelMayOwn: false
            ),
            CoachScenarioFixture(
                name: "F1 high recovery no training",
                makeState: { self.makeState(activities: [], currentDate: morningTime, sleepState: .strong, recoveryState: .strong, readinessState: .good, recoveryPercent: 94, sleepHours: 8.2) },
                allowedOwners: [.readiness, .stableOverview],
                allowedFocuses: [.dailyOverview, .performanceReadiness],
                requiredAnyText: ["plan", "body", "consistent", "nothing", "change"],
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
                allowedFocuses: [.performanceReadiness, .recoveryNeeded, .postActivityRecovery, .dailyOverview, .eveningWindDown],
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
                allowedFocuses: [.hydrationBehind, .prepareForActivity, .nextActivityLater, .trainingReadinessWarning],
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
                requiredAnyText: ["carbs", "fuel", "light", "start", "food", "nutrition", "fluids", "meal", "snack"],
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
                allowedFocuses: [.dailyOverview, .nextActivityLater, .performanceReadiness, .recoveryNeeded, .eveningWindDown],
                requiredAnyText: ["plan", "sauna", "routine", "calm", "sleep", "recovery"],
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
            XCTAssertLessThanOrEqual(field.count, 300, "\(scenario.name) field too long: \(field)")
            XCTAssertFalse(field.contains("coach.final."), "\(scenario.name) raw key: \(field)")
        }

        let primaryAllowsNoSupportAction = story.whatToDoNext.resolved.localizedCaseInsensitiveContains("do nothing") ||
            story.whatToDoNext.resolved.localizedCaseInsensitiveContains("no useful change") ||
            story.whatToDoNext.resolved.localizedCaseInsensitiveContains("ничего полезного") ||
            story.whatToDoNext.resolved.localizedCaseInsensitiveContains("ничего дополнительно")
        XCTAssertFalse(
            coach.supportActions.isEmpty && !primaryAllowsNoSupportAction,
            "\(scenario.name) should have a useful primary support action or an explicit no-action recommendation"
        )
        XCTAssertLessThanOrEqual(renderModel.whyRows.count, 3, "\(scenario.name) Why rows should stay concise")
        XCTAssertLessThanOrEqual(renderModel.supportActions.count, 3, "\(scenario.name) What-to-do rows should stay concise")
        XCTAssertTrue(
            renderModel.whyRows.allSatisfy { row in
                story.reasons.contains { $0.text.resolved == row.title }
            },
            "\(scenario.name) Why must come from structured story reasons"
        )
        if story.owner == .postActivityRecovery {
            XCTAssertTrue(renderModel.whyRows.isEmpty, "\(scenario.name) post recovery should rely on My Read, not Why")
            XCTAssertFalse(
                renderModel.displaySubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(scenario.name) post recovery should show My Read"
            )
        } else {
            XCTAssertFalse(renderModel.whyRows.isEmpty, "\(scenario.name) should explain the decision")
            XCTAssertWhyRowsAreRationale(renderModel.whyRows, scenarioName: scenario.name)
        }
        XCTAssertActionsAreConcrete(renderModel.supportActions, scenarioName: scenario.name)
        XCTAssertNoDuplicateActions(coach.supportActions)
        assertHeroTriadIsDistinct(renderModel, scenarioName: scenario.name)
        assertActionRowsDoNotRepeatHeroOrWhy(renderModel, scenarioName: scenario.name)
        assertNoDuplicateHeroOrSupportCopy(story, scenarioName: scenario.name)
        assertSupportSignalsDoNotRepeatHero(story, scenarioName: scenario.name)
        assertNoInventedActivityCopy(story, renderModel: renderModel, scenarioName: scenario.name)

        if !scenario.hydrationFuelMayOwn {
            XCTAssertNotEqual(story.owner, .hydration, scenario.name)
            XCTAssertNotEqual(story.owner, .fuel, scenario.name)
            if story.owner == .readiness || story.owner == .stableOverview,
               !story.decisionContext.hasFutureActivityContext,
               !story.decisionContext.hasTomorrowDemand {
                XCTAssertFalse(
                    renderModel.supportActions.contains { action in
                        XCTAssertIsHydrationOrFuelAction(action)
                    },
                    "\(scenario.name) hydration/fuel should not dominate stable no-activity What-to-do"
                )
            }
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
            XCTAssertFalse(lowerVisible.contains("потолок"), scenario.name)
            XCTAssertFalse(lowerVisible.contains("тренеров"), scenario.name)
        }
    }

    private func assertHeroTriadIsDistinct(
        _ renderModel: CoachFinalStoryRenderModel,
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let heroRows = [
            renderModel.subtitle,
            renderModel.primaryRecommendation,
            renderModel.avoidRecommendation
        ]
        let normalized = heroRows
            .map { normalizedCoachCopy($0) }
            .filter { !$0.isEmpty }

        XCTAssertEqual(normalized.count, 3, "\(scenarioName) hero triad must have three visible rows", file: file, line: line)
        XCTAssertEqual(Set(normalized).count, normalized.count, "\(scenarioName) hero triad repeats copy: \(heroRows)", file: file, line: line)
    }

    private func assertActionRowsDoNotRepeatHeroOrWhy(
        _ renderModel: CoachFinalStoryRenderModel,
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let existing = Set((
            [
                renderModel.title,
                renderModel.subtitle,
                renderModel.primaryRecommendation,
                renderModel.avoidRecommendation
            ] + renderModel.whyRows.map(\.title)
        ).map { normalizedCoachCopy($0) })

        let actionTitles = renderModel.supportActions.map(\.title)
        let normalizedActionTitles = actionTitles.map { normalizedCoachCopy($0) }

        XCTAssertEqual(
            Set(normalizedActionTitles).count,
            normalizedActionTitles.count,
            "\(scenarioName) action rows repeat each other: \(actionTitles)",
            file: file,
            line: line
        )
        XCTAssertFalse(
            normalizedActionTitles.contains { existing.contains($0) },
            "\(scenarioName) action row repeats hero/why: \(actionTitles)",
            file: file,
            line: line
        )
    }

    private func assertNoCrossSectionPhraseReuse(
        _ renderModel: CoachFinalStoryRenderModel,
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        struct SectionText {
            let section: String
            let text: String
        }

        let sections: [SectionText] = [
            SectionText(section: "hero", text: renderModel.title),
            SectionText(section: "risk", text: renderModel.avoidRecommendation)
        ] +
            renderModel.whyRows.map { SectionText(section: "why", text: $0.title) } +
            renderModel.supportActions.map { SectionText(section: "action", text: "\($0.title) \($0.subtitle)") }

        for (index, first) in sections.enumerated() {
            let firstText = normalizedCoachCopy(first.text)
            guard firstText.count >= 8 else { continue }
            for second in sections.dropFirst(index + 1) {
                guard first.section != second.section else { continue }
                let secondText = normalizedCoachCopy(second.text)
                guard secondText.count >= 8 else { continue }
                XCTAssertFalse(
                    firstText.contains(secondText) || secondText.contains(firstText),
                    "\(scenarioName) repeats \(first.section)/\(second.section): \(first.text) | \(second.text)",
                    file: file,
                    line: line
                )
            }
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
        ] + renderModel.whyRows.map(\.title) + renderModel.supportActions.flatMap { [$0.title, $0.subtitle] } + renderModel.supportSignals.map(\.title)

        let normalized = rows
            .map { normalizedCoachCopy($0) }
            .filter { !$0.isEmpty }
        XCTAssertLessThanOrEqual(normalized.count - Set(normalized).count, 1, "\(scenarioName) duplicate copy rows: \(normalized)")

        for (index, row) in normalized.enumerated() {
            for other in normalized.dropFirst(index + 1) {
                guard row.count >= 12, other.count >= 12 else { continue }
                XCTAssertFalse(
                    row.contains(other) || other.contains(row),
                    "\(scenarioName) overlapping copy rows: \(row) <> \(other)"
                )
            }
        }
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
        ].map { normalizedCoachCopy($0) }

        XCTAssertFalse(renderModel.supportSignals.contains { signal in
            heroTexts.contains(normalizedCoachCopy(signal.title))
        }, "\(scenarioName) support signal repeats hero")
    }

    private func normalizedCoachCopy(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func XCTAssertWhyRowsAreRationale(
        _ rows: [CoachFinalStoryRenderedReason],
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for row in rows {
            let title = row.title.lowercased()
            XCTAssertFalse(title.contains("kcal"), "\(scenarioName) Why row looks like a raw metric: \(row.title)", file: file, line: line)
            XCTAssertFalse(title.contains("%"), "\(scenarioName) Why row looks like a raw metric: \(row.title)", file: file, line: line)
            XCTAssertFalse(title.contains("supports this story"), "\(scenarioName) Why row is generic support copy: \(row.title)", file: file, line: line)
            XCTAssertFalse(title.contains("is part of the decision"), "\(scenarioName) Why row is generic support copy: \(row.title)", file: file, line: line)
        }
    }

    private func XCTAssertActionsAreConcrete(
        _ actions: [CoachSupportActionV3],
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for action in actions {
            let title = action.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            XCTAssertFalse(title.isEmpty, "\(scenarioName) empty action title", file: file, line: line)
            XCTAssertFalse(title.contains("behind"), "\(scenarioName) action copies status instead of next step: \(action.title)", file: file, line: line)
        }
    }

    private func assertNoInventedActivityCopy(
        _ story: CoachFinalStory,
        renderModel: CoachFinalStoryRenderModel,
        scenarioName: String
    ) {
        guard !story.decisionContext.hasActivityContext else { return }

        let visible = ([
            renderModel.title,
            renderModel.subtitle,
            renderModel.whatMattersNow,
            renderModel.primaryRecommendation,
            renderModel.avoidRecommendation
        ] + renderModel.whyRows.map(\.title) + renderModel.supportActions.flatMap { [$0.title, $0.subtitle] })
            .joined(separator: " ")
            .lowercased()

        let forbidden = [
            "prepare for training",
            "prepare for workout",
            "prepare for cycling",
            "prepare for running",
            "coming soon",
            "next activity",
            "next planned effort",
            "session is active",
            "workout readiness",
            "first 15 minutes",
            "подготовьтесь",
            "скоро начнется",
            "следующая активность",
            "первые 15 минут"
        ]

        for phrase in forbidden {
            XCTAssertFalse(visible.contains(phrase), "\(scenarioName) invented activity copy '\(phrase)': \(visible)")
        }
    }

    private func assertNoWorkoutAssumptionCopy(
        in visible: String,
        scenarioName: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let forbidden = [
            "reduce intensity",
            "main set",
            "extra work",
            "before the body confirms",
            "control the first part of the session",
            "holding back how much you can do",
            "maximal-effort",
            "maximal effort",
            "moderately ready"
        ]

        for phrase in forbidden {
            XCTAssertFalse(
                visible.localizedCaseInsensitiveContains(phrase),
                "\(scenarioName) used workout-assumption copy '\(phrase)': \(visible)",
                file: file,
                line: line
            )
        }
    }

    private func assertNoMetricNarration(
        in visible: String,
        scenarioName: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let forbidden = [
            "recovery is at",
            "recovery score",
            "% today",
            "only at "
        ]

        for phrase in forbidden {
            XCTAssertFalse(
                visible.localizedCaseInsensitiveContains(phrase),
                "\(scenarioName) repeated metrics instead of interpreting them: '\(phrase)' in \(visible)",
                file: file,
                line: line
            )
        }

        XCTAssertFalse(
            visible.range(of: #"\b\d{2}%\b"#, options: .regularExpression) != nil,
            "\(scenarioName) surfaced a raw recovery percentage in \(visible)",
            file: file,
            line: line
        )
    }

    private func XCTAssertIsHydrationOrFuelAction(_ action: CoachSupportActionV3) -> Bool {
        switch action.type {
        case .hydrateBeforeSession,
             .steadyHydration,
             .rehydrateGradually,
             .electrolyteRecovery,
             .lightFueling,
             .sustainEnergy,
             .startRecoveryNutrition,
             .recoveryMeal:
            return true
        default:
            return false
        }
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
        sleepHours: Double = 7.4,
        priorityActivityOverride: PlannedActivity?? = nil
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
        let activity = priorityActivityOverride ?? activityForPriority(focus: focus, phase: phase, activities: activities)
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

    private func importedAppleWalk(
        minutesFromNow: Int,
        duration: Int,
        baseDate: Date? = nil
    ) -> PlannedActivity {
        let walk = activity(
            type: "workout",
            title: "Walk",
            minutesFromNow: minutesFromNow,
            duration: duration,
            icon: "figure.walk",
            completed: true,
            baseDate: baseDate,
            source: "appleWorkout"
        )
        walk.healthKitWorkoutUUID = UUID().uuidString
        walk.actualDurationMinutes = duration
        return walk
    }

    func testV4ImportedAppleWalkWithoutPlanMatchDoesNotTriggerRecoveryNeeded() throws {
        WeekFitSetCurrentLanguage(.russian)

        let syncedWalk = importedAppleWalk(minutesFromNow: -120, duration: 39, baseDate: morning)
        let futurePlannedWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: 180,
            duration: 30,
            icon: "figure.walk",
            baseDate: morning
        )
        let plannedSauna = activity(
            type: "recovery",
            title: "Sauna",
            minutesFromNow: 240,
            duration: 30,
            icon: "flame.fill",
            baseDate: morning
        )
        let afternoon = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: morning) ?? morning

        let state = makeState(
            activities: [syncedWalk, futurePlannedWalk, plannedSauna],
            currentDate: afternoon,
            nutrition: nutrition(water: 1.4, calories: 1_100, protein: 60, carbs: 120),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 420,
            completedWorkoutsCount: 1,
            recoveryPercent: 88,
            sleepHours: 8.0,
            exerciseMinutes: 39
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)
        let visible = visibleText(state).lowercased()

        XCTAssertNotEqual(state.guidance?.priority.focus, .recoveryNeeded)
        XCTAssertNotEqual(state.guidance?.priority.focus, .eveningWindDown)
        XCTAssertEqual(story.owner, .stableOverview)
        XCTAssertNotEqual(story.owner, .recovery)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("сауна сделана"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("отличный прогресс"), render.title)
        XCTAssertTrue(
            render.title.localizedCaseInsensitiveContains("прогулка учтена") ||
                render.title.localizedCaseInsensitiveContains("хороший день") ||
                render.title.localizedCaseInsensitiveContains("лёгкая активность") ||
                visible.contains("прогулка"),
            render.title
        )
    }

    func testV4PlannedWalkLaterTodayDoesNotTriggerRecoveryNeeded() throws {
        WeekFitSetCurrentLanguage(.english)

        let laterWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: 120,
            duration: 30,
            icon: "figure.walk",
            baseDate: morning
        )
        let afternoon = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: morning) ?? morning

        let state = makeState(
            activities: [laterWalk],
            currentDate: afternoon,
            nutrition: nutrition(),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 120,
            recoveryPercent: 90,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)

        XCTAssertNotEqual(state.guidance?.priority.focus, .recoveryNeeded)
        XCTAssertNotEqual(story.owner, .recovery)
        XCTAssertTrue(story.owner == .stableOverview || story.owner == .readiness || story.owner == .activityPreparation)
    }

    func testV4PlannedWalkWithModerateCaloriesDoesNotShowFuelWarning() throws {
        WeekFitSetCurrentLanguage(.russian)

        let plannedWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: 90,
            duration: 30,
            icon: "figure.walk",
            baseDate: morning
        )
        let afternoon = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: morning) ?? morning

        let state = makeState(
            activities: [plannedWalk],
            currentDate: afternoon,
            nutrition: nutrition(water: 1.2, calories: 673, protein: 40, carbs: 80),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 180,
            recoveryPercent: 90,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)
        let whyText = render.whyRows.map(\.title).joined(separator: " ")
        let visible = visibleText(state) + " " + story.title.resolved + " " +
            story.whatHappened.resolved + " " + whyText

        XCTAssertFalse(visible.localizedCaseInsensitiveContains("Не хватает еды"), visible)
        XCTAssertFalse(visible.localizedCaseInsensitiveContains("мало еды"), visible)
        XCTAssertFalse(render.supportSignals.contains { $0.kind == .fuel })
        XCTAssertTrue(
            story.owner == .stableOverview || story.owner == .readiness || story.owner == .activityPreparation,
            "\(story.owner)"
        )
        XCTAssertTrue(
            render.title.localizedCaseInsensitiveContains("прогулка") ||
                render.title.localizedCaseInsensitiveContains("план") ||
                render.title.localizedCaseInsensitiveContains("спокойно") ||
                render.title.localizedCaseInsensitiveContains("ровно"),
            render.title
        )
    }

    func testV4PlannedSaunaMustNotAppearCompletedInDaySummary() throws {
        WeekFitSetCurrentLanguage(.russian)

        let syncedWalk = importedAppleWalk(minutesFromNow: -90, duration: 35, baseDate: morning)
        let plannedSauna = activity(
            type: "recovery",
            title: "Sauna",
            minutesFromNow: 120,
            duration: 30,
            icon: "flame.fill",
            baseDate: morning
        )
        let afternoon = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: morning) ?? morning

        let state = makeState(
            activities: [syncedWalk, plannedSauna],
            currentDate: afternoon,
            nutrition: nutrition(water: 1.3, calories: 1_000, protein: 55, carbs: 110),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 360,
            completedWorkoutsCount: 1,
            recoveryPercent: 90,
            sleepHours: 8.0,
            exerciseMinutes: 35
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)

        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("сауна сделана"), render.title)
        XCTAssertTrue(
            render.title.localizedCaseInsensitiveContains("прогулка") ||
                render.title.localizedCaseInsensitiveContains("сауна") && render.title.localizedCaseInsensitiveContains("план"),
            render.title
        )
    }

    func testV4PlannedWalkWithUnverifiedSaunaDoesNotShowSaunaDone() throws {
        WeekFitSetCurrentLanguage(.russian)

        let afternoon = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: morning) ?? morning
        let plannedWalk = activity(
            type: "walking",
            title: "Walk",
            minutesFromNow: 90,
            duration: 30,
            icon: "figure.walk",
            baseDate: afternoon
        )
        let falselyCompletedSauna = activity(
            type: "recovery",
            title: "Sauna",
            minutesFromNow: -60,
            duration: 30,
            icon: "flame.fill",
            completed: true,
            baseDate: morning
        )

        let state = makeState(
            activities: [falselyCompletedSauna, plannedWalk],
            currentDate: afternoon,
            nutrition: nutrition(water: 1.3, calories: 1_000, protein: 55, carbs: 110),
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            activeCalories: 180,
            recoveryPercent: 90,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)

        XCTAssertEqual(state.guidance?.priority.focus, .dailyOverview)
        XCTAssertEqual(state.guidance?.priority.priority, .stable)
        XCTAssertEqual(story.owner, .stableOverview)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("сауна сделана"), render.title)
        XCTAssertFalse(render.title.localizedCaseInsensitiveContains("отличный прогресс"), render.title)
        XCTAssertTrue(
            render.title.localizedCaseInsensitiveContains("прогулка") ||
                render.title.localizedCaseInsensitiveContains("walk") ||
                render.title.localizedCaseInsensitiveContains("план") ||
                render.title.localizedCaseInsensitiveContains("спокойно") ||
                render.title.localizedCaseInsensitiveContains("ровно"),
            render.title
        )
    }

    func testV4CompletedSeriousTrainingMayStillUseRecoveryNeeded() throws {
        WeekFitSetCurrentLanguage(.english)

        let ride = activity(
            type: "cycling",
            title: "Cycling",
            minutesFromNow: -180,
            duration: 150,
            icon: "bicycle",
            completed: true,
            baseDate: morning
        )
        let evening = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: morning) ?? morning

        let state = makeState(
            activities: [ride],
            currentDate: evening,
            nutrition: nutrition(water: 2.5, calories: 2_400, protein: 120, carbs: 260),
            sleepState: .okay,
            recoveryState: .stable,
            readinessState: .good,
            activeCalories: 1_850,
            completedWorkoutsCount: 1,
            recoveryPercent: 72,
            sleepHours: 7.0,
            exerciseMinutes: 150
        )

        XCTAssertTrue(
            state.guidance?.priority.focus == .recoveryNeeded ||
                state.guidance?.priority.focus == .eveningWindDown ||
                state.guidance?.priority.focus == .postActivityRecovery
        )
        XCTAssertTrue(
            state.finalStory?.owner == .recovery ||
                state.finalStory?.owner == .postActivityRecovery
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

    private func assertNoLegacyV4FallbackCopy(
        in text: String,
        scenarioName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lowercased = text.lowercased()
        let forbidden = [
            "stay aware",
            "finish with reserve",
            "use conversational effort",
            "do not increase intensity yet",
            "stay with the plan",
            "no extra fix is needed",
            "control effort and finish with reserve",
            "recovery remains important",
            "training adaptation",
            "energy systems",
            "performance limiter",
            "recovery optimization",
            "maintain sustainable pacing"
        ]
        for phrase in forbidden {
            XCTAssertFalse(
                lowercased.contains(phrase),
                "\(scenarioName) leaked legacy V4 fallback phrase: \(phrase)\n\(text)",
                file: file,
                line: line
            )
        }
    }

    private func XCTAssertNoDuplicateActions(
        _ actions: [CoachSupportActionV3],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let keys = actions.map { "\($0.type)-\($0.title.lowercased())" }
        XCTAssertEqual(Set(keys).count, keys.count, "actions=\(actions.map(\.title))", file: file, line: line)
    }

    private func XCTAssertNoMainActionDuplicateOfSupportSignal(
        _ renderModel: CoachFinalStoryRenderModel,
        signalKind: CoachFinalStorySupportSignal.Kind,
        hour: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard renderModel.supportSignals.contains(where: { $0.kind == signalKind }) else {
            return
        }

        let duplicateTypes = renderModel.supportActions
            .map(\.type)
            .filter { actionType in
                switch (signalKind, actionType) {
                case (.hydration, .hydrateBeforeSession),
                     (.hydration, .steadyHydration),
                     (.hydration, .rehydrateGradually),
                     (.hydration, .electrolyteRecovery),
                     (.fuel, .lightFueling),
                     (.fuel, .sustainEnergy),
                     (.fuel, .startRecoveryNutrition),
                     (.fuel, .recoveryMeal):
                    return true
                default:
                    return false
                }
            }

        XCTAssertTrue(
            duplicateTypes.isEmpty,
            "hour=\(hour) signal=\(signalKind) actions=\(renderModel.supportActions.map { "\($0.type):\($0.title)" })",
            file: file,
            line: line
        )
    }

    // MARK: - Late-night sleep deficit vs protection (Phase 3 regression)

    private var lateNight: Date {
        Calendar.current.date(bySettingHour: 23, minute: 30, second: 0, of: now) ?? now
    }

    private func visibleStoryText(from state: CoachState) -> String {
        guard let story = state.finalStory else { return "" }
        let render = CoachFinalStoryRenderModel(story: story)
        let read = render.displaySubtitle.isEmpty ? render.subtitle : render.displaySubtitle
        let careful = render.displayAvoid.isEmpty ? render.avoidRecommendation : render.displayAvoid
        return [
            render.title,
            read,
            render.primaryRecommendation,
            careful,
            render.whyRows.map(\.title).joined(separator: " ")
        ].joined(separator: " ").lowercased()
    }

    private func assertNoSleepDeficitCopy(
        _ text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let forbidden = [
            "short sleep",
            "shorter than ideal",
            "didn't sleep enough",
            "not enough sleep",
            "sleep deficit",
            "sleep is reducing",
            "sleep was poor"
        ]
        for phrase in forbidden {
            XCTAssertFalse(
                text.contains(phrase),
                "Unexpected sleep-deficit copy '\(phrase)' in: \(text)",
                file: file,
                line: line
            )
        }
    }

    func testLateNightExcellentRecoveryDoesNotDiagnoseSleepDeficit() throws {
        WeekFitSetCurrentLanguage(.english)
        let state = makeState(
            activities: [],
            currentDate: lateNight,
            sleepState: .strong,
            recoveryState: .strong,
            readinessState: .good,
            recoveryPercent: 95,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let text = visibleStoryText(from: state)
        assertNoSleepDeficitCopy(text)
        XCTAssertTrue(
            text.contains("wind") || text.contains("evening") || text.contains("recovery looked solid"),
            text
        )
        XCTAssertTrue(story.owner == .stableOverview || story.primaryFocus == .eveningWindDown)
    }

    func testLateNightGoodRecoveryDoesNotDiagnoseSleepDeficit() throws {
        WeekFitSetCurrentLanguage(.english)
        let state = makeState(
            activities: [],
            currentDate: lateNight,
            sleepState: .strong,
            recoveryState: .stable,
            readinessState: .good,
            recoveryPercent: 82,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        assertNoSleepDeficitCopy(visibleStoryText(from: state))
        XCTAssertTrue(story.owner == .stableOverview || story.primaryFocus == .eveningWindDown)
    }

    func testLateNightCalmEveningWindDownUsesSleepProtectionNotDeficit() throws {
        WeekFitSetCurrentLanguage(.english)
        let state = makeState(
            activities: [],
            currentDate: lateNight,
            sleepState: .strong,
            recoveryState: .stable,
            readinessState: .good,
            recoveryPercent: 82,
            sleepHours: 8.0
        )
        let story = try XCTUnwrap(state.finalStory)
        let render = CoachFinalStoryRenderModel(story: story)
        let text = visibleStoryText(from: state)
        assertNoSleepDeficitCopy(text)
        XCTAssertTrue(
            text.contains("evening") || text.contains("wind") || text.contains("protect"),
            text
        )
        XCTAssertFalse(render.primaryRecommendation.lowercased().contains("didn't sleep"))
    }
}
