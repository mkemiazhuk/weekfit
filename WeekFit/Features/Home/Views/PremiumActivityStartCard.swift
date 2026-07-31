import SwiftUI
import SwiftData

struct PremiumActivityStartCard: View {

    let title: String
    let subtitle: String
    let imageName: String
    let systemIcon: String
    let accentColor: Color
    let cardBackground: Color
    let textSecondary: Color
    let durationMinutes: Int
    let plannerType: PlannerType
    let badge: String?
    let hasConflict: Bool
    let action: () -> Void

    @Environment(\.weekFitPalette) private var palette
    @State private var pressed = false

    private var actionButtonSize: CGFloat { QuickActionSheetDesign.Row.actionButtonSize }

    private var titleColor: Color {
        hasConflict ? WeekFitTheme.secondaryText : WeekFitTheme.primaryText
    }

    private var metaColor: Color {
        hasConflict ? WeekFitTheme.tertiaryText : WeekFitTheme.secondaryText
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: QuickActionSheetDesign.Row.contentSpacing) {
                imageBlock

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(QuickActionSheetDesign.Typography.rowTitle)
                        .foregroundStyle(titleColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 6) {
                        if let badge {
                            Text(badge.uppercased())
                                .font(QuickActionSheetDesign.Typography.rowBadge)
                                .tracking(0.35)
                                .foregroundStyle(accentColor)
                                .lineLimit(1)
                        }

                        Text(cleanSubtitle)
                            .lineLimit(1)

                        if badge != nil {
                            Circle()
                                .fill(WeekFitTheme.quaternaryText)
                                .frame(width: 3, height: 3)
                        }

                        Text(formattedDuration(durationMinutes))
                            .monospacedDigit()
                    }
                    .font(QuickActionSheetDesign.Typography.rowSubtitle)
                    .foregroundStyle(metaColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 4)

                startControl
            }
            .padding(.horizontal, QuickActionSheetDesign.Row.horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: QuickActionSheetDesign.Row.height)
            .weekFitCompactRowCard(
                accent: hasConflict ? nil : accentColor,
                cornerRadius: QuickActionSheetDesign.Row.cardCornerRadius
            )
            .opacity(hasConflict ? 0.78 : 1.0)
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
                    RoundedRectangle(cornerRadius: QuickActionSheetDesign.Row.imageCornerRadius, style: .continuous)
                        .fill(accentColor.opacity(palette.isLight ? 0.14 : 0.10))

                    Image(systemName: systemIcon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .offset(y: -0.5)
                }
                .frame(
                    width: QuickActionSheetDesign.Row.imageSize,
                    height: QuickActionSheetDesign.Row.imageSize
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: QuickActionSheetDesign.Row.imageCornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: QuickActionSheetDesign.Row.imageCornerRadius, style: .continuous)
                        .stroke(
                            palette.isLight
                                ? WeekFitLightTokens.divider.opacity(0.45)
                                : WeekFitTheme.whiteOpacity(0.05),
                            lineWidth: 1
                        )
                }
            }
        }
        .opacity(hasConflict ? 0.72 : 1.0)
    }

    private var startControl: some View {
        ZStack {
            Circle()
                .fill(
                    hasConflict
                        ? WeekFitTheme.internalTile
                        : (palette.isLight ? accentColor.opacity(0.16) : accentColor.opacity(0.22))
                )
                .frame(width: actionButtonSize, height: actionButtonSize)

            Circle()
                .stroke(
                    hasConflict
                        ? WeekFitLightTokens.divider.opacity(0.50)
                        : accentColor.opacity(palette.isLight ? 0.35 : 0.22),
                    lineWidth: 1
                )

            Image(systemName: hasConflict ? "lock.fill" : "play.fill")
                .font(.system(size: hasConflict ? 10.5 : 11, weight: .semibold))
                .foregroundStyle(
                    hasConflict
                        ? WeekFitTheme.iconInactive
                        : (palette.isLight ? accentColor : Color.white.opacity(0.94))
                )
                .offset(x: hasConflict ? 0 : 0.5)
        }
        .frame(width: actionButtonSize, height: actionButtonSize)
    }

    private var cleanSubtitle: String {
        if subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plannerType == .workout
                ? WeekFitLocalizedString("home.activityStart.subtitle.training")
                : WeekFitLocalizedString("home.activityStart.subtitle.recovery")
        }

        return subtitle
            .replacingOccurrences(of: "• 60 min", with: "")
            .replacingOccurrences(of: "60 min", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formattedDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60

            if remainingMinutes == 0 {
                return String(format: WeekFitLocalizedString("common.duration.hoursShortFormat"), Int64(hours))
            }

            return String(
                format: WeekFitLocalizedString("common.duration.hoursMinutesShortFormat"),
                Int64(hours),
                Int64(remainingMinutes)
            )
        }

        return String(format: WeekFitLocalizedString("common.duration.minutesFormat"), Int64(minutes))
    }
}
