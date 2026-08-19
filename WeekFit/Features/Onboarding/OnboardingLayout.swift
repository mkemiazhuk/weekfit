import SwiftUI

/// Shared onboarding layout, type, and chrome. Screens compose these primitives
/// instead of inventing per-step offsets, fonts, or CTA treatments.
enum OnboardingLayout {
    static let horizontalPadding: CGFloat = 28
    static let navHeight: CGFloat = 44
    static let navTopPadding: CGFloat = 8
    static let navBottomPadding: CGFloat = 8
    static let navControlSize: CGFloat = 44
    static let progressTrackHeight: CGFloat = 3.5
    static let progressMinFill: CGFloat = 16

    static let pageTopPadding: CGFloat = 6
    static let pageBottomPadding: CGFloat = 8
    static let titleToSubtitle: CGFloat = 8
    static let subtitleToContent: CGFloat = 22
    static let contentToHelper: CGFloat = 12
    static let helperLineSpacing: CGFloat = 4
    static let minBreathingRoom: CGFloat = 12

    static let cardCornerRadius: CGFloat = 20
    static let cardRowHorizontal: CGFloat = 16
    static let cardRowVertical: CGFloat = 14
    static let cardRowSpacing: CGFloat = 14
    static let dividerHeight: CGFloat = 0.5
    static let dividerLeading: CGFloat = 16

    static let ctaMinHeight: CGFloat = 52
    static let ctaTopPadding: CGFloat = 10
    static let ctaBottomPadding: CGFloat = 20
    static let ctaSecondarySpacing: CGFloat = 8

    enum Title {
        static let size: CGFloat = 28
        static let tracking: CGFloat = -0.35
    }

    enum Subtitle {
        static let size: CGFloat = 15
        static let lineSpacing: CGFloat = 3
    }

    enum CardTitle {
        static let size: CGFloat = 16
    }

    enum CardSecondary {
        static let size: CGFloat = 13
    }

    enum Helper {
        static let size: CGFloat = 13
    }

    enum CTA {
        static let size: CGFloat = 16
    }

    enum SmallLabel {
        static let size: CGFloat = 11
    }

    enum Eyebrow {
        static let size: CGFloat = 10
        static let tracking: CGFloat = 1.3
    }
}

// MARK: - Type

struct OnboardingTitle: View {
    let text: String
    @Environment(\.weekFitPalette) private var palette
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = OnboardingLayout.Title.size

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(palette.textPrimary)
            .tracking(OnboardingLayout.Title.tracking)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct OnboardingSubtitle: View {
    let text: String
    @Environment(\.weekFitPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = OnboardingLayout.Subtitle.size

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(palette.textSecondary)
            .lineSpacing(OnboardingLayout.Subtitle.lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingHelper: View {
    let text: String
    @ScaledMetric(relativeTo: .footnote) private var size: CGFloat = OnboardingLayout.Helper.size

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(WeekFitTheme.tertiaryText)
            .lineSpacing(OnboardingLayout.helperLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Page

struct OnboardingPage<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    var helper: String? = nil
    let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        helper: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.helper = helper
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if let title {
                    OnboardingTitle(text: title)
                }
                if let subtitle {
                    OnboardingSubtitle(text: subtitle)
                        .padding(.top, title == nil ? 0 : OnboardingLayout.titleToSubtitle)
                }
                content
                    .padding(
                        .top,
                        (title != nil || subtitle != nil) ? OnboardingLayout.subtitleToContent : 0
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let helper {
                    OnboardingHelper(text: helper)
                        .padding(.top, OnboardingLayout.contentToHelper)
                }

                Spacer(minLength: OnboardingLayout.minBreathingRoom)
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
            .padding(.top, OnboardingLayout.pageTopPadding)
            .padding(.bottom, OnboardingLayout.pageBottomPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Navigation

struct OnboardingNavBar: View {
    var progress: CGFloat?
    var progressAccessibilityLabel: String = ""
    var showsBack: Bool
    var showsSkip: Bool
    var onBack: () -> Void
    var onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            leading
            center
            trailing
        }
        .frame(height: OnboardingLayout.navHeight)
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.top, OnboardingLayout.navTopPadding)
        .padding(.bottom, OnboardingLayout.navBottomPadding)
    }

    @ViewBuilder
    private var leading: some View {
        if showsBack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .frame(
                        width: OnboardingLayout.navControlSize,
                        height: OnboardingLayout.navControlSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WeekFitLocalizedString("onboarding.v12.nav.back"))
        } else {
            Color.clear.frame(
                width: OnboardingLayout.navControlSize,
                height: OnboardingLayout.navControlSize
            )
        }
    }

    @ViewBuilder
    private var center: some View {
        if let progress {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WeekFitTheme.borderSoft.opacity(0.7))
                        .frame(height: OnboardingLayout.progressTrackHeight)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [WeekFitTheme.brandGold, WeekFitTheme.brandGoldDeep],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(
                                OnboardingLayout.progressMinFill,
                                geo.size.width * min(max(progress, 0), 1)
                            ),
                            height: OnboardingLayout.progressTrackHeight
                        )
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: progress)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(progressAccessibilityLabel)
        } else {
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if showsSkip {
            Button(action: onSkip) {
                Text(WeekFitLocalizedString("onboarding.v12.nav.skip"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .padding(.horizontal, 10)
                    .frame(
                        minWidth: OnboardingLayout.navControlSize,
                        minHeight: OnboardingLayout.navControlSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WeekFitLocalizedString("onboarding.v12.nav.skip"))
        } else {
            Color.clear.frame(
                width: OnboardingLayout.navControlSize,
                height: OnboardingLayout.navControlSize
            )
        }
    }
}

// MARK: - CTA

struct OnboardingPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var pressed = false
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = OnboardingLayout.CTA.size

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(Color.black.opacity(0.7))
                }
                Text(title)
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(Color.black.opacity(0.82))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .frame(minHeight: OnboardingLayout.ctaMinHeight)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [WeekFitTheme.brandGold, WeekFitTheme.brandGoldDeep.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(pressed ? 0.985 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .accessibilityAddTraits(.isButton)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

struct OnboardingTextButton: View {
    let title: String
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 15

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.tertiaryText)
                .frame(maxWidth: .infinity)
                .frame(minHeight: OnboardingLayout.navControlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Choice card

struct OnboardingChoiceRow: View {
    let title: String
    let subtitle: String
    var badge: String? = nil
    var accessibilityText: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = OnboardingLayout.CardTitle.size
    @ScaledMetric(relativeTo: .footnote) private var subtitleSize: CGFloat = OnboardingLayout.CardSecondary.size
    @ScaledMetric(relativeTo: .caption) private var badgeSize: CGFloat = OnboardingLayout.SmallLabel.size

    private var accent: Color { WeekFitTheme.settingsAccent }

    var body: some View {
        Button(action: action) {
            HStack(spacing: OnboardingLayout.cardRowSpacing) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(title)
                            .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(WeekFitTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)
                            .allowsTightening(true)

                        if let badge {
                            Text(badge)
                                .font(.system(size: badgeSize, weight: .bold, design: .rounded))
                                .foregroundStyle(accent)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background {
                                    Capsule().fill(WeekFitTheme.settingsIconWell)
                                }
                                .layoutPriority(1)
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: subtitleSize, weight: .medium))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : WeekFitTheme.secondaryText.opacity(0.35))
                    .accessibilityHidden(true)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isSelected)
            }
            .padding(.horizontal, OnboardingLayout.cardRowHorizontal)
            .padding(.vertical, OnboardingLayout.cardRowVertical)
            .frame(minHeight: OnboardingLayout.navControlSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityText ?? "\(title). \(subtitle)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct OnboardingChoiceDivider: View {
    var body: some View {
        Rectangle()
            .fill(WeekFitTheme.borderSoft.opacity(0.55))
            .frame(height: OnboardingLayout.dividerHeight)
            .padding(.leading, OnboardingLayout.dividerLeading)
            .padding(.trailing, OnboardingLayout.cardRowHorizontal)
    }
}
