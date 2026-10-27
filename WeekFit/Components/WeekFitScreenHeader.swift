import SwiftUI

struct WeekFitScreenHeader<Trailing: View>: View {

    let title: String
    let subtitle: String
    let initials: String
    var hasProfileName: Bool = false
    let showAvatar: Bool
    /// Slightly quieter avatar when another surface (e.g. Coach card) should lead.
    var avatarProminence: WeekFitAvatarButton.Prominence = .standard
    @ViewBuilder let trailing: () -> Trailing
    let onAvatarTap: () -> Void

    private var showsSubtitle: Bool {
        !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .weekFitScreenTitle()

                // Always reserve the subtitle row so the avatar keeps the same
                // Y (and trailing X) on Plan / title-only screens as on Today /
                // Coach / Meals.
                Text(showsSubtitle ? subtitle : " ")
                    .weekFitScreenSubtitle()
                    .opacity(showsSubtitle ? 1 : 0)
                    .accessibilityHidden(!showsSubtitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            HStack(spacing: 10) {
                trailing()

                if showAvatar {
                    WeekFitAvatarButton(
                        initials: initials,
                        hasProfileName: hasProfileName,
                        prominence: avatarProminence,
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
        avatarProminence: WeekFitAvatarButton.Prominence = .standard,
        onAvatarTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.initials = initials
        self.hasProfileName = hasProfileName
        self.showAvatar = showAvatar
        self.avatarProminence = avatarProminence
        self.trailing = { EmptyView() }
        self.onAvatarTap = onAvatarTap
    }
}

struct WeekFitAvatarButton: View {

    enum Prominence: Equatable {
        case standard
        /// Keeps gold identity, but softens glow/border so content can lead.
        case subdued
        /// Simple circular initials — no gold ring (Today redesign).
        case plain
    }

    let initials: String
    var hasProfileName: Bool = false
    var prominence: Prominence = .standard
    let action: () -> Void

    @Environment(\.weekFitPalette) private var palette

    private let goldLight = Color(red: 255/255, green: 235/255, blue: 170/255)
    private let goldMid = Color(red: 211/255, green: 163/255, blue: 62/255)
    private let goldStrokeLight = Color(red: 255/255, green: 221/255, blue: 132/255)
    private let goldStrokeDeep = Color(red: 142/255, green: 104/255, blue: 36/255)

    private var isSubdued: Bool { prominence == .subdued }
    private var isPlain: Bool { prominence == .plain }
    private var avatarSize: CGFloat {
        if isPlain { return 36 }
        return isSubdued ? 40 : 44
    }
    private var cornerRadius: CGFloat { isSubdued ? 12 : 14 }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Group {
                if isPlain {
                    plainAvatar
                } else {
                    standardAvatar
                }
            }
            .animation(.easeInOut(duration: 0.28), value: hasProfileName)
            .animation(.easeInOut(duration: 0.28), value: initials)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(WeekFitLocalizedString("common.openProfile")))
    }

    private var plainAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    palette.isLight
                        ? WeekFitLightTokens.avatarFill
                        : Color(red: 0.14, green: 0.16, blue: 0.22)
                )
            Circle()
                .strokeBorder(
                    palette.isLight
                        ? WeekFitLightTokens.avatarStroke.opacity(WeekFitLightTokens.avatarStrokeOpacity)
                        : Color.white.opacity(0.10),
                    lineWidth: 1
                )
            avatarContent
        }
        .frame(width: avatarSize, height: avatarSize)
    }

    private var standardAvatar: some View {
        ZStack {
            ZStack {
                if !palette.isLight {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 214/255, green: 170/255, blue: 74/255)
                                        .opacity(isSubdued ? 0.10 : 0.22),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: isSubdued ? 18 : 22
                            )
                        )
                        .blur(radius: isSubdued ? 3 : 6)
                        .frame(width: isSubdued ? 36 : 42, height: isSubdued ? 36 : 42)
                }

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(avatarFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(avatarStrokeStyle, lineWidth: avatarStrokeWidth)
                    }
                    .overlay {
                        if !palette.isLight {
                            RoundedRectangle(cornerRadius: max(cornerRadius - 2, 10), style: .continuous)
                                .stroke(WeekFitTheme.whiteOpacity(isSubdued ? 0.03 : 0.05), lineWidth: 0.8)
                                .padding(isSubdued ? 3 : 4)
                        }
                    }

                avatarContent
            }
            .frame(width: avatarSize, height: avatarSize)
            .shadow(
                color: palette.isLight
                    ? Color.black.opacity(isSubdued ? 0.025 : 0.03)
                    : Color.black.opacity(isSubdued ? 0.16 : 0.30),
                radius: palette.isLight ? (isSubdued ? 1 : 1.5) : (isSubdued ? 4 : 8),
                y: palette.isLight ? 1 : (isSubdued ? 3 : 5)
            )
            .shadow(
                color: palette.isLight
                    ? Color.black.opacity(isSubdued ? 0.03 : 0.045)
                    : Color.clear,
                radius: palette.isLight ? (isSubdued ? 4 : 6) : 0,
                y: palette.isLight ? (isSubdued ? 1.5 : 2) : 0
            )
        }
    }

    private var avatarFill: LinearGradient {
        if palette.isLight {
            // Warm ceramic fill under the gold ring.
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

    private var avatarStrokeWidth: CGFloat {
        if palette.isLight {
            return isSubdued ? 1.15 : 1.35
        }
        return isSubdued ? 0.85 : 1.1
    }

    private var avatarStrokeStyle: AnyShapeStyle {
        // Gold ring in both themes (light uses deeper brand gold for contrast on milk).
        AnyShapeStyle(
            LinearGradient(
                colors: [
                    goldStrokeLight.opacity(
                        palette.isLight
                            ? (isSubdued ? 0.88 : 0.98)
                            : (isSubdued ? 0.62 : 0.95)
                    ),
                    goldStrokeDeep.opacity(
                        palette.isLight
                            ? (isSubdued ? 0.62 : 0.78)
                            : (isSubdued ? 0.42 : 0.72)
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var avatarGlyphStyle: some ShapeStyle {
        if isPlain {
            if palette.isLight {
                return AnyShapeStyle(WeekFitLightTokens.avatarGlyph.opacity(0.88))
            }
            return AnyShapeStyle(Color.white.opacity(0.92))
        }
        if palette.isLight {
            // Deep brand gold glyph on ceramic — restored premium Light chrome.
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        WeekFitLightTokens.brandGold,
                        WeekFitLightTokens.brandGoldDark
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [goldLight, goldMid],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var avatarContent: some View {
        if hasProfileName {
            Text(initials)
                .font(.system(
                    size: isPlain
                        ? 13
                        : (palette.isLight
                            ? (isSubdued ? 13.5 : 15)
                            : (isSubdued ? 13 : 14.5)),
                    weight: isPlain ? .semibold : .black,
                    design: .rounded
                ))
                .tracking(palette.isLight ? 0.4 : 0)
                .foregroundStyle(avatarGlyphStyle)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: isSubdued ? 20 : 23, weight: .semibold))
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
