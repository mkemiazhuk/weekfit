import SwiftUI
import SwiftData
import UIKit
import WeekFitPlanner

struct ActivityCollectionScreen: View {
    var highlightedID: String?
    var dismissStyle: ProfilePremiumHeaderDismissStyle = .back
    var onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var healthManager: HealthManager
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
            },
            healthManager: healthManager,
            plannedActivities: activities
        )
        .task {
            await ActivityBadgeCenter.backfillDistances(
                activities: activities,
                modelContext: modelContext,
                waterGoalLiters: goal
            )
        }
    }
}

struct ActivityCollectionView: View {
    let sections: [ActivityBadgeSection]
    var highlightedID: String?
    var dismissStyle: ProfilePremiumHeaderDismissStyle = .back
    var scrolls = true
    let onClose: () -> Void
    let onStart: (ActivityBadgeDisplay) -> Void
    var healthManager: HealthManager? = nil
    var plannedActivities: [PlannedActivity] = []

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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background { ActivityCollectionPopEnabler() }
        .fullScreenCover(item: $selected) { badge in
            ActivityAwardDetailScreen(
                badge: badge,
                onClose: { selected = nil },
                onStart: {
                    selected = nil
                    onStart(badge)
                },
                healthManager: healthManager,
                plannedActivities: plannedActivities
            )
        }
        .onAppear {
            guard let highlightedID else { return }
            selected = sections.flatMap(\.cells).first { $0.id == highlightedID }
        }
    }

    private var collectionStack: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                if dismissStyle != .close {
                    ProfilePremiumDismissButton(style: .back, action: onClose)
                }
                Spacer(minLength: 0)
                if dismissStyle == .close {
                    WeekFitCloseButton(size: .large, playsHaptic: false, action: onClose)
                        .accessibilityLabel(Text(AppText.Common.Action.close))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(ActivityBadgeCopy.screenTitle)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text(ActivityBadgeCopy.progress(unlocked: unlocked, total: total))
                    .foregroundStyle(palette.textSecondary)
                GeometryReader { geometry in
                    Capsule().fill(ActivityBadgePalette.leaf.opacity(0.16))
                        .overlay(alignment: .leading) {
                            Capsule().fill(ActivityBadgePalette.leaf)
                                .frame(width: geometry.size.width * CGFloat(unlocked) / CGFloat(max(total, 1)))
                        }
                }
                .frame(height: 7)
            }

            ForEach(sections) { section in
                sectionBlock(section)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
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
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3),
                spacing: 16
            ) {
                ForEach(section.cells) { badge in
                    badgeCell(badge)
                }
            }
        }
    }

    private func badgeCell(_ badge: ActivityBadgeDisplay) -> some View {
        let content = VStack(spacing: 6) {
            ActivityBadgeRibbon(
                symbol: badge.symbol,
                category: badge.category,
                artworkID: badge.id,
                locked: !badge.isUnlocked,
                size: 96
            )
            Text(badge.caption)
                .font(.system(size: badge.isUnlocked ? 13 : 11, weight: badge.isUnlocked ? .semibold : .regular))
                .foregroundStyle(badge.isUnlocked ? palette.textPrimary : palette.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 16)
            timesPill(badge.isUnlocked ? badge.times : 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)

        return Button {
            selected = badge
        } label: {
            content
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(badge))
        .accessibilityAddTraits(.isButton)
    }

    /// Small count under the name, the same place as the Activity app’s repeat total.
    private func timesPill(_ times: Int) -> some View {
        Text(times > 0 ? "\(times)" : " ")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background {
                if times > 0 {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(palette.textPrimary.opacity(0.08))
                }
            }
            .opacity(times > 0 ? 1 : 0)
            .accessibilityHidden(true)
    }

    private func accessibilityLabel(_ badge: ActivityBadgeDisplay) -> String {
        var label = ActivityAwardCopy.accessibilityLabel(for: badge)
        if badge.isUnlocked, badge.times > 0 {
            label += ", \(badge.times)"
        }
        return label
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

/// Keeps the edge swipe after the navigation back button is hidden.
private struct ActivityCollectionPopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigation = navigationController, navigation.viewControllers.count > 1 else { return }
            navigation.interactivePopGestureRecognizer?.isEnabled = true
            navigation.interactivePopGestureRecognizer?.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}
