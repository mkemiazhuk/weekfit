import SwiftUI

enum WeekFitMealSlot: String {
    case breakfast
    case lunch
    case snack
    case dinner

    var title: String {
        switch self {
        case .breakfast:
            return WeekFitLocalizedString("meals.breakfast")

        case .lunch:
            return WeekFitLocalizedString("meals.lunch")

        case .snack:
            return WeekFitLocalizedString("meals.snack")

        case .dinner:
            return WeekFitLocalizedString("meals.dinner")
        }
    }

    var icon: String {
        switch self {
        case .breakfast:
            return "sun.max.fill"

        case .lunch:
            return "fork.knife"

        case .snack:
            return "leaf.fill"

        case .dinner:
            return "moon.fill"
        }
    }

    var color: Color {
        switch self {
        case .breakfast:
            return WeekFitTheme.orange

        case .lunch:
            return WeekFitTheme.green

        case .snack:
            return WeekFitTheme.blue

        case .dinner:
            return WeekFitTheme.purple
        }
    }
}
