import SwiftUI

struct WeekFitDetailScreenHeader<Leading: View, Trailing: View>: View {

    let title: String
    var subtitle: String? = nil
    var titleSize: CGFloat = 30
    var titleTracking: CGFloat = -0.75
    var titleMinimumScaleFactor: CGFloat = 0.78
    var subtitleLineLimit: Int = 1
    var titleColor: Color = WeekFitTheme.primaryText
    var subtitleColor: Color = WeekFitTheme.secondaryText.opacity(0.76)
    var titleDesign: Font.Design = .rounded
    var spacing: CGFloat = 12
    var bottomPadding: CGFloat = 2

    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            leading()
                .fixedSize()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: titleSize, weight: .bold, design: titleDesign))
                    .foregroundStyle(titleColor)
                    .tracking(titleTracking)
                    .lineLimit(1)
                    .minimumScaleFactor(titleMinimumScaleFactor)
                    .allowsTightening(true)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13.2, weight: .semibold, design: titleDesign))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(subtitleLineLimit)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            trailing()
                .fixedSize()
        }
        .padding(.bottom, bottomPadding)
    }
}

struct WeekFitDetailScreenBackButton: View {

    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(WeekFitTheme.whiteOpacity(0.045))
                    .overlay {
                        Circle()
                            .stroke(WeekFitTheme.whiteOpacity(0.065), lineWidth: 1)
                    }

                Image(systemName: "chevron.left")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.primaryText.opacity(0.92))
            }
            .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WeekFitLocalizedString("common.action.back"))
    }
}

struct WeekFitDetailScreenCircleButton: View {

    let systemName: String
    var iconSize: CGFloat = 14
    var iconWeight: Font.Weight = .semibold
    var accessibilityLabelText: String?
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(WeekFitTheme.whiteOpacity(0.045))
                    .overlay {
                        Circle()
                            .stroke(WeekFitTheme.whiteOpacity(0.065), lineWidth: 1)
                    }

                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: iconWeight))
                    .foregroundStyle(WeekFitTheme.primaryText.opacity(0.86))
            }
            .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelText ?? systemName)
    }
}

struct WeekFitDetailScreenSaveButton: View {

    let isEnabled: Bool
    let accent: Color
    let action: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                // Light: same soft circle chrome as Back / close controls.
                // Dark: slightly stronger disc so the save affordance still reads.
                Circle()
                    .fill(saveDiscFill)
                    .overlay {
                        Circle()
                            .stroke(saveDiscStroke, lineWidth: 1)
                    }

                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        isEnabled
                        ? accent.opacity(0.95)
                        : WeekFitTheme.secondaryText.opacity(palette.isLight ? 0.55 : 0.42)
                    )
            }
            .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(WeekFitLocalizedString("common.action.save"))
        .scaleEffect(isEnabled ? 1.0 : 0.96)
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: isEnabled)
    }

    private var saveDiscFill: Color {
        if palette.isLight {
            return isEnabled
                ? accent.opacity(0.12)
                : WeekFitLightTokens.internalTile
        }
        return WeekFitTheme.whiteOpacity(isEnabled ? 0.16 : 0.10)
    }

    private var saveDiscStroke: Color {
        if palette.isLight {
            return isEnabled
                ? accent.opacity(0.28)
                : WeekFitLightTokens.cardBorder.opacity(0.14)
        }
        return WeekFitTheme.whiteOpacity(isEnabled ? 0.08 : 0.05)
    }
}
