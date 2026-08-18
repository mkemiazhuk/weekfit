import XCTest
@testable import WeekFitWidgetShared

final class WeekFitWidgetSnapshotTests: XCTestCase {
    func testClampAndProgressSummary() {
        let snap = WeekFitWidgetSnapshot(
            dateKey: "2026-08-11",
            activityProgress: 1.4,
            activityCalories: 500,
            activityGoal: 400,
            hasActivitySignal: true,
            nutritionProgress: -0.2,
            consumedCalories: 100,
            remainingCalories: 900,
            hasNutritionSignal: true,
            recoveryScore: 120,
            sleepHours: 7,
            recoveryLabel: "Solid",
            hasRecoverySignal: true,
            dayMode: .goodToGo,
            dayStateLabel: "Good to go",
            dayGuidance: "You're on track",
            dayGuidanceDetail: "",
            nextActionTitle: "Walk",
            nextActionSubtitle: "20 min",
            nextActionTime: "09:00",
            nextActionKind: .walk,
            completedItems: 1,
            totalItems: 3,
            updatedAt: Date()
        )
        XCTAssertEqual(snap.activityProgress, 1)
        XCTAssertEqual(snap.nutritionProgress, 0)
        XCTAssertEqual(snap.recoveryScore, 100)
        XCTAssertEqual(snap.progressSummary, "1 of 3 done")
        XCTAssertTrue(snap.hasNextAction)
    }

    func testRoundTripEncodeDecodeIncludesDayStateLabel() throws {
        let original = WeekFitWidgetSnapshot.placeholderEmpty()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WeekFitWidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded.dayMode, .empty)
        XCTAssertEqual(decoded.dayStateLabel, "")
        XCTAssertEqual(decoded.schemaVersion, WeekFitWidgetSnapshot.currentSchemaVersion)
    }

    func testDeepLinkParsing() {
        XCTAssertTrue(WeekFitWidgetDeepLink.isTodayURL(WeekFitWidgetDeepLink.todayURL))
        XCTAssertTrue(WeekFitWidgetDeepLink.isTodayURL(WeekFitWidgetDeepLink.todayNextActionURL))
        XCTAssertFalse(WeekFitWidgetDeepLink.isTodayURL(URL(string: "https://example.com")!))
    }

    func testCompactNextTitleKeepsWidgetReadable() {
        let long = "Take five quiet minutes before you stack more load"
        let compact = WeekFitWidgetCopy.mediumNextTitle(raw: long, kind: .recovery)
        XCTAssertEqual(compact, "Quiet pause")
        XCTAssertFalse(WeekFitWidgetCopy.containsEllipsis(compact))
        XCTAssertEqual(WeekFitWidgetCopy.mediumNextTitle(raw: "Sauna", kind: .sauna), "Sauna")
    }

    func testMediumCopyNeverUsesEllipsis() {
        let headline = WeekFitWidgetCopy.mediumHeadline(
            raw: "Before sauna and everything else you planned this morning",
            mode: .goodToGo
        )
        let detail = WeekFitWidgetCopy.mediumDetail(
            raw: "Small steps today beat stacking load later when recovery is already taxed.",
            mode: .goodToGo
        )
        let next = WeekFitWidgetCopy.mediumNextTitle(
            raw: "Take five quiet minutes before you stack more load",
            kind: .walk
        )
        let meta = WeekFitWidgetCopy.mediumNextMeta(subtitle: "30 min easy outdoor", time: "14:00")

        for text in [headline, detail, next, meta] {
            XCTAssertFalse(WeekFitWidgetCopy.containsEllipsis(text), text)
        }
        XCTAssertLessThanOrEqual(headline.count, WeekFitWidgetCopy.MediumBudget.headline)
        XCTAssertLessThanOrEqual(detail.count, WeekFitWidgetCopy.MediumBudget.detail)
        XCTAssertLessThanOrEqual(next.count, WeekFitWidgetCopy.MediumBudget.nextTitle)
        XCTAssertLessThanOrEqual(meta.count, WeekFitWidgetCopy.MediumBudget.nextMeta)
    }

    func testSmallPresentationHierarchyAndNoEllipsis() {
        let beforeSauna = WeekFitWidgetSnapshot(
            dateKey: "2026-08-11",
            activityProgress: 0.12,
            activityCalories: 60,
            activityGoal: 500,
            hasActivitySignal: true,
            nutritionProgress: 0.28,
            consumedCalories: 560,
            remainingCalories: 1440,
            hasNutritionSignal: true,
            recoveryScore: 89,
            sleepHours: 7,
            recoveryLabel: "Ready",
            hasRecoverySignal: true,
            dayMode: .goodToGo,
            dayStateLabel: "Before sauna",
            dayGuidance: "Hydrate first",
            dayGuidanceDetail: "",
            nextActionTitle: "Sauna",
            nextActionSubtitle: "",
            nextActionTime: "18:00",
            nextActionKind: .sauna,
            completedItems: 0,
            totalItems: 2,
            updatedAt: Date()
        )

        let presentation = WeekFitSmallPresentation.make(from: beforeSauna)
        XCTAssertEqual(presentation.stateLabel, "Before sauna")
        XCTAssertEqual(presentation.hero, "Hydrate first")
        XCTAssertEqual(presentation.nextHeader, "Next · 18:00")
        XCTAssertEqual(presentation.nextTitle, "Sauna")
        XCTAssertTrue(presentation.showsNext)
        XCTAssertFalse(WeekFitWidgetCopy.containsEllipsis(presentation.stateLabel))
        XCTAssertFalse(WeekFitWidgetCopy.containsEllipsis(presentation.hero))
        XCTAssertFalse(WeekFitWidgetCopy.containsEllipsis(presentation.nextTitle))

        // Event echo must not become the hero.
        let echo = WeekFitWidgetSnapshot(
            dateKey: "2026-08-11",
            activityProgress: 0.4,
            activityCalories: 200,
            activityGoal: 500,
            hasActivitySignal: true,
            nutritionProgress: 0.3,
            consumedCalories: 600,
            remainingCalories: 1400,
            hasNutritionSignal: true,
            recoveryScore: 80,
            sleepHours: 7,
            recoveryLabel: "Ready",
            hasRecoverySignal: true,
            dayMode: .goodToGo,
            dayStateLabel: "Good to go",
            dayGuidance: "Before sauna",
            dayGuidanceDetail: "",
            nextActionTitle: "Sauna",
            nextActionSubtitle: "",
            nextActionTime: "18:00",
            nextActionKind: .sauna,
            completedItems: 0,
            totalItems: 1,
            updatedAt: Date()
        )
        let echoPresentation = WeekFitSmallPresentation.make(from: echo)
        XCTAssertEqual(echoPresentation.hero, "You're on track")
        XCTAssertNotEqual(echoPresentation.hero.lowercased(), "before sauna")
    }

    func testSmallAllClearHidesNext() {
        let snap = WeekFitWidgetSnapshot.placeholderEmpty()
        let presentation = WeekFitSmallPresentation.make(from: snap)
        XCTAssertFalse(presentation.showsNext)
        XCTAssertEqual(presentation.stateLabel, "All clear")
        XCTAssertEqual(presentation.hero, "Nothing urgent now")
    }

    func testEventEchoDetection() {
        XCTAssertTrue(WeekFitWidgetCopy.isEventEcho("Before sauna", nextTitle: "Sauna"))
        XCTAssertTrue(WeekFitWidgetCopy.isEventEcho("Sauna", nextTitle: "Sauna"))
        XCTAssertFalse(WeekFitWidgetCopy.isEventEcho("Hydrate first", nextTitle: "Sauna"))
    }

    func testInProgressUsesNowNotUpNext() {
        XCTAssertEqual(WeekFitWidgetCopy.mediumNextSectionTitle(phase: .inProgress), "Now")
        XCTAssertEqual(WeekFitWidgetCopy.mediumNextSectionTitle(phase: .upcoming), "Up next")
        XCTAssertEqual(WeekFitWidgetCopy.mediumNextSectionTitle(phase: .due), "Due")
        XCTAssertEqual(
            WeekFitWidgetCopy.smallNextHeader(time: "14:00", phase: .inProgress),
            "Now · 14:00"
        )
        XCTAssertEqual(
            WeekFitWidgetCopy.smallNextHeader(time: "14:00", phase: .upcoming),
            "Next · 14:00"
        )
    }

    func testCompactPhraseNeverEndsWithDash() {
        let dashed = WeekFitWidgetCopy.compactPhrase(
            "Short first round — hydrate before the heat starts",
            limit: WeekFitWidgetCopy.SmallBudget.hero,
            fallback: "You're on track"
        )
        XCTAssertEqual(dashed, "Short first round")
        XCTAssertFalse(dashed.hasSuffix("-"))
        XCTAssertFalse(dashed.hasSuffix("—"))
        XCTAssertFalse(WeekFitWidgetCopy.containsEllipsis(dashed))

        let clippedTail = WeekFitWidgetCopy.compactPhrase(
            "Hydrate before the —",
            limit: 22,
            fallback: "Hydrate first"
        )
        XCTAssertEqual(clippedTail, "Hydrate before the")
        XCTAssertFalse(clippedTail.hasSuffix("—"))
    }
}
