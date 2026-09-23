import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Full challenge experience: polished intro, daily task, journey, and summary.
struct RecoveryChallengeView: View {
    let source: String
    let onParticipationChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var participation: RecoveryChallengeParticipation?
    @State private var plannedDate: Date = Date()
    @State private var selectedHabitDayIndex: Int?
    @State private var selectedFavoriteDayIndex: Int?
    @State private var focusedJourneyDay: Int?
    @State private var errorMessage: String?
    @State private var acknowledgmentMessage: String?
    @State private var showCompletionPulse = false
    @State private var didTrackOpen = false
    @State private var isJoining = false
    @State private var isPerformingCompletion = false
    @State private var isHowItWorksExpanded = false
    @State private var planIsSuggestion = true
    @State private var hasExplicitPlanChoice = false
    @State private var isApplyingPlanSuggestion = false
    @State private var isEditingPlan = false
    @State private var plan: RecoveryChallengeWindDownPlanner.Plan?
    /// Calendar day key last used to drive phase UI — detects midnight / manual date jumps.
    @State private var lastObservedDayKey: String?

    private var accent: Color { WeekFitTheme.recovery }
    private var now: Date { Date() }

    private var phase: RecoveryChallengeScreenPhase {
        RecoveryChallengeEngine.screenPhase(now: now, participation: participation)
    }

    private var taskVersion: RecoveryChallengeTaskDefinitionVersion {
        participation?.resolvedTaskVersion ?? .current
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetChromeHeader
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: phase == .overview ? 22 : 20) {
                    content
                    if let acknowledgmentMessage {
                        acknowledgmentBanner(acknowledgmentMessage)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.red.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("recovery.challenge.error")
                    }
                    #if DEBUG
                    debugTools
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.top, phase == .overview ? 4 : 8)
                .padding(.bottom, 16)
            }
        }
        .background(WeekFitTheme.backgroundColor.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            footer
        }
        .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
        .accessibilityIdentifier("recovery.challenge.sheet")
        .onAppear {
            reload()
            // Do not mark intro here — that hid the Today entry path after a failed/partial
            // sheet open. Intro is marked only from overlay dismiss / successful enroll.
            if !didTrackOpen {
                didTrackOpen = true
                ProductScreenTracker.shared.trackScreenIfChanged(.recoveryChallenge)
                RecoveryChallengeAnalytics.overviewOpened(source: source)
            }
        }
        .onDisappear {
            // Swipe / close while on summary must clear Today + Coach finished chrome —
            // otherwise the challenge keeps appearing after the run is over.
            if case .summary = phase {
                RecoveryChallengeStore.dismissFinishedTodayCard()
                onParticipationChanged()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            handleCalendarContextChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            handleCalendarContextChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            handleCalendarContextChange()
        }
        .onChange(of: plannedDate) { _, newValue in
            guard !isApplyingPlanSuggestion else { return }
            hasExplicitPlanChoice = true
            planIsSuggestion = false
            let tz = participation?.timeZone ?? .current
            plan = RecoveryChallengeWindDownPlanner.planFromPickerSelection(
                selected: newValue,
                now: Date(),
                timeZone: tz,
                treatAsSuggestion: false
            )
        }
    }

    // MARK: - Header

    private var sheetChromeHeader: some View {
        VStack(spacing: 0) {
            // Native `.presentationDragIndicator(.visible)` is provided by the presenting
            // sheet — do not draw a second custom grabber here.

            if phase != .overview {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(WeekFitLocalizedString("challenge.recovery7.title"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(WeekFitTheme.primaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .accessibilityAddTraits(.isHeader)

                        if case .active(let dayIndex, _) = phase {
                            Text(
                                String(
                                    format: WeekFitLocalizedString("challenge.recovery7.dayOf"),
                                    dayIndex,
                                    RecoveryChallengeConfig.dayCount
                                )
                            )
                            .font(.caption.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(accent.opacity(palette.isLight ? 0.92 : 0.8))
                        } else if case .morningConfirm = phase {
                            Text(WeekFitLocalizedString("challenge.recovery7.morning.headerEyebrow"))
                                .font(.caption.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundStyle(accent.opacity(palette.isLight ? 0.92 : 0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    closeButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)
            } else {
                HStack {
                    Spacer(minLength: 0)
                    closeButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
            }
        }
    }

    private var closeButton: some View {
        WeekFitCloseButton(size: .large, playsHaptic: false) {
            dismiss()
        }
        .accessibilityLabel(WeekFitLocalizedString("common.action.close"))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        // Type-erase phase panes so the sheet’s opaque view type stays small.
        // A single mega-ViewBuilder here previously risked SwiftUI metadata blow-ups
        // (frozen UI / blocked tab bar) when presenting the sheet.
        switch phase {
        case .overview:
            AnyView(overviewContent)
        case .active(let dayIndex, let todayCompleted):
            AnyView(activeContent(dayIndex: dayIndex, todayCompleted: todayCompleted))
        case .morningConfirm(let dayIndex):
            AnyView(morningConfirmContent(dayIndex: dayIndex))
        case .summary(let completedCount):
            AnyView(summaryContent(completedCount: completedCount))
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            introHero
            dayOnePreview
            expectSection
            if let availability = availabilityLine {
                Text(availability)
                    .font(.caption.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("recovery.challenge.availability")
            }
            howItWorksSection
        }
    }

    private var introHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroVisual
                .frame(maxWidth: .infinity)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 148 : 168)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityHidden(true)

            Text(WeekFitLocalizedString("challenge.recovery7.intro.eyebrow"))
                .font(.caption2.weight(.bold))
                .fontDesign(.rounded)
                .tracking(1.2)
                .foregroundStyle(accent.opacity(palette.isLight ? 0.9 : 0.8))

            Text(WeekFitLocalizedString("challenge.recovery7.intro.headline"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(WeekFitLocalizedString("challenge.recovery7.intro.support"))
                .font(.system(size: 15.5, weight: .medium))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(WeekFitLocalizedString("challenge.recovery7.intro.badge"))
                .font(.caption.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(accent.opacity(0.95))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(WeekFitTheme.recoverySoftSurface)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(accent.opacity(palette.isLight ? 0.18 : 0.28), lineWidth: 1)
                )
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var heroVisual: some View {
        #if canImport(UIKit)
        if UIImage(named: "habit-sleep") != nil {
            Image("habit-sleep")
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(palette.isLight ? 0.08 : 0.28),
                            Color.black.opacity(palette.isLight ? 0.22 : 0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .bottomLeading) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .padding(16)
                }
        } else {
            nativeHeroFallback
        }
        #else
        nativeHeroFallback
        #endif
    }

    private var nativeHeroFallback: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    accent.opacity(palette.isLight ? 0.22 : 0.28),
                    WeekFitTheme.recoverySoftSurface,
                    WeekFitTheme.backgroundColor.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 92, weight: .ultraLight))
                .foregroundStyle(accent.opacity(0.14))
                .offset(x: 36, y: 10)
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(accent.opacity(0.95))
                .padding(18)
        }
    }

    private var dayOnePreview: some View {
        let day1 = RecoveryChallengeTaskCatalog.definition(dayIndex: 1, version: .v2)
        return VStack(alignment: .leading, spacing: 12) {
            Text(WeekFitLocalizedString("challenge.recovery7.intro.firstStepEyebrow"))
                .font(.caption2.weight(.bold))
                .fontDesign(.rounded)
                .tracking(1.15)
                .foregroundStyle(accent.opacity(0.84))

            Text(WeekFitLocalizedString(day1?.titleKey ?? "challenge.recovery7.v2.task.1.title"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(WeekFitLocalizedString(day1?.criterionKey ?? "challenge.recovery7.v2.task.1.criterion"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            previewJourneyStrip
                .padding(.top, 2)
                .accessibilityLabel(WeekFitLocalizedString("challenge.recovery7.intro.previewJourneyA11y"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .elevated, accent: accent, cornerRadius: 20)
    }

    private var previewJourneyStrip: some View {
        HStack(spacing: 7) {
            ForEach(1...RecoveryChallengeConfig.dayCount, id: \.self) { day in
                Capsule(style: .continuous)
                    .fill(day == 1 ? accent : WeekFitTheme.tertiaryText.opacity(0.22))
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 8 : 6)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
    }

    private var expectSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            expectRow(
                symbol: "checklist",
                titleKey: "challenge.recovery7.intro.expect.daily.title",
                bodyKey: "challenge.recovery7.intro.expect.daily.body"
            )
            Divider().opacity(0.35)
            expectRow(
                symbol: "chart.bar.fill",
                titleKey: "challenge.recovery7.intro.expect.progress.title",
                bodyKey: "challenge.recovery7.intro.expect.progress.body"
            )
            Divider().opacity(0.35)
            expectRow(
                symbol: "hand.tap.fill",
                titleKey: "challenge.recovery7.intro.expect.continue.title",
                bodyKey: "challenge.recovery7.intro.expect.continue.body"
            )
        }
        .padding(.vertical, 2)
    }

    private func expectRow(symbol: String, titleKey: String, bodyKey: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent.opacity(0.95))
                .frame(width: 28, height: 28)
                .background(Circle().fill(WeekFitTheme.recoverySoftSurface))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(WeekFitLocalizedString(titleKey))
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(WeekFitLocalizedString(bodyKey))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                let animation: Animation? = reduceMotion ? nil : .easeOut(duration: 0.2)
                withAnimation(animation) {
                    isHowItWorksExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(WeekFitLocalizedString("challenge.recovery7.intro.howItWorks"))
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(accent.opacity(0.92))
                    Image(systemName: isHowItWorksExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent.opacity(0.75))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isHowItWorksExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(WeekFitLocalizedString("challenge.recovery7.intro.howItWorksBody"))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(WeekFitLocalizedString("challenge.recovery7.intro.manualComplete"))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Active day

    private func activeContent(dayIndex: Int, todayCompleted: Bool) -> some View {
        let displayDay = focusedJourneyDay ?? dayIndex
        let isCurrent = displayDay == dayIndex
        let morningDay = participation.flatMap {
            RecoveryChallengeEngine.morningConfirmableDayIndex(now: now, participation: $0)
        }
        return VStack(alignment: .leading, spacing: 16) {
            journeyStrip(currentDay: dayIndex)

            Text(
                String(
                    format: WeekFitLocalizedString("challenge.recovery7.progress.count"),
                    participation?.completedCount ?? 0,
                    RecoveryChallengeConfig.dayCount
                )
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent.opacity(0.9))

            if let morningDay {
                morningConfirmCard(dayIndex: morningDay)
            }

            if isCurrent {
                if todayCompleted {
                    completedTaskCard(dayIndex: dayIndex)
                    if dayIndex < RecoveryChallengeConfig.dayCount {
                        tomorrowPreview(after: dayIndex)
                    }
                } else {
                    activeTaskCard(dayIndex: dayIndex)
                }
            } else {
                journeyPreviewCard(dayIndex: displayDay, currentDay: dayIndex)
            }
        }
    }

    private func morningConfirmCard(dayIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(WeekFitLocalizedString("challenge.recovery7.morning.prompt"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(WeekFitLocalizedString("challenge.recovery7.morning.support"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                String(
                    format: WeekFitLocalizedString("challenge.recovery7.morning.awaitingLabel"),
                    dayIndex
                )
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent.opacity(0.9))

            HStack(spacing: 10) {
                Button {
                    confirmMorning(dayIndex: dayIndex, didIt: true)
                } label: {
                    Text(WeekFitLocalizedString("challenge.recovery7.morning.yesCTA"))
                        .font(.footnote.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(WeekFitTheme.primaryCTAForeground)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(accent.opacity(palette.isLight ? 0.98 : 0.9)))
                }
                .buttonStyle(.plain)
                .disabled(isPerformingCompletion)

                Button {
                    confirmMorning(dayIndex: dayIndex, didIt: false)
                } label: {
                    Text(WeekFitLocalizedString("challenge.recovery7.morning.noCTA"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(isPerformingCompletion)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .elevated, accent: accent, cornerRadius: 20)
        .accessibilityIdentifier("recovery.challenge.morningConfirm")
    }

    private func activeTaskCard(dayIndex: Int) -> some View {
        let def = RecoveryChallengeTaskCatalog.definition(dayIndex: dayIndex, version: taskVersion)
        return VStack(alignment: .leading, spacing: 14) {
            taskHeader(definition: def, dayIndex: dayIndex)

            if let durationKey = def?.durationLabelKey {
                Text(WeekFitLocalizedString(durationKey))
                    .font(.caption.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(accent.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(WeekFitTheme.recoverySoftSurface))
            }

            if let criterionKey = def?.criterionKey {
                Text(WeekFitLocalizedString(criterionKey))
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let purposeKey = def?.purposeKey {
                Text(WeekFitLocalizedString(purposeKey))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(WeekFitTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let altKey = def?.alternativeKey {
                Text(WeekFitLocalizedString(altKey))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if def?.capability == .optionalSchedule {
                planEditor(for: dayIndex)
            }

            if def?.capability == .day5Breaks {
                day5BreakControls
            }

            if def?.capability == .day7FavoritePick {
                day7FavoritePicker
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .elevated, accent: accent, cornerRadius: 20)
        .scaleEffect(showCompletionPulse ? 1.02 : 1)
        .accessibilityIdentifier("recovery.challenge.activeTask")
    }

    private func completedTaskCard(dayIndex: Int) -> some View {
        let def = RecoveryChallengeTaskCatalog.definition(dayIndex: dayIndex, version: taskVersion)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent)
                Text(WeekFitLocalizedString(def?.acknowledgmentKey ?? "challenge.recovery7.active.completedBody"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let minutes = participation?.effectivePlannedMinuteOfDay,
               def?.capability == .optionalSchedule || (taskVersion == .v1 && dayIndex == 1) {
                let tz = participation?.timeZone ?? .current
                let saved = RecoveryChallengeWindDownPlanner.planFromSaved(
                    minuteOfDay: minutes,
                    dayKey: participation?.effectivePlannedTargetDayKey,
                    now: now,
                    timeZone: tz
                )
                Text(
                    String(
                        format: WeekFitLocalizedString("challenge.recovery7.plan.plannedFor"),
                        formattedPlanLabel(for: saved, timeZone: tz)
                    )
                )
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .elevated, accent: accent, cornerRadius: 20)
        .accessibilityIdentifier("recovery.challenge.completedTask")
    }

    private func tomorrowPreview(after dayIndex: Int) -> some View {
        let next = dayIndex + 1
        guard let def = RecoveryChallengeTaskCatalog.definition(dayIndex: next, version: taskVersion) else {
            return AnyView(EmptyView())
        }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text(WeekFitLocalizedString("challenge.recovery7.active.nextStepTomorrow"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                Text(WeekFitLocalizedString(def.titleKey))
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                Text(WeekFitLocalizedString(def.criterionKey))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .weekFitPremiumCard(emphasis: .standard, accent: accent, cornerRadius: 16)
        )
    }

    private func journeyPreviewCard(dayIndex: Int, currentDay: Int) -> some View {
        let state = participation.map {
            RecoveryChallengeEngine.journeyState(dayIndex: dayIndex, now: now, participation: $0)
        } ?? .future
        let def = RecoveryChallengeTaskCatalog.definition(dayIndex: dayIndex, version: taskVersion)
        let actionable = dayIndex == currentDay && state == .current

        return VStack(alignment: .leading, spacing: 10) {
            Text(journeyStateLabel(state))
                .font(.caption.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(accent.opacity(0.9))

            taskHeader(definition: def, dayIndex: dayIndex)

            if let criterionKey = def?.criterionKey {
                Text(WeekFitLocalizedString(criterionKey))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !actionable {
                Text(WeekFitLocalizedString("challenge.recovery7.journey.previewOnly"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WeekFitTheme.tertiaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .standard, accent: accent, cornerRadius: 20)
        .accessibilityIdentifier("recovery.challenge.journeyPreview")
    }

    private func taskHeader(definition: RecoveryChallengeTaskDefinition?, dayIndex: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(WeekFitTheme.recoverySoftSurface)
                    .frame(width: 44, height: 44)
                Image(systemName: definition?.symbolName ?? "leaf.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.95))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    String(
                        format: WeekFitLocalizedString("challenge.recovery7.dayOf"),
                        dayIndex,
                        RecoveryChallengeConfig.dayCount
                    )
                )
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent.opacity(0.85))

                Text(WeekFitLocalizedString(definition?.titleKey ?? ""))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Plan editor (optional schedule)

    private func planEditor(for dayIndex: Int) -> some View {
        let tz = participation?.timeZone ?? .current
        let currentPlan = plan
            ?? RecoveryChallengeWindDownPlanner.planFromPickerSelection(
                selected: plannedDate,
                now: now,
                timeZone: tz,
                treatAsSuggestion: planIsSuggestion
            )
        let savedPlan: RecoveryChallengeWindDownPlanner.Plan? = {
            guard let minutes = participation?.effectivePlannedMinuteOfDay else { return nil }
            return RecoveryChallengeWindDownPlanner.planFromSaved(
                minuteOfDay: minutes,
                dayKey: participation?.effectivePlannedTargetDayKey,
                now: now,
                timeZone: tz
            )
        }()

        return VStack(alignment: .leading, spacing: 12) {
            if let savedPlan, !participationHasOpenPlanEditor {
                Text(
                    String(
                        format: WeekFitLocalizedString("challenge.recovery7.plan.plannedFor"),
                        formattedPlanLabel(for: savedPlan, timeZone: tz)
                    )
                )
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)

                Button {
                    isEditingPlan = true
                } label: {
                    Text(WeekFitLocalizedString("challenge.recovery7.plan.changeTime"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            } else {
                if planIsSuggestion && !hasExplicitPlanChoice {
                    Text(WeekFitLocalizedString("challenge.recovery7.windDown.suggestionLabel"))
                        .font(.caption.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(accent.opacity(0.9))
                }

                HStack(alignment: .center, spacing: 12) {
                    Text(formattedPlanLabel(for: currentPlan, timeZone: tz))
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 26 : 30, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DatePicker("", selection: $plannedDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(accent)
                        .accessibilityLabel(WeekFitLocalizedString("challenge.recovery7.windDown.editTimeA11y"))
                }

                if currentPlan.isTomorrow {
                    Text(WeekFitLocalizedString("challenge.recovery7.windDown.tomorrowSupport"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                }

                Button {
                    savePlan(for: dayIndex)
                } label: {
                    Text(WeekFitLocalizedString("challenge.recovery7.plan.setTimeCTA"))
                        .font(.footnote.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("recovery.challenge.setTime")
            }

            Text(WeekFitLocalizedString("challenge.recovery7.input.noNotificationNote"))
                .font(.caption.weight(.medium))
                .foregroundStyle(WeekFitTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("recovery.challenge.planEditor")
    }

    private var participationHasOpenPlanEditor: Bool {
        isEditingPlan || participation?.effectivePlannedMinuteOfDay == nil
    }

    // MARK: - Day 5 / Day 7

    private var day5BreakControls: some View {
        let bits = RecoveryChallengeEngine.day5BreakMask(from: participation?.day5BreakCount ?? 0)
        let marked = bits.count
        return VStack(alignment: .leading, spacing: 10) {
            Text(
                String(
                    format: WeekFitLocalizedString("challenge.recovery7.day5.progress"),
                    marked,
                    3
                )
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(WeekFitTheme.secondaryText)

            ForEach(0..<3, id: \.self) { index in
                let on = bits.contains(index)
                Button {
                    _ = RecoveryChallengeStore.setDay5Break(breakIndex: index, enabled: !on)
                    participation = RecoveryChallengeStore.load()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? accent : WeekFitTheme.tertiaryText)
                        Text(
                            String(
                                format: WeekFitLocalizedString("challenge.recovery7.day5.breakLabel"),
                                index + 1
                            )
                        )
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if marked > 0 && marked < 3 {
                Text(WeekFitLocalizedString("challenge.recovery7.day5.partialNote"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WeekFitTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("recovery.challenge.day5Breaks")
    }

    private var day7FavoritePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("challenge.recovery7.day7.pickTitle"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(WeekFitTheme.secondaryText)

            ForEach(1...6, id: \.self) { day in
                let def = RecoveryChallengeTaskCatalog.definition(dayIndex: day, version: taskVersion)
                let selected = (selectedFavoriteDayIndex ?? participation?.day7SelectedFavoriteDayIndex) == day
                Button {
                    selectedFavoriteDayIndex = day
                    _ = RecoveryChallengeStore.selectDay7Favorite(dayIndex: day)
                    participation = RecoveryChallengeStore.load()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? accent : WeekFitTheme.tertiaryText)
                        Text(WeekFitLocalizedString(def?.titleKey ?? ""))
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(WeekFitTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }

            Text(WeekFitLocalizedString("challenge.recovery7.day7.selectionNotComplete"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(WeekFitTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("recovery.challenge.day7Favorite")
    }

    // MARK: - Morning confirm

    private func morningConfirmContent(dayIndex: Int) -> some View {
        let current = participation.flatMap {
            RecoveryChallengeEngine.challengeDayIndex(for: now, participation: $0)
        }
        return VStack(alignment: .leading, spacing: 16) {
            if let current {
                journeyStrip(currentDay: current)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(WeekFitLocalizedString("challenge.recovery7.morning.prompt"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(WeekFitLocalizedString("challenge.recovery7.morning.support"))
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    String(
                        format: WeekFitLocalizedString("challenge.recovery7.morning.awaitingLabel"),
                        dayIndex
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent.opacity(0.9))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .weekFitPremiumCard(emphasis: .elevated, accent: accent, cornerRadius: 20)
            .accessibilityIdentifier("recovery.challenge.morningConfirm")

            if let current,
               let participation,
               !participation.hasCompleted(dayIndex: current) {
                Text(WeekFitLocalizedString("challenge.recovery7.morning.todayStillAvailable"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
            }
        }
    }

    // MARK: - Journey strip

    private func journeyStrip(currentDay: Int) -> some View {
        HStack(spacing: dynamicTypeSize.isAccessibilitySize ? 6 : 8) {
            ForEach(1...RecoveryChallengeConfig.dayCount, id: \.self) { day in
                let state = participation.map {
                    RecoveryChallengeEngine.journeyState(dayIndex: day, now: now, participation: $0)
                } ?? .future
                Button {
                    focusedJourneyDay = day
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    journeyNode(day: day, state: state, isFocused: (focusedJourneyDay ?? currentDay) == day)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("recovery.challenge.progressStrip")
    }

    private func journeyNode(
        day: Int,
        state: RecoveryChallengeJourneyDayState,
        isFocused: Bool
    ) -> some View {
        let size: CGFloat = dynamicTypeSize.isAccessibilitySize ? 18 : 14
        return ZStack {
            switch state {
            case .completed:
                Circle().fill(accent)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.95))
            case .current:
                Circle().strokeBorder(accent, lineWidth: 2)
                    .background(Circle().fill(accent.opacity(0.18)))
            case .awaitingMorningConfirm:
                Circle().strokeBorder(accent.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                    .background(Circle().fill(accent.opacity(0.12)))
            case .missed:
                Circle()
                    .strokeBorder(WeekFitTheme.tertiaryText.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            case .future:
                Circle().fill(WeekFitTheme.tertiaryText.opacity(0.18))
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if isFocused {
                Circle().strokeBorder(accent.opacity(0.45), lineWidth: 1).padding(-3)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(journeyAccessibilityLabel(day: day, state: state)))
    }

    private func journeyStateLabel(_ state: RecoveryChallengeJourneyDayState) -> String {
        switch state {
        case .completed: return WeekFitLocalizedString("challenge.recovery7.a11y.completed")
        case .current: return WeekFitLocalizedString("challenge.recovery7.a11y.current")
        case .missed: return WeekFitLocalizedString("challenge.recovery7.a11y.missed")
        case .future: return WeekFitLocalizedString("challenge.recovery7.a11y.future")
        case .awaitingMorningConfirm: return WeekFitLocalizedString("challenge.recovery7.a11y.awaitingMorning")
        }
    }

    private func journeyAccessibilityLabel(day: Int, state: RecoveryChallengeJourneyDayState) -> String {
        String(
            format: WeekFitLocalizedString("challenge.recovery7.a11y.dayStatus"),
            day,
            journeyStateLabel(state)
        )
    }

    // MARK: - Summary

    private func summaryContent(completedCount: Int) -> some View {
        let perfect = completedCount == RecoveryChallengeConfig.dayCount
        return VStack(alignment: .leading, spacing: 16) {
            Text(
                perfect
                    ? WeekFitLocalizedString("challenge.recovery7.summary.perfectHeadline")
                    : String(
                        format: WeekFitLocalizedString("challenge.recovery7.summary.partialHeadline"),
                        completedCount,
                        RecoveryChallengeConfig.dayCount
                    )
            )
            .font(.title3.weight(.bold))
            .fontDesign(.rounded)
            .foregroundStyle(WeekFitTheme.primaryText)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear {
                RecoveryChallengeAnalytics.summaryViewed(completedCount: completedCount)
            }

            if let participation {
                summaryJourneyList(participation)
            }

            Text(
                perfect
                    ? WeekFitLocalizedString("challenge.recovery7.summary.perfectBody")
                    : WeekFitLocalizedString("challenge.recovery7.summary.partialBody")
            )
            .font(.system(size: 14.5, weight: .medium))
            .foregroundStyle(WeekFitTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            if let habitID = participation?.chosenHabitID,
               let title = habitTitle(for: habitID) {
                labeledMeta(
                    title: WeekFitLocalizedString("challenge.recovery7.summary.habitLabel"),
                    value: title
                )
            } else if !(participation?.completedDayIndices.filter { $0 <= 6 }.isEmpty ?? true) {
                completedHabitsPicker
            }
        }
    }

    private func summaryJourneyList(_ participation: RecoveryChallengeParticipation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(1...RecoveryChallengeConfig.dayCount, id: \.self) { day in
                let completed = participation.hasCompleted(dayIndex: day)
                let def = RecoveryChallengeTaskCatalog.definition(
                    dayIndex: day,
                    version: participation.resolvedTaskVersion
                )
                HStack(spacing: 10) {
                    Image(systemName: completed ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(completed ? accent : WeekFitTheme.tertiaryText)
                    Text(WeekFitLocalizedString(def?.titleKey ?? ""))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .weekFitPremiumCard(emphasis: .standard, accent: accent, cornerRadius: 16)
    }

    private var completedHabitsPicker: some View {
        let completedDays = (participation?.completedDayIndices ?? []).filter { (1...6).contains($0) }.sorted()
        return VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("challenge.recovery7.input.habitTitle"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(WeekFitTheme.secondaryText)

            ForEach(completedDays, id: \.self) { day in
                let def = RecoveryChallengeTaskCatalog.definition(dayIndex: day, version: taskVersion)
                let selected = selectedHabitDayIndex == day
                Button {
                    selectedHabitDayIndex = day
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? accent : WeekFitTheme.tertiaryText)
                        Text(WeekFitLocalizedString(def?.titleKey ?? ""))
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(WeekFitTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .weekFitPremiumCard(emphasis: .standard, accent: accent, cornerRadius: 16)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 8) {
            switch phase {
            case .overview:
                overviewFooter
            case .active(let dayIndex, let todayCompleted):
                if !todayCompleted, (focusedJourneyDay ?? dayIndex) == dayIndex {
                    activeFooter(dayIndex: dayIndex)
                }
            case .morningConfirm(let dayIndex):
                morningFooter(dayIndex: dayIndex)
            case .summary:
                summaryFooter
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background {
            WeekFitTheme.backgroundColor
                .opacity(palette.isLight ? 0.94 : 0.92)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(
                            palette.isLight
                                ? WeekFitLightTokens.divider.opacity(0.45)
                                : Color.white.opacity(0.08)
                        )
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private func activeFooter(dayIndex: Int) -> some View {
        if taskVersion == .v1, RecoveryChallengeTaskID(rawValue: dayIndex)?.requiresTimeInput == true {
            primaryButton(
                WeekFitLocalizedString("challenge.recovery7.active.saveTimeCompleteCTA"),
                disabled: isPerformingCompletion
            ) {
                markCompleteV1Day1()
            }
        } else {
            let ready = isReadyToComplete(dayIndex: dayIndex)
            primaryButton(
                WeekFitLocalizedString("challenge.recovery7.markCompleteCTA"),
                disabled: !ready || isPerformingCompletion
            ) {
                markComplete(dayIndex: dayIndex)
            }
        }
    }

    private func morningFooter(dayIndex: Int) -> some View {
        VStack(spacing: 8) {
            primaryButton(
                WeekFitLocalizedString("challenge.recovery7.morning.yesCTA"),
                disabled: isPerformingCompletion
            ) {
                confirmMorning(dayIndex: dayIndex, didIt: true)
            }
            Button {
                confirmMorning(dayIndex: dayIndex, didIt: false)
            } label: {
                Text(WeekFitLocalizedString("challenge.recovery7.morning.noCTA"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WeekFitTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .disabled(isPerformingCompletion)
        }
    }

    @ViewBuilder
    private var summaryFooter: some View {
        VStack(spacing: 10) {
            if shouldOfferHabitSaveFromSummary {
                primaryButton(
                    WeekFitLocalizedString("challenge.recovery7.saveHabitCTA"),
                    disabled: selectedHabitDayIndex == nil
                ) {
                    saveHabitFromSummary()
                }
            }

            // Always allow Done — habit save is optional and must never trap finished chrome.
            primaryButton(WeekFitLocalizedString("challenge.recovery7.doneCTA"), disabled: false) {
                dismissFinishedChallengeSurfaces()
            }
        }
    }

    private var shouldOfferHabitSaveFromSummary: Bool {
        guard participation?.chosenHabitID == nil else { return false }
        let completedBeforeDay7 = participation?.completedDayIndices.contains { $0 <= 6 } ?? false
        return completedBeforeDay7
    }

    private func dismissFinishedChallengeSurfaces() {
        RecoveryChallengeStore.dismissFinishedTodayCard()
        onParticipationChanged()
        dismiss()
    }

    @ViewBuilder
    private var overviewFooter: some View {
        switch overviewCTAState {
        case .eligible:
            primaryButton(WeekFitLocalizedString("challenge.recovery7.intro.startCTA"), disabled: isJoining) {
                join()
            }
            Text(WeekFitLocalizedString("challenge.recovery7.intro.startSupport"))
                .font(.caption.weight(.medium))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        case .upcoming:
            statusFooter(WeekFitLocalizedString("challenge.recovery7.intro.state.upcoming"))
        case .closed:
            statusFooter(WeekFitLocalizedString("challenge.recovery7.intro.state.closed"))
        case .unavailable:
            statusFooter(WeekFitLocalizedString("challenge.recovery7.intro.state.unavailable"))
        }
    }

    private func statusFooter(_ message: String) -> some View {
        Text(message)
            .font(.footnote.weight(.medium))
            .foregroundStyle(WeekFitTheme.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    private enum OverviewCTAState { case eligible, upcoming, closed, unavailable }

    private var overviewCTAState: OverviewCTAState {
        guard participation == nil else { return .unavailable }
        guard RecoveryChallengeConfig.isFeatureAvailable else { return .unavailable }
        guard let window = RecoveryChallengeConfig.eventWindow(now: now) else { return .unavailable }
        if now < window.start { return .upcoming }
        if RecoveryChallengeEngine.canEnroll(
            now: now,
            eventStart: window.start,
            eventEnd: window.end,
            timeZone: .current
        ) {
            return .eligible
        }
        return .closed
    }

    private var availabilityLine: String? {
        guard let window = RecoveryChallengeConfig.eventWindow(now: now) else { return nil }
        return String(
            format: WeekFitLocalizedString("challenge.recovery7.intro.availabilityFormat"),
            formatEventDates(start: window.start, end: window.end)
        )
    }

    private func primaryButton(
        _ title: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            guard !disabled else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryCTAForeground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background {
                    Capsule(style: .continuous)
                        .fill(accent.opacity(disabled ? 0.45 : (palette.isLight ? 0.98 : 0.9)))
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func acknowledgmentBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14.5, weight: .semibold, design: .rounded))
            .foregroundStyle(accent)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(WeekFitTheme.recoverySoftSurface)
            )
            .accessibilityIdentifier("recovery.challenge.acknowledgment")
    }

    #if DEBUG
    private var debugTools: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEBUG")
                .font(.caption2.weight(.bold))
                .foregroundStyle(WeekFitTheme.tertiaryText)
            Button("Reset to fresh v2 enrollment") {
                if case .success(let p) = RecoveryChallengeStore.debugResetToFreshV2Enrollment() {
                    participation = p
                    focusedJourneyDay = 1
                    acknowledgmentMessage = nil
                    onParticipationChanged()
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(accent)

            Button("Clear intro-shown (restore Today overlay)") {
                RecoveryChallengeStore.clearIntroShown()
                onParticipationChanged()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(accent)

            Button("Clear all challenge local state") {
                RecoveryChallengeStore.clear()
                participation = nil
                focusedJourneyDay = nil
                acknowledgmentMessage = nil
                onParticipationChanged()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(accent)
        }
        .padding(.top, 8)
    }
    #endif

    // MARK: - Actions

    private func reload() {
        participation = RecoveryChallengeStore.load()
        selectedFavoriteDayIndex = participation?.day7SelectedFavoriteDayIndex
        if let habit = participation?.chosenHabitID,
           habit.hasPrefix("taskDay."),
           let day = Int(habit.replacingOccurrences(of: "taskDay.", with: "")) {
            selectedHabitDayIndex = day
        }
        let tz = participation?.timeZone ?? .current
        let todayKey = RecoveryChallengeEngine.dayKey(for: Date(), timeZone: tz)
        let dayChanged = lastObservedDayKey != nil && lastObservedDayKey != todayKey
        lastObservedDayKey = todayKey

        if let minutes = participation?.effectivePlannedMinuteOfDay {
            let saved = RecoveryChallengeWindDownPlanner.planFromSaved(
                minuteOfDay: minutes,
                dayKey: participation?.effectivePlannedTargetDayKey,
                now: Date(),
                timeZone: tz
            )
            applyPlan(saved, asSuggestion: false)
            isEditingPlan = false
        } else {
            refreshPlanSuggestionIfNeeded(force: true)
        }
        if case .active(let day, _) = phase {
            if dayChanged || focusedJourneyDay == nil {
                focusedJourneyDay = day
            }
        } else if case .summary = phase {
            focusedJourneyDay = nil
        }
        errorMessage = nil
        isJoining = false
        isPerformingCompletion = false
        isEditingPlan = false
    }

    private func handleCalendarContextChange() {
        isEditingPlan = false
        acknowledgmentMessage = nil
        reload()
        refreshPlanSuggestionIfNeeded(force: participation?.effectivePlannedMinuteOfDay == nil)
    }

    private func join() {
        guard !isJoining else { return }
        isJoining = true
        errorMessage = nil
        switch RecoveryChallengeStore.enroll(taskDefinitionVersion: .v2) {
        case .success(let enrolled):
            RecoveryChallengeStore.markIntroShown()
            let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.28)
            withAnimation(animation) {
                participation = enrolled
                focusedJourneyDay = 1
            }
            refreshPlanSuggestionIfNeeded(force: true)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            RecoveryChallengeAnalytics.enrolled()
            onParticipationChanged()
            isJoining = false
        case .failure(let error):
            errorMessage = enrollmentErrorText(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            isJoining = false
        }
    }

    private func isReadyToComplete(dayIndex: Int) -> Bool {
        guard let participation else { return false }
        // Only the live calendar day is completable (blocks clock-rollback / preview taps).
        guard RecoveryChallengeEngine.challengeDayIndex(for: Date(), participation: participation) == dayIndex else {
            return false
        }
        if taskVersion == .v2 {
            if dayIndex == 5 { return RecoveryChallengeEngine.day5MarkedBreakCount(participation) >= 3 }
            if dayIndex == 7 {
                return (selectedFavoriteDayIndex ?? participation.day7SelectedFavoriteDayIndex) != nil
            }
        }
        return true
    }

    private func savePlan(for _: Int) {
        let tz = participation?.timeZone ?? .current
        switch RecoveryChallengeWindDownPlanner.validatedPlanForConfirmation(
            selected: plannedDate,
            isExplicitChoice: hasExplicitPlanChoice,
            now: Date(),
            timeZone: tz
        ) {
        case .success(let plan):
            applyPlan(plan, asSuggestion: false)
            switch RecoveryChallengeStore.savePlan(minuteOfDay: plan.minuteOfDay, targetDayKey: plan.dayKey) {
            case .success(let updated):
                participation = updated
                isEditingPlan = false
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                errorMessage = nil
            case .failure(let error):
                errorMessage = completionErrorText(error)
            }
        case .failure(.staleSuggestion):
            refreshPlanSuggestionIfNeeded(force: true)
            errorMessage = WeekFitLocalizedString("challenge.recovery7.windDown.staleSuggestion")
        }
    }

    private func markComplete(dayIndex: Int) {
        guard !isPerformingCompletion else { return }
        isPerformingCompletion = true
        let habit: String? = {
            if dayIndex == 7, let fav = selectedFavoriteDayIndex ?? participation?.day7SelectedFavoriteDayIndex {
                return "taskDay.\(fav)"
            }
            return nil
        }()
        switch RecoveryChallengeStore.completeDay(dayIndex: dayIndex, chosenHabitID: habit) {
        case .success(let updated):
            playCompletionSuccess(dayIndex: dayIndex, updated: updated)
        case .failure(let error):
            errorMessage = completionErrorText(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            isPerformingCompletion = false
        }
    }

    private func markCompleteV1Day1() {
        guard !isPerformingCompletion else { return }
        isPerformingCompletion = true
        let tz = participation?.timeZone ?? .current
        switch RecoveryChallengeWindDownPlanner.validatedPlanForConfirmation(
            selected: plannedDate,
            isExplicitChoice: hasExplicitPlanChoice,
            now: Date(),
            timeZone: tz
        ) {
        case .success(let plan):
            applyPlan(plan, asSuggestion: false)
            switch RecoveryChallengeStore.completeCurrentDay(
                windDownMinuteOfDay: plan.minuteOfDay,
                windDownTargetDayKey: plan.dayKey
            ) {
            case .success(let updated):
                playCompletionSuccess(dayIndex: 1, updated: updated)
            case .failure(let error):
                errorMessage = completionErrorText(error)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                isPerformingCompletion = false
            }
        case .failure(.staleSuggestion):
            refreshPlanSuggestionIfNeeded(force: true)
            errorMessage = WeekFitLocalizedString("challenge.recovery7.windDown.staleSuggestion")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            isPerformingCompletion = false
        }
    }

    private func confirmMorning(dayIndex: Int, didIt: Bool) {
        guard !isPerformingCompletion else { return }
        isPerformingCompletion = true
        if didIt {
            switch RecoveryChallengeStore.completeDay(dayIndex: dayIndex) {
            case .success(let updated):
                playCompletionSuccess(dayIndex: dayIndex, updated: updated)
            case .failure(let error):
                errorMessage = completionErrorText(error)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                isPerformingCompletion = false
            }
        } else {
            _ = RecoveryChallengeStore.declineMorningConfirm(dayIndex: dayIndex)
            participation = RecoveryChallengeStore.load()
            onParticipationChanged()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isPerformingCompletion = false
        }
    }

    private func playCompletionSuccess(dayIndex: Int, updated: RecoveryChallengeParticipation) {
        let def = RecoveryChallengeTaskCatalog.definition(
            dayIndex: dayIndex,
            version: updated.resolvedTaskVersion
        )
        let animation: Animation? = reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)
        withAnimation(animation) {
            participation = updated
            showCompletionPulse = true
            acknowledgmentMessage = WeekFitLocalizedString(
                def?.acknowledgmentKey ?? "challenge.recovery7.active.completedBody"
            )
            focusedJourneyDay = dayIndex
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        RecoveryChallengeAnalytics.dayCompleted(dayIndex: dayIndex)
        onParticipationChanged()
        errorMessage = nil
        isPerformingCompletion = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                showCompletionPulse = false
            }
        }
    }

    private func refreshPlanSuggestionIfNeeded(force: Bool = false) {
        if participation?.effectivePlannedMinuteOfDay != nil, !force { return }
        guard force || (!hasExplicitPlanChoice && !isEditingPlan && planIsSuggestion) else { return }
        let tz = participation?.timeZone ?? .current
        applyPlan(RecoveryChallengeWindDownPlanner.suggest(now: Date(), timeZone: tz), asSuggestion: true)
    }

    private func applyPlan(_ plan: RecoveryChallengeWindDownPlanner.Plan, asSuggestion: Bool) {
        isApplyingPlanSuggestion = true
        self.plan = plan
        plannedDate = plan.targetAt
        planIsSuggestion = asSuggestion
        hasExplicitPlanChoice = !asSuggestion
        // Keep the flag true until after the current run-loop turn so plannedDate's
        // onChange does not treat this programmatic update as an explicit user edit.
        DispatchQueue.main.async {
            isApplyingPlanSuggestion = false
        }
    }

    private func saveHabitFromSummary() {
        guard let day = selectedHabitDayIndex else { return }
        RecoveryChallengeStore.saveChosenHabitID("taskDay.\(day)")
        participation = RecoveryChallengeStore.load()
        RecoveryChallengeAnalytics.habitChosen()
        onParticipationChanged()
    }

    // MARK: - Helpers

    private func formattedPlanLabel(
        for plan: RecoveryChallengeWindDownPlanner.Plan,
        timeZone: TimeZone
    ) -> String {
        RecoveryChallengeWindDownPlanner.formatTimeAndDayLabel(plan: plan, timeZone: timeZone) { time in
            String(
                format: WeekFitLocalizedString("challenge.recovery7.windDown.tomorrowTimeFormat"),
                time
            )
        }
    }

    private func habitTitle(for habitID: String) -> String? {
        if habitID.hasPrefix("taskDay."),
           let day = Int(habitID.replacingOccurrences(of: "taskDay.", with: "")),
           let def = RecoveryChallengeTaskCatalog.definition(dayIndex: day, version: taskVersion) {
            return WeekFitLocalizedString(def.titleKey)
        }
        if let habit = RecoveryChallengeHabitID(rawValue: habitID) {
            return WeekFitLocalizedString(habit.localizationKey)
        }
        return nil
    }

    private func labeledMeta(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WeekFitTheme.secondaryText)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .standard, accent: accent, cornerRadius: 16)
    }

    private func formatEventDates(start: Date, end: Date) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: start, to: end.addingTimeInterval(-1))
    }

    private func enrollmentErrorText(_ error: RecoveryChallengeEnrollmentError) -> String {
        switch error {
        case .alreadyEnrolled:
            return WeekFitLocalizedString("challenge.recovery7.error.alreadyEnrolled")
        case .outsideEventWindow:
            return WeekFitLocalizedString("challenge.recovery7.intro.state.closed")
        case .sevenDaysDoNotFit:
            return WeekFitLocalizedString("challenge.recovery7.intro.state.notEnoughDays")
        case .featureUnavailable:
            return WeekFitLocalizedString("challenge.recovery7.intro.state.unavailable")
        }
    }

    private func completionErrorText(_ error: RecoveryChallengeCompletionError) -> String {
        switch error {
        case .alreadyCompleted:
            return WeekFitLocalizedString("challenge.recovery7.error.alreadyCompleted")
        case .missingRequiredInput:
            return WeekFitLocalizedString("challenge.recovery7.error.missingInput")
        case .futureDayLocked, .notCurrentDay:
            return WeekFitLocalizedString("challenge.recovery7.error.notCurrentDay")
        case .day5BreaksIncomplete:
            return WeekFitLocalizedString("challenge.recovery7.error.day5Incomplete")
        case .day7FavoriteMissing:
            return WeekFitLocalizedString("challenge.recovery7.error.day7FavoriteMissing")
        case .outsideEventWindow:
            return WeekFitLocalizedString("challenge.recovery7.intro.state.closed")
        case .morningWindowClosed:
            return WeekFitLocalizedString("challenge.recovery7.error.morningClosed")
        case .challengeFinished, .notEnrolled:
            return WeekFitLocalizedString("challenge.recovery7.error.generic")
        }
    }
}
