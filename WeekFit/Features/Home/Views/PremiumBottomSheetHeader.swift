import SwiftUI

struct PremiumBottomSheetHeader: View {

    let title: String
    let subtitle: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.14))
                .frame(width: 42, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 8)

            ZStack(alignment: .top) {
                VStack(spacing: 3) {
                    Text(title)
                        .font(QuickActionSheetDesign.Typography.headerTitle)
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.96))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)

                    Text(subtitle)
                        .font(QuickActionSheetDesign.Typography.headerSubtitle)
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.42))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 44)

                HStack {
                    Spacer()

                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(WeekFitTheme.primaryText.opacity(0.92))
                            .frame(width: 36, height: 36)
                            .background {
                                Circle()
                                    .fill(WeekFitTheme.whiteOpacity(0.075))
                            }
                            .overlay {
                                Circle()
                                    .stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(AppText.Common.Action.close))
                    .fixedSize()
                }
            }
            .padding(.horizontal, QuickActionSheetDesign.Layout.horizontalPadding)
            .padding(.bottom, QuickActionSheetDesign.Layout.segmentedTopPadding)
        }
    }
}
