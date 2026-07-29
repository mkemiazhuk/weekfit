import SwiftUI
import SwiftData
import WeekFitPlanner

private enum MealCreationRoute {
    case builder
    case manualFood
}

private enum MealCreationStep: Equatable {
    case chooser
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

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    @State private var showCreationSheet = false
    @State private var creationStep: MealCreationStep = .chooser
    @State private var creationDetent: PresentationDetent = .height(270)
    @State private var selectedMeal: Meals?
    @State private var selectedFood: Meals?
    @State private var showContent = false
    @State private var highlightedMealID: String?

    @State private var showProfile = false
    @AppStorage(OnboardingStore.Keys.introMeals) private var mealsIntroDismissed = false

    private let background = WeekFitTheme.backgroundColor
    private let cardSecondary = WeekFitTheme.cardSecondary
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let textTertiary = WeekFitTheme.tertiaryText

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
            WeekFitTheme.appBackground
                .ignoresSafeArea()

            ambientBackground

            WeekFitScreenContainer {

                WeekFitScreenHeader(
                    title: WeekFitLocalizedString("meals.library.title"),
                    subtitle: headerSubtitle,
                    initials: userSettings.profileInitials,
                    hasProfileName: userSettings.hasProfileName,
                    showAvatar: true
                ) {
                    showProfile = true
                }

            } content: {
                mealsContent
            }
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
            .weekFitSheetChrome(cornerRadius: 36)
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
            .weekFitSheetChrome(cornerRadius: 36)
        }
        .weekFitSettingsSheet(isPresented: $showProfile)
        .sheet(isPresented: $showCreationSheet) {
            // One sheet only — SwiftUI cannot present a second sheet on top of this one.
            MealCreationSheetHost(
                step: $creationStep,
                detent: $creationDetent,
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
            creationStep = .chooser
            creationDetent = .height(270)
        }
    }

    private func openCreationChooser() {
        creationStep = .chooser
        creationDetent = .height(270)
        showCreationSheet = true
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
        List {
            ForEach(0..<3, id: \.self) { _ in
                MealsLibrarySkeletonRow()
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 7, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            bottomSpacerRow
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .listRowSpacing(0)
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }

    private var emptyLibraryList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !mealsIntroDismissed {
                OnboardingContextualIntroCard(
                    title: WeekFitLocalizedString("onboarding.intro.meals.title"),
                    message: WeekFitLocalizedString("onboarding.intro.meals.body"),
                    accent: WeekFitTheme.meal
                ) {
                    mealsIntroDismissed = true
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            List {
                customEmptyState
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                emptyBottomSpacerRow
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowSpacing(0)
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
        }
    }

    private var catalogErrorList: some View {
        List {
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
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            bottomSpacerRow
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .listRowSpacing(0)
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }

    private var populatedLibraryList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !mealsIntroDismissed {
                OnboardingContextualIntroCard(
                    title: WeekFitLocalizedString("onboarding.intro.meals.title"),
                    message: WeekFitLocalizedString("onboarding.intro.meals.body"),
                    accent: WeekFitTheme.meal
                ) {
                    mealsIntroDismissed = true
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            List {
                if shouldShowRecommendation, let recommendation = visibleRecommendation {
                    coachRecommendationHero(recommendation)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !displayedMealItems.isEmpty {
                    sectionHeader(
                        title: "meals.library.section.meals",
                        count: displayedMealItems.count,
                        icon: "fork.knife",
                        prominence: .primary
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    libraryRows(displayedMealItems, kind: .meal)
                }

                if !sortedFoodItems.isEmpty {
                    sectionHeader(
                        title: "meals.library.section.foods",
                        count: sortedFoodItems.count,
                        icon: "takeoutbag.and.cup.and.straw.fill",
                        prominence: .secondary
                    )
                    .listRowInsets(EdgeInsets(top: displayedMealItems.isEmpty ? 8 : 16, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    libraryRows(sortedFoodItems, kind: .food)
                }

                bottomSpacerRow
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowSpacing(0)
            .scrollIndicators(.hidden)
            .animation(
                .spring(response: 0.38, dampingFraction: 0.86),
                value: visibleRecommendation?.meal.id
            )
            .frame(maxHeight: .infinity)
        }
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

    private var bottomSpacerRow: some View {
        Color.clear
            .frame(height: isQuickLogMode ? 52 : 56)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private var emptyBottomSpacerRow: some View {
        Color.clear
            .frame(height: isQuickLogMode ? 36 : 44)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private var ambientBackground: some View {
        WeekFitTheme.mealsAmbient
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }


    @ViewBuilder
    private func libraryRows(_ items: [Meals], kind: MealLibraryRowKind) -> some View {
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
            .id(meal.id)
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if meal.isFoodProduct {
                    selectedFood = meal
                } else {
                    selectedMeal = meal
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !isQuickLogMode {
                    Button(role: .destructive) {
                        deleteCustomMeal(meal)
                    } label: {
                        Label(WeekFitLocalizedString("common.action.delete"), systemImage: "trash.fill")
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: kind == .meal ? 8 : 7, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
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

    private func sectionHeader(
        title: String,
        count: Int,
        icon: String,
        prominence: SectionHeaderProminence = .primary,
        showCount: Bool = true
    ) -> some View {
        let titleOpacity: Double = prominence == .primary ? 0.76 : 0.62
        let iconOpacity: Double = prominence == .primary ? 0.58 : 0.46
        let badgeOpacity: Double = prominence == .primary ? 0.58 : 0.48
        let titleWeight: Font.Weight = prominence == .primary ? .semibold : .medium

        return HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WeekFitTheme.meal.opacity(iconOpacity))
                .frame(width: 14, alignment: .center)
                .accessibilityHidden(true)

            Text(WeekFitLocalizedString(title))
                .font(.system(size: 13, weight: titleWeight, design: .rounded))
                .foregroundStyle(textSecondary.opacity(titleOpacity))
                .tracking(-0.06)

            if showCount {
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(badgeOpacity))
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background {
                        Capsule(style: .continuous)
                            .fill(WeekFitTheme.whiteOpacity(prominence == .primary ? 0.06 : 0.045))
                    }
                    .accessibilityLabel("\(count)")
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var customEmptyState: some View {
        MealLibraryEmptyStateCard(
            title: WeekFitLocalizedString("meals.emptyState.expanded.title"),
            message: WeekFitLocalizedString("meals.emptyState.expanded.message"),
            ctaTitle: WeekFitLocalizedString("meals.emptyState.expanded.cta"),
            benefits: [
                .init(
                    id: "build",
                    icon: "fork.knife",
                    title: WeekFitLocalizedString("meals.emptyState.expanded.benefit.build.title"),
                    subtitle: WeekFitLocalizedString("meals.emptyState.expanded.benefit.build.subtitle")
                ),
                .init(
                    id: "scan",
                    icon: "barcode.viewfinder",
                    title: WeekFitLocalizedString("meals.emptyState.expanded.benefit.scan.title"),
                    subtitle: WeekFitLocalizedString("meals.emptyState.expanded.benefit.scan.subtitle")
                ),
                .init(
                    id: "reuse",
                    icon: "arrow.triangle.2.circlepath",
                    title: WeekFitLocalizedString("meals.emptyState.expanded.benefit.reuse.title"),
                    subtitle: WeekFitLocalizedString("meals.emptyState.expanded.benefit.reuse.subtitle")
                )
            ],
            presentation: .expanded
        ) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            openCreationChooser()
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
                imageName: meal.imageName
            ),
            imageName: meal.imageName,
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

    private var createActionTitle: String {
        "meals.createFoodOrMeal"
    }

    private var bottomFixedActionArea: some View {
        VStack(spacing: 0) {
            if !isQuickLogMode && hasAnyItems {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    openCreationChooser()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))

                        Text(WeekFitLocalizedString(createActionTitle))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .tracking(-0.10)
                    }
                    .foregroundStyle(WeekFitTheme.meal.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        WeekFitTheme.meal.opacity(0.14),
                                        WeekFitTheme.meal.opacity(0.07)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                WeekFitTheme.whiteOpacity(0.035),
                                                WeekFitTheme.whiteOpacity(0.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        WeekFitTheme.meal.opacity(0.26),
                                        WeekFitTheme.meal.opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.22), radius: 10, y: 4)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(MealsCreateCTAButtonStyle())
                .accessibilityIdentifier("meals.create")
                .accessibilityLabel(WeekFitLocalizedString(createActionTitle))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 72)
            } else {
                bottomFadeOnly
                    .frame(height: 64)
            }
        }
        .background {
            bottomFadeGradient
        }
    }

    private var bottomFadeOnly: some View {
        bottomFadeGradient
            .frame(height: 66)
            .allowsHitTesting(false)
    }

    private var bottomFadeGradient: some View {
        LinearGradient(
            colors: [
                background.opacity(0),
                background.opacity(0.58),
                background.opacity(0.94),
                background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}


private struct MealCreationSheetHost: View {
    @Binding var step: MealCreationStep
    @Binding var detent: PresentationDetent

    let existingMeals: [Meals]
    let onSaved: (Meals) -> Void

    var body: some View {
        Group {
            switch step {
            case .chooser:
                MealCreationChooserSheet { route in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    // Expand first while both detents are still allowed, then swap content.
                    detent = .large
                    switch route {
                    case .builder:
                        ProductAnalytics.mealBuilderStarted(mode: .new, source: .meals)
                        ProductAnalytics.trackScreen(.mealBuilder)
                        step = .builder
                    case .manualFood:
                        ProductAnalytics.foodLoggingStarted(method: .manual, source: .meals)
                        step = .manualFood
                    }
                }

            case .builder:
                MealBuilderView(onSave: onSaved)

            case .manualFood:
                CustomMealBuilderView(existingMeals: existingMeals, onSave: onSaved)
            }
        }
        .presentationDetents(
            step == .chooser ? [.height(270), .large] : [.large],
            selection: $detent
        )
        .presentationDragIndicator(step == .chooser ? .hidden : .visible)
        .weekFitSheetChrome(cornerRadius: 36)
    }
}

private struct MealCreationChooserSheet: View {
    let onSelect: (MealCreationRoute) -> Void

    private let card = WeekFitTheme.elevatedCard
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let accent = WeekFitTheme.meal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(WeekFitTheme.whiteOpacity(0.14))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(WeekFitLocalizedString("meals.create"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.55)

                Text(WeekFitLocalizedString("meals.chooseHowYouWantToAddFood"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.76))
            }

            VStack(spacing: 10) {
                optionRow(
                    icon: "square.grid.2x2.fill",
                    title: "meals.creation.builder.title",
                    subtitle: "meals.creation.builder.subtitle",
                    route: .builder,
                    accessibilityId: "meals.creation.builder"
                )

                optionRow(
                    icon: "camera.fill",
                    title: "meals.creation.customFood.title",
                    subtitle: "meals.creation.customFood.subtitle",
                    route: .manualFood,
                    accessibilityId: "meals.creation.customFood"
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.clear)
    }

    private func optionRow(
        icon: String,
        title: String,
        subtitle: String,
        route: MealCreationRoute,
        accessibilityId: String
    ) -> some View {
        Button {
            onSelect(route)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))

                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(accent.opacity(0.94))
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(WeekFitLocalizedString(title))
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.15)
                        .lineLimit(1)

                    Text(WeekFitLocalizedString(subtitle))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.68))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(textSecondary.opacity(0.46))
            }
            .padding(14)
            .weekFitPremiumCard(
                emphasis: .standard,
                accent: accent,
                cornerRadius: 20
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
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
    @EnvironmentObject private var languageManager: AppLanguageManager
    @State private var showEditForm = false

    private let background = WeekFitTheme.appBackground
    private let cardBackground = WeekFitTheme.cardBackground
    private let elevatedCard = WeekFitTheme.elevatedCard
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let accent = WeekFitTheme.meal

    var body: some View {
        let _ = languageManager.selectedLanguage

        ZStack {
            background.ignoresSafeArea()
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
                    WeekFitTheme.backgroundColor.opacity(0),
                    WeekFitTheme.backgroundColor.opacity(0.62),
                    WeekFitTheme.backgroundColor.opacity(0.96),
                    WeekFitTheme.backgroundColor
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
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

// MARK: - Keep-alive gate (skip heavy library body while tab inactive)

private struct MealsBodyGate<MealsContent: View>: View, Equatable {
    let gateRevision: String
    let content: MealsContent

    static func == (lhs: MealsBodyGate, rhs: MealsBodyGate) -> Bool {
        lhs.gateRevision == rhs.gateRevision
    }

    var body: some View {
        content
    }
}

private struct RecommendedTodayMealCard: View {
    let recommendation: MealRecommendation
    let onDetails: () -> Void

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    /// Purple is reserved for Coach / AI recommendation surfaces.
    private let accent = WeekFitTheme.coachAccent

    private let thumbSize: CGFloat = 64
    private let cornerRadius: CGFloat = 20

    private var shortReason: String {
        let summary = recommendation.factors.prefix(2).joined(separator: " • ")
        if !summary.isEmpty {
            return summary
        }
        return recommendation.reason
    }

    var body: some View {
        Button(action: openDetails) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    coachBadge

                    Text(recommendation.meal.localizedDisplayTitle)
                        .font(.system(size: 16.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.28)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(String(format: WeekFitLocalizedString("meals.value.kcalFormat"), recommendation.meal.calories))
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.66))
                        .monospacedDigit()
                        .lineLimit(1)

                    Text(shortReason)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.48))
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                MealLibraryThumbnail(
                    meal: recommendation.meal,
                    size: thumbSize,
                    cornerRadius: 16
                )
            }
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(MealsCreateCTAButtonStyle(pressedScale: 0.985))
        .accessibilityLabel(
            String(
                format: WeekFitLocalizedString("meals.coachRecommendation.accessibilityFormat"),
                recommendation.meal.localizedDisplayTitle
            )
        )
        .accessibilityHint(WeekFitLocalizedString("meals.library.openDetailsHint"))
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .elevated, accent: accent, cornerRadius: cornerRadius)
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
        .foregroundStyle(accent.opacity(0.88))
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background {
            Capsule(style: .continuous)
                .fill(accent.opacity(0.11))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(accent.opacity(0.16), lineWidth: 1)
                }
        }
    }
}

private struct MealsCreateCTAButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.982

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

