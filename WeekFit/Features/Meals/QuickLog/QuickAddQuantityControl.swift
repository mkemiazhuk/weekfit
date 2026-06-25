import SwiftUI

struct QuickAddQuantityControl: View {
    let quantity: Double
    let isExpanded: Bool
    let isSelected: Bool
    let accentColor: Color
    let onPlusTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    private let collapsedSize: CGFloat = QuickActionSheetDesign.Row.actionButtonSize
    private let expandedWidth: CGFloat = QuickActionSheetDesign.Row.actionExpandedWidth

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
        .frame(width: isExpanded ? expandedWidth : collapsedSize, height: collapsedSize, alignment: .trailing)
    }

    private var collapsedButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onPlusTap()
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(accentColor.opacity(isSelected ? 0.24 : 0.18))
                    .frame(width: collapsedSize, height: collapsedSize)
                    .overlay {
                        Circle()
                            .stroke(accentColor.opacity(isSelected ? 0.22 : 0.14), lineWidth: 1)
                    }

                Image(systemName: isSelected ? "checkmark" : "plus")
                    .font(.system(size: isSelected ? 11.5 : 15, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: collapsedSize, height: collapsedSize)

                if let badge = badgeText {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.84))
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background {
                            Capsule()
                                .fill(accentColor.opacity(0.94))
                        }
                        .offset(x: 4, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var expandedControl: some View {
        HStack(spacing: 0) {
            stepperButton(systemName: "minus", action: onDecrement)

            Text(QuickLogServingMath.formattedQuantity(max(quantity, 1)))
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .monospacedDigit()
                .frame(minWidth: 24)

            stepperButton(systemName: "plus", action: onIncrement)
        }
        .padding(.horizontal, 4)
        .frame(width: expandedWidth, height: collapsedSize)
        .background {
            Capsule()
                .fill(accentColor.opacity(0.16))
        }
        .overlay {
            Capsule()
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
        }
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 26, height: 26)
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
            Text("Not selected")
            Spacer()
            QuickAddQuantityControl(
                quantity: 0,
                isExpanded: false,
                isSelected: false,
                accentColor: Color(red: 0.50, green: 0.74, blue: 0.54),
                onPlusTap: {},
                onIncrement: {},
                onDecrement: {}
            )
        }

        HStack {
            Text("Selected x1")
            Spacer()
            QuickAddQuantityControl(
                quantity: 1,
                isExpanded: false,
                isSelected: true,
                accentColor: Color(red: 0.50, green: 0.74, blue: 0.54),
                onPlusTap: {},
                onIncrement: {},
                onDecrement: {}
            )
        }

        HStack {
            Text("Selected x2 collapsed")
            Spacer()
            QuickAddQuantityControl(
                quantity: 2,
                isExpanded: false,
                isSelected: true,
                accentColor: Color(red: 0.50, green: 0.74, blue: 0.54),
                onPlusTap: {},
                onIncrement: {},
                onDecrement: {}
            )
        }

        HStack {
            Text("Expanded")
            Spacer()
            QuickAddQuantityControl(
                quantity: 2,
                isExpanded: true,
                isSelected: true,
                accentColor: Color(red: 0.25, green: 0.55, blue: 0.95),
                onPlusTap: {},
                onIncrement: {},
                onDecrement: {}
            )
        }
    }
    .padding(24)
    .background(Color(red: 0.035, green: 0.043, blue: 0.047))
}
#endif
