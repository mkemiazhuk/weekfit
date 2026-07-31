import SwiftUI

/// Approved WeekFit Light Mode semantic palette.
/// Dark Mode values live elsewhere and must remain unchanged.
enum WeekFitLightTokens {
    // Foundation — shared ivory canvas across all main tabs
    static let backgroundPrimary = Color(red: 0.984, green: 0.976, blue: 0.957) // #FBF9F4
    /// Soft secondary ivory — chips / wells only. Never use as a page or content-canvas fill.
    static let backgroundSecondary = Color(red: 0.953, green: 0.941, blue: 0.914) // #F3F0E9
    static let backgroundElevated = Color(red: 0.984, green: 0.976, blue: 0.957) // #FBF9F4
    static let backgroundTopGlow = Color(red: 1.000, green: 0.973, blue: 0.910) // #FFF8E8

    // Surfaces — pearl / warm-white (not pure #FFF); gentle lift off ivory canvas
    static let surfacePrimary = Color(red: 0.996, green: 0.994, blue: 0.988) // #FEFDFC elevated pearl
    static let surfaceSecondary = Color(red: 0.969, green: 0.961, blue: 0.945) // #F7F5F1
    static let surfaceTertiary = Color(red: 0.941, green: 0.933, blue: 0.918) // #F0EEEA
    /// Standard card body — warm pearl, slightly quieter than elevated.
    static let surfaceCard = Color(red: 0.992, green: 0.988, blue: 0.980) // #FDFCF9
    static let internalTile = Color(red: 0.961, green: 0.953, blue: 0.937) // #F5F3EF
    static let thumbnailWell = Color(red: 0.945, green: 0.937, blue: 0.922) // #F1EFEB

    // Text (solid roles — never opacity hierarchy)
    // Secondary aims ≥ WCAG AA on ivory (#FBF9F4): ~#636366 system gray.
    static let textPrimary = Color(red: 0.165, green: 0.157, blue: 0.145) // #2A2825
    static let textSecondary = Color(red: 0.388, green: 0.388, blue: 0.400) // #636366
    static let textTertiary = Color(red: 0.455, green: 0.447, blue: 0.431) // #74726E
    static let textQuaternary = Color(red: 0.561, green: 0.541, blue: 0.510) // #8F8A82
    static let textDisabled = Color(red: 0.702, green: 0.682, blue: 0.651) // #B3AEA6

    // MARK: - Icons

    static let iconPrimary = Color(red: 0.227, green: 0.216, blue: 0.200) // #3A3733
    static let iconSecondary = Color(red: 0.420, green: 0.408, blue: 0.388) // #6B6863
    static let iconInactive = Color(red: 0.561, green: 0.541, blue: 0.510) // #8F8A82

    // MARK: - Edges / tracks

    static let divider = Color(red: 0.847, green: 0.831, blue: 0.804) // #D8D4CD
    /// Hairline edge ink — used at very low opacity; top rim prefers white highlight.
    static let cardBorder = Color(red: 0.0, green: 0.0, blue: 0.0) // stroke via opacity
    static let cardBorderStrokeOpacity: Double = 0.045
    /// Soft top-edge highlight (precision rim, not a visible outline).
    static let cardEdgeHighlight = Color.white
    /// Airy chart / ring track (#E5E5EA).
    static let inactiveTrack = Color(red: 0.898, green: 0.898, blue: 0.918) // #E5E5EA

    // MARK: - Shadows (neutral black, tight & quiet — Wallet / Journal depth)

    static let shadowAmbient = Color.black
    static let shadowContact = Color.black
    static let cardContactShadowOpacity: Double = 0.045
    static let cardAmbientShadowOpacity: Double = 0.028

    // MARK: - Metrics

    static let activity = Color(red: 0.196, green: 0.725, blue: 0.420) // #32B96B
    static let activitySoft = Color(red: 0.886, green: 0.961, blue: 0.914) // #E2F5E9
    static let nutrition = Color(red: 0.898, green: 0.553, blue: 0.196) // #E58D32
    static let nutritionSoft = Color(red: 1.000, green: 0.941, blue: 0.875) // #FFF0DF
    static let recovery = Color(red: 0.208, green: 0.678, blue: 0.816) // #35ADD0
    static let recoverySoft = Color(red: 0.890, green: 0.957, blue: 0.973) // #E3F4F8

    static let coach = Color(red: 0.176, green: 0.741, blue: 0.451) // #2DBD73
    static let coachSoft = Color(red: 0.894, green: 0.965, blue: 0.925) // #E4F6EC
    static let coachPurple = Color(red: 0.482, green: 0.380, blue: 0.820) // #7B61D1
    static let coachPurpleSoft = Color(red: 0.937, green: 0.918, blue: 0.984) // #EFEAFB

    static let water = Color(red: 0.255, green: 0.545, blue: 0.878) // #418BE0
    static let waterSoft = Color(red: 0.906, green: 0.941, blue: 0.988) // #E7F0FC
    static let stress = Color(red: 0.839, green: 0.604, blue: 0.196) // #D69A32
    static let stressSoft = Color(red: 1.000, green: 0.945, blue: 0.843) // #FFF1D7

    // MARK: - Brand / chrome

    static let brandGold = Color(red: 0.725, green: 0.541, blue: 0.196) // #B98A32
    static let brandGoldSoft = Color(red: 0.949, green: 0.898, blue: 0.765) // #F2E5C3
    static let brandGoldDark = Color(red: 0.588, green: 0.431, blue: 0.141) // #966E24
    /// Active tab icon/label on champagne pill — darker for crisp contrast.
    static let tabActiveForeground = Color(red: 0.455, green: 0.333, blue: 0.106) // #74551B
    static let tabInactive = Color(red: 0.510, green: 0.490, blue: 0.463) // #827D76
    static let tabActiveCapsule = Color(red: 0.953, green: 0.906, blue: 0.784) // #F3E7C8
    static let tabGoldAccent = Color(red: 0.725, green: 0.541, blue: 0.196) // #B98A32

    // MARK: - CTA

    static let primaryCTA = Color(red: 0.239, green: 0.749, blue: 0.459) // #3DBF75
    static let primaryCTAForeground = Color.white
    static let softCTA = Color(red: 0.804, green: 0.937, blue: 0.851) // #CDEFD9
    static let softCTAForeground = Color(red: 0.090, green: 0.298, blue: 0.173) // #174C2C

    // MARK: - Status

    static let success = Color(red: 0.184, green: 0.686, blue: 0.400) // #2FAF66
    static let warning = Color(red: 0.831, green: 0.573, blue: 0.173) // #D4922C
    static let critical = Color(red: 0.839, green: 0.345, blue: 0.322) // #D65852
    static let informational = Color(red: 0.255, green: 0.545, blue: 0.878) // #418BE0

    // MARK: - Macros

    static let protein = Color(red: 0.522, green: 0.404, blue: 0.831) // #8567D4
    static let carbs = Color(red: 0.894, green: 0.553, blue: 0.243) // #E48D3E
    static let fats = Color(red: 0.851, green: 0.373, blue: 0.529) // #D95F87
    static let fiber = Color(red: 0.247, green: 0.706, blue: 0.451) // #3FB473

    // Aliases for existing call sites
    static let cardPrimary = surfaceCard
    static let cardElevated = surfacePrimary
    static let cardGrouped = surfaceTertiary
    static let ringTrack = inactiveTrack
    static let tabActive = brandGoldDark
}
