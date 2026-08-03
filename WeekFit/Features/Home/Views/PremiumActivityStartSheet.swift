import SwiftUI
import SwiftData
import WeekFitPlanner

struct PremiumActivityStartSheet: View {

    let background: Color
    let cardBackground: Color
    let textSecondary: Color

    @Binding var isPresented: Bool
    @Binding var refreshID: UUID

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: AppLanguageManager
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var coachInputProvider: CoachInputProvider
    @EnvironmentObject private var activityCoordinator: WeekFitActivityCoordinator

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var allPlannedActivities: [PlannedActivity]

    @State private var currentSubTab: String = "Workout"
    @State private var usageEntries: [String: QuickActivityUsageStore.Entry] = QuickActivityUsageStore.load()
    @State private var weatherRisk: ProposalWeatherRiskToken = .unavailable
    @State private var sortAscending = true
    @State private var revealContent = false
    @Environment(\.weekFitPalette) private var palette

    private var activeLiveActivity: PlannedActivity? {
        let now = Date()
        let calendar = Calendar.current

        return allPlannedActivities.first { activity in
            guard calendar.isDate(activity.date, inSameDayAs: now),
                  isTrackableLiveActivity(activity)
            else { return false }

            return activity.terminalState(now: now) == .active
        }
    }

    private var selectedPlannerType: PlannerType {
        currentSubTab == "Workout" ? .workout : .recovery
    }

    private var activityAccent: Color {
        QuickActivityAccent.color(for: selectedPlannerType, isLight: palette.isLight)
    }

    private var selectedAccentComponents: (red: Double, green: Double, blue: Double) {
        currentSubTab == "Workout"
            ? (palette.isLight ? (0.208, 0.678, 0.816) : (0.50, 0.62, 0.92))
            : (palette.isLight ? (0.482, 0.380, 0.820) : (0.66, 0.58, 0.86))
    }

    private var recoveryBand: CoachRecoveryBand? {
        guard let input = coachInputProvider.lastInput else { return nil }
        let readiness = CoachDayReadinessResolver.resolve(from: input)
        guard readiness.recoveryDataAvailable else { return nil }
        return readiness.recoveryBand
    }

    var body: some View {
        let _ = languageManager.selectedLanguage
        let liveActivity = activeLiveActivity

        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                QuickSheetPremiumHeader(
                    title: liveActivity != nil
                        ? WeekFitLocalizedString("home.activityStart.activeSession.title")
                        : WeekFitLocalizedString("home.activityStart.title"),
                    subtitle: liveActivity != nil
                        ? WeekFitLocalizedString("home.activityStart.activeSession.subtitle")
                        : WeekFitLocalizedString("home.activityStart.subtitle")
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isPresented = false
                }

                if let liveItem = liveActivity {
                    liveSessionCard(liveItem)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                }

                QuickActionSheetSegmentedControl(
                    segments: [
                        QuickActionSheetSegment(
                            id: "Workout",
                            title: WeekFitLocalizedString("home.activityStart.tab.workout"),
                            systemImage: "dumbbell.fill"
                        ),
                        QuickActionSheetSegment(
                            id: "Recovery",
                            title: WeekFitLocalizedString("home.activityStart.tab.recovery"),
                            systemImage: "leaf.fill"
                        )
                    ],
                    selection: $currentSubTab,
                    selectedAccent: activityAccent
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

                activityOptionsList(liveActivity: liveActivity)
            }
        }
        .onAppear {
            usageEntries = QuickActivityUsageStore.load()
            revealContent = false
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.04)) {
                revealContent = true
            }
            Task {
                let (summary, _) = await WeekFitWeatherProvider.shared.cachedSummaryAndFreshness()
                weatherRisk = ProposalWeatherRisk.resolve(from: summary)
            }
        }
        .onChange(of: currentSubTab) { _, _ in
            revealContent = false
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                revealContent = true
            }
        }
    }

    private func activityOptionsList(liveActivity: PlannedActivity?) -> some View {
        let options = selectedPlannerType.options
        let frequent = QuickActivityFrequentComposer.picks(
            options: options,
            usage: usageEntries,
            weatherRisk: weatherRisk,
            recoveryBand: recoveryBand
        )
        let sorted = sortedOptions(options)
        let isBlocked = liveActivity != nil

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if !frequent.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(WeekFitLocalizedString("today.quickLog.section.frequentlyUsed"))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(frequent.enumerated()), id: \.element.option.imageName) { _, pick in
                                    activityFrequentCard(
                                        option: pick.option,
                                        badge: pick.badge,
                                        isBlocked: isBlocked
                                    )
                                }
                            }
                            .padding(.vertical, 14)
                            .padding(.trailing, 18)
                        }
                        .padding(.horizontal, -18)
                        .padding(.leading, 18)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    allHeader(
                        title: WeekFitLocalizedString(
                            currentSubTab == "Workout"
                                ? "home.activityStart.section.allWorkouts"
                                : "home.activityStart.section.allRecovery"
                        )
                    )

                    VStack(spacing: 10) {
                        ForEach(sorted, id: \.imageName) { option in
                            let duration = defaultDuration(for: option, type: selectedPlannerType)
                            let category = ActivityOptionPresentation.category(for: option)
                            let chip = ActivityOptionPresentation.detailChip(for: option)
                            PremiumActivityStartCard(
                                title: localizedOptionTitle(option.title),
                                category: category,
                                categoryLabel: WeekFitLocalizedString(category.localizationKey),
                                detailLine: listDetailLine(option: option, duration: duration),
                                chip: chip,
                                chipLabel: WeekFitLocalizedString(chip.localizationKey),
                                imageName: option.imageName,
                                systemIcon: selectedPlannerType.icon,
                                accentColor: activityAccent,
                                hasConflict: isBlocked
                            ) {
                                start(option: option, duration: duration)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
            .opacity(revealContent ? 1 : 0)
            .offset(y: revealContent ? 0 : 10)
        }
    }

    private func sortedOptions(_ options: [PlannerOption]) -> [PlannerOption] {
        options.sorted {
            let left = localizedOptionTitle($0.title)
            let right = localizedOptionTitle($1.title)
            return sortAscending
                ? left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                : left.localizedCaseInsensitiveCompare(right) == .orderedDescending
        }
    }

    private func listDetailLine(option: PlannerOption, duration: Int) -> String {
        // Duration only — category is already shown as the colored label (avoids "Mobility Mobility").
        formattedDurationLabel(duration)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
    }

    private func allHeader(title: String) -> some View {
        HStack {
            sectionHeader(title)
            Spacer(minLength: 8)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                sortAscending.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(
                        WeekFitLocalizedString(
                            sortAscending ? "today.quickLog.sort.az" : "today.quickLog.sort.za"
                        )
                    )
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(activityAccent)
            }
            .buttonStyle(.plain)
        }
    }

    private func activityFrequentCard(
        option: PlannerOption,
        badge: QuickActivityFrequentComposer.Badge,
        isBlocked: Bool
    ) -> some View {
        let duration = defaultDuration(for: option, type: selectedPlannerType)
        let intensityKey = ActivityOptionPresentation.intensityLabelKey(for: option)
        let cardWidth: CGFloat = 172
        let cardHeight: CGFloat = 228
        let cardRadius: CGFloat = 26
        let accent = activityAccent

        return Button {
            start(option: option, duration: duration)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                activityThumb(option.imageName)
                    .frame(width: 108, height: 108)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.black.opacity(palette.isLight ? 0.05 : 0.0), lineWidth: 0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(localizedOptionTitle(option.title))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)
                    .padding(.top, 12)

                Text(WeekFitLocalizedString(intensityKey))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
                    .lineLimit(1)
                    .padding(.top, 2)

                Spacer(minLength: 8)

                HStack(alignment: .center, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(accent)
                        Text(formattedDurationLabel(duration))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.78))
                            .lineLimit(1)
                    }
                    .fixedSize()

                    Spacer(minLength: 2)

                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                        .offset(x: 0.5)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle().fill(accent)
                        }
                        .shadow(
                            color: palette.isLight ? accent.opacity(0.28) : .clear,
                            radius: 6,
                            y: 2
                        )
                }
            }
            .padding(14)
            .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                QuickActivityAccent.cardTop(accent: accent, isLight: palette.isLight),
                                QuickActivityAccent.cardBottom(accent: accent, isLight: palette.isLight)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                            .fill(
                                palette.isLight
                                    ? Color.white.opacity(0.22)
                                    : WeekFitTheme.cardBackground.opacity(0.55)
                            )
                    }
                    .shadow(
                        color: QuickSheetChrome.cardShadowColor(isLight: palette.isLight),
                        radius: QuickSheetChrome.cardShadowRadius,
                        y: QuickSheetChrome.cardShadowY
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .strokeBorder(
                        palette.isLight
                            ? accent.opacity(0.14)
                            : WeekFitTheme.whiteOpacity(0.08),
                        lineWidth: 0.75
                    )
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: badge.symbolName)
                        .font(.system(size: 9, weight: .bold))
                    Text(WeekFitLocalizedString(badge.localizationKey))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(palette.isLight ? accent : WeekFitTheme.secondaryText.opacity(0.88))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(
                            palette.isLight
                                ? Color.white.opacity(0.92)
                                : WeekFitTheme.whiteOpacity(0.08)
                        )
                }
                .overlay {
                    Capsule().strokeBorder(
                        palette.isLight
                            ? accent.opacity(0.28)
                            : WeekFitTheme.whiteOpacity(0.10),
                        lineWidth: 0.8
                    )
                }
                .padding(10)
            }
            .opacity(isBlocked ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isBlocked)
        .accessibilityLabel(localizedOptionTitle(option.title))
    }

    @ViewBuilder
    private func activityThumb(_ imageName: String) -> some View {
        if !imageName.isEmpty, UIImage(named: imageName) != nil {
            PremiumAssetImage(
                imageName: imageName,
                style: .activityThumbnail,
                accentColor: activityAccent,
                fallbackSystemName: selectedPlannerType.icon
            )
        } else {
            Image(systemName: selectedPlannerType.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    palette.isLight
                        ? activityAccent.opacity(0.7)
                        : WeekFitTheme.secondaryText.opacity(0.55)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    palette.isLight
                        ? activityAccent.opacity(0.10)
                        : WeekFitTheme.whiteOpacity(0.06)
                )
        }
    }

    private func formattedDurationLabel(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            if remaining == 0 {
                return String(format: WeekFitLocalizedString("common.duration.hoursShortFormat"), Int64(hours))
            }
            return String(
                format: WeekFitLocalizedString("common.duration.hoursMinutesShortFormat"),
                Int64(hours),
                Int64(remaining)
            )
        }
        return String(format: WeekFitLocalizedString("common.duration.minutesFormat"), Int64(minutes))
    }

    private func start(option: PlannerOption, duration: Int) {
        guard activeLiveActivity == nil else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let components = selectedAccentComponents

        let newActivity = PlannedActivity(
            id: UUID().uuidString,
            date: Date(),
            type: selectedPlannerType.title.lowercased(),
            title: option.title,
            durationMinutes: duration,
            icon: WeekFitActivityIconResolver.preferredIcon(
                storedIcon: option.icon,
                title: option.title,
                type: selectedPlannerType.title.lowercased(),
                imageName: option.imageName
            ),
            imageName: option.imageName,
            colorRed: components.red,
            colorGreen: components.green,
            colorBlue: components.blue,
            calories: 0,
            protein: 0,
            carbs: 0,
            fats: 0,
            isCompleted: false,
            isSkipped: false,
            source: "today"
        )

        AppReviewDemoPlannedActivityTagger.tagIfNeeded(newActivity)
        modelContext.insert(newActivity)
        do {
            try modelContext.save()
            QuickActivityUsageStore.record(imageName: option.imageName)
            usageEntries = QuickActivityUsageStore.load()
            ProductAnalytics.activityStarted(
                category: ProductAnalytics.activityCategory(forType: newActivity.type),
                source: .today
            )
        } catch {
            modelContext.delete(newActivity)
            ProductAnalytics.activityLoggingFailed(source: .today, reason: .saveFailed)
            return
        }

        isPresented = false
        refreshID = UUID()
    }

    private func isTrackableLiveActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        return type == "workout" || type == "recovery"
    }

    private func defaultDuration(for option: PlannerOption, type: PlannerType) -> Int {
        let title = option.title.lowercased()

        if title.contains("sleep") || title.contains("bedtime") {
            return 480
        }

        if title.contains("breath") || title.contains("breathing") {
            return 10
        }

        if title.contains("stretch") || title.contains("mobility") {
            return 20
        }

        if title.contains("sauna") {
            return 20
        }

        if type == .recovery {
            return 20
        }

        return 60
    }

    private func localizedOptionTitle(_ title: String) -> String {
        PlannerOptionLocalization.localizedTitle(for: title)
    }

    private func localizedOptionSubtitle(_ subtitle: String) -> String {
        PlannerOptionLocalization.localizedSubtitle(for: subtitle)
    }

    private func liveSessionCard(_ liveItem: PlannedActivity) -> some View {
        let accentColor = WeekFitTheme.brandGold
        let badgeColor = WeekFitTheme.brandGoldDeep

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.14))
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(accentColor.opacity(0.28), lineWidth: 1))

                Image(systemName: liveItem.icon.isEmpty ? "figure.run" : liveItem.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(badgeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 5, height: 5)
                        .phaseAnimator([0.35, 1.0]) { content, phase in
                            content.opacity(phase)
                        } animation: { _ in
                            .easeInOut(duration: 0.9)
                        }

                    Text(WeekFitLocalizedString("home.liveNow"))
                        .font(.system(size: 9.4, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(badgeColor)
                }

                Text(localizedOptionTitle(liveItem.title))
                    .font(.system(size: 15.2, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)

                liveProgressText(startedAt: liveItem.date, maxMinutes: liveItem.durationMinutes)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                liveTimer(startedAt: liveItem.date)

                Button {
                    stopLiveSession(liveItem)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(WeekFitLightTokens.critical)
                        )
                        .shadow(color: WeekFitLightTokens.critical.opacity(0.22), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(WeekFitLocalizedString("common.action.close")))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPrimaryCard(accent: accentColor, featured: true)
    }

    private func liveTimer(startedAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(startedAt)))
            let minutes = elapsed / 60
            let seconds = elapsed % 60
            let timeText = String(format: "%02d:%02d", minutes, seconds)

            Text(timeText)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(WeekFitTheme.primaryText)
                .frame(width: 82, alignment: .trailing)
        }
    }

    private func liveProgressText(startedAt: Date, maxMinutes: Int) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(startedAt)))
            let elapsedMinutes = min(elapsed / 60, max(maxMinutes, 1))

            Text(String(format: WeekFitLocalizedString("home.activityStart.progressFormat"), elapsedMinutes, maxMinutes))
                .font(.system(size: 10.6, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(WeekFitTheme.secondaryText)
                .lineLimit(1)
        }
    }

    private func stopLiveSession(_ activity: PlannedActivity) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let passedMinutes = max(1, Int(Date().timeIntervalSince(activity.date) / 60))

        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            activity.actualDurationMinutes = passedMinutes
            activity.isCompleted = true

            try? modelContext.save()

            ReviewEngagement.record(.activityLoggedOrCompleted)
            ProductAnalytics.activityCompleted(
                category: ProductAnalytics.activityCategory(forType: activity.type),
                source: .today
            )

            refreshID = UUID()
            isPresented = false
        }

        CoachSnapshotInvalidator.invalidate(
            coordinator: coachCoordinator,
            nutritionViewModel: nutritionViewModel,
            inputProvider: coachInputProvider,
            reason: "todayActivityStop"
        )
        activityCoordinator.refresh()
        appSession.triggerHealthRefresh(source: "todayActivityStop")
        appSession.triggerCoachRefresh(source: "todayActivityStop")
    }
}
