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
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(WeekFitTheme.whiteOpacity(0.70))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.05))
                            )
                            .overlay {
                                Circle()
                                    .stroke(.white.opacity(0.05), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                }
            }
            .padding(.horizontal, QuickActionSheetDesign.Layout.horizontalPadding)
            .padding(.bottom, QuickActionSheetDesign.Layout.segmentedTopPadding)
        }
    }
}
