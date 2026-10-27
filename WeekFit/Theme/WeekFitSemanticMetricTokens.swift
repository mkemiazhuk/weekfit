import SwiftUI

/// Canonical Activity / Nutrition / Recovery accents for the whole app
/// (rings, icons, charts, section chrome). Independent of tab-bar chrome.
enum WeekFitSemanticMetricTokens {

    // MARK: - Brand metric hues

    /// Activity — green.
    static let activity = Color(red: 0.447, green: 0.678, blue: 0.541) // #72AD8A
    /// Nutrition — orange.
    static let nutrition = Color(red: 0.918, green: 0.627, blue: 0.420) // #EAA06B
    /// Recovery — lavender.
    static let recovery = Color(red: 0.608, green: 0.541, blue: 0.796) // #9B8ACB

    // MARK: - Soft wells (icon badges / washes)

    static let activitySoft = Color(red: 0.910, green: 0.953, blue: 0.925) // #E8F3EC
    /// Soft peach well for Nutrition icons / Plan badges.
    static let nutritionSoft = Color(red: 0.973, green: 0.922, blue: 0.886) // #F8EBE2
    static let recoverySoft = Color(red: 0.941, green: 0.925, blue: 0.969) // #F0ECF7

    // MARK: - Label / icon ink (small text on white / milk — ≥4.5:1)

    static let activityInk = Color(red: 0.220, green: 0.420, blue: 0.302) // #386B4D
    static let nutritionInk = Color(red: 0.655, green: 0.392, blue: 0.196) // #A76432
    /// Soft terracotta for Nutrition icon glyphs (rings keep `nutrition`).
    static let nutritionIcon = Color(red: 0.863, green: 0.584, blue: 0.400) // #DC9566
    static let recoveryInk = Color(red: 0.365, green: 0.310, blue: 0.549) // #5D4F8C
}
