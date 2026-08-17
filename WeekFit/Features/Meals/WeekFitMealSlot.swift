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

/// Library grouping for View All Meals — breakfast, lunch, dinner only.
enum MealLibraryPeriod: String, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast:
            return WeekFitLocalizedString("meals.breakfast")
        case .lunch:
            return WeekFitLocalizedString("meals.lunch")
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
        case .dinner:
            return "moon.fill"
        }
    }

    /// Period that matches the View All grouping windows.
    static func period(at hour: Int) -> MealLibraryPeriod {
        switch hour {
        case 0..<11:
            return .breakfast
        case 11..<16:
            return .lunch
        default:
            return .dinner
        }
    }

    static var current: MealLibraryPeriod {
        period(at: Calendar.current.component(.hour, from: Date()))
    }

    static func groupedSections(from meals: [Meals]) -> [(period: MealLibraryPeriod, meals: [Meals])] {
        allCases.compactMap { period in
            let items = meals.filter { $0.libraryPeriod == period }
            guard !items.isEmpty else { return nil }
            return (period, items)
        }
    }
}
