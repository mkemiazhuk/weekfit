import XCTest
import SwiftUI
@testable import WeekFit

@MainActor
final class WeekFitAppearanceResumeTests: XCTestCase {

    override func tearDown() async throws {
        WeekFitAppearanceSync.apply(preference: .dark, system: .dark, nightBlend: 0)
        try await super.tearDown()
    }

    func testLightPreferenceSurvivesNightComfortBlendRefresh() {
        WeekFitAppearanceSync.apply(preference: .light, system: .light, nightBlend: 0)
        XCTAssertEqual(WeekFitPaletteStore.current.appearance, .light)

        let nightComfort = NightComfortController(preference: .off)
        nightComfort.handleSceneBecameActive()

        // Night Comfort must not overwrite Light with the Dark store default.
        XCTAssertEqual(WeekFitPaletteStore.current.appearance, .light)
        XCTAssertEqual(WeekFitPaletteStore.current.blendFactor, 0, accuracy: 0.001)
    }

    func testAppearanceSyncForcesZeroBlendInLight() {
        WeekFitAppearanceSync.apply(preference: .light, system: .light, nightBlend: 0.85)
        XCTAssertEqual(WeekFitPaletteStore.current.appearance, .light)
        XCTAssertEqual(WeekFitPaletteStore.current.blendFactor, 0, accuracy: 0.001)
    }

    func testAppearanceSyncKeepsDarkBlend() {
        WeekFitAppearanceSync.apply(preference: .dark, system: .dark, nightBlend: 0.6)
        XCTAssertEqual(WeekFitPaletteStore.current.appearance, .dark)
        XCTAssertEqual(WeekFitPaletteStore.current.blendFactor, 0.6, accuracy: 0.001)
    }

    func testSetPreferenceAlignsStoreBeforePublish() {
        // Mirror WeekFitAppearanceController.setPreference: sync store first, then preference.
        WeekFitAppearanceSync.apply(preference: .dark, system: .dark, nightBlend: 0.4)
        XCTAssertEqual(WeekFitPaletteStore.current.appearance, .dark)

        WeekFitAppearanceSync.apply(preference: .light, system: .light, nightBlend: 0)
        XCTAssertEqual(WeekFitPaletteStore.current.appearance, .light)
        XCTAssertEqual(WeekFitPaletteStore.current.blendFactor, 0, accuracy: 0.001)
    }

    func testSystemPreferenceResolvesFromSystemScheme() {
        WeekFitAppearanceSync.apply(preference: .system, system: .light, nightBlend: 0)
        XCTAssertEqual(WeekFitPaletteStore.current.appearance, .light)

        WeekFitAppearanceSync.apply(preference: .system, system: .dark, nightBlend: 0.2)
        XCTAssertEqual(WeekFitPaletteStore.current.appearance, .dark)
        XCTAssertEqual(WeekFitPaletteStore.current.blendFactor, 0.2, accuracy: 0.001)
    }

    func testAppearanceInvalidationTokenChangesWithAppearance() {
        let light = WeekFitSemanticPalette.interpolated(blend: 0, appearance: .light)
        let dark = WeekFitSemanticPalette.interpolated(blend: 0, appearance: .dark)
        XCTAssertNotEqual(light.appearanceInvalidationToken, dark.appearanceInvalidationToken)
    }

    func testAppearanceInvalidationTokenChangesWithNightBlend() {
        let day = WeekFitSemanticPalette.interpolated(blend: 0, appearance: .dark)
        let night = WeekFitSemanticPalette.interpolated(blend: 0.8, appearance: .dark)
        XCTAssertNotEqual(day.appearanceInvalidationToken, night.appearanceInvalidationToken)
    }

    func testPaletteAppScreenBackgroundIsDistinctPerAppearance() {
        let light = WeekFitSemanticPalette.interpolated(blend: 0, appearance: .light)
        let dark = WeekFitSemanticPalette.interpolated(blend: 0, appearance: .dark)
        XCTAssertTrue(light.isLight)
        XCTAssertFalse(dark.isLight)
        // Tokens must come from the palette itself (env path), not a shared Dark store.
        XCTAssertNotEqual(
            light.appearanceInvalidationToken,
            dark.appearanceInvalidationToken
        )
    }

    func testStoreRevisionBumpsOnlyOnChange() {
        WeekFitAppearanceSync.apply(preference: .light, system: .light, nightBlend: 0)
        let revision = WeekFitPaletteStore.revision
        WeekFitAppearanceSync.apply(preference: .light, system: .light, nightBlend: 0)
        XCTAssertEqual(WeekFitPaletteStore.revision, revision)

        WeekFitAppearanceSync.apply(preference: .dark, system: .dark, nightBlend: 0)
        XCTAssertGreaterThan(WeekFitPaletteStore.revision, revision)
    }
}
