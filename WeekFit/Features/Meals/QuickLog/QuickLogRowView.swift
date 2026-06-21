import SwiftUI

enum QuickLogRowMetrics {
    static let height: CGFloat = 74
    static let horizontalPadding: CGFloat = 12
    static let imageSize: CGFloat = 60
    static let imageCornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 23
    static let plusButtonSize: CGFloat = 42
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
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                mealImage

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.35)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(.system(size: 12.2, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.56))
                        .lineLimit(1)

                    if let metaText {
                        Text(metaText)
                            .font(.system(size: 11.2, weight: .semibold, design: .rounded))
                            .foregroundStyle(textSecondary.opacity(0.62))
                            .lineLimit(1)
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
        .shadow(color: accentColor.opacity(selection.isSelected ? 0.05 : 0.035), radius: 12, y: 5)
    }

    private var mealImage: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: QuickLogRowMetrics.imageCornerRadius,
                style: .continuous
            )
            .fill(Color.white.opacity(0.04))

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
            .stroke(Color.white.opacity(0.045), lineWidth: 1)
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
                    Color.white.opacity(isSelected ? 0.06 : 0.035),
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
                        .foregroundStyle(.white.opacity(0.4))
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
