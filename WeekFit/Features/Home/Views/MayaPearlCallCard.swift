import SwiftUI

/// What the Maya card knows about call time before the tap.
enum MayaCallBalance: Equatable {
    /// Seconds the next call may use, including time still held by a call that is closing.
    case seconds(Int)
    case needsPremium

    init(_ usage: WeekFitAIUsage) {
        self = usage.active ? .seconds(usage.voice.total + usage.voice.reserved) : .needsPremium
    }

    func note(locale: Locale = WeekFitCurrentLocale()) -> String {
        switch self {
        case .seconds(let seconds) where seconds >= 60:
            let format = WeekFitLocalizedString("ai.usage.mayaMinutesLeft", locale: locale)
            return String(format: format, locale: locale, seconds / 60)
        case .seconds(let seconds) where seconds > 0:
            return WeekFitLocalizedString("ai.usage.mayaUnderMinute", locale: locale)
        case .seconds:
            return WeekFitLocalizedString("ai.usage.mayaNoMinutes", locale: locale)
        case .needsPremium:
            return WeekFitLocalizedString("ai.usage.mayaWithPremium", locale: locale)
        }
    }

    /// The last minute and an empty balance are worth noticing before the call, not during it.
    var isLow: Bool {
        if case .seconds(let seconds) = self { return seconds < 120 }
        return false
    }
}

/// Quiet call entry on Today. One button: the phone chip is visual, not a second control.
struct MayaPearlCallCard: View {
    var isReturning: Bool
    var isOpening = false
    var balance: MayaCallBalance? = nil
    var action: () -> Void

    @Environment(\.weekFitPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var messageSize: CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var noteSize: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 44

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                emblem
                VStack(alignment: .leading, spacing: 2) {
                    Text(WeekFitLocalizedString("planner.voice.maya"))
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(nameColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    Text(WeekFitLocalizedString("today.maya.subtitle"))
                        .font(.system(size: messageSize, weight: .regular))
                        .foregroundStyle(subtitleColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    if let balance {
                        Text(balance.note())
                            .font(.system(size: noteSize, weight: .semibold))
                            .foregroundStyle(balance.isLow ? WeekFitTheme.brandGold : subtitleColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 2)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: balance)
                .frame(maxWidth: .infinity, alignment: .leading)

                callChip
            }
            .padding(TodayChrome.cardPadding)
            .frame(maxWidth: .infinity, alignment: .center)
            .todaySurface()
        }
        .buttonStyle(TodayCardPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WeekFitLocalizedString("today.maya.accessibility"))
        .accessibilityValue(balance?.note() ?? "")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("today.maya.call")
    }

    private var emblem: some View {
        Image("maya-portrait")
            .resizable()
            .scaledToFill()
            .frame(width: iconSide, height: iconSide)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(Color.white.opacity(palette.isLight ? 0.9 : 0.28), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var callChip: some View {
        HStack(spacing: 6) {
            if isOpening {
                ProgressView()
                    .controlSize(.small)
                    .tint(chipInk)
            } else {
                Image(systemName: "phone")
                    .font(.system(size: 15, weight: .semibold))
            }
            Text(WeekFitLocalizedString(isReturning ? "today.maya.return" : "planner.voice.call"))
                .font(.system(size: messageSize, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(chipInk)
        .padding(.horizontal, 14)
        .frame(minWidth: 44, minHeight: 36)
        .background {
            Capsule(style: .continuous)
                .fill(palette.isLight ? Color.white.opacity(0.94) : Color.white.opacity(0.10))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.black.opacity(palette.isLight ? 0.06 : 0.18), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var nameColor: Color {
        palette.isLight ? WeekFitLightTokens.textPrimary : Color.white
    }

    private var subtitleColor: Color {
        palette.isLight ? WeekFitLightTokens.textSecondary : TodayChrome.secondaryText(isLight: false)
    }

    private var chipInk: Color {
        palette.isLight ? WeekFitLightTokens.pearlInk : Color.white
    }

}

