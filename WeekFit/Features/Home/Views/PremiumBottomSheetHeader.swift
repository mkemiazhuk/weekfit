import SwiftUI

struct PremiumBottomSheetHeader: View {

    let title: String
    let subtitle: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            Capsule()
                .fill(.white.opacity(0.16))
                .frame(width: 46, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 10)

            ZStack {

                VStack(spacing: 4) {

                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.96))

                    Text(subtitle)
                        .font(.system(size: 11.8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.38))
                        .lineLimit(1)
                }

                HStack {
                    Spacer()

                    Button {
                        onClose()
                    } label: {

                        Image(systemName: "xmark")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.055))
                            )
                            .overlay {
                                Circle()
                                    .stroke(.white.opacity(0.055), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 48)
            .padding(.horizontal, 18)
            .padding(.bottom, 10)
        }
    }
}
