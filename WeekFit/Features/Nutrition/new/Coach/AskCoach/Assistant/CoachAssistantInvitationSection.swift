import SwiftUI

/// Compact Premium Assistant entry on the Coach tab.
struct CoachAssistantInvitationSection: View {
    let activeConversation: CoachAssistantConversation?
    let onOpen: () -> Void

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        invitationCard
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("coach.assistant.entry")
    }

    private var invitationCard: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 14) {
                assistantIcon

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(WeekFitLocalizedString("coach.assistant.title"))
                            .font(.system(
                                size: dynamicTypeSize.isAccessibilitySize ? 20 : 18,
                                weight: .semibold,
                                design: .rounded
                            ))
                            .foregroundStyle(palette.textPrimary.opacity(0.96))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        premiumBadge

                        Spacer(minLength: 0)
                    }

                    Text(WeekFitLocalizedString("coach.assistant.subtitle"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textSecondary.opacity(0.88))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(ctaTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.coachAccent)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .weekFitPrimaryCard(
            accent: WeekFitTheme.coachAccent,
            featured: true
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(WeekFitLocalizedString("coach.assistant.a11y.hint"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(
            hasActiveConversation ? "coach.assistant.continue" : "coach.assistant.talk"
        )
    }

    private var premiumBadge: some View {
        Text(WeekFitLocalizedString("coach.assistant.badge"))
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(WeekFitTheme.coachAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .fill(WeekFitTheme.coachAccent.opacity(palette.isLight ? 0.12 : 0.22))
            }
            .accessibilityHidden(true)
    }

    private var assistantIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WeekFitSurface.iconWellRadius, style: .continuous)
                .fill(WeekFitTheme.coachAccent.opacity(palette.isLight ? 0.14 : 0.24))
                .frame(width: 40, height: 40)
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(WeekFitTheme.coachAccent)
        }
        .accessibilityHidden(true)
    }

    private var hasActiveConversation: Bool {
        activeConversation != nil
    }

    private var ctaTitle: String {
        hasActiveConversation
            ? WeekFitLocalizedString("coach.assistant.continue")
            : WeekFitLocalizedString("coach.assistant.talk")
    }

    private var accessibilityLabel: String {
        let title = WeekFitLocalizedString("coach.assistant.title")
        let badge = WeekFitLocalizedString("coach.assistant.badge")
        let subtitle = WeekFitLocalizedString("coach.assistant.subtitle")
        return "\(title). \(badge). \(subtitle). \(ctaTitle)"
    }
}
