import SwiftUI

enum QuickLogRowMetrics {
    static let height: CGFloat = QuickActionSheetDesign.Row.height
    static let horizontalPadding: CGFloat = QuickActionSheetDesign.Row.horizontalPadding
    static let imageSize: CGFloat = QuickActionSheetDesign.Row.imageSize
    static let imageCornerRadius: CGFloat = QuickActionSheetDesign.Row.imageCornerRadius
    static let cardCornerRadius: CGFloat = QuickActionSheetDesign.Row.cardCornerRadius
    static let plusButtonSize: CGFloat = QuickActionSheetDesign.Row.actionButtonSize
}

struct QuickLogRowView<ImageContent: View>: View {
    let title: String
    let subtitle: String
    let metaText: String?
    let accentColor: Color
    let selection: QuickLogSelection
    let displayQuantity: Double
    @ViewBuilder let imageContent: () -> ImageContent
    let onPlusTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let cardSecondary = WeekFitTheme.cardSecondary
    private let cardBackground = WeekFitTheme.cardBackground

    var body: some View {
        HStack(spacing: QuickActionSheetDesign.Row.contentSpacing) {
            HStack(spacing: QuickActionSheetDesign.Row.contentSpacing) {
                mealImage

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(QuickActionSheetDesign.Typography.rowTitle)
                        .foregroundStyle(textPrimary)
                        .tracking(-0.2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(QuickActionSheetDesign.Typography.rowSubtitle)
                        .foregroundStyle(textSecondary.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if let metaText {
                        Text(metaText)
                            .font(QuickActionSheetDesign.Typography.rowMeta)
                            .foregroundStyle(textSecondary.opacity(0.52))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            QuickAddQuantityControl(
                quantity: displayQuantity,
                isExpanded: selection.isExpanded,
                isSelected: selection.isSelected,
                accentColor: accentColor,
                onPlusTap: onPlusTap,
                onIncrement: onIncrement,
                onDecrement: onDecrement
            )
        }
        .padding(.horizontal, QuickLogRowMetrics.horizontalPadding)
        .frame(height: QuickLogRowMetrics.height)
        .quickLogSelectableRowBackground(
            cardSecondary: cardSecondary,
            cardBackground: cardBackground,
            cornerRadius: QuickLogRowMetrics.cardCornerRadius,
            isSelected: selection.isSelected
        )
        .shadow(color: accentColor.opacity(selection.isSelected ? 0.04 : 0.025), radius: 8, y: 3)
    }

    private var mealImage: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: QuickLogRowMetrics.imageCornerRadius,
                style: .continuous
            )
            .fill(WeekFitTheme.whiteOpacity(0.04))

            imageContent()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.04),
                    Color.black.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.multiply)
            .allowsHitTesting(false)
        }
        .frame(width: QuickLogRowMetrics.imageSize, height: QuickLogRowMetrics.imageSize)
        .clipShape(
            RoundedRectangle(
                cornerRadius: QuickLogRowMetrics.imageCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: QuickLogRowMetrics.imageCornerRadius,
                style: .continuous
            )
            .stroke(WeekFitTheme.whiteOpacity(0.045), lineWidth: 1)
        }
    }
}

private extension View {
    func quickLogSelectableRowBackground(
        cardSecondary: Color,
        cardBackground: Color,
        cornerRadius: CGFloat,
        isSelected: Bool
    ) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            cardSecondary.opacity(0.97),
                            cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    WeekFitTheme.whiteOpacity(isSelected ? 0.06 : 0.035),
                    lineWidth: 1
                )
        }
    }
}

#if DEBUG
#Preview("Quick Log Row States") {
    ScrollView {
        VStack(spacing: 10) {
            QuickLogRowView(
                title: "Chicken Bowl",
                subtitle: "350g serving",
                metaText: "520 kcal • P 42g • C 38g • F 18g",
                accentColor: Color(red: 0.50, green: 0.74, blue: 0.54),
                selection: QuickLogSelection(),
                displayQuantity: 0,
                imageContent: {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.4))
                },
                onPlusTap: {},
                onIncrement: {},
                onDecrement: {}
            )

            QuickLogRowView(
                title: "Water",
                subtitle: "Hydration support",
                metaText: nil,
                accentColor: Color(red: 0.25, green: 0.55, blue: 0.95),
                selection: QuickLogSelection(portions: 2, isExpanded: true),
                displayQuantity: 2,
                imageContent: {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Color(red: 0.25, green: 0.55, blue: 0.95))
                },
                onPlusTap: {},
                onIncrement: {},
                onDecrement: {}
            )
        }
        .padding(18)
    }
    .background(Color(red: 0.035, green: 0.043, blue: 0.047))
}
#endif
