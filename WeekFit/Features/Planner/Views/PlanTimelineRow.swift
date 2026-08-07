import SwiftUI
import WeekFitPlanner

enum PlanTimelineLayout {
    static let timeWidth: CGFloat = 54
    static let columnWidth: CGFloat = 18
    static let timeToTimelineSpacing: CGFloat = 4
    static let timelineToCardSpacing: CGFloat = 5
    static let nodeSize: CGFloat = 9
    static let nodeVerticalPadding: CGFloat = 3
    static let lineWidth: CGFloat = 1.0
    static let rowSpacing: CGFloat = 10
    static let cardCornerRadius: CGFloat = WeekFitSurface.compactRadius
    static let compactHydrationVerticalPadding: CGFloat = 7
    static let cardHorizontalPadding: CGFloat = WeekFitSurface.compactHorizontalPadding
    static let cardVerticalPadding: CGFloat = 10
    static let cardIconSpacing: CGFloat = 9
    static let cardAccentBarWidth: CGFloat = WeekFitSurface.accentIndicatorWidth
    static let rowTopInset: CGFloat = 8
    static let firstConnectorInset: CGFloat = 8
    static let lastConnectorInset: CGFloat = 4
    static let titleFontSize: CGFloat = 15.2
    static let subtitleFontSize: CGFloat = 12.5
    static let timeFontSize: CGFloat = 15
    static let titleSubtitleSpacing: CGFloat = 1
}

struct PlanTimelineNowDivider: View {

    @ScaledMetric(relativeTo: .caption) private var timeColumnWidth = PlanTimelineLayout.timeWidth
    @State private var pulse = false

    private let liveTint = Color(red: 1.0, green: 0.706, blue: 0.341)

    var body: some View {
        HStack(alignment: .center, spacing: PlanTimelineLayout.timeToTimelineSpacing) {
            Color.clear
                .frame(width: timeColumnWidth)

            ZStack {
                Circle()
                    .fill(liveTint.opacity(pulse ? 0.22 : 0.10))
                    .frame(width: pulse ? 12 : 9, height: pulse ? 12 : 9)

                Circle()
                    .fill(liveTint.opacity(pulse ? 0.98 : 0.78))
                    .frame(width: 5, height: 5)
            }
            .frame(width: PlanTimelineLayout.columnWidth)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            liveTint.opacity(pulse ? 0.40 : 0.18),
                            WeekFitTheme.whiteOpacity(0.04)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WeekFitLocalizedString("planner.timeline.now"))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct PlanTimelineRow: View {

    let activity: PlannedActivity
    let displayTitle: String
    let metadata: PlanTimelineRowMetadata
    let customMeals: [Meals]
    let time: String
    let category: PlanTimelineCategory
    let status: PlanActivityStatus
    let emphasis: PlanTimelineVisualEmphasis
    let nextEmphasis: PlanTimelineVisualEmphasis?
    let isFirst: Bool
    let isLast: Bool
    let connectorAbove: CGFloat
    var density: PlanTimelineRowDensity = .standard
    var showsTimeLabel: Bool = true

    @ScaledMetric(relativeTo: .caption) private var timeColumnWidth = PlanTimelineLayout.timeWidth
    @ScaledMetric(relativeTo: .body) private var titleFontSize = PlanTimelineLayout.titleFontSize
    @ScaledMetric(relativeTo: .subheadline) private var subtitleFontSize = PlanTimelineLayout.subtitleFontSize
    @ScaledMetric(relativeTo: .callout) private var timeFontSize = PlanTimelineLayout.timeFontSize
    @State private var livePulse = false
    @Environment(\.weekFitPalette) private var palette

    private var accent: Color { activity.color }

    private var pendingAttentionColor: Color {
        Color(red: 0.95, green: 0.60, blue: 0.15)
    }

    private var rowAccent: Color {
        isPending ? pendingAttentionColor : accent
    }

    private var isLive: Bool {
        status == .live
    }

    private var isPending: Bool {
        status == .pending
    }

    private var coachProvenanceKind: CoachChangeKind? {
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: activity.date)
        return CoachProvenanceLookupCache.adjustment(
            forActivityId: activity.id,
            dayKey: dayKey
        )?.kind
    }

    private var rowOpacity: Double {
        if palette.isLight {
            switch emphasis {
            case .past:
                return 1.0
            case .skipped:
                return 0.72
            case .upcoming, .active, .next:
                return 1.0
            }
        }
        switch emphasis {
        case .past:
            return 0.88
        case .skipped:
            return 0.58
        case .upcoming, .active, .next:
            return 1.0
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            timeLabel

            Color.clear
                .frame(width: PlanTimelineLayout.timeToTimelineSpacing)

            timelineColumn

            Color.clear
                .frame(width: PlanTimelineLayout.timelineToCardSpacing)

            activityCard
        }
        .opacity(rowOpacity)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: emphasis)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: status)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: activity.isCompleted)
    }

    private var timeLabel: some View {
        Group {
            if showsTimeLabel {
                Text(time)
                    .font(.system(size: timeFontSize, weight: timeFontWeight).monospacedDigit())
                    .foregroundStyle(timeColor)
            } else {
                Text("·")
                    .font(.system(size: timeFontSize * 0.72, weight: .medium))
                    .foregroundStyle(WeekFitTheme.quaternaryText)
            }
        }
        .frame(width: timeColumnWidth, alignment: .trailing)
        .padding(.top, PlanTimelineLayout.rowTopInset)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        .accessibilityHidden(true)
    }

    private var timeFontWeight: Font.Weight {
        switch emphasis {
        case .next, .active:
            return .semibold
        default:
            return .medium
        }
    }

    private var timeColor: Color {
        if isLive {
            return accent
        }

        switch emphasis {
        case .next, .active:
            return WeekFitTheme.primaryText
        case .upcoming:
            return WeekFitTheme.secondaryText
        case .past:
            return WeekFitTheme.secondaryText
        case .skipped:
            return WeekFitTheme.disabledText
        }
    }

    private var timelineColumn: some View {
        VStack(spacing: 0) {
            if isFirst && connectorAbove == 0 {
                Color.clear.frame(height: PlanTimelineLayout.firstConnectorInset)
            } else {
                timelineLine(opacity: lineOpacityAbove)
                    .frame(height: max(10, connectorAbove + 8))
            }

            PlanTimelineNode(
                accent: rowAccent,
                status: status,
                emphasis: emphasis,
                livePulse: $livePulse
            )
            .padding(.vertical, PlanTimelineLayout.nodeVerticalPadding)

            if isLast {
                Color.clear.frame(height: PlanTimelineLayout.lastConnectorInset)
            } else {
                timelineLine(opacity: lineOpacityBelow)
                    .frame(minHeight: 12)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: PlanTimelineLayout.columnWidth)
    }

    private func timelineLine(opacity: Double) -> some View {
        Rectangle()
            .fill(rowAccent.opacity(opacity))
            .frame(width: PlanTimelineLayout.lineWidth)
            .frame(maxWidth: .infinity)
    }

    private var lineOpacityAbove: Double {
        lineOpacity(for: emphasis)
    }

    private var lineOpacityBelow: Double {
        guard let nextEmphasis else {
            return lineOpacity(for: emphasis) * 0.80
        }
        return (lineOpacity(for: emphasis) + lineOpacity(for: nextEmphasis)) / 2
    }

    private func lineOpacity(for emphasis: PlanTimelineVisualEmphasis) -> Double {
        let lightBoost = palette.isLight ? 1.35 : 1.0
        switch emphasis {
        case .past:
            return 0.36 * lightBoost
        case .skipped:
            return 0.28 * lightBoost
        case .upcoming:
            return 0.48 * lightBoost
        case .active:
            return 0.55 * lightBoost
        case .next:
            return 0.60 * lightBoost
        }
    }

    private var activityCard: some View {
        HStack(alignment: .center, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(rowAccent.opacity(accentBarOpacity))
                .frame(width: PlanTimelineLayout.cardAccentBarWidth)
                .padding(.vertical, 4)

            HStack(alignment: .center, spacing: PlanTimelineLayout.cardIconSpacing) {
                iconView

                VStack(alignment: .leading, spacing: PlanTimelineLayout.titleSubtitleSpacing + 1) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(displayTitle)
                            .font(.system(size: titleFontSize, weight: titleFontWeight, design: .rounded))
                            .foregroundStyle(titleColor)
                            .tracking(-0.22)
                            .strikethrough(status == .skipped, color: titleColor.opacity(0.72))
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)
                            .truncationMode(.tail)
                            .layoutPriority(1)

                        if isLive {
                            liveStatusBadge
                        }

                        if let coachKind = coachProvenanceKind {
                            CoachProvenanceBadge(kind: coachKind, showsLabel: false, compact: true)
                        }
                    }

                    if isPending {
                        pendingStatusLine
                    } else if !metadata.isEmpty {
                        metadataLine
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(chevronColor)
                    .frame(width: 6, alignment: .trailing)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 10)
            .padding(.trailing, PlanTimelineLayout.cardHorizontalPadding)
            .padding(.vertical, cardVerticalPadding)
        }
        .weekFitCompactRowCard(
            accent: timelinePremiumAccent
        )
        .overlay {
            if isLive {
                RoundedRectangle(cornerRadius: PlanTimelineLayout.cardCornerRadius, style: .continuous)
                    .stroke(accent.opacity(livePulse ? 0.38 : 0.22), lineWidth: 1)
            }
        }
        .shadow(
            color: nextGlowColor,
            radius: emphasis == .next ? 10 : 0,
            y: emphasis == .next ? 2 : 0
        )
        .shadow(
            color: liveGlowColor,
            radius: isLive && livePulse ? 16 : (isLive ? 10 : 0),
            y: isLive ? 3 : 0
        )
        .shadow(
            color: pendingGlowColor,
            radius: isPending ? 10 : 0,
            y: isPending ? 2 : 0
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(WeekFitLocalizedString("planner.timeline.accessibility.opensDetails"))
        .accessibilityAddTraits(.isButton)
    }

    private var timelinePremiumAccent: Color? {
        if isPending { return pendingAttentionColor }
        if isLive || emphasis == .next || emphasis == .active || emphasis == .upcoming {
            return accent
        }
        return nil
    }

    private var accentBarOpacity: Double {
        if isPending { return 0.90 }
        if isLive { return 0.80 }

        switch emphasis {
        case .next:
            return 0.72
        case .active:
            return 0.62
        case .upcoming:
            return 0.52
        case .past:
            return 0.40
        case .skipped:
            return 0.28
        }
    }

    private var titleFontWeight: Font.Weight {
        switch emphasis {
        case .skipped:
            return .regular
        default:
            return .semibold
        }
    }

    private var chevronColor: Color {
        if isPending {
            return pendingAttentionColor.opacity(0.70)
        }

        switch emphasis {
        case .next, .active, .upcoming:
            return WeekFitTheme.iconSecondary
        case .past:
            return WeekFitTheme.iconInactive
        case .skipped:
            return WeekFitTheme.disabledText
        }
    }

    private var cardVerticalPadding: CGFloat {
        density == .compactHydration
            ? PlanTimelineLayout.compactHydrationVerticalPadding
            : PlanTimelineLayout.cardVerticalPadding
    }

    private var metadataLine: some View {
        HStack(alignment: .center, spacing: 4) {
            if let primary = metadata.primary, !primary.isEmpty {
                Text(primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }

            if let sourceLabel = metadata.sourceLabel, !sourceLabel.isEmpty {
                if metadata.primary != nil {
                    Text("·")
                        .foregroundStyle(metadataColor.opacity(0.55))
                }
                Text(sourceLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(WeekFitTheme.coachAccent.opacity(0.82))
            }

            if metadata.showsWatchIcon {
                watchSourceBadge
            }
        }
        .font(.system(size: subtitleFontSize, weight: .regular))
        .foregroundStyle(metadataColor)
        .lineLimit(1)
    }

    private var liveStatusBadge: some View {
        Circle()
            .fill(accent.opacity(livePulse ? 1.0 : 0.55))
            .frame(width: 7, height: 7)
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(accent.opacity(livePulse ? 0.18 : 0.11))
            }
            .overlay {
                Capsule()
                    .stroke(accent.opacity(livePulse ? 0.34 : 0.18), lineWidth: 0.75)
            }
            .accessibilityLabel(WeekFitLocalizedString("planner.status.live"))
    }

    private var watchSourceBadge: some View {
        Image(systemName: "applewatch")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(metadataColor.opacity(0.58))
            .accessibilityLabel(WeekFitLocalizedString("planner.timeline.source.appleWatch"))
    }

    private var accessibilityLabelText: String {
        var parts: [String] = [time, displayTitle]
        if isLive {
            parts.append(WeekFitLocalizedString("planner.status.live"))
        }
        if status == .skipped {
            parts.append(WeekFitLocalizedString("planner.status.skipped"))
        }
        if let primary = metadata.primary, !primary.isEmpty {
            parts.append(primary)
        }
        if let sourceLabel = metadata.sourceLabel, !sourceLabel.isEmpty {
            parts.append(sourceLabel)
        }
        if metadata.showsWatchIcon {
            parts.append(
                String(
                    format: WeekFitLocalizedString("planner.timeline.accessibility.appleWatchSyncedFormat"),
                    WeekFitLocalizedString("planner.timeline.source.appleWatch")
                )
            )
        }
        if let foodSource = PlanTimelineMetadataBuilder.accessibilityFoodSource(
            for: activity,
            customMeals: customMeals
        ) {
            parts.append(foodSource)
        }
        return parts.joined(separator: ", ")
    }

    private var titleColor: Color {
        switch emphasis {
        case .next, .active, .upcoming, .past:
            return WeekFitTheme.primaryText
        case .skipped:
            return WeekFitTheme.disabledText
        }
    }

    private var metadataColor: Color {
        switch emphasis {
        case .next, .active, .upcoming, .past:
            return WeekFitTheme.secondaryText
        case .skipped:
            return WeekFitTheme.tertiaryText
        }
    }


    private var nextGlowColor: Color {
        emphasis == .next ? accent.opacity(0.10) : .clear
    }

    private var liveGlowColor: Color {
        isLive ? accent.opacity(livePulse ? 0.24 : 0.14) : .clear
    }

    private var pendingGlowColor: Color {
        isPending ? pendingAttentionColor.opacity(0.12) : .clear
    }

    private var pendingStatusLine: some View {
        HStack(spacing: 4) {
            Text(WeekFitLocalizedString("today.pending.title"))
                .lineLimit(1)

            if let primary = metadata.primary, !primary.isEmpty {
                Text("·")
                Text(primary)
                    .lineLimit(1)
            }
        }
        .font(.system(size: subtitleFontSize, weight: .semibold))
        .foregroundStyle(pendingAttentionColor.opacity(0.92))
    }

    @ViewBuilder
    private var iconView: some View {
        if isPending {
            ZStack {
                Circle()
                    .fill(pendingAttentionColor.opacity(0.10))
                    .frame(width: 34, height: 34)

                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(pendingAttentionColor)
            }
        } else {
            WeekFitIconBadge(
                systemName: resolvedIcon,
                color: accent,
                size: .sm,
                shape: .roundedRect,
                backgroundOpacity: iconBackgroundOpacity,
                foregroundOpacity: iconForegroundOpacity
            )
        }
    }

    private var iconBackgroundOpacity: Double {
        if isLive { return palette.isLight ? 0.22 : 0.20 }

        switch emphasis {
        case .next:
            return palette.isLight ? 0.22 : 0.20
        case .active:
            return palette.isLight ? 0.18 : 0.17
        case .upcoming:
            return palette.isLight ? 0.16 : 0.14
        case .past:
            return palette.isLight ? 0.14 : 0.11
        case .skipped:
            return palette.isLight ? 0.10 : 0.06
        }
    }

    private var iconForegroundOpacity: Double {
        if isLive { return 1.0 }

        switch emphasis {
        case .next:
            return 1.0
        case .active, .upcoming:
            return palette.isLight ? 0.96 : 0.84
        case .past:
            return palette.isLight ? 0.88 : 0.70
        case .skipped:
            return palette.isLight ? 0.55 : 0.42
        }
    }

    private var resolvedIcon: String {
        PlanTimelineIconResolver.icon(for: activity)
    }
}

// MARK: - Timeline Node

private struct PlanTimelineNode: View {

    let accent: Color
    let status: PlanActivityStatus
    let emphasis: PlanTimelineVisualEmphasis
    @Binding var livePulse: Bool

    private var isFilled: Bool {
        status == .completed || status == .logged || status == .live || status == .skipped
    }

    private var isSkipped: Bool {
        status == .skipped
    }

    var body: some View {
        ZStack {
            if isSkipped {
                Circle()
                    .fill(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(skippedNodeFillOpacity))
                    .frame(width: nodeDiameter, height: nodeDiameter)

                Image(systemName: "xmark")
                    .font(.system(size: 5.5, weight: .bold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
            } else if status == .pending {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: nodeDiameter, height: nodeDiameter)
                    .shadow(color: accent.opacity(0.24), radius: 3)

                Image(systemName: "exclamationmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(accent.opacity(0.96))
            } else if isFilled {
                if status == .live {
                    Circle()
                        .stroke(accent.opacity(livePulse ? 0.52 : 0.20), lineWidth: 1.25)
                        .frame(
                            width: nodeDiameter + (livePulse ? 9 : 5),
                            height: nodeDiameter + (livePulse ? 9 : 5)
                        )

                    Circle()
                        .fill(accent.opacity(livePulse ? 0.14 : 0.06))
                        .frame(
                            width: nodeDiameter + (livePulse ? 14 : 8),
                            height: nodeDiameter + (livePulse ? 14 : 8)
                        )
                        .blur(radius: 1.5)
                }

                Circle()
                    .fill(accent.opacity(filledOpacity))
                    .frame(width: nodeDiameter, height: nodeDiameter)
                    .scaleEffect(status == .live && livePulse ? 1.14 : 1.0)
                    .shadow(
                        color: accent.opacity(filledShadowOpacity),
                        radius: status == .live ? (livePulse ? 8 : 5) : 1.5
                    )

                if status == .completed || status == .logged {
                    Image(systemName: "checkmark")
                        .font(.system(size: 5, weight: .bold))
                        .foregroundStyle(Color.black.opacity(checkmarkOpacity))
                }
            } else {
                Circle()
                    .strokeBorder(
                        accent.opacity(emptyStrokeOpacity),
                        lineWidth: emptyStrokeWidth
                    )
                    .frame(width: nodeDiameter, height: nodeDiameter)
                    .background(
                        Circle()
                            .fill(WeekFitTheme.cardSurface.opacity(0.92))
                    )
            }
        }
        .frame(width: PlanTimelineLayout.columnWidth, height: nodeDiameter + PlanTimelineLayout.nodeVerticalPadding * 2 + 1)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: status)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: emphasis)
        .onAppear {
            startLivePulseIfNeeded()
        }
        .onChange(of: status) { _, newValue in
            if newValue == .live {
                startLivePulseIfNeeded()
            } else {
                livePulse = false
            }
        }
        .accessibilityHidden(true)
    }

    private func startLivePulseIfNeeded() {
        guard status == .live else { return }
        livePulse = false
        withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
            livePulse = true
        }
    }

    private var filledOpacity: Double {
        if status == .live { return 0.95 }

        switch emphasis {
        case .past:
            return 0.82
        default:
            return 0.88
        }
    }

    private var skippedNodeFillOpacity: Double {
        switch emphasis {
        case .skipped:
            return 0.72
        case .past:
            return 0.58
        default:
            return 0.66
        }
    }

    private var filledShadowOpacity: Double {
        if status == .live { return 0.28 }

        switch emphasis {
        case .past:
            return 0.12
        case .skipped:
            return 0.06
        default:
            return 0.12
        }
    }

    private var checkmarkOpacity: Double {
        switch emphasis {
        case .past:
            return 0.76
        case .skipped:
            return 0.58
        default:
            return 0.72
        }
    }

    private var emptyStrokeOpacity: Double {
        switch emphasis {
        case .next:
            return 0.72
        case .active, .upcoming:
            return 0.56
        case .past, .skipped:
            return 0.24
        }
    }

    private var emptyStrokeWidth: CGFloat {
        emphasis == .next ? 1.55 : 1.35
    }

    private var emptyFillOpacity: Double {
        emphasis == .next ? 0.22 : 0.16
    }

    private var nodeDiameter: CGFloat {
        if status == .live { return 10 }
        if emphasis == .next && !isFilled { return 10 }
        return PlanTimelineLayout.nodeSize
    }
}

// MARK: - Icon Resolver

enum PlanTimelineIconResolver {

    static func icon(for activity: PlannedActivity) -> String {
        WeekFitActivityIconResolver.resolve(for: activity)
    }
}

// MARK: - Previews

#if DEBUG
private enum PlanTimelinePreviewFactory {

    static func row(
        title: String,
        time: String,
        status: PlanActivityStatus,
        emphasis: PlanTimelineVisualEmphasis,
        completed: Bool = false,
        category: PlanTimelineCategory = .activity,
        metadata: PlanTimelineRowMetadata? = nil
    ) -> some View {
        PlanTimelineRow(
            activity: PlannedActivity(
                date: Date(),
                type: "habit",
                title: title,
                durationMinutes: 30,
                icon: "bed.double.fill",
                colorRed: 0.66,
                colorGreen: 0.58,
                colorBlue: 0.86,
                isCompleted: completed
            ),
            displayTitle: title,
            metadata: metadata ?? PlanTimelineRowMetadata(
                primary: emphasis == .past ? "39 min" : nil,
                sourceLabel: nil,
                showsWatchIcon: false
            ),
            customMeals: [],
            time: time,
            category: category,
            status: status,
            emphasis: emphasis,
            nextEmphasis: emphasis == .past ? .next : nil,
            isFirst: false,
            isLast: false,
            connectorAbove: 0
        )
    }
}

#Preview("Plan Timeline Emphasis") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 0) {
            PlanTimelinePreviewFactory.row(
                title: "Water",
                time: "14:09",
                status: .logged,
                emphasis: .past,
                completed: true,
                category: .nutrition
            )
            PlanTimelinePreviewFactory.row(
                title: "Холодник с картошкой",
                time: "14:41",
                status: .logged,
                emphasis: .past,
                completed: true,
                category: .nutrition
            )
            PlanTimelinePreviewFactory.row(
                title: "Walk",
                time: "17:31",
                status: .logged,
                emphasis: .past,
                completed: true,
                metadata: PlanTimelineRowMetadata(
                    primary: "19 min",
                    sourceLabel: nil,
                    showsWatchIcon: true
                )
            )
            PlanTimelineNowDivider()
            PlanTimelinePreviewFactory.row(
                title: "Sleep Routine",
                time: "22:30",
                status: .upcoming,
                emphasis: .next
            )
        }
        .padding(.horizontal, 12)
    }
    .preferredColorScheme(.dark)
}
#endif
