import Foundation
import SwiftUI

struct QuickItem: Codable, Identifiable {

    let id: String
    let title: String
    let subtitle: String

    let category: Category

    let imageName: String
    let icon: String

    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int

    enum Category: String, Codable {
        case drink
        case snack
    }
}
