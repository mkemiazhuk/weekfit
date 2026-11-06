import SwiftUI
import XCTest
@testable import WeekFit

@MainActor
final class ActivityBadgeRulesTests: XCTestCase {

    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    func testCatalogCoversEveryPlannerActivityRecoveryAndHabit() {
        let planned = PlannerType.workout.options.map(\.title)
            + PlannerType.recovery.options.map(\.title)
            + PlannerType.habit.options.map(\.title)
        let covered = Set(ActivityBadgeCatalog.definitions.map(\.catalogTitle))
        for title in planned {
            XCTAssertTrue(covered.contains(title), title)
        }
        XCTAssertEqual(covered.count, planned.count)
        XCTAssertEqual(ActivityBadgeCatalog.definition(catalogTitle: "Walk")?.category, .recovery)
        XCTAssertEqual(ActivityBadgeCatalog.canonicalCatalogTitle("HIIT Workout"), "High Intensity Interval Training")
        XCTAssertEqual(ActivityBadgeCatalog.canonicalCatalogTitle("Core Training"), "Core")
        XCTAssertNil(ActivityBadgeCatalog.canonicalCatalogTitle("Strength Workout"))
    }

    func testStepsDoNotUnlockAWalkAndARealWalkUnlocksOnce() {
        var ledger = ActivityBadgeLedger()
        ActivityBadgeEngine.ingest([
            input(title: "Walk", type: "recovery", source: "stepCount", completed: true)
        ], waterGoalMilliliters: 2000, now: day, into: &ledger)
        XCTAssertNil(ledger.unlocks["recovery.walk"])

        let firstWalk = day.addingTimeInterval(-3 * 86_400)
        ActivityBadgeEngine.ingest([
            input(id: "a", title: "Walk", type: "recovery", source: "appleWorkout", completed: true, startedAt: firstWalk),
            input(id: "b", title: "Walk", type: "recovery", source: "today", completed: true, startedAt: day.addingTimeInterval(86_400))
        ], waterGoalMilliliters: 2000, now: day.addingTimeInterval(90_000), into: &ledger)
        XCTAssertEqual(ledger.unlocks["recovery.walk"], firstWalk.addingTimeInterval(20 * 60))
        XCTAssertNil(ledger.pendingUnlockID)
    }

    func testBreathingNeedsAFullMinuteAndHistoryDoesNotPop() {
        var ledger = ActivityBadgeLedger()
        ledger.disqualifiedRecordIDs = ["short"]
        ActivityBadgeEngine.ingest([
            input(id: "short", title: "Breathing", type: "recovery", completed: true, actual: 1)
        ], waterGoalMilliliters: 0, now: day, into: &ledger)
        XCTAssertNil(ledger.unlocks["recovery.breathing"])
        XCTAssertNil(ledger.pendingUnlockID)

        let finished = day.addingTimeInterval(10_060)
        ledger.justFinishedRecordIDs = ["live"]
        ActivityBadgeEngine.ingest([
            input(id: "short", title: "Breathing", type: "recovery", completed: true, actual: 1),
            input(id: "live", title: "Breathing", type: "recovery", completed: true, startedAt: day.addingTimeInterval(10_000), actual: 1)
        ], waterGoalMilliliters: 0, now: finished, into: &ledger)
        XCTAssertEqual(ledger.pendingUnlockID, "recovery.breathing")
        XCTAssertEqual(ledger.unlocks["recovery.breathing"], finished)
    }

    func testHabitGoalCheckInAndRename() {
        var ledger = ActivityBadgeLedger()
        let plannedWater = input(title: "Drink Water", type: "habit", completed: true, waterML: 0)
        ActivityBadgeEngine.ingest([plannedWater], waterGoalMilliliters: 2000, now: day, into: &ledger)
        XCTAssertNil(ledger.unlocks["habit.drink-water"])

        let sipped = day.addingTimeInterval(-86_400)
        let glass = input(id: "glass", title: "Water", type: "drink", source: "today", completed: true, startedAt: sipped, waterML: 2000)
        ActivityBadgeEngine.ingest([plannedWater, glass], waterGoalMilliliters: 2000, now: day.addingTimeInterval(4_000), into: &ledger)
        XCTAssertEqual(ledger.unlocks["habit.drink-water"], sipped)
        XCTAssertNil(ledger.pendingUnlockID)

        let created = input(id: "plan", title: "Read", type: "habit", completed: false)
        ActivityBadgeEngine.ingest([created], waterGoalMilliliters: 0, now: day, into: &ledger)
        let customID = ledger.customIDsByTitle["read"]
        XCTAssertNotNil(customID)
        XCTAssertNil(ledger.unlocks[customID!])

        let done = input(id: "done", title: "Read", type: "habit", completed: true, startedAt: day)
        ledger.justFinishedRecordIDs = ["done"]
        ActivityBadgeEngine.ingest([done], waterGoalMilliliters: 0, now: day.addingTimeInterval(120), into: &ledger)
        XCTAssertEqual(ledger.pendingUnlockID, customID)
        XCTAssertEqual(ledger.customNames[customID!], "Read")

        ActivityBadgeEngine.renameCustomHabit(from: "Read", to: "Read pages", ledger: &ledger)
        XCTAssertNil(ledger.customIDsByTitle["read"])
        XCTAssertEqual(ledger.customIDsByTitle["read pages"], customID)
        XCTAssertEqual(ledger.customNames[customID!], "Read pages")
        XCTAssertNotNil(ledger.unlocks[customID!])
    }

    func testSuggestionSkipsWhenNothingImmediateIsLocked() {
        var ledger = ActivityBadgeLedger()
        ledger.unlocks["recovery.breathing"] = day
        ledger.unlocks["recovery.walk"] = day
        ledger.unlocks["habit.drink-water"] = day
        let id = ActivityBadgeEngine.suggestionID(ledger: ledger, inputs: [], now: day)
        XCTAssertNil(id)

        ledger.unlocks["recovery.breathing"] = nil
        XCTAssertEqual(ActivityBadgeEngine.suggestionID(ledger: ledger, inputs: [], now: day), "recovery.breathing")
    }

    func testInvitationWaitsFourteenDaysAndThirtyBetween() {
        let now = day
        let first = ActivitySuggestionPlanner.decide(
            now: now,
            suggestionID: "recovery.breathing",
            enabled: true,
            notificationsAuthorized: true,
            lastInviteAt: nil,
            scheduledFireAt: nil
        )
        XCTAssertEqual(first?.fireAt, now.addingTimeInterval(ActivitySuggestionPlanner.idleInterval))

        let recent = ActivitySuggestionPlanner.decide(
            now: now,
            suggestionID: "recovery.breathing",
            enabled: true,
            notificationsAuthorized: true,
            lastInviteAt: now.addingTimeInterval(-10 * 86_400),
            scheduledFireAt: nil
        )
        XCTAssertEqual(recent?.fireAt, now.addingTimeInterval(20 * 86_400))

        XCTAssertNil(ActivitySuggestionPlanner.decide(
            now: now,
            suggestionID: nil,
            enabled: true,
            notificationsAuthorized: true,
            lastInviteAt: nil,
            scheduledFireAt: nil
        ))
        XCTAssertNil(ActivitySuggestionPlanner.decide(
            now: now,
            suggestionID: "recovery.breathing",
            enabled: false,
            notificationsAuthorized: true,
            lastInviteAt: nil,
            scheduledFireAt: nil
        ))
    }

    func testAwardsUseRealCompletionsAndNeverReset() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2024, month: 6, day: 1, hour: 9))!
        func session(_ offset: Int, minutes: Int, completed: Bool = true, id: String? = nil) -> ActivityBadgeInput {
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            return input(
                id: id ?? "p\(offset)",
                title: "Padel",
                type: "workout",
                completed: completed,
                startedAt: date,
                actual: minutes
            )
        }
        let sessions = (0..<7).map { session($0, minutes: 20 + $0) }
        var ledger = ActivityBadgeLedger()
        let now = calendar.date(byAdding: .day, value: 6, to: start)!
        ActivityBadgeEngine.ingest(
            sessions + [session(8, minutes: 40, completed: false, id: "plan")],
            waterGoalMilliliters: 0,
            now: now,
            into: &ledger,
            calendar: calendar
        )
        let fifth = calendar.date(byAdding: .day, value: 4, to: start)!.addingTimeInterval(24 * 60)
        XCTAssertEqual(ledger.storedAwards["activity.padel.count.5"]?.earnedAt, fifth)
        XCTAssertNil(ledger.storedAwards["activity.padel.count.10"])
        XCTAssertEqual(ledger.storedAwards["activity.padel.streak"]?.value, 7)
        XCTAssertEqual(ledger.storedAwards["activity.padel.record"]?.value, 26)
        let earnedAt = ledger.storedAwards["activity.padel.count.5"]?.earnedAt

        ActivityBadgeEngine.ingest(sessions, waterGoalMilliliters: 0, now: now, into: &ledger, calendar: calendar)
        XCTAssertEqual(ledger.storedAwards["activity.padel.count.5"]?.earnedAt, earnedAt)

        let kept = [session(0, minutes: 10), session(2, minutes: 12)]
        ActivityBadgeEngine.ingest(kept, waterGoalMilliliters: 0, now: now, into: &ledger, calendar: calendar)
        XCTAssertEqual(ledger.storedAwards["activity.padel.streak"]?.value, 7)
        XCTAssertEqual(ledger.storedAwards["activity.padel.record"]?.value, 26)
        XCTAssertNotNil(ledger.unlocks["activity.padel"])

        let cells = ActivityBadgePresenter.sections(
            ledger: ledger,
            inputs: kept,
            now: now,
            calendar: calendar,
            activityName: { $0 }
        ).flatMap(\.cells)
        let ten = cells.first { $0.id == "activity.padel.count.10" }
        XCTAssertEqual(ten?.isUnlocked, false)
        XCTAssertEqual(ten?.award.current, 2)
        XCTAssertEqual(ten?.award.goal, 10)
        XCTAssertEqual(ActivityAwardCopy.progressFraction(ten!), 0.2)
        XCTAssertEqual(ActivityAwardCopy.progress(7, 10, "en"), "7 of 10")
        XCTAssertEqual(ActivityAwardCopy.progress(7, 10, "ru"), "7 из 10")
        XCTAssertEqual(cells.first { $0.id == "activity.padel.streak" }?.award.best, 7)
        XCTAssertEqual(cells.first { $0.id == "activity.padel.record" }?.award.current, 26)

        let steps = ActivityBadgeLedger()
        var stepLedger = steps
        ActivityBadgeEngine.ingest([
            input(title: "Walk", type: "recovery", source: "stepCount", completed: true, startedAt: start)
        ], waterGoalMilliliters: 0, now: now, into: &stepLedger, calendar: calendar)
        XCTAssertNil(stepLedger.storedAwards["recovery.walk.count.5"])
        XCTAssertNil(stepLedger.storedAwards["recovery.walk.record"])
    }

    func testWaterDaysAndCheckInHaveNoFakeRecord() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2024, month: 6, day: 1, hour: 8))!
        func sip(_ offset: Int, ml: Int) -> ActivityBadgeInput {
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            return input(id: "w\(offset)-\(ml)", title: "Water", type: "drink", completed: true, startedAt: date, waterML: ml)
        }
        var ledger = ActivityBadgeLedger()
        let now = calendar.date(byAdding: .day, value: 3, to: start)!
        ActivityBadgeEngine.ingest([
            sip(0, ml: 1000), sip(0, ml: 1000), sip(1, ml: 500), sip(2, ml: 2500)
        ], waterGoalMilliliters: 2000, now: now, into: &ledger, calendar: calendar)
        XCTAssertNil(ledger.storedAwards["habit.drink-water.count.5"])
        XCTAssertNil(ledger.storedAwards["habit.drink-water.streak"])
        XCTAssertEqual(ledger.storedAwards["habit.drink-water.record"]?.value, 2500)

        ActivityBadgeEngine.ingest([
            input(id: "read", title: "Read", type: "habit", completed: true, startedAt: start)
        ], waterGoalMilliliters: 0, now: now, into: &ledger, calendar: calendar)
        let custom = ledger.customIDsByTitle["read"]
        XCTAssertNotNil(custom)
        XCTAssertNil(ledger.storedAwards["\(custom!).record"])
    }

    func testOldLedgerDecodesWithoutStoredAwards() throws {
        let json = #"{"unlocks":{"recovery.walk":0},"waterGoalMilliliters":2000}"#
        let decoded = try JSONDecoder().decode(ActivityBadgeLedger.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.waterGoalMilliliters, 2000)
        XCTAssertNotNil(decoded.unlocks["recovery.walk"])
        XCTAssertTrue(decoded.storedAwards.isEmpty)
    }

    func testRendersAwardDetailInBothThemes() throws {
        let long = "Утренняя растяжка спины и плечевого пояса после долгой сидячей работы за столом"
        let progressBadge = ActivityBadgeDisplay(
            id: "activity.padel.count.10",
            name: long,
            caption: long,
            symbol: "figure.tennis",
            category: .activity,
            condition: "Complete the long padel practice ten times",
            activityName: long,
            isUnlocked: false,
            unlockedAt: nil,
            canStart: true,
            actionTitle: "Play padel",
            actionMinutes: 45,
            award: ActivityAwardState(kind: .accumulation, current: 7, goal: 10, unit: .sessions)
        )
        let spoken = ActivityAwardCopy.accessibilityLabel(for: progressBadge, language: "en")
        XCTAssertTrue(spoken.contains("7 of 10"))
        XCTAssertTrue(spoken.contains(long))
        XCTAssertTrue(spoken.contains("Complete the long padel practice ten times"))
        let earned = ActivityBadgeDisplay(
            id: "activity.padel.record",
            name: "Longest session",
            caption: "Longest session",
            symbol: "figure.tennis",
            category: .activity,
            condition: "Longest measured Padel",
            activityName: "Padel",
            isUnlocked: true,
            unlockedAt: day,
            canStart: false,
            actionTitle: "Play padel",
            actionMinutes: 45,
            award: ActivityAwardState(kind: .personalRecord, current: 48, goal: nil, unit: .minutes, rangeEnd: day)
        )
        XCTAssertEqual(ActivityAwardCopy.result(earned, language: "en"), "48 min")
        XCTAssertNil(ActivityAwardCopy.progressFraction(earned))
        let directory = URL(fileURLWithPath: "/tmp/weekfit-badges", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try render(ActivityAwardDetailScreen(badge: progressBadge, onClose: {}, onStart: {}, scrolls: false), name: "award-progress-dark", scheme: .dark, palette: .daytime, directory: directory)
        try render(ActivityAwardDetailScreen(badge: progressBadge, onClose: {}, onStart: {}, scrolls: false), name: "award-progress-light", scheme: .light, palette: .light, directory: directory)
        try render(ActivityAwardDetailScreen(badge: earned, onClose: {}, onStart: {}, scrolls: false), name: "award-earned-dark", scheme: .dark, palette: .daytime, directory: directory)
        try render(ActivityAwardDetailScreen(badge: earned, onClose: {}, onStart: {}, scrolls: false), name: "award-earned-light", scheme: .light, palette: .light, directory: directory)
    }

    func testRendersCollectionUnlockAndFocus() throws {
        let badge = ActivityBadgeDisplay(
            id: "recovery.breathing",
            name: "First Pause",
            caption: "First Pause",
            symbol: "wind",
            category: .recovery,
            condition: "A full minute of breathing",
            activityName: "Breathing",
            isUnlocked: false,
            unlockedAt: nil,
            canStart: true,
            actionTitle: "Take a minute to breathe",
            actionMinutes: 1
        )
        let unlocked = ActivityBadgeDisplay(
            id: "recovery.breathing",
            name: "First Pause",
            caption: "First Pause",
            symbol: "wind",
            category: .recovery,
            condition: "A full minute of breathing",
            activityName: "Breathing",
            isUnlocked: true,
            unlockedAt: day,
            canStart: false,
            actionTitle: "Take a minute to breathe",
            actionMinutes: 1
        )
        let stretch = ActivityBadgeDisplay(
            id: "recovery.stretching",
            name: "Stretch Break",
            caption: "Stretch Break",
            symbol: "figure.cooldown",
            category: .recovery,
            condition: "First completed stretch",
            activityName: "Stretching",
            isUnlocked: false,
            unlockedAt: nil,
            canStart: true,
            actionTitle: "Stretch",
            actionMinutes: 20
        )
        let ride = ActivityBadgeDisplay(
            id: "activity.cycling",
            name: "Two Wheels",
            caption: "Two Wheels",
            symbol: "figure.outdoor.cycle",
            category: .activity,
            condition: "First completed ride",
            activityName: "Cycling",
            isUnlocked: true,
            unlockedAt: day,
            canStart: false,
            actionTitle: "Ride",
            actionMinutes: 45
        )
        let sections = [
            ActivityBadgeSection(id: "activity", title: "Activities", unlocked: 1, total: 2, cells: [ride, stretch]),
            ActivityBadgeSection(id: "recovery", title: "Recovery", unlocked: 1, total: 2, cells: [unlocked, stretch]),
            ActivityBadgeSection(id: "habit", title: "Habits", unlocked: 0, total: 1, cells: [
                ActivityBadgeDisplay(
                    id: "habit.custom.1",
                    name: "First Check-in",
                    caption: "Read",
                    symbol: "checkmark",
                    category: .habit,
                    condition: "First time this habit is checked in",
                    activityName: "Read",
                    isUnlocked: false,
                    unlockedAt: nil,
                    canStart: false,
                    actionTitle: "Check in Read",
                    actionMinutes: nil
                )
            ])
        ]
        let directory = URL(fileURLWithPath: "/tmp/weekfit-badges", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try render(
            TodayBadgeFocusPreview(suggestion: badge),
            name: "today-focus-dark",
            scheme: .dark,
            palette: .daytime,
            directory: directory
        )
        try render(
            TodayBadgeFocusPreview(suggestion: badge),
            name: "today-focus-light",
            scheme: .light,
            palette: .light,
            directory: directory
        )
        try render(
            ActivityBadgeUnlockedSheet(badge: unlocked, onDone: {}, onViewCollection: {}),
            name: "unlock-dark",
            scheme: .dark,
            palette: .daytime,
            directory: directory
        )
        try render(
            ActivityCollectionView(sections: sections, scrolls: false, onClose: {}, onStart: { _ in }),
            name: "collection-dark",
            scheme: .dark,
            palette: .daytime,
            directory: directory
        )
        try render(
            ActivityCollectionView(sections: sections, scrolls: false, onClose: {}, onStart: { _ in }),
            name: "collection-light",
            scheme: .light,
            palette: .light,
            directory: directory
        )
    }

    private func render<V: View>(
        _ view: V,
        name: String,
        scheme: ColorScheme,
        palette: WeekFitSemanticPalette,
        directory: URL
    ) throws {
        let hosted = view
            .frame(width: 390, height: 844)
            .environment(\.colorScheme, scheme)
            .environment(\.weekFitPalette, palette)
        let renderer = ImageRenderer(content: hosted)
        renderer.scale = 2
        let image = renderer.uiImage
        let data = image?.pngData()
        XCTAssertNotNil(data, name)
        try data?.write(to: directory.appendingPathComponent("\(name).png"))
    }

    private func input(
        id: String = UUID().uuidString,
        title: String,
        type: String,
        source: String = "planner",
        completed: Bool,
        startedAt: Date? = nil,
        actual: Int? = nil,
        waterML: Int = 0
    ) -> ActivityBadgeInput {
        ActivityBadgeInput(
            recordID: id,
            title: title,
            type: type,
            imageName: "",
            isCompleted: completed,
            isSkipped: false,
            startedAt: startedAt ?? day,
            durationMinutes: 20,
            actualDurationMinutes: actual,
            source: source,
            waterMilliliters: waterML
        )
    }
}

private struct TodayBadgeFocusPreview: View {
    let suggestion: ActivityBadgeDisplay
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        ZStack {
            palette.appScreenBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text("Today")
                    .font(.system(size: 34, weight: .bold))
                TodayMiddleCard(
                    header: "Today's focus",
                    title: suggestion.actionTitle,
                    message: "1 min · Unlock \(suggestion.name)",
                    systemImage: suggestion.symbol,
                    tone: .lavender,
                    showsChevron: true
                )
                Spacer()
            }
            .padding(20)
        }
    }
}
