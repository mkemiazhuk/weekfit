import XCTest
@testable import WeekFitWidgetShared

final class WeekFitWidgetTextFittingTests: XCTestCase {
    func testNeverEllipsisOrDanglingPunctuationAcrossAdversarialInputs() {
        let samples = [
            "Short first round — hydrate before the heat starts",
            "Hydrate before the —",
            "Keep today light - protect sleep later tonight",
            "Small steps today beat stacking load later when recovery is already taxed.",
            "Take five quiet minutes before you stack more load",
            "Before sauna",
            "Hello… world",
            "One; two; three long continuing clause that exceeds budgets badly",
            "СупердлинноеСловоБезПробеловКотороеНеВлезетНикуда",
            "  · leading bullet junk — trailing ",
            "A — B — C — D",
            ""
        ]

        let fallback = "You're on track"
        for sample in samples {
            let fitted = WeekFitWidgetTextFitting.fit(
                sample,
                to: .smallHero,
                fallback: fallback
            )
            XCTAssertFalse(WeekFitWidgetTextFitting.containsEllipsis(fitted), sample)
            XCTAssertLessThanOrEqual(fitted.count, WeekFitWidgetTextFitting.Slot.smallHero.limit, fitted)
            XCTAssertFalse(fitted.hasSuffix("-"), fitted)
            XCTAssertFalse(fitted.hasSuffix("—"), fitted)
            XCTAssertFalse(fitted.hasSuffix("–"), fitted)
            XCTAssertFalse(fitted.hasSuffix("·"), fitted)
            XCTAssertFalse(fitted.hasPrefix("—"), fitted)
            if !fitted.isEmpty {
                XCTAssertTrue(
                    WeekFitWidgetTextFitting.isDisplaySafe(fitted, limit: WeekFitWidgetTextFitting.Slot.smallHero.limit),
                    fitted
                )
            }
        }
    }

    func testDashSplitsToCompleteLeadingPhrase() {
        let fitted = WeekFitWidgetTextFitting.fit(
            "Short first round — hydrate before the heat",
            to: .smallHero,
            fallback: "You're on track"
        )
        XCTAssertEqual(fitted, "Short first round")
    }

    func testOverlongSingleTokenFallsBack() {
        let fitted = WeekFitWidgetTextFitting.fit(
            "Supercalifragilisticexpialidocious",
            limit: 12,
            fallback: "Ready"
        )
        XCTAssertEqual(fitted, "Ready")
    }

    func testEmptyUsesFallback() {
        XCTAssertEqual(
            WeekFitWidgetTextFitting.fit("   ", to: .smallHero, fallback: "You're on track"),
            "You're on track"
        )
    }

    func testAllSlotsRejectUnsafeOutput() {
        let raw = "Move as planned — then protect sleep and keep fueling carefully all evening"
        for slot in [
            WeekFitWidgetTextFitting.Slot.smallState,
            .smallHero,
            .smallNextTitle,
            .mediumHeadline,
            .mediumDetail,
            .mediumNextTitle,
            .mediumNextMeta
        ] {
            let fitted = WeekFitWidgetTextFitting.fit(raw, to: slot, fallback: "Steady")
            XCTAssertTrue(
                fitted.isEmpty || WeekFitWidgetTextFitting.isDisplaySafe(fitted, limit: slot.limit),
                "\(slot) → \(fitted)"
            )
        }
    }
}
