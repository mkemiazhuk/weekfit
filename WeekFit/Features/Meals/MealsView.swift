import SwiftUI
import SwiftData
import WeekFitPlanner

private enum MealCreationStep: Equatable {
    case builder
    case manualFood
}

struct MealsView: View {

    @ObservedObject var authViewModel: AuthViewModel
    let nutritionResult: NutritionResult?

    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var languageManager: AppLanguageManager
    @Environment(\.tabIsActive) private var tabIsActive

    // MARK: - UX-Контексты логирования
    var isQuickLogMode: Bool = false
    var onMealLogged: (() -> Void)? = nil

    @StateObject private var userSettings = WeekFitUserSettings.shared
    @StateObject private var mealsViewModel = MealsViewModel()

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    @State private var showCreationSheet = false
    @State private var creationStep: MealCreationStep = .builder
    @State private var selectedMeal: Meals?
    @State private var selectedFood: Meals?
    @State private var showContent = false
    @State private var highlightedMealID: String?

    @State private var showProfile = false
    @State private var expandedLibraryKind: MealLibraryRowKind?
    @AppStorage(OnboardingStore.Keys.introMeals) private var mealsIntroDismissed = false

    private let cardSecondary = WeekFitTheme.cardSecondary
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let textTertiary = WeekFitTheme.tertiaryText

    /// Prefer env palette over `WeekFitTheme.*` snapshots — those can stay Dark after Appearance flips.
    private var canvasBackground: Color { palette.appScreenBackground }

    // MARK: - Library groups
    
    private var mealItems: [Meals] {
        mealsViewModel.customMeals.filter { $0.isRecipeMeal && resolvedLibraryType($0) != .ingredient }
    }

    private var foodItems: [Meals] {
        mealsViewModel.customMeals.filter { $0.isFoodProduct }
    }

    private var shouldShowRecommendation: Bool {
        mealItems.count > 1 && visibleRecommendation != nil
    }

    private var sortedMealItems: [Meals] {
        guard let recommended = visibleRecommendation?.meal,
              mealItems.count > 1 else {
            return mealItems
        }

        return mealItems.sorted { lhs, rhs in
            if lhs.id == recommended.id { return true }
            if rhs.id == recommended.id { return false }
            return lhs.shortTitle < rhs.shortTitle
        }
    }

    private var displayedMealItems: [Meals] {
        guard shouldShowRecommendation,
              let recommendedID = visibleRecommendation?.meal.id else {
            return sortedMealItems
        }

        return sortedMealItems.filter { $0.id != recommendedID }
    }

    private var sortedFoodItems: [Meals] {
        foodItems.sorted { $0.shortTitle < $1.shortTitle }
    }

    private var hasAnyItems: Bool {
        !mealItems.isEmpty || !foodItems.isEmpty
    }

    private var headerSubtitle: String {
        if !mealsViewModel.hasLoadedCustomMeals {
            return WeekFitLocalizedString("meals.library.subtitle.loading")
        }

        if !hasAnyItems {
            return WeekFitLocalizedString("meals.library.subtitle.empty")
        }

        let total = mealItems.count + foodItems.count
        return String(
            format: WeekFitLocalizedString("meals.library.subtitle.savedItemsFormat"),
            total
        )
    }

    private var mealsContentRevision: String {
        let mealSignature = mealsViewModel.customMeals
            .sorted { $0.id < $1.id }
            .map { "\($0.id):\($0.title)" }
            .joined(separator: "|")
        return "\(mealsViewModel.hasLoadedCustomMeals)-\(mealsViewModel.customMeals.count)-\(mealsViewModel.lastRecommendationSignature)-\(userSettings.customMealsCatalogRevision)-\(mealSignature)"
    }

    var body: some View {
        Group {
            if tabIsActive {
                EquatableView(
                    content: MealsBodyGate(
                        gateRevision: mealsContentRevision,
                        appearanceInvalidationToken: palette.appearanceInvalidationToken,
                        content: activeMealsBody
                    )
                )
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: tabIsActive) { _, isActive in
            guard !isActive else { return }
            MealPhotoStore.releaseMemoryCache()
            #if DEBUG
            TabSwitchProfiler.markEvent("MealsView.releasePhotoCache")
            #endif
        }
    }

    @ViewBuilder
    private var activeMealsBody: some View {
        let _ = languageManager.selectedLanguage

        ZStack(alignment: .top) {
            // Root already paints `appScreenBackground` + meals ambient.
            // Keep ScrollView transparent so cards sit on the same continuous canvas.
            WeekFitScreenContainer {

                WeekFitScreenHeader(
                    title: WeekFitLocalizedString("meals.library.title"),
                    subtitle: headerSubtitle,
                    initials: userSettings.profileInitials,
                    hasProfileName: userSettings.hasProfileName,
                    showAvatar: true,
                    trailing: {
                        if !isQuickLogMode {
                            mealsAddMenu
                        }
                    },
                    onAvatarTap: { showProfile = true }
                )

            } content: {
                mealsContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(canvasBackground)
            }
            .id(palette.appearanceInvalidationToken)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.meals")
        .onAppear {
            if !showContent {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    showContent = true
                }
            }

            // Pick up catalog writes from Plan / other surfaces that may have
            // updated UserDefaults while Meals held a stale in-memory copy.
            userSettings.refreshFromStorage()

            guard !mealsViewModel.hasLoadedCustomMeals else {
                mealsViewModel.applyLoadedCustomMeals(userSettings.customMealsCatalog)
                updateRecommendationIfNeeded(source: "MealsView.onAppear.refreshRecommendation")
                return
            }

            mealsViewModel.applyLoadedCustomMeals(userSettings.customMealsCatalog)

            Task {
                await migrateCustomMealsCatalogIfNeeded()
                updateRecommendationIfNeeded(source: "MealsView.onAppear.loadCustomMeals")
            }
        }
        .onChange(of: highlightedMealID) { _, mealID in
            guard mealID != nil else { return }

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeOut(duration: 0.25)) {
                    highlightedMealID = nil
                }
            }
        }
        .onChange(of: userSettings.customMealsCatalogRevision) { _, _ in
            mealsViewModel.applyLoadedCustomMeals(userSettings.customMealsCatalog)
            guard tabIsActive else { return }
            updateRecommendationIfNeeded(source: "MealsView.onChange.customMealsCatalogRevision")
        }
        .onChange(of: mealsViewModel.customMeals) { _, _ in
            guard tabIsActive else { return }
            updateRecommendationIfNeeded(source: "MealsView.onChange.customMeals")
        }
        .onChange(of: plannedActivities) { _, _ in
            guard tabIsActive else { return }
            updateRecommendationIfNeeded(source: "MealsView.onChange.plannedActivities")
        }
        .onChange(of: nutritionViewModel.coachStateRefreshID) { _, _ in
            guard tabIsActive else { return }
            updateRecommendationIfNeeded(source: "MealsView.onChange.nutritionCoachStateRefreshID")
        }
        .onChange(of: languageManager.selectedLanguage) { _, _ in
            guard tabIsActive else { return }
            updateRecommendationIfNeeded(source: "MealsView.onChange.language")
        }
        .onChange(of: tabIsActive) { _, isActive in
            guard isActive else { return }
            updateRecommendationIfNeeded(source: "MealsView.onBecomeActive")
        }
        .safeAreaInset(edge: .bottom) {
            bottomFixedActionArea
        }
        .sheet(item: $selectedMeal) { meal in
            MealDetailsView(
                meal: meal,
                isQuickLogMode: self.isQuickLogMode,
                onMealLogged: {
                    selectedMeal = nil
                    onMealLogged?()
                },
                onMealUpdated: { updatedMeal in
                    saveMealToLibrary(updatedMeal)
                },
                onMealSavedAndClose: {
                    selectedMeal = nil
                }
            )
            .weekFitSheetChrome(
                cornerRadius: 36,
                background: QuickActionSheetDesign.Color.sheetBackground(for: .food)
            )
        }
        .sheet(item: $selectedFood) { food in
            CustomFoodDetailsView(
                food: food,
                existingMeals: mealsViewModel.customMeals,
                isQuickLogMode: self.isQuickLogMode,
                onFoodUpdated: { updatedFood in
                    saveMealToLibrary(updatedFood)
                    selectedFood = updatedFood
                },
                onFoodLogged: {
                    selectedFood = nil
                    onMealLogged?()
                }
            )
            .id("\(food.id)-\(food.title)")
            .weekFitSheetChrome(
                cornerRadius: 36,
                background: QuickActionSheetDesign.Color.sheetBackground(for: .food)
            )
        }
        .weekFitSettingsSheet(isPresented: $showProfile)
        .sheet(item: $expandedLibraryKind) { kind in
            MealLibraryExpandSheet(
                kind: kind,
                items: kind == .meal ? displayedMealItems : sortedFoodItems,
                highlightedMealID: highlightedMealID,
                onSelect: { meal in
                    expandedLibraryKind = nil
                    if meal.isFoodProduct {
                        selectedFood = meal
                    } else {
                        selectedMeal = meal
                    }
                },
                onDelete: { meal in
                    deleteCustomMeal(meal)
                }
            )
            .weekFitSheetChrome(
                cornerRadius: 36,
                background: QuickActionSheetDesign.Color.sheetBackground(for: .food)
            )
        }
        .sheet(isPresented: $showCreationSheet) {
            // One sheet only — SwiftUI cannot present a second sheet on top of this one.
            MealCreationSheetHost(
                step: $creationStep,
                existingMeals: mealsViewModel.customMeals,
                onSaved: { newMeal in
                    showCreationSheet = false
                    saveMealToLibrary(newMeal, scrollToNewItem: true)
                }
            )
        }
        .onChange(of: showCreationSheet) { _, isPresented in
            guard !isPresented else { return }
            // Manual food path: cancel only if started and not already completed/failed.
            ProductAnalytics.foodLoggingCancelIfNeeded()
            creationStep = .builder
        }
    }

    private func openCreation(_ step: MealCreationStep) {
        switch step {
        case .builder:
            ProductAnalytics.mealBuilderStarted(mode: .new, source: .meals)
            ProductAnalytics.trackScreen(.mealBuilder)
        case .manualFood:
            ProductAnalytics.foodLoggingStarted(method: .manual, source: .meals)
        }
        creationStep = step
        showCreationSheet = true
    }

    private var mealsAddMenu: some View {
        Menu {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openCreation(.builder)
            } label: {
                Label(
                    WeekFitLocalizedString("meals.creation.builder.title"),
                    systemImage: "fork.knife"
                )
            }
            .accessibilityIdentifier("meals.creation.builder")

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openCreation(.manualFood)
            } label: {
                Label(
                    WeekFitLocalizedString("meals.creation.customFood.title"),
                    systemImage: "camera.fill"
                )
            }
            .accessibilityIdentifier("meals.creation.customFood")
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(mealsAddForeground)
                .frame(width: 36, height: 36)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(mealsAddBackground)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    mealsAddStrokeLight.opacity(palette.isLight ? 0.98 : 0.95),
                                    mealsAddStrokeDeep.opacity(palette.isLight ? 0.78 : 0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: palette.isLight ? 1.35 : 1.1
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .id(palette.appearanceInvalidationToken)
        .accessibilityLabel(WeekFitLocalizedString("meals.create"))
        .accessibilityHint(WeekFitLocalizedString("meals.createFoodOrMeal"))
        .accessibilityIdentifier("meals.create")
    }

    private var mealsAddBackground: LinearGradient {
        if palette.isLight {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.998, blue: 0.992),
                    Color(red: 0.985, green: 0.978, blue: 0.965)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 30/255, green: 24/255, blue: 18/255),
                Color(red: 10/255, green: 10/255, blue: 10/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var mealsAddForeground: LinearGradient {
        if palette.isLight {
            return LinearGradient(
                colors: [
                    WeekFitLightTokens.brandGold,
                    WeekFitLightTokens.brandGoldDark
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 255/255, green: 235/255, blue: 170/255),
                Color(red: 211/255, green: 163/255, blue: 62/255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var mealsAddStrokeLight: Color {
        Color(red: 255/255, green: 221/255, blue: 132/255)
    }

    private var mealsAddStrokeDeep: Color {
        Color(red: 142/255, green: 104/255, blue: 36/255)
    }
    
    @MainActor
    private func migrateCustomMealsCatalogIfNeeded() async {
        let storage = userSettings.customMealsStorage
        let result = await mealsViewModel.loadCustomMealsAsync(storage: storage)
        guard result.encodedStorage != nil else { return }

        mealsViewModel.applyLoadedCustomMeals(result.meals)
        userSettings.replaceCustomMealsCatalog(result.meals)
    }

    private var plannedActivitiesForSelectedDate: [PlannedActivity] {
        mealsViewModel.plannedActivitiesForSelectedDate(
            selectedDate: mealsViewModel.selectedDate,
            from: plannedActivities
        )
    }

    private func updateRecommendationIfNeeded(source: String) {
        mealsViewModel.updateRecommendationIfNeeded(
            source: source,
            selectedDate: mealsViewModel.selectedDate,
            plannedActivities: plannedActivities,
            mealItems: mealItems,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            nutritionResult: nutritionResult,
            languageCode: languageManager.selectedLanguage.rawValue
        )
    }

    private var visibleRecommendation: MealRecommendation? {
        mealsViewModel.cachedRecommendation
    }

    private var mealsContent: some View {
        ScrollViewReader { proxy in
            Group {
                if !mealsViewModel.hasLoadedCustomMeals {
                    loadingLibraryList
                } else if nutritionViewModel.catalogLoadFailed && !hasAnyItems {
                    catalogErrorList
                } else if !hasAnyItems {
                    emptyLibraryList
                } else {
                    populatedLibraryList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onChange(of: highlightedMealID) { _, mealID in
                guard let mealID else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    proxy.scrollTo(mealID, anchor: .center)
                }
            }
        }
    }

    private var loadingLibraryList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { _ in
                    MealsLibrarySkeletonRow()
                }

                Color.clear
                    .frame(height: isQuickLogMode ? 52 : 56)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .weekFitTransparentScrollBackground()
    }

    private var emptyLibraryList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                if !mealsIntroDismissed {
                    OnboardingContextualIntroCard(
                        title: WeekFitLocalizedString("onboarding.intro.meals.title"),
                        message: WeekFitLocalizedString("onboarding.intro.meals.body"),
                        accent: WeekFitTheme.meal
                    ) {
                        mealsIntroDismissed = true
                    }
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                customEmptyState
                    .padding(.top, 4)

                Color.clear
                    .frame(height: isQuickLogMode ? 36 : 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .weekFitTransparentScrollBackground()
    }

    private var catalogErrorList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.orange.opacity(0.88))

                Text(WeekFitLocalizedString("meals.catalog.loadFailed.title"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(WeekFitLocalizedString("meals.catalog.loadFailed.message"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(textSecondary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    nutritionViewModel.reloadCatalog()
                } label: {
                    Text(WeekFitLocalizedString("common.action.retry"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.86))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(WeekFitTheme.meal.opacity(0.92))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(18)
            .weekFitPremiumCard(
                emphasis: .accent,
                accent: WeekFitTheme.orange,
                cornerRadius: 20
            )
            .padding(.top, 2)

            Color.clear
                .frame(height: isQuickLogMode ? 52 : 56)
        }
        .scrollIndicators(.hidden)
        .weekFitTransparentScrollBackground()
    }

    private var populatedLibraryList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                if !mealsIntroDismissed {
                    OnboardingContextualIntroCard(
                        title: WeekFitLocalizedString("onboarding.intro.meals.title"),
                        message: WeekFitLocalizedString("onboarding.intro.meals.body"),
                        accent: WeekFitTheme.meal
                    ) {
                        mealsIntroDismissed = true
                    }
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if shouldShowRecommendation, let recommendation = visibleRecommendation {
                    coachRecommendationHero(recommendation)
                        .padding(.bottom, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !displayedMealItems.isEmpty {
                    sectionHeader(
                        title: "meals.library.section.meals",
                        count: displayedMealItems.count,
                        icon: "fork.knife",
                        prominence: .primary,
                        showsViewAll: displayedMealItems.count > MealLibraryCardMetrics.previewLimit,
                        onViewAll: { expandedLibraryKind = .meal }
                    )
                    .padding(.top, 4)
                    .padding(.bottom, 2)

                    libraryGrid(
                        Array(displayedMealItems.prefix(MealLibraryCardMetrics.previewLimit)),
                        kind: .meal
                    )
                }

                if !sortedFoodItems.isEmpty {
                    sectionHeader(
                        title: "meals.library.section.foods",
                        count: sortedFoodItems.count,
                        icon: "takeoutbag.and.cup.and.straw.fill",
                        prominence: .secondary,
                        showsViewAll: sortedFoodItems.count > MealLibraryCardMetrics.previewLimit,
                        onViewAll: { expandedLibraryKind = .food }
                    )
                    .padding(.top, displayedMealItems.isEmpty ? 4 : 12)
                    .padding(.bottom, 2)

                    libraryGrid(
                        Array(sortedFoodItems.prefix(MealLibraryCardMetrics.previewLimit)),
                        kind: .food
                    )
                }

                Color.clear
                    .frame(height: isQuickLogMode ? 52 : 56)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(
                .spring(response: 0.38, dampingFraction: 0.86),
                value: visibleRecommendation?.meal.id
            )
        }
        .scrollIndicators(.hidden)
        .weekFitTransparentScrollBackground()
    }

    @ViewBuilder
    private func coachRecommendationHero(_ recommendation: MealRecommendation) -> some View {
        RecommendedTodayMealCard(
            recommendation: recommendation,
            onDetails: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if recommendation.meal.isFoodProduct {
                    selectedFood = recommendation.meal
                } else {
                    selectedMeal = recommendation.meal
                }
            }
        )
        .id("coachRecommendationHero")
    }

    @ViewBuilder
    private func libraryGrid(_ items: [Meals], kind: MealLibraryRowKind) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: MealLibraryCardMetrics.gridSpacing),
            GridItem(.flexible(), spacing: MealLibraryCardMetrics.gridSpacing)
        ]

        if isQuickLogMode {
            libraryRows(items, kind: kind)
        } else {
            LazyVGrid(columns: columns, spacing: MealLibraryCardMetrics.gridSpacing) {
                ForEach(items) { meal in
                    MealLibraryGridCard(
                        meal: meal,
                        kind: kind,
                        isHighlighted: highlightedMealID == meal.id,
                        onDelete: { deleteCustomMeal(meal) }
                    )
                    .id(meal.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if meal.isFoodProduct {
                            selectedFood = meal
                        } else {
                            selectedMeal = meal
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func libraryRows(_ items: [Meals], kind: MealLibraryRowKind) -> some View {
        LazyVStack(alignment: .leading, spacing: kind == .meal ? 8 : 7) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, meal in
                HeroMealLibraryRow(
                    meal: meal,
                    kind: kind,
                    isQuickLogMode: isQuickLogMode,
                    isRecommended: rowShowsRecommendationBadge(for: meal, in: items, at: index),
                    recommendationBadge: rowRecommendationBadge(for: meal, in: items, at: index),
                    recommendationIcon: rowRecommendationIcon(for: meal, in: items, at: index),
                    isHighlighted: highlightedMealID == meal.id,
                    onPlusTap: isQuickLogMode ? { executeDirectQuickLog(meal) } : nil
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(meal.id)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if meal.isFoodProduct {
                        selectedFood = meal
                    } else {
                        selectedMeal = meal
                    }
                }
                .contextMenu {
                    if !isQuickLogMode {
                        Button(role: .destructive) {
                            deleteCustomMeal(meal)
                        } label: {
                            Label(WeekFitLocalizedString("common.action.delete"), systemImage: "trash.fill")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(
        title: String,
        count: Int,
        icon: String,
        prominence: SectionHeaderProminence = .primary,
        showCount: Bool = true,
        showsViewAll: Bool = false,
        onViewAll: (() -> Void)? = nil
    ) -> some View {
        let titleWeight: Font.Weight = prominence == .primary ? .semibold : .medium
        let linkColor = palette.isLight ? WeekFitLightTokens.brandGold : WeekFitTheme.meal

        return HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    palette.isLight
                        ? linkColor.opacity(prominence == .primary ? 0.92 : 0.72)
                        : WeekFitTheme.meal.opacity(prominence == .primary ? 0.72 : 0.55)
                )
                .frame(width: 14, alignment: .center)
                .accessibilityHidden(true)

            Text(WeekFitLocalizedString(title))
                .font(.system(size: 15, weight: titleWeight, design: .rounded))
                .foregroundStyle(
                    palette.isLight
                        ? WeekFitTheme.primaryText
                        : textSecondary.opacity(prominence == .primary ? 0.88 : 0.72)
                )
                .tracking(-0.12)

            if showCount {
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        palette.isLight
                            ? WeekFitTheme.tertiaryText
                            : textSecondary.opacity(prominence == .primary ? 0.58 : 0.48)
                    )
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background {
                        Capsule(style: .continuous)
                            .fill(
                                palette.isLight
                                    ? WeekFitLightTokens.surfaceTertiary
                                    : WeekFitTheme.whiteOpacity(prominence == .primary ? 0.06 : 0.045)
                            )
                    }
                    .accessibilityLabel("\(count)")
            }

            Spacer(minLength: 0)

            if showsViewAll, let onViewAll {
                Button(action: onViewAll) {
                    HStack(spacing: 2) {
                        Text(WeekFitLocalizedString("planner.sheet.viewAll"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(linkColor)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func rowShowsRecommendationBadge(for meal: Meals, in items: [Meals], at index: Int) -> Bool {
        guard !meal.isFoodProduct,
              !shouldShowRecommendation,
              mealItems.count > 1,
              items == sortedMealItems,
              index == 0,
              meal.id == visibleRecommendation?.meal.id else {
            return false
        }
        return true
    }

    private func rowRecommendationBadge(for meal: Meals, in items: [Meals], at index: Int) -> String? {
        guard rowShowsRecommendationBadge(for: meal, in: items, at: index) else { return nil }
        return visibleRecommendation?.badge
    }

    private func rowRecommendationIcon(for meal: Meals, in items: [Meals], at index: Int) -> String? {
        guard rowShowsRecommendationBadge(for: meal, in: items, at: index) else { return nil }
        return visibleRecommendation?.icon
    }

    private enum SectionHeaderProminence {
        case primary
        case secondary
    }

    private var customEmptyState: some View {
        MealLibraryEmptyStateCard(
            title: WeekFitLocalizedString("meals.emptyState.expanded.title"),
            message: WeekFitLocalizedString("meals.emptyState.expanded.message"),
            ctaTitle: WeekFitLocalizedString("meals.emptyLibrary.createMealCTA"),
            benefits: [],
            presentation: .compact,
            secondaryCTATitle: WeekFitLocalizedString("meals.creation.customFood.title"),
            secondaryAction: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openCreation(.manualFood)
            }
        ) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            openCreation(.builder)
        }
    }

    private func executeDirectQuickLog(_ meal: Meals) {
        let quickActivity = PlannedActivity(
            date: Date(),
            type: PlannerType.meal.title,
            title: meal.title,
            durationMinutes: 20,
            icon: WeekFitActivityIconResolver.preferredIcon(
                storedIcon: PlannerType.meal.icon,
                title: meal.title,
                type: "meal",
                imageName: meal.activityImageName
            ),
            imageName: meal.activityImageName,
            colorRed: PlannerType.meal.colorComponents.red,
            colorGreen: PlannerType.meal.colorComponents.green,
            colorBlue: PlannerType.meal.colorComponents.blue,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fats: meal.fats,
            fiber: meal.fiber,
            source: "nutritionLog"
        )
        quickActivity.isCompleted = true

        AppReviewDemoPlannedActivityTagger.tagIfNeeded(quickActivity)
        modelContext.insert(quickActivity)
        do {
            try modelContext.save()
            ReviewEngagement.record(.foodLogged)
            ProductAnalytics.foodLoggingCompleted(method: .quickLog, source: .meals)
            onMealLogged?()
        } catch {
            modelContext.delete(quickActivity)
            ProductAnalytics.foodLoggingFailed(method: .quickLog, source: .meals, reason: .saveFailed)
        }
    }

    private func deleteCustomMeal(_ meal: Meals) {
        withAnimation(.easeInOut(duration: 0.22)) {
            mealsViewModel.customMeals = CustomMealStore.remove(meal, from: mealsViewModel.customMeals)
        }

        MealPhotoStore.deletePhotoSet(
            originalFilename: meal.localPhotoFilename,
            thumbnailFilename: meal.localPhotoThumbnailFilename
        )
        MealPhotoStore.releaseMemoryCache()
        userSettings.replaceCustomMealsCatalog(mealsViewModel.customMeals)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func saveMealToLibrary(_ meal: Meals, scrollToNewItem: Bool = false) {
        let wasNew = !mealsViewModel.customMeals.contains(where: { $0.id == meal.id })

        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            mealsViewModel.customMeals = CustomMealStore.upsert(meal, into: mealsViewModel.customMeals)
        }

        MealPhotoStore.releaseMemoryCache()
        userSettings.replaceCustomMealsCatalog(mealsViewModel.customMeals)

        if scrollToNewItem && wasNew {
            highlightedMealID = meal.id
        }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private enum ResolvedLibraryType {
        case meal
        case ingredient
    }

    private func resolvedLibraryType(_ meal: Meals) -> ResolvedLibraryType {
        if let libraryKind = meal.libraryKind {
            return libraryKind == .ingredient ? .ingredient : .meal
        }

        let ids = meal.builderImageItems?.map { $0.id } ?? []

        if !ids.isEmpty {
            let nonDrinkIds = ids.filter { !$0.hasPrefix("drink_") }
            if ids.count == 1 || nonDrinkIds.count <= 1 {
                return .ingredient
            }

            return .meal
        }

        return meal.ingredients.count <= 1 ? .ingredient : .meal
    }

    private var bottomFixedActionArea: some View {
        bottomFadeOnly
            .frame(height: WeekFitScreenLayout.tabBarClearance + 18)
            .background {
                bottomFadeGradient
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var bottomFadeOnly: some View {
        Color.clear
    }

    private var bottomFadeGradient: some View {
        Group {
            if palette.isLight {
                // Light canvas needs no dark veil — a Dark-stale fade was compositing
                // as a black slab over ivory when EquatableView skipped appearance updates.
                Color.clear
            } else {
                LinearGradient(
                    colors: [
                        canvasBackground.opacity(0),
                        canvasBackground.opacity(0.58),
                        canvasBackground.opacity(0.94),
                        canvasBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .id(palette.appearanceInvalidationToken)
    }
}


private struct MealCreationSheetHost: View {
    @Binding var step: MealCreationStep

    let existingMeals: [Meals]
    let onSaved: (Meals) -> Void

    var body: some View {
        Group {
            switch step {
            case .builder:
                MealBuilderView(onSave: onSaved)

            case .manualFood:
                CustomMealBuilderView(existingMeals: existingMeals, onSave: onSaved)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .weekFitSheetChrome(
            cornerRadius: 36,
            background: QuickActionSheetDesign.Color.sheetBackground(for: .food)
        )
    }
}

private typealias CustomFoodFormView = CustomMealBuilderView

struct CustomFoodDetailsView: View {
    @State var food: Meals
    let existingMeals: [Meals]
    var isQuickLogMode: Bool = false
    var onFoodUpdated: ((Meals) -> Void)? = nil
    var onFoodLogged: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var languageManager: AppLanguageManager
    @State private var showEditForm = false

    private var canvasBackground: Color { palette.appScreenBackground }
    private let cardBackground = WeekFitTheme.cardBackground
    private let elevatedCard = WeekFitTheme.elevatedCard
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let accent = WeekFitTheme.meal

    var body: some View {
        let _ = languageManager.selectedLanguage

        ZStack {
            canvasBackground.ignoresSafeArea()
            WeekFitTheme.mealsAmbient
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 12) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        foodPreviewCard
                        servingCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, isQuickLogMode ? 118 : 30)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isQuickLogMode {
                quickLogButton
            }
        }
        .fullScreenCover(isPresented: $showEditForm) {
            CustomFoodFormView(
                editingMeal: food,
                existingMeals: existingMeals,
                onSave: { updatedFood in
                    food = updatedFood
                    onFoodUpdated?(updatedFood)
                }
            )
            .id("\(food.id)-\(food.title)-edit")
        }
    }

    private var header: some View {
        WeekFitDetailScreenHeader(
            title: WeekFitLocalizedString("meals.foodDetails"),
            subtitle: WeekFitLocalizedString("meals.reviewServingSizeAndNutrition"),
            titleColor: textPrimary,
            subtitleColor: textSecondary.opacity(0.76)
        ) {
            WeekFitDetailScreenBackButton {
                dismiss()
            }
        } trailing: {
            if !isQuickLogMode {
                WeekFitDetailScreenCircleButton(systemName: "square.and.pencil") {
                    showEditForm = true
                }
            }
        }
    }

    private var foodPreviewCard: some View {
        VStack(spacing: 12) {
            FoodMediaView(
                meal: food,
                presentation: .hero(size: 168),
                forceCircleForLocalPhoto: true
            )
            .frame(maxWidth: .infinity)
            .frame(height: 188)

            VStack(alignment: .leading, spacing: 5) {
                Text(food.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.42)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(food.servingDescription)
                    .font(.system(size: 12.4, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.76))
                    .lineLimit(2)
                    .lineSpacing(1.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MealNutritionSummaryStrip(
                calories: food.calories,
                protein: food.protein,
                carbs: food.carbs,
                fats: food.fats,
                fiber: food.fiber,
                accent: accent,
                style: .embedded
            )
            .padding(.top, 2)
        }
        .padding(.horizontal, 13)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .weekFitPremiumCard(emphasis: .elevated, accent: accent, cornerRadius: 26)
    }

    private var servingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("meals.serving"))
                .font(.system(size: 17.0, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
                .tracking(-0.25)

            HStack {
                Text(food.servingDescription)
                    .font(.system(size: 14.2, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(0.94))

                Spacer()

                Text(food.sourceLabel)
                    .font(.system(size: 12.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.70))
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .weekFitPremiumCard(emphasis: .compact, cornerRadius: 18)
        }
    }

    private var quickLogButton: some View {
        VStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                logFood()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))

                    Text(WeekFitLocalizedString("meals.logFood"))
                        .font(.system(size: 14.2, weight: .bold, design: .rounded))
                        .tracking(-0.08)
                }
                .foregroundStyle(.black.opacity(0.84))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    Capsule()
                        .fill(accent.opacity(0.92))
                        .shadow(color: accent.opacity(0.18), radius: 10, y: 4)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 84)
        }
        .background {
            LinearGradient(
                colors: [
                    canvasBackground.opacity(0),
                    canvasBackground.opacity(palette.isLight ? 0.42 : 0.62),
                    canvasBackground.opacity(palette.isLight ? 0.82 : 0.96),
                    canvasBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .id(palette.appearanceInvalidationToken)
        }
    }

    private func logFood() {
        let activity = PlannedActivity(
            date: Date(),
            type: PlannerType.meal.title,
            title: food.title,
            durationMinutes: 10,
            icon: WeekFitActivityIconResolver.preferredIcon(
                storedIcon: PlannerType.meal.icon,
                title: food.title,
                type: "meal",
                imageName: food.imageName
            ),
            imageName: food.imageName,
            colorRed: PlannerType.meal.colorComponents.red,
            colorGreen: PlannerType.meal.colorComponents.green,
            colorBlue: PlannerType.meal.colorComponents.blue,
            calories: food.calories,
            protein: food.protein,
            carbs: food.carbs,
            fats: food.fats,
            fiber: food.fiber,
            source: "nutritionLog"
        )

        activity.isCompleted = true
        AppReviewDemoPlannedActivityTagger.tagIfNeeded(activity)
        modelContext.insert(activity)
        do {
            try modelContext.save()
            ReviewEngagement.record(.foodLogged)
            ProductAnalytics.foodLoggingCompleted(method: .recent, source: .meals)
            onFoodLogged?()
        } catch {
            modelContext.delete(activity)
            ProductAnalytics.foodLoggingFailed(method: .recent, source: .meals, reason: .saveFailed)
        }
    }
}


struct MealRecommendation: Equatable {
    let meal: Meals

    let badge: String
    let reason: String
    let factors: [String]

    let icon: String
    let color: Color

    static func == (lhs: MealRecommendation, rhs: MealRecommendation) -> Bool {
        lhs.meal == rhs.meal &&
        lhs.badge == rhs.badge &&
        lhs.reason == rhs.reason &&
        lhs.factors == rhs.factors &&
        lhs.icon == rhs.icon
    }
}

enum MealRecommendationEngine {

    static func make(
        input: CoachInputSnapshot,
        meals: [Meals],
        now: Date
    ) -> MealRecommendation? {
        guard !meals.isEmpty else { return nil }

        let context = context(from: input, now: now)
        let rankedMeal = meals.max { lhs, rhs in
            score(lhs, context: context) < score(rhs, context: context)
        }

        guard let meal = rankedMeal else { return nil }

        let copy = copy(for: context, input: input, meal: meal)
        let factors = recommendationFactors(
            meal: meal,
            context: context,
            meals: meals,
            input: input
        )

        return MealRecommendation(
            meal: meal,
            badge: copy.badge,
            reason: copy.reason,
            factors: factors,
            icon: copy.icon,
            color: copy.color
        )
    }

    // This is deliberately about TIMING, not just "best macros".
    // A full meal can be a great choice today, but not necessarily right now.
    private enum RecommendationContext {
        case morningLight
        case middayBalanced
        case eveningLight
        case beforeSessionLight(minutesUntil: Int)
        case afterSessionLater(activityTitle: String?)
        case recoveryWindow
        case afterHeatLater
        case heatRecovery
        case recoveryProtection
        case balanced
    }

    private static func context(
        from input: CoachInputSnapshot,
        now: Date
    ) -> RecommendationContext {
        let hour = Calendar.current.component(.hour, from: now)
        let focus = CoachFocusResolver.resolve(input: input)

        switch focus.source {
        case .active:
            if focus.family == .heat {
                return .afterHeatLater
            }
            return .afterSessionLater(activityTitle: focus.activity?.title)

        case .upcoming:
            if focus.family == .heat {
                let minutes = focus.minutesUntilStart ?? 120
                return minutes < 75
                    ? .afterHeatLater
                    : .beforeSessionLight(minutesUntil: minutes)
            }

            if let minutes = focus.minutesUntilStart {
                if minutes < 45 {
                    return .afterSessionLater(activityTitle: focus.activity?.title)
                }
                if minutes <= 150 {
                    return .beforeSessionLight(minutesUntil: minutes)
                }
            }
            return dayContext(for: hour, input: input)

        case .recentCompleted:
            if focus.family == .heat {
                return .heatRecovery
            }
            return .recoveryWindow

        case .idle:
            return dayContext(for: hour, input: input)
        }
    }

    private static func dayContext(
        for hour: Int,
        input: CoachInputSnapshot
    ) -> RecommendationContext {
        if input.brain.recovery == .compromised ||
            input.brain.recovery == .vulnerable ||
            input.dayPriorityModel.tomorrowDemand == .hard {
            return .recoveryProtection
        }

        if input.dayContext.hasMeaningfulLoadCompleted ||
            input.brain.strain == .high ||
            input.brain.strain == .veryHigh {
            return .recoveryWindow
        }

        switch hour {
        case 5..<11:
            return .morningLight
        case 11..<17:
            return .middayBalanced
        case 17..<22:
            return .eveningLight
        default:
            return .recoveryProtection
        }
    }

    private static func score(
        _ meal: Meals,
        context: RecommendationContext
    ) -> Double {
        let calories = Double(meal.calories)
        let protein = Double(meal.protein)
        let carbs = Double(meal.carbs)
        let fats = Double(meal.fats)

        switch context {
        case .morningLight:
            let heavyPenalty = max(0, calories - 430) * 0.55
            let carbPenalty = max(0, carbs - 42) * 0.75
            let fatPenalty = max(0, fats - 16) * 1.20

            return protein * 1.55
                + carbs * 0.18
                - fats * 0.90
                + calorieBandScore(calories, ideal: 340, width: 0.34)
                - heavyPenalty
                - carbPenalty
                - fatPenalty

        case .middayBalanced:
            return protein * 1.70
                + carbs * 0.62
                - fats * 0.28
                + calorieBandScore(calories, ideal: 540, width: 0.16)

        case .eveningLight:
            return protein * 2.05
                + carbs * 0.18
                - fats * 0.85
                + calorieBandScore(calories, ideal: 420, width: 0.22)
                - max(0, calories - 560) * 0.12
                - max(0, carbs - 45) * 0.45

        case .beforeSessionLight:
            return carbs * 1.30
                + protein * 1.05
                - fats * 1.10
                + calorieBandScore(calories, ideal: 460, width: 0.20)
                - max(0, calories - 620) * 0.10

        case .afterSessionLater, .recoveryWindow:
            return protein * 2.55
                + carbs * 1.05
                - fats * 0.42
                + calorieBandScore(calories, ideal: 610, width: 0.16)

        case .afterHeatLater, .heatRecovery:
            return protein * 1.85
                + carbs * 0.42
                - fats * 1.00
                + calorieBandScore(calories, ideal: 430, width: 0.22)
                - max(0, calories - 560) * 0.12

        case .recoveryProtection:
            return protein * 2.05
                + carbs * 0.20
                - fats * 0.85
                + calorieBandScore(calories, ideal: 430, width: 0.22)
                - max(0, calories - 560) * 0.12

        case .balanced:
            return protein * 1.60
                + carbs * 0.55
                - fats * 0.25
                + calorieBandScore(calories, ideal: 530, width: 0.16)
        }
    }

    private static func calorieBandScore(
        _ calories: Double,
        ideal: Double,
        width: Double
    ) -> Double {
        max(0, 80 - abs(calories - ideal) * width)
    }

    private static func copy(
        for context: RecommendationContext,
        input: CoachInputSnapshot,
        meal: Meals
    ) -> (badge: String, reason: String, icon: String, color: Color) {
        switch context {
        case .morningLight:
            return (
                WeekFitLocalizedString("meals.library.badge.morningPick"),
                WeekFitLocalizedString("meals.library.recommendation.reason.morningLight"),
                "sunrise.fill",
                WeekFitTheme.meal
            )

        case .middayBalanced:
            let coachFocused = input.dayContext.hasMeaningfulLoadCompleted ||
                input.dayPriorityModel.dayStressLevel == .high
            return (
                WeekFitLocalizedString("meals.library.badge.bestForToday"),
                coachFocused
                    ? WeekFitLocalizedString("meals.library.recommendation.reason.middayCoachFocus")
                    : WeekFitLocalizedString("meals.library.recommendation.reason.middayBalanced"),
                "fork.knife",
                WeekFitTheme.meal
            )

        case .eveningLight:
            return (
                WeekFitLocalizedString("meals.library.badge.eveningPick"),
                WeekFitLocalizedString("meals.library.recommendation.reason.eveningLight"),
                "moon.fill",
                CoachPalette.recovery
            )

        case .beforeSessionLight(let minutesUntil):
            return (
                WeekFitLocalizedString("meals.library.badge.enduranceFuel"),
                String(
                    format: WeekFitLocalizedString("meals.library.recommendation.reason.beforeSessionFormat"),
                    timeText(minutesUntil)
                ),
                "bolt.fill",
                .orange
            )

        case .afterSessionLater(let activityTitle):
            let activity = activityTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let reason = activity?.isEmpty == false
                ? String(
                    format: WeekFitLocalizedString("meals.library.recommendation.reason.afterSessionNamedFormat"),
                    activity ?? WeekFitLocalizedString("meals.library.recommendation.sessionFallback")
                )
                : WeekFitLocalizedString("meals.library.recommendation.reason.afterSessionGeneric")

            return (
                WeekFitLocalizedString("meals.library.badge.postWorkoutPick"),
                reason,
                "clock.badge.checkmark.fill",
                WeekFitTheme.meal
            )

        case .recoveryWindow:
            return (
                meal.protein >= 35
                    ? WeekFitLocalizedString("meals.library.badge.highProteinPick")
                    : WeekFitLocalizedString("meals.library.badge.recoveryPick"),
                WeekFitLocalizedString("meals.library.recommendation.reason.recoveryWindow"),
                "bolt.shield.fill",
                WeekFitTheme.meal
            )

        case .afterHeatLater:
            return (
                WeekFitLocalizedString("meals.library.badge.preWorkoutPick"),
                WeekFitLocalizedString("meals.library.recommendation.reason.afterHeatLater"),
                "thermometer.sun.fill",
                .orange
            )

        case .heatRecovery:
            return (
                WeekFitLocalizedString("meals.library.badge.heatRecoveryPick"),
                WeekFitLocalizedString("meals.library.recommendation.reason.heatRecovery"),
                "drop.triangle.fill",
                CoachPalette.hydration
            )

        case .recoveryProtection:
            return (
                WeekFitLocalizedString("meals.library.badge.recoveryPick"),
                WeekFitLocalizedString("meals.library.recommendation.reason.recoveryProtection"),
                "heart.fill",
                CoachPalette.recovery
            )

        case .balanced:
            return (
                WeekFitLocalizedString("meals.library.badge.bestForToday"),
                WeekFitLocalizedString("meals.library.recommendation.reason.balanced"),
                "fork.knife",
                WeekFitTheme.meal
            )
        }
    }

    private static func recommendationFactors(
        meal: Meals,
        context: RecommendationContext,
        meals: [Meals],
        input: CoachInputSnapshot
    ) -> [String] {
        let topProtein = meals.map(\.protein).max() ?? meal.protein
        let topCarbs = meals.map(\.carbs).max() ?? meal.carbs
        let lightThreshold = max(450, (meals.map(\.calories).min() ?? meal.calories) + 80)
        let isTopProtein = meal.protein >= topProtein
        let isHighProtein = meal.protein >= 35
        let hasRecoveryCarbs = meal.carbs >= 35
        let isLight = meal.calories <= lightThreshold || meal.calories <= 430
        let isLowFat = meal.fats <= 15

        var factors: [String] = []

        func appendUnique(_ key: String) {
            let text = WeekFitLocalizedString(key)
            guard factors.count < 3, !factors.contains(text) else { return }
            factors.append(text)
        }

        switch context {
        case .morningLight:
            appendUnique(isLight
                ? "meals.library.recommendation.factor.lighterMorningOption"
                : "meals.library.recommendation.factor.controlledMorningCalories")
            appendUnique(isHighProtein
                ? "meals.library.recommendation.factor.proteinFocusedStart"
                : "meals.library.recommendation.factor.keepsBreakfastSimple")
            appendUnique(isLowFat
                ? "meals.library.recommendation.factor.noHeavyDigestion"
                : "meals.library.recommendation.factor.balancedMacros")

        case .middayBalanced, .balanced:
            appendUnique("meals.library.recommendation.factor.bestMacroBalanceToday")
            appendUnique(isHighProtein
                ? "meals.library.recommendation.factor.strongProteinBase"
                : "meals.library.recommendation.factor.steadyProteinSupport")
            appendUnique(hasRecoveryCarbs
                ? "meals.library.recommendation.factor.usefulEnergyCarbs"
                : "meals.library.recommendation.factor.controlledCarbs")

        case .eveningLight:
            appendUnique(isLight
                ? "meals.library.recommendation.factor.lighterCalorieOption"
                : "meals.library.recommendation.factor.controlledEveningChoice")
            appendUnique(isHighProtein
                ? "meals.library.recommendation.factor.highProtein"
                : "meals.library.recommendation.factor.recoverySupport")
            appendUnique(isLowFat
                ? "meals.library.recommendation.factor.easyEveningDigestion"
                : "meals.library.recommendation.factor.simpleCloseToDay")

        case .beforeSessionLight:
            appendUnique(hasRecoveryCarbs
                ? "meals.library.recommendation.factor.usefulPreSessionCarbs"
                : "meals.library.recommendation.factor.lightEnergySupport")
            appendUnique(isLowFat
                ? "meals.library.recommendation.factor.lowerFatBeforeActivity"
                : "meals.library.recommendation.factor.keepsPrepSimple")
            appendUnique("meals.library.recommendation.factor.timedForUpcomingLoad")

        case .afterSessionLater, .recoveryWindow:
            appendUnique(isTopProtein
                ? "meals.library.recommendation.factor.highestProteinMeal"
                : "meals.library.recommendation.factor.highProteinForRecovery")
            appendUnique(hasRecoveryCarbs
                ? "meals.library.recommendation.factor.recoveryCarbsIncluded"
                : "meals.library.recommendation.factor.controlledCarbs")
            appendUnique("meals.library.recommendation.factor.matchesTodaysActivityLoad")

        case .afterHeatLater, .heatRecovery:
            appendUnique(isLight
                ? "meals.library.recommendation.factor.lighterAfterHeat"
                : "meals.library.recommendation.factor.controlledAfterHeat")
            appendUnique(isHighProtein
                ? "meals.library.recommendation.factor.proteinForRecovery"
                : "meals.library.recommendation.factor.recoverySupport")
            appendUnique("meals.library.recommendation.factor.rehydrateFirst")

        case .recoveryProtection:
            appendUnique(isLight
                ? "meals.library.recommendation.factor.lighterRecoveryOption"
                : "meals.library.recommendation.factor.keepsIntakeControlled")
            appendUnique(isHighProtein
                ? "meals.library.recommendation.factor.highProtein"
                : "meals.library.recommendation.factor.supportsRecovery")
            appendUnique("meals.library.recommendation.factor.fitsTodaysCoachFocus")
        }

        while factors.count < 3 {
            if factors.isEmpty {
                appendUnique("meals.library.recommendation.factor.bestMatchFromSavedMeals")
            } else if factors.count == 1 {
                appendUnique("meals.library.recommendation.factor.alignedWithCoachContext")
            } else {
                appendUnique("meals.library.recommendation.factor.goodMacroFitToday")
            }
        }

        return Array(factors.prefix(3))
    }

    private static func timeText(_ minutes: Int) -> String {
        if minutes < 60 {
            return String(
                format: WeekFitLocalizedString("meals.library.recommendation.time.minutesFormat"),
                minutes
            )
        }

        let hours = minutes / 60
        let remainder = minutes % 60

        if remainder == 0 {
            return String(
                format: WeekFitLocalizedString("meals.library.recommendation.time.hoursFormat"),
                hours
            )
        }

        return String(
            format: WeekFitLocalizedString("meals.library.recommendation.time.hoursMinutesFormat"),
            hours,
            remainder
        )
    }
}

// MARK: - Keep-alive gate (skip heavy library body while data unchanged)

private struct MealsBodyGate<MealsContent: View>: View, Equatable {
    let gateRevision: String
    /// Must invalidate on Light/Dark — otherwise opaque chrome (+ / bottom fade)
    /// stays Dark while translucent cards composite onto the new Light root canvas.
    let appearanceInvalidationToken: UInt64
    let content: MealsContent

    static func == (lhs: MealsBodyGate, rhs: MealsBodyGate) -> Bool {
        lhs.gateRevision == rhs.gateRevision
            && lhs.appearanceInvalidationToken == rhs.appearanceInvalidationToken
    }

    var body: some View {
        content
    }
}

private struct RecommendedTodayMealCard: View {
    let recommendation: MealRecommendation
    let onDetails: () -> Void

    @Environment(\.weekFitPalette) private var palette

    private var textPrimary: Color { WeekFitTheme.primaryText }
    private var textSecondary: Color { WeekFitTheme.secondaryText }
    /// Purple is reserved for Coach / AI recommendation surfaces.
    private let accent = WeekFitTheme.coachAccent

    private let thumbSize: CGFloat = 72
    private let cornerRadius: CGFloat = WeekFitSurface.primaryRadius

    private var kcalColor: Color {
        palette.isLight ? accent : WeekFitTheme.meal
    }

    private var shortReason: String {
        let summary = recommendation.factors.prefix(2).joined(separator: " • ")
        if !summary.isEmpty {
            return summary
        }
        return recommendation.reason
    }

    var body: some View {
        Button(action: openDetails) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    coachBadge

                    Text(recommendation.meal.localizedDisplayTitle)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.28)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(String(format: WeekFitLocalizedString("meals.value.kcalFormat"), recommendation.meal.calories))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(kcalColor)
                        .monospacedDigit()
                        .lineLimit(1)

                    Text(shortReason)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                MealLibraryThumbnail(
                    meal: recommendation.meal,
                    size: thumbSize,
                    isCircle: true
                )
            }
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .weekFitPremiumCard(emphasis: .standard, accent: accent, cornerRadius: cornerRadius)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(
                format: WeekFitLocalizedString("meals.coachRecommendation.accessibilityFormat"),
                recommendation.meal.localizedDisplayTitle
            )
        )
        .accessibilityHint(WeekFitLocalizedString("meals.library.openDetailsHint"))
    }

    private func openDetails() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onDetails()
    }

    private var coachBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .semibold))

            Text(WeekFitLocalizedString("meals.library.hero.coachRecommendation"))
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .tracking(0.2)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(accent.opacity(0.92))
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background {
            Capsule(style: .continuous)
                .fill(accent.opacity(0.12))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(accent.opacity(0.16), lineWidth: 1)
                }
        }
    }
}

private struct MealLibraryExpandSheet: View {
    let kind: MealLibraryRowKind
    let items: [Meals]
    var highlightedMealID: String?
    let onSelect: (Meals) -> Void
    let onDelete: (Meals) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: MealLibraryCardMetrics.gridSpacing),
        GridItem(.flexible(), spacing: MealLibraryCardMetrics.gridSpacing)
    ]

    private var filteredItems: [Meals] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { meal in
            meal.localizedDisplayTitle.localizedCaseInsensitiveContains(query)
                || meal.title.localizedCaseInsensitiveContains(query)
                || meal.localizedShortTitle.localizedCaseInsensitiveContains(query)
                || meal.localizedDisplaySubtitle.localizedCaseInsensitiveContains(query)
        }
    }

    private var searchPlaceholderKey: String {
        switch kind {
        case .meal: return "meals.library.search.meals"
        case .food: return "meals.library.search.foods"
        }
    }

    var body: some View {
        ZStack {
            palette.appScreenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Text(WeekFitLocalizedString(kind.sectionTitleKey))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)

                    // Same close control as Weather / Details — not toolbar chrome.
                    WeekFitCloseButton(size: .large) {
                        dismiss()
                    }
                    .fixedSize()
                }
                .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 10)

                searchField
                    .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                    .padding(.bottom, 12)

                if filteredItems.isEmpty {
                    emptySearchState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: MealLibraryCardMetrics.gridSpacing) {
                            ForEach(filteredItems) { meal in
                                MealLibraryGridCard(
                                    meal: meal,
                                    kind: kind,
                                    isHighlighted: highlightedMealID == meal.id,
                                    onDelete: { onDelete(meal) }
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onSelect(meal)
                                }
                            }
                        }
                        .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                        .padding(.top, 4)
                        .padding(.bottom, 28)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.85))
                .accessibilityHidden(true)

            TextField(
                WeekFitLocalizedString(searchPlaceholderKey),
                text: $searchText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(WeekFitTheme.primaryText)
            .tint(WeekFitTheme.meal)
            .focused($isSearchFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityLabel(WeekFitLocalizedString(searchPlaceholderKey))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(WeekFitLocalizedString("common.action.clear"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    palette.isLight
                        ? WeekFitLightTokens.internalTile
                        : WeekFitTheme.whiteOpacity(0.08)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    WeekFitTheme.whiteOpacity(palette.isLight ? 0.0 : 0.06),
                    lineWidth: 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            isSearchFocused = true
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.45))
            Text(WeekFitLocalizedString("meals.library.search.empty"))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
    }
}


