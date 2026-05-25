import Foundation

struct PlanItem: Identifiable {
    let id = UUID()
    let date: Date
    let category: PlanCategory
    let title: String
    let durationMinutes: Int
}
