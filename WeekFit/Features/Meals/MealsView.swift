import SwiftUI
import SwiftData

private enum MealIngredientGroup: String, CaseIterable, Identifiable {
    case bases
    case proteins
    case vegetables
    case extras

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bases: return "Bases"
        case .proteins: return "Proteins"
        case .vegetables: return "Vegetables"
        case .extras: return "Extras"
        }
    }

    var singularTitle: String {
        switch self {
        case .bases: return "base"
        case .proteins: return "protein"
        case .vegetables: return "vegetable"
        case .extras: return "extra"
        }
    }

    var icon: String {
        switch self {
        case .bases: return "circle.grid.2x2.fill"
        case .proteins: return "bolt.fill"
        case .vegetables: return "leaf.fill"
        case .extras: return "sparkles"
        }
    }

    var chipTitle: String {
        switch self {
        case .bases: return "Base"
        case .proteins: return "Protein"
        case .vegetables: return "Veggies"
        case .extras: return "Extras"
        }
    }

    var accent: Color {
        switch self {
        case .bases:
            return Color(red: 0.86, green: 0.62, blue: 0.30)
        case .proteins:
            return Color(red: 0.96, green: 0.42, blue: 0.25)
        case .vegetables:
            return Color(red: 0.42, green: 0.78, blue: 0.42)
        case .extras:
            return Color(red: 0.96, green: 0.76, blue: 0.22)
        }
    }
}

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

    // MARK: - UX-Контексты логирования
    var isQuickLogMode: Bool = false
    var onMealLogged: (() -> Void)? = nil

    @StateObject private var userSettings = WeekFitUserSettings.shared

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    @State private var customMeals: [Meals] = []

    @State private var showCreationChooser = false
    @State private var creationRoute: MealCreationRoute?
    @State private var selectedMeal: Meals?
    @State private var selectedFood: Meals?
    @State private var showContent = false
    @State private var cachedRecommendation: MealRecommendation?
    @State private var lastRecommendationSignature = ""

    @State private var showProfile = false
    @State private var selectedDate = Date()

    private let background = WeekFitTheme.backgroundColor
    private let cardSecondary = WeekFitTheme.cardSecondary
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let textTertiary = WeekFitTheme.tertiaryText

    // MARK: - Library groups
    
    private var mealItems: [Meals] {
        customMeals.filter { $0.isRecipeMeal && resolvedLibraryType($0) != .ingredient }
    }

    private var foodItems: [Meals] {
        customMeals.filter { $0.isFoodProduct }
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

    private var sortedFoodItems: [Meals] {
        foodItems.sorted { $0.shortTitle < $1.shortTitle }
    }

    private var hasAnyItems: Bool {
        !mealItems.isEmpty || !foodItems.isEmpty
    }

    private var headerSubtitle: String {
        if customMeals.isEmpty {
            return "Empty"
        }

        let total = mealItems.count + foodItems.count
        let format = total == 1 ? "%lld item" : "%lld items"
        return String(format: WeekFitLocalizedString(format), total)
    }

    var body: some View {
        ZStack(alignment: .top) {
            WeekFitTheme.appBackground
                .ignoresSafeArea()

            ambientBackground

            WeekFitScreenContainer {

                WeekFitScreenHeader(
                    title: WeekFitLocalizedString("meals.library.title"),
                    subtitle: selectedDateTitle,
                    initials: userSettings.profileInitials,
                    showAvatar: true
                ) {
                    showProfile = true
                }

            } content: {
                mealsContent
            }
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            guard !showContent else { return }
            showContent = true

            Task {
                await loadCustomMealsAsync()
                updateRecommendationIfNeeded(source: "MealsView.onAppear.loadCustomMeals")
            }
        }
        .onChange(of: customMeals) { _, _ in
            updateRecommendationIfNeeded(source: "MealsView.onChange.customMeals")
        }
        .onChange(of: plannedActivities) { _, _ in
            updateRecommendationIfNeeded(source: "MealsView.onChange.plannedActivities")
        }
        .onChange(of: nutritionViewModel.coachStateRefreshID) { _, _ in
            updateRecommendationIfNeeded(source: "MealsView.onChange.nutritionCoachStateRefreshID")
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
        }
        .sheet(item: $selectedFood) { food in
            CustomFoodDetailsView(
                food: food,
                existingMeals: customMeals,
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
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
            .presentationDetents([.large])
            .presentationCornerRadius(36)
            .presentationDragIndicator(.hidden)
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
            .presentationBackground(WeekFitTheme.backgroundColor)
            .presentationCornerRadius(36)
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $creationRoute) { route in
            switch route {
            case .builder:
                MealBuilderView { newMeal in
                    saveMealToLibrary(newMeal)
                }
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .presentationDragIndicator(.hidden)

            case .manualFood:
                CustomMealBuilderView(existingMeals: customMeals) { newMeal in
                    saveMealToLibrary(newMeal)
                }
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .presentationDragIndicator(.hidden)
            }
        }
    }
    
    @MainActor
    private func loadCustomMealsAsync() async {
        let storage = userSettings.customMealsStorage

        let result = await Task.detached(priority: .utility) {
            let loadedMeals = CustomMealStore.load(from: storage)
            let migratedMeals = loadedMeals.map { MealPhotoStore.ensureThumbnail(for: $0) }
            let encoded = migratedMeals != loadedMeals
                ? CustomMealStore.encode(migratedMeals)
                : nil

            return (migratedMeals, encoded)
        }.value

        customMeals = result.0

        if let encoded = result.1 {
            userSettings.setCustomMealsStorage(encoded)
        }
    }
    
    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "E, MMM d"
        return formatter.string(from: selectedDate)
    }


    private var plannedActivitiesForSelectedDate: [PlannedActivity] {
        let calendar = Calendar.current

        return plannedActivities.filter { activity in
            calendar.isDate(activity.date, inSameDayAs: selectedDate)
        }
    }

    private func updateRecommendationIfNeeded(source: String) {
        let signature = recommendationSignature()
        guard signature != lastRecommendationSignature else { return }

        let nextRecommendation: MealRecommendation?
        if let guidance = nutritionViewModel.coachGuidanceSnapshot?.guidance {
            nextRecommendation = MealRecommendationEngine.make(
                guidance: guidance,
                meals: mealItems,
                now: Date()
            )
        } else {
            nextRecommendation = nil
        }

        lastRecommendationSignature = signature
        if cachedRecommendation != nextRecommendation {
            cachedRecommendation = nextRecommendation
        }
    }

    private func recommendationSignature() -> String {
        let snapshot = nutritionViewModel.coachMetricsSnapshot
        let goals = snapshot?.result.goals ?? nutritionResult?.goals
        let metrics = snapshot?.metrics
        let guidanceID = nutritionViewModel.coachGuidanceSnapshot?.id.uuidString ?? "guidance=nil"
        let day = Calendar.current.startOfDay(for: selectedDate).timeIntervalSince1970
        let activitySignature = plannedActivitiesForSelectedDate
            .sorted { $0.id < $1.id }
            .map { activity in
                [
                    activity.id,
                    "\(Int(activity.date.timeIntervalSince1970 / 60))",
                    activity.type,
                    activity.title,
                    "\(activity.durationMinutes)",
                    "\(activity.calories)",
                    "\(activity.protein)",
                    "\(activity.carbs)",
                    "\(activity.fats)",
                    "\(activity.fiber)",
                    "\(activity.isCompleted)",
                    "\(activity.isSkipped)",
                    activity.imageName
                ].joined(separator: ":")
            }
            .joined(separator: "|")
        let mealSignature = mealItems
            .sorted { $0.id < $1.id }
            .map { meal in
                [
                    meal.id,
                    meal.title,
                    "\(meal.calories)",
                    "\(meal.protein)",
                    "\(meal.carbs)",
                    "\(meal.fats)",
                    "\(meal.fiber)"
                ].joined(separator: ":")
            }
            .joined(separator: "|")

        return [
            sourceNutritionSignature(),
            snapshot?.id.uuidString ?? "snapshot=nil",
            guidanceID,
            "\(Int(day / 86_400))",
            String(format: "%.1f", metrics?.calories ?? -1),
            String(format: "%.1f", metrics?.protein ?? -1),
            String(format: "%.1f", metrics?.carbs ?? -1),
            String(format: "%.1f", metrics?.fats ?? -1),
            String(format: "%.1f", metrics?.waterLiters ?? -1),
            String(format: "%.1f", goals?.calories ?? -1),
            String(format: "%.1f", goals?.protein ?? -1),
            String(format: "%.1f", goals?.carbs ?? -1),
            String(format: "%.1f", goals?.fats ?? -1),
            String(format: "%.1f", goals?.waterLiters ?? -1),
            activitySignature,
            mealSignature
        ].joined(separator: "#")
    }

    private func sourceNutritionSignature() -> String {
        if let snapshot = nutritionViewModel.coachMetricsSnapshot {
            return "snapshot:\(snapshot.id)"
        }

        if nutritionResult?.brain != nil {
            return "input"
        }

        return "missing"
    }

    private var visibleRecommendation: MealRecommendation? {
        cachedRecommendation
    }


    private var addButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showCreationChooser = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(WeekFitTheme.meal.opacity(0.95))
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.045))
                }
                .overlay {
                    Circle()
                        .stroke(WeekFitTheme.meal.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: WeekFitTheme.meal.opacity(0.10), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var mealsContent: some View {
        VStack(spacing: 0) {
            if !hasAnyItems {
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
            } else {
                List {
                    if !sortedMealItems.isEmpty {
                        sectionHeader(
                            title: "Meals",
                            count: sortedMealItems.count,
                            icon: "fork.knife"
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 9, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                        libraryRows(sortedMealItems)
                    }

                    if !sortedFoodItems.isEmpty {
                        sectionHeader(
                            title: "Foods",
                            count: sortedFoodItems.count,
                            icon: "takeoutbag.and.cup.and.straw.fill"
                        )
                        .listRowInsets(EdgeInsets(top: sortedMealItems.isEmpty ? 2 : 10, leading: 16, bottom: 9, trailing: 16))
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
            }
        }
    }

    private var bottomSpacerRow: some View {
        Color.clear
            .frame(height: isQuickLogMode ? 70 : 126)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private var ambientBackground: some View {
        WeekFitTheme.mealsAmbient
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }


    // MARK: - Meals

    @ViewBuilder
    private var mealsSection: some View {
        if mealItems.isEmpty {
            emptyTabState(
                title: "meals.library.empty.title",
                message: "meals.library.empty.message",
                buttonTitle: "meals.library.empty.action",
                icon: "fork.knife"
            )
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 10, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            ForEach(Array(sortedMealItems.enumerated()), id: \.element.id) { index, meal in
                HeroMealLibraryRow(
                    meal: meal,
                    isQuickLogMode: isQuickLogMode,
                    isRecommended: shouldShowRecommendation &&
                                   index == 0 &&
                                   meal.id == visibleRecommendation?.meal.id
                ) {
                    executeDirectQuickLog(meal)
                }
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedMeal = meal
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !isQuickLogMode {
                        Button(role: .destructive) {
                            deleteCustomMeal(meal)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 7, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private func libraryRows(_ items: [Meals]) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, meal in
//            Group {
//                if meal.isFoodProduct {
//                    MealCardRow(
//                        meal: meal,
//                        isQuickLogMode: isQuickLogMode
//                    ) {
//                        executeDirectQuickLog(meal)
//                    }
//                } else {
//                    HeroMealLibraryRow(
//                        meal: meal,
//                        isQuickLogMode: isQuickLogMode,
//                        isRecommended: shouldShowRecommendation &&
//                                       items == sortedMealItems &&
//                                       index == 0 &&
//                                       meal.id == visibleRecommendation?.meal.id
//                    ) {
//                        executeDirectQuickLog(meal)
//                    }
//                }
//            }
            HeroMealLibraryRow(
                meal: meal,
                isQuickLogMode: isQuickLogMode,
                isRecommended: !meal.isFoodProduct &&
                               shouldShowRecommendation &&
                               items == sortedMealItems &&
                               index == 0 &&
                               meal.id == visibleRecommendation?.meal.id
            ) {
                executeDirectQuickLog(meal)
            }
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if meal.isFoodProduct {
                    selectedFood = meal
                } else {
                    selectedMeal = meal
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if !isQuickLogMode {
                    Button(role: .destructive) {
                        deleteCustomMeal(meal)
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 7, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
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

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(WeekFitLocalizedString(title))
                    .font(.system(size: 15.6, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(0.84))
                    .tracking(-0.22)

                if showCount {
                    Text(String(format: "(%lld)", count))
                        .font(.system(size: 15.0, weight: .semibold, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.48))
                        .tracking(-0.12)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private func emptyTabState(
        title: String,
        message: String,
        buttonTitle: String,
        icon: String
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showCreationChooser = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.045))
                        .frame(width: 46, height: 46)

                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(textPrimary.opacity(0.88))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(WeekFitLocalizedString(title))
                        .font(.system(size: 15.6, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.18)

                    Text(WeekFitLocalizedString(message))
                        .font(.system(size: 12.2, weight: .medium))
                        .foregroundStyle(textSecondary.opacity(0.60))
                        .lineSpacing(1.4)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Text(WeekFitLocalizedString(buttonTitle))
                    .font(.system(size: 12.6, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.meal.opacity(0.92))
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardSecondary.opacity(0.40))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.035), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
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

    private func deleteCustomMeal(_ meal: Meals) {
        withAnimation(.easeInOut(duration: 0.22)) {
            customMeals = CustomMealStore.remove(meal, from: customMeals)
            saveCustomMeals()
        }
        MealPhotoStore.deletePhotoSet(
            originalFilename: meal.localPhotoFilename,
            thumbnailFilename: meal.localPhotoThumbnailFilename
        )
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func saveMealToLibrary(_ meal: Meals) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            customMeals = CustomMealStore.upsert(meal, into: customMeals)
            saveCustomMeals()
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


    private func loadCustomMeals() {
        let loadedMeals = CustomMealStore.load(from: userSettings.customMealsStorage)
        let migratedMeals = loadedMeals.map { MealPhotoStore.ensureThumbnail(for: $0) }
        customMeals = migratedMeals

        if migratedMeals != loadedMeals {
            userSettings.setCustomMealsStorage(CustomMealStore.encode(migratedMeals))
        }
    }

    private func saveCustomMeals() {
        userSettings.setCustomMealsStorage(CustomMealStore.encode(customMeals))
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
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(WeekFitTheme.meal.opacity(0.95))

                        Text(WeekFitLocalizedString(createActionTitle))
                            .font(.system(size: 14.0, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary.opacity(0.94))
                            .tracking(-0.16)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(WeekFitTheme.cardBackground.opacity(0.56))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(Color.white.opacity(0.055), lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 100)
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

private struct CustomFoodDetailsView: View {
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


private struct MealRecommendation: Equatable {
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

private enum MealRecommendationEngine {

    static func make(
        guidance: CoachGuidanceV3,
        meals: [Meals],
        now: Date
    ) -> MealRecommendation? {
        guard !meals.isEmpty else { return nil }

        let context = context(from: guidance, now: now)
        let rankedMeal = meals.max { lhs, rhs in
            score(lhs, context: context) < score(rhs, context: context)
        }

        guard let meal = rankedMeal else { return nil }

        let copy = copy(for: context, guidance: guidance, meal: meal)
        let factors = recommendationFactors(
            meal: meal,
            context: context,
            meals: meals,
            guidance: guidance
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
        from guidance: CoachGuidanceV3,
        now: Date
    ) -> RecommendationContext {
        let hour = Calendar.current.component(.hour, from: now)

        switch guidance.phase {
        case .preparing(let activity, let kind, let minutesUntil):
            if kind == .heat {
                return minutesUntil < 75
                    ? .afterHeatLater
                    : .beforeSessionLight(minutesUntil: minutesUntil)
            }

            if minutesUntil < 45 {
                return .afterSessionLater(activityTitle: activity.title)
            }

            if minutesUntil <= 150 {
                return .beforeSessionLight(minutesUntil: minutesUntil)
            }

            return dayContext(for: hour, guidance: guidance)

        case .active(_, let kind):
            return kind == .heat ? .afterHeatLater : .afterSessionLater(activityTitle: nil)

        case .recovering(_, let kind, _):
            return kind == .heat ? .heatRecovery : .recoveryWindow

        case .stable:
            return dayContext(for: hour, guidance: guidance)
        }
    }

    private static func dayContext(
        for hour: Int,
        guidance: CoachGuidanceV3
    ) -> RecommendationContext {
        let actionTypes = guidance.supportActions.map(\.type)

        if guidance.opportunity.type == .protectRecoveryBeforeActivity ||
            actionTypes.contains(.sleepPriority) ||
            actionTypes.contains(.downshiftNervousSystem) {
            return .recoveryProtection
        }

        if guidance.opportunity.type == .recoverAfterWorkout ||
            actionTypes.contains(.recoveryMeal) ||
            actionTypes.contains(.startRecoveryNutrition) {
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
        guidance: CoachGuidanceV3,
        meal: Meals
    ) -> (badge: String, reason: String, icon: String, color: Color) {
        switch context {
        case .morningLight:
            return (
                "Today's Best Match",
                "Balanced morning option without going too heavy",
                "sunrise.fill",
                WeekFitTheme.meal
            )

        case .middayBalanced:
            return (
                "Today's Best Match",
                guidance.shouldSurface
                    ? "Best match for the current Coach focus"
                    : "Steady balanced choice for this part of the day",
                "fork.knife",
                WeekFitTheme.meal
            )

        case .eveningLight:
            return (
                "Today's Best Match",
                "Light evening choice to close the day cleanly",
                "moon.fill",
                CoachPalette.recovery
            )

        case .beforeSessionLight(let minutesUntil):
            return (
                "Today's Best Match",
                "Good option before activity — keep it light with \(timeText(minutesUntil)) to go",
                "bolt.fill",
                .orange
            )

        case .afterSessionLater(let activityTitle):
            let activity = activityTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let reason = activity?.isEmpty == false
                ? "Best recovery choice after today's \(activity ?? "session")"
                : "Best recovery choice after your session"

            return (
                "Today's Best Match",
                reason,
                "clock.badge.checkmark.fill",
                WeekFitTheme.meal
            )

        case .recoveryWindow:
            return (
                "Today's Best Match",
                "Best recovery choice while the recovery window is open",
                "bolt.shield.fill",
                WeekFitTheme.meal
            )

        case .afterHeatLater:
            return (
                "Today's Best Match",
                "Save this for after heat exposure — rehydrate first",
                "thermometer.sun.fill",
                .orange
            )

        case .heatRecovery:
            return (
                "Today's Best Match",
                "Lighter recovery choice after heat exposure",
                "drop.triangle.fill",
                CoachPalette.hydration
            )

        case .recoveryProtection:
            return (
                "Today's Best Match",
                "Recovery-friendly choice that keeps the day controlled",
                "heart.fill",
                CoachPalette.recovery
            )

        case .balanced:
            return (
                "Today's Best Match",
                "Best balanced option from your saved meals",
                "fork.knife",
                WeekFitTheme.meal
            )
        }
    }

    private static func recommendationFactors(
        meal: Meals,
        context: RecommendationContext,
        meals: [Meals],
        guidance: CoachGuidanceV3
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

        func appendUnique(_ text: String) {
            guard factors.count < 3, !factors.contains(text) else { return }
            factors.append(text)
        }

        switch context {
        case .morningLight:
            appendUnique(isLight ? "Lighter morning option" : "Controlled morning calories")
            appendUnique(isHighProtein ? "Protein-focused start" : "Keeps breakfast simple")
            appendUnique(isLowFat ? "No heavy digestion" : "Balanced macros")

        case .middayBalanced, .balanced:
            appendUnique("Best macro balance today")
            appendUnique(isHighProtein ? "Strong protein base" : "Steady protein support")
            appendUnique(hasRecoveryCarbs ? "Useful energy carbs" : "Controlled carbs")

        case .eveningLight:
            appendUnique(isLight ? "Lighter calorie option" : "Controlled evening choice")
            appendUnique(isHighProtein ? "High protein" : "Recovery support")
            appendUnique(isLowFat ? "Easy evening digestion" : "Simple close to the day")

        case .beforeSessionLight:
            appendUnique(hasRecoveryCarbs ? "Useful pre-session carbs" : "Light energy support")
            appendUnique(isLowFat ? "Lower fat before activity" : "Keeps prep simple")
            appendUnique("Timed for upcoming load")

        case .afterSessionLater, .recoveryWindow:
            appendUnique(isTopProtein ? "Highest protein meal" : "High protein for recovery")
            appendUnique(hasRecoveryCarbs ? "Recovery carbs included" : "Controlled carbs")
            appendUnique("Matches today's activity load")

        case .afterHeatLater, .heatRecovery:
            appendUnique(isLight ? "Lighter after heat" : "Controlled after heat")
            appendUnique(isHighProtein ? "Protein for recovery" : "Recovery support")
            appendUnique("Rehydrate first")

        case .recoveryProtection:
            appendUnique(isLight ? "Lighter recovery option" : "Keeps intake controlled")
            appendUnique(isHighProtein ? "High protein" : "Supports recovery")
            appendUnique("Fits today's Coach focus")
        }

        while factors.count < 3 {
            if factors.count == 0 {
                appendUnique("Best match from saved meals")
            } else if factors.count == 1 {
                appendUnique("Aligned with Coach context")
            } else {
                appendUnique("Good macro fit today")
            }
        }

        return Array(factors.prefix(3))
    }

    private static func timeText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }

        let hours = minutes / 60
        let remainder = minutes % 60

        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }
}

private struct RecommendedTodayMealCard: View {
    let recommendation: MealRecommendation

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let cardBackground = WeekFitTheme.cardBackground

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                badge

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.meal.shortTitle)
                        .font(.system(size: 19.6, weight: .bold, design: .rounded))
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

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(recommendation.factors, id: \.self) { factor in
                        factorRow(factor)
                    }
                }
                .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

//            VStack(spacing: 8) {
//                platePreview
//                    .frame(width: 62, height: 52)
//                    .opacity(0.58)
//                    .allowsHitTesting(false)
//
//                Image(systemName: "chevron.right")
//                    .font(.system(size: 10.8, weight: .bold))
//                    .foregroundStyle(Color.white.opacity(0.26))
//            }
//            .frame(width: 66)
        }
        .padding(.leading, 15)
        .padding(.trailing, 11)
        .padding(.vertical, 14)
        .frame(minHeight: 142)
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
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var badge: some View {
        HStack(spacing: 7) {
            Image(systemName: recommendation.icon)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(recommendation.color)

            Text(recommendation.badge.uppercased())
                .font(.system(size: 9.4, weight: .black, design: .rounded))
                .tracking(0.9)
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

    @ViewBuilder
    private var platePreview: some View {
        if let items = recommendation.meal.builderImageItems, !items.isEmpty {
            BuiltMealPlateView(
                items: items,
                plateSize: 68,
                itemScale: 0.23,
                offsetScale: 0.24,
                plateOpacity: 0.22,
                shadowOpacity: 0.12,
                layoutMode: .compactPreview
            )
            .frame(width: 62, height: 52)
        } else if !recommendation.meal.imageName.isEmpty, UIImage(named: recommendation.meal.imageName) != nil {
            Image(recommendation.meal.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 50)
                .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
        } else {
            Image(systemName: "fork.knife")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(textSecondary.opacity(0.18))
        }
    }
}


// MARK: - Meal row

private struct HeroMealLibraryRow: View {
    let meal: Meals
    let isQuickLogMode: Bool
    let isRecommended: Bool
    let onPlusTap: (() -> Void)?

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let rowBackground = WeekFitTheme.cardBackground
    private let cardShadow = WeekFitTheme.cardShadow
    private let accent = WeekFitTheme.meal

    var body: some View {
        ZStack(alignment: .leading) {
            cardBase

            plateBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .allowsHitTesting(false)

            readabilityOverlay

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    VStack(alignment: .leading, spacing: isRecommended ? 2 : 4) {
                        if isRecommended {
                            Text(WeekFitLocalizedString("meals.todaySMatch"))
                                .font(.system(size: 8.2, weight: .black, design: .rounded))
                                .tracking(0.9)
                                .foregroundStyle(accent.opacity(0.88))
                                .lineLimit(1)
                        }

                        Text(meal.shortTitle)
                            .font(.system(size: 14.9, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary.opacity(0.97))
                            .tracking(-0.28)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)

                        Text(String(format: WeekFitLocalizedString("meals.library.itemSummaryFormat"), meal.calories, ingredientCountText))
                            .font(.system(size: 10.9, weight: .semibold, design: .rounded))
                            .foregroundStyle(textSecondary.opacity(0.78))
                            .lineLimit(1)
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 126, height: 1)

                    macroStrip
                }
                .frame(width: 176, alignment: .leading)
                .padding(.leading, 14)

                Spacer(minLength: 0)

                trailingAction
                    .padding(.trailing, 10)
            }
        }
        .frame(height: isRecommended ? 82 : 76)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.050), lineWidth: 1)
        }
        .shadow(color: cardShadow.opacity(0.12), radius: 7, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    

    private var cardBase: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.028),
                rowBackground.opacity(0.64),
                Color.black.opacity(0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var plateBackground: some View {
        ZStack {
            if meal.isFoodProduct {
                AsyncCustomFoodPlateView(
                    filename: meal.displayPhotoFilename,
                    initial: meal.placeholderInitial,
                    plateSize: 104,
                    itemScale: 0.36,
                    offsetScale: 0.36,
                    plateOpacity: 0.26,
                    shadowOpacity: 0.18,
                    layoutMode: .compactPreview
                )
                .frame(width: 130, height: 84)
                .offset(x: -6, y: 0)
                .opacity(0.76)
            } else if let items = meal.builderImageItems, !items.isEmpty {
                BuiltMealPlateView(
                    items: items,
                    plateSize: 104,
                    itemScale: 0.36,
                    offsetScale: 0.36,
                    plateOpacity: 0.26,
                    shadowOpacity: 0.18,
                    layoutMode: .compactPreview
                )
                    .frame(width: 130, height: 84)
                    .offset(x: -6, y: 0)
                    .opacity(0.76)
            } else if !meal.imageName.isEmpty, UIImage(named: meal.imageName) != nil {
                Image(meal.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 136, height: 92)
                    .offset(x: -6, y: 0)
                    .opacity(0.76)
                    .shadow(color: Color.black.opacity(0.18), radius: 7, y: 4)
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.20))
                    .offset(x: 54)
            }
        }
    }

    private var readabilityOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.95), location: 0.0),
                .init(color: .black.opacity(0.80), location: 0.30),
                .init(color: .black.opacity(0.34), location: 0.64),
                .init(color: .black.opacity(0.00), location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var macroStrip: some View {
        HStack(spacing: 7) {
            macroView(prefix: WeekFitLocalizedString("meals.library.macroProtein"), value: meal.protein)

            Divider()
                .frame(height: 14)
                .overlay(Color.white.opacity(0.12))

            macroView(prefix: WeekFitLocalizedString("meals.library.macroCarbs"), value: meal.carbs)

            Divider()
                .frame(height: 14)
                .overlay(Color.white.opacity(0.12))

            macroView(prefix: WeekFitLocalizedString("meals.library.macroFats"), value: meal.fats)
        }
    }

    private func macroView(prefix: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(prefix)
                .font(.system(size: 10.9, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.82))

            Text(String(format: WeekFitLocalizedString("common.unit.gramValueFormat"), value))
                .font(.system(size: 10.9, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.74))
                .monospacedDigit()
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var trailingAction: some View {
        if isQuickLogMode {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onPlusTap?()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black.opacity(0.82))
                    .frame(width: 34, height: 34)
                    .background {
                        Circle()
                            .fill(accent.opacity(0.94))
                    }
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: "chevron.right")
                   .font(.system(size: 10.8, weight: .bold))
                   .foregroundStyle(Color.white.opacity(0.28))
                   .frame(width: 18, height: 18)
        }
    }

    private var ingredientCountText: String {
        let count = max(meal.ingredients.count, meal.builderImageItems?.count ?? 0)
        return count == 1 ? "1 ingredient" : "\(count) ingredients"
    }
}

private struct BuiltMealPlateBackground: View {
    let items: [MealBuilderImageItem]

    var body: some View {
        BuiltMealPlateView(
            items: items,
            plateSize: 112,
            itemScale: 0.38,
            offsetScale: 0.40,
            plateOpacity: 0.28,
            shadowOpacity: 0.20,
            layoutMode: .compactPreview
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

