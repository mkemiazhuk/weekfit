//import SwiftUI
//
//struct ActivityNutritionClassifier {
//
//    func profile(for activity: PlannedActivity) -> ActivityNutritionProfile {
//        let value = activity.type.lowercased()
//
//        if contains(value, ["strength", "gym", "weights", "lift"]) {
//            return .strength
//        }
//
//        if contains(value, ["run", "running"]) {
//            return .running
//        }
//
//        if contains(value, ["cardio", "hiit", "cycling", "bike"]) {
//            return .cardio
//        }
//
//        if contains(value, ["sauna", "spa", "heat"]) {
//            return .sauna
//        }
//
//        if contains(value, ["walk", "walking", "steps"]) {
//            return .walking
//        }
//
//        if contains(value, ["yoga", "stretch", "mobility"]) {
//            return .mobility
//        }
//
//        if contains(value, ["meditation", "breath", "relax"]) {
//            return .recovery
//        }
//
//        return .balanced
//    }
//
//    private func contains(_ value: String, _ keywords: [String]) -> Bool {
//        keywords.contains { value.contains($0) }
//    }
//}
