import SwiftUI
import UIKit
import SwiftData

struct PlanAddActivitySheet: View {

    @ObservedObject var viewModel: PlanViewModel

    let plannedActivities: [PlannedActivity]
    let modelContext: ModelContext
    let activityRemindersEnabled: Bool
    let completionCheckInsEnabled: Bool

    @AppStorage("weekfit_custom_meals_v1")
    private var customMealsStorage: String = ""
    
    @State private var showDeleteConfirmation = false

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let borderSoft = WeekFitTheme.borderSoft

    private let addSheetHorizontalInset: CGFloat = 8
    private let addSheetCornerRadius: CGFloat = 34
    private let addSheetMealCardWidth: CGFloat = 118
    private let addSheetMealCardHeight: CGFloat = 96
    private let addSheetMealImageWidth: CGFloat = 104
    private let addSheetMealImageHeight: CGFloat = 48

    private let timelineStartHour = 5
    private let timelineEndHour = 24
    private let timelineMinuteStep = 15

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    private var calendar: Calendar { viewModel.calendar }
    private var availableMeals: [Meals] { viewModel.availableMeals }
    private var currentOptions: [PlannerOption] { viewModel.currentOptions }
    private var selectedDayTitle: String { viewModel.selectedDayTitle }

    

    func nextHourSlot() -> Date? {
        let base = viewModel.selectedSlot ?? Date()
        let target = calendar.date(byAdding: .hour, value: 1, to: base) ?? base

        return timeSlots.first { slot in
            slot >= target &&
            !viewModel.hasTimeConflict(
                newStart: slot,
                durationMinutes: viewModel.selectedDuration,
                activities: plannedActivities,
                excluding: viewModel.editingActivity
            )
        }
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

        return allSlots.filter { $0 >= Date() }
    }

    private var addSheetHeight: CGFloat {
        switch viewModel.selectedType {
        case .meal:
            return viewModel.editingActivity == nil ? 500 : 520

        case .workout:
            return viewModel.editingActivity == nil ? 560 : 580

        case .recovery:
            return viewModel.editingActivity == nil ? 560 : 580

        case .habit:
            return viewModel.editingActivity == nil ? 470 : 490
        }
    }
    
    var body: some View {
        addActivitySheet
            .sheet(isPresented: $viewModel.showCustomDuration) {
                customDurationSheet
            }
            .alert("Time already booked", isPresented: $viewModel.showTimeConflictAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.timeConflictMessage)
            }
            .alert("Delete activity?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }

                Button("Delete", role: .destructive) {
                    if let editingActivity = viewModel.editingActivity {
                        deleteActivity(editingActivity)
                        closeAddSheet()
                    }
                }
            } message: {
                Text("This activity will be removed from your plan.")
            }

            .onAppear {
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
        VStack(alignment: .leading, spacing: 6) {
            addSheetGrabber

            sheetHeader
                .padding(.bottom, 4)

            activityTypePickerSection
            itemPickerSection
            timePickerSection
            durationPickerSection

            saveButton
                .padding(.top, hasSelectedTimeConflict ? 6 : 2)

        }
        .padding(.horizontal, WeekFitStyle.Size.horizontalPadding)
        .padding(.top, 7)
        .padding(.bottom, viewModel.editingActivity == nil ? 11 : 10)
        .frame(height: addSheetHeight, alignment: .top)
        .clipped()
        .background { addSheetBackground }
        .overlay { addSheetBorder }
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: -5)
        .shadow(color: viewModel.selectedType.color.opacity(0.012), radius: 12, x: 0, y: -2)
        .padding(.horizontal, addSheetHorizontalInset)
        .padding(.bottom, 8)
    }

    var addSheetGrabber: some View {
        Capsule()
            .fill(Color.white.opacity(0.12))
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 2)
    }

    var sheetHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.editingActivity == nil ? "Add activity" : "Edit activity")
                    .font(.system(size: 21.5, weight: .semibold))
                    .foregroundStyle(textPrimary.opacity(0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)

                Text(viewModel.editingActivity == nil ? "What do you want to add?" : "What do you want to edit?")
                    .font(.system(size: 13.2, weight: .medium))
                    .foregroundStyle(textSecondary.opacity(0.66))
                    .lineLimit(1)
            }

            Spacer()
            
            if let editingActivity = viewModel.editingActivity {
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
                    .background(Color.white.opacity(0.045))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.040), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 1)
            .accessibilityLabel("Close")
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
            sheetSectionHeader("Activity")

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
                viewModel.selectedType == .meal ? "Choose meal" : "Choose activity",
                subtitle: chooseItemSubtitle,
                trailing: viewModel.selectedType == .meal ? "View all" : nil
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
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
//            .mask { horizontalFadeMask }
            .onAppear { scrollToSelectedOption(proxy) }
            .onChange(of: viewModel.selectedItem.title) { _, _ in scrollToSelectedOption(proxy) }
            .onChange(of: viewModel.selectedType) { _, _ in scrollToSelectedOption(proxy) }
        }
    }

    var timePickerSection: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("When")
                            .font(.system(size: 15.6, weight: .semibold))
                            .foregroundStyle(textPrimary.opacity(0.93))

                        Text(timeSectionSubtitle)
                            .font(.system(size: 12.2, weight: .regular))
                            .foregroundStyle(textSecondary.opacity(0.66))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer()

                    bestSlotButton(proxy)
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
                sheetSectionHeader("Duration", subtitle: durationSectionSubtitle)
                    .padding(.top, 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        durationButton(15)
                        durationButton(30)
                        durationButton(45)
                        durationButton(60)
                        customDurationButton
                    }
                    .padding(.horizontal, 2)
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
        trailing: String? = nil
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

            if let trailing {
                Button {
                    lightHaptic.impactOccurred()
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
        let activeFillOpacity: Double = type == .workout ? 0.30 : 0.38

        return Button {
            lightHaptic.impactOccurred()

            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                viewModel.selectedType = type

                if type == .meal {
                    viewModel.syncDefaultSelectedMeal()
                } else {
                    viewModel.selectedMealID = nil
                    viewModel.selectedItem = type.options[0]
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 10.5, weight: .semibold))

                Text(type.title)
                    .font(.system(size: 10.8, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(active ? saveButtonForeground : textPrimary.opacity(0.58))
            .frame(maxWidth: .infinity)
            .frame(height: 31)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(active ? type.color.opacity(activeFillOpacity) : Color.white.opacity(0.026))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(active ? Color.white.opacity(0.070) : Color.white.opacity(0.035), lineWidth: 1)
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
                    Text(option.title)
                        .font(.system(size: 11.8, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(active ? 0.96 : 0.80))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.88)

                    Text(option.subtitle)
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
                    .fill(active ? viewModel.selectedType.color.opacity(0.05) : Color.white.opacity(0.022))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(active ? viewModel.selectedType.color.opacity(0.16) : Color.white.opacity(0.05), lineWidth: 1)
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

                    Text("\(meal.calories) kcal • P \(meal.protein)g")
                        .font(.system(size: 11.0, weight: .medium))
                        .foregroundStyle(viewModel.selectedType.color.opacity(active ? 0.60 : 0.50))
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
                    .fill(active ? viewModel.selectedType.color.opacity(0.05) : Color.white.opacity(0.022))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(active ? viewModel.selectedType.color.opacity(0.16) : Color.white.opacity(0.05), lineWidth: 1)
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
    
    func firstAvailableSlot() -> Date? {
        timeSlots.first { slot in
            !viewModel.hasTimeConflict(
                newStart: slot,
                durationMinutes: viewModel.selectedDuration,
                activities: plannedActivities,
                excluding: viewModel.editingActivity
            )
        }
    }

    func ensureSelectedAvailableSlot(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            let currentSlot = viewModel.selectedSlot

            let currentIsUsable: Bool = {
                guard let currentSlot else { return false }

                let isPast = isPastSlot(currentSlot)
                let conflict = viewModel.hasTimeConflict(
                    newStart: currentSlot,
                    durationMinutes: viewModel.selectedDuration,
                    activities: plannedActivities,
                    excluding: viewModel.editingActivity
                )

                return !isPast && !conflict
            }()

            let targetSlot = currentIsUsable ? currentSlot : firstAvailableSlot()

            guard let targetSlot else { return }

            if !currentIsUsable {
                viewModel.selectedSlot = targetSlot
            }

            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(timeSlotID(targetSlot), anchor: .center)
            }
        }
    }

    func bestSlotButton(_ proxy: ScrollViewProxy) -> some View {
        Button {
            lightHaptic.impactOccurred()

            if let slot = nextHourSlot() {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    viewModel.selectedSlot = slot
                }

                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(timeSlotID(slot), anchor: .center)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                Text("+1 hour")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(viewModel.selectedType.color.opacity(0.78))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.white.opacity(0.032))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(viewModel.selectedType.color.opacity(0.10), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    func timeSelectionSection(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(timeSlots, id: \.self) { slot in
                        timeSlotButton(slot)
                            .id(timeSlotID(slot))
                    }
                }
                .padding(.horizontal, 2)
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

            HStack(spacing: 6) {
                Circle()
                    .fill(hasSelectedTimeConflict ? Color.red.opacity(0.74) : viewModel.selectedType.color.opacity(0.70))
                    .frame(width: 5, height: 5)

                Text(selectedTimeStatusText)
                    .font(.system(size: 11.6, weight: .medium))
                    .foregroundStyle(hasSelectedTimeConflict ? Color.red.opacity(0.76) : textSecondary.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 2)
        }
    }

    func timeSlotButton(_ slot: Date) -> some View {
        let active = viewModel.selectedSlot.map {
            calendar.isDate($0, equalTo: slot, toGranularity: .minute)
        } ?? false

        let conflict = viewModel.hasTimeConflict(
            newStart: slot,
            durationMinutes: viewModel.selectedDuration,
            activities: plannedActivities,
            excluding: viewModel.editingActivity
        )

        let isPast = isPastSlot(slot)

        return Button {
            guard !isPast else { return }

            lightHaptic.impactOccurred()

            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                viewModel.selectedSlot = slot
            }
        } label: {
            Text(slotTitle(slot))
                .font(.system(size: 12.8, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    isPast
                    ? textPrimary.opacity(0.22)
                    : timeSlotForeground(active: active, conflict: conflict)
                )
                .frame(width: 58, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            isPast
                            ? Color.white.opacity(0.014)
                            : timeSlotBackground(active: active, conflict: conflict)
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(
                            isPast
                            ? Color.white.opacity(0.018)
                            : timeSlotBorder(active: active, conflict: conflict),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .disabled(isPast)
        .opacity(isPast ? 0.42 : 1.0)
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
            Text("\(minutes) min")
                .font(.system(size: 12.8, weight: .semibold))
                .foregroundStyle(active ? viewModel.selectedType.color.opacity(0.72) : textPrimary.opacity(0.58))
                .frame(width: 68, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(active ? viewModel.selectedType.color.opacity(0.046) : Color.white.opacity(0.030))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(active ? viewModel.selectedType.color.opacity(0.16) : Color.white.opacity(0.030), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    var customDurationButton: some View {
        Button {
            lightHaptic.impactOccurred()
            viewModel.customDuration = viewModel.selectedDuration
            viewModel.showCustomDuration = true
        } label: {
            HStack(spacing: 5) {
                Text("Custom")
                Image(systemName: "slider.horizontal.3")
            }
            .font(.system(size: 12.6, weight: .semibold))
            .foregroundStyle(textPrimary.opacity(0.56))
            .frame(width: 88, height: 32)
            .background(Color.white.opacity(0.034))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.045), lineWidth: 1)
            }
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

                Text(viewModel.editingActivity == nil ? addButtonTitle : "Save changes")
                    .font(.system(size: 15.2, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(saveButtonForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
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
                    .stroke(Color.white.opacity(0.055), lineWidth: 1)
            }
            .shadow(color: viewModel.selectedType.color.opacity(0.020), radius: 4, y: 2)
            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
            .shadow(color: viewModel.selectedType.color.opacity(0.08), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.editingActivity == nil ? addButtonTitle : "Save changes")
    }
}

// MARK: - Custom Duration Sheet

private extension PlanAddActivitySheet {

    var customDurationSheet: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.14))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("Custom duration")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text("Fine tune the activity length")
                    .font(.system(size: 13.2, weight: .medium))
                    .foregroundStyle(textSecondary.opacity(0.62))
            }

            Picker("Duration", selection: $viewModel.customDuration) {
                ForEach(Array(stride(from: 5, through: 240, by: 5)), id: \.self) { minutes in
                    Text("\(minutes) min")
                        .tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)

            Button {
                viewModel.selectedDuration = viewModel.customDuration
                viewModel.showCustomDuration = false
            } label: {
                Text("Set \(viewModel.customDuration) min")
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
                Text("Cancel")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.78))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
        }
        .background(WeekFitTheme.backgroundColor.ignoresSafeArea())
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
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
            if UIImage(named: option.imageName) != nil {
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
        let sortedItems = meal.builderImageItems?.sorted { $0.zIndex < $1.zIndex } ?? []

        if !sortedItems.isEmpty {
            return AnyView(customMealPreview(items: sortedItems))
        }

        if UIImage(named: meal.imageName) != nil {
            return AnyView(
                Image(meal.imageName)
                    .resizable()
                    .scaledToFill()
            )
        }

        return AnyView(fallbackOptionImage(icon: PlannerType.meal.icon))
    }

    func customMealPreview(items sortedItems: [MealBuilderImageItem]) -> some View {
        let isStandalone = sortedItems.count == 1

        return ZStack {
            Image("plate-dark")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            ForEach(sortedItems) { item in
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: customMealPreviewWidth(item, isStandalone: isStandalone))
                    .offset(
                        x: customMealPreviewOffsetX(item, isStandalone: isStandalone),
                        y: customMealPreviewOffsetY(item, isStandalone: isStandalone)
                    )
                    .rotationEffect(.degrees(customMealPreviewRotation(item, isStandalone: isStandalone)))
                    .zIndex(Double(item.zIndex))
            }
        }
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

    func customMealPreviewWidth(_ item: MealBuilderImageItem, isStandalone: Bool) -> CGFloat {
        let baseWidth = CGFloat(item.visualSize) * 0.34

        guard isStandalone, item.supportsStandalonePresentation else {
            return baseWidth
        }

        if item.id.hasPrefix("base_") { return baseWidth * 1.05 }
        if item.id.hasPrefix("protein_") { return baseWidth * 1.18 }
        if item.id.hasPrefix("veg_") { return baseWidth * 1.35 }
        return baseWidth * 1.62
    }

    func customMealPreviewOffsetX(_ item: MealBuilderImageItem, isStandalone: Bool) -> CGFloat {
        guard isStandalone, item.supportsStandalonePresentation else {
            return CGFloat(item.offsetX) * 0.265
        }
        return 0
    }

    func customMealPreviewOffsetY(_ item: MealBuilderImageItem, isStandalone: Bool) -> CGFloat {
        guard isStandalone, item.supportsStandalonePresentation else {
            return CGFloat(item.offsetY) * 0.265
        }
        return -2
    }

    func customMealPreviewRotation(_ item: MealBuilderImageItem, isStandalone: Bool) -> Double {
        guard isStandalone, item.supportsStandalonePresentation else {
            return Double(item.rotation)
        }
        return 0
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
                            Color.white.opacity(0.010),
                            Color.white.opacity(0.004),
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
                        Color.white.opacity(0.056),
                        Color.white.opacity(0.018),
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
            return Color.white.opacity(0.90)
        case .meal, .habit:
            return Color.black.opacity(0.82)
        }
    }

    var addButtonTitle: String {
        switch viewModel.selectedType {
        case .meal: return "Add meal"
        case .workout: return "Add workout"
        case .recovery: return "Add recovery"
        case .habit: return "Add habit"
        }
    }

    var chooseItemSubtitle: String {
        switch viewModel.selectedType {
        case .meal:
            return viewModel.customMeals.isEmpty ? "Suggested meals for today" : "Custom meals you've saved"
        case .workout:
            return "Choose the movement that fits your day"
        case .recovery:
            return "Support recovery and keep momentum"
        case .habit:
            return "Small routines that keep the day on track"
        }
    }

    var timeSectionSubtitle: String {
        hasSelectedTimeConflict ? "Choose a free slot" : "Best time for you"
    }

    var durationSectionSubtitle: String {
        viewModel.selectedType == .recovery ? "Recommended for recovery balance" : "Recommended for energy balance"
    }

    var selectedTimeIntelligenceLabel: String {
        guard let selectedSlot = viewModel.selectedSlot else { return "Choose time" }
        guard !hasSelectedTimeConflict else { return "Overlap" }

        let hour = calendar.component(.hour, from: selectedSlot)

        switch viewModel.selectedType {
        case .meal:
            switch hour {
            case 6...10: return "Good breakfast window"
            case 11...14: return "Good lunch window"
            case 17...21: return "Good dinner window"
            default: return "Light fuel window"
            }
        case .workout:
            switch hour {
            case 6...10: return "Strong energy window"
            case 11...15: return "Balanced training time"
            case 16...19: return "Good cardio timing"
            default: return "Keep it gentle"
            }
        case .recovery:
            switch hour {
            case 6...11: return "Easy reset window"
            case 12...17: return "Good recovery gap"
            default: return "Wind-down friendly"
            }
        case .habit:
            switch hour {
            case 6...11: return "Good morning anchor"
            case 12...17: return "Steady routine slot"
            default: return "Calm evening anchor"
            }
        }
    }

    var selectedTimeStatusText: String {
        hasSelectedTimeConflict ? "This time overlaps another activity" : selectedTimeIntelligenceLabel
    }

    var hasSelectedTimeConflict: Bool {
        guard let selectedSlot = viewModel.selectedSlot else { return false }

        return viewModel.hasTimeConflict(
            newStart: selectedSlot,
            durationMinutes: viewModel.selectedDuration,
            activities: plannedActivities,
            excluding: viewModel.editingActivity
        )
    }

    func timeSlotForeground(active: Bool, conflict: Bool) -> Color {
        if active && conflict { return Color.red.opacity(0.84) }
        if active { return viewModel.selectedType.color.opacity(0.72) }
        if conflict { return Color.red.opacity(0.44) }
        return textPrimary.opacity(0.58)
    }

    func timeSlotBackground(active: Bool, conflict: Bool) -> Color {
        if active && conflict { return Color.red.opacity(0.075) }
        if active { return viewModel.selectedType.color.opacity(0.046) }
        if conflict { return Color.red.opacity(0.025) }
        return Color.white.opacity(0.030)
    }

    func timeSlotBorder(active: Bool, conflict: Bool) -> Color {
        if active && conflict { return Color.red.opacity(0.22) }
        if active { return viewModel.selectedType.color.opacity(0.16) }
        if conflict { return Color.red.opacity(0.08) }
        return Color.white.opacity(0.030)
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
            withAnimation(.easeInOut(duration: 0.22)) {
                if viewModel.selectedType == .meal,
                   let selectedMealID = viewModel.selectedMealID {
                    proxy.scrollTo(selectedMealID, anchor: .center)
                } else {
                    proxy.scrollTo(optionScrollID(viewModel.selectedItem), anchor: .center)
                }
            }
        }
    }
}

// MARK: - Actions

private extension PlanAddActivitySheet {

    func closeAddSheet() {
        viewModel.closeAddSheet()
    }

    func saveSelectedItem() {
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
}
