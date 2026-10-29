import SwiftUI

/// Approved WeekFit Light Mode semantic palette.
/// Dark Mode values live elsewhere and must remain unchanged.
enum WeekFitLightTokens {
    // Foundation — warm milk canvas across all main tabs
    static let backgroundPrimary = Color(red: 0.969, green: 0.965, blue: 0.949) // #F7F6F2
    /// Soft secondary milk — chips / wells only. Never use as a page or content-canvas fill.
    static let backgroundSecondary = Color(red: 0.941, green: 0.933, blue: 0.914) // #F0EEE9
    static let backgroundElevated = Color(red: 0.969, green: 0.965, blue: 0.949) // #F7F6F2
    static let backgroundTopGlow = Color(red: 1.000, green: 0.976, blue: 0.925) // #FFF9EC

    // Surfaces — true white cards so they lift cleanly off the milk canvas.
    static let surfacePrimary = Color.white
    static let surfaceSecondary = Color(red: 0.961, green: 0.957, blue: 0.945) // #F5F4F1
    static let surfaceTertiary = Color(red: 0.937, green: 0.929, blue: 0.914) // #EFEEE9
    /// Standard card body — pure white (no warm cast).
    static let surfaceCard = Color.white
    static let internalTile = Color(red: 0.953, green: 0.949, blue: 0.937) // #F3F2EF
    static let thumbnailWell = Color(red: 0.941, green: 0.937, blue: 0.925) // #F0EFEC

    // Text (solid roles — never opacity hierarchy)
    // Primary graphite on milk (#F7F6F2) / white cards — WCAG AA+.
    static let textPrimary = Color(red: 0.161, green: 0.169, blue: 0.157) // #292B28
    static let textSecondary = Color(red: 0.365, green: 0.373, blue: 0.361) // #5D5F5C
    static let textTertiary = Color(red: 0.455, green: 0.463, blue: 0.451) // #747673
    static let textQuaternary = Color(red: 0.561, green: 0.565, blue: 0.545) // #8F908B
    static let textDisabled = Color(red: 0.702, green: 0.698, blue: 0.671) // #B3B2AB

    // MARK: - Icons

    static let iconPrimary = Color(red: 0.220, green: 0.227, blue: 0.216) // #383A37
    static let iconSecondary = Color(red: 0.420, green: 0.427, blue: 0.412) // #6B6D69
    static let iconInactive = Color(red: 0.561, green: 0.565, blue: 0.545) // #8F908B

    // MARK: - Edges / tracks

    static let divider = Color(red: 0.847, green: 0.839, blue: 0.820) // #D8D6D1
    /// Warm stone hairline — readable on milk without a hard outline.
    static let cardBorder = Color(red: 0.36, green: 0.34, blue: 0.31) // #5C574F
    static let cardBorderStrokeOpacity: Double = 0.11
    /// Soft top-edge highlight (precision rim, not a visible outline).
    static let cardEdgeHighlight = Color.white
    /// Airy chart / ring track (#E5E5EA).
    static let inactiveTrack = Color(red: 0.898, green: 0.898, blue: 0.918) // #E5E5EA

    // MARK: - Shadows (short contact only — wide ambient casts a rectangular slab on milk)

    static let shadowAmbient = Color.black
    static let shadowContact = Color.black
    static let cardContactShadowOpacity: Double = 0.035
    static let cardAmbientShadowOpacity: Double = 0.014

    // MARK: - Metrics (aliases → WeekFitSemanticMetricTokens)

    static let activity = WeekFitSemanticMetricTokens.activity
    static let activitySoft = WeekFitSemanticMetricTokens.activitySoft
    static let activityInk = WeekFitSemanticMetricTokens.activityInk

    static let nutrition = WeekFitSemanticMetricTokens.nutrition
    static let nutritionSoft = WeekFitSemanticMetricTokens.nutritionSoft
    static let nutritionInk = WeekFitSemanticMetricTokens.nutritionInk

    /// Recovery — lavender (not shared with drinks / hydration).
    static let recovery = WeekFitSemanticMetricTokens.recovery
    static let recoverySoft = WeekFitSemanticMetricTokens.recoverySoft
    static let recoveryInk = WeekFitSemanticMetricTokens.recoveryInk

    static let coach = WeekFitSemanticMetricTokens.activity
    static let coachSoft = WeekFitSemanticMetricTokens.activitySoft
    /// Coach purple chrome follows recovery lavender.
    static let coachPurple = WeekFitSemanticMetricTokens.recovery
    static let coachPurpleSoft = WeekFitSemanticMetricTokens.recoverySoft

    /// Hydration / drinks — cool teal (distinct from Recovery lavender).
    static let water = Color(red: 0.208, green: 0.678, blue: 0.816) // #35ADD0
    static let waterSoft = Color(red: 0.902, green: 0.961, blue: 0.973) // #E6F5F8
    static let waterInk = Color(red: 0.071, green: 0.455, blue: 0.557) // #12748E

    static let stress = Color(red: 0.831, green: 0.573, blue: 0.173) // #D4922C
    static let stressSoft = Color(red: 1.000, green: 0.949, blue: 0.867) // #FFF2DD

    /// Delicate stroke for pastel metric wells / icon badges.
    static let softBadgeStrokeOpacity: Double = 0.22

    // MARK: - Brand / chrome

    /// Brand gold — avatar ring/glyph, Quick Log / onboarding accents.
    static let brandGold = Color(red: 0.725, green: 0.541, blue: 0.196) // #B98A32
    static let brandGoldSoft = Color(red: 0.949, green: 0.898, blue: 0.765) // #F2E5C3
    static let brandGoldDark = Color(red: 0.588, green: 0.431, blue: 0.141) // #966E24

    // MARK: - Tab bar (aliases → WeekFitTabBarTokens)

    static let tabActiveForeground = WeekFitTabBarTokens.activeForegroundLight
    static let tabInactive = WeekFitTabBarTokens.inactiveLight
    /// Soft peach well for sheet chrome / legacy call sites (not the tab-bar wash).
    static let tabActiveCapsule = Color(red: 1.000, green: 0.953, blue: 0.906) // #FFF3E7
    static let tabActiveAccent = WeekFitTabBarTokens.activeForegroundLight
    /// Alias kept for older call sites that referenced the gold tab stroke.
    static let tabGoldAccent = tabActiveAccent
    /// Unused by current tab bar; kept for call-site compatibility.
    static let tabActiveFillOpacity: Double = 1.0

    // MARK: - Avatar (ceramic fill + brand-gold ring / glyph)

    static let avatarFill = Color(red: 0.980, green: 0.976, blue: 0.969) // #FAF9F7
    /// Gold ring ink (used by plain circular variant / legacy call sites).
    static let avatarStroke = brandGold
    static let avatarStrokeOpacity: Double = 0.55
    static let avatarGlyph = brandGoldDark

    // MARK: - CTA

    static let primaryCTA = Color(red: 0.239, green: 0.749, blue: 0.459) // #3DBF75
    static let primaryCTAForeground = Color.white
    static let softCTA = Color(red: 0.804, green: 0.937, blue: 0.851) // #CDEFD9
    static let softCTAForeground = Color(red: 0.090, green: 0.298, blue: 0.173) // #174C2C

    // MARK: - Status

    /// Calm completed green — shared with Plan checkmarks / Logged badges.
    static let success = WeekFitPlanChromeTokens.completed // #4D9875
    static let successSoft = WeekFitPlanChromeTokens.loggedBadgeFill // #EFF5F0
    static let successInk = WeekFitPlanChromeTokens.loggedBadgeInk // #487C60
    static let warning = Color(red: 0.831, green: 0.573, blue: 0.173) // #D4922C
    static let critical = Color(red: 0.839, green: 0.345, blue: 0.322) // #D65852
    static let informational = waterInk

    // MARK: - Macros

    static let protein = Color(red: 0.522, green: 0.404, blue: 0.831) // #8567D4
    static let carbs = Color(red: 0.894, green: 0.553, blue: 0.243) // #E48D3E
    static let fats = Color(red: 0.851, green: 0.373, blue: 0.529) // #D95F87
    static let fiber = Color(red: 0.247, green: 0.706, blue: 0.451) // #3FB473

    // MARK: - Maya Pearl call card (light only; dark uses the existing surfaces)

    /// White card body on the milk canvas.
    static let pearlCardFill = surfacePrimary
    /// Warm gray hairline, #DEDAD4.
    static let pearlCardBorder = Color(red: 0.871, green: 0.855, blue: 0.831)
    /// Warm graphite for the call control, #625D57.
    static let pearlInk = Color(red: 0.384, green: 0.365, blue: 0.341)
    /// Light cream well behind the emblem.
    static let pearlEmblemWell = Color(red: 0.965, green: 0.953, blue: 0.933)
    /// Muted taupe for the emblem on the cream well.
    static let pearlEmblemTaupe = Color(red: 0.545, green: 0.518, blue: 0.478)

    // Aliases for existing call sites
    static let cardPrimary = surfaceCard
    static let cardElevated = surfacePrimary
    static let cardGrouped = surfaceTertiary
    static let ringTrack = inactiveTrack
    static let tabActive = tabActiveForeground
}
