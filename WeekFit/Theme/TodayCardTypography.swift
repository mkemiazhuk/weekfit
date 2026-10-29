import SwiftUI
import UIKit

/// Today-card-only type ramp (~+10–12% vs prior defaults).
/// Does **not** mutate global `WeekFitType` tokens — other screens stay unchanged.
/// Sizes are Dynamic-Type scaled via `UIFontMetrics`.
enum TodayCardTypography {

    // MARK: - Base points (pre-scale) = prior default × factor

    /// Ring center % — was 17 / 15 → ×1.12.
    private static let ringPercentBase: CGFloat = 19.0
    private static let ringPercentCompactBase: CGFloat = 16.8

    /// Activity / Nutrition / Recovery under rings — caption (~12) ×1.10.
    private static let ringCategoryBase: CGFloat = 13.2

    /// Calories / Good status — caption2 (~11) ×1.12.
    private static let ringPrimaryValueBase: CGFloat = 12.3

    /// Goal / remaining / Sleep — caption2 (~11) ×1.10.
    private static let ringMetaBase: CGFloat = 12.1

    /// Your day / Tonight’s focus / Log quickly — footnote (~13) ×1.10.
    private static let sectionLabelBase: CGFloat = 14.3

    /// Your plan / Recovery titles — body (~17) ×1.10.
    private static let cardTitleBase: CGFloat = 18.7

    /// Card descriptions — subheadline (~15) ×1.10.
    private static let cardBodyBase: CGFloat = 16.5

    /// Quick-action labels (Log drink / Log food / Start activity).
    private static let quickActionLabelBase: CGFloat = 16.0

    /// “Quick actions” heading only — Your day keeps `sectionLabel`.
    private static let quickActionSectionTitleBase: CGFloat = 16.0

    /// Legacy support line (unused after single-label quick actions).
    private static let quickActionSupportBase: CGFloat = 12.0

    // MARK: - Fonts

    static func ringPercent(compact: Bool) -> Font {
        system(
            compact ? ringPercentCompactBase : ringPercentBase,
            relativeTo: .body,
            weight: .bold
        )
    }

    static var ringCategory: Font {
        system(ringCategoryBase, relativeTo: .caption1, weight: .semibold)
    }

    static var ringPrimaryValue: Font {
        system(ringPrimaryValueBase, relativeTo: .caption2, weight: .bold)
    }

    static var ringMeta: Font {
        system(ringMetaBase, relativeTo: .caption2, weight: .medium)
    }

    static var sectionLabel: Font {
        system(sectionLabelBase, relativeTo: .footnote, weight: .medium)
    }

    static var cardTitle: Font {
        system(cardTitleBase, relativeTo: .body, weight: .semibold)
    }

    static var cardBody: Font {
        system(cardBodyBase, relativeTo: .subheadline, weight: .regular)
    }

    static var cardBodySemibold: Font {
        system(cardBodyBase, relativeTo: .subheadline, weight: .semibold)
    }

    static var quickActionSectionTitle: Font {
        system(quickActionSectionTitleBase, relativeTo: .subheadline, weight: .medium)
    }

    static var quickActionLabel: Font {
        system(quickActionLabelBase, relativeTo: .subheadline, weight: .medium)
    }

    static var quickActionSupport: Font {
        system(quickActionSupportBase, relativeTo: .caption1, weight: .regular)
    }

    // MARK: - Helpers

    private static func system(
        _ size: CGFloat,
        relativeTo textStyle: UIFont.TextStyle,
        weight: Font.Weight
    ) -> Font {
        let scaled = UIFontMetrics(forTextStyle: textStyle).scaledValue(for: size)
        return .system(size: scaled, weight: weight, design: .rounded)
    }
}
