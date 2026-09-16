import SwiftUI

/// Recovery Challenge entry card — recovery accent language matching Coach “Recovering”.
struct RecoveryChallengeHeaderEntryChip: View {
    let entry: RecoveryChallengePresenter.HeaderEntry
    let onTap: () -> Void

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { WeekFitTheme.recovery }
    private var textPrimary: Color { WeekFitTheme.primaryText }
    private var textSecondary: Color { WeekFitTheme.secondaryText }

    var body: some View {
        switch entry {
        case .hidden:
            EmptyView()
        case .invite, .participating, .summary:
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 52, weight: .regular))
                        .foregroundStyle(accent.opacity(palette.isLight ? 0.10 : 0.16))
                        // Keep the full moon + stars inside the card (was clipping on the trailing edge).
                        .padding(.trailing, 18)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    cardContent
                        .padding(.horizontal, 16)
                        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 16 : 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
                .contentShape(Rectangle())
            }
            .buttonStyle(RecoveryChallengeHeaderPressStyle(reduceMotion: reduceMotion))
            .weekFitPremiumCard(
                emphasis: summaryQuieter ? .standard : .elevated,
                accent: accent,
                cornerRadius: WeekFitSurface.primaryRadius
            )
            .opacity(summaryQuieter ? 0.94 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityHint(Text(WeekFitLocalizedString("challenge.recovery7.header.a11yHint")))
            .accessibilityIdentifier("recovery.challenge.headerEntry")
        }
    }

    private var summaryQuieter: Bool {
        if case .summary = entry { return true }
        return false
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 10) {
            titleRow

            if !statusLine.isEmpty {
                statusBadge
            }

            if !actionLine.isEmpty {
                Text(actionLine)
                    .font(.system(size: actionSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            progressRow
                .padding(.top, 2)
        }
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(WeekFitLocalizedString("challenge.recovery7.intro.eyebrow"))
                    .font(.caption2.weight(.bold))
                    .fontDesign(.rounded)
                    .tracking(1.2)
                    .foregroundStyle(accent.opacity(palette.isLight ? 0.88 : 0.82))

                Text(WeekFitLocalizedString("challenge.recovery7.title"))
                    .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: chevronSize, weight: .semibold))
                .foregroundStyle(accent.opacity(0.55))
                .accessibilityHidden(true)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            if showsCompletedCheck {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: statusSize, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.95))
                    .accessibilityHidden(true)
            }

            Text(statusLine)
                .font(.system(size: statusSize, weight: .bold, design: .rounded))
                .tracking(statusIsDayLabel ? 0.8 : 0)
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(WeekFitTheme.recoverySoftSurface)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(accent.opacity(palette.isLight ? 0.22 : 0.30), lineWidth: 1)
                }
        }
    }

    private var progressRow: some View {
        HStack(alignment: .center, spacing: 12) {
            RecoveryChallengeHeaderProgressStrip(
                nodes: progressNodes,
                accent: accent
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingMeta
        }
    }

    @ViewBuilder
    private var trailingMeta: some View {
        switch entry {
        case .participating(let active) where !active.todayCompleted:
            HStack(spacing: 3) {
                Text(WeekFitLocalizedString("challenge.recovery7.header.doToday"))
                    .font(.system(size: metaSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent.opacity(0.95))
                Image(systemName: "chevron.right")
                    .font(.system(size: metaSize - 2, weight: .bold))
                    .foregroundStyle(accent.opacity(0.72))
            }
            .fixedSize()
            .accessibilityHidden(true)

        case .participating(let active):
            Text(
                String(
                    format: WeekFitLocalizedString("challenge.recovery7.header.ofCount"),
                    active.completedCount,
                    RecoveryChallengeConfig.dayCount
                )
            )
            .font(.system(size: metaSize, weight: .semibold, design: .rounded))
            .foregroundStyle(accent.opacity(0.88))
            .fixedSize()
            .accessibilityHidden(true)

        case .summary(let summary):
            Text(
                String(
                    format: WeekFitLocalizedString("challenge.recovery7.header.ofCount"),
                    summary.completedCount,
                    RecoveryChallengeConfig.dayCount
                )
            )
            .font(.system(size: metaSize, weight: .semibold, design: .rounded))
            .foregroundStyle(accent.opacity(0.78))
            .fixedSize()
            .accessibilityHidden(true)

        case .invite:
            HStack(spacing: 3) {
                Text(WeekFitLocalizedString("challenge.recovery7.header.viewCTA"))
                    .font(.system(size: metaSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent.opacity(0.95))
                Image(systemName: "chevron.right")
                    .font(.system(size: metaSize - 2, weight: .bold))
                    .foregroundStyle(accent.opacity(0.72))
            }
            .fixedSize()
            .accessibilityHidden(true)

        case .hidden:
            EmptyView()
        }
    }

    private var progressNodes: [RecoveryChallengeJourneyDayState] {
        switch entry {
        case .invite:
            return Array(repeating: .future, count: RecoveryChallengeConfig.dayCount)
        case .participating(let active):
            return active.nodeStates
        case .summary(let summary):
            return summary.nodeStates
        case .hidden:
            return []
        }
    }

    private var showsCompletedCheck: Bool {
        if case .participating(let active) = entry, active.todayCompleted { return true }
        if case .summary = entry { return true }
        return false
    }

    private var statusIsDayLabel: Bool {
        if case .participating(let active) = entry, !active.todayCompleted { return true }
        return false
    }

    private var statusColor: Color {
        accent.opacity(0.95)
    }

    private var statusLine: String {
        switch entry {
        case .hidden:
            return ""
        case .invite:
            return WeekFitLocalizedString("challenge.recovery7.header.status.invite")
        case .participating(let active):
            if active.todayCompleted {
                return String(
                    format: WeekFitLocalizedString("challenge.recovery7.header.dayComplete"),
                    active.dayIndex
                )
            }
            return String(
                format: WeekFitLocalizedString("challenge.recovery7.header.dayLabel"),
                active.dayIndex
            )
        case .summary(let summary):
            if summary.isPerfect {
                return WeekFitLocalizedString("challenge.recovery7.header.challengeComplete")
            }
            return WeekFitLocalizedString("challenge.recovery7.header.challengeFinished")
        }
    }

    private var actionLine: String {
        switch entry {
        case .participating(let active):
            return WeekFitLocalizedString(active.taskTitleKey)
        case .invite, .summary, .hidden:
            return ""
        }
    }

    private var titleSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 18 : 17
    }

    private var statusSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 13 : 11
    }

    private var actionSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 15
    }

    private var metaSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 13 : 12
    }

    private var chevronSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 11
    }

    private var accessibilityLabel: String {
        let name = WeekFitLocalizedString("challenge.recovery7.title")
        let parts = [name, statusLine, actionLine].filter { !$0.isEmpty }
        switch entry {
        case .participating(let active) where !active.todayCompleted:
            return parts.joined(separator: ". ")
                + ". "
                + WeekFitLocalizedString("challenge.recovery7.header.doToday")
        case .participating(let active):
            return parts.joined(separator: ". ")
                + ". "
                + String(
                    format: WeekFitLocalizedString("challenge.recovery7.header.ofCount"),
                    active.completedCount,
                    RecoveryChallengeConfig.dayCount
                )
        case .summary(let summary):
            return parts.joined(separator: ". ")
                + ". "
                + String(
                    format: WeekFitLocalizedString("challenge.recovery7.header.ofCount"),
                    summary.completedCount,
                    RecoveryChallengeConfig.dayCount
                )
        default:
            return parts.joined(separator: ". ")
        }
    }
}

// MARK: - Progress strip

private struct RecoveryChallengeHeaderProgressStrip: View {
    let nodes: [RecoveryChallengeJourneyDayState]
    let accent: Color

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weekFitPalette) private var palette

    private var nodeSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 9
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { index, state in
                if index > 0 {
                    connector(before: state, afterCompleted: nodes[index - 1] == .completed)
                }
                node(state)
            }
        }
        .accessibilityHidden(true)
    }

    private func connector(before state: RecoveryChallengeJourneyDayState, afterCompleted: Bool) -> some View {
        Rectangle()
            .fill(
                (afterCompleted || state == .completed)
                    ? accent.opacity(palette.isLight ? 0.40 : 0.45)
                    : WeekFitTheme.tertiaryText.opacity(0.22)
            )
            .frame(height: 1.5)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 3)
    }

    @ViewBuilder
    private func node(_ state: RecoveryChallengeJourneyDayState) -> some View {
        let size = nodeSize
        switch state {
        case .completed:
            Circle()
                .fill(accent)
                .frame(width: size, height: size)
                .shadow(color: accent.opacity(palette.isLight ? 0.22 : 0.40), radius: 3, y: 1)
        case .current, .awaitingMorningConfirm:
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: size + 4, height: size + 4)
                Circle()
                    .strokeBorder(accent, lineWidth: 1.75)
                    .frame(width: size + 2, height: size + 2)
                Circle()
                    .fill(accent.opacity(0.55))
                    .frame(width: size - 2, height: size - 2)
            }
            .frame(width: size + 4, height: size + 4)
        case .missed:
            Circle()
                .strokeBorder(WeekFitTheme.tertiaryText.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2]))
                .frame(width: size, height: size)
        case .future:
            Circle()
                .strokeBorder(WeekFitTheme.tertiaryText.opacity(0.38), lineWidth: 1.2)
                .frame(width: size, height: size)
        }
    }
}

private struct RecoveryChallengeHeaderPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}
