import SwiftUI
import SwiftData

private enum MealsTab {
    case suggested
    case custom
}

struct MealsView: View {

    @ObservedObject var authViewModel: AuthViewModel
    let nutritionResult: NutritionResult?
    
    // MARK: - UX-Контексты логирования
    var isQuickLogMode: Bool = false
    var onMealLogged: (() -> Void)? = nil

    @AppStorage(ProfileService.Keys.initials)
    private var profileInitials: String = "P"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    @Namespace private var tabNamespace

    @State private var selectedTab: MealsTab = .custom
    @State private var suggestedMeals: [Meals] = []
    @State private var customMeals: [Meals] = []

    @State private var showMealBuilder = false
    @State private var selectedMeal: Meals?
    @State private var showContent = false
    @State private var isLoading = false
    @State private var isAddingToPlan = false

    @State private var showProfile = false
    @State private var calendarMessage: String?
    @State private var showCalendarAlert = false
    @State private var selectedDate = Date()

    @AppStorage("weekfit_custom_meals_v1")
    private var customMealsStorage: String = ""

    private let mealsService = MealsService()

    private let background = WeekFitTheme.background
    private let cardBackground = WeekFitTheme.cardBackground
    private let cardSecondary = WeekFitTheme.cardSecondary
    private let elevatedCard = WeekFitTheme.elevatedCard

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let textTertiary = WeekFitTheme.tertiaryText

    private let cardShadow = WeekFitTheme.cardShadow

    private let suggestedAccent = Color(red: 0.50, green: 0.66, blue: 1.00)

    private var activeMeals: [Meals] {
        selectedTab == .suggested ? Array(suggestedMeals.prefix(3)) : customMeals
    }

    private var shouldShowBottomAction: Bool {
        selectedTab == .suggested && !suggestedMeals.isEmpty && !isQuickLogMode
    }

    private var totalCalories: Int {
        activeMeals.reduce(0) { $0 + $1.calories }
    }

    private var totalProtein: Int {
        activeMeals.reduce(0) { $0 + $1.protein }
    }

    private var totalCarbs: Int {
        activeMeals.reduce(0) { $0 + $1.carbs }
    }

    private var totalFats: Int {
        activeMeals.reduce(0) { $0 + $1.fats }
    }

    // MARK: - Исправленные встроенные свойства (Фикс ошибок)
    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(width: 1, height: 12)
    }

    private var nutritionInsightIcon: String {
        if activeMeals.isEmpty {
            return selectedTab == .custom ? "fork.knife.circle.fill" : "sparkles"
        }
        if totalCalories < Int(Double(targetCalories) * 0.72) { return "flame.fill" }
        if totalProtein < Int(Double(targetProtein) * 0.75) { return "bolt.heart.fill" }
        if totalCalories > Int(Double(targetCalories) * 1.08) { return "gauge.medium" }
        return "checkmark.seal.fill"
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ambientBackground

            VStack(spacing: 0) {
                headerListBlock
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                List {
                    mealCards

                    Color.clear
                        .frame(height: shouldShowBottomAction ? 164 : 118)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 8)
            .animation(.spring(response: 0.42, dampingFraction: 0.88), value: showContent)
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .bottom) {
            if shouldShowBottomAction {
                bottomActionBar
            } else {
                bottomFadeOnly
            }
        }
        .onAppear {
            loadCustomMeals()
            loadMealsPlan()
        }
        .sheet(item: $selectedMeal) { meal in
            MealDetailsView(
                meal: meal,
                isQuickLogMode: self.isQuickLogMode,
                onMealLogged: {
                    selectedMeal = nil
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
        .alert("Meal Plan", isPresented: $showCalendarAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(calendarMessage ?? "")
        }
        .sheet(isPresented: $showMealBuilder) {
            MealBuilderView { newMeal in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    customMeals.append(newMeal)
                    selectedTab = .custom
                    saveCustomMeals()
                }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            .presentationDetents([.large])
            .presentationCornerRadius(36)
            .presentationDragIndicator(.hidden)
        }
    }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [
                    selectedTab == .suggested ? suggestedAccent.opacity(0.085) : WeekFitTheme.meal.opacity(0.065),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 340
            )

            RadialGradient(
                colors: [
                    WeekFitTheme.orange.opacity(0.032),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 90,
                endRadius: 390
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.012),
                    Color.clear,
                    Color.black.opacity(0.13)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.28), value: selectedTab)
    }

    private var headerListBlock: some View {
        VStack(spacing: 12) {
            heroHeaderSection
                .padding(.bottom, 3)

            nutritionInsightCard

            mealTabs

            mealSectionHeader
                .padding(.top, 1)
        }
    }

    private var heroHeaderSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Meal Plan")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.75)

                Text(selectedDateTitle)
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.76))
            }

            Spacer()

            if !isQuickLogMode {
                avatarButton
            }
        }
    }

    private var avatarButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showProfile = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.92, green: 0.78, blue: 0.50),
                                Color(red: 0.76, green: 0.62, blue: 0.36)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .stroke(WeekFitTheme.meal.opacity(0.38), lineWidth: 2.5)

                Circle()
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
                    .padding(5)

                Text(profileInitials)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.94))
            }
            .frame(width: 48, height: 48)
            .shadow(color: WeekFitTheme.meal.opacity(0.09), radius: 11, y: 5)
            .shadow(color: Color.black.opacity(0.22), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var nutritionInsightCard: some View {
        HStack(alignment: .center, spacing: 11) {
            ZStack {
                Circle()
                    .fill(insightAccent.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: nutritionInsightIcon)
                    .font(.system(size: 16.2, weight: .semibold))
                    .foregroundStyle(insightAccent.opacity(0.94))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(nutritionInsightTitle)
                    .font(.system(size: 14.2, weight: .medium))
                    .foregroundStyle(textPrimary.opacity(0.98))
                    .tracking(-0.15)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(nutritionInsightMessage)
                    .font(.system(size: 12.2, weight: .medium))
                    .foregroundStyle(textSecondary.opacity(0.78))
                    .lineSpacing(1.35)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            insightAccent.opacity(0.045),
                            elevatedCard.opacity(0.96),
                            cardBackground.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.046), lineWidth: 1)
        }
        .shadow(color: cardShadow.opacity(0.68), radius: 13, y: 7)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
    }

    private var insightAccent: Color {
        selectedTab == .suggested ? suggestedAccent : WeekFitTheme.meal
    }

    private var mealTabs: some View {
        HStack(spacing: 4) {
            mealTabButton(
                tab: .custom,
                title: "Custom",
                subtitle: "\(customMeals.count) meals",
                icon: "fork.knife"
            )

            mealTabButton(
                tab: .suggested,
                title: "Suggested",
                subtitle: "\(suggestedMeals.count) meals",
                icon: "sparkles"
            )
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04)) // Более мягкая нейтральная подложка
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.02), lineWidth: 1)
                }
        }
    }

    private func mealTabButton(
        tab: MealsTab,
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {
        let isSelected = selectedTab == tab
        // 🎯 ФИКС: Если выбрана вкладка Custom, акцент становится благородно-белым, а не зелёным
        let accent = tab == .suggested ? suggestedAccent : (isSelected ? Color.white : WeekFitTheme.meal)

        return Button {
            guard selectedTab != tab else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        // Используем нативный ультра-тонкий материал размытия
                        .fill(.ultraThinMaterial)
                        .matchedGeometryEffect(id: "mealTabSelection", in: tabNamespace)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        }
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.02)))
                }

                VStack(spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 11.5, weight: .semibold))

                        Text(title)
                            .font(.system(size: 14.5, weight: .bold))
                            .tracking(-0.12)
                    }

                    Text(subtitle)
                        .font(.system(size: 10.9, weight: .semibold))
                        // Подсвечиваем сабтитл мягким зелёным/синим только у активного таба
                        .foregroundStyle(isSelected ? (tab == .suggested ? suggestedAccent : WeekFitTheme.meal.opacity(0.85)) : Color.white.opacity(0.35))
                }
                .foregroundStyle(
                    isSelected ? .white : .white.opacity(0.4)
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var mealSectionHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedTab == .suggested ? "Suggested for today" : "Your custom meals")
                    .font(.system(size: 17.4, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.28)
                    .lineLimit(1)

                Text(selectedTab == .suggested ? "Balanced meal set • \(activeMeals.count) meals" : "\(customMeals.count) saved meals")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if selectedTab == .suggested {
                refreshButton
            } else {
                addCustomButton
            }
        }
        .padding(.horizontal, 4)
    }

    private var refreshButton: some View {
        Button {
            regenerateSuggestedMeals()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isLoading ? "hourglass" : "arrow.clockwise")
                    .font(.system(size: 13, weight: .bold))

                Text(isLoading ? "Updating" : "Refresh")
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(WeekFitTheme.meal.opacity(0.90))
            .padding(.horizontal, 12)
            .frame(height: 31)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.034))
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.62 : 1)
    }

    private var addCustomButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showMealBuilder = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13.2, weight: .bold))
                .foregroundStyle(WeekFitTheme.meal.opacity(0.92))
                .frame(width: 32, height: 32)
                .weekFitMealActionBackground()
        }
        .buttonStyle(.plain)
    }

    private var mealCards: some View {
        Group {
            if selectedTab == .custom && customMeals.isEmpty {
                customEmptyState
                    .listRowInsets(EdgeInsets(top: 1, leading: 16, bottom: 9, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(activeMeals) { meal in
                    MealCardRow(meal: meal, isQuickLogMode: isQuickLogMode) {
                        // Экшен для плюса (если включен Quick Log)
                        executeDirectQuickLog(meal)
                    }
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedMeal = meal
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 9, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if selectedTab == .custom && !isQuickLogMode {
                            Button(role: .destructive) {
                                deleteCustomMeal(meal)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var customEmptyState: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showMealBuilder = true
        } label: {
            VStack(alignment: .leading, spacing: 15) { // Слегка увеличили отступ
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            // 🎯 ФИКС: Убрали зелёное пятно, сделали круг благородно-монохромным
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 44, height: 44)

                        Image(systemName: "fork.knife")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85)) // Белая аккуратная иконка
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Build your first meal")
                            .font(.system(size: 15.2, weight: .bold))
                            .foregroundStyle(textPrimary)

                        Text("Choose ingredients, see macros instantly and save favorite combinations.")
                            .font(.system(size: 12.1, weight: .medium))
                            .foregroundStyle(textSecondary.opacity(0.55))
                            .lineSpacing(1.3)
                            .lineLimit(2)
                    }

                    Spacer()
                }

                // 🎯 ФИКС КНОПКИ ДЕЙСТВИЯ: Теперь это контрастная, дорогая плашка
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))

                    Text("Start building")
                        .font(.system(size: 13.0, weight: .bold))
                }
                .foregroundStyle(.black.opacity(0.85)) // Тёмный текст на ярком фоне
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background {
                    Capsule()
                        .fill(WeekFitTheme.meal) // Плотная зелёная заливка
                        .shadow(color: WeekFitTheme.meal.opacity(0.2), radius: 8, y: 3)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardSecondary.opacity(0.4)) // Сделали фон карточки чистым и тёмным
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.02), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func mealCard(_ meal: Meals) -> some View {
        HStack(spacing: 10) {
            mealSlotColumn(meal)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 7) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(meal.shortTitle)
                            .font(.system(size: 15.4, weight: .bold))
                            .foregroundStyle(textPrimary.opacity(0.97))
                            .tracking(-0.22)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)

                        Text(meal.subtitle)
                            .font(.system(size: 12.05, weight: .medium))
                            .foregroundStyle(textSecondary.opacity(0.73))
                            .lineSpacing(1.15)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    mealImage(meal)

                    if isQuickLogMode {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            executeDirectQuickLog(meal)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(mealCardAccent(meal))
                                .frame(width: 24, height: 42)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13.2, weight: .bold))
                            .foregroundStyle(textTertiary.opacity(0.48))
                            .rotationEffect(.degrees(90))
                            .frame(width: 9)
                            .padding(.top, 1)
                    }
                }

                macrosPill(meal)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(minHeight: 80)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            mealCardAccent(meal).opacity(selectedTab == .custom ? 0.028 : 0.018),
                            cardSecondary.opacity(0.97),
                            cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(
                    selectedTab == .custom ? mealCardAccent(meal).opacity(0.06) : Color.white.opacity(0.038),
                    lineWidth: 1
                )
        }
        .shadow(color: cardShadow.opacity(0.66), radius: 12, y: 6)
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
            fats: meal.fats
        )
        quickActivity.isCompleted = true
        
        modelContext.insert(quickActivity)
        try? modelContext.save()
        
        onMealLogged?()
    }

    private func mealSlotColumn(_ meal: Meals) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(mealSlotColor(meal).opacity(0.13))
                    .frame(width: 35, height: 35)

                Image(systemName: mealSlotIcon(meal))
                    .font(.system(size: 17.2, weight: .semibold))
                    .foregroundStyle(mealSlotColor(meal).opacity(0.93))
            }

            Text(meal.slotTitle)
                .font(.system(size: 10.1, weight: .bold))
                .foregroundStyle(textPrimary.opacity(0.90))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(width: 52)
    }

    private func mealImage(_ meal: Meals) -> some View {
        Group {
            if let items = meal.builderImageItems, !items.isEmpty {
                builtMealImage(items)
            } else if UIImage(named: meal.imageName) != nil {
                Image(meal.imageName)
                    .resizable()
                    .scaledToFill()
                    .overlay {
                        Color.black.opacity(0.045)
                    }
            } else {
                fallbackMealImage(meal)
            }
        }
        .frame(width: 56, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.038), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.13), radius: 6, y: 3)
    }

    private func builtMealImage(_ items: [MealBuilderImageItem]) -> some View {
        ZStack {
            Image("plate-dark")
                .resizable()
                .scaledToFit()
                .frame(width: 68, height: 68)

            ForEach(items.sorted(by: { $0.zIndex < $1.zIndex })) { item in
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: CGFloat(item.visualSize) * 0.31)
                    .offset(
                        x: CGFloat(item.offsetX) * 0.225,
                        y: (CGFloat(item.offsetY) - 2) * 0.225
                    )
                    .rotationEffect(.degrees(Double(item.rotation)))
                    .zIndex(Double(item.zIndex))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.09))
    }

    private func fallbackMealImage(_ meal: Meals) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(mealSlotColor(meal).opacity(0.12))
            .overlay {
                Image(systemName: "fork.knife")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(mealSlotColor(meal).opacity(0.90))
            }
    }

    private func macrosPill(_ meal: Meals) -> some View {
        HStack(spacing: 0) {
            Text("\(meal.calories) kcal")
                .font(.system(size: 10.6, weight: .bold))
                .foregroundStyle(textPrimary.opacity(0.92))
                .frame(maxWidth: .infinity)

            separator
            macroText("P \(meal.protein)g")
            separator
            macroText("C \(meal.carbs)g")
            separator
            macroText("F \(meal.fats)g")
        }
        .padding(.horizontal, 9)
        .frame(height: 20)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.038))
        }
    }

    private func macroText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.1, weight: .medium))
            .foregroundStyle(textSecondary.opacity(0.70))
            .frame(maxWidth: .infinity)
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Button {
                addSuggestedMealsToPlan()
            } label: {
                HStack(spacing: 9) {
                    if isAddingToPlan {
                        ProgressView()
                            .scaleEffect(0.66)
                            .tint(WeekFitTheme.meal.opacity(0.86))
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                    }

                    Text(addToPlanTitle)
                        .font(.system(size: 14.1, weight: .bold))
                        .tracking(-0.08)
                }
                .foregroundStyle(WeekFitTheme.meal.opacity(0.92))
                .frame(maxWidth: .infinity)
                .frame(height: 43)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    WeekFitTheme.meal.opacity(0.135),
                                    WeekFitTheme.meal.opacity(0.085)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Capsule()
                                .stroke(WeekFitTheme.meal.opacity(0.17), lineWidth: 1)
                        }
                }
                .shadow(color: WeekFitTheme.meal.opacity(0.065), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isAddingToPlan || suggestedMeals.isEmpty)
            .opacity(isAddingToPlan ? 0.72 : 1)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 84)
        }
        .background {
            bottomFadeGradient
        }
    }
    
    private func addSuggestedMealsToPlan() {
        guard selectedTab == .suggested else { return }
        guard !isAddingToPlan else { return }
        guard !activeMeals.isEmpty else { return }

        isAddingToPlan = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task { @MainActor in
            var addedCount = 0
            var skippedCount = 0
            let now = Date()

            for meal in activeMeals {
                let mealStartDate = mealDate(for: meal)

                if hasMealConflict(at: mealStartDate) {
                    skippedCount += 1
                    continue
                }

                let activity = PlannedActivity(
                    date: mealStartDate,
                    type: PlannerType.meal.title,
                    title: meal.title,
                    durationMinutes: 30,
                    icon: PlannerType.meal.icon,
                    imageName: meal.imageName,
                    colorRed: PlannerType.meal.colorComponents.red,
                    colorGreen: PlannerType.meal.colorComponents.green,
                    colorBlue: PlannerType.meal.colorComponents.blue,
                    calories: meal.calories,
                    protein: meal.protein,
                    carbs: meal.carbs,
                    fats: meal.fats
                )

                // 🧠 УМНОЕ UX-КЛОНИРОВАНИЕ:
                // Если мы добавляем еду на Сегодня, и время этого приема пищи уже прошло (например, завтрак в 9:00),
                // мы автоматически ставим ей статус Исполнено (isCompleted = true), чтобы макросы сразу упали в кольца!
                if Calendar.current.isDateInToday(selectedDate) && mealStartDate < now {
                    activity.isCompleted = true
                }

                modelContext.insert(activity)
                ActivityNotificationService.shared.scheduleReminder(for: activity)
                addedCount += 1
            }

            do {
                try modelContext.save()

                if addedCount > 0 && skippedCount == 0 {
                    calendarMessage = "Suggested meals added to your plan."
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } else if addedCount > 0 {
                    calendarMessage = "\(addedCount) meals added. \(skippedCount) skipped because that time is already booked."
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } else {
                    calendarMessage = "These meal times are already booked in your plan."
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
            } catch {
                calendarMessage = "Could not add suggested meals to your plan."
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }

            showCalendarAlert = true
            isAddingToPlan = false
            
            // Если мы находимся в режиме шторки быстрого логирования — закрываем её после успеха
            if isQuickLogMode && addedCount > 0 {
                onMealLogged?()
            }
        }
    }

    private var bottomFadeOnly: some View {
        bottomFadeGradient
            .frame(height: 64)
            .allowsHitTesting(false)
    }

    private var bottomFadeGradient: some View {
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

    private var addToPlanTitle: String {
        isAddingToPlan ? "Adding..." : "Add Suggested to Plan"
    }

    private func mealCardAccent(_ meal: Meals) -> Color {
        switch selectedTab {
        case .suggested:
            return suggestedAccent
        case .custom:
            return mealSlotColor(meal)
        }
    }

    private func deleteCustomMeal(_ meal: Meals) {
        guard selectedTab == .custom else { return }

        withAnimation(.easeInOut(duration: 0.22)) {
            customMeals.removeAll { $0.id == meal.id }
            saveCustomMeals()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func regenerateSuggestedMeals() {
        guard !isLoading else { return }
        isLoading = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            let plan = await mealsService.getMealsPlan()
            await MainActor.run {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    suggestedMeals = Array(plan.prefix(3))
                }
                isLoading = false
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
    }

    private func loadMealsPlan() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            let plan = await mealsService.getMealsPlan()
            await MainActor.run {
                suggestedMeals = Array(plan.prefix(3))
                showContent = true
                isLoading = false
            }
        }
    }

    private func loadCustomMeals() {
        guard let data = customMealsStorage.data(using: .utf8) else { return }
        guard let decoded = try? JSONDecoder().decode([Meals].self, from: data) else { return }
        customMeals = decoded
    }

    private func saveCustomMeals() {
        guard let data = try? JSONEncoder().encode(customMeals) else { return }
        customMealsStorage = String(data: data, encoding: .utf8) ?? ""
    }

    private func mealDate(for meal: Meals) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let parts = meal.displayTime.split(separator: ":")
        components.hour = Int(parts.first ?? "12") ?? 12
        components.minute = Int(parts.dropFirst().first ?? "00") ?? 0
        return calendar.date(from: components) ?? selectedDate
    }

    private func hasMealConflict(at date: Date) -> Bool {
        plannedActivities.contains { existing in
            guard Calendar.current.isDate(existing.date, inSameDayAs: date) else { return false }
            guard !existing.isSkipped else { return false }
            return Calendar.current.isDate(existing.date, equalTo: date, toGranularity: .minute)
        }
    }

    private func mealSlotColor(_ meal: Meals) -> Color {
        switch meal.slot {
        case .breakfast: return WeekFitTheme.orange
        case .lunch:     return WeekFitTheme.green
        case .snack:     return WeekFitTheme.blue
        case .dinner:    return WeekFitTheme.purple
        }
    }

    private func mealSlotIcon(_ meal: Meals) -> String {
        switch meal.slot {
        case .breakfast: return "sun.max.fill"
        case .lunch:     return "fork.knife"
        case .snack:     return "leaf.fill"
        case .dinner:    return "moon.fill"
        }
    }

    private var nutritionInsightTitle: String {
        if selectedTab == .custom && activeMeals.isEmpty { return "Build your own meal flow" }
        if selectedTab == .suggested && activeMeals.isEmpty { return "Your meal plan is ready to build" }
        if selectedTab == .custom { return "Fuel for today" }
        if totalCalories < Int(Double(targetCalories) * 0.72) { return "Light day, keep energy steady" }
        if totalProtein < Int(Double(targetProtein) * 0.75) { return "Protein could be stronger" }
        if totalCalories > Int(Double(targetCalories) * 1.08) { return "Slightly above today’s target" }
        return "Balanced around your targets"
    }

    private var nutritionInsightMessage: String {
        if selectedTab == .custom && activeMeals.isEmpty { return "Create meals from ingredients and keep them separate from your suggested plan." }
        if selectedTab == .custom { return "Build your own day. We’ll track calories and macros from the meals you choose." }
        if activeMeals.isEmpty { return "Generate a plan and we’ll balance the day around calories, protein, carbs and fats." }
        let caloriesLeft = targetCalories - totalCalories
        let proteinLeft = max(targetProtein - totalProtein, 0)
        if totalCalories < Int(Double(targetCalories) * 0.72) { return "This plan is around \(totalCalories) kcal, still light for today. Add a steady meal or snack later." }
        if totalProtein < Int(Double(targetProtein) * 0.75) { return "Calories look workable at \(totalCalories) kcal, but protein is only \(totalProtein)g." }
        if totalCalories > Int(Double(targetCalories) * 1.08) { return "You’re at \(totalCalories) kcal, a bit over target. Keep the next meal lighter." }
        if proteinLeft <= 10 && caloriesLeft >= -120 { return "Nice balance: \(totalCalories) kcal and \(totalProtein)g protein." }
        return "You’re at \(totalCalories) kcal with about \(max(caloriesLeft, 0)) kcal left. Protein gap is around \(proteinLeft)g."
    }

    private var targetCalories: Int { max(Int(nutritionResult?.goals.calories.rounded() ?? 1800), 1) }
    private var targetProtein: Int { max(Int(nutritionResult?.goals.protein.rounded() ?? 120), 1) }
}
