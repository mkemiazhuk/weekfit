import SwiftUI
import SwiftData
import HealthKit
internal import Combine

private final class CoachScreenLifecycleTracker: ObservableObject {
    init() {
        #if DEBUG
        CoachRefreshDebug.log(
            "[CoachScreenLifecycle]",
            "Coach screen state object init"
        )
        #endif
    }
}

struct ExpertCoachViewV3: View {

    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var languageManager: AppLanguageManager
    @Environment(\.modelContext) private var modelContext

    @StateObject private var userSettings = WeekFitUserSettings.shared
    @StateObject private var lifecycleTracker = CoachScreenLifecycleTracker()
    @StateObject private var screenViewModel = CoachScreenViewModel()

    @State private var showProfile = false

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    private let coachContentHorizontalInset: CGFloat = 0

    private let background = WeekFitTheme.backgroundColor
    private let cardBackground = WeekFitTheme.cardBackground
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let green = WeekFitTheme.meal

    init(authViewModel: AuthViewModel) {
        _ = authViewModel
    }

    var body: some View {
        let _ = lifecycleTracker
        let _ = languageManager.selectedLanguage

        return ZStack(alignment: .top) {
            WeekFitTheme.appBackground
                .ignoresSafeArea()

            ambientBackground

            WeekFitScreenContainer {

                WeekFitScreenHeader(
                    title: WeekFitLocalizedString("common.tab.coach"),
                    subtitle: selectedDateTitle,
                    initials: userSettings.profileInitials,
                    showAvatar: true
                ) {
                    showProfile = true
                }

            } content: {
                coachContent
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.coach")
        .onAppear {
            #if DEBUG
            CoachRefreshDebug.log(
                "[CoachScreenLifecycle]",
                "CoachView onAppear stateID=\(coachCoordinator.state.id) \(debugCoachPrioritySummary())"
            )
            debugCoachHeroColorSystem(event: "onAppear")
            debugCoachV6Integration(event: "onAppear")
            #endif
        }
        .onChange(of: coachCoordinator.state.id) { _, _ in
            #if DEBUG
            debugCoachHeroColorSystem(event: "stateChanged")
            debugCoachV6Integration(event: "stateChanged")
            #endif
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
            .environmentObject(healthManager)
            .environmentObject(nutritionViewModel)
            .environmentObject(appSession)
            .environmentObject(languageManager)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .weekFitSheetChrome(cornerRadius: 36)
        }
    }


    // MARK: - Coach V3 Binding
    
    private var dayContext: CoachDayContext {
        screenViewModel.dayContext(
            selectedDate: screenViewModel.selectedDate,
            allPlannedActivities: plannedActivities
        )
    }

    private var hasTodayRecoverySignals: Bool {
        screenViewModel.hasTodayRecoverySignals(healthManager: healthManager)
    }

    private var shouldShowHealthConnectPrompt: Bool {
        screenViewModel.shouldShowHealthConnectPrompt(healthManager: healthManager)
    }

    private var guidance: CoachGuidanceV3 {
        coachCoordinator.state.guidance ?? fallbackGuidance
    }


    private var coachScenario: CoachActivityScenario {
        guard let brain = nutritionViewModel.coachMetricsSnapshot?.brain else {
            return fallbackCoachScenario
        }

        return CoachActivityScenarioResolver.resolve(
            phase: effectiveCoachPhase,
            brain: brain
        )
    }

    private var coachRule: CoachScenarioRule {
        guard let snapshot = nutritionViewModel.coachMetricsSnapshot else {
            return fallbackCoachRule
        }
        let brain = snapshot.brain

        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: effectiveCoachPhase
        )

        return CoachScenarioRuleEngine.resolve(
            scenario: coachScenario,
            dayContext: dayContext,
            recoveryContext: snapshot.recoveryContext,
            nutritionContext: snapshot.nutritionContext,
            readiness: readiness,
            brain: brain
        )
    }

    private var coachV6Presentation: CoachV6UIPresentation? {
        coachCoordinator.state.coachV6Presentation
    }

    private var finalStory: CoachFinalStory? {
        coachCoordinator.state.finalStory
    }

    private var finalStoryRenderModel: CoachFinalStoryRenderModel? {
        guard coachV6Presentation == nil else { return nil }
        guard let finalStory else { return nil }
        return CoachFinalStoryRenderModel(story: finalStory)
    }

    private var fallbackCoachScenario: CoachActivityScenario {
        CoachActivityScenario(
            stage: .stable,
            archetype: .stable,
            kind: .other,
            load: .low,
            durationBucket: .under30,
            dayTime: coachDayTime(from: Calendar.current.component(.hour, from: Date())),
            activity: nil,
            minutesUntilStart: nil,
            minutesSinceEnd: nil
        )
    }

    private var fallbackCoachRule: CoachScenarioRule {
        let stable = CoachActivityContextResolverV3.stablePresentation(from: coachDayContext)
        return CoachScenarioRule(
            stateLabel: "OVERVIEW",
            title: stable.title,
            message: stable.message,
            supportFocus: [
                WeekFitLocalizedString("coach.fallback.keepRhythm"),
                WeekFitLocalizedString("coach.fallback.avoidUnnecessaryIntensity"),
                WeekFitLocalizedString("coach.fallback.followThePlan")
            ],
            supportActions: [],
            avoidNotes: []
        )
    }

    private var presentationSemanticColor: Color {
        if let v6 = coachV6Presentation {
            return v6.semanticColor.uiColor
        }
        return coachCoordinator.state.coachPresentation?.color
            ?? coachCoordinator.state.todayPresentation.color
    }

    private var coachAccentColor: Color {
        presentationSemanticColor
    }

    private var heroSemanticColor: Color {
        presentationSemanticColor
    }

    private var heroSemanticColorSource: String {
        if coachV6Presentation != nil {
            return "coachV6Presentation.semanticColor"
        }
        if coachCoordinator.state.coachPresentation != nil {
            return "coachPresentation.color"
        }
        if coachCoordinator.state.finalStory != nil {
            return "todayPresentation.color"
        }
        return "coachScreenStory.color"
    }

    private var coachIcon: String {
        coachV6Presentation?.icon
            ?? finalStoryRenderModel?.icon
            ?? coachCoordinator.state.coachPresentation?.icon
            ?? coachScreenStory.icon
    }

    private var coachScreenStory: CoachScreenStory {
        if let story = guidance.screenStory {
            return story
        }

        let fallbackDecision = HumanCoachDecision(
            status: .goodToGo,
            title: fallbackGuidance.title,
            myRead: fallbackGuidance.message,
            myRecommendation: WeekFitLocalizedString("coach.fallback.keepNextStepSimple"),
            beCarefulWith: WeekFitLocalizedString("coach.fallback.normalDayWarning"),
            why: nil,
            planChallenge: nil,
            supportingActions: [
                CoachSupportingAction(
                    type: .stayConsistent,
                    icon: "waveform.path.ecg",
                    title: WeekFitLocalizedString("coach.fallback.keepRhythm"),
                    subtitle: WeekFitLocalizedString("coach.fallback.stayConsistentWithBasics"),
                    color: CoachPalette.stable
                )
            ],
            priority: .supporting,
            sourceSignals: [],
            v5Contract: nil,
            narrativePlan: nil,
            dayDecisionFrame: nil
        )

        return CoachScreenStory(
            decision: fallbackDecision,
            phase: fallbackGuidance.phase,
            icon: fallbackGuidance.icon,
            color: fallbackGuidance.color,
            tone: fallbackGuidance.tone
        )
    }

    private var coachRenderedTitle: String {
        coachCoordinator.state.coachPresentation?.title
            ?? finalStoryRenderModel?.title
            ?? validTitle(guidance.title)
            ?? coachScreenStory.title
    }

    private func validTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var fallbackGuidance: CoachGuidanceV3 {
        CoachGuidanceV3(
            phase: .stable,
            opportunity: CoachSupportOpportunityV3(
                type: .stable,
                importance: .quiet,
                reason: "No active guidance."
            ),
            shouldSurface: false,
            stateLabel: "OVERVIEW",
            title: WeekFitLocalizedString("coach.fallback.noActiveFocusRightNow"),
            message: CoachActivityContextResolverV3.stablePresentation(from: coachDayContext).message,
            insightTitle: CoachActivityContextResolverV3.stablePresentation(from: coachDayContext).title,
            insightSubtitle: nil,
            supportActions: [
                CoachSupportActionV3(
                    type: .stayConsistent,
                    icon: "waveform.path.ecg",
                    title: WeekFitLocalizedString("coach.fallback.keepRhythm"),
                    subtitle: WeekFitLocalizedString("coach.fallback.stayConsistentWithBasics"),
                    color: CoachPalette.stable
                )
            ],
            avoidNotes: [],
            icon: "waveform.path.ecg.rectangle.fill",
            color: green,
            importance: .quiet,
            tone: .calm
        )
    }

    // MARK: - Background

    private var ambientBackground: some View {
        WeekFitTheme.coachAmbient
            .blur(radius: 30)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private func coachDayTime(from hour: Int) -> CoachDayTime {
        switch hour {
        case 5..<10:
            return .morning
        case 10..<12:
            return .preLunch
        case 12..<14:
            return .lunch
        case 14..<18:
            return .afternoon
        case 18..<21:
            return .evening
        case 21..<24:
            return .lateEvening
        default:
            return .night
        }
    }

    private var selectedDateTitle: String {
        screenViewModel.selectedDateTitle(for: screenViewModel.selectedDate)
    }

    // MARK: - Coach Card

    private var coachCard: some View {
        let story = finalStoryRenderModel == nil ? coachScreenStory : nil
        let presentation = finalStoryRenderModel == nil ? coachCoordinator.state.coachPresentation : nil
        let renderedTitle = coachRenderedTitle
        let heroCopy = coachHeroCopy(story: story, presentation: presentation)
        let renderedRead = heroCopy.read
        let renderedRecommendation = heroCopy.recommendation
        let renderedRisk = heroCopy.risk
        let shouldShowRisk = heroCopy.showRisk
        let shouldShowRead = heroCopy.showRead
        let v6NextAction = coachV6Presentation?.nextAction.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let shouldShowV6NextAction = !v6NextAction.isEmpty
        let v6WarningMessage = coachV6Presentation?.warningMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let shouldShowV6Warning = !v6WarningMessage.isEmpty

        return ZStack(alignment: .topTrailing) {
            Image(systemName: coachIcon)
                .font(.system(size: 68, weight: .regular))
                .foregroundStyle(heroSemanticColor.opacity(0.045))
                .offset(x: -4, y: 22)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                stateBadge

                if shouldShowV6Warning {
                    coachV6WarningBanner(v6WarningMessage)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(renderedTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.8)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        if shouldShowRead {
                            coachHeroTextBlock(
                                label: WeekFitLocalizedString("coach.hero.myRead"),
                                text: renderedRead
                            )
                        }

                        coachHeroTextBlock(
                            label: WeekFitLocalizedString("coach.hero.myRecommendation"),
                            text: renderedRecommendation
                        )

                        if shouldShowRisk {
                            coachHeroTextBlock(
                                label: WeekFitLocalizedString("coach.hero.beCarefulWith"),
                                text: renderedRisk
                            )
                        }

                        if shouldShowV6NextAction {
                            coachHeroTextBlock(
                                label: coachV6NextActionLabel,
                                text: v6NextAction
                            )
                        }
                    }
                }
                .padding(.top, 14)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            heroSemanticColor.opacity(0.13),
                            cardBackground.opacity(0.50),
                            cardBackground.opacity(0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    heroSemanticColor.opacity(0.22),
                                    Color.white.opacity(0.035)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: heroSemanticColor.opacity(0.085), radius: 18, y: 8)
        .shadow(color: Color.black.opacity(0.18), radius: 14, y: 7)
    }

    private func coachContextChip(_ chip: CoachActivityContextChip) -> some View {
        HStack(spacing: 6) {
            Image(systemName: chip.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(heroSemanticColor.opacity(0.82))

            Text(chip.label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(heroSemanticColor.opacity(0.10))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(heroSemanticColor.opacity(0.16), lineWidth: 1)
        )
    }

    private var coachV6NextActionLabel: String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? "Следующий шаг" : "Next step"
    }

    private func coachV6WarningBanner(_ message: String) -> some View {
        let accent = coachV6Presentation?.alertSeverity.uiAccentColor ?? CoachPalette.warning

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)

            Text(message)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.92))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
    }

    private func coachHeroTextBlock(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .black, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(textSecondary.opacity(0.42))

            Text(text)
                .font(.system(size: 13.4, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.76))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func coachLocalizedGeneratedText(_ text: String, fallback: String) -> String {
        let localized = WeekFitCoachRuntimeLocalizedString(text)
        if localized != text || !WeekFitCurrentLocale().identifier.hasPrefix("ru") {
            return localized
        }
        return fallback
    }

    private enum CoachHeroCopyRole {
        case assessment
        case recommendation
        case caution
    }

    private func coachOneStoryHeroText(
        _ text: String,
        role: CoachHeroCopyRole,
        fallback: String
    ) -> String {
        let localized = coachLocalizedGeneratedText(text, fallback: fallback)

        guard shouldUsePrimaryStoryFallback(localized, role: role) else {
            return localized
        }

        return fallback
    }

    private func shouldUsePrimaryStoryFallback(
        _ text: String,
        role: CoachHeroCopyRole
    ) -> Bool {
        let normalized = coachNormalizedCopy(text)
        guard !normalized.isEmpty else { return true }

        if WeekFitCurrentLocale().identifier.hasPrefix("ru") && containsEnglishCoachCopy(normalized) {
            return true
        }

        let competingSignals = competingCoachSignals(in: normalized)
        if competingSignals.count > 1 {
            return true
        }

        switch guidance.priority.focus {
        case .recoveryNeeded, .postActivityRecovery:
            return competingSignals.contains { $0 != "recovery" }
        case .activeActivity, .prepareForActivity, .nextActivityLater, .performanceReadiness, .trainingReadinessWarning:
            return competingSignals.contains { $0 != "activity" && $0 != "readiness" }
        case .hydrationBehind:
            return competingSignals.contains { $0 != "hydration" }
        case .fuelBehind:
            return competingSignals.contains { $0 != "fuel" }
        case .tomorrowPlanRisk:
            return competingSignals.contains { $0 != "tomorrow" && $0 != "recovery" }
        case .dailyOverview, .eveningWindDown:
            return false
        }
    }

    private func containsEnglishCoachCopy(_ normalized: String) -> Bool {
        let englishFragments = [
            "recovery is",
            "main constraint",
            "should stay below",
            "normal ceiling",
            "fuel is",
            "hydration is",
            "this effort",
            "today s",
            "upper body",
            "running",
            "cycling"
        ]

        return englishFragments.contains { normalized.contains($0) }
    }

    private func competingCoachSignals(in normalized: String) -> Set<String> {
        var signals = Set<String>()

        if normalized.contains("recovery") ||
            normalized.contains("восстанов") ||
            normalized.contains("устал") {
            signals.insert("recovery")
        }

        if normalized.contains("activity") ||
            normalized.contains("training") ||
            normalized.contains("workout") ||
            normalized.contains("ride") ||
            normalized.contains("run") ||
            normalized.contains("трениров") ||
            normalized.contains("нагруз") ||
            normalized.contains("темп") {
            signals.insert("activity")
        }

        if normalized.contains("readiness") ||
            normalized.contains("готовност") ||
            normalized.contains("ceiling") ||
            normalized.contains("потолок") {
            signals.insert("readiness")
        }

        if normalized.contains("fuel") ||
            normalized.contains("food") ||
            normalized.contains("nutrition") ||
            normalized.contains("питан") ||
            normalized.contains("энерг") {
            signals.insert("fuel")
        }

        if normalized.contains("hydration") ||
            normalized.contains("water") ||
            normalized.contains("fluid") ||
            normalized.contains("гидратац") ||
            normalized.contains("вод") {
            signals.insert("hydration")
        }

        if normalized.contains("tomorrow") ||
            normalized.contains("завтра") {
            signals.insert("tomorrow")
        }

        return signals
    }

    private struct CoachHeroCopy {
        let read: String
        let recommendation: String
        let risk: String
        let showRead: Bool
        let showRisk: Bool
    }

    private func coachHeroCopy(
        story: CoachScreenStory?,
        presentation: CoachScreenPresentation?
    ) -> CoachHeroCopy {
        if let v6 = coachV6Presentation {
            let read = v6.assessment.trimmingCharacters(in: .whitespacesAndNewlines)
            let recommendation = v6.recommendation.trimmingCharacters(in: .whitespacesAndNewlines)
            let risk = v6.avoid.trimmingCharacters(in: .whitespacesAndNewlines)
            return CoachHeroCopy(
                read: v6.assessment,
                recommendation: v6.recommendation,
                risk: v6.avoid,
                showRead: !read.isEmpty,
                showRisk: !risk.isEmpty
            )
        }

        let renderedTitle = coachRenderedTitle
        let read = coachCoordinator.state.coachPresentation?.message
            ?? finalStoryRenderModel?.displaySubtitle
            ?? coachUniqueHeroText(
                coachOneStoryHeroText(
                    presentation?.message ?? story?.myRead ?? coachHeroReadFallback,
                    role: .assessment,
                    fallback: coachHeroReadFallback
                ),
                fallback: coachHeroReadFallback,
                avoiding: [coachDisplayStateLabel, renderedTitle]
            )
        let recommendation = coachCoordinator.state.coachPresentation?.recommendation
            ?? finalStoryRenderModel?.primaryRecommendation
            ?? coachUniqueHeroText(
                coachOneStoryHeroText(
                    presentation?.recommendation ?? canonicalRecommendationText ?? story?.myRecommendation ?? coachHeroRecommendationFallback,
                    role: .recommendation,
                    fallback: coachHeroRecommendationFallback
                ),
                fallback: coachHeroRecommendationFallback,
                avoiding: [coachDisplayStateLabel, renderedTitle, read]
            )
        let risk = finalStoryRenderModel?.displayAvoid ?? coachUniqueHeroText(
            coachOneStoryHeroText(
                presentation?.avoidNotes.first ?? story?.beCarefulWith ?? coachHeroRiskFallback,
                role: .caution,
                fallback: coachHeroRiskFallback
            ),
            fallback: coachHeroRiskFallback,
            avoiding: [coachDisplayStateLabel, renderedTitle, read, recommendation]
        )
        let showRisk = finalStoryRenderModel != nil
            ? !risk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : (presentation?.avoidNotes.isEmpty == false || story?.shouldShowBeCarefulWith == true)
        let showRead = !read.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return CoachHeroCopy(
            read: read,
            recommendation: recommendation,
            risk: risk,
            showRead: showRead,
            showRisk: showRisk
        )
    }

    private func coachUniqueHeroText(
        _ text: String,
        fallback: String,
        avoiding higherPriorityTexts: [String]
    ) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        if higherPriorityTexts.contains(where: { coachCopiesOverlap(trimmed, $0) }) {
            return fallback
        }

        if guidance.priority.focus == .dailyOverview,
           coachNormalizedCopy(trimmed).contains("сегодня все идет по плану") {
            return fallback
        }

        if guidance.priority.focus == .activeActivity,
           coachNormalizedCopy(trimmed).contains("сегодня лучше держать нагрузку ниже привычного максимума") {
            return fallback
        }

        return trimmed
    }

    private func coachCopiesOverlap(_ lhs: String, _ rhs: String) -> Bool {
        let left = coachNormalizedCopy(lhs)
        let right = coachNormalizedCopy(rhs)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left == right
    }

    private func coachNormalizedCopy(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var coachHeroStateFallback: String {
        switch guidance.priority.focus {
        case .activeActivity:
            return "ТРЕНИРОВКА"

        case .prepareForActivity, .nextActivityLater:
            return "ПОДГОТОВКА"

        case .performanceReadiness:
            return "ГОТОВ К НАГРУЗКЕ"

        case .postActivityRecovery:
            return "ПОСЛЕ НАГРУЗКИ"

        case .recoveryNeeded:
            return "ВОССТАНОВЛЕНИЕ"

        case .hydrationBehind:
            return "НУЖНА ВОДА"

        case .fuelBehind:
            return "НУЖНА ЭНЕРГИЯ"

        case .trainingReadinessWarning:
            return "СБАВЬТЕ ТЕМП"

        case .tomorrowPlanRisk:
            return "ЗАВТРА ВАЖНО"

        case .dailyOverview:
            return "ВСЕ ПО ПЛАНУ"

        case .eveningWindDown:
            return "ВЕЧЕРНИЙ РЕЖИМ"
        }
    }

    private var coachHeroTitleFallback: String {
        switch guidance.priority.focus {
        case .activeActivity:
            return "Не гонитесь за цифрами"

        case .prepareForActivity, .nextActivityLater:
            return "Готовьтесь к следующей активности"

        case .performanceReadiness:
            return "Сегодня многое зависит от восстановления"

        case .postActivityRecovery:
            return "Хорошая работа — теперь восстановитесь"

        case .recoveryNeeded:
            return "Сегодня лучше восстановиться"

        case .hydrationBehind:
            return "Организму нужна вода"

        case .fuelBehind:
            return "Пора восполнить энергию"

        case .trainingReadinessWarning:
            return "Не давите сильнее, чем нужно"

        case .tomorrowPlanRisk:
            return "Поберегите силы на завтра"

        case .dailyOverview:
            return "Сегодня нет причин менять план"

        case .eveningWindDown:
            return "Пора замедлиться"
        }
    }

    private var coachHeroReadFallback: String {
        switch guidance.priority.focus {

        case .activeActivity:
            return "Сегодняшняя тренировка уже создает достаточную нагрузку."

        case .prepareForActivity, .nextActivityLater:
            return "До следующей активности есть время. Вода, питание и спокойная подготовка сейчас важнее всего."

        case .performanceReadiness:
            return "Сегодняшняя готовность выглядит неплохо, но начните спокойно и дайте телу войти в ритм."

        case .postActivityRecovery:
            return "Главная тренировка уже сделана. Сейчас больше пользы даст восстановление, а не новая нагрузка."

        case .recoveryNeeded:
            return "Организму нужно чуть больше времени. Не всегда нужно делать больше — иногда лучше сделать меньше."

        case .hydrationBehind:
            return "Воды пока недостаточно. Небольшой запас гидратации поможет чувствовать себя лучше до конца дня."

        case .fuelBehind:
            return "Организму нужно немного энергии для восстановления и обычной активности."

        case .trainingReadinessWarning:
            return "Сегодня лучше не форсировать. Спокойный подход даст больше пользы, чем попытка выжать максимум."

        case .tomorrowPlanRisk:
            return "Сохраните часть энергии на завтра. Следующий день выиграет от более аккуратного темпа сегодня."

        case .dailyOverview:
            return "Сон, нагрузка, вода и питание не дают срочного сигнала для коррекции."

        case .eveningWindDown:
            return "Лучшее, что можно сделать сейчас — спокойно завершить день и подготовиться ко сну."
        }
    }

    private var coachHeroRecommendationFallback: String {
        switch guidance.priority.focus {

        case .activeActivity:
            return "Сохраняйте комфортный темп до конца тренировки."

        case .prepareForActivity, .nextActivityLater:
            return "Добавьте воды, при необходимости перекусите и начинайте без спешки."

        case .performanceReadiness:
            return "Начните спокойно и повышайте нагрузку только если чувствуете себя хорошо."

        case .postActivityRecovery:
            return "Восполните воду, нормально поешьте и дайте организму восстановиться."

        case .recoveryNeeded:
            return "Сегодня лучше восстановиться, а не добавлять нагрузку."

        case .hydrationBehind:
            return "Постепенно восполняйте воду в течение дня."

        case .fuelBehind:
            return "Добавьте полноценный прием пищи или небольшой перекус."

        case .trainingReadinessWarning:
            return "Снизьте ожидания от тренировки и ориентируйтесь на самочувствие."

        case .tomorrowPlanRisk:
            return "Сохраните немного энергии сегодня, чтобы чувствовать себя лучше завтра."

        case .dailyOverview:
            return "Следуйте своему плану и не добавляйте лишнюю нагрузку."

        case .eveningWindDown:
            return "Замедлитесь, отключитесь от дел и готовьтесь ко сну."
        }
    }

    private var coachHeroRiskFallback: String {
        switch guidance.priority.focus {

        case .activeActivity:
            return "Не пытайтесь добавить темп, если усилие уже ощущается высоким."

        case .prepareForActivity, .nextActivityLater:
            return "Не начинайте слишком быстро — организму может понадобиться немного больше времени на подготовку."

        case .performanceReadiness:
            return "Не делайте первые минуты проверкой своих пределов."

        case .postActivityRecovery:
            return "Не ищите дополнительную нагрузку после уже выполненной тренировки."

        case .recoveryNeeded:
            return "Не путайте усталость с необходимостью сделать ещё больше."

        case .hydrationBehind:
            return "Не пытайтесь восполнить всю воду за один раз."

        case .fuelBehind:
            return "Не ждите сильного чувства голода, чтобы поесть."

        case .trainingReadinessWarning:
            return "Не игнорируйте сигналы усталости ради запланированной интенсивности."

        case .tomorrowPlanRisk:
            return "Не расходуйте сегодня энергию, которая понадобится завтра."

        case .dailyOverview:
            return "Не усложняйте день без веской причины."

        case .eveningWindDown:
            return "Не затягивайте вечер активностями, которые могут помешать сну."
        }
    }

    private func coachFallbackActionTitle(for type: CoachSupportActionTypeV3) -> String {
        switch type {
        case .lightFueling:
            return "Перекусите"

        case .hydrateBeforeSession:
            return "Пейте воду"

        case .breathingReset:
            return "Подышите глубже"

        case .mobilityPrep:
            return "Разомнитесь"

        case .keepDigestionLight:
            return "Не переедайте"

        case .cooldown:
            return "Восстанавливайтесь"

        case .controlIntensity:
            return "Не форсируйте"

        case .sustainEnergy:
            return "Поддержите энергию"

        case .recoveryMeal:
            return "Поешьте"

        case .steadyHydration:
            return "Продолжайте пить"

        case .lightRecoveryMovement:
            return "Легко подвигайтесь"

        case .downshiftNervousSystem:
            return "Замедлитесь"

        case .sleepPriority:
            return "Готовьтесь ко сну"

        case .stayConsistent:
            return "Держите ритм"

        case .rehydrateGradually:
            return "Восполняйте воду"

        case .startRecoveryNutrition:
            return "Начните восстановление"

        case .electrolyteRecovery:
            return "Добавьте электролиты"
        }
    }

    private var stateBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: coachIcon)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(heroSemanticColor)

            Text(coachDisplayStateLabel)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(heroSemanticColor)
        }
        .padding(.horizontal, 11)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(heroSemanticColor.opacity(0.09))
                .overlay(
                    Capsule()
                        .stroke(heroSemanticColor.opacity(0.22), lineWidth: 1)
                )
        )
    }

    // MARK: - Today Balance

    private struct TodayBalanceItem: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        let color: Color
        let isGood: Bool
    }
    
    private func expectedHydrationProgress(hour: Int) -> Double {

        switch hour {
        case 5..<9:
            return 0.15

        case 9..<12:
            return 0.35

        case 12..<15:
            return 0.55

        case 15..<18:
            return 0.70

        case 18..<21:
            return 0.85

        default:
            return 1.0
        }
    }

    private var todayBalanceItems: [TodayBalanceItem] {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)

        let waterGoal = nutritionViewModel.nutritionResult?.goals.waterLiters ?? 3.0
        let currentWater = nutritionViewModel.totalWaterLiters
        
        let waterRatio = waterGoal > 0 ? currentWater / waterGoal : 0
        let expectedRatio = expectedHydrationProgress(hour: hour)

        let hydrationGood =
            waterRatio >= expectedRatio * 0.9
        
        let waterRemaining = max(0, waterGoal - currentWater)

        let protein = nutritionViewModel.currentMetrics?.protein ?? 0
        let proteinGoal = nutritionViewModel.nutritionResult?.goals.protein ?? 140
        let proteinRatio = proteinGoal > 0 ? protein / proteinGoal : 0
        let proteinRemaining = max(0, proteinGoal - protein)

        let calories = nutritionViewModel.currentMetrics?.calories ?? 0
        let calorieGoal = nutritionViewModel.nutritionResult?.goals.calories ?? 2200
        let calorieRatio = calorieGoal > 0 ? calories / calorieGoal : 0
        let caloriesRemaining = max(0, calorieGoal - calories)

        let fuelingGood = proteinRatio >= 0.65 || calorieRatio >= 0.45

        let recoveryPercent = healthManager.recoveryPercent
        let sleepHours = healthManager.sleepHours
        let hrv = healthManager.hrvSDNN
        let rhr = healthManager.restingHeartRate

        let hasSleepData = sleepHours > 0
        let hasRecoveryData = hasTodayRecoverySignals
        let shortSleep = hasSleepData && sleepHours < 7
        let recoveryGood = recoveryPercent >= 80
        let recoveryOkay = recoveryPercent >= 65
        let recoveryIsGood = recoveryGood || recoveryOkay

        let completedActivities = plannedActivitiesForSelectedDate.filter { $0.isCompleted }.count
        let upcomingActivities = plannedActivitiesForSelectedDate.filter {
            !$0.isCompleted && !$0.isSkipped && $0.date >= now
        }.count

        let nextActivity = plannedActivitiesForSelectedDate
            .filter { !$0.isCompleted && !$0.isSkipped && $0.date >= now }
            .sorted { $0.date < $1.date }
            .first

        let hasActivityToday = !plannedActivitiesForSelectedDate.isEmpty

        let recoverySubtitle: String = {
            if !hasRecoveryData {
                return shouldShowHealthConnectPrompt
                    ? WeekFitLocalizedString("coach.status.recovery.limited")
                    : WeekFitLocalizedString("coach.status.recovery.sleepSyncPending")
            }

            if !hasSleepData {
                if hrv > 0 && rhr > 0 {
                    return String(format: WeekFitLocalizedString("coach.status.recovery.hrvRhrFormat"), Int(recoveryPercent), Int(hrv), Int(rhr))
                }

                if recoveryPercent > 0 {
                    return String(format: WeekFitLocalizedString("coach.status.recovery.sleepMissingFormat"), Int(recoveryPercent))
                }
                return WeekFitLocalizedString("coach.status.recovery.sleepSyncPending")
            }

            if recoveryGood && shortSleep {
                return String(format: WeekFitLocalizedString("coach.status.recovery.shortSleepLimitedFormat"), Int(recoveryPercent))
            }

            if recoveryGood {
                return String(format: WeekFitLocalizedString("coach.status.recovery.readyFormat"), Int(recoveryPercent))
            }

            if recoveryOkay && shortSleep {
                return String(format: WeekFitLocalizedString("coach.status.recovery.shortSleepNotedFormat"), Int(recoveryPercent))
            }

            if recoveryPercent < 65 && shortSleep {
                return String(format: WeekFitLocalizedString("coach.status.recovery.sleepLimitingFormat"), Int(recoveryPercent))
            }

            if hrv > 0 && rhr > 0 {
                return String(format: WeekFitLocalizedString("coach.status.recovery.hrvRhrFormat"), Int(recoveryPercent), Int(hrv), Int(rhr))
            }

            return String(format: WeekFitLocalizedString("coach.status.recovery.todayFormat"), Int(recoveryPercent))
        }()

        let hydrationSubtitle: String = {
            if waterGoal <= 0 {
                return String(format: WeekFitLocalizedString("coach.status.hydration.loggedFormat"), oneDecimal(currentWater))
            }

            if currentWater <= 0.01 {
                return WeekFitLocalizedString("coach.status.hydration.notStarted")
            }

            if hydrationGood {
                return String(format: WeekFitLocalizedString("coach.status.hydration.completedFormat"), oneDecimal(currentWater), oneDecimal(waterGoal))
            }

            if hour < 12 {
                return String(format: WeekFitLocalizedString("coach.status.hydration.morningLoggedFormat"), oneDecimal(currentWater))
            }

            return String(format: WeekFitLocalizedString("coach.status.hydration.remainingFormat"), oneDecimal(waterRemaining))
        }()

        let fuelingSubtitle: String = {
            if protein <= 0.5 && calories <= 20 {
                if hour < 12 {
                    return WeekFitLocalizedString("coach.status.fueling.breakfastNotStarted")
                }
                return WeekFitLocalizedString("coach.status.fueling.noneLogged")
            }

            if proteinRatio < 0.65 && calorieRatio < 0.45 {
                return String(format: WeekFitLocalizedString("coach.status.fueling.proteinCaloriesLeftFormat"), Int(proteinRemaining), Int(caloriesRemaining))
            }

            if proteinRatio < 0.65 {
                return String(format: WeekFitLocalizedString("coach.status.fueling.proteinRemainingFormat"), Int(proteinRemaining))
            }

            if calorieRatio < 0.45 {
                return String(format: WeekFitLocalizedString("coach.status.fueling.caloriesRemainingFormat"), Int(caloriesRemaining))
            }

            return String(format: WeekFitLocalizedString("coach.status.fueling.proteinReachedFormat"), Int(protein), Int(proteinGoal))
        }()

        let loadSubtitle: String = {
            if let nextActivity {
                return String(format: WeekFitLocalizedString("coach.status.load.nextActivityFormat"), completedActivities, WeekFitCoachRuntimeLocalizedString(nextActivity.title), timeUntil(nextActivity.date))
            }

            if !hasActivityToday {
                return WeekFitLocalizedString("coach.status.load.openSchedule")
            }

            return String(format: WeekFitLocalizedString("coach.status.load.completedUpcomingFormat"), completedActivities, upcomingActivities)
        }()

        return [
            TodayBalanceItem(
                id: "recovery",
                icon: recoveryIsGood ? "heart.fill" : "heart.text.square.fill",
                title: WeekFitLocalizedString("today.status.recovery"),
                subtitle: recoverySubtitle,
                color: recoveryIsGood ? CoachPalette.recovery : CoachPalette.warning,
                isGood: recoveryIsGood
            ),

            TodayBalanceItem(
                id: "load",
                icon: hasActivityToday ? "figure.run" : "waveform.path.ecg",
                title: hasActivityToday ? WeekFitLocalizedString("coach.status.load.activities") : WeekFitLocalizedString("coach.status.load.dailyLoad"),
                subtitle: loadSubtitle,
                color: hasActivityToday ? CoachPalette.training : CoachPalette.stable,
                isGood: true
            )
        ]
    }
    
    private var coachDisplayText: (title: String, message: String) {
        return (
            finalStoryRenderModel?.title ?? coachCoordinator.state.coachPresentation?.title ?? coachScreenStory.title,
            finalStoryRenderModel?.subtitle ?? coachCoordinator.state.coachPresentation?.message ?? coachScreenStory.myRecommendation
        )
    }

    private var coachDisplayStateLabel: String {
        if let v6 = coachV6Presentation {
            return v6.statusLabel.uppercased()
        }

        if let finalStoryRenderModel {
            return finalStoryRenderModel.badge.uppercased()
        }

        // Compatibility fallback only. When CoachFinalStory exists, badge text is finalStory.badgeState.
        let localized = coachLocalizedGeneratedText(
            coachCoordinator.state.coachPresentation?.stateLabel ?? coachScreenStory.stateLabel,
            fallback: coachHeroStateFallback
        )

        if shouldUseShortCoachStateFallback(localized) {
            return coachHeroStateFallback
        }

        return localized.uppercased()
    }

    private func shouldUseShortCoachStateFallback(_ stateLabel: String) -> Bool {
        let trimmed = stateLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        if trimmed.split(separator: " ").count > 3 {
            return true
        }

        let normalized = coachNormalizedCopy(trimmed)
        if normalized.contains("сегодня все идет по плану") ||
            normalized.contains("продолжайте") ||
            normalized.contains("сделайте") ||
            normalized.contains("снизьте") {
            return true
        }

        return false
    }

    private var canonicalRecommendationText: String? {
        guard finalStoryRenderModel == nil else { return nil }
        guard let presentation = coachCoordinator.state.coachPresentation else { return nil }

        switch guidance.priority.focus {
        case .recoveryNeeded, .postActivityRecovery:
            return WeekFitLocalizedString("coach.recommendation.recoveryBeforeLoad")
        case .hydrationBehind:
            return WeekFitLocalizedString("coach.recommendation.hydrationBeforeMore")
        case .fuelBehind:
            return WeekFitLocalizedString("coach.recommendation.fuelBeforeIntensity")
        default:
            return nil
        }
    }

    private var coachSections: [CoachSection] {
        guard finalStoryRenderModel == nil else { return [] }

        // Compatibility fallback only. Final-story support is rendered by storySupportSection.
        return CoachSectionBuilder.build(
            scenario: coachScenario,
            nutrition: nutritionContext,
            trainingFallback: trainingFocusFallback,
            coachAccentColor: heroSemanticColor,
            priority: guidance.priority
        )
    }

    private var trainingFocusFallback: [String] {
        guard finalStoryRenderModel == nil else { return [] }

        // Compatibility fallback only. Final-story actions come from CoachFinalStory.primaryAction.
        let items = guidance.supportActions
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !items.isEmpty {
            return Array(items.prefix(3))
        }

        let ruleItems = coachRule.supportFocus
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !ruleItems.isEmpty {
            return Array(ruleItems.prefix(3))
        }

        return [
            WeekFitLocalizedString("coach.fallback.staySteady"),
            WeekFitLocalizedString("coach.fallback.keepPlanSimple"),
            WeekFitLocalizedString("coach.fallback.avoidUnnecessaryIntensity")
        ]
    }

    private var premiumAvoidNotes: [String] {
        if let finalStoryRenderModel {
            let avoid = finalStoryRenderModel.avoidRecommendation.trimmingCharacters(in: .whitespacesAndNewlines)
            return avoid.isEmpty ? [] : [avoid]
        }

        // Compatibility fallback only. Final-story avoid text comes from CoachFinalStory.avoidRecommendation.
        let whyText = guidance.priority.whyThisMatters?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return guidance.avoidNotes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { note in
                guard let whyText else { return true }
                return note.lowercased() != whyText
            }
            .map {
                coachLocalizedGeneratedText(
                    $0,
                    fallback: WeekFitLocalizedString("coach.fallback.avoidUnnecessaryIntensity")
                )
            }
    }

    private var shouldSurfaceCoach: Bool {
        coachCoordinator.state.hasValidGuidance
    }

    private var coachDayContext: CoachDayActivityContext {
        screenViewModel.coachDayContext(
            selectedDate: screenViewModel.selectedDate,
            allPlannedActivities: plannedActivities,
            brain: nutritionViewModel.coachMetricsSnapshot?.brain
        )
    }

    private var effectiveCoachPhase: CoachActivityPhaseV3 {
        guidance.phase
    }

    private func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func timeUntil(_ date: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSince(Date()) / 60))

        if minutes < 60 {
            return String(format: WeekFitLocalizedString("common.duration.minutesShortFormat"), minutes)
        }

        let hours = minutes / 60
        let remainder = minutes % 60

        if remainder == 0 {
            return String(format: WeekFitLocalizedString("common.duration.hoursShortFormat"), hours)
        }

        return String(format: WeekFitLocalizedString("common.duration.hoursMinutesShortFormat"), hours, remainder)
    }
    
    private var coachContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .center, spacing: WeekFitScreenLayout.rootSpacing) {

//                if shouldShowEveningReview {
//                    CoachEveningReviewSection(
//                        summary: eveningReviewSummary,
//                        plan: eveningReviewPlan,
//                        readiness: tomorrowReadiness
//                    )
//                } else
                if shouldSurfaceCoach {
                    #if DEBUG
                    coachV6IntegrationDebugBanner
                    #endif
                    coachCard
                    storySupportSection
                } else {
                    coachUnavailableSection
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, coachContentHorizontalInset)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 110)
        }
    }

    private var coachUnavailableSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(textSecondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.05)))

            VStack(alignment: .leading, spacing: 4) {
                Text(WeekFitLocalizedString(shouldShowHealthConnectPrompt ? "coach.unavailable.title" : "coach.unavailable.sleepSync.title"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(WeekFitLocalizedString(shouldShowHealthConnectPrompt ? "coach.unavailable.message" : "coach.unavailable.sleepSync.message"))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(cardBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var shouldShowEveningReview: Bool {
        let now = Date()
        let calendar = Calendar.current

        let hour = calendar.component(.hour, from: now)
        guard hour >= 23 else { return false }

        guard let lastPlannedActivity = reviewRelevantActivities.max(by: {
            $0.date < $1.date
        }) else {
            return true
        }

        let lastActivityEnd = calendar.date(
            byAdding: .minute,
            value: lastPlannedActivity.durationMinutes + 15,
            to: lastPlannedActivity.date
        ) ?? lastPlannedActivity.date

        guard now >= lastActivityEnd else { return false }

        return !hasUnresolvedActivities
    }
    
    private var reviewRelevantActivities: [PlannedActivity] {
        plannedActivitiesForSelectedDate.filter { activity in
            activity.source != "today" &&
            activity.imageName != "hydration"
        }
    }
    
    private var hasUnresolvedActivities: Bool {
        reviewRelevantActivities.contains { activity in
            !activity.isCompleted &&
            !activity.isSkipped
        }
    }

    private var eveningReviewSummary: CoachEveningReviewSummary {

        let plannerActivities = plannedActivitiesForSelectedDate.filter {
            $0.source == "planner"
        }

        let completedPlannerActivities = plannerActivities.filter {
            $0.isCompleted
        }

        let skippedPlannerActivities = plannerActivities.filter {
            $0.isSkipped
        }

        let completedActivities = plannedActivitiesForSelectedDate.filter {
            $0.isCompleted
        }

        let plannedCount = plannerActivities.count
        let completedCount = completedPlannerActivities.count
        let skippedCount = skippedPlannerActivities.count

        let totalMinutes = completedActivities.reduce(0) { result, activity in
            result + activity.durationMinutes
        }

        let activeTimeText = formatMinutes(totalMinutes)
        let score = eveningReviewScore

        if plannedCount == 0 {
            return CoachEveningReviewSummary(
                title: totalMinutes > 0 ? WeekFitLocalizedString("coach.activeRecoveryDay") : WeekFitLocalizedString("coach.recoveryDay"),
                message: totalMinutes > 0
                    ? String(format: WeekFitLocalizedString("coach.evening.activeTimeFormat"), activeTimeText)
                    : WeekFitLocalizedString("coach.eveningReview.noPlannedActivities"),
                achievement: biggestAchievementText,
                score: score
            )
        }

        if completedCount == plannedCount && skippedCount == 0 {
            return CoachEveningReviewSummary(
                title: WeekFitLocalizedString("coach.perfectExecution"),
                message: String(format: WeekFitLocalizedString("coach.evening.activeTimeFormat"), activeTimeText),
                achievement: biggestAchievementText,
                score: score
            )
        }

        if completedCount > 0 {
            return CoachEveningReviewSummary(
                title: WeekFitLocalizedString("coach.solidExecution"),
                message: String(format: WeekFitLocalizedString("coach.evening.activeTimeFormat"), activeTimeText),
                achievement: biggestAchievementText,
                score: score
            )
        }

        return CoachEveningReviewSummary(
            title: WeekFitLocalizedString("coach.resetTomorrow"),
            message: totalMinutes > 0
                ? String(format: WeekFitLocalizedString("coach.evening.activeTimeFormat"), activeTimeText)
                : WeekFitLocalizedString("coach.evening.noActiveTimeLogged"),
            achievement: biggestAchievementText,
            score: score
        )
    }
    
    private func formatMinutes(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return String(format: WeekFitLocalizedString("common.duration.hoursMinutesShortFormat"), hours, minutes)
        }

        if hours > 0 {
            return String(format: WeekFitLocalizedString("common.duration.hoursShortFormat"), hours)
        }

        return String(format: WeekFitLocalizedString("common.duration.minutesShortFormat"), minutes)
    }

    private var eveningReviewScore: Int {

        let plannerActivities = plannedActivitiesForSelectedDate.filter {
            $0.source == "planner"
        }

        let plannedCount = plannerActivities.count

        let completedCount = plannerActivities.filter {
            $0.isCompleted
        }.count

        // PLAN

        let planScore: Double

        if plannedCount == 0 {
            planScore = 100
        } else {
            planScore = Double(completedCount) / Double(plannedCount) * 100
        }

        // BURN

        let baseTargetCalories: Double =
            nutritionViewModel.nutritionResult?.targetCalories ?? 1743

        let activeCaloriesBurned: Double =
            healthManager.activeCalories

        let burnScore = min(
            100,
            activeCaloriesBurned / max(baseTargetCalories * 0.35, 1) * 100
        )

        // NUTRITION

        let nutritionBudget = NutritionBudgetCalculator.make(
            from: nutritionViewModel.nutritionResult,
            consumed: nutritionViewModel.currentMetrics?.calories ?? 0
        )

        let nutritionRatio =
            nutritionBudget.totalCalories > 0
            ? nutritionBudget.progressRatio
            : 1

        let nutritionScore: Double

        switch nutritionRatio {

        case 0.90...1.10:
            nutritionScore = 100

        case 0.80..<0.90, 1.10...1.20:
            nutritionScore = 80

        case 0.70..<0.80, 1.20...1.35:
            nutritionScore = 60

        default:
            nutritionScore = 30
        }

        let score =
            planScore * 0.40 +
            burnScore * 0.35 +
            nutritionScore * 0.25

        return max(0, min(100, Int(score.rounded())))
    }
    
    private var eveningReviewActiveTimeText: String {

        let completedActivities = plannedActivitiesForSelectedDate.filter {
            $0.isCompleted
        }

        let totalMinutes = completedActivities.reduce(0) { result, activity in
            result + activity.durationMinutes
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        return formatMinutes(totalMinutes)
    }

    private var tomorrowReadiness: CoachTomorrowReadiness {
        let completed = plannedActivitiesForSelectedDate.filter { $0.isCompleted }

        let totalMinutes = completed.reduce(0) { result, activity in
            result + activity.durationMinutes
        }

        let recovery = healthManager.recoveryPercent

        let longest = completed.max {
            $0.durationMinutes < $1.durationMinutes
        }

        let longestTitle = longest.map { WeekFitCoachRuntimeLocalizedString($0.title) } ?? WeekFitLocalizedString("coach.activity.fallbackTitle")
        let longestDuration = longest.map { formatMinutes($0.effectiveDurationMinutes) } ?? formatMinutes(0)

        let hasLongSession = longest?.durationMinutes ?? 0 >= 120
        let hasVeryHighVolume = totalMinutes >= 240
        let hasHighVolume = totalMinutes >= 150

        let recoveryActivities = completed.filter { activity in
            let text = "\(activity.type) \(activity.title)".lowercased()

            return text.contains("sauna")
                || text.contains("stretch")
                || text.contains("mobility")
                || text.contains("recovery")
                || text.contains("walk")
                || text.contains("walking")
                || text.contains("yoga")
        }

        let hasRecoverySupport = !recoveryActivities.isEmpty

        let loadLabel: String = {
            if hasVeryHighVolume || hasLongSession {
                return WeekFitLocalizedString("coach.highLoad")
            }

            if hasHighVolume {
                return WeekFitLocalizedString("coach.moderateLoad")
            }

            return WeekFitLocalizedString("coach.balancedLoad")
        }()

        let metricsLine: String = {
            if let longest {
                return String(format: WeekFitLocalizedString("coach.tomorrow.metrics.recoveryActivityFormat"), Int(recovery), WeekFitCoachRuntimeLocalizedString(longest.title), formatMinutes(longest.effectiveDurationMinutes))
            }

            return String(format: WeekFitLocalizedString("coach.tomorrow.metrics.recoveryLoadFormat"), Int(recovery), loadLabel)
        }()

        if recovery < 55 {
            return CoachTomorrowReadiness(
                title: WeekFitLocalizedString("coach.recoveryDayRecommended"),
                metrics: metricsLine,
                recommendation: WeekFitLocalizedString("coach.tomorrow.recommendation.sleepMobilityWalk"),
                icon: "moon.zzz.fill",
                color: CoachPalette.stress
            )
        }

        if hasVeryHighVolume || hasLongSession {
            if recovery >= 75 {
                return CoachTomorrowReadiness(
                    title: WeekFitLocalizedString("coach.keepTomorrowLighter"),
                    metrics: String(format: WeekFitLocalizedString("coach.tomorrow.metrics.recoveryActivityFormat"), Int(recovery), longestTitle, longestDuration),
                    recommendation: WeekFitLocalizedString("coach.tomorrow.recommendation.saunaMobilityWalk"),
                    icon: "figure.cooldown",
                    color: CoachPalette.warning
                )
            } else {
                return CoachTomorrowReadiness(
                    title: WeekFitLocalizedString("coach.prioritizeRecoveryTomorrow"),
                    metrics: String(format: WeekFitLocalizedString("coach.tomorrow.metrics.recoveryLoadFormat"), Int(recovery), loadLabel),
                    recommendation: WeekFitLocalizedString("coach.tomorrow.recommendation.sleepMobilityWalk"),
                    icon: "heart.fill",
                    color: CoachPalette.warning
                )
            }
        }

        if hasHighVolume && !hasRecoverySupport {
            return CoachTomorrowReadiness(
                title: WeekFitLocalizedString("coach.addRecoverySupport"),
                metrics: String(format: WeekFitLocalizedString("coach.tomorrow.metrics.recoveryLoadFormat"), Int(recovery), loadLabel),
                recommendation: WeekFitLocalizedString("coach.tomorrow.recommendation.saunaStretchingWalk"),
                icon: "sparkles",
                color: CoachPalette.recovery
            )
        }

        if recovery >= 75 {
            return CoachTomorrowReadiness(
                title: WeekFitLocalizedString("coach.readyForTraining"),
                metrics: String(format: WeekFitLocalizedString("coach.tomorrow.metrics.recoveryLoadFormat"), Int(recovery), loadLabel),
                recommendation: WeekFitLocalizedString("coach.tomorrow.recommendation.normalTraining"),
                icon: "checkmark.seal.fill",
                color: CoachPalette.stable
            )
        }

        return CoachTomorrowReadiness(
            title: WeekFitLocalizedString("coach.moderateReadiness"),
            metrics: String(format: WeekFitLocalizedString("coach.tomorrow.metrics.recoveryLoadFormat"), Int(recovery), loadLabel),
            recommendation: WeekFitLocalizedString("coach.tomorrow.recommendation.flexiblePlan"),
            icon: "gauge.medium",
            color: CoachPalette.training
        )
    }
    
    private var biggestAchievementText: String {

        let completed = plannedActivitiesForSelectedDate.filter { $0.isCompleted }

        let meaningfulCompleted = completed.filter {
            let type = $0.type.lowercased()
            let title = $0.title.lowercased()

            return type != "meal"
                && $0.imageName != "hydration"
                && !title.contains("water")
                && !title.contains("hydration")
                && $0.durationMinutes >= 20
        }

        if let best = meaningfulCompleted.max(by: {
            achievementScore(for: $0) < achievementScore(for: $1)
        }) {
            return String(format: WeekFitLocalizedString("coach.evening.achievement.completedFormat"), achievementLabel(for: best), durationText(best.durationMinutes))
        }

        let planned = plannedActivitiesForSelectedDate.count
        let completedCount = completed.count
        let skippedCount = plannedActivitiesForSelectedDate.filter { $0.isSkipped }.count

        if planned > 0 && completedCount == planned {
            return WeekFitLocalizedString("coach.youCompletedEverythingYouPlannedToday")
        }

        if planned > 0 && completedCount + skippedCount == planned {
            return WeekFitLocalizedString("coach.evening.closedByResolvingPlan")
        }

        let recovery = Int(healthManager.recoveryPercent)
        if recovery >= 80 {
            return String(format: WeekFitLocalizedString("coach.evening.recoveryFinishedFormat"), recovery)
        }

        if completedCount > 0 {
            return WeekFitCountPluralization.eveningPlannedCompletedPhrase(count: completedCount)
        }

        return WeekFitLocalizedString("coach.evening.closedWithoutCatchUp")
    }

    private func achievementScore(for activity: PlannedActivity) -> Double {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()

        var score = Double(activity.durationMinutes)

        if type == "workout" {
            score *= 1.6
        }

        if type == "recovery" {
            score *= 1.15
        }

        if title.contains("ride") ||
            title.contains("bike") ||
            title.contains("cycling") ||
            title.contains("run") ||
            title.contains("walk") ||
            title.contains("strength") ||
            title.contains("gym") ||
            title.contains("training") {
            score *= 1.35
        }

        if activity.durationMinutes >= 180 {
            score += 90
        } else if activity.durationMinutes >= 120 {
            score += 60
        } else if activity.durationMinutes >= 60 {
            score += 30
        }

        return score
    }

    private func achievementLabel(for activity: PlannedActivity) -> String {
        let title = WeekFitCoachRuntimeLocalizedString(activity.title).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? WeekFitLocalizedString("coach.evening.achievement.strongestActivity") : title
    }

    private func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60

        if hours > 0 && remainder > 0 {
            return String(format: WeekFitLocalizedString("common.duration.hoursMinutesShortFormat"), hours, remainder)
        }

        if hours > 0 {
            return String(format: WeekFitLocalizedString("common.duration.hoursShortFormat"), hours)
        }

        return String(format: WeekFitLocalizedString("common.duration.minutesShortFormat"), minutes)
    }

    private var nutritionContext: CoachNutritionContext {
        if let snapshot = nutritionViewModel.coachMetricsSnapshot {
            return snapshot.nutritionContext
        }

        let goals = nutritionViewModel.nutritionResult?.goals
        let completedMeals = CoachCanonicalDayState.completedMeals(from: plannedActivitiesForSelectedDate)

        return CoachNutritionContext(
            caloriesCurrent: nutritionViewModel.currentMetrics?.calories ?? 0,
            caloriesGoal: goals?.calories ?? 2200,

            proteinCurrent: nutritionViewModel.currentMetrics?.protein ?? 0,
            proteinGoal: goals?.protein ?? 140,

            carbsCurrent: nutritionViewModel.currentMetrics?.carbs ?? 0,
            carbsGoal: goals?.carbs ?? 300,

            fatsCurrent: nutritionViewModel.currentMetrics?.fats ?? 0,
            fatsGoal: goals?.fats ?? 80,

            waterCurrent: nutritionViewModel.totalWaterLiters,
            waterGoal: goals?.waterLiters ?? 3.0,

            mealsCount: completedMeals.count,
            lastMealTime: completedMeals.last?.date
        )
    }
    
    private var todayBalanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(WeekFitLocalizedString("coach.status.current.title"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(WeekFitLocalizedString("coach.status.current.subtitle"))
                    .font(.system(size: 12.2, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.62))
            }

            VStack(spacing: 8) {
                ForEach(todayBalanceItems) { item in
                    todayBalanceRow(item)
                }
            }
        }
    }

    private func todayBalanceRow(_ item: TodayBalanceItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(item.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15.2, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(item.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.72))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: item.isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(item.isGood ? green.opacity(0.85) : item.color.opacity(0.95))
        }
        .padding(.horizontal, 14)
        .frame(height: 66)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    item.isGood
                    ? LinearGradient(
                        colors: [
                            cardBackground.opacity(0.36),
                            cardBackground.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [
                            item.color.opacity(0.10),
                            cardBackground.opacity(0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    // MARK: - Suggested Support

    private var storySupportSection: some View {
        if coachV6Presentation != nil {
            let rows = coachCoordinator.state.coachPresentation?.whyRows ?? []
            return AnyView(VStack(alignment: .leading, spacing: 13) {
                if !rows.isEmpty {
                    presentationWhySection(rows)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading))
        }

        if let finalStoryRenderModel {
            return AnyView(finalStorySupportSection(finalStoryRenderModel))
        }

        // Compatibility fallback only. Final-story support must not use coachScreenStory or priority-derived rationale.
        let story = coachScreenStory
        let actions = coachCoordinator.state.coachPresentation?.supportActions ?? []

        return AnyView(VStack(alignment: .leading, spacing: 13) {
            if let rationale = coachCoordinator.state.rationalePresentation {
                rationaleSection(rationale)
            }

            if shouldShowOwnerPlanAdjustment,
               story.shouldShowPlanAdjustment,
               let planAdjustment = story.planAdjustment {
                storyInfoSection(
                    title: WeekFitLocalizedString("coach.info.planAdjustment.title"),
                    subtitle: WeekFitLocalizedString("coach.info.planAdjustment.subtitle"),
                    icon: "arrow.triangle.2.circlepath",
                    text: WeekFitCoachRuntimeLocalizedString(planAdjustment),
                    color: CoachPalette.warning
                )
            }

            if shouldShowOwnerActivityContext,
               story.shouldShowActivityContext,
               let activityContext = story.activityContext {
                storyInfoSection(
                    title: WeekFitLocalizedString("coach.info.activityContext.title"),
                    subtitle: WeekFitLocalizedString("coach.info.activityContext.subtitle"),
                    icon: "figure.mind.and.body",
                    text: WeekFitCoachRuntimeLocalizedString(activityContext),
                    color: story.color
                )
            }

            if !actions.isEmpty {
                primaryActionsSection(actions)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading))
    }

    private func finalStorySupportSection(_ renderModel: CoachFinalStoryRenderModel) -> some View {
        let presentationRows = coachCoordinator.state.coachPresentation?.whyRows ?? []
        let hasPresentationWhy = !presentationRows.isEmpty

        return VStack(alignment: .leading, spacing: 13) {
            if hasPresentationWhy {
                presentationWhySection(presentationRows)
            } else if !renderModel.whyRows.isEmpty {
                whySection(renderModel)
            }

            if !renderModel.supportActions.isEmpty {
                primaryActionsSection(renderModel.supportActions)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func presentationWhySection(_ rows: [CoachPresentationWhyRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            supportGroupHeader(
                title: WeekFitLocalizedString("coach.why"),
                subtitle: WeekFitLocalizedString("coach.why.subtitle")
            )

            VStack(spacing: 5) {
                ForEach(Array(rows.prefix(3).enumerated()), id: \.offset) { _, row in
                    coachDecisionRow(
                        row.title,
                        color: row.color,
                        icon: row.icon
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func whySection(_ renderModel: CoachFinalStoryRenderModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            supportGroupHeader(
                title: WeekFitLocalizedString("coach.why"),
                subtitle: WeekFitLocalizedString("coach.why.subtitle")
            )

            VStack(spacing: 5) {
                ForEach(Array(renderModel.whyRows.prefix(3).enumerated()), id: \.offset) { _, row in
                    coachDecisionRow(
                        row.title,
                        color: row.color,
                        icon: row.icon
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func whySection(_ signals: [CoachFinalStoryRenderedSupportSignal]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            supportGroupHeader(
                title: WeekFitLocalizedString("coach.why"),
                subtitle: WeekFitLocalizedString("coach.why.subtitle")
            )

            VStack(spacing: 5) {
                ForEach(Array(signals.prefix(3).enumerated()), id: \.offset) { _, signal in
                    coachDecisionRow(
                        signal.title,
                        color: semanticWhyColor(title: signal.title, icon: signal.icon, fallback: signal.color),
                        icon: signal.icon
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct CoachWhyRowModel {
        let title: String
        let icon: String
        let color: Color
    }

    private func whyRows(for renderModel: CoachFinalStoryRenderModel) -> [CoachWhyRowModel] {
        var rows = decisionWhyRows(for: renderModel)

        let decisionSignalKinds = decisionShapingSignalKinds(for: renderModel)
        let decisionSignals = renderModel.supportSignals.filter { decisionSignalKinds.contains($0.kind) }
        rows.append(
            contentsOf: decisionSignals.map {
                CoachWhyRowModel(title: $0.title, icon: $0.icon, color: $0.color)
            }
        )

        let fallbackCandidates = [
            (renderModel.whatMattersNow, "lightbulb.fill"),
            (renderModel.whatToAvoid, "exclamationmark.triangle.fill")
        ]

        for candidate in fallbackCandidates {
            let title = candidate.0.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            guard !rows.contains(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(title) == .orderedSame }) else {
                continue
            }

            rows.append(
                CoachWhyRowModel(
                    title: title,
                    icon: candidate.1,
                    color: renderModel.color
                )
            )
        }

        return Array(rows.prefix(3))
    }

    private func decisionWhyRows(for renderModel: CoachFinalStoryRenderModel) -> [CoachWhyRowModel] {
        switch renderModel.owner {
        case .stableOverview, .readiness:
            return [
                whyRow("Recovery looks normal", "Восстановление в норме", icon: "heart.fill", color: CoachPalette.recovery),
                whyRow("Plenty of time before the next activity", "До следующей активности достаточно времени", icon: "clock.fill", color: renderModel.color),
                whyRow("Nothing big is holding the day back", "Ничего серьёзного не мешает дню", icon: "checkmark.seal.fill", color: renderModel.color)
            ]

        case .activityPreparation:
            return [
                whyRow("The hardest workout is still ahead", "Самая тяжёлая тренировка ещё впереди", icon: "figure.run", color: renderModel.color),
                whyRow("Starting fresh helps most right now", "Сейчас лучше всего выйти свежим", icon: "figure.cooldown", color: renderModel.color),
                whyRow("A calm start usually goes better", "Спокойный старт обычно идёт лучше", icon: "speedometer", color: CoachPalette.warning)
            ]

        case .activeActivity, .pacingExecution, .sustainableExecution:
            return [
                whyRow("This session is already enough load", "Этой тренировки уже достаточно", icon: "figure.run", color: renderModel.color),
                whyRow("Holding back now saves you for later", "Сдержанность сейчас сбережёт силы на потом", icon: "speedometer", color: CoachPalette.warning),
                whyRow("You'll recover better if you finish with something left", "Восстановитесь лучше, если закончите с запасом", icon: "heart.fill", color: CoachPalette.recovery)
            ]
        case .fuelingDuringActivity:
            return [
                whyRow("Energy expenditure is already high", "Расход энергии уже высокий", icon: "flame.fill", color: CoachPalette.activity),
                whyRow("Fuel intake is behind the workload", "Питание отстаёт от тренировки", icon: "bolt.fill", color: CoachPalette.fueling)
            ]
        case .hydrationExecution:
            return [
                whyRow("Fluid intake is behind the session demand", "Воды меньше, чем требует сессия", icon: "drop.fill", color: CoachPalette.hydration),
                whyRow("The workload is long enough for hydration to affect quality", "Сессия достаточно длинная, чтобы вода влияла на качество", icon: "figure.run", color: CoachPalette.activity)
            ]

        case .postActivityRecovery, .recovery:
            return [
                whyRow("The main work is done", "Основная работа уже сделана", icon: "checkmark.circle.fill", color: renderModel.color),
                whyRow("Rest beats another hard effort", "Отдых лучше ещё одной тяжёлой тренировки", icon: "heart.fill", color: CoachPalette.recovery),
                whyRow("More intensity probably won't help", "Ещё одна интенсивность вряд ли поможет", icon: "exclamationmark.triangle.fill", color: CoachPalette.warning)
            ]

        case .tomorrowProtection:
            return [
                whyRow("Tomorrow's workout matters more", "Завтрашняя тренировка важнее", icon: "calendar", color: renderModel.color),
                whyRow("Extra load today will hurt tomorrow", "Лишнее сегодня ударит по завтра", icon: "arrow.down.heart.fill", color: CoachPalette.warning),
                whyRow("Sleep tonight sets up the next session", "Сон сегодня готовит следующую сессию", icon: "moon.fill", color: CoachPalette.recovery)
            ]

        case .hydration:
            return [
                whyRow("You're low on water", "Не хватает воды", icon: "drop.fill", color: CoachPalette.hydration),
                whyRow("The next part goes better if you drink now", "Следующая часть пойдёт лучше, если выпить сейчас", icon: "figure.run", color: renderModel.color),
                whyRow("Fixing it now avoids extra stress", "Сейчас проще, чем догонять потом", icon: "checkmark.seal.fill", color: renderModel.color)
            ]

        case .fuel:
            return [
                whyRow("You haven't eaten enough", "Мало еды", icon: "bolt.fill", color: CoachPalette.fueling),
                whyRow("The next effort needs fuel", "Следующей тренировке нужна еда", icon: "figure.run", color: renderModel.color),
                whyRow("Hard work on empty doesn't help much", "Тяжело работать на пустом желудке", icon: "exclamationmark.triangle.fill", color: CoachPalette.warning)
            ]
        }
    }

    private func decisionShapingSignalKinds(for renderModel: CoachFinalStoryRenderModel) -> Set<CoachFinalStorySupportSignal.Kind> {
        switch renderModel.owner {
        case .hydration:
            return [.hydration]
        case .fuel:
            return [.fuel]
        case .postActivityRecovery, .recovery:
            return [.recovery, .sleep]
        case .tomorrowProtection:
            return [.activity, .sleep, .recovery]
        case .activeActivity, .pacingExecution, .sustainableExecution, .activityPreparation:
            return [.activity, .recovery, .sleep]
        case .fuelingDuringActivity:
            return [.fuel, .activity, .hydration]
        case .hydrationExecution:
            return [.hydration, .activity, .fuel]
        case .readiness, .stableOverview:
            return [.recovery, .sleep, .activity]
        }
    }

    private func whyRow(
        _ english: String,
        _ russian: String,
        icon: String,
        color: Color
    ) -> CoachWhyRowModel {
        CoachWhyRowModel(
            title: WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english,
            icon: icon,
            color: color
        )
    }

    private func semanticWhyColor(for row: CoachWhyRowModel) -> Color {
        semanticWhyColor(title: row.title, icon: row.icon, fallback: row.color)
    }

    private func semanticWhyColor(
        title: String,
        icon: String,
        fallback: Color
    ) -> Color {
        let value = "\(title) \(icon)".lowercased()

        if value.contains("sleep") ||
            value.contains("сон") ||
            value.contains("moon") {
            return Color(red: 0.55, green: 0.40, blue: 0.85)
        }

        if value.contains("recovery") ||
            value.contains("восстанов") ||
            value.contains("heart") {
            return CoachPalette.recovery
        }

        if value.contains("time") ||
            value.contains("clock") ||
            value.contains("calendar") ||
            value.contains("врем") ||
            value.contains("завтра") ||
            value.contains("следующ") {
            return Color(red: 0.40, green: 0.62, blue: 0.96)
        }

        if value.contains("training") ||
            value.contains("activity") ||
            value.contains("session") ||
            value.contains("нагруз") ||
            value.contains("актив") ||
            value.contains("figure") ||
            value.contains("run") {
            return CoachPalette.stable
        }

        if value.contains("constraint") ||
            value.contains("intensity") ||
            value.contains("warning") ||
            value.contains("огранич") ||
            value.contains("интенсив") ||
            value.contains("stress") ||
            value.contains("exclamationmark") {
            return CoachPalette.warning
        }

        if value.contains("hydration") ||
            value.contains("water") ||
            value.contains("drop") ||
            value.contains("вод") {
            return CoachPalette.hydration
        }

        if value.contains("fuel") ||
            value.contains("nutrition") ||
            value.contains("energy") ||
            value.contains("питан") ||
            value.contains("энерг") ||
            value.contains("bolt") {
            return CoachPalette.fueling
        }

        if value.contains("checkmark") ||
            value.contains("shield") ||
            value.contains("seal") {
            return Color(red: 0.48, green: 0.58, blue: 0.72)
        }

        return fallback
    }

    private var shouldShowOwnerPlanAdjustment: Bool {
        switch guidance.priority.focus {
        case .tomorrowPlanRisk, .trainingReadinessWarning:
            return true
        default:
            return false
        }
    }

    private var shouldShowOwnerActivityContext: Bool {
        switch guidance.priority.focus {
        case .activeActivity, .prepareForActivity, .nextActivityLater, .performanceReadiness:
            return true
        default:
            return false
        }
    }

    private func rationaleSection(_ presentation: CoachRationalePresentation) -> some View {
        storyInfoSection(
            title: WeekFitCoachRuntimeLocalizedString(presentation.title),
            subtitle: WeekFitLocalizedString("coach.info.rationale.subtitle"),
            icon: presentation.icon,
            text: WeekFitCoachRuntimeLocalizedString(presentation.message),
            color: presentation.color
        )
    }

    private func primaryActionsSection(_ actions: [CoachSupportActionV3]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            supportGroupHeader(
                title: WeekFitLocalizedString("coach.whatToDo"),
                subtitle: WeekFitLocalizedString("coach.whatToDo.subtitle")
            )

            VStack(spacing: 5) {
                ForEach(Array(actions.prefix(3).enumerated()), id: \.offset) { _, action in
                    coachDecisionRow(
                        finalStory == nil ? coachLocalizedGeneratedText(action.title, fallback: coachFallbackActionTitle(for: action.type)) : action.title,
                        color: ActionSemanticColor.color(for: action),
                        icon: action.icon
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func supportSignalsSection(_ story: CoachScreenStory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            supportGroupHeader(
                title: WeekFitLocalizedString("coach.why"),
                subtitle: WeekFitLocalizedString("coach.why.subtitle")
            )

            VStack(spacing: 5) {
                ForEach(Array(story.supportActions.prefix(3).enumerated()), id: \.offset) { _, action in
                    coachDecisionRow(
                        coachLocalizedGeneratedText(action.title, fallback: coachFallbackActionTitle(for: action.type)),
                        color: action.color,
                        icon: action.icon
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func storyInfoSection(
        title: String,
        subtitle: String,
        icon: String,
        text: String,
        color: Color
    ) -> some View {
        coachSectionView(
            CoachSection(
                title: WeekFitCoachRuntimeLocalizedString(title),
                subtitle: WeekFitCoachRuntimeLocalizedString(subtitle),
                icon: icon,
                color: color,
                style: .info,
                items: [],
                informationalText: WeekFitCoachRuntimeLocalizedString(text)
            )
        )
    }

    private func coachSectionView(
        _ section: CoachSection
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            supportGroupHeader(
                title: WeekFitCoachRuntimeLocalizedString(section.title),
                subtitle: WeekFitCoachRuntimeLocalizedString(section.subtitle)
            )

            switch section.style {
            case .compact:
                compactSectionBody(section)

            case .cards:
                cardSectionBody(section)

            case .info:
                infoSectionBody(section)
            }
        }
    }
    
    private func infoSectionBody(
        _ section: CoachSection
    ) -> some View {

        HStack(alignment: .top, spacing: 12) {

            ZStack {
                Circle()
                    .fill(section.color.opacity(0.12))
                    .frame(width: 30, height: 30)

                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(section.color)
            }
            .padding(.top, 1)

            Text(WeekFitCoachRuntimeLocalizedString(section.informationalText ?? ""))
                .font(.system(size: 13.2, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.84))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            section.color.opacity(0.06),
                            cardBackground.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    private func compactSectionBody(
        _ section: CoachSection
    ) -> some View {
        VStack(spacing: 7) {
            ForEach(Array(section.items.prefix(3).enumerated()), id: \.offset) { _, item in
                compactSupportRow(
                    WeekFitCoachRuntimeLocalizedString(item),
                    color: section.color,
                    icon: section.icon
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            section.color.opacity(0.075),
                            cardBackground.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.045), lineWidth: 1)
                )
        )
    }

    private func cardSectionBody(
        _ section: CoachSection
    ) -> some View {
        VStack(spacing: 5) {
            ForEach(Array(section.items.prefix(3).enumerated()), id: \.offset) { _, item in
                coachFocusRow(
                    WeekFitCoachRuntimeLocalizedString(item),
                    color: section.color,
                    icon: section.icon
                )
            }
        }
    }

    private func supportGroupHeader(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            Text(subtitle)
                .font(.system(size: 12.1, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.62))
        }
    }

    private func compactSupportRow(
        _ text: String,
        color: Color,
        icon: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.13))
                    .frame(width: 26, height: 26)

                Image(systemName: compactIcon(for: text, fallback: icon))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color.opacity(0.96))
            }
            .padding(.top, 1)

            Text(text)
                .font(.system(size: 13.8, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.94))
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private func compactIcon(
        for text: String,
        fallback: String
    ) -> String {
        let value = text.lowercased()

        if value.contains("water") ||
            value.contains("drink") ||
            value.contains("sip") ||
            value.contains("fluid") ||
            value.contains("hydrate") {
            return "drop.fill"
        }

        if value.contains("electrolyte") ||
            value.contains("isotonic") ||
            value.contains("mineral") {
            return "bolt.fill"
        }

        if value.contains("banana") ||
            value.contains("bar") ||
            value.contains("gel") ||
            value.contains("snack") {
            return "takeoutbag.and.cup.and.straw.fill"
        }

        if value.contains("protein") ||
            value.contains("yogurt") ||
            value.contains("eggs") ||
            value.contains("chicken") ||
            value.contains("shake") ||
            value.contains("meal") ||
            value.contains("food") {
            return "fork.knife"
        }

        if value.contains("sleep") ||
            value.contains("calm") ||
            value.contains("stress") ||
            value.contains("nervous") {
            return "moon.stars.fill"
        }

        if value.contains("stiffness") ||
            value.contains("mobility") ||
            value.contains("circulation") ||
            value.contains("tension") {
            return "leaf.fill"
        }

        return fallback
    }

    private func coachFocusRow(
        _ text: String,
        color: Color? = nil,
        icon: String = "checkmark"
    ) -> some View {
        coachDecisionRow(
            text,
            color: color ?? coachAccentColor,
            icon: icon
        )
    }

    private func coachDecisionRow(
        _ text: String,
        color: Color,
        icon: String
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.10))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(color)
            }

            Text(text)
                .font(.system(size: 13.8, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.94))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardBackground.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.035), lineWidth: 1)
                )
        )
    }


    private var avoidNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(premiumAvoidNotes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(coachAccentColor.opacity(0.9))
                        .padding(.top, 2)

                    Text(note)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.78))
                        .lineSpacing(3)

                    Spacer()
                }
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardBackground.opacity(0.26))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    private func fastFuelRow(_ item: FastFuelItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.026))
                    .frame(width: 30, height: 30)

                if !item.imageName.isEmpty, UIImage(named: item.imageName) != nil {
                    Image(item.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .opacity(0.92)
                } else {
                    Image(systemName: item.imageName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(coachAccentColor.opacity(0.9))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15.2, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(item.reason)
                    .font(.system(size: 11.8, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.68))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()

                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    nutritionViewModel.addCoachRecommendationToPlan(
                        item: item,
                        context: modelContext
                    )
                    appSession.triggerCoachRefresh(source: "ExpertCoachViewV3.addFuelRecommendation")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WeekFitTheme.purple.opacity(0.92))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(WeekFitTheme.purple.opacity(0.065))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 15)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardBackground.opacity(0.32),
                            cardBackground.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.035), lineWidth: 1)
                )
        )
    }

    #if DEBUG
    private func debugHydrationSummary() -> String {
        if let snapshot = nutritionViewModel.coachMetricsSnapshot {
            return CoachRefreshDebug.hydrationSummary(
                current: snapshot.nutritionContext.waterCurrent,
                goal: snapshot.nutritionContext.waterGoal
            ) + " snapshot=\(snapshot.id)"
        }

        return CoachRefreshDebug.hydrationSummary(
            current: nutritionViewModel.currentMetrics?.waterLiters ?? 0,
            goal: nutritionViewModel.nutritionResult?.goals.waterLiters ?? 0
        )
    }

    private func debugCoachPrioritySummary() -> String {
        guard let output = coachCoordinator.state.guidance else { return "priority=missingCanonicalGuidance" }
        return debugCoachPrioritySummary(for: output)
    }

    private func debugCoachPrioritySummary(for output: CoachGuidanceV3) -> String {
        let presentation = coachCoordinator.state.coachPresentation
        let renderedState = presentation?.stateLabel ?? output.screenStory?.stateLabel ?? output.stateLabel
        let renderedTitle = presentation?.title ?? validTitle(output.title) ?? output.screenStory?.title ?? output.priority.detailTitle
        return "priority=\(output.priority.priority)/\(output.priority.focus) limiter=\(output.priority.limiter) strength=\(output.priority.strength) title=\"\(output.priority.todayTitle)\" renderedState=\"\(renderedState)\" renderedTitle=\"\(renderedTitle)\""
    }

    private var coachV6IntegrationDebugBanner: some View {
        Group {
            if let debug = coachCoordinator.state.coachV6Debug {
                VStack(alignment: .leading, spacing: 4) {
                    Text(debug.devLabel)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(debug.usingV6 ? CoachPalette.stable : CoachPalette.warning)
                        .fixedSize(horizontal: false, vertical: true)

                    if let fallbackReason = debug.fallbackReason {
                        Text("fallbackReason: \(fallbackReason)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(textSecondary.opacity(0.72))
                    }

                    Text("renderPath: \(coachV6Presentation != nil ? "coachV6Presentation" : (finalStoryRenderModel != nil ? "finalStoryRenderModel" : "coachPresentation"))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(textSecondary.opacity(0.62))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
        }
    }

    private func debugCoachV6Integration(event: String) {
        guard let debug = coachCoordinator.state.coachV6Debug else {
            CoachRefreshDebug.log("[CoachV6Integration]", "event=\(event) debug=nil status=\(coachCoordinator.state.status)")
            return
        }

        CoachRefreshDebug.log(
            "[CoachV6Integration]",
            "event=\(event) \(debug.logSummary) renderPath=\(coachV6Presentation != nil ? "coachV6Presentation" : (finalStoryRenderModel != nil ? "finalStoryRenderModel" : "coachPresentation"))"
        )
    }

    private func debugCoachHeroColorSystem(event: String) {
        guard let guidance = coachCoordinator.state.guidance else {
            CoachRefreshDebug.log("[CoachHeroColorDebug]", "event=\(event) priority=missing")
            return
        }

        CoachRefreshDebug.log(
            "[CoachHeroColorDebug]",
            [
                "event=\(event)",
                "priority.focus=\(guidance.priority.focus)",
                "priority.priority=\(guidance.priority.priority)",
                "priority.strength=\(guidance.priority.strength)",
                "priority.severity=\(guidance.priority.severity)",
                "guidance.importance=\(guidance.importance)",
                "heroSemanticColorSource=\(heroSemanticColorSource)",
                "finalStoryRenderModel.colorFamily=\(finalStoryRenderModel?.colorFamily.rawValue ?? "nil")",
                "coachPresentation.colorSource=\(coachCoordinator.state.coachPresentation == nil ? "nil" : "coachPresentation.color")",
                "badgeColorSource=heroSemanticColor",
                "actionColorSource=ActionSemanticColor/per-action"
            ].joined(separator: " ")
        )
    }

    private func debugScreenStoryType(_ output: CoachGuidanceV3) -> String {
        guard output.screenStory != nil else { return "nil" }
        return output.narrativePlan.map { "badge=\($0.badgeIntent)" } ?? "legacy"
    }

    private func debugCoachScreenRenderDetails(for output: CoachGuidanceV3) -> String {
        let story = output.screenStory
        let presentation = coachCoordinator.state.coachPresentation
        let selectedActivity = output.priority.activity ?? coachDayContext.coachFocusActivity
        let nextActivity = dayContext.nextActivity
        let coachRelevantActivities = plannedActivitiesForSelectedDate.filter(CoachDayActivityContextResolver.isCoachRelevant)
        let visibleFutureUpNextCount = coachRelevantActivities.filter {
            !$0.isCompleted &&
                !$0.isSkipped &&
                $0.date >= Date()
        }.count
        let selectedActivityRenderState = debugSelectedActivityRenderState(
            selectedActivity,
            visibleFutureActivities: coachRelevantActivities.filter {
                !$0.isCompleted &&
                    !$0.isSkipped &&
                    $0.date >= Date()
            }
        )
        let supportSignals = output.priority.supportBullets
        let primaryActions = story?.primaryActions ?? []
        let secondarySupportActions = story?.supportActions ?? []
        let hiddenSupportReason: String = {
            if story == nil { return "screenStoryNil" }
            if supportSignals.isEmpty && primaryActions.isEmpty && secondarySupportActions.isEmpty && output.supportActions.isEmpty { return "noSupportSignalsOrActions" }
            if !supportSignals.isEmpty || !secondarySupportActions.isEmpty { return "hiddenByRenderingContract" }
            if !supportSignals.isEmpty && secondarySupportActions.isEmpty { return "supportSignalsNotMappedToSupportActions" }
            return "none"
        }()
        let visibleRisk = story?.shouldShowBeCarefulWith == true ? story?.beCarefulWith : nil

        return """
        ExpertCoachViewV3.renderSource=canonicalCoachState stateID=\(coachCoordinator.state.id) screenStoryNil=\(story == nil) \
        renderedState=\"\(presentation?.stateLabel ?? story?.stateLabel ?? output.stateLabel)\" renderedTitle=\"\(presentation?.title ?? validTitle(output.title) ?? story?.title ?? output.priority.detailTitle)\" \
        myRead=\"\(presentation?.message ?? story?.myRead ?? output.message)\" myRecommendation=\"\(canonicalRecommendationText ?? story?.myRecommendation ?? output.insightSubtitle ?? "")\" beCarefulWith=\"\(visibleRisk ?? output.avoidNotes.joined(separator: " | "))\" \
        hiddenSupportSignals.count=\(supportSignals.count) \
        primaryActions.count=\(primaryActions.count) primaryActions.titles=\"\(primaryActions.map(\.title).joined(separator: " | "))\" \
        hiddenSecondarySupportActions.count=\(secondarySupportActions.count) \
        visibleSupportActions.count=\(output.supportActions.count) hiddenSupportReason=\(hiddenSupportReason) \
        selectedCoachActivity=\"\(debugActivitySummary(selectedActivity))\" selectedCoachActivityRenderState=\(selectedActivityRenderState) nextActivityTime=\(nextActivity.map { "\($0.date)" } ?? "nil") \
        visibleFutureUpNextActivities=\(visibleFutureUpNextCount) rawAllActivities=\(plannedActivities.count) selectedDayActivities=\(plannedActivitiesForSelectedDate.count) coachRelevantActivities=\(coachRelevantActivities.count) \
        guidanceSourceTime=\(Date().timeIntervalSince1970) planVersion=\"\(coachCoordinator.state.fingerprint?.rawValue ?? "nil")\" \
        priority=\(output.priority.priority)/\(output.priority.focus) limiter=\(output.priority.limiter) intent=\(debugCoachIntentSummary())
        """
    }

    private func debugActivitySummary(_ activity: PlannedActivity?) -> String {
        guard let activity else { return "none" }
        return "\(activity.title)|\(activity.date)|completed=\(activity.isCompleted)|skipped=\(activity.isSkipped)"
    }

    private func debugSelectedActivityRenderState(
        _ activity: PlannedActivity?,
        visibleFutureActivities: [PlannedActivity]
    ) -> String {
        guard let activity else { return "none" }
        if visibleFutureActivities.contains(where: { $0.id == activity.id }) {
            return "visibleFutureUpNext"
        }
        if activity.isCompleted {
            return "selectedCompletedOrRecovering"
        }
        if activity.isSkipped {
            return "selectedSkipped"
        }
        if activity.date < Date() {
            return "selectedActiveOrPast"
        }
        return "selectedCoachOnly"
    }

    private func debugCoachIntentSummary() -> String {
        guard let snapshot = nutritionViewModel.coachMetricsSnapshot else { return "missingSnapshot" }
        let brain = snapshot.brain
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: plannedActivitiesForSelectedDate,
            selectedDate: screenViewModel.selectedDate,
            now: Date(),
            brain: brain
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: nil,
            recoveryContext: snapshot.recoveryContext,
            nutritionContext: snapshot.nutritionContext,
            readiness: readiness
        )
        return "\(CoachIntentResolver.resolve(context))"
    }
    #endif

    private var plannedActivitiesForSelectedDate: [PlannedActivity] {
        screenViewModel.plannedActivities(
            for: screenViewModel.selectedDate,
            from: plannedActivities
        )
    }
    
    
    private var eveningReviewPlan: CoachEveningReviewPlan {

        let plannerActivities = plannedActivitiesForSelectedDate.filter {
            $0.source == "planner"
        }

        let planned = plannerActivities.count

        let completed = plannerActivities.filter {
            $0.isCompleted
        }.count

        let skipped = plannerActivities.filter {
            $0.isSkipped
        }.count

        return CoachEveningReviewPlan(
            planned: planned,
            completed: completed,
            skipped: skipped
        )
    }
}

private extension CoachSupportActionV3 {
    init(_ action: CoachSupportingAction) {
        self.init(
            type: action.type,
            icon: action.icon,
            title: action.title,
            subtitle: action.subtitle,
            color: action.color,
            actionProvenance: action.actionProvenance
        )
    }
}

enum CoachPalette {
    static let recovery = Color(red: 0.18, green: 0.74, blue: 0.89)
    static let hydration = Color(red: 0.40, green: 0.72, blue: 0.98)
    static let warning = Color(red: 1.00, green: 0.76, blue: 0.26)
    static let fueling = WeekFitTheme.orange
    static let training = WeekFitTheme.workout
    static let stable = Color(red: 0.16, green: 0.80, blue: 0.43)
    /// Strategic protect-tomorrow — calm lunar tone, not alarm red.
    static let protection = Color(red: 0.58, green: 0.52, blue: 0.95)
    static let stress = Color(red: 1.00, green: 0.47, blue: 0.47)

    // NEW
    static let good = stable
    static let activity = training

    static func accent(for priority: CoachDayPriorityResult) -> Color {
        if priority.strength == .critical {
            return stress
        }

        if priority.focus == .activeActivity {
            return priority.severity == .critical ? warning : activity
        }

        switch priority.severity {
        case .critical:
            return stress
        case .caution:
            if priority.focus == .hydrationBehind || priority.limiter == .hydration {
                return hydration
            }
            if priority.focus == .fuelBehind || priority.limiter == .fueling {
                return fueling
            }
            if priority.focus == .prepareForActivity ||
                priority.focus == .nextActivityLater ||
                priority.focus == .performanceReadiness {
                return training
            }
            if priority.focus == .postActivityRecovery ||
                priority.focus == .recoveryNeeded ||
                priority.focus == .eveningWindDown ||
                priority.limiter == .sleep ||
                priority.limiter == .recovery ||
                priority.limiter == .insufficientRecoveryTime {
                return recovery
            }
            return warning
        case .normal:
            if priority.focus == .postActivityRecovery || priority.focus == .recoveryNeeded || priority.focus == .eveningWindDown {
                return recovery
            }
            return stable
        }
    }

    static func accent(for focus: CoachDayFocus) -> Color {
        switch focus {
        case .activeActivity, .prepareForActivity, .nextActivityLater, .performanceReadiness:
            return training
        case .postActivityRecovery, .recoveryNeeded, .eveningWindDown:
            return recovery
        case .hydrationBehind:
            return hydration
        case .fuelBehind:
            return fueling
        case .trainingReadinessWarning, .tomorrowPlanRisk:
            return warning
        case .dailyOverview:
            return stable
        }
    }
}

private enum ActionSemanticColor {
    static func color(for action: CoachSupportActionV3) -> Color {
        switch action.type {
        case .sleepPriority:
            return Color(red: 0.30, green: 0.42, blue: 0.95)

        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return CoachPalette.hydration

        case .startRecoveryNutrition, .recoveryMeal, .lightFueling, .sustainEnergy, .keepDigestionLight:
            return CoachPalette.fueling

        case .cooldown, .lightRecoveryMovement:
            return Color(red: 0.18, green: 0.78, blue: 0.42)

        case .mobilityPrep:
            return Color(red: 0.20, green: 0.78, blue: 0.68)

        case .breathingReset, .downshiftNervousSystem:
            return Color(red: 0.22, green: 0.78, blue: 0.88)

        case .controlIntensity:
            return action.actionProvenance == .activeSessionExecution
                ? Color(red: 1.00, green: 0.68, blue: 0.24)
                : Color(red: 0.62, green: 0.66, blue: 0.72)

        case .stayConsistent:
            return CoachPalette.stable
        }
    }
}
