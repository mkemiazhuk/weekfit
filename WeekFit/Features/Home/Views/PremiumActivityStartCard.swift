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

    @State private var pressed = false

    private var actionButtonSize: CGFloat { QuickActionSheetDesign.Row.actionButtonSize }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: QuickActionSheetDesign.Row.contentSpacing) {
                imageBlock

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(QuickActionSheetDesign.Typography.rowTitle)
                        .foregroundStyle(WeekFitTheme.whiteOpacity(hasConflict ? 0.46 : 0.96))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 6) {
                        if let badge {
                            Text(badge.uppercased())
                                .font(QuickActionSheetDesign.Typography.rowBadge)
                                .tracking(0.35)
                                .foregroundStyle(accentColor.opacity(0.82))
                                .lineLimit(1)
                        }

                        Text(cleanSubtitle)
                            .lineLimit(1)

                        if badge != nil {
                            Circle()
                                .fill(textSecondary.opacity(0.24))
                                .frame(width: 3, height: 3)
                        }

                        Text(formattedDuration(durationMinutes))
                            .monospacedDigit()
                    }
                    .font(QuickActionSheetDesign.Typography.rowSubtitle)
                    .foregroundStyle(textSecondary.opacity(hasConflict ? 0.34 : 0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 4)

                startControl
            }
            .padding(.horizontal, QuickActionSheetDesign.Row.horizontalPadding)
            .frame(maxWidth: .infinity)
            .frame(height: QuickActionSheetDesign.Row.height)
            .background {
                RoundedRectangle(cornerRadius: QuickActionSheetDesign.Row.cardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                cardBackground.opacity(0.98),
                                WeekFitTheme.whiteOpacity(0.024)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: QuickActionSheetDesign.Row.cardCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(hasConflict ? 0.03 : 0.09),
                                .white.opacity(0.04),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: accentColor.opacity(hasConflict ? 0.0 : 0.03),
                radius: 8,
                y: 3
            )
            .scaleEffect(pressed ? 0.985 : 1.0)
            .opacity(hasConflict ? 0.52 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(hasConflict)
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
                        .fill(accentColor.opacity(0.10))

                    Image(systemName: systemIcon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(accentColor.opacity(0.76))
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
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                }
            }
        }
    }

    private var startControl: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(hasConflict ? 0.07 : 0.18))
                .frame(width: actionButtonSize, height: actionButtonSize)

            Circle()
                .stroke(accentColor.opacity(hasConflict ? 0.07 : 0.15), lineWidth: 1)

            Image(systemName: hasConflict ? "lock.fill" : "play.fill")
                .font(.system(size: hasConflict ? 10.5 : 11, weight: .semibold))
                .foregroundStyle(hasConflict ? .white.opacity(0.26) : .white.opacity(0.92))
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
