import SwiftUI
import WeekFitPlanner

struct ActivityAwardDetailScreen: View {
    let badge: ActivityBadgeDisplay
    let onClose: () -> Void
    let onStart: () -> Void
    var scrolls = true
    var healthManager: HealthManager? = nil
    var plannedActivities: [PlannedActivity] = []

    @Environment(\.weekFitPalette) private var palette
    @State private var openedSession: ActivitySessionSnapshot?

    var body: some View {
        ZStack {
            palette.appScreenBackground.ignoresSafeArea()
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    detailStack
                        .frame(minHeight: geometry.size.height)
                }
            }
        }
        .fullScreenCover(item: $openedSession) { session in
            if let healthManager {
                ActivitySessionDetailView(session: session, healthManager: healthManager)
            }
        }
    }

    private var awardExplanation: some View {
        VStack(spacing: 8) {
            if badge.award.kind == .personalRecord, badge.award.unit == .kilometers, badge.isUnlocked {
                Text(ActivityAwardCopy.result(badge))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                if let date = ActivityAwardCopy.dateLine(badge) {
                    Text(ActivityAwardCopy.earnedOnLine(date))
                        .font(.body)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                Text(ActivityAwardCopy.story(badge))
                    .font(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.center)
    }

    private func openActivity(_ source: ActivityAwardSource) {
        guard let healthManager,
              let activity = plannedActivities.first(where: { $0.id == source.recordID }) else { return }
        Task {
            openedSession = await PlannedActivitySessionResolver().resolve(activity, healthManager: healthManager)
        }
    }

    private var detailStack: some View {
        VStack(spacing: 0) {
            HStack {
                ProfilePremiumDismissButton(style: .back, action: onClose)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 8)
            ActivityBadgeRibbon(
                symbol: badge.symbol,
                category: badge.category,
                artworkID: badge.id,
                locked: false,
                size: 248
            )
            .padding(.top, 28)
            .padding(.bottom, 32)
            Text(badge.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            awardExplanation
                .padding(.top, 12)
                .padding(.horizontal, 8)
            if !badge.isUnlocked, badge.canStart {
                Button(action: onStart) {
                    Text(badge.actionTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(ActivityBadgePalette.tint(badge.category), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 28)
            }
            Spacer(minLength: 24)
            if badge.isUnlocked, let source = badge.source {
                ActivityAwardSessionCard(
                    source: source,
                    emphasis: badge.award.unit == .kilometers ? .kilometers : nil,
                    onOpen: healthManager == nil ? nil : { openActivity(source) }
                )
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, minHeight: scrolls ? nil : 640)
    }
}

struct ActivityAwardSessionCard: View {
    let source: ActivityAwardSource
    var emphasis: ActivityAwardUnit? = nil
    var onOpen: (() -> Void)? = nil

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ActivityBadgeCopy.sessionTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
            Button(action: { onOpen?() }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(ActivityBadgePalette.leaf.opacity(0.16))
                            .frame(width: 32, height: 32)
                        Image(systemName: source.icon.isEmpty ? "figure.mixed.cardio" : source.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ActivityBadgePalette.leaf)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(source.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if let metric = ActivityAwardCopy.sessionMetric(source, preferring: emphasis) {
                            Text(metric)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(ActivityBadgePalette.leaf)
                                .lineLimit(1)
                        }
                        Text(ActivityAwardCopy.sessionWhen(source.startedAt))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if onOpen != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(onOpen == nil)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

struct ActivityAwardPlaques: View {
    let awardIDs: [String]
    var size: CGFloat = 32

    var body: some View {
        HStack(spacing: 4) {
            ForEach(awardIDs, id: \.self) { id in
                ActivityBadgeRibbon(
                    symbol: "medal.fill",
                    category: category(for: id),
                    artworkID: id,
                    locked: false,
                    size: size
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func category(for id: String) -> ActivityBadgeCategory {
        if id.hasPrefix("energy.") { return .energy }
        if id.hasPrefix("recovery.") { return .recovery }
        if id.hasPrefix("habit.") { return .habit }
        return .activity
    }
}
