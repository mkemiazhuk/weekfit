import Foundation
import SwiftUI

enum MealsType: String, Codable, CaseIterable, Identifiable {
    case preWorkout
    case recovery
    case highProtein
    case sleepSupport
    case hydration
    case antiInflammatory
    case balanced

    var id: String { rawValue }
}

struct Meals: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let imageName: String
    let type: MealsType
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let benefits: [String]
    let ingredients: [MealsIngredient]
    let suggestedTime: String?
    let builderImageItems: [MealBuilderImageItem]?
}

struct MealsIngredient: Codable, Equatable {
    let name: String
    let amount: String
}

struct MealBuilderImageItem: Codable, Equatable, Identifiable {
    let id: String
    let imageName: String
    let visualSize: Int
    let offsetX: Int
    let offsetY: Int
    let rotation: Int
    let zIndex: Int
    let grams: Int
}

extension Meals {
    var displayTime: String {
        suggestedTime ?? "12:00"
    }

    var displayType: String {
        type.title
    }

    var tag: String {
        benefits.first ?? type.title
    }

    var shortTitle: String {
        title.components(separatedBy: ",").first ?? title
    }

    var color: Color {
        type.color
    }

    var slot: WeekFitMealSlot {
        let time = displayTime
        let hour = Int(time.prefix(2)) ?? 12
        let minutes = Int(time.dropFirst(3).prefix(2)) ?? 0
        let totalMinutes = hour * 60 + minutes

        switch totalMinutes {
        case 6 * 60...(10 * 60 + 30):
            return .breakfast

        case 11 * 60...(14 * 60 + 30):
            return .lunch

        case 15 * 60...(17 * 60 + 30):
            return .snack

        default:
            return .dinner
        }
    }

    var slotTitle: String {
        slot.title
    }

    var generatedSteps: [String] {
        let ingredientNames = ingredients
            .prefix(4)
            .map { ingredient in
                ingredient.name
            }
            .joined(separator: ", ")

        return [
            "Prepare all ingredients: \(ingredientNames).",
            "Cook or assemble the main protein and base components.",
            "Add vegetables, toppings and dressing if included.",
            "Serve fresh and adjust seasoning to taste."
        ]
    }
}

extension MealsType {

    var title: String {
        switch self {
        case .preWorkout:
            return "Pre-Workout"

        case .recovery:
            return "Recovery"

        case .highProtein:
            return "High Protein"

        case .sleepSupport:
            return "Sleep Support"

        case .hydration:
            return "Hydration"

        case .antiInflammatory:
            return "Anti-Inflammatory"

        case .balanced:
            return "Balanced"
        }
    }

    var color: Color {
        switch self {

        case .preWorkout:
            return Color(
                red: 0.93,
                green: 0.63,
                blue: 0.30
            )

        case .recovery:
            return Color(
                red: 0.45,
                green: 0.72,
                blue: 0.56
            )

        case .highProtein:
            return Color(
                red: 0.58,
                green: 0.68,
                blue: 0.82
            )

        case .sleepSupport:
            return Color(
                red: 0.52,
                green: 0.47,
                blue: 0.78
            )

        case .hydration:
            return Color(
                red: 0.42,
                green: 0.68,
                blue: 0.86
            )

        case .antiInflammatory:
            return Color(
                red: 0.50,
                green: 0.70,
                blue: 0.48
            )

        case .balanced:
            return Color(
                red: 0.55,
                green: 0.68,
                blue: 0.62
            )
        }
    }
}
