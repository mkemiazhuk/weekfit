import Foundation
import SwiftUI

enum CoachTabPresentationIntent: String, Hashable {
    case statusAction
    case interpretation
}

struct CoachActivityContextChip: Hashable {
    let icon: String
    let label: String
}

struct CoachPresentationWhyRow: Hashable {
    let title: String
    let icon: String
    let color: Color
}

struct CoachSupportAction: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}
