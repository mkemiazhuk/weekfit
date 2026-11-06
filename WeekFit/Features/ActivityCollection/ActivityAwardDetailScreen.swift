import SwiftUI

struct ActivityAwardDetailScreen: View {
    let badge: ActivityBadgeDisplay
    let onClose: () -> Void
    let onStart: () -> Void
    var scrolls = true

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        ZStack {
            palette.appScreenBackground.ignoresSafeArea()
            Group {
                if scrolls {
                    ScrollView(showsIndicators: false) { detailStack }
                } else {
                    detailStack
                }
            }
        }
    }

    private var detailStack: some View {
                VStack(spacing: 18) {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(palette.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(palette.textPrimary.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(AppText.Common.Action.close))
                    }
                    ActivityBadgeRibbon(
                        symbol: badge.symbol,
                        category: badge.category,
                        artworkID: badge.id,
                        locked: !badge.isUnlocked,
                        size: 220
                    )
                    VStack(spacing: 8) {
                        Text(badge.name)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.55)
                        Text(badge.activityName)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                        if badge.isUnlocked {
                            Text(ActivityAwardCopy.result(badge))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                                .multilineTextAlignment(.center)
                            if let date = ActivityAwardCopy.dateLine(badge) {
                                Text(date)
                                    .font(.subheadline)
                                    .foregroundStyle(palette.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            if let extra = ActivityAwardCopy.supporting(badge) {
                                Text(extra)
                                    .font(.subheadline)
                                    .foregroundStyle(palette.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            Text(badge.condition)
                                .font(.body)
                                .foregroundStyle(palette.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(ActivityAwardCopy.result(badge))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                            if let fraction = ActivityAwardCopy.progressFraction(badge) {
                                AwardProgressBar(fraction: fraction, tint: ActivityBadgePalette.tint(badge.category))
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(ActivityAwardCopy.accessibilityLabel(for: badge))
                    if !badge.isUnlocked, badge.canStart {
                        Button(action: onStart) {
                            Text(badge.actionTitle)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(ActivityBadgePalette.tint(badge.category), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 28)
    }
}

private struct AwardProgressBar: View {
    var fraction: Double
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.18))
                    Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}
