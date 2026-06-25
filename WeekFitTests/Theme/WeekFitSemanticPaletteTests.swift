import XCTest
@testable import WeekFit

final class WeekFitSemanticPaletteTests: XCTestCase {

    func testDaytimePaletteMatchesBaselineTokens() {
        let palette = WeekFitSemanticPalette.daytime

        XCTAssertEqual(palette.blendFactor, 0, accuracy: 0.001)
        XCTAssertEqual(palette.textPrimaryOpacity, 0.94, accuracy: 0.001)
        XCTAssertEqual(palette.ringGlowOpacity, 0.18, accuracy: 0.001)
        XCTAssertEqual(palette.cardBackgroundOpacity, 0.075, accuracy: 0.001)
    }

    func testFullNightComfortSoftensTokensMonotonically() {
        let night = WeekFitSemanticPalette.interpolated(blend: 1)

        XCTAssertEqual(night.blendFactor, 1, accuracy: 0.001)
        XCTAssertLessThan(night.textPrimaryOpacity, WeekFitSemanticPalette.daytime.textPrimaryOpacity)
        XCTAssertLessThan(night.ringGlowOpacity, WeekFitSemanticPalette.daytime.ringGlowOpacity)
        XCTAssertLessThan(night.cardBackgroundOpacity, WeekFitSemanticPalette.daytime.cardBackgroundOpacity)
        XCTAssertLessThan(night.accentSaturation, WeekFitSemanticPalette.daytime.accentSaturation)
    }

    func testInterpolationIsLinearAtMidpoint() {
        let midpoint = WeekFitSemanticPalette.interpolated(blend: 0.5)

        XCTAssertEqual(
            midpoint.textPrimaryOpacity,
            (WeekFitSemanticPalette.daytime.textPrimaryOpacity + 0.82) / 2,
            accuracy: 0.001
        )
        XCTAssertEqual(
            midpoint.ambientOpacity,
            (WeekFitSemanticPalette.daytime.ambientOpacity + 0.62) / 2,
            accuracy: 0.001
        )
    }

    func testScaledWhiteOpacitySoftensAtNight() {
        let day = WeekFitSemanticPalette.daytime
        let night = WeekFitSemanticPalette.interpolated(blend: 1)

        XCTAssertEqual(day.scaledOpacity(0.10), 0.10, accuracy: 0.001)
        XCTAssertLessThan(night.scaledOpacity(0.10), day.scaledOpacity(0.10))
    }
}
