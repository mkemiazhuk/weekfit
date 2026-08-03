import SwiftUI

/// Shared left-aligned header used by Drinks / Food / Activity quick sheets.
struct QuickSheetPremiumHeader: View {
    let title: String
    let subtitle: String
    let onClose: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(
                    palette.isLight
                        ? WeekFitLightTokens.shadowContact.opacity(0.16)
                        : Color.white.opacity(0.14)
                )
                .frame(width: 36, height: 3.5)
                .padding(.top, 8)
                .padding(.bottom, 14)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .tracking(-0.4)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.72))
                }

                Spacer(minLength: 8)

                WeekFitCloseButton(size: .regular, playsHaptic: false, action: onClose)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 10)
        }
    }
}

struct QuickSheetSectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
    }
}
