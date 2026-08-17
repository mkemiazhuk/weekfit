import SwiftUI

enum QuickAddChrome {
    /// Solid accent fill + light/dark icon (recommended cards).
    case solidFilled
    /// Soft surface + accent stroke/icon (library rows in the mock).
    case softOutline
}

enum QuickAddQuantityDensity {
    /// Full stepper for list rows.
    case regular
    /// Narrow stepper that fits frequent / recommended cards.
    case compact

    var expandedWidth: CGFloat {
        switch self {
        case .regular: return QuickActionSheetDesign.Row.actionExpandedWidth
        case .compact: return 74
        }
    }

    var stepperSize: CGFloat {
        switch self {
        case .regular: return 26
        case .compact: return 22
        }
    }

    var quantityFontSize: CGFloat {
        switch self {
        case .regular: return 13.5
        case .compact: return 12.5
        }
    }

    var quantityMinWidth: CGFloat {
        switch self {
        case .regular: return 24
        case .compact: return 18
        }
    }
}

struct QuickAddQuantityControl: View {
    let quantity: Double
    let isExpanded: Bool
    let isSelected: Bool
    let accentColor: Color
    var chrome: QuickAddChrome = .solidFilled
    var density: QuickAddQuantityDensity = .regular
    var collapsedVisualSize: CGFloat? = nil
    let onPlusTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    @Environment(\.weekFitPalette) private var palette

    private let collapsedSize: CGFloat = QuickActionSheetDesign.Row.actionButtonSize
    private var visualSize: CGFloat { collapsedVisualSize ?? collapsedSize }
    private var visualScale: CGFloat { visualSize / collapsedSize }
    private var expandedWidth: CGFloat { density.expandedWidth }

    var body: some View {
        ZStack {
            if isExpanded {
                expandedControl
                    .transition(.scale(scale: 0.88, anchor: .trailing).combined(with: .opacity))
            } else {
                collapsedButton
                    .transition(.scale(scale: 0.88, anchor: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isExpanded)
        .frame(width: isExpanded ? expandedWidth : collapsedSize, height: collapsedSize, alignment: .center)
    }

    private var collapsedButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onPlusTap()
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(collapsedFill)
                    .frame(width: visualSize, height: visualSize)
                    .overlay {
                        Circle()
                            .stroke(collapsedStroke, lineWidth: chrome == .softOutline ? 1.4 : 0.8)
                    }
                    .shadow(
                        color: palette.isLight && chrome == .solidFilled
                            ? accentColor.opacity(0.22)
                            : .clear,
                        radius: 4 * visualScale,
                        y: 2 * visualScale
                    )

                Image(systemName: isSelected ? "checkmark" : "plus")
                    .font(.system(size: (isSelected ? 11.5 : 15) * visualScale, weight: .semibold))
                    .foregroundStyle(collapsedForeground)
                    .frame(width: visualSize, height: visualSize)

                if let badge = badgeText {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(badgeForeground)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background {
                            Capsule().fill(badgeFill)
                        }
                        .offset(x: 4, y: -3)
                }
            }
            .frame(width: visualSize, height: visualSize)
            .frame(width: collapsedSize, height: collapsedSize, alignment: .center)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var collapsedFill: Color {
        switch chrome {
        case .solidFilled:
            return isSelected ? accentColor.opacity(0.92) : accentColor
        case .softOutline:
            if isSelected {
                return accentColor.opacity(palette.isLight ? 0.14 : 0.22)
            }
            return palette.isLight ? WeekFitLightTokens.surfaceCard : WeekFitTheme.whiteOpacity(0.06)
        }
    }

    private var collapsedStroke: Color {
        switch chrome {
        case .solidFilled:
            return accentColor.opacity(palette.isLight ? 0.22 : 0.28)
        case .softOutline:
            return accentColor.opacity(palette.isLight ? 0.55 : 0.45)
        }
    }

    private var collapsedForeground: Color {
        switch chrome {
        case .solidFilled:
            // Always light glyph on solid accent fill (gold / purple / green).
            return .white
        case .softOutline:
            return accentColor
        }
    }

    private var badgeFill: Color {
        switch chrome {
        case .solidFilled:
            return accentColor.opacity(palette.isLight ? 1.0 : 0.92)
        case .softOutline:
            return accentColor
        }
    }

    private var badgeForeground: Color {
        switch chrome {
        case .solidFilled:
            return .white
        case .softOutline:
            return .white
        }
    }

    private var expandedControl: some View {
        HStack(spacing: 0) {
            stepperButton(systemName: "minus", action: onDecrement)

            Text(QuickLogServingMath.formattedQuantity(max(quantity, 1)))
                .font(.system(size: density.quantityFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .monospacedDigit()
                .frame(minWidth: density.quantityMinWidth)

            stepperButton(systemName: "plus", action: onIncrement)
        }
        .padding(.horizontal, 4)
        .frame(width: expandedWidth, height: collapsedSize)
        .background {
            Capsule()
                .fill(
                    palette.isLight
                        ? WeekFitLightTokens.internalTile
                        : accentColor.opacity(0.16)
                )
        }
        .overlay {
            Capsule()
                .stroke(
                    accentColor.opacity(palette.isLight ? 0.28 : 0.18),
                    lineWidth: 1
                )
        }
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: density == .compact ? 11 : 12, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: density.stepperSize, height: density.stepperSize)
                .background {
                    Circle()
                        .fill(accentColor.opacity(0.14))
                }
        }
        .buttonStyle(.plain)
    }

    private var badgeText: String? {
        guard isSelected else { return nil }
        let rounded = Int(quantity.rounded())
        return rounded > 1 ? "\(rounded)" : nil
    }
}

#if DEBUG
#Preview("Quick Add States") {
    VStack(spacing: 18) {
        HStack {
            Text("Filled")
            Spacer()
            QuickAddQuantityControl(
                quantity: 0,
                isExpanded: false,
                isSelected: false,
                accentColor: WeekFitLightTokens.brandGold,
                chrome: .solidFilled,
                onPlusTap: {},
                onIncrement: {},
                onDecrement: {}
            )
        }
        HStack {
            Text("Outline")
            Spacer()
            QuickAddQuantityControl(
                quantity: 0,
                isExpanded: false,
                isSelected: false,
                accentColor: QuickDrinkAccent.listAction,
                chrome: .softOutline,
                onPlusTap: {},
                onIncrement: {},
                onDecrement: {}
            )
        }
    }
    .padding()
    .background(WeekFitLightTokens.backgroundPrimary)
}
#endif
