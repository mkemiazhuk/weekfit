import SwiftUI

struct WeekFitScreenHeader<Trailing: View>: View {

    let title: String
    let subtitle: String
    let initials: String
    var hasProfileName: Bool = false
    let showAvatar: Bool
    @ViewBuilder let trailing: () -> Trailing
    let onAvatarTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .weekFitScreenTitle()

                Text(subtitle)
                    .weekFitScreenSubtitle()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            HStack(spacing: 10) {
                trailing()

                if showAvatar {
                    WeekFitAvatarButton(
                        initials: initials,
                        hasProfileName: hasProfileName,
                        action: onAvatarTap
                    )
                    .accessibilityIdentifier("settings.open")
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minHeight: 52)
    }
}

extension WeekFitScreenHeader where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String,
        initials: String,
        hasProfileName: Bool = false,
        showAvatar: Bool,
        onAvatarTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.initials = initials
        self.hasProfileName = hasProfileName
        self.showAvatar = showAvatar
        self.trailing = { EmptyView() }
        self.onAvatarTap = onAvatarTap
    }
}

struct WeekFitAvatarButton: View {

    let initials: String
    var hasProfileName: Bool = false
    let action: () -> Void

    @Environment(\.weekFitPalette) private var palette

    private let goldLight = Color(red: 255/255, green: 235/255, blue: 170/255)
    private let goldMid = Color(red: 211/255, green: 163/255, blue: 62/255)
    private let goldStrokeLight = Color(red: 255/255, green: 221/255, blue: 132/255)
    private let goldStrokeDeep = Color(red: 142/255, green: 104/255, blue: 36/255)

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                ZStack {
                    if !palette.isLight {
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
                    }

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(avatarFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            goldStrokeLight.opacity(palette.isLight ? 0.98 : 0.95),
                                            goldStrokeDeep.opacity(palette.isLight ? 0.78 : 0.72)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: palette.isLight ? 1.35 : 1.1
                                )
                        }
                        .overlay {
                            if !palette.isLight {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(WeekFitTheme.whiteOpacity(0.05), lineWidth: 0.8)
                                    .padding(4)
                            }
                        }

                    avatarContent
                }
                .frame(width: 44, height: 44)
                .shadow(
                    color: palette.isLight
                        ? Color.black.opacity(0.04)
                        : Color.black.opacity(0.30),
                    radius: palette.isLight ? 2 : 8,
                    y: palette.isLight ? 1 : 5
                )
                .shadow(
                    color: palette.isLight
                        ? Color.black.opacity(0.08)
                        : Color.clear,
                    radius: palette.isLight ? 10 : 0,
                    y: palette.isLight ? 4 : 0
                )
            }
            .animation(.easeInOut(duration: 0.28), value: hasProfileName)
            .animation(.easeInOut(duration: 0.28), value: initials)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(WeekFitLocalizedString("common.openProfile")))
    }

    private var avatarFill: LinearGradient {
        if palette.isLight {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.998, blue: 0.992),
                    Color(red: 0.985, green: 0.978, blue: 0.965)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 30/255, green: 24/255, blue: 18/255),
                Color(red: 10/255, green: 10/255, blue: 10/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var avatarGlyphStyle: some ShapeStyle {
        if palette.isLight {
            // Deep brand gold on ceramic — pale champagne reads soft/unfocused in Light.
            return LinearGradient(
                colors: [
                    WeekFitLightTokens.brandGold,
                    WeekFitLightTokens.brandGoldDark
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [goldLight, goldMid],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var avatarContent: some View {
        if hasProfileName {
            Text(initials)
                .font(.system(size: palette.isLight ? 15 : 14.5, weight: .black, design: .rounded))
                .tracking(palette.isLight ? 0.4 : 0)
                .foregroundStyle(avatarGlyphStyle)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(avatarGlyphStyle)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }
}

extension View {
    func debugFrame(_ name: String) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let frame = geo.frame(in: .global)
                    }
                    .onChange(of: geo.size) { _, _ in
                        let frame = geo.frame(in: .global)
                    }
            }
        )
    }
}
