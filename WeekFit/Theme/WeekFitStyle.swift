import SwiftUI

enum WeekFitStyle {

    enum Font {
        static let screenTitle = SwiftUI.Font.system(size: 22, weight: .bold)
        static let sectionTitle = SwiftUI.Font.system(size: 20, weight: .bold)
        static let cardTitle = SwiftUI.Font.system(size: 14, weight: .bold)
        static let cardSubtitle = SwiftUI.Font.system(size: 11.5, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 12.8, weight: .semibold)
        static let caption = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let tiny = SwiftUI.Font.system(size: 8.5, weight: .bold)
        static let button = SwiftUI.Font.system(size: 15, weight: .bold)
        static let icon = SwiftUI.Font.system(size: 13.5, weight: .bold)
        static let dayNumber = SwiftUI.Font.system(size: 14, weight: .bold)
        static let dayName = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let timelineTime = SwiftUI.Font.system(size: 12, weight: .medium)
        static let timelineTimeActive = SwiftUI.Font.system(size: 12, weight: .bold)
        static let sheetTitle = SwiftUI.Font.system(size: 20, weight: .bold)
        static let sheetSubtitle = SwiftUI.Font.system(size: 12.5, weight: .semibold)
        static let optionTitle = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let optionSubtitle = SwiftUI.Font.system(size: 11.5, weight: .regular)
        static let iconSmall = SwiftUI.Font.system(size: 11, weight: .bold)
        static let iconLarge = SwiftUI.Font.system(size: 17, weight: .semibold)
        static let iconMedium = SwiftUI.Font.system(size: 15, weight: .bold)
    }

    enum Size {
        static let horizontalPadding: CGFloat = 18
        static let cardRadius: CGFloat = 22
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
    static let brandGreen = Color(red: 0.40, green: 0.74, blue: 0.53)
    static let sageGreen = Color(red: 0.54, green: 0.88, blue: 0.65)
    static let champagneGold = Color(red: 0.96, green: 0.75, blue: 0.36)

    static let mutedPurple = Color(red: 0.50, green: 0.36, blue: 0.88)
    static let mutedOrange = Color(red: 0.96, green: 0.56, blue: 0.26)
    static let amber = Color(red: 0.95, green: 0.65, blue: 0.12)
}
