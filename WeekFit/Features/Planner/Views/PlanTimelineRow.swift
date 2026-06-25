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
    static let cardCornerRadius: CGFloat = 16
    static let compactHydrationVerticalPadding: CGFloat = 7
    static let cardHorizontalPadding: CGFloat = 11
    static let cardVerticalPadding: CGFloat = 10
    static let cardIconSpacing: CGFloat = 9
    static let cardAccentBarWidth: CGFloat = 3.5
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

    var body: some View {
        HStack(alignment: .center, spacing: PlanTimelineLayout.timeToTimelineSpacing) {
            Color.clear
                .frame(width: timeColumnWidth)

            Circle()
                .fill(WeekFitTheme.whiteOpacity(0.22))
                .frame(width: 4, height: 4)

            Text(WeekFitLocalizedString("planner.timeline.now"))
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.45)
                .textCase(.uppercase)
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.30))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Rectangle()
                .fill(WeekFitTheme.whiteOpacity(0.07))
                .frame(height: 0.5)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(WeekFitLocalizedString("planner.timeline.now"))
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

    private var accent: Color { activity.color }

    private var isLive: Bool {
        status == .live
    }

    private var isPending: Bool {
        status == .pending
    }

    private var rowOpacity: Double {
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
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.24))
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
            return accent.opacity(0.95)
        }

        switch emphasis {
        case .next:
            return accent.opacity(0.88)
        case .active:
            return isPending
                ? Color(red: 1.0, green: 0.706, blue: 0.341).opacity(0.88)
                : accent.opacity(0.90)
        case .upcoming:
            return .white.opacity(0.72)
        case .past:
            return .white.opacity(0.60)
        case .skipped:
            return .white.opacity(0.40)
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
                accent: accent,
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
            .fill(accent.opacity(opacity))
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
        switch emphasis {
        case .past:
            return 0.32
        case .skipped:
            return 0.20
        case .upcoming:
            return 0.40
        case .active:
            return 0.48
        case .next:
            return 0.54
        }
    }

    private var activityCard: some View {
        HStack(alignment: .center, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent.opacity(accentBarOpacity))
                .frame(width: PlanTimelineLayout.cardAccentBarWidth)
                .padding(.vertical, 4)

            HStack(alignment: .center, spacing: PlanTimelineLayout.cardIconSpacing) {
                iconView

                VStack(alignment: .leading, spacing: PlanTimelineLayout.titleSubtitleSpacing + 1) {
                    Text(displayTitle)
                        .font(.system(size: titleFontSize, weight: titleFontWeight, design: .rounded))
                        .foregroundStyle(titleColor)
                        .tracking(-0.22)
                        .strikethrough(status == .skipped, color: titleColor.opacity(0.72))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    if !metadata.isEmpty {
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
        .background {
            RoundedRectangle(cornerRadius: PlanTimelineLayout.cardCornerRadius, style: .continuous)
                .fill(cardFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PlanTimelineLayout.cardCornerRadius, style: .continuous)
                .stroke(cardStroke, lineWidth: cardStrokeWidth)
        }
        .shadow(
            color: cardShadowColor,
            radius: cardShadowRadius,
            y: cardShadowY
        )
        .shadow(
            color: nextGlowColor,
            radius: emphasis == .next ? 10 : 0,
            y: emphasis == .next ? 2 : 0
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(WeekFitLocalizedString("planner.timeline.accessibility.opensDetails"))
        .accessibilityAddTraits(.isButton)
    }

    private var accentBarOpacity: Double {
        if isLive { return 0.88 }

        switch emphasis {
        case .next:
            return 0.82
        case .active:
            return 0.74
        case .upcoming:
            return 0.62
        case .past:
            return 0.48
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
        switch emphasis {
        case .next:
            return .white.opacity(0.42)
        case .active, .upcoming:
            return .white.opacity(0.34)
        case .past:
            return .white.opacity(0.28)
        case .skipped:
            return .white.opacity(0.18)
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

            if metadata.showsWatchIcon {
                watchSourceBadge
            }
        }
        .font(.system(size: subtitleFontSize, weight: .regular))
        .foregroundStyle(metadataColor)
        .lineLimit(1)
    }

    private var watchSourceBadge: some View {
        Image(systemName: "applewatch")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(metadataColor.opacity(0.58))
            .accessibilityLabel(WeekFitLocalizedString("planner.timeline.source.appleWatch"))
    }

    private var accessibilityLabelText: String {
        var parts: [String] = [time, displayTitle]
        if status == .skipped {
            parts.append(WeekFitLocalizedString("planner.status.skipped"))
        }
        if let primary = metadata.primary, !primary.isEmpty {
            parts.append(primary)
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
        case .next:
            return .white.opacity(0.96)
        case .active:
            return .white.opacity(0.92)
        case .upcoming:
            return .white.opacity(0.84)
        case .past:
            return .white.opacity(0.74)
        case .skipped:
            return .white.opacity(0.38)
        }
    }

    private var metadataColor: Color {
        switch emphasis {
        case .next:
            return .white.opacity(0.74)
        case .active, .upcoming:
            return .white.opacity(0.72)
        case .past:
            return .white.opacity(0.68)
        case .skipped:
            return .white.opacity(0.42)
        }
    }

    private var cardFill: Color {
        if isLive {
            return accent.opacity(0.10)
        }

        switch emphasis {
        case .next:
            return accent.opacity(0.08)
        case .active:
            return accent.opacity(0.065)
        case .upcoming:
            return accent.opacity(0.048)
        case .past:
            return Color(red: 0.036, green: 0.040, blue: 0.046)
        case .skipped:
            return Color(red: 0.030, green: 0.033, blue: 0.038)
        }
    }

    private var cardStroke: Color {
        if isLive {
            return accent.opacity(0.26)
        }

        switch emphasis {
        case .next:
            return accent.opacity(0.24)
        case .active:
            return isPending
                ? Color(red: 1.0, green: 0.706, blue: 0.341).opacity(0.22)
                : accent.opacity(0.18)
        case .upcoming:
            return accent.opacity(0.12)
        case .past:
            return WeekFitTheme.whiteOpacity(0.034)
        case .skipped:
            return Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.16)
        }
    }

    private var cardStrokeWidth: CGFloat {
        switch emphasis {
        case .next:
            return 0.75
        case .active:
            return isLive ? 0.85 : 0.65
        default:
            return 0.55
        }
    }

    private var cardShadowColor: Color {
        switch emphasis {
        case .next:
            return Color.black.opacity(0.20)
        case .active, .upcoming:
            return Color.black.opacity(0.16)
        case .past:
            return Color.black.opacity(0.12)
        case .skipped:
            return Color.black.opacity(0.08)
        }
    }

    private var cardShadowRadius: CGFloat {
        switch emphasis {
        case .next:
            return 8
        case .active, .upcoming:
            return 6
        case .past:
            return 5
        case .skipped:
            return 3
        }
    }

    private var cardShadowY: CGFloat {
        switch emphasis {
        case .past, .skipped:
            return 2
        default:
            return 3
        }
    }

    private var nextGlowColor: Color {
        emphasis == .next ? accent.opacity(0.10) : .clear
    }

    @ViewBuilder
    private var iconView: some View {
        WeekFitIconBadge(
            systemName: resolvedIcon,
            color: accent,
            size: .sm,
            shape: .roundedRect,
            backgroundOpacity: iconBackgroundOpacity,
            foregroundOpacity: iconForegroundOpacity
        )
    }

    private var iconBackgroundOpacity: Double {
        if isLive { return 0.20 }

        switch emphasis {
        case .next:
            return 0.20
        case .active:
            return 0.17
        case .upcoming:
            return 0.14
        case .past:
            return 0.11
        case .skipped:
            return 0.06
        }
    }

    private var iconForegroundOpacity: Double {
        if isLive { return 0.95 }

        switch emphasis {
        case .next:
            return 0.92
        case .active, .upcoming:
            return 0.84
        case .past:
            return 0.70
        case .skipped:
            return 0.42
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
            } else if isFilled {
                Circle()
                    .fill(accent.opacity(filledOpacity))
                    .frame(width: nodeDiameter, height: nodeDiameter)
                    .scaleEffect(status == .live && livePulse ? 1.06 : 1.0)
                    .shadow(
                        color: accent.opacity(filledShadowOpacity),
                        radius: status == .live ? 4 : 1.5
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
                            .fill(Color.black.opacity(emptyFillOpacity))
                    )
            }
        }
        .frame(width: PlanTimelineLayout.columnWidth, height: nodeDiameter + PlanTimelineLayout.nodeVerticalPadding * 2 + 1)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: status)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: emphasis)
        .onAppear {
            guard status == .live else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                livePulse = true
            }
        }
        .onChange(of: status) { _, newValue in
            if newValue == .live {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    livePulse = true
                }
            } else {
                livePulse = false
            }
        }
        .accessibilityHidden(true)
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
