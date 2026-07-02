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

struct PlanAddActivitySheet: View {

    @ObservedObject var viewModel: PlanViewModel
    @EnvironmentObject private var languageManager: AppLanguageManager

    let plannedActivities: [PlannedActivity]
    let modelContext: ModelContext
    let activityRemindersEnabled: Bool
    let completionCheckInsEnabled: Bool

    @AppStorage("weekfit_custom_meals_v1")
    private var customMealsStorage: String = ""
    
    @State private var showDeleteConfirmation = false
    @State private var showMealLibrarySheet = false
    @State private var showMealBuilder = false

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let borderSoft = WeekFitTheme.borderSoft

    private let addSheetCarouselInset: CGFloat = 10
    private let addSheetHorizontalInset: CGFloat = 8
    private let busySlotColor = Color(red: 0.93, green: 0.62, blue: 0.22)
    private let addSheetCornerRadius: CGFloat = 34
    private let addSheetMealCardWidth: CGFloat = 118
    private let addSheetMealCardHeight: CGFloat = 104
    private let addSheetMealImageWidth: CGFloat = 104
    private let addSheetMealImageHeight: CGFloat = 48

    private let timelineStartHour = 5
    private let timelineEndHour = 24
    private let timelineMinuteStep = 15

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    private var calendar: Calendar { viewModel.calendar }
    private var availableMeals: [Meals] { viewModel.availableMeals }
    private var currentOptions: [PlannerOption] { viewModel.currentOptions }

    

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

        return allSlots.filter { $0 >= Date() }
    }

    private var addSheetMaxHeight: CGFloat {
        min(UIScreen.main.bounds.height * 0.78, 620)
    }
    
    var body: some View {
        let _ = languageManager.selectedLanguage

        addActivitySheet
            .sheet(isPresented: $showMealLibrarySheet) {
                mealLibrarySheet
                    .weekFitSheetChrome(cornerRadius: 30)
            }
            .sheet(isPresented: $showMealBuilder) {
                MealBuilderView { newMeal in
                    saveMealToLibrary(newMeal)
                    showMealBuilder = false
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .weekFitSheetChrome(cornerRadius: 36)
            }
            .sheet(isPresented: $viewModel.showCustomDuration) {
                customDurationSheet
                    .weekFitSheetChrome(cornerRadius: 30)
            }
            .alert(WeekFitLocalizedString("planner.timeConflict.title"), isPresented: $viewModel.showTimeConflictAlert) {
                Button(WeekFitLocalizedString("common.action.ok"), role: .cancel) { }
            } message: {
                Text(viewModel.timeConflictMessage)
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
                viewModel.loadCustomMeals(from: customMealsStorage)

                if viewModel.editingActivity == nil {
                    viewModel.syncDefaultSelectedMeal()
                }
            }
            .onChange(of: customMealsStorage) { _, _ in
                viewModel.loadCustomMeals(from: customMealsStorage)

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

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    activityTypePickerSection
                    itemPickerSection
                    timePickerSection
                    durationPickerSection
                }
                .padding(.bottom, 4)
            }

            saveButton
                .padding(.top, 6)
        }
        .padding(.horizontal, WeekFitStyle.Size.horizontalPadding)
        .padding(.top, 7)
        .padding(.bottom, viewModel.editingActivity == nil ? 9 : 8)
        .frame(maxHeight: addSheetMaxHeight, alignment: .top)
        .background { addSheetBackground }
        .overlay { addSheetBorder }
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: -5)
        .shadow(color: viewModel.selectedType.color.opacity(0.012), radius: 12, x: 0, y: -2)
        .padding(.horizontal, addSheetHorizontalInset)
        .padding(.bottom, 8)
    }

    var addSheetGrabber: some View {
        Capsule()
            .fill(WeekFitTheme.whiteOpacity(0.12))
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 2)
    }

    var sheetHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.editingActivity == nil ? WeekFitLocalizedString("planner.sheet.addTitle") : WeekFitLocalizedString("planner.sheet.editTitle"))
                    .font(.system(size: 21.5, weight: .semibold))
                    .foregroundStyle(textPrimary.opacity(0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .allowsTightening(true)

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(viewModel.selectedType.color.opacity(0.88))

                    Text(addSheetDayChipTitle)
                        .font(.system(size: 13.8, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary.opacity(0.92))
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

            Button {
                closeAddSheet()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(textPrimary.opacity(0.88))
                    .frame(width: 30, height: 30)
                    .background(WeekFitTheme.whiteOpacity(0.045))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(WeekFitTheme.whiteOpacity(0.040), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .fixedSize()
            .padding(.top, 1)
            .accessibilityLabel(Text(AppText.Common.Action.close))
        }
    }

    func isPastSlot(_ slot: Date) -> Bool {
        if !calendar.isDate(slot, inSameDayAs: Date()) {
            return false
        }

        return slot < Date()
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
                    ? { showMealLibrarySheet = true }
                    : nil
            )
            .padding(.top, 1)

            itemPickerCarousel
                .frame(height: addSheetMealCardHeight + 8)
        }
    }

    var itemPickerCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if viewModel.selectedType == .meal {
                        if availableMeals.isEmpty {
                            emptyMealPickerState
                                .id(optionScrollID(.emptyMealPlaceholder))
                        } else {
                            ForEach(availableMeals) { meal in
                                mealOptionCard(meal)
                                    .id(meal.id)
                            }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(viewModel.selectedType.color.opacity(0.72))

                VStack(alignment: .leading, spacing: 2) {
                    Text(WeekFitLocalizedString("planner.emptyMeal.title"))
                        .font(.system(size: 12.6, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(0.86))

                    Text(WeekFitLocalizedString("planner.emptyMeal.message"))
                        .font(.system(size: 10.8, weight: .medium))
                        .foregroundStyle(textSecondary.opacity(0.62))
                }
            }

            Button {
                lightHaptic.impactOccurred()
                showMealBuilder = true
            } label: {
                Text(WeekFitLocalizedString("meals.createFoodOrMeal"))
                    .font(.system(size: 12.4, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(viewModel.selectedType.color.opacity(0.92))
                    .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(width: addSheetMealCardWidth * 1.9, height: addSheetMealCardHeight, alignment: .leading)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WeekFitTheme.whiteOpacity(0.022))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.05), lineWidth: 1)
        }
    }

    var timePickerSection: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 7) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppText.Planner.whenTitle)
                        .font(.system(size: 15.6, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(0.93))

                    Text(timeSectionSubtitle)
                        .font(.system(size: 12.2, weight: .regular))
                        .foregroundStyle(textSecondary.opacity(0.66))
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
                    .foregroundStyle(textPrimary.opacity(0.93))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.2, weight: .regular))
                        .foregroundStyle(textSecondary.opacity(0.66))
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
            .foregroundStyle(active ? typeButtonActiveForeground(for: type) : textPrimary.opacity(0.58))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 38)
            .padding(.horizontal, 2)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(active ? type.color.opacity(activeFillOpacity) : WeekFitTheme.whiteOpacity(0.026))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(active ? WeekFitTheme.whiteOpacity(type == .habit ? 0.10 : 0.070) : WeekFitTheme.whiteOpacity(0.035), lineWidth: 1)
            }
            .shadow(
                color: active ? type.color.opacity(type == .workout ? 0.014 : 0.022) : Color.black.opacity(0.032),
                radius: active ? 6 : 3,
                y: active ? 3 : 2
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
                        .frame(width: addSheetMealImageWidth, height: addSheetMealImageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                    if active {
                        selectionCheckmark
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedTitle(for: option))
                        .font(.system(size: 11.8, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(active ? 0.96 : 0.80))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.88)

                    Text(localizedSubtitle(for: option))
                        .font(.system(size: 10.2, weight: .medium))
                        .foregroundStyle(viewModel.selectedType.color.opacity(active ? 0.60 : 0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(height: 34, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 7)
            .frame(width: addSheetMealCardWidth, height: addSheetMealCardHeight, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(active ? viewModel.selectedType.color.opacity(0.05) : WeekFitTheme.whiteOpacity(0.022))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(active ? viewModel.selectedType.color.opacity(0.16) : WeekFitTheme.whiteOpacity(0.05), lineWidth: 1)
            }
            .shadow(
                color: active ? viewModel.selectedType.color.opacity(0.012) : Color.black.opacity(0.018),
                radius: active ? 6 : 3,
                x: 0,
                y: active ? 3 : 2
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
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .opacity(active ? 1.0 : 0.90)

                    if active {
                        selectionCheckmark
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(meal.title)
                        .font(.system(size: 13.2, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(active ? 0.96 : 0.88))
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
                        .foregroundStyle(viewModel.selectedType.color.opacity(active ? 0.60 : 0.50))
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
                    .fill(active ? viewModel.selectedType.color.opacity(0.05) : WeekFitTheme.whiteOpacity(0.022))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(active ? viewModel.selectedType.color.opacity(0.16) : WeekFitTheme.whiteOpacity(0.05), lineWidth: 1)
            }
            .shadow(
                color: active ? viewModel.selectedType.color.opacity(0.012) : Color.black.opacity(0.014),
                radius: active ? 6 : 3,
                x: 0,
                y: active ? 3 : 2
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

            timeSlotLegendRow(showsBusyLegend: showsBusyLegend)

            HStack(spacing: 6) {
                Circle()
                    .fill(hasSelectedTimeConflict ? Color.red.opacity(0.74) : viewModel.selectedType.color.opacity(0.70))
                    .frame(width: 5, height: 5)

                Text(selectedTimeStatusText)
                    .font(.system(size: 11.6, weight: .medium))
                    .foregroundStyle(hasSelectedTimeConflict ? Color.red.opacity(0.76) : textSecondary.opacity(0.58))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, addSheetCarouselInset)
        }
    }

    @ViewBuilder
    func timeSlotLegendRow(showsBusyLegend: Bool) -> some View {
        let showsPastLegend = calendar.isDateInToday(viewModel.selectedDate)

        if showsPastLegend || showsBusyLegend {
            HStack(spacing: 14) {
                if showsPastLegend {
                    timeLegendItem(
                        color: textPrimary.opacity(0.22),
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
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(WeekFitTheme.whiteOpacity(0.08), lineWidth: 0.5)
                }

            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(textSecondary.opacity(0.52))
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
            .background(
                LinearGradient(
                    colors: [
                        viewModel.selectedType.color.opacity(topOpacity),
                        viewModel.selectedType.color.opacity(bottomOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(WeekFitTheme.whiteOpacity(0.055), lineWidth: 1)
            }
            .shadow(color: viewModel.selectedType.color.opacity(0.020), radius: 4, y: 2)
            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
            .shadow(color: viewModel.selectedType.color.opacity(0.08), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!canSaveSelectedItem)
        .opacity(canSaveSelectedItem ? 1 : 0.46)
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
                    .foregroundStyle(textSecondary.opacity(0.62))
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
                    .foregroundStyle(.black.opacity(0.84))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.selectedType.color.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 20)

            Button {
                viewModel.showCustomDuration = false
            } label: {
                Text(AppText.Common.Action.cancel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.78))
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
            .fill(viewModel.selectedType.color.opacity(0.56))
            .frame(width: 18, height: 18)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black.opacity(0.82))
            }
            .shadow(color: viewModel.selectedType.color.opacity(0.045), radius: 5, y: 2)
            .padding(5)
    }

    func optionImage(_ option: PlannerOption) -> some View {
        Group {
            if !option.imageName.isEmpty, UIImage(named: option.imageName) != nil {
                Image(option.imageName)
                    .resizable()
                    .scaledToFill()
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

        if !meal.imageName.isEmpty, UIImage(named: meal.imageName) != nil {
            return AnyView(
                Image(meal.imageName)
                    .resizable()
                    .scaledToFill()
            )
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

}

// MARK: - Styling / State Helpers

private extension PlanAddActivitySheet {
    
    func timeSlotID(_ slot: Date) -> String {
        "\(Int(slot.timeIntervalSince1970))"
    }

    var addSheetBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: addSheetCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.046, green: 0.050, blue: 0.054),
                            Color(red: 0.032, green: 0.036, blue: 0.039)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: addSheetCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.whiteOpacity(0.010),
                            WeekFitTheme.whiteOpacity(0.004),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        }
    }

    var addSheetBorder: some View {
        RoundedRectangle(cornerRadius: addSheetCornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        WeekFitTheme.whiteOpacity(0.056),
                        WeekFitTheme.whiteOpacity(0.018),
                        borderSoft.opacity(0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
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
        switch option.title {
        case "Cycling": return WeekFitLocalizedString("planner.option.cycling")
        case "Running": return WeekFitLocalizedString("planner.option.running")
        case "Upper Body": return WeekFitLocalizedString("planner.option.upperBody")
        case "Core": return WeekFitLocalizedString("planner.option.core")
        case "Lower Body": return WeekFitLocalizedString("planner.option.lowerBody")
        case "Full Body": return WeekFitLocalizedString("planner.option.fullBody")
        case "Tennis": return WeekFitLocalizedString("planner.option.tennis")
        case "Squash": return WeekFitLocalizedString("planner.option.squash")
        case "Stretching": return WeekFitLocalizedString("planner.option.stretching")
        case "Walk": return WeekFitLocalizedString("planner.option.walk")
        case "Sauna": return WeekFitLocalizedString("planner.option.sauna")
        case "Yoga": return WeekFitLocalizedString("planner.option.yoga")
        case "Breathing": return WeekFitLocalizedString("planner.option.breathing")
        case "Drink Water": return WeekFitLocalizedString("planner.option.drinkWater")
        case "Sleep Routine": return WeekFitLocalizedString("planner.option.sleepRoutine")
        case "No Screens": return WeekFitLocalizedString("planner.option.noScreens")
        case "Morning Routine": return WeekFitLocalizedString("planner.option.morningRoutine")
        case "No saved meals": return WeekFitLocalizedString("planner.emptyMeal.title")
        default: return option.title
        }
    }

    func localizedSubtitle(for option: PlannerOption) -> String {
        switch option.subtitle {
        case "Endurance": return WeekFitLocalizedString("planner.option.subtitle.endurance")
        case "Cardio": return WeekFitLocalizedString("planner.option.subtitle.cardio")
        case "Strength": return WeekFitLocalizedString("planner.option.subtitle.strength")
        case "High Intensity": return WeekFitLocalizedString("planner.option.subtitle.highIntensity")
        case "Mobility": return WeekFitLocalizedString("planner.option.subtitle.mobility")
        case "Light recovery": return WeekFitLocalizedString("planner.option.subtitle.lightRecovery")
        case "Relax": return WeekFitLocalizedString("planner.option.subtitle.relax")
        case "Calm": return WeekFitLocalizedString("planner.option.subtitle.calm")
        case "Hydration": return WeekFitLocalizedString("planner.option.subtitle.hydration")
        case "Wind down": return WeekFitLocalizedString("planner.option.subtitle.windDown")
        case "Focus": return WeekFitLocalizedString("planner.option.subtitle.focus")
        case "Start day": return WeekFitLocalizedString("planner.option.subtitle.startDay")
        case "Create a meal first": return WeekFitLocalizedString("planner.emptyMeal.subtitle")
        default: return option.subtitle
        }
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
        switch type {
        case .workout, .recovery, .habit:
            return WeekFitTheme.whiteOpacity(0.90)
        case .meal:
            return Color.black.opacity(0.82)
        }
    }

    func selectionChipForeground(active: Bool, occupied: Bool, isPast: Bool) -> Color {
        if isPast { return textPrimary.opacity(0.18) }
        if active && occupied { return Color.red.opacity(0.84) }
        if active { return textPrimary.opacity(0.96) }
        if occupied { return busySlotColor.opacity(0.62) }
        return textPrimary.opacity(0.58)
    }

    func selectionChipBackground(active: Bool, occupied: Bool, isPast: Bool) -> Color {
        if isPast { return WeekFitTheme.whiteOpacity(0.012) }
        if active && occupied { return Color.red.opacity(0.075) }
        if occupied { return busySlotColor.opacity(0.07) }
        if active { return viewModel.selectedType.color.opacity(0.08) }
        return WeekFitTheme.whiteOpacity(0.022)
    }

    func selectionChipBorder(active: Bool, occupied: Bool, isPast: Bool) -> Color {
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
                            showMealLibrarySheet = false
                        } label: {
                            mealLibraryRow(meal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(WeekFitTheme.backgroundColor.ignoresSafeArea())
            .navigationTitle(WeekFitLocalizedString("planner.sheet.chooseMeal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(WeekFitLocalizedString("common.action.cancel")) {
                        showMealLibrarySheet = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMealLibrarySheet = false
                        showMealBuilder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(WeekFitLocalizedString("meals.createFoodOrMeal")))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    func mealLibraryRow(_ meal: Meals) -> some View {
        HStack(spacing: 12) {
            mealPreview(meal)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(meal.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(textPrimary.opacity(0.92))
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
                .foregroundStyle(textSecondary.opacity(0.66))
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
        Task {
            await viewModel.deleteActivity(activity, modelContext: modelContext)
        }
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
            into: CustomMealStore.load(from: customMealsStorage)
        )
        customMealsStorage = CustomMealStore.encode(updatedMeals)
        viewModel.loadCustomMeals(from: customMealsStorage)
        viewModel.selectedMealID = meal.id
        viewModel.selectedItem = viewModel.plannerOption(for: meal)
    }
}
