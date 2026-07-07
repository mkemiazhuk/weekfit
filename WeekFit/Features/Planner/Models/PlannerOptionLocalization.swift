import Foundation

enum PlannerOptionLocalization {

    static func localizedTitle(for storedTitle: String) -> String {
        switch storedTitle.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Cycling": return WeekFitLocalizedString("planner.option.cycling")
        case "Running": return WeekFitLocalizedString("planner.option.running")
        case "Upper Body": return WeekFitLocalizedString("planner.option.upperBody")
        case "Core": return WeekFitLocalizedString("planner.option.core")
        case "Lower Body": return WeekFitLocalizedString("planner.option.lowerBody")
        case "Full Body": return WeekFitLocalizedString("planner.option.fullBody")
        case "Tennis": return WeekFitLocalizedString("planner.option.tennis")
        case "Squash": return WeekFitLocalizedString("planner.option.squash")
        case "Stretching": return WeekFitLocalizedString("planner.option.stretching")
        case "Walk": return WeekFitLocalizedString("planner.option.walk")
        case "Sauna": return WeekFitLocalizedString("planner.option.sauna")
        case "Yoga": return WeekFitLocalizedString("planner.option.yoga")
        case "Breathing": return WeekFitLocalizedString("planner.option.breathing")
        case "Drink Water": return WeekFitLocalizedString("planner.option.drinkWater")
        case "Sleep Routine": return WeekFitLocalizedString("planner.option.sleepRoutine")
        case "No Screens": return WeekFitLocalizedString("planner.option.noScreens")
        case "Morning Routine": return WeekFitLocalizedString("planner.option.morningRoutine")
        case "No saved meals": return WeekFitLocalizedString("planner.emptyMeal.title")
        default: return storedTitle
        }
    }

    static func localizedSubtitle(for storedSubtitle: String) -> String {
        switch storedSubtitle.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Endurance": return WeekFitLocalizedString("planner.option.subtitle.endurance")
        case "Cardio": return WeekFitLocalizedString("planner.option.subtitle.cardio")
        case "Strength": return WeekFitLocalizedString("planner.option.subtitle.strength")
        case "High Intensity": return WeekFitLocalizedString("planner.option.subtitle.highIntensity")
        case "Mobility": return WeekFitLocalizedString("planner.option.subtitle.mobility")
        case "Light recovery": return WeekFitLocalizedString("planner.option.subtitle.lightRecovery")
        case "Relax": return WeekFitLocalizedString("planner.option.subtitle.relax")
        case "Calm": return WeekFitLocalizedString("planner.option.subtitle.calm")
        case "Hydration": return WeekFitLocalizedString("planner.option.subtitle.hydration")
        case "Wind down": return WeekFitLocalizedString("planner.option.subtitle.windDown")
        case "Focus": return WeekFitLocalizedString("planner.option.subtitle.focus")
        case "Start day": return WeekFitLocalizedString("planner.option.subtitle.startDay")
        case "Create a meal first": return WeekFitLocalizedString("planner.emptyMeal.subtitle")
        default: return storedSubtitle
        }
    }
}
