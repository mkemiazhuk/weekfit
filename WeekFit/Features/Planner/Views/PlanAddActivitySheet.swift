import SwiftUI
import UIKit
import SwiftData

private struct AddSheetTimeSlotState: Identifiable {
    var id: Date { slot }

    let slot: Date
    let isPast: Bool
    let isOccupied: Bool
    let isActive: Bool
    let isRecommended: Bool
}

private struct PlanAddLibraryWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Single meal sheet avoids dismiss→present races when opening the builder from the library.
private enum PlannerMealSheetStep: Equatable {
    case library
    case builder
}

private struct PlannerMealSheetHost<Library: View>: View {
    @Binding var step: PlannerMealSheetStep
    @Binding var detent: PresentationDetent
    @ViewBuilder let library: () -> Library
    let onBuilderSave: (Meals) -> Void

    var body: some View {
        Group {
            switch step {
            case .library:
                library()

            case .builder:
                MealBuilderView(onSave: onBuilderSave)
            }
        }
        .presentationDetents(
            step == .library ? [.medium, .large] : [.large],
            selection: $detent
        )
        .presentationDragIndicator(step == .library ? .visible : .hidden)
        .weekFitSheetChrome(
            cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius,
            background: QuickActionSheetDesign.Color.sheetBackground(for: .food)
        )
    }
}

struct PlanAddActivitySheet: View {

    @ObservedObject var viewModel: PlanViewModel
    @EnvironmentObject private var languageManager: AppLanguageManager

    let plannedActivities: [PlannedActivity]
    let modelContext: ModelContext
    let activityRemindersEnabled: Bool
    let completionCheckInsEnabled: Bool

    @ObservedObject private var userSettings = WeekFitUserSettings.shared

    @State private var showDeleteConfirmation = false
    @State private var showMealSheet = false
    @State private var mealSheetStep: PlannerMealSheetStep = .library
    @State private var mealSheetDetent: PresentationDetent = .medium
    @State private var showOptionCatalogSheet = false
    @State private var isSaving = false
    @State private var showDatePicker = false
    @State private var showExpandedTimePicker = false
    /// Measured content width so exactly two library cards fit the viewport.
    @State private var libraryContentWidth: CGFloat = 0
    @Namespace private var typePickerNamespace

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var textPrimary: Color { WeekFitTheme.primaryText }
    private var textSecondary: Color {
        // Night: slightly softer secondary so labels don’t glare on charcoal.
        palette.isLight ? WeekFitTheme.secondaryText : WeekFitTheme.secondaryText.opacity(0.88)
    }
    /// Decorative accent: Meal green, Workout blue, Recovery purple, Habit amber.
    private var selectionAccent: Color {
        guard !palette.isLight else { return viewModel.selectedType.color }
        return PlanAddNightChrome.softAccent(for: viewModel.selectedType)
    }
    /// Light: cool gray. Dark: calm charcoal (not OLED pure black).
    private var screenBackground: Color {
        if palette.isLight {
            return Color(red: 0.969, green: 0.969, blue: 0.969) // #F7F7F7
        }
        return PlanAddNightChrome.canvas
    }

    private let contentPadding: CGFloat = 16
    /// Date → library / parameters → time panels — tight so the sheet fits without vertical scroll.
    private let majorSectionSpacing: CGFloat = 10
    /// Section heading → cards / controls
    private let sectionHeaderSpacing: CGFloat = 8
    private let libraryCardGap: CGFloat = 10
    private let addSheetCarouselInset: CGFloat = 0
    private let busySlotColor = WeekFitTheme.orange
    private let cardCornerRadius: CGFloat = 20
    private let cardInnerPadding: CGFloat = 12
    /// Two-line title band shared by every card in the carousel.
    private let cardTitleBlockHeight: CGFloat = 40
    private let plannerChipHeight: CGFloat = 34
    private let plannerChipCorner: CGFloat = 12
    /// Visible plate ≈ 85–90% of the square image well.
    private let mealPlateFillRatio: CGFloat = 0.90
    private let sectionPanelRadius: CGFloat = 16
    private let sectionPanelPadding: CGFloat = 12

    private var sectionPanelFill: Color {
        palette.isLight ? Color.white : PlanAddNightChrome.cardFill
    }

    private var sectionPanelStroke: Color {
        palette.isLight ? Color.black.opacity(0.10) : WeekFitTheme.whiteOpacity(0.12)
    }

    private var libraryCardWidth: CGFloat {
        // Measured inside the library section panel (inner width after panel padding).
        let width = libraryContentWidth > 0 ? libraryContentWidth : 350
        return floor((width - libraryCardGap) / 2)
    }

    /// Circular / square media fills the card width (original card presence).
    private var mediaSize: CGFloat {
        max(96, libraryCardWidth - (cardInnerPadding * 2))
    }

    private var activityThumbSize: CGFloat { mediaSize }
    private var mealThumbSize: CGFloat { mediaSize }

    private var showsLibraryViewAll: Bool {
        switch viewModel.selectedType {
        case .meal:
            return availableMeals.count > 2
        case .workout, .recovery, .habit:
            return currentOptions.count > 2
        }
    }

    /// Deep CTA fills for ≥4.5:1 white text; night uses muted family fills (not neon accents).
    private var actionButtonFill: Color {
        if palette.isLight {
            switch viewModel.selectedType {
            case .meal:
                return Color(red: 0.10, green: 0.48, blue: 0.36)
            case .workout:
                return Color(red: 0.18, green: 0.38, blue: 0.72)
            case .recovery:
                return Color(red: 0.38, green: 0.28, blue: 0.68)
            case .habit:
                return Color(red: 0.70, green: 0.38, blue: 0.10)
            }
        }
        return PlanAddNightChrome.ctaFill(for: viewModel.selectedType)
    }

    private var chipNeutralFill: Color {
        palette.isLight ? Color.white : PlanAddNightChrome.elevatedSurface
    }

    private let timelineStartHour = 5
    private let timelineEndHour = 24
    private let timelineMinuteStep = 15

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    private var calendar: Calendar { viewModel.calendar }
    private var availableMeals: [Meals] { viewModel.availableMeals }
    private var currentOptions: [PlannerOption] { viewModel.currentOptions }
    private var showsMealEmptyState: Bool { viewModel.selectedType == .meal && availableMeals.isEmpty }

    private var timeSlots: [Date] {
        let startOfDay = calendar.startOfDay(for: viewModel.selectedDate)

        let startMinutes = timelineStartHour * 60
        let endMinutes = timelineEndHour * 60

        let allSlots = stride(from: startMinutes, through: endMinutes, by: timelineMinuteStep).compactMap { minutes in
            calendar.date(byAdding: .minute, value: minutes, to: startOfDay)
        }

        guard calendar.isDate(viewModel.selectedDate, inSameDayAs: Date()) else {
            return allSlots
        }

        return allSlots.filter { slot in
            slot >= Date() || isEditingOriginalSlot(slot)
        }
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        NavigationStack {
            addActivityScreen
                .background {
                    ZStack {
                        screenBackground
                        if !palette.isLight {
                            LinearGradient(
                                colors: PlanAddSheetPalette.sheetWash(
                                    for: viewModel.selectedType,
                                    isLight: false
                                ),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .allowsHitTesting(false)
                        }
                    }
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.28), value: viewModel.selectedType)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    cancelToolbarItem

                    ToolbarItem(placement: .principal) {
                        Text(
                            viewModel.editingActivity == nil
                                ? scenarioTitle
                                : WeekFitLocalizedString("planner.sheet.editTitle")
                        )
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                    }

                    if viewModel.editingActivity != nil {
                        deleteToolbarItem
                    }
                }
                .sheet(isPresented: $showDatePicker) {
                    NavigationStack {
                        DatePicker(
                            WeekFitLocalizedString("planner.sheet.dateLabel"),
                            selection: $viewModel.selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(selectionAccent)
                        .padding()
                        .navigationTitle(WeekFitLocalizedString("planner.sheet.dateLabel"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(WeekFitLocalizedString("common.action.done")) {
                                    showDatePicker = false
                                }
                                .foregroundStyle(selectionAccent)
                            }
                        }
                    }
                    .presentationDetents([.medium])
                    .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
                }
        }
        .preferredColorScheme(palette.isLight ? .light : .dark)
        .environment(\.weekFitPalette, palette)
        .sheet(isPresented: $showMealSheet) {
            PlannerMealSheetHost(
                step: $mealSheetStep,
                detent: $mealSheetDetent,
                library: { mealLibrarySheet },
                onBuilderSave: { newMeal in
                    saveMealToLibrary(newMeal)
                    showMealSheet = false
                }
            )
        }
        .onChange(of: showMealSheet) { _, isPresented in
            guard !isPresented else { return }
            mealSheetStep = .library
            mealSheetDetent = .medium
        }
        .sheet(isPresented: $viewModel.showCustomDuration) {
            customDurationSheet
                .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
        }
        .sheet(isPresented: $showOptionCatalogSheet) {
            optionCatalogSheet
                .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
        }
        .alert(WeekFitLocalizedString("planner.timeConflict.title"), isPresented: $viewModel.showTimeConflictAlert) {
            Button(WeekFitLocalizedString("common.action.ok"), role: .cancel) { }
        } message: {
            Text(viewModel.timeConflictMessage)
        }
        .alert(WeekFitLocalizedString("planner.saveFailure.title"), isPresented: $viewModel.showSaveFailureAlert) {
            Button(WeekFitLocalizedString("common.action.ok"), role: .cancel) { }
        } message: {
            Text(viewModel.saveFailureMessage)
        }
        .alert(WeekFitLocalizedString("planner.delete.title"), isPresented: $showDeleteConfirmation) {
            Button(WeekFitLocalizedString("common.action.cancel"), role: .cancel) { }

            Button(WeekFitLocalizedString("common.action.delete"), role: .destructive) {
                if let editingActivity = viewModel.editingActivity {
                    deleteActivity(editingActivity)
                    closeAddSheet()
                }
            }
        } message: {
            Text(AppText.Planner.deleteActivityMessage)
        }
        .onAppear {
            lightHaptic.prepare()
            isSaving = false
            viewModel.syncCustomMeals(
                from: userSettings.customMealsCatalog,
                revision: userSettings.customMealsCatalogRevision
            )
            viewModel.syncDefaultSelectedMeal()
        }
        .onChange(of: userSettings.customMealsCatalogRevision) { _, revision in
            viewModel.syncCustomMeals(
                from: userSettings.customMealsCatalog,
                revision: revision
            )
            viewModel.syncDefaultSelectedMeal()
        }
        .onChange(of: viewModel.selectedDate) { _, newDate in
            remapSelectedSlot(toDay: newDate)
        }
    }
}

// MARK: - Main Screen

private extension PlanAddActivitySheet {

    @ToolbarContentBuilder
    var cancelToolbarItem: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) {
                cancelToolbarButton
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) {
                cancelToolbarButton
            }
        }
    }

    @ToolbarContentBuilder
    var deleteToolbarItem: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) {
                deleteToolbarButton
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                deleteToolbarButton
            }
        }
    }

    var cancelToolbarButton: some View {
        Button {
            closeAddSheet()
        } label: {
            Text(WeekFitLocalizedString("common.action.cancel"))
                .font(.body)
                .foregroundStyle(selectionAccent)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    var deleteToolbarButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Image(systemName: "trash")
                .frame(minWidth: 44, minHeight: 44)
        }
        .disabled(isSaving)
        .accessibilityLabel(WeekFitLocalizedString("common.action.delete"))
    }

    var addActivityScreen: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize || showExpandedTimePicker {
                ScrollView(showsIndicators: false) {
                    sheetBodyContent(fillsHeight: false)
                }
            } else {
                // Prefer one-page layout; fall back to scroll only if large cards don't fit.
                ViewThatFits(in: .vertical) {
                    sheetBodyContent(fillsHeight: true)
                    ScrollView(showsIndicators: false) {
                        sheetBodyContent(fillsHeight: false)
                    }
                }
            }
        }
        .onPreferenceChange(PlanAddLibraryWidthKey.self) { libraryContentWidth = $0 }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !showsMealEmptyState {
                footerBar
            }
        }
    }

    /// Shared body for Meal / Workout / Recovery / Habit.
    private func sheetBodyContent(fillsHeight: Bool) -> some View {
        VStack(alignment: .leading, spacing: majorSectionSpacing) {
            activityTypePickerSection
                .padding(.top, 8)

            sectionPanel {
                dateChipButton
            }

            sectionPanel {
                VStack(alignment: .leading, spacing: 10) {
                    itemPickerSection

                    // Meal macros stay with the selected card; duration is its own panel below.
                    if showsMealMacros {
                        selectedParametersSection
                    }
                }
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: PlanAddLibraryWidthKey.self,
                            value: geo.size.width
                        )
                    }
                }
            }

            if showsDurationPanel {
                sectionPanel {
                    durationPickerSection
                }
            }

            if !showsMealEmptyState {
                sectionPanel {
                    timePickerSection
                }
            }

            if fillsHeight {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, contentPadding)
        .padding(.bottom, 8)
        .frame(
            maxWidth: .infinity,
            maxHeight: fillsHeight ? .infinity : nil,
            alignment: .topLeading
        )
    }

    /// Elevated region chrome — white/charcoal tile + hairline so Date / Library / Time read as blocks.
    @ViewBuilder
    private func sectionPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(sectionPanelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: sectionPanelRadius, style: .continuous)
                    .fill(sectionPanelFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: sectionPanelRadius, style: .continuous)
                    .strokeBorder(sectionPanelStroke, lineWidth: 1)
            }
    }

    /// Protein / carbs / fats / fiber under the selected meal card.
    private var showsMealMacros: Bool {
        viewModel.selectedType == .meal && viewModel.selectedMealForPlanner != nil
    }

    /// Workout / Recovery duration — separate panel from the library cards.
    private var showsDurationPanel: Bool {
        viewModel.selectedType == .workout || viewModel.selectedType == .recovery
    }

    private var footerBar: some View {
        saveButton
            .padding(.horizontal, contentPadding)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(sectionPanelStroke.opacity(palette.isLight ? 0.85 : 1))
                        .frame(height: 1)
                    screenBackground
                }
                .ignoresSafeArea(edges: .bottom)
            }
    }

    var scenarioTitle: String {
        switch viewModel.selectedType {
        case .meal: return WeekFitLocalizedString("planner.add.scenario.meal")
        case .workout: return WeekFitLocalizedString("planner.add.scenario.workout")
        case .recovery: return WeekFitLocalizedString("planner.add.scenario.recovery")
        case .habit: return WeekFitLocalizedString("planner.add.scenario.habit")
        }
    }

    var librarySectionTitle: String {
        switch viewModel.selectedType {
        case .meal: return WeekFitLocalizedString("planner.add.library.meals")
        case .workout: return WeekFitLocalizedString("planner.add.library.workouts")
        case .recovery: return WeekFitLocalizedString("planner.add.library.recoveryActivities")
        case .habit: return WeekFitLocalizedString("planner.add.library.habits")
        }
    }

    var selectionPrompt: String {
        switch viewModel.selectedType {
        case .meal: return WeekFitLocalizedString("planner.add.prompt.selectMeal")
        case .workout: return WeekFitLocalizedString("planner.add.prompt.selectWorkout")
        case .recovery: return WeekFitLocalizedString("planner.add.prompt.selectRecovery")
        case .habit: return WeekFitLocalizedString("planner.add.prompt.selectHabit")
        }
    }

    var dateChipButton: some View {
        Button {
            lightHaptic.impactOccurred()
            showDatePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectionAccent)

                Text(addSheetDayChipTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.55))

                Spacer(minLength: 0)
            }
            .frame(minHeight: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WeekFitLocalizedString("planner.sheet.dateLabel"))
        .accessibilityValue(addSheetDayChipTitle)
    }

    @ViewBuilder
    var selectedParametersSection: some View {
        switch viewModel.selectedType {
        case .meal:
            if let meal = viewModel.selectedMealForPlanner {
                mealMacrosRow(meal)
            }
        case .workout, .recovery:
            durationPickerSection
        case .habit:
            EmptyView()
        }
    }

    func mealMacrosRow(_ meal: Meals) -> some View {
        let unit = WeekFitLocalizedString("common.unit.gramShort")
        return HStack(spacing: 0) {
            macroStat(
                label: WeekFitLocalizedString("nutrition.macro.protein"),
                value: "\(meal.protein) \(unit)"
            )
            macroDivider
            macroStat(
                label: WeekFitLocalizedString("nutrition.macro.carbs"),
                value: "\(meal.carbs) \(unit)"
            )
            macroDivider
            macroStat(
                label: WeekFitLocalizedString("nutrition.macro.fats"),
                value: "\(meal.fats) \(unit)"
            )
            macroDivider
            macroStat(
                label: WeekFitLocalizedString("nutrition.macro.fiber"),
                value: "\(meal.fiber) \(unit)"
            )
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: WeekFitLocalizedString("planner.add.nutritionA11yFormat"),
                meal.title,
                meal.protein,
                meal.carbs,
                meal.fats,
                meal.fiber
            )
        )
    }

    private func formattedDurationLabel(_ minutes: Int) -> String {
        String(format: WeekFitLocalizedString("common.duration.minutesFormat"), minutes)
    }

    func macroStat(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    var macroDivider: some View {
        Rectangle()
            .fill(palette.isLight ? Color.black.opacity(0.10) : WeekFitTheme.whiteOpacity(0.10))
            .frame(width: 1, height: 28)
    }

    func remapSelectedSlot(toDay newDate: Date) {
        let day = calendar.startOfDay(for: newDate)
        let reference = viewModel.selectedSlot ?? Date()
        let hour = calendar.component(.hour, from: reference)
        let minute = calendar.component(.minute, from: reference)
        guard let remapped = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else {
            return
        }
        viewModel.selectedSlot = viewModel.clampedTimelineDate(remapped)
    }

    func isPastSlot(_ slot: Date) -> Bool {
        if isEditingOriginalSlot(slot) {
            return false
        }

        if !calendar.isDate(slot, inSameDayAs: Date()) {
            return false
        }

        return slot < Date()
    }

    func isEditingOriginalSlot(_ slot: Date) -> Bool {
        guard let editingDate = viewModel.editingActivity?.date else { return false }
        return calendar.isDate(slot, equalTo: editingDate, toGranularity: .minute)
    }
}

// MARK: - Sections

private extension PlanAddActivitySheet {

    private var categoryPickerTrackFill: Color {
        palette.isLight ? Color(white: 0.93) : PlanAddNightChrome.trackFill
    }

    private var categoryPickerSelectedFill: Color {
        // Night: soft elevated pill — avoid near-white glare on charcoal.
        palette.isLight ? Color.white : PlanAddNightChrome.selectedPill
    }

    private var usesAccessibilityCategoryLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var activityTypePickerSection: some View {
        Group {
            if usesAccessibilityCategoryLayout {
                categoryPickerGrid
            } else {
                // Ideal width = 4 × longest title; otherwise fall back to wrapping grid.
                ViewThatFits(in: .horizontal) {
                    categoryPickerSingleRow
                    categoryPickerGrid
                }
            }
        }
    }

    private var categoryPickerSingleRow: some View {
        PlanAddEqualWidthSegmentLayout {
            ForEach(PlannerType.allCases, id: \.segmentID) { type in
                typeSegmentButton(type, allowsMultiline: false)
            }
        }
        .padding(4)
        .background {
            Capsule(style: .continuous)
                .fill(categoryPickerTrackFill)
        }
    }

    private var categoryPickerGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ],
            spacing: 4
        ) {
            ForEach(PlannerType.allCases, id: \.segmentID) { type in
                typeSegmentButton(type, allowsMultiline: true)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(categoryPickerTrackFill)
        }
    }

    private func selectPlannerType(_ type: PlannerType) {
        guard viewModel.selectedType != type else { return }
        lightHaptic.impactOccurred()
        let apply = {
            showExpandedTimePicker = false
            viewModel.selectType(type)
        }
        if reduceMotion {
            apply()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                apply()
            }
        }
    }

    var itemPickerSection: some View {
        VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(librarySectionTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(textPrimary)

                Spacer(minLength: 8)

                if showsLibraryViewAll {
                    Button {
                        lightHaptic.impactOccurred()
                        openLibraryCatalog()
                    } label: {
                        Text(WeekFitLocalizedString("planner.sheet.viewAll"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectionAccent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showsMealEmptyState {
                emptyMealPickerState
            } else {
                itemPickerCarousel
            }

            if !viewModel.hasValidItemSelection, !showsMealEmptyState {
                Text(selectionPrompt)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(textSecondary)
            }
        }
    }

    private func openLibraryCatalog() {
        switch viewModel.selectedType {
        case .meal:
            mealSheetStep = .library
            mealSheetDetent = .medium
            showMealSheet = true
        case .workout, .recovery, .habit:
            showOptionCatalogSheet = true
        }
    }

    var itemPickerCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: libraryCardGap) {
                    if viewModel.selectedType == .meal {
                        ForEach(availableMeals) { meal in
                            mealOptionCard(meal)
                                .id(meal.id)
                        }
                    } else {
                        ForEach(currentOptions, id: \.imageName) { option in
                            optionCard(option)
                                .id(optionScrollID(option))
                        }
                    }
                }
                .padding(.horizontal, addSheetCarouselInset)
            }
            .onAppear { scrollToSelectedOption(proxy) }
            .onChange(of: viewModel.selectedItem.title) { _, _ in scrollToSelectedOption(proxy) }
            .onChange(of: viewModel.selectedType) { _, _ in scrollToSelectedOption(proxy) }
            .onChange(of: viewModel.selectedMealID) { _, _ in scrollToSelectedOption(proxy) }
        }
    }

    var emptyMealPickerState: some View {
        MealLibraryEmptyStateCard(
            title: WeekFitLocalizedString("planner.emptyMeal.title"),
            message: WeekFitLocalizedString("planner.emptyMeal.message"),
            ctaTitle: WeekFitLocalizedString("meals.emptyLibrary.createMealCTA"),
            benefits: [],
            presentation: .compact
        ) {
            lightHaptic.impactOccurred()
            mealSheetStep = .builder
            mealSheetDetent = .large
            showMealSheet = true
        }
    }

    var timePickerSection: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(WeekFitLocalizedString("planner.sheet.timeLabel"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(textPrimary)

                    Spacer(minLength: 8)

                    if let range = selectedDurationTimeRangeLabel {
                        Text(range)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(textSecondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Button {
                        lightHaptic.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showExpandedTimePicker.toggle()
                        }
                    } label: {
                        Text(
                            showExpandedTimePicker
                                ? WeekFitLocalizedString("planner.sheet.changeAction")
                                : WeekFitLocalizedString("planner.time.chooseTime")
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectionAccent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, sectionHeaderSpacing)

                if showExpandedTimePicker {
                    timeSelectionSection(proxy)
                } else {
                    quickTimePicksRow
                }

                if hasSelectedTimeConflict {
                    Text(WeekFitLocalizedString("planner.time.overlapMessage"))
                        .font(.caption)
                        .foregroundStyle(WeekFitLightTokens.critical)
                        .lineLimit(2)
                        .padding(.top, 8)
                } else if let suggestion = suggestedTimeLine, let recommended = recommendedSlot {
                    Button {
                        lightHaptic.impactOccurred()
                        viewModel.selectedSlot = recommended
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selectionAccent.opacity(0.85))
                            Text(suggestion)
                                .font(.caption)
                                .foregroundStyle(textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .onAppear {
                ensureSelectedAvailableSlot(proxy)
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                ensureSelectedAvailableSlot(proxy)
            }
            .onChange(of: viewModel.selectedType) { _, _ in
                ensureSelectedAvailableSlot(proxy)
            }
            .onChange(of: viewModel.selectedDuration) { _, _ in
                ensureSelectedAvailableSlot(proxy)
            }
        }
    }

    private var recommendedSlot: Date? {
        buildTimeSlotStates().first { $0.isRecommended && !$0.isOccupied && !$0.isPast }?.slot
    }

    private var quickTimePicksRow: some View {
        let picks = quickTimePickStates
        return HStack(spacing: 10) {
            ForEach(picks) { state in
                timeSlotButton(state, compact: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var quickTimePickStates: [AddSheetTimeSlotState] {
        let all = buildTimeSlotStates().filter { !$0.isPast && !$0.isOccupied }
        guard !all.isEmpty else { return [] }

        if let selected = viewModel.selectedSlot,
           let selectedIndex = all.firstIndex(where: {
               calendar.isDate($0.slot, equalTo: selected, toGranularity: .minute)
           }) {
            let start = max(0, selectedIndex - 1)
            let end = min(all.count, start + 3)
            let adjustedStart = max(0, end - 3)
            return Array(all[adjustedStart..<end])
        }

        return Array(all.prefix(3))
    }

    private var suggestedTimeLine: String? {
        guard let recommended = recommendedSlot else { return nil }
        // Only meal windows are meaningful recommendations; first-free for others is not personalized.
        guard viewModel.selectedType == .meal else { return nil }
        let window = selectedTimeIntelligenceLabel
        guard !window.isEmpty else { return nil }
        return String(
            format: WeekFitLocalizedString("planner.time.suggestedWindowFormat"),
            slotTitle(recommended),
            window
        )
    }

    /// Workout / Recovery: selected start–end interval from duration (e.g. "13:30–14:15").
    private var selectedDurationTimeRangeLabel: String? {
        guard viewModel.selectedType == .workout || viewModel.selectedType == .recovery,
              let start = viewModel.selectedSlot else { return nil }
        let end = calendar.date(byAdding: .minute, value: viewModel.selectedDuration, to: start) ?? start
        return "\(slotTitle(start))–\(slotTitle(end))"
    }

    @ViewBuilder
    var durationPickerSection: some View {
        if viewModel.selectedType == .workout || viewModel.selectedType == .recovery {
            VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(WeekFitLocalizedString("planner.duration.pickerTitle"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(textPrimary)

                    Spacer(minLength: 8)

                    Button {
                        lightHaptic.impactOccurred()
                        viewModel.customDuration = viewModel.selectedDuration
                        viewModel.showCustomDuration = true
                    } label: {
                        Text(customDurationHeaderTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectionAccent)
                    }
                    .buttonStyle(.plain)
                }

                FlowLayout(spacing: 6) {
                    ForEach(durationPresets, id: \.self) { minutes in
                        durationButton(minutes)
                    }
                }
            }
        }
    }

    private var customDurationHeaderTitle: String {
        if isCustomDurationSelected {
            return String(
                format: WeekFitLocalizedString("planner.duration.customMinutesFormat"),
                viewModel.selectedDuration
            )
        }
        return WeekFitLocalizedString("planner.duration.customEllipsis")
    }

    private var durationPresets: [Int] {
        switch viewModel.selectedType {
        case .recovery:
            return [10, 15, 20, 30]
        case .workout:
            return [15, 30, 45, 60]
        case .meal, .habit:
            return []
        }
    }

    private var isCustomDurationSelected: Bool {
        !durationPresets.contains(viewModel.selectedDuration)
    }
}

// MARK: - Section Components

private extension PlanAddActivitySheet {

    func sheetSectionHeader(
        _ title: String,
        subtitle: String? = nil,
        trailing: String? = nil,
        trailingAction: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15.6, weight: .semibold))
                    .foregroundStyle(textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.2, weight: .regular))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            Spacer()

            if let trailing, let trailingAction {
                Button {
                    lightHaptic.impactOccurred()
                    trailingAction()
                } label: {
                    Text(trailing)
                        .font(.system(size: 12.2, weight: .semibold))
                        .foregroundStyle(viewModel.selectedType.color.opacity(0.78))
                }
                .buttonStyle(.plain)
            }
        }
    }

    func typeSegmentButton(_ type: PlannerType, allowsMultiline: Bool) -> some View {
        let active = viewModel.selectedType == type

        return Button {
            selectPlannerType(type)
        } label: {
            Text(localizedTitle(for: type))
                .font(.system(size: 14.5, weight: active ? .semibold : .medium))
                .foregroundStyle(
                    active
                        ? (palette.isLight ? type.color : PlanAddNightChrome.softAccent(for: type))
                        : textSecondary
                )
                .lineLimit(allowsMultiline ? 3 : 1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: !allowsMultiline, vertical: false)
                .frame(maxWidth: .infinity)
                .frame(minHeight: allowsMultiline ? 40 : 34)
                .padding(.horizontal, 2)
                .padding(.vertical, allowsMultiline ? 4 : 0)
                .background {
                    if active {
                        Capsule(style: .continuous)
                            .fill(categoryPickerSelectedFill)
                            .matchedGeometryEffect(id: "planAddTypeSelection", in: typePickerNamespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityLabel(localizedTitle(for: type))
    }

    func optionCard(_ option: PlannerOption) -> some View {
        let active = selectedItemMatches(option)
        let thumb = activityThumbSize

        return Button {
            lightHaptic.impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.selectedItem = option
                viewModel.applyDefaultDurationForSelectedItem()
            }
        } label: {
            planSelectionCard(
                active: active,
                title: localizedTitle(for: option),
                subtitle: localizedSubtitle(for: option),
                width: libraryCardWidth,
                thumbSize: thumb,
                clipsMediaToCircle: true
            ) {
                activityCircularPhoto(option: option, size: thumb)
            }
        }
        .buttonStyle(.plain)
    }

    func mealOptionCard(_ meal: Meals) -> some View {
        let active = viewModel.selectedMealID == meal.id
        let thumb = mealThumbSize

        return Button {
            lightHaptic.impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.selectedMealID = meal.id
                viewModel.selectedItem = viewModel.plannerOption(for: meal)
            }
        } label: {
            planSelectionCard(
                active: active,
                title: meal.title,
                subtitle: "\(meal.calories) \(WeekFitLocalizedString("common.unit.kcal"))",
                width: libraryCardWidth,
                thumbSize: thumb,
                clipsMediaToCircle: false
            ) {
                mealPreview(meal, size: thumb)
            }
        }
        .buttonStyle(.plain)
    }

    func planSelectionCard<Thumb: View>(
        active: Bool,
        title: String,
        subtitle: String,
        width: CGFloat,
        thumbSize: CGFloat,
        clipsMediaToCircle: Bool,
        @ViewBuilder thumb: () -> Thumb
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if clipsMediaToCircle {
                        thumb()
                    } else {
                        // Square image well — plate fills ~88% without cropping the dish.
                        thumb()
                    }
                }
                .frame(width: thumbSize, height: thumbSize)
                .frame(maxWidth: .infinity)

                if active {
                    selectionCheckmark
                }
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: cardTitleBlockHeight, alignment: .topLeading)
                .padding(.top, 10)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
        .padding(cardInnerPadding)
        .frame(width: width, alignment: .topLeading)
        // Selection stroke drawn inset so active/inactive cards stay the same size.
        .background {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    active
                        ? selectionAccent.opacity(palette.isLight ? 0.10 : 0.16)
                        : (palette.isLight
                            ? Color(white: 0.985)
                            : PlanAddNightChrome.elevatedSurface)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(
                    active
                        ? selectionAccent.opacity(palette.isLight ? 1 : 0.72)
                        : sectionPanelStroke.opacity(palette.isLight ? 0.90 : 1),
                    lineWidth: active ? 1.25 : 1
                )
        }
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

// MARK: - Time / Duration

private extension PlanAddActivitySheet {

    func buildTimeSlotStates() -> [AddSheetTimeSlotState] {
        let slots = timeSlots
        let selectedSlot = viewModel.selectedSlot
        let blocksTime = viewModel.selectedType.blocksPlannerTime
        let duration = viewModel.selectedDuration
        let excluding = viewModel.editingActivity

        var recommendedSlot: Date?
        var states: [AddSheetTimeSlotState] = []
        states.reserveCapacity(slots.count)

        for slot in slots {
            let past = isPastSlot(slot)
            let occupied = !past && viewModel.hasTimeConflict(
                newStart: slot,
                durationMinutes: duration,
                activities: plannedActivities,
                excluding: excluding,
                newEventBlocksPlannerTime: blocksTime
            )

            if recommendedSlot == nil, !past, !occupied {
                recommendedSlot = slot
            }

            let active = selectedSlot.map {
                calendar.isDate($0, equalTo: slot, toGranularity: .minute)
            } ?? false

            states.append(
                AddSheetTimeSlotState(
                    slot: slot,
                    isPast: past,
                    isOccupied: occupied,
                    isActive: active,
                    isRecommended: false
                )
            )
        }

        guard let recommendedSlot else { return states }

        return states.map { state in
            guard calendar.isDate(state.slot, equalTo: recommendedSlot, toGranularity: .minute) else {
                return state
            }

            return AddSheetTimeSlotState(
                slot: state.slot,
                isPast: state.isPast,
                isOccupied: state.isOccupied,
                isActive: state.isActive,
                isRecommended: true
            )
        }
    }

    func firstAvailableSlot(from states: [AddSheetTimeSlotState]) -> Date? {
        states.first { !$0.isPast && !$0.isOccupied }?.slot
    }

    func firstAvailableSlot() -> Date? {
        firstAvailableSlot(from: buildTimeSlotStates())
    }

    func ensureSelectedAvailableSlot(_ proxy: ScrollViewProxy) {
        let slotStates = buildTimeSlotStates()

        DispatchQueue.main.async {
            let currentSlot = viewModel.selectedSlot

            let currentIsUsable: Bool = {
                guard let currentSlot else { return false }

                return slotStates.contains { state in
                    calendar.isDate(state.slot, equalTo: currentSlot, toGranularity: .minute)
                        && !state.isPast
                        && !state.isOccupied
                }
            }()

            let targetSlot = currentIsUsable ? currentSlot : firstAvailableSlot(from: slotStates)

            guard let targetSlot else { return }

            if !currentIsUsable {
                viewModel.selectedSlot = targetSlot
            }

            proxy.scrollTo(timeSlotID(targetSlot), anchor: .center)
        }
    }

    func timeSelectionSection(_ proxy: ScrollViewProxy) -> some View {
        let slotStates = buildTimeSlotStates()
        let showsBusyLegend = slotStates.contains { !$0.isPast && $0.isOccupied }
        let showsPastLegend = slotStates.contains { $0.isPast }

        return VStack(alignment: .leading, spacing: 7) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(slotStates) { state in
                        timeSlotButton(state)
                            .id(timeSlotID(state.slot))
                    }
                }
                .padding(.horizontal, addSheetCarouselInset)
                .padding(.vertical, 2)
            }
            .onAppear {
                ensureSelectedAvailableSlot(proxy)
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                ensureSelectedAvailableSlot(proxy)
            }
            .onChange(of: viewModel.selectedType) { _, _ in
                ensureSelectedAvailableSlot(proxy)
            }
            .onChange(of: viewModel.selectedDuration) { _, _ in
                ensureSelectedAvailableSlot(proxy)
            }

            timeSlotLegendRow(showsPastLegend: showsPastLegend, showsBusyLegend: showsBusyLegend)
        }
    }

    @ViewBuilder
    func timeSlotLegendRow(showsPastLegend: Bool, showsBusyLegend: Bool) -> some View {
        if showsPastLegend || showsBusyLegend {
            HStack(spacing: 14) {
                if showsPastLegend {
                    timeLegendItem(
                        color: palette.isLight
                            ? WeekFitTheme.disabledText
                            : textPrimary.opacity(0.22),
                        label: WeekFitLocalizedString("planner.time.pastLegend")
                    )
                }

                if showsBusyLegend {
                    timeLegendItem(
                        color: busySlotColor.opacity(0.78),
                        label: WeekFitLocalizedString("planner.time.busyLegend")
                    )
                }
            }
            .padding(.horizontal, addSheetCarouselInset)
        }
    }

    func timeLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(WeekFitTheme.tertiaryText)
        }
    }

    func timeSlotButton(_ state: AddSheetTimeSlotState, compact: Bool = false) -> some View {
        let slot = state.slot
        let active = state.isActive
        let occupied = state.isOccupied
        let isPast = state.isPast

        return Button {
            guard !isPast else { return }

            lightHaptic.impactOccurred()
            viewModel.selectedSlot = slot
        } label: {
            plannerControlChip(
                title: slotTitle(slot),
                active: active,
                monospaced: true,
                minWidth: compact ? 76 : 58
            )
        }
        .buttonStyle(.plain)
        .disabled(isPast || occupied)
        .opacity(isPast ? 0.30 : (occupied ? 0.45 : 1.0))
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    func durationButton(_ minutes: Int) -> some View {
        let active = viewModel.selectedDuration == minutes
        return Button {
            lightHaptic.impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                viewModel.selectedDuration = minutes
                viewModel.customDuration = minutes
            }
        } label: {
            plannerControlChip(
                title: String(format: WeekFitLocalizedString("common.duration.minutesFormat"), minutes),
                active: active,
                monospaced: false,
                minWidth: 64
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// Shared Duration / Time chip: ~44 pt, no shadow, weight + border for selection.
    @ViewBuilder
    func plannerControlChip(
        title: String,
        active: Bool,
        monospaced: Bool,
        minWidth: CGFloat
    ) -> some View {
        let label = Text(title)
            .font(.subheadline.weight(active ? .bold : .semibold))
            .foregroundStyle(active ? textPrimary : textSecondary)
            .lineLimit(1)

        Group {
            if monospaced {
                label.monospacedDigit()
            } else {
                label
            }
        }
        .padding(.horizontal, 12)
        .frame(minWidth: minWidth, minHeight: plannerChipHeight)
        .background {
            RoundedRectangle(cornerRadius: plannerChipCorner, style: .continuous)
                .fill(
                    active
                        ? selectionAccent.opacity(palette.isLight ? 0.14 : 0.18)
                        : (palette.isLight ? Color(white: 0.97) : chipNeutralFill)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: plannerChipCorner, style: .continuous)
                .strokeBorder(
                    active
                        ? selectionAccent.opacity(palette.isLight ? 1 : 0.70)
                        : sectionPanelStroke.opacity(palette.isLight ? 0.85 : 1),
                    lineWidth: active ? 1.25 : 1
                )
        }
    }
}

// MARK: - Buttons

private extension PlanAddActivitySheet {

    var saveButton: some View {
        let title = primaryActionTitle
        let enabled = canSaveSelectedItem && !isSaving

        return Button {
            saveSelectedItem()
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .tint(enabled ? Color.white : textSecondary)
                }

                Text(title)
                    .font(WeekFitType.button)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(enabled ? Color.white : textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(enabled ? actionButtonFill : disabledActionFill)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.22), value: viewModel.selectedType)
        .accessibilityLabel(title)
    }

    private var disabledActionFill: Color {
        palette.isLight
            ? Color(white: 0.90)
            : PlanAddNightChrome.elevatedSurface
    }

    var primaryActionTitle: String {
        if viewModel.editingActivity == nil {
            return WeekFitLocalizedString("planner.add.toPlan")
        }
        return WeekFitLocalizedString("planner.add.saveChanges")
    }
}

// MARK: - Custom Duration Sheet

private extension PlanAddActivitySheet {

    var customDurationSheet: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(WeekFitTheme.whiteOpacity(0.14))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text(AppText.Planner.customDurationTitle)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(AppText.Planner.customDurationSubtitle)
                    .font(.system(size: 13.2, weight: .medium))
                    .foregroundStyle(textSecondary)
            }

            Picker(WeekFitLocalizedString("planner.duration.pickerLabel"), selection: $viewModel.customDuration) {
                ForEach(Array(stride(from: 5, through: 240, by: 5)), id: \.self) { minutes in
                    Text(String(format: WeekFitLocalizedString("common.duration.minutesFormat"), minutes))
                        .tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)

            Button {
                viewModel.selectedDuration = viewModel.customDuration
                viewModel.showCustomDuration = false
            } label: {
                Text(String(format: WeekFitLocalizedString("planner.duration.setMinutesFormat"), viewModel.customDuration))
                    .font(WeekFitStyle.Font.button)
                    .foregroundStyle(palette.isLight ? Color.white : Color.black.opacity(0.84))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        viewModel.selectedType.color.opacity(palette.isLight ? 1.0 : 0.95)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 20)

            Button {
                viewModel.showCustomDuration = false
            } label: {
                Text(AppText.Common.Action.cancel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
        }
        .background(WeekFitTheme.backgroundColor.ignoresSafeArea())
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Images

private extension PlanAddActivitySheet {

    var selectionCheckmark: some View {
        Circle()
            .fill(selectionAccent)
            .frame(width: 22, height: 22)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .padding(6)
    }

    /// Workout / Recovery / Habit — circular photo, aspect-fill, no nested wells.
    func activityCircularPhoto(option: PlannerOption, size: CGFloat) -> some View {
        Group {
            if !option.imageName.isEmpty,
               FoodImageQualityValidator.isDisplayableAsset(named: option.imageName) {
                Image(option.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(selectionAccent.opacity(0.12))
                    Image(systemName: option.icon.isEmpty ? viewModel.selectedType.icon : option.icon)
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundStyle(selectionAccent.opacity(0.78))
                }
                .frame(width: size, height: size)
            }
        }
    }

    /// Meal plates — whole plate, no tinted well / nested colored container.
    func mealPreview(_ meal: Meals, size: CGFloat? = nil) -> some View {
        let thumb = size ?? mealThumbSize
        if meal.isFoodProduct {
            return AnyView(customFoodPreview(meal, size: thumb))
        }

        let sortedItems = meal.builderImageItems?.sorted { $0.zIndex < $1.zIndex } ?? []

        if !sortedItems.isEmpty {
            return AnyView(customMealPreview(items: sortedItems, size: thumb))
        }

        if !meal.imageName.isEmpty, FoodImageQualityValidator.isDisplayableAsset(named: meal.imageName) {
            return AnyView(mealPlateAsset(named: meal.imageName, size: thumb))
        }

        return AnyView(mealFallbackIcon(size: thumb))
    }

    func customFoodPreview(_ meal: Meals, size: CGFloat) -> some View {
        let plate = size * mealPlateFillRatio
        return AsyncCustomFoodVisualView(
            filename: meal.displayPhotoFilename,
            placeholderInitial: meal.placeholderInitial,
            size: plate,
            imageScale: 1.08,
            fallbackSystemImage: PlannerType.meal.icon
        )
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    func customMealPreview(items sortedItems: [MealBuilderImageItem], size: CGFloat) -> some View {
        // Plate occupies ~88% of the square well; whole dish + shadow room, no crop.
        BuiltMealPlateView(
            items: sortedItems,
            plateSize: size * mealPlateFillRatio,
            itemScale: 0.74,
            offsetScale: 0.32,
            plateOpacity: 0.82,
            shadowOpacity: 0.10,
            layoutMode: .preview,
            showsPlateChrome: true
        )
        .frame(width: size, height: size)
    }

    func mealPlateAsset(named imageName: String, size: CGFloat) -> some View {
        // scaledToFit keeps the whole plate; scale counters transparent asset padding.
        Image(imageName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .scaleEffect(1.10)
            .frame(width: size * mealPlateFillRatio, height: size * mealPlateFillRatio)
            .frame(width: size, height: size)
            .clipped()
    }

    func mealFallbackIcon(size: CGFloat) -> some View {
        Image(systemName: PlannerType.meal.icon)
            .font(.system(size: size * 0.28, weight: .semibold))
            .foregroundStyle(selectionAccent.opacity(0.72))
            .frame(width: size, height: size)
    }

}

// MARK: - Styling / State Helpers

private extension PlanAddActivitySheet {
    
    func timeSlotID(_ slot: Date) -> String {
        "\(Int(slot.timeIntervalSince1970))"
    }

    var addSheetBackground: some View {
        ZStack {
            PlanAddSheetPalette.sheetBase(for: viewModel.selectedType, isLight: palette.isLight)

            // Quiet type wash — depth without painting the whole sheet in accent.
            LinearGradient(
                colors: PlanAddSheetPalette.sheetWash(
                    for: viewModel.selectedType,
                    isLight: palette.isLight
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)

            if !palette.isLight {
                LinearGradient(
                    colors: [
                        WeekFitTheme.whiteOpacity(0.045),
                        WeekFitTheme.whiteOpacity(0.012),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.28), value: viewModel.selectedType)
    }

    var horizontalFadeMask: some View {
        LinearGradient(
            colors: [Color.clear, Color.black, Color.black, Color.clear],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var durationFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.96), location: 0.0),
                .init(color: .black.opacity(0.96), location: 0.88),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var saveButtonForeground: Color {
        if palette.isLight {
            return Color.white
        }
        switch viewModel.selectedType {
        case .workout, .recovery:
            return WeekFitTheme.whiteOpacity(0.92)
        case .meal, .habit:
            return Color.black.opacity(0.84)
        }
    }

    var addButtonTitle: String {
        switch viewModel.selectedType {
        case .meal: return WeekFitLocalizedString("planner.add.meal")
        case .workout: return WeekFitLocalizedString("planner.add.workout")
        case .recovery: return WeekFitLocalizedString("planner.add.recovery")
        case .habit: return WeekFitLocalizedString("planner.add.habit")
        }
    }

    var chooseItemSubtitle: String {
        switch viewModel.selectedType {
        case .meal:
            return viewModel.customMeals.isEmpty
                ? WeekFitLocalizedString("planner.sheet.chooseMeal.emptySubtitle")
                : WeekFitLocalizedString("planner.sheet.chooseMeal.savedSubtitle")
        case .workout:
            return WeekFitLocalizedString("planner.sheet.chooseWorkout.subtitle")
        case .recovery:
            return WeekFitLocalizedString("planner.sheet.chooseRecovery.subtitle")
        case .habit:
            return WeekFitLocalizedString("planner.sheet.chooseHabit.subtitle")
        }
    }

    var timeSectionSubtitle: String {
        hasSelectedTimeConflict
            ? WeekFitLocalizedString("planner.time.chooseFreeSlot")
            : WeekFitLocalizedString("planner.time.bestTime")
    }

    var durationSectionSubtitle: String {
        viewModel.selectedType == .recovery
            ? WeekFitLocalizedString("planner.duration.recoverySubtitle")
            : WeekFitLocalizedString("planner.duration.energySubtitle")
    }

    var selectedTimeIntelligenceLabel: String {
        guard let selectedSlot = viewModel.selectedSlot else { return WeekFitLocalizedString("planner.time.chooseTime") }
        guard !hasSelectedTimeConflict else { return WeekFitLocalizedString("planner.time.overlap") }

        let hour = calendar.component(.hour, from: selectedSlot)

        switch viewModel.selectedType {
        case .meal:
            switch hour {
            case 6...10: return WeekFitLocalizedString("planner.time.meal.breakfast")
            case 11...14: return WeekFitLocalizedString("planner.time.meal.lunch")
            case 17...21: return WeekFitLocalizedString("planner.time.meal.dinner")
            default: return WeekFitLocalizedString("planner.time.meal.lightFuel")
            }
        case .workout:
            switch hour {
            case 6...10: return WeekFitLocalizedString("planner.time.workout.strongEnergy")
            case 11...15: return WeekFitLocalizedString("planner.time.workout.balanced")
            case 16...19: return WeekFitLocalizedString("planner.time.workout.cardio")
            default: return WeekFitLocalizedString("planner.time.workout.gentle")
            }
        case .recovery:
            switch hour {
            case 6...11: return WeekFitLocalizedString("planner.time.recovery.reset")
            case 12...17: return WeekFitLocalizedString("planner.time.recovery.gap")
            default: return WeekFitLocalizedString("planner.time.recovery.windDown")
            }
        case .habit:
            switch hour {
            case 6...11: return WeekFitLocalizedString("planner.time.habit.morning")
            case 12...17: return WeekFitLocalizedString("planner.time.habit.steady")
            default: return WeekFitLocalizedString("planner.time.habit.evening")
            }
        }
    }

    var selectedTimeStatusText: String {
        hasSelectedTimeConflict
            ? WeekFitLocalizedString("planner.time.overlapMessage")
            : selectedTimeIntelligenceLabel
    }

    func localizedTitle(for type: PlannerType) -> String {
        switch type {
        case .meal: return WeekFitLocalizedString("planner.type.meal")
        case .workout: return WeekFitLocalizedString("planner.type.workout")
        case .recovery: return WeekFitLocalizedString("planner.type.recovery")
        case .habit: return WeekFitLocalizedString("planner.type.habit")
        }
    }

    func localizedTitle(for option: PlannerOption) -> String {
        PlannerOptionLocalization.localizedTitle(for: option.title)
    }

    func localizedSubtitle(for option: PlannerOption) -> String {
        PlannerOptionLocalization.localizedSubtitle(for: option.subtitle)
    }

    var hasSelectedTimeConflict: Bool {
        guard let selectedSlot = viewModel.selectedSlot else { return false }

        return viewModel.hasTimeConflict(
            newStart: selectedSlot,
            durationMinutes: viewModel.selectedDuration,
            activities: plannedActivities,
            excluding: viewModel.editingActivity,
            newEventBlocksPlannerTime: viewModel.selectedType.blocksPlannerTime
        )
    }

    var addSheetDayChipTitle: String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        let shortDay = formatter.string(from: viewModel.selectedDate)

        if calendar.isDateInToday(viewModel.selectedDate) {
            return String(
                format: WeekFitLocalizedString("planner.sheet.todayDateFormat"),
                shortDay
            )
        }

        if calendar.isDateInTomorrow(viewModel.selectedDate) {
            return String(
                format: WeekFitLocalizedString("planner.sheet.tomorrowDateFormat"),
                shortDay
            )
        }

        formatter.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return formatter.string(from: viewModel.selectedDate)
    }

    func typeButtonActiveForeground(for type: PlannerType) -> Color {
        if palette.isLight {
            return WeekFitTheme.primaryText
        }
        switch type {
        case .workout, .recovery, .habit:
            return WeekFitTheme.whiteOpacity(0.90)
        case .meal:
            return Color.black.opacity(0.82)
        }
    }

    func selectionChipForeground(active: Bool, occupied: Bool, isPast: Bool) -> Color {
        if palette.isLight {
            if isPast { return WeekFitTheme.disabledText }
            if active && occupied { return WeekFitLightTokens.critical }
            if active { return WeekFitTheme.primaryText }
            if occupied { return busySlotColor }
            return WeekFitTheme.secondaryText
        }
        if isPast { return textPrimary.opacity(0.18) }
        if active && occupied { return Color.red.opacity(0.84) }
        if active { return textPrimary.opacity(0.96) }
        if occupied { return busySlotColor.opacity(0.62) }
        return textPrimary.opacity(0.58)
    }

    func selectionChipBackground(active: Bool, occupied: Bool, isPast: Bool) -> Color {
        if palette.isLight {
            if isPast { return WeekFitLightTokens.surfaceTertiary.opacity(0.70) }
            if active && occupied { return WeekFitLightTokens.critical.opacity(0.12) }
            if occupied { return busySlotColor.opacity(0.12) }
            if active { return viewModel.selectedType.color.opacity(0.16) }
            return PlanAddSheetPalette.chipWellFill(for: viewModel.selectedType)
        }
        if isPast { return WeekFitTheme.whiteOpacity(0.012) }
        if active && occupied { return Color.red.opacity(0.075) }
        if occupied { return busySlotColor.opacity(0.07) }
        if active { return viewModel.selectedType.color.opacity(0.08) }
        return WeekFitTheme.whiteOpacity(0.022)
    }

    func selectionChipBorder(active: Bool, occupied: Bool, isPast: Bool) -> Color {
        if palette.isLight {
            if isPast { return WeekFitLightTokens.divider.opacity(0.40) }
            if active && occupied { return WeekFitLightTokens.critical.opacity(0.45) }
            if occupied { return busySlotColor.opacity(0.40) }
            if active { return viewModel.selectedType.color.opacity(0.50) }
            return WeekFitLightTokens.divider.opacity(0.50)
        }
        if isPast { return WeekFitTheme.whiteOpacity(0.04) }
        if active && occupied { return Color.red.opacity(0.22) }
        if occupied { return busySlotColor.opacity(0.20) }
        if active { return viewModel.selectedType.color.opacity(0.22) }
        return WeekFitTheme.whiteOpacity(0.05)
    }

    func selectedItemMatches(_ option: PlannerOption) -> Bool {
        option.imageName == viewModel.selectedItem.imageName ||
        option.title == viewModel.selectedItem.title
    }

    func slotTitle(_ date: Date) -> String {
        // Match mockup clock chips: "12:15" without locale AM/PM suffix.
        date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    func optionScrollID(_ option: PlannerOption) -> String {
        "\(viewModel.selectedType.title)-\(option.title)-\(option.imageName)"
    }

    func scrollToSelectedOption(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if viewModel.selectedType == .meal {
                if let selectedMealID = viewModel.selectedMealID {
                    let isFirst = availableMeals.first?.id == selectedMealID
                    proxy.scrollTo(selectedMealID, anchor: isFirst ? .leading : .center)
                } else if let firstID = availableMeals.first?.id {
                    proxy.scrollTo(firstID, anchor: .leading)
                }
            } else if viewModel.hasValidItemSelection {
                let isFirst = currentOptions.first.map(selectedItemMatches) ?? false
                proxy.scrollTo(
                    optionScrollID(viewModel.selectedItem),
                    anchor: isFirst ? .leading : .center
                )
            } else if let first = currentOptions.first {
                proxy.scrollTo(optionScrollID(first), anchor: .leading)
            }
        }
    }
}

// MARK: - Catalog Sheets

private extension PlanAddActivitySheet {

    var optionCatalogSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(currentOptions, id: \.imageName) { option in
                        Button {
                            lightHaptic.impactOccurred()
                            viewModel.selectedItem = option
                            viewModel.applyDefaultDurationForSelectedItem()
                            showOptionCatalogSheet = false
                        } label: {
                            optionCatalogRow(option)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(screenBackground.ignoresSafeArea())
            .navigationTitle(libraryCatalogTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(WeekFitLocalizedString("common.action.cancel")) {
                        showOptionCatalogSheet = false
                    }
                    .foregroundStyle(selectionAccent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var libraryCatalogTitle: String {
        switch viewModel.selectedType {
        case .meal: return WeekFitLocalizedString("planner.add.choose.meal")
        case .workout: return WeekFitLocalizedString("planner.add.choose.workout")
        case .recovery: return WeekFitLocalizedString("planner.add.choose.recovery")
        case .habit: return WeekFitLocalizedString("planner.add.choose.habit")
        }
    }

    func optionCatalogRow(_ option: PlannerOption) -> some View {
        let active = selectedItemMatches(option)
        return HStack(spacing: 12) {
            activityCircularPhoto(option: option, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(localizedTitle(for: option))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)

                Text(localizedSubtitle(for: option))
                    .font(.footnote)
                    .foregroundStyle(textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if active {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selectionAccent)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(active ? selectionAccent.opacity(0.10) : chipNeutralFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(active ? selectionAccent : Color.clear, lineWidth: 1.25)
        }
    }

    var mealLibrarySheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(availableMeals) { meal in
                        Button {
                            lightHaptic.impactOccurred()
                            viewModel.selectedMealID = meal.id
                            viewModel.selectedItem = viewModel.plannerOption(for: meal)
                            showMealSheet = false
                        } label: {
                            mealLibraryRow(meal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(QuickActionSheetDesign.Color.sheetBackground(for: .food).ignoresSafeArea())
            .navigationTitle(WeekFitLocalizedString("planner.sheet.chooseMeal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(WeekFitLocalizedString("common.action.cancel")) {
                        showMealSheet = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mealSheetDetent = .large
                        mealSheetStep = .builder
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(WeekFitLocalizedString("meals.createFoodOrMeal")))
                }
            }
        }
    }

    func mealLibraryRow(_ meal: Meals) -> some View {
        HStack(spacing: 12) {
            mealPreview(meal, size: 52)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(meal.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)

                Text(
                    String(
                        format: WeekFitLocalizedString("planner.meal.macroSummaryFormat"),
                        meal.calories,
                        meal.protein,
                        meal.carbs,
                        meal.fats
                    )
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textSecondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            if viewModel.selectedMealID == meal.id {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selectionAccent)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WeekFitTheme.whiteOpacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.05), lineWidth: 1)
        }
    }
}

// MARK: - Actions

private extension PlanAddActivitySheet {

    func closeAddSheet() {
        viewModel.closeAddSheet()
    }

    func saveSelectedItem() {
        guard canSaveSelectedItem, !isSaving else { return }

        isSaving = true
        viewModel.saveSelectedItem(
            activities: plannedActivities,
            modelContext: modelContext,
            activityRemindersEnabled: activityRemindersEnabled,
            completionCheckInsEnabled: completionCheckInsEnabled
        )

        // Conflict / save-failure keeps the screen open — allow retry.
        if viewModel.showAddActivity {
            isSaving = false
        }
    }

    func deleteActivity(_ activity: PlannedActivity) {
        viewModel.deleteActivity(activity, modelContext: modelContext)
    }

    var canSaveSelectedItem: Bool {
        guard viewModel.selectedSlot != nil else { return false }
        guard !hasSelectedTimeConflict else { return false }
        return viewModel.hasValidItemSelection
    }

    func saveMealToLibrary(_ meal: Meals) {
        let updatedMeals = CustomMealStore.upsert(
            meal,
            into: userSettings.customMealsCatalog
        )
        userSettings.replaceCustomMealsCatalog(updatedMeals)
        viewModel.syncCustomMeals(
            from: userSettings.customMealsCatalog,
            revision: userSettings.customMealsCatalogRevision
        )
        viewModel.selectedMealID = meal.id
        viewModel.selectedItem = viewModel.plannerOption(for: meal)
    }
}

// MARK: - Add sheet surfaces (4 types)

/// Calm night surfaces for Plan Add — charcoal canvas, muted accents, no OLED glare.
private enum PlanAddNightChrome {
    /// Soft charcoal canvas (~#1A1C20), lifted from pure black.
    static let canvas = Color(red: 0.102, green: 0.110, blue: 0.125)
    /// Quiet elevated wells for chips / idle cards.
    static let elevatedSurface = Color.white.opacity(0.07)
    static let cardFill = Color(red: 0.145, green: 0.152, blue: 0.168)
    static let trackFill = Color.white.opacity(0.06)
    /// Selected segment — soft slate, not near-white.
    static let selectedPill = Color(red: 0.22, green: 0.23, blue: 0.255)

    static func softAccent(for type: PlannerType) -> Color {
        switch type {
        case .meal:
            return Color(red: 0.45, green: 0.72, blue: 0.60) // muted sage
        case .workout:
            return Color(red: 0.48, green: 0.62, blue: 0.88) // soft steel blue
        case .recovery:
            return Color(red: 0.62, green: 0.55, blue: 0.82) // quiet lilac
        case .habit:
            return Color(red: 0.82, green: 0.62, blue: 0.42) // warm sand
        }
    }

    static func ctaFill(for type: PlannerType) -> Color {
        switch type {
        case .meal:
            return Color(red: 0.22, green: 0.46, blue: 0.38)
        case .workout:
            return Color(red: 0.26, green: 0.38, blue: 0.62)
        case .recovery:
            return Color(red: 0.38, green: 0.32, blue: 0.58)
        case .habit:
            return Color(red: 0.55, green: 0.38, blue: 0.22)
        }
    }
}

/// Soft stone sheets + family-tinted ceramic cards — Quick Log depth language, per Plan type.
/// Idle cards must never read as pure white on the sheet.
private enum PlanAddSheetPalette {

    @MainActor
    static func sheetBase(for type: PlannerType, isLight: Bool) -> Color {
        guard isLight else { return PlanAddNightChrome.canvas }
        switch type {
        case .meal:
            return Color(red: 0.941, green: 0.922, blue: 0.890) // #F0EBE3 deeper food stone
        case .workout:
            return Color(red: 0.922, green: 0.929, blue: 0.941) // #EBEDF0 cool slate mist
        case .recovery:
            return Color(red: 0.937, green: 0.929, blue: 0.949) // #EFEDF2 lilac stone
        case .habit:
            return Color(red: 0.941, green: 0.933, blue: 0.906) // #F0EEE7 champagne stone
        }
    }

    @MainActor
    static func sheetWash(for type: PlannerType, isLight: Bool) -> [Color] {
        let accent = isLight ? type.color : PlanAddNightChrome.softAccent(for: type)
        if isLight {
            return [
                accent.opacity(0.070),
                accent.opacity(0.022),
                Color.clear
            ]
        }
        return [
            accent.opacity(0.05),
            accent.opacity(0.018),
            Color.clear
        ]
    }

    @MainActor
    static func optionCardFill(active: Bool, type: PlannerType, isLight: Bool) -> Color {
        if !isLight {
            return active ? type.color.opacity(0.07) : WeekFitTheme.whiteOpacity(0.032)
        }
        if active {
            return type.color.opacity(0.16)
        }
        // One step lighter than the sheet, still clearly tinted — never pearl/white.
        switch type {
        case .meal:
            return Color(red: 0.973, green: 0.961, blue: 0.941) // #F8F5F0
        case .workout:
            return Color(red: 0.957, green: 0.961, blue: 0.969) // #F4F5F7
        case .recovery:
            return Color(red: 0.965, green: 0.957, blue: 0.973) // #F6F4F8
        case .habit:
            return Color(red: 0.973, green: 0.965, blue: 0.945) // #F8F6F1
        }
    }

    /// Shared idle well for the type row — keyed to the *current* sheet family.
    @MainActor
    static func typeChipIdleFill(for selectedType: PlannerType) -> Color {
        switch selectedType {
        case .meal:
            return Color(red: 0.922, green: 0.906, blue: 0.875) // #EBE7DF
        case .workout:
            return Color(red: 0.906, green: 0.914, blue: 0.925) // #E7E9EC
        case .recovery:
            return Color(red: 0.918, green: 0.910, blue: 0.929) // #EAE8ED
        case .habit:
            return Color(red: 0.922, green: 0.914, blue: 0.890) // #EBE9E3
        }
    }

    @MainActor
    static func chipWellFill(for type: PlannerType) -> Color {
        typeChipIdleFill(for: type)
    }

    @MainActor
    static func imageWellFill(for type: PlannerType, isLight: Bool) -> Color {
        guard isLight else { return WeekFitTheme.cardSurface.opacity(0.88) }
        // Slightly deeper than the card body so photos sit in a quiet nest.
        switch type {
        case .meal:
            return Color(red: 0.953, green: 0.941, blue: 0.918) // #F3F0EA
        case .workout:
            return Color(red: 0.941, green: 0.945, blue: 0.953) // #F0F1F3
        case .recovery:
            return Color(red: 0.949, green: 0.941, blue: 0.957) // #F2F0F4
        case .habit:
            return Color(red: 0.953, green: 0.945, blue: 0.925) // #F3F1EC
        }
    }

    @MainActor
    static func optionCardShadow(active: Bool, type: PlannerType, isLight: Bool) -> Color {
        if active {
            return type.color.opacity(isLight ? 0.12 : 0.014)
        }
        // Quiet contact only — no floating white-sticker look.
        return Color.black.opacity(isLight ? 0.035 : 0.012)
    }
}

/// Equal-width segments sized to the longest label so titles never truncate in a single row.
private struct PlanAddEqualWidthSegmentLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else {
            return .zero
        }

        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        // Slack covers medium → semibold width shift when selection changes.
        let segmentWidth = ceil((ideals.map(\.width).max() ?? 0) + 2)
        let height = max(ideals.map(\.height).max() ?? 0, 38)
        let count = CGFloat(subviews.count)
        let idealWidth = segmentWidth * count

        if let proposedWidth = proposal.width, proposedWidth.isFinite, proposedWidth > 0 {
            // Report ideal when proposed space is too narrow so ViewThatFits can fall back.
            if proposedWidth + 0.5 < idealWidth {
                return CGSize(width: idealWidth, height: height)
            }
            return CGSize(width: proposedWidth, height: height)
        }

        return CGSize(width: idealWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }

        let count = CGFloat(subviews.count)
        let segmentWidth = bounds.width / count

        for index in subviews.indices {
            let x = bounds.minX + CGFloat(index) * segmentWidth
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: segmentWidth, height: bounds.height)
            )
        }
    }
}
