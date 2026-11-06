import SwiftUI
import SwiftData
import WeekFitPlanner

struct ActivityCollectionScreen: View {
    var highlightedID: String?
    var dismissStyle: ProfilePremiumHeaderDismissStyle = .back
    var onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @Query(sort: \PlannedActivity.date, order: .forward)
    private var activities: [PlannedActivity]
    @ObservedObject private var store = ActivityBadgeStore.shared

    var body: some View {
        let goal = nutritionViewModel.nutritionResult?.goals.waterLiters ?? 0
        let sections = ActivityBadgePresenter.sections(
            ledger: store.ledger,
            inputs: activities.map(ActivityBadgeCenter.input(from:)),
            activityName: { PlannerOptionLocalization.localizedTitle(for: $0) }
        )
        ActivityCollectionView(
            sections: sections,
            highlightedID: highlightedID,
            dismissStyle: dismissStyle,
            onClose: { onClose?() ?? dismiss() },
            onStart: { badge in
                let opensWater = ActivityBadgeCenter.start(
                    badge,
                    activities: activities,
                    modelContext: modelContext,
                    waterGoalLiters: goal
                )
                if opensWater {
                    store.openWaterLog = true
                }
                onClose?() ?? dismiss()
            }
        )
    }
}

struct ActivityCollectionView: View {
    let sections: [ActivityBadgeSection]
    var highlightedID: String?
    var dismissStyle: ProfilePremiumHeaderDismissStyle = .back
    var scrolls = true
    let onClose: () -> Void
    let onStart: (ActivityBadgeDisplay) -> Void

    @Environment(\.weekFitPalette) private var palette
    @State private var selected: ActivityBadgeDisplay?

    private var unlocked: Int { sections.reduce(0) { $0 + $1.unlocked } }
    private var total: Int { sections.reduce(0) { $0 + $1.total } }

    var body: some View {
        ZStack {
            palette.appScreenBackground.ignoresSafeArea()
            Group {
                if scrolls {
                    ScrollView(showsIndicators: false) { collectionStack }
                } else {
                    collectionStack
                }
            }
        }
        .sheet(item: $selected) { badge in
            ActivityAwardDetailScreen(badge: badge, onClose: { selected = nil }, onStart: {
                selected = nil
                onStart(badge)
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            guard let highlightedID else { return }
            selected = sections.flatMap(\.cells).first { $0.id == highlightedID }
        }
    }

    private var collectionStack: some View {
        VStack(alignment: .leading, spacing: 22) {
                    ProfilePremiumHeader(
                        title: ActivityBadgeCopy.screenTitle,
                        subtitle: ActivityBadgeCopy.progress(unlocked: unlocked, total: total),
                        accent: ActivityBadgePalette.lavender,
                        dismissStyle: dismissStyle,
                        onClose: onClose
                    )
                    ForEach(sections) { section in
                        sectionBlock(section)
                    }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    private func sectionBlock(_ section: ActivityBadgeSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text(ActivityBadgeCopy.progress(unlocked: section.unlocked, total: section.total))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.textSecondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
                ForEach(section.cells) { badge in
                    Button {
                        selected = badge
                    } label: {
                        VStack(spacing: 8) {
                            ActivityBadgeRibbon(
                                symbol: badge.symbol,
                                category: badge.category,
                                artworkID: badge.id,
                                locked: !badge.isUnlocked,
                                size: 104
                            )
                            Text(badge.caption)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(palette.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(badge))
                }
            }
        }
    }

    private func accessibilityLabel(_ badge: ActivityBadgeDisplay) -> String {
        ActivityAwardCopy.accessibilityLabel(for: badge)
    }
}

struct ActivityBadgeUnlockedSheet: View {
    let badge: ActivityBadgeDisplay
    let onDone: () -> Void
    let onViewCollection: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        VStack(spacing: 14) {
            ActivityBadgeRibbon(
                symbol: badge.symbol,
                category: badge.category,
                artworkID: badge.id,
                size: 148
            )
            .padding(.top, 28)
            Text(ActivityBadgeCopy.unlockedTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
            Text(badge.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(palette.textPrimary)
            Text(detail)
                .font(.body)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: onDone) {
                Text(ActivityBadgeCopy.done)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.isLight ? Color.white : Color.black.opacity(0.86))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(ActivityBadgePalette.lavender, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            Button(action: onViewCollection) {
                Text(ActivityBadgeCopy.viewCollection)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.appScreenBackground.ignoresSafeArea())
    }

    private var detail: String {
        if let minutes = badge.actionMinutes {
            return ActivityBadgeCopy.russian
                ? "\(minutes) мин · \(badge.activityName)"
                : "\(minutes) minute of \(badge.activityName.lowercased())"
        }
        return badge.activityName
    }
}
