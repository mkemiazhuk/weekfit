import SwiftUI
import SwiftData

private enum MealCreationRoute: Identifiable {
    case builder
    case manualFood

    var id: String {
        switch self {
        case .builder: return "builder"
        case .manualFood: return "manualFood"
        }
    }
}

struct MealsView: View {

    @ObservedObject var authViewModel: AuthViewModel
    let nutritionResult: NutritionResult?

    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var languageManager: AppLanguageManager

    // MARK: - UX-Контексты логирования
    var isQuickLogMode: Bool = false
    var onMealLogged: (() -> Void)? = nil

    @StateObject private var userSettings = WeekFitUserSettings.shared
    @StateObject private var mealsViewModel = MealsViewModel()

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    @State private var showCreationChooser = false
    @State private var creationRoute: MealCreationRoute?
    @State private var selectedMeal: Meals?
    @State private var selectedFood: Meals?
    @State private var showContent = false
    @State private var highlightedMealID: String?
    @State private var mealsLogToastMessage: String?
    @State private var pendingDelete: PendingMealDelete?
    @State private var deleteUndoTask: Task<Void, Never>?

    @State private var showProfile = false

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

    var body: some View {
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
        .overlay(alignment: .bottom) {
            mealsToastOverlay
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.meals")
        .onAppear {
            if !showContent {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    showContent = true
                }
            }

            guard !mealsViewModel.hasLoadedCustomMeals else {
                updateRecommendationIfNeeded(source: "MealsView.onAppear.refreshRecommendation")
                return
            }

            Task {
                await loadCustomMealsAsync()
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
        .onDisappear {
            finalizePendingDelete()
        }
        .onChange(of: mealsViewModel.customMeals) { _, _ in
            updateRecommendationIfNeeded(source: "MealsView.onChange.customMeals")
        }
        .onChange(of: plannedActivities) { _, _ in
            updateRecommendationIfNeeded(source: "MealsView.onChange.plannedActivities")
        }
        .onChange(of: nutritionViewModel.coachStateRefreshID) { _, _ in
            updateRecommendationIfNeeded(source: "MealsView.onChange.nutritionCoachStateRefreshID")
        }
        .onChange(of: languageManager.selectedLanguage) { _, _ in
            updateRecommendationIfNeeded(source: "MealsView.onChange.language")
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
            .weekFitSheetChrome(cornerRadius: 36)
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
        .sheet(isPresented: $showCreationChooser) {
            MealCreationChooserSheet { route in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showCreationChooser = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    creationRoute = route
                }
            }
            .presentationDetents([.height(270)])
            .presentationDragIndicator(.hidden)
            .weekFitSheetChrome(cornerRadius: 36)
        }
        .sheet(item: $creationRoute) { route in
            switch route {
            case .builder:
                MealBuilderView { newMeal in
                    saveMealToLibrary(newMeal, scrollToNewItem: true)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .weekFitSheetChrome(cornerRadius: 36)

            case .manualFood:
                CustomMealBuilderView(existingMeals: mealsViewModel.customMeals) { newMeal in
                    saveMealToLibrary(newMeal, scrollToNewItem: true)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .weekFitSheetChrome(cornerRadius: 36)
            }
        }
    }
    
    @MainActor
    private func loadCustomMealsAsync() async {
        let storage = userSettings.customMealsStorage
        let result = await mealsViewModel.loadCustomMealsAsync(storage: storage)
        mealsViewModel.applyLoadedCustomMeals(result.meals)

        if let encoded = result.encodedStorage {
            userSettings.setCustomMealsStorage(encoded)
        }
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
        List {
            customEmptyState
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
        List {
            if shouldShowRecommendation, let recommendation = visibleRecommendation {
                coachRecommendationHero(recommendation)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !displayedMealItems.isEmpty {
                sectionHeader(
                    title: "meals.library.section.meals",
                    count: displayedMealItems.count,
                    icon: "fork.knife"
                )
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 9, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                libraryRows(displayedMealItems)
            }

            if !sortedFoodItems.isEmpty {
                sectionHeader(
                    title: "meals.library.section.foods",
                    count: sortedFoodItems.count,
                    icon: "takeoutbag.and.cup.and.straw.fill"
                )
                .listRowInsets(EdgeInsets(top: displayedMealItems.isEmpty ? 2 : 10, leading: 16, bottom: 9, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                libraryRows(sortedFoodItems)
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

    @ViewBuilder
    private func coachRecommendationHero(_ recommendation: MealRecommendation) -> some View {
        RecommendedTodayMealCard(
            recommendation: recommendation,
            onLogNow: {
                logRecommendedMeal(recommendation)
            },
            onDetails: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedMeal = recommendation.meal
            }
        )
        .id("coachRecommendationHero")
    }

    private var mealsToastOverlay: some View {
        VStack(spacing: 8) {
            if let mealsLogToastMessage {
                mealsBannerToast(message: mealsLogToastMessage, accent: WeekFitTheme.meal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if pendingDelete != nil {
                deleteUndoToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, isQuickLogMode ? 78 : 118)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: mealsLogToastMessage)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: pendingDelete?.meal.id)
    }

    private func mealsBannerToast(message: String, accent: Color) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.94))
            .lineLimit(1)
            .minimumScaleFactor(0.84)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background {
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.92))
                    .shadow(color: accent.opacity(0.18), radius: 10, y: 4)
            }
    }

    private var deleteUndoToast: some View {
        HStack(spacing: 12) {
            Text(
                String(
                    format: WeekFitLocalizedString("meals.library.toast.deletedFormat"),
                    pendingDelete?.meal.localizedDisplayTitle ?? ""
                )
            )
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(textPrimary.opacity(0.92))
            .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                undoPendingDelete()
            } label: {
                Text(WeekFitLocalizedString("common.action.undo"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.meal.opacity(0.96))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardSecondary.opacity(0.94))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 14, y: 6)
    }

    private var bottomSpacerRow: some View {
        Color.clear
            .frame(height: isQuickLogMode ? 70 : 96)
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
    private func libraryRows(_ items: [Meals]) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, meal in
            HeroMealLibraryRow(
                meal: meal,
                isQuickLogMode: isQuickLogMode,
                isRecommended: rowShowsRecommendationBadge(for: meal, in: items, at: index),
                recommendationBadge: rowRecommendationBadge(for: meal, in: items, at: index),
                recommendationIcon: rowRecommendationIcon(for: meal, in: items, at: index),
                isHighlighted: highlightedMealID == meal.id
            ) {
                executeDirectQuickLog(meal)
            }
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
                        requestDeleteCustomMeal(meal)
                    } label: {
                        Label(WeekFitLocalizedString("common.action.delete"), systemImage: "trash.fill")
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 7, trailing: 16))
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
    
    private func sectionHeader(
        title: String,
        count: Int,
        icon: String,
        showCount: Bool = true
    ) -> some View {
        HStack(alignment: .center, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11.6, weight: .semibold))
                .foregroundStyle(WeekFitTheme.meal.opacity(0.88))
                .frame(width: 16)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(WeekFitLocalizedString(title))
                    .font(.system(size: 15.6, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(0.84))
                    .tracking(-0.22)

                if showCount {
                    Text("·")
                        .font(.system(size: 15.0, weight: .semibold, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.30))

                    Text("\(count)")
                        .font(.system(size: 15.0, weight: .semibold, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.46))
                        .tracking(-0.12)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private var customEmptyState: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showCreationChooser = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {

                HStack(alignment: .top, spacing: 14) {

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.045))
                            .frame(width: 44, height: 44)

                        Image(systemName: "fork.knife")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(textPrimary.opacity(0.90))
                    }

                    VStack(alignment: .leading, spacing: 6) {

                        Text(WeekFitLocalizedString("meals.createYourFirstFoodOrMeal"))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary)

                        Text(WeekFitLocalizedString("meals.saveFoodsAndMealsYouEatOftenAndLog"))
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(textSecondary.opacity(0.72))

                        Text(WeekFitLocalizedString("meals.coachRecommendationsWillUseYourSavedMeals"))
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(textSecondary.opacity(0.72))
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    benefitChip(
                        icon: "clock.fill",
                        title: "meals.library.benefit.fastLogging"
                    )

                    benefitChip(
                        icon: "brain.head.profile",
                        title: "meals.library.benefit.coach"
                    )

                    benefitChip(
                        icon: "sparkles",
                        title: "meals.library.benefit.reusable"
                    )
                }
                .padding(.top, 2)
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardSecondary.opacity(0.42))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.16), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func benefitChip(
        icon: String,
        title: String
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WeekFitTheme.meal.opacity(0.9))

            Text(WeekFitLocalizedString(title))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.78))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.035))
        }
    }

    private func executeDirectQuickLog(_ meal: Meals) {
        let quickActivity = PlannedActivity(
            date: Date(),
            type: PlannerType.meal.title,
            title: meal.title,
            durationMinutes: 20,
            icon: PlannerType.meal.icon,
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

        modelContext.insert(quickActivity)
        try? modelContext.save()

        onMealLogged?()
    }

    private func logRecommendedMeal(_ recommendation: MealRecommendation) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        executeDirectQuickLog(recommendation.meal)
        presentMealsLogToast(for: recommendation.meal)
    }

    private func presentMealsLogToast(for meal: Meals) {
        let message = String(
            format: WeekFitLocalizedString("quickLog.toast.singleCaloriesFormat"),
            meal.localizedDisplayTitle,
            meal.calories
        )

        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            mealsLogToastMessage = message
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                mealsLogToastMessage = nil
            }
        }
    }

    private struct PendingMealDelete {
        let meal: Meals
        let originalFilename: String?
        let thumbnailFilename: String?
    }

    private func requestDeleteCustomMeal(_ meal: Meals) {
        finalizePendingDelete()

        withAnimation(.easeInOut(duration: 0.22)) {
            mealsViewModel.customMeals = CustomMealStore.remove(meal, from: mealsViewModel.customMeals)
            saveCustomMeals()
        }

        pendingDelete = PendingMealDelete(
            meal: meal,
            originalFilename: meal.localPhotoFilename,
            thumbnailFilename: meal.localPhotoThumbnailFilename
        )

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        deleteUndoTask?.cancel()
        deleteUndoTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            finalizePendingDelete()
        }
    }

    private func undoPendingDelete() {
        guard let pendingDelete else { return }

        deleteUndoTask?.cancel()
        deleteUndoTask = nil

        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            mealsViewModel.customMeals = CustomMealStore.upsert(
                pendingDelete.meal,
                into: mealsViewModel.customMeals
            )
            saveCustomMeals()
            self.pendingDelete = nil
        }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func finalizePendingDelete() {
        deleteUndoTask?.cancel()
        deleteUndoTask = nil

        guard let pendingDelete else { return }

        MealPhotoStore.deletePhotoSet(
            originalFilename: pendingDelete.originalFilename,
            thumbnailFilename: pendingDelete.thumbnailFilename
        )
        self.pendingDelete = nil
    }

    private func saveMealToLibrary(_ meal: Meals, scrollToNewItem: Bool = false) {
        let wasNew = !mealsViewModel.customMeals.contains(where: { $0.id == meal.id })

        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            mealsViewModel.customMeals = CustomMealStore.upsert(meal, into: mealsViewModel.customMeals)
            saveCustomMeals()
        }

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

    private func saveCustomMeals() {
        userSettings.setCustomMealsStorage(CustomMealStore.encode(mealsViewModel.customMeals))
    }
    
    private var createActionTitle: String {
        "meals.createFoodOrMeal"
    }

    private var bottomFixedActionArea: some View {
        VStack(spacing: 0) {
            if !isQuickLogMode {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showCreationChooser = true
                } label: {
                    HStack(spacing: 9) {
                        Spacer(minLength: 0)

                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(WeekFitTheme.meal.opacity(0.92))

                        Text(WeekFitLocalizedString(createActionTitle))
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(textPrimary.opacity(0.92))
                            .tracking(-0.10)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        WeekFitTheme.meal.opacity(0.16),
                                        WeekFitTheme.meal.opacity(0.09)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(WeekFitTheme.meal.opacity(0.20), lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 78)
            } else {
                bottomFadeOnly
                    .frame(height: 66)
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


private struct MealCreationChooserSheet: View {
    let onSelect: (MealCreationRoute) -> Void

    private let background = WeekFitTheme.backgroundColor
    private let card = WeekFitTheme.elevatedCard
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let accent = WeekFitTheme.meal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.14))
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
                    route: .builder
                )

                optionRow(
                    icon: "camera.fill",
                    title: "meals.creation.customFood.title",
                    subtitle: "meals.creation.customFood.subtitle",
                    route: .manualFood
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            background
                .ignoresSafeArea()
        }
    }

    private func optionRow(
        icon: String,
        title: String,
        subtitle: String,
        route: MealCreationRoute
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

                    Text(WeekFitLocalizedString(subtitle))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.68))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(textSecondary.opacity(0.46))
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(card.opacity(0.70))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
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
    @State private var showEditForm = false

    private let background = WeekFitTheme.backgroundColor
    private let cardBackground = WeekFitTheme.cardBackground
    private let elevatedCard = WeekFitTheme.elevatedCard
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let accent = WeekFitTheme.meal

    var body: some View {
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
                        nutritionSummary
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
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                CircleIconButton(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(WeekFitLocalizedString("meals.foodDetails"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.75)
                    .lineLimit(1)

                Text(WeekFitLocalizedString("meals.reviewServingSizeAndNutrition"))
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            if !isQuickLogMode {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showEditForm = true
                } label: {
                    CircleIconButton(systemName: "square.and.pencil")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 2)
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
        }
        .padding(.horizontal, 13)
        .padding(.top, 12)
        .padding(.bottom, 13)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            elevatedCard.opacity(0.96),
                            cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
        .shadow(color: WeekFitTheme.cardShadow.opacity(0.66), radius: 14, y: 7)
    }

    private var nutritionSummary: some View {
        HStack(spacing: 8) {
            nutritionTile("nutrition.metric.calories", "\(food.calories)", "common.unit.kcal", isPrimary: true)
            nutritionTile("nutrition.metric.protein", "\(food.protein)", "common.unit.gramShort")
            nutritionTile("nutrition.metric.carbs", "\(food.carbs)", "common.unit.gramShort")
            nutritionTile("nutrition.metric.fats", "\(food.fats)", "common.unit.gramShort")
        }
    }

    private func nutritionTile(
        _ title: String,
        _ value: String,
        _ unit: String,
        isPrimary: Bool = false
    ) -> some View {
        VStack(spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: isPrimary ? 15.8 : 15.2, weight: .bold, design: .rounded))
                    .foregroundStyle(isPrimary ? accent.opacity(0.94) : textPrimary.opacity(0.94))

                Text(WeekFitLocalizedString(unit))
                    .font(.system(size: 9.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(isPrimary ? accent.opacity(0.76) : textSecondary.opacity(0.70))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            Text(WeekFitLocalizedString(title))
                .font(.system(size: 9.4, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.74))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isPrimary ? accent.opacity(0.052) : Color.white.opacity(0.030))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(isPrimary ? accent.opacity(0.17) : Color.white.opacity(0.038), lineWidth: 1)
        }
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
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.038))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.045), lineWidth: 1)
            }
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
                    background.opacity(0),
                    background.opacity(0.62),
                    background.opacity(0.96),
                    background
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
            icon: PlannerType.meal.icon,
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
        modelContext.insert(activity)
        try? modelContext.save()
        onFoodLogged?()
    }
}

private struct CircleIconButton: View {
    let systemName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.045))
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.065), lineWidth: 1)
                }

            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WeekFitTheme.primaryText.opacity(0.88))
        }
        .frame(width: 38, height: 38)
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

private struct RecommendedTodayMealCard: View {
    let recommendation: MealRecommendation
    let onLogNow: () -> Void
    let onDetails: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let cardBackground = WeekFitTheme.cardBackground

    private var displayedFactors: [String] {
        let usesCompactHero = verticalSizeClass == .compact || UIScreen.main.bounds.height < 860
        let limit = usesCompactHero ? 2 : 3
        return Array(recommendation.factors.prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            badge

            VStack(alignment: .leading, spacing: 3) {
                Text(recommendation.meal.localizedDisplayTitle)
                    .font(.system(size: 19.0, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(0.98))
                    .tracking(-0.62)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(recommendation.reason)
                    .font(.system(size: 12.0, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.68))
                    .lineSpacing(1.8)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(displayedFactors, id: \.self) { factor in
                    factorRow(factor)
                }
            }

            HStack(spacing: 8) {
                Button(action: onLogNow) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12, weight: .bold))

                        Text(WeekFitLocalizedString("meals.library.hero.logNow"))
                            .font(.system(size: 12.8, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.black.opacity(0.84))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background {
                        Capsule(style: .continuous)
                            .fill(recommendation.color.opacity(0.88))
                    }
                }
                .buttonStyle(.plain)

                Button(action: onDetails) {
                    Text(WeekFitLocalizedString("meals.library.hero.details"))
                        .font(.system(size: 12.6, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary.opacity(0.88))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.045))
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 1)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            recommendation.color.opacity(0.16),
                            Color.white.opacity(0.040)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: recommendation.color.opacity(0.055), radius: 14, y: 7)
        .shadow(color: Color.black.opacity(0.16), radius: 12, y: 6)
    }

    private var badge: some View {
        HStack(spacing: 7) {
            Image(systemName: recommendation.icon)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(recommendation.color)

            Text(recommendation.badge)
                .font(.system(size: 10.0, weight: .bold, design: .rounded))
                .tracking(0.15)
                .foregroundStyle(recommendation.color)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background {
            Capsule()
                .fill(recommendation.color.opacity(0.10))
        }
    }

    private func factorRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10.2, weight: .bold))
                .foregroundStyle(recommendation.color.opacity(0.95))
                .frame(width: 12)

            Text(text)
                .font(.system(size: 11.4, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.84)
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    recommendation.color.opacity(0.080),
                    cardBackground.opacity(0.58),
                    Color.black.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.28), location: 0.0),
                    .init(color: .black.opacity(0.16), location: 0.56),
                    .init(color: .black.opacity(0.02), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}


