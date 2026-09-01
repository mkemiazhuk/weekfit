import XCTest
@testable import WeekFit

@MainActor
final class WeekFitStoreKitTimelineDiagnosticsTests: XCTestCase {
    override func tearDown() {
        WeekFitStoreKitTimelineDiagnostics.shared.resetForTests()
        super.tearDown()
    }

    func testTimelineTextFormatsOrderedEvents() {
        let events = [
            WeekFitStoreKitTimelineDiagnostics.Event(
                id: UUID(),
                sequence: 1,
                recordedAt: Date(),
                kind: .productLoadBefore,
                detail: "USA / 143478"
            ),
            WeekFitStoreKitTimelineDiagnostics.Event(
                id: UUID(),
                sequence: 2,
                recordedAt: Date(),
                kind: .purchaseAfter,
                detail: "POL / 143478 / userCancelled"
            )
        ]
        let text = WeekFitStoreKitTimelineDiagnostics.timelineText(events: events)
        XCTAssertTrue(text.contains("#1 LOAD BEFORE"))
        XCTAssertTrue(text.contains("USA / 143478"))
        XCTAssertTrue(text.contains("#2 PURCHASE AFTER"))
        XCTAssertTrue(text.contains("userCancelled"))
    }

    func testDiagnosticsFormatterIncludesTimelineSection() {
        let timeline = [
            WeekFitStoreKitTimelineDiagnostics.Event(
                id: UUID(),
                sequence: 1,
                recordedAt: Date(),
                kind: .storefrontUpdate,
                detail: "POL / 143478"
            )
        ]
        let text = WeekFitStoreKitPaywallDiagnosticsFormatter.text(
            distribution: .testFlight,
            appVersion: "1.3.2",
            appBuild: "20",
            storefrontCountryCode: "USA",
            storefrontID: "143478",
            rawReturnedCount: 2,
            products: [],
            productsFailedToLoad: false,
            timelineEvents: timeline
        )
        XCTAssertTrue(text.contains("Timeline"))
        XCTAssertTrue(text.contains("#1 STOREFRONT UPDATE"))
        XCTAssertTrue(text.contains("POL / 143478"))
    }
}
