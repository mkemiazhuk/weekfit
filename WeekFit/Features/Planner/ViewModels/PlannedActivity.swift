import Foundation
import SwiftData
import SwiftUI

@Model
final class PlannedActivity {
    @Attribute(.unique) var id: String
    
    var healthKitWorkoutUUID: String?

    var date: Date
    var type: String
    var title: String
    var durationMinutes: Int
    var icon: String
    var imageName: String = ""

    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double

    var calories: Int = 0
    var protein: Int = 0
    var carbs: Int = 0
    var fats: Int = 0
    var fiber: Int = 0

    var isCompleted: Bool = false
    var isSkipped: Bool = false
    var source: String = "planner"
    
    var actualDurationMinutes: Int?

    init(
        id: String = UUID().uuidString,
        healthKitWorkoutUUID: String? = nil,
        date: Date,
        type: String,
        title: String,
        durationMinutes: Int,
        icon: String,
        imageName: String = "",
        colorRed: Double,
        colorGreen: Double,
        colorBlue: Double,
        calories: Int = 0,
        protein: Int = 0,
        carbs: Int = 0,
        fats: Int = 0,
        fiber: Int = 0,
        isCompleted: Bool = false,
        isSkipped: Bool = false,
        source: String = "planner"
    ) {
        self.id = id
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
        self.date = date
        self.type = type
        self.title = title
        self.durationMinutes = durationMinutes
        self.icon = icon
        self.imageName = imageName
        self.colorRed = colorRed
        self.colorGreen = colorGreen
        self.colorBlue = colorBlue
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.fiber = fiber
        self.isCompleted = isCompleted
        self.isSkipped = isSkipped
        self.source = source
    }
}

extension PlannedActivity {
    var color: Color {
        Color(red: colorRed, green: colorGreen, blue: colorBlue)
    }
}

struct DisplayActivity: Identifiable {
    let id: String
    let timeString: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let calories: Int
    let isWater: Bool
    let totalWaterVolume: Double?
    let isCompleted: Bool
    let originalActivities: [PlannedActivity]
}

extension PlannedActivity {
    var effectiveDurationMinutes: Int {
        if isCompleted, let actualDurationMinutes, actualDurationMinutes > 0 {
            return actualDurationMinutes
        }

        return durationMinutes
    }
}
