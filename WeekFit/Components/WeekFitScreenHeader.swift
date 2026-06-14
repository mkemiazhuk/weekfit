import SwiftUI

struct WeekFitScreenHeader: View {

    let title: String
    let subtitle: String
    let initials: String
    let showAvatar: Bool
    let onAvatarTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-0.75)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            if showAvatar {
                WeekFitAvatarButton(
                    initials: initials,
                    action: onAvatarTap
                )
            }
        }
        .frame(height: 44)
    }
}

struct WeekFitAvatarButton: View {

    let initials: String
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 214/255, green: 170/255, blue: 74/255).opacity(0.22),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 22
                        )
                    )
                    .blur(radius: 6)
                    .frame(width: 42, height: 42)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 30/255, green: 24/255, blue: 18/255),
                                Color(red: 10/255, green: 10/255, blue: 10/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 255/255, green: 221/255, blue: 132/255).opacity(0.95),
                                        Color(red: 142/255, green: 104/255, blue: 36/255).opacity(0.72)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.1
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                            .padding(4)
                    }

                Text(initials)
                    .font(.system(size: 14.5, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 255/255, green: 235/255, blue: 170/255),
                                Color(red: 211/255, green: 163/255, blue: 62/255)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.30), radius: 8, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(WeekFitLocalizedString("common.openProfile")))
    }
}

enum WeekFitScreenLayout {
    static let horizontalPadding: CGFloat = 16
    static let topPaddingLarge: CGFloat = 14
    static let topPaddingSmall: CGFloat = 5
    static let rootSpacing: CGFloat = 12

    static var topPadding: CGFloat {
        UIScreen.main.bounds.height > 800 ? topPaddingLarge : topPaddingSmall
    }
}

extension View {
    func debugFrame(_ name: String) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let frame = geo.frame(in: .global)
//                        print("📐 \(name): x=\(frame.minX), maxX=\(frame.maxX), width=\(frame.width), y=\(frame.minY)")
                    }
                    .onChange(of: geo.size) { _, _ in
                        let frame = geo.frame(in: .global)
//                        print("📐 \(name): x=\(frame.minX), maxX=\(frame.maxX), width=\(frame.width), y=\(frame.minY)")
                    }
            }
        )
    }
}
