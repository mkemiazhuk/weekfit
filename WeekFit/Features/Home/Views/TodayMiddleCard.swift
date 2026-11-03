import SwiftUI

/// Shared geometry for the single card under Maya: Up next or Today’s focus.
struct TodayMiddleCard: View {
    enum Tone {
        case sage
        case lavender
    }

    let header: String
    let title: String
    let message: String
    let systemImage: String
    let tone: Tone
    var trailingTime: String? = nil
    var showsChevron: Bool = false

    @Environment(\.weekFitPalette) private var palette
    @ScaledMetric(relativeTo: .footnote) private var headerSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var messageSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 44

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(header)
                    .font(.system(size: headerSize, weight: .medium))
                    .foregroundStyle(accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: messageSize, weight: .regular))
                        .foregroundStyle(messageColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if trailingTime != nil || showsChevron {
                HStack(spacing: 6) {
                    if let trailingTime {
                        Text(trailingTime)
                            .font(.system(size: messageSize, weight: .medium))
                            .foregroundStyle(titleColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(accent.opacity(0.85))
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(TodayChrome.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .todaySurface(tint: accent)
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(palette.isLight ? 0.16 : 0.22))
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: iconSide, height: iconSide)
        .accessibilityHidden(true)
    }

    private var accent: Color {
        switch tone {
        case .sage:
            return palette.isLight
                ? WeekFitSemanticMetricTokens.activityInk
                : WeekFitSemanticMetricTokens.activity
        case .lavender:
            return palette.isLight
                ? WeekFitSemanticMetricTokens.recoveryInk
                : WeekFitSemanticMetricTokens.recovery
        }
    }

    private var titleColor: Color {
        palette.isLight ? WeekFitLightTokens.textPrimary : Color.white
    }

    private var messageColor: Color {
        palette.isLight ? WeekFitLightTokens.textSecondary : TodayChrome.secondaryText(isLight: false)
    }
}
