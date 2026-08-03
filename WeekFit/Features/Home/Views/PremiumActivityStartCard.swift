import SwiftUI

struct PremiumActivityStartCard: View {

    let title: String
    let category: ActivityOptionPresentation.Category
    let categoryLabel: String
    let detailLine: String
    let chip: ActivityOptionPresentation.DetailChip
    let chipLabel: String
    let imageName: String
    let systemIcon: String
    let accentColor: Color
    let hasConflict: Bool
    let action: () -> Void

    @Environment(\.weekFitPalette) private var palette
    @State private var pressed = false

    private var actionButtonSize: CGFloat { 40 }

    private var titleColor: Color {
        hasConflict ? WeekFitTheme.secondaryText : WeekFitTheme.primaryText
    }

    private var metaColor: Color {
        hasConflict ? WeekFitTheme.tertiaryText : WeekFitTheme.secondaryText.opacity(0.62)
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                imageBlock

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)

                    HStack(spacing: 5) {
                        Text(categoryLabel.uppercased())
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(categoryForeground)

                        Text(detailLine)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(metaColor)
                            .lineLimit(1)
                    }

                    detailChip
                        .padding(.top, 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                startControl
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .quickSheetFloatingCard(
                cornerRadius: 18,
                fill: palette.isLight ? WeekFitLightTokens.surfaceCard : WeekFitTheme.cardBackground,
                stroke: palette.isLight
                    ? Color.black.opacity(0.05)
                    : WeekFitTheme.whiteOpacity(0.07),
                isLight: palette.isLight
            )
            .opacity(hasConflict ? 0.72 : 1.0)
            .scaleEffect(pressed ? 0.985 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(hasConflict)
        .accessibilityLabel(title)
        .accessibilityHint(
            hasConflict
                ? WeekFitLocalizedString("home.activityStart.activeSession.subtitle")
                : WeekFitLocalizedString("home.activityStart.subtitle")
        )
    }

    /// Light keeps mock rainbow; Dark uses the tab accent only.
    private var categoryForeground: Color {
        palette.isLight ? category.color : accentColor
    }

    private var imageBlock: some View {
        Group {
            if !imageName.isEmpty, UIImage(named: imageName) != nil {
                PremiumAssetImage(
                    imageName: imageName,
                    style: .activityThumbnail,
                    accentColor: accentColor,
                    fallbackSystemName: systemIcon
                )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            palette.isLight
                                ? accentColor.opacity(0.10)
                                : WeekFitTheme.whiteOpacity(0.06)
                        )

                    Image(systemName: systemIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            palette.isLight
                                ? accentColor.opacity(0.75)
                                : WeekFitTheme.secondaryText.opacity(0.55)
                        )
                }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    palette.isLight ? Color.black.opacity(0.05) : WeekFitTheme.whiteOpacity(0.06),
                    lineWidth: 1
                )
        }
        .opacity(hasConflict ? 0.72 : 1.0)
    }

    private var detailChip: some View {
        HStack(spacing: 5) {
            Image(systemName: chip.symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(chipIconColor)
            Text(chipLabel)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.78))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(
                    palette.isLight
                        ? WeekFitLightTokens.internalTile
                        : WeekFitTheme.whiteOpacity(0.08)
                )
        }
    }

    private var chipIconColor: Color {
        palette.isLight ? category.color : accentColor
    }

    private var startControl: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    hasConflict
                        ? WeekFitTheme.iconInactive.opacity(0.35)
                        : accentColor,
                    lineWidth: 1.6
                )
                .frame(width: actionButtonSize, height: actionButtonSize)

            Image(systemName: hasConflict ? "lock.fill" : "play.fill")
                .font(.system(size: hasConflict ? 11 : 12, weight: .semibold))
                .foregroundStyle(hasConflict ? WeekFitTheme.iconInactive : accentColor)
                .offset(x: hasConflict ? 0 : 0.5)
        }
        .frame(width: actionButtonSize, height: actionButtonSize)
    }
}

enum QuickActivityAccent {
    /// Workout — green (matches mock / activity token).
    static let workout = Color(red: 0.22, green: 0.72, blue: 0.45)
    /// Recovery — soft purple (distinct from workout).
    static let recovery = Color(red: 0.62, green: 0.54, blue: 0.86)

    static let green = workout

    static func color(for type: PlannerType, isLight: Bool) -> Color {
        switch type {
        case .workout:
            return isLight ? workout : Color(red: 0.42, green: 0.78, blue: 0.58)
        case .recovery:
            return isLight ? WeekFitLightTokens.coachPurple : recovery
        default:
            return workout
        }
    }

    static func frequentFill(accent: Color, isLight: Bool) -> Color {
        guard isLight else { return WeekFitTheme.whiteOpacity(0.06) }
        return accent.opacity(0.11)
    }

    static func frequentStroke(accent: Color, isLight: Bool) -> Color {
        guard isLight else { return WeekFitTheme.whiteOpacity(0.08) }
        return accent.opacity(0.16)
    }
}
