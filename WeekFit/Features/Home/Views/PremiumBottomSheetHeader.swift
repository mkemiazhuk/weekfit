import SwiftUI

struct PremiumBottomSheetHeader: View {

    let title: String
    let subtitle: String
    let onClose: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(palette.isLight
                      ? WeekFitLightTokens.shadowContact.opacity(0.18)
                      : Color.white.opacity(0.14))
                .frame(width: 42, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 8)

            ZStack(alignment: .top) {
                VStack(spacing: 3) {
                    Text(title)
                        .font(QuickActionSheetDesign.Typography.headerTitle)
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)

                    Text(subtitle)
                        .font(QuickActionSheetDesign.Typography.headerSubtitle)
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 44)

                HStack {
                    Spacer()

                    WeekFitCloseButton(size: .regular, playsHaptic: false, action: onClose)
                        .fixedSize()
                }
            }
            .padding(.horizontal, QuickActionSheetDesign.Layout.horizontalPadding)
            .padding(.bottom, QuickActionSheetDesign.Layout.segmentedTopPadding)
        }
    }
}
