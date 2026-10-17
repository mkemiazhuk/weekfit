import SwiftUI

enum WeekFitStyle {

    /// Dense Plan / sheet tokens. Prefer `WeekFitType` for new UI (Dynamic Type roles).
    enum Font {
        static let screenTitle = WeekFitType.screenTitle
        static let sectionTitle = WeekFitType.sectionTitle
        static let cardTitle = WeekFitType.cardTitle
        static let cardSubtitle = WeekFitType.secondary
        static let body = WeekFitType.body
        static let caption = WeekFitType.captionEmphasized
        /// Dense timeline / chip exception — not a general body style.
        static let tiny = SwiftUI.Font.caption2.weight(.bold)
        static let button = WeekFitType.button
        static let icon = SwiftUI.Font.subheadline.weight(.bold)
        static let dayNumber = SwiftUI.Font.body.weight(.bold)
        static let dayName = SwiftUI.Font.caption.weight(.semibold)
        /// Keep Plan time tokens in step with `WeekFitType.body`.
        static let timelineTime = WeekFitType.body.weight(.medium)
        static let timelineTimeActive = WeekFitType.body.weight(.semibold)
        static let sheetTitle = WeekFitType.cardTitle
        static let sheetSubtitle = WeekFitType.secondary
        static let optionTitle = WeekFitType.secondary.weight(.semibold)
        static let optionSubtitle = WeekFitType.caption
        static let iconSmall = SwiftUI.Font.caption.weight(.bold)
        static let iconLarge = SwiftUI.Font.body.weight(.semibold)
        static let iconMedium = SwiftUI.Font.subheadline.weight(.bold)
    }

    enum Size {
        static let horizontalPadding: CGFloat = 18
        static let cardRadius: CGFloat = 22
        static let compactCardRadius: CGFloat = 18
        static let largeCardRadius: CGFloat = 28
        static let sheetRadius: CGFloat = 30
        static let compactButton: CGFloat = 38
        static let iconCircle: CGFloat = 34
        static let timelineRow: CGFloat = 66
        static let plannedCardHeight: CGFloat = 40
        static let timelineEmptyRow: CGFloat = 52
        static let circleButton: CGFloat = 36
        static let dayCell: CGFloat = 32
        static let sheetCornerRadius: CGFloat = 30
    }

    enum Spacing {
        static let screen: CGFloat = 14
        static let card: CGFloat = 10
        static let compact: CGFloat = 7
    }

    enum Shadow {
        static let soft = Color.black.opacity(0.04)
        static let medium = Color.black.opacity(0.08)
    }

    static let background = Color(red: 0.955, green: 0.962, blue: 0.968)
    static let cardWhite = Color.white.opacity(0.94)
    static let textPrimary = Color.black.opacity(0.88)
    static let textSecondary = Color.black.opacity(0.48)
    /// Soft brand green — Light follows theme coach/CTA; Dark keeps legacy sage.
    @MainActor
    static var brandGreen: Color { WeekFitTheme.primaryGreen }
    static let sageGreen = Color(red: 0.54, green: 0.88, blue: 0.65)
    static let champagneGold = Color(red: 0.96, green: 0.75, blue: 0.36)

    static let mutedPurple = Color(red: 0.50, green: 0.36, blue: 0.88)
    static let mutedOrange = Color(red: 0.96, green: 0.56, blue: 0.26)
    static let amber = Color(red: 0.95, green: 0.65, blue: 0.12)
}
