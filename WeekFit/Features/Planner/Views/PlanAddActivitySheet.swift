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

    @Environment(\.weekFitPalette) private var palette

    private var textPrimary: Color { WeekFitTheme.primaryText }
    private var textSecondary: Color { WeekFitTheme.secondaryText }

    private let addSheetCarouselInset: CGFloat = 10
    private let busySlotColor = WeekFitTheme.orange
    private let addSheetMealCardWidth: CGFloat = 118
    private let addSheetMealCardHeight: CGFloat = 104
    private let addSheetMealImageWidth: CGFloat = 104
    private let addSheetMealImageHeight: CGFloat = 48
    /// Taller well so workout / recovery / habit people photos are not sliced into a thin strip.
    private let addSheetActivityCardHeight: CGFloat = 128
    private let addSheetActivityImageHeight: CGFloat = 72

    private let timelineStartHour = 5
    private let timelineEndHour = 24
    private let timelineMinuteStep = 15

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    private var calendar: Calendar { viewModel.calendar }
    private var availableMeals: [Meals] { viewModel.availableMeals }
    private var currentOptions: [PlannerOption] { viewModel.currentOptions }
    private var showsMealEmptyState: Bool { viewModel.selectedType == .meal && availableMeals.isEmpty }
    private var mealPickerSectionHeight: CGFloat {
        (viewModel.selectedType == .meal ? addSheetMealCardHeight : addSheetActivityCardHeight) + 8
    }

    

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

    private var addSheetPresentationDetents: Set<PresentationDetent> {
        if showsMealEmptyState {
            return [.fraction(0.62), .large]
        }
        return [.fraction(0.82), .large]
    }
    
    var body: some View {
        let _ = languageManager.selectedLanguage

        addActivitySheet
            .presentationDetents(addSheetPresentationDetents)
            .presentationDragIndicator(.hidden)
            .presentationContentInteraction(.scrolls)
            .weekFitSheetChrome(
                cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius,
                background: PlanAddSheetPalette.sheetBase(
                    for: viewModel.selectedType,
                    isLight: palette.isLight
                )
            )
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
                viewModel.syncCustomMeals(
                    from: userSettings.customMealsCatalog,
                    revision: userSettings.customMealsCatalogRevision
                )

                if viewModel.editingActivity == nil {
                    viewModel.syncDefaultSelectedMeal()
                }
            }
            .onChange(of: userSettings.customMealsCatalogRevision) { _, revision in
                viewModel.syncCustomMeals(
                    from: userSettings.customMealsCatalog,
                    revision: revision
                )

                if viewModel.editingActivity == nil {
                    viewModel.syncDefaultSelectedMeal()
                }
            }
    }
}

// MARK: - Main Sheet

private extension PlanAddActivitySheet {

    var addActivitySheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            addSheetGrabber

            sheetHeader
                .padding(.bottom, 8)

            Group {
                if showsMealEmptyState {
                    VStack(alignment: .leading, spacing: 6) {
                        activityTypePickerSection
                        itemPickerSection
                    }
                    .padding(.bottom, 4)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            activityTypePickerSection
                            itemPickerSection
                            timePickerSection
                            durationPickerSection
                        }
                        .padding(.bottom, 4)
                    }
                }
            }

            if !showsMealEmptyState {
                saveButton
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, WeekFitStyle.Size.horizontalPadding)
        .padding(.top, 7)
        .padding(.bottom, viewModel.editingActivity == nil ? 12 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { addSheetBackground }
    }

    var addSheetGrabber: some View {
        Capsule()
            .fill(
                palette.isLight
                    ? WeekFitLightTokens.shadowContact.opacity(0.18)
                    : WeekFitTheme.whiteOpacity(0.16)
            )
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
    }

    var sheetHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.editingActivity == nil ? WeekFitLocalizedString("planner.sheet.addTitle") : WeekFitLocalizedString("planner.sheet.editTitle"))
                    .font(.system(size: 21.5, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .allowsTightening(true)

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(viewModel.selectedType.color)

                    Text(addSheetDayChipTitle)
                        .font(.system(size: 13.8, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(viewModel.selectedType.color.opacity(0.08))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(viewModel.selectedType.color.opacity(0.18), lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if viewModel.editingActivity != nil {
                Button(role: .destructive) {
                    lightHaptic.impactOccurred()
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.red.opacity(0.62))
                        .frame(width: 30, height: 30)
                        .background(Color.red.opacity(0.028))
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.red.opacity(0.05), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .fixedSize()

                Spacer()
                    .frame(width: 6)
            }

            WeekFitCloseButton(size: .compact) {
                closeAddSheet()
            }
            .fixedSize()
            .padding(.top, 1)
        }
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

    var activityTypePickerSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sheetSectionHeader(WeekFitLocalizedString("planner.sheet.activitySection"))

            HStack(spacing: 9) {
                ForEach(PlannerType.allCases, id: \.self) { type in
                    typeButton(type)
                }
            }
        }
    }

    var itemPickerSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sheetSectionHeader(
                viewModel.selectedType == .meal
                    ? WeekFitLocalizedString("planner.sheet.chooseMeal")
                    : WeekFitLocalizedString("planner.sheet.chooseActivity"),
                subtitle: chooseItemSubtitle,
                trailing: viewModel.selectedType == .meal && !availableMeals.isEmpty
                    ? WeekFitLocalizedString("planner.sheet.viewAll")
                    : nil,
                trailingAction: viewModel.selectedType == .meal && !availableMeals.isEmpty
                    ? {
                        mealSheetStep = .library
                        mealSheetDetent = .medium
                        showMealSheet = true
                    }
                    : nil
            )
            .padding(.top, 1)

            if showsMealEmptyState {
                emptyMealPickerState
            } else {
                itemPickerCarousel
                    .frame(height: mealPickerSectionHeight)
            }
        }
    }

    var itemPickerCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if viewModel.selectedType == .meal {
                        ForEach(availableMeals) { meal in
                            mealOptionCard(meal)
                                .id(meal.id)
                        }
                    } else {
                        ForEach(currentOptions) { option in
                            optionCard(option)
                                .id(optionScrollID(option))
                        }
                    }
                }
                .padding(.horizontal, addSheetCarouselInset)
                .padding(.vertical, 2)
            }
            .onAppear { scrollToSelectedOption(proxy) }
            .onChange(of: viewModel.selectedItem.title) { _, _ in scrollToSelectedOption(proxy) }
            .onChange(of: viewModel.selectedType) { _, _ in scrollToSelectedOption(proxy) }
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
        .padding(.top, 2)
    }

    var timePickerSection: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 7) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppText.Planner.whenTitle)
                        .font(.system(size: 15.6, weight: .semibold))
                        .foregroundStyle(textPrimary)

                    Text(timeSectionSubtitle)
                        .font(.system(size: 12.2, weight: .regular))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .padding(.top, 2)

                timeSelectionSection(proxy)
            }
        }
    }

    @ViewBuilder
    var durationPickerSection: some View {
        if viewModel.selectedType == .workout || viewModel.selectedType == .recovery {
            VStack(alignment: .leading, spacing: 7) {
                sheetSectionHeader(WeekFitLocalizedString("planner.duration.pickerTitle"), subtitle: durationSectionSubtitle)
                    .padding(.top, 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        durationButton(15)
                        durationButton(30)
                        durationButton(45)
                        durationButton(60)
                        customDurationButton
                    }
                    .padding(.horizontal, addSheetCarouselInset)
                    .padding(.vertical, 2)
                }
                .mask { durationFadeMask }
            }
        }
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

    func typeButton(_ type: PlannerType) -> some View {
        let active = viewModel.selectedType == type
        let activeFillOpacity: Double = switch type {
        case .workout: 0.30
        case .habit: 0.46
        case .recovery: 0.38
        case .meal: 0.38
        }

        return Button {
            guard viewModel.selectedType != type else { return }

            lightHaptic.impactOccurred()
            viewModel.selectedType = type

            if type == .meal {
                viewModel.syncDefaultSelectedMeal()
            } else {
                viewModel.selectedMealID = nil
                viewModel.selectedItem = type.options[0]
                viewModel.applyDefaultDurationForSelectedItem()
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: type.icon)
                    .font(.system(size: 11, weight: .semibold))

                Text(localizedTitle(for: type))
                    .font(.system(size: 9.8, weight: .medium, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(active ? typeButtonActiveForeground(for: type) : (palette.isLight ? textSecondary : textPrimary.opacity(0.58)))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 38)
            .padding(.horizontal, 2)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(active
                          ? (palette.isLight ? type.color.opacity(0.16) : type.color.opacity(activeFillOpacity))
                          : (palette.isLight
                             ? PlanAddSheetPalette.typeChipIdleFill(for: viewModel.selectedType)
                             : WeekFitTheme.whiteOpacity(0.026)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        active
                            ? (palette.isLight ? type.color.opacity(0.42) : WeekFitTheme.whiteOpacity(type == .habit ? 0.10 : 0.070))
                            : (palette.isLight
                               ? WeekFitLightTokens.cardBorder.opacity(0.22)
                               : WeekFitTheme.whiteOpacity(0.035)),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: active
                    ? type.color.opacity(type == .workout ? 0.014 : 0.022)
                    : Color.black.opacity(palette.isLight ? 0.02 : 0.032),
                radius: active ? 6 : 1.5,
                y: active ? 3 : 1
            )
        }
        .buttonStyle(.plain)
    }

    func optionCard(_ option: PlannerOption) -> some View {
        let active = selectedItemMatches(option)

        return Button {
            lightHaptic.impactOccurred()

            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                viewModel.selectedItem = option
                viewModel.applyDefaultDurationForSelectedItem()
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    optionImage(option)
                        .frame(width: addSheetMealImageWidth, height: addSheetActivityImageHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                    if active {
                        selectionCheckmark
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedTitle(for: option))
                        .font(.system(size: 11.8, weight: .semibold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.88)

                    Text(localizedSubtitle(for: option))
                        .font(.system(size: 10.2, weight: .medium))
                        .foregroundStyle(palette.isLight ? textSecondary : viewModel.selectedType.color.opacity(active ? 0.60 : 0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(height: 34, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 7)
            .frame(width: addSheetMealCardWidth, height: addSheetActivityCardHeight, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        PlanAddSheetPalette.optionCardFill(
                            active: active,
                            type: viewModel.selectedType,
                            isLight: palette.isLight
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        active
                            ? viewModel.selectedType.color.opacity(palette.isLight ? 0.38 : 0.16)
                            : (palette.isLight
                               ? WeekFitLightTokens.cardBorder.opacity(0.28)
                               : WeekFitTheme.whiteOpacity(0.05)),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: PlanAddSheetPalette.optionCardShadow(
                    active: active,
                    type: viewModel.selectedType,
                    isLight: palette.isLight
                ),
                radius: active ? 6 : 2,
                x: 0,
                y: active ? 3 : 1
            )
        }
        .buttonStyle(.plain)
    }

    func mealOptionCard(_ meal: Meals) -> some View {
        let active = viewModel.selectedMealID == meal.id

        return Button {
            lightHaptic.impactOccurred()

            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                viewModel.selectedMealID = meal.id
                viewModel.selectedItem = viewModel.plannerOption(for: meal)
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    mealPreview(meal)
                        .frame(width: addSheetMealImageWidth, height: addSheetMealImageHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .opacity(active ? 1.0 : 0.90)

                    if active {
                        selectionCheckmark
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(meal.title)
                        .font(.system(size: 13.2, weight: .semibold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.88)

                    Text(
                        String(
                            format: WeekFitLocalizedString("planner.meal.macroSummaryFormat"),
                            meal.calories,
                            meal.protein,
                            meal.carbs,
                            meal.fats
                        )
                    )
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(
                            palette.isLight
                                ? (active ? viewModel.selectedType.color : textSecondary)
                                : viewModel.selectedType.color.opacity(active ? 0.60 : 0.50)
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
                .frame(minHeight: 34, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 7)
            .frame(width: addSheetMealCardWidth, height: addSheetMealCardHeight, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        PlanAddSheetPalette.optionCardFill(
                            active: active,
                            type: viewModel.selectedType,
                            isLight: palette.isLight
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        active
                            ? viewModel.selectedType.color.opacity(palette.isLight ? 0.38 : 0.16)
                            : (palette.isLight
                               ? WeekFitLightTokens.cardBorder.opacity(0.28)
                               : WeekFitTheme.whiteOpacity(0.05)),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: PlanAddSheetPalette.optionCardShadow(
                    active: active,
                    type: viewModel.selectedType,
                    isLight: palette.isLight
                ),
                radius: active ? 6 : 2,
                x: 0,
                y: active ? 3 : 1
            )
        }
        .buttonStyle(.plain)
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

            HStack(spacing: 6) {
                Circle()
                    .fill(hasSelectedTimeConflict ? Color.red.opacity(0.74) : viewModel.selectedType.color.opacity(0.70))
                    .frame(width: 5, height: 5)

                Text(selectedTimeStatusText)
                    .font(.system(size: 11.6, weight: .medium))
                    .foregroundStyle(hasSelectedTimeConflict ? WeekFitLightTokens.critical : textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, addSheetCarouselInset)
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

    func timeSlotButton(_ state: AddSheetTimeSlotState) -> some View {
        let slot = state.slot
        let active = state.isActive
        let occupied = state.isOccupied
        let isPast = state.isPast
        let recommended = state.isRecommended

        return Button {
            guard !isPast else { return }

            lightHaptic.impactOccurred()
            viewModel.selectedSlot = slot
        } label: {
            VStack(spacing: 1) {
                HStack(spacing: 3) {
                    Text(slotTitle(slot))
                        .font(.system(size: active ? 13.4 : 12.6, weight: active ? .bold : .semibold, design: .rounded))
                        .monospacedDigit()

                    if recommended && !active && !occupied && !isPast {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(viewModel.selectedType.color.opacity(0.72))
                    }
                }

                if active && recommended && !occupied {
                    Text(WeekFitLocalizedString("planner.time.recommended"))
                        .font(.system(size: 8.6, weight: .semibold))
                        .foregroundStyle(viewModel.selectedType.color.opacity(0.68))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(
                selectionChipForeground(active: active, occupied: occupied, isPast: isPast)
            )
            .padding(.horizontal, active ? 12 : 10)
            .frame(minWidth: active ? 68 : 58)
            .frame(height: active ? 38 : 32)
            .background {
                RoundedRectangle(cornerRadius: active ? 16 : 13, style: .continuous)
                    .fill(
                        selectionChipBackground(active: active, occupied: occupied, isPast: isPast)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: active ? 16 : 13, style: .continuous)
                    .stroke(
                        selectionChipBorder(active: active, occupied: occupied, isPast: isPast),
                        lineWidth: active ? 1.05 : 1
                    )
            }
            .shadow(
                color: active && !occupied ? viewModel.selectedType.color.opacity(0.10) : Color.black.opacity(0.018),
                radius: active ? 8 : 3,
                y: active ? 4 : 2
            )
        }
        .buttonStyle(.plain)
        .disabled(isPast || occupied)
        .opacity(isPast ? 0.30 : 1.0)
    }

    func durationButton(_ minutes: Int) -> some View {
        durationChip(
            title: String(format: WeekFitLocalizedString("common.duration.minutesFormat"), minutes),
            active: viewModel.selectedDuration == minutes
        ) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                viewModel.selectedDuration = minutes
                viewModel.customDuration = minutes
            }
        }
    }

    var customDurationButton: some View {
        let presetDurations = [15, 30, 45, 60]
        let isCustomActive = !presetDurations.contains(viewModel.selectedDuration)

        return durationChip(
            title: isCustomActive
                ? String(format: WeekFitLocalizedString("common.duration.minutesFormat"), viewModel.selectedDuration)
                : WeekFitLocalizedString("planner.duration.custom"),
            active: isCustomActive,
            showsIcon: !isCustomActive
        ) {
            viewModel.customDuration = viewModel.selectedDuration
            viewModel.showCustomDuration = true
        }
    }

    func durationChip(
        title: String,
        active: Bool,
        showsIcon: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            lightHaptic.impactOccurred()
            action()
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: active ? 13.4 : 12.6, weight: active ? .bold : .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if showsIcon {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundStyle(selectionChipForeground(active: active, occupied: false, isPast: false))
            .padding(.horizontal, active ? 14 : 12)
            .frame(minWidth: active ? 76 : 68)
            .frame(height: active ? 38 : 32)
            .background {
                RoundedRectangle(cornerRadius: active ? 16 : 13, style: .continuous)
                    .fill(selectionChipBackground(active: active, occupied: false, isPast: false))
            }
            .overlay {
                RoundedRectangle(cornerRadius: active ? 16 : 13, style: .continuous)
                    .stroke(
                        selectionChipBorder(active: active, occupied: false, isPast: false),
                        lineWidth: active ? 1.05 : 1
                    )
            }
            .shadow(
                color: active ? viewModel.selectedType.color.opacity(0.10) : Color.black.opacity(0.018),
                radius: active ? 8 : 3,
                y: active ? 4 : 2
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Buttons

private extension PlanAddActivitySheet {

    var saveButton: some View {
        let topOpacity: Double = viewModel.selectedType == .workout ? 0.38 : 0.42
        let bottomOpacity: Double = viewModel.selectedType == .workout ? 0.32 : 0.36
        let accent = viewModel.selectedType.color

        return Button {
            saveSelectedItem()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: viewModel.editingActivity == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 14.5, weight: .semibold))

                Text(viewModel.editingActivity == nil ? addButtonTitle : WeekFitLocalizedString("planner.saveChanges"))
                    .font(.system(size: 15.2, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(saveButtonForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background {
                if palette.isLight {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(accent)
                } else {
                    LinearGradient(
                        colors: [
                            accent.opacity(topOpacity),
                            accent.opacity(bottomOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        palette.isLight
                            ? Color.white.opacity(0.22)
                            : WeekFitTheme.whiteOpacity(0.055),
                        lineWidth: 1
                    )
            }
            .shadow(color: accent.opacity(palette.isLight ? 0.22 : 0.020), radius: 4, y: 2)
            .shadow(color: Color.black.opacity(palette.isLight ? 0.08 : 0.12), radius: 6, y: 3)
            .shadow(color: accent.opacity(palette.isLight ? 0.16 : 0.08), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!canSaveSelectedItem)
        .opacity(canSaveSelectedItem ? 1 : 0.46)
        .animation(.easeInOut(duration: 0.22), value: viewModel.selectedType)
        .accessibilityLabel(viewModel.editingActivity == nil ? addButtonTitle : WeekFitLocalizedString("planner.saveChanges"))
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
            .fill(viewModel.selectedType.color)
            .frame(width: 18, height: 18)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(palette.isLight ? Color.white : Color.black.opacity(0.82))
            }
            .shadow(color: viewModel.selectedType.color.opacity(0.18), radius: 5, y: 2)
            .padding(5)
    }

    func optionImage(_ option: PlannerOption) -> some View {
        Group {
            if !option.imageName.isEmpty, FoodImageQualityValidator.isDisplayableAsset(named: option.imageName) {
                addSheetCoverImage(named: option.imageName)
            } else {
                fallbackOptionImage(icon: option.icon)
            }
        }
        .overlay {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.00),
                    Color.black.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    func mealPreview(_ meal: Meals) -> some View {
        if meal.isFoodProduct {
            return AnyView(customFoodPreview(meal))
        }

        let sortedItems = meal.builderImageItems?.sorted { $0.zIndex < $1.zIndex } ?? []

        if !sortedItems.isEmpty {
            return AnyView(customMealPreview(items: sortedItems))
        }

        if !meal.imageName.isEmpty, FoodImageQualityValidator.isDisplayableAsset(named: meal.imageName) {
            return AnyView(addSheetCoverImage(named: meal.imageName))
        }

        return AnyView(fallbackOptionImage(icon: PlannerType.meal.icon))
    }

    func customFoodPreview(_ meal: Meals) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(viewModel.selectedType.color.opacity(0.09))

            AsyncCustomFoodVisualView(
                filename: meal.displayPhotoFilename,
                placeholderInitial: meal.placeholderInitial,
                size: 42,
                imageScale: 0.62,
                fallbackSystemImage: PlannerType.meal.icon
            )
        }
    }

    func customMealPreview(items sortedItems: [MealBuilderImageItem]) -> some View {
        BuiltMealPlateView(
            items: sortedItems,
            plateSize: 80,
            itemScale: 0.30,
            offsetScale: 0.28,
            plateOpacity: 0.42,
            shadowOpacity: 0.12,
            layoutMode: .compactPreview
        )
    }

    func fallbackOptionImage(icon: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(viewModel.selectedType.color.opacity(0.09))

            Image(systemName: icon.isEmpty ? viewModel.selectedType.icon : icon)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(viewModel.selectedType.color.opacity(0.68))
        }
    }

    func addSheetCoverImage(named imageName: String) -> some View {
        PlanAddSheetPalette.imageWellFill(
            for: viewModel.selectedType,
            isLight: palette.isLight
        )
        .overlay {
            Image(imageName)
                .resizable()
                .scaledToFill()
        }
        .clipped()
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
            // Solid type fills are saturated enough for white label on all four types.
            return Color.white
        }
        switch viewModel.selectedType {
        case .workout, .recovery:
            return WeekFitTheme.whiteOpacity(0.90)
        case .meal, .habit:
            return Color.black.opacity(0.82)
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
        if calendar.isDateInToday(viewModel.selectedDate) {
            return WeekFitLocalizedString("planner.sheet.todayLabel")
        }

        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d MMMM")
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
        date.formatted(.dateTime.hour().minute())
    }

    func optionScrollID(_ option: PlannerOption) -> String {
        "\(viewModel.selectedType.title)-\(option.title)-\(option.imageName)"
    }

    func scrollToSelectedOption(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if viewModel.selectedType == .meal,
               let selectedMealID = viewModel.selectedMealID {
                proxy.scrollTo(selectedMealID, anchor: .center)
            } else {
                proxy.scrollTo(optionScrollID(viewModel.selectedItem), anchor: .center)
            }
        }
    }
}

// MARK: - Meal Library

private extension PlanAddActivitySheet {

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
            mealPreview(meal)
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
                    .foregroundStyle(viewModel.selectedType.color.opacity(0.82))
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
        guard canSaveSelectedItem else { return }

        viewModel.saveSelectedItem(
            activities: plannedActivities,
            modelContext: modelContext,
            activityRemindersEnabled: activityRemindersEnabled,
            completionCheckInsEnabled: completionCheckInsEnabled
        )
    }

    func deleteActivity(_ activity: PlannedActivity) {
        viewModel.deleteActivity(activity, modelContext: modelContext)
    }

    var canSaveSelectedItem: Bool {
        guard viewModel.selectedSlot != nil else { return false }
        guard !hasSelectedTimeConflict else { return false }

        return viewModel.selectedType != .meal ||
            viewModel.selectedMealForPlanner != nil ||
            viewModel.editingActivity != nil
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

/// Soft stone sheets + family-tinted ceramic cards — Quick Log depth language, per Plan type.
/// Idle cards must never read as pure white on the sheet.
private enum PlanAddSheetPalette {

    @MainActor
    static func sheetBase(for type: PlannerType, isLight: Bool) -> Color {
        guard isLight else { return WeekFitTheme.backgroundColor }
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
        let accent = type.color
        if isLight {
            return [
                accent.opacity(0.070),
                accent.opacity(0.022),
                Color.clear
            ]
        }
        return [
            accent.opacity(0.08),
            accent.opacity(0.03),
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
