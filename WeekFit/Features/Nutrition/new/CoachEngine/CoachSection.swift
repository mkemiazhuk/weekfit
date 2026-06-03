import Foundation
import SwiftUI

struct CoachSection: Identifiable {

    let id = UUID()

    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let style: CoachSectionStyle

    let items: [String]
    let informationalText: String?

    init(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        style: CoachSectionStyle,
        items: [String] = [],
        informationalText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.style = style
        self.items = items
        self.informationalText = informationalText
    }

    var isEmpty: Bool {

        let hasItems = items.contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let hasInfo =
            !(informationalText?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty ?? true)

        return !hasItems && !hasInfo
    }
}

enum CoachSectionStyle {
    case compact
    case cards
    case info
}
