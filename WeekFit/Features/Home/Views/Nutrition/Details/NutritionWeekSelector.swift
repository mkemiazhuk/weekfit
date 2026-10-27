import SwiftUI

/// Compact week day pills matched to the Nutrition Details Light reference.
struct NutritionWeekSelector: View {
    @Binding var selectedDate: Date
    var accentColor: Color = NutritionDetailsDesign.nutritionAccent
    var onDateSelected: ((Date) -> Void)?

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var visibleWeekOffset = 0

    private let calendar = Calendar.current

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var visibleDays: [Date] {
        let endDay = calendar.date(byAdding: .day, value: visibleWeekOffset * 7, to: today) ?? today
        guard let startDay = calendar.date(byAdding: .day, value: -6, to: endDay) else {
            return [endDay]
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDay).map {
                calendar.startOfDay(for: $0)
            }
        }
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibleWeek
            } else {
                ViewThatFits(in: .horizontal) {
                    weekRow(showsNavigation: true)
                        .fixedSize(horizontal: true, vertical: false)
                    weekRow(showsNavigation: false)
                }
            }
        }
        .onAppear { syncVisibleWeek(toInclude: selectedDate) }
        .onChange(of: selectedDate) { _, newDate in
            syncVisibleWeek(toInclude: newDate)
        }
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            Button(WeekFitLocalizedString("planner.week.previous")) {
                moveWeek(by: -1)
            }
            Button(WeekFitLocalizedString("planner.week.next")) {
                moveWeek(by: 1)
            }
        }
    }

    private var accessibleWeek: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                navButton(
                    systemName: "chevron.left",
                    label: WeekFitLocalizedString("planner.week.previous"),
                    enabled: true
                ) {
                    moveWeek(by: -1)
                }
                Spacer(minLength: 8)
                navButton(
                    systemName: "chevron.right",
                    label: WeekFitLocalizedString("planner.week.next"),
                    enabled: visibleWeekOffset < 0
                ) {
                    moveWeek(by: 1)
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72), spacing: 6)],
                spacing: 6
            ) {
                ForEach(visibleDays, id: \.self) { date in
                    dayPill(date, fillsWidth: true)
                }
            }
        }
    }

    private func weekRow(showsNavigation: Bool) -> some View {
        HStack(spacing: 6) {
            if showsNavigation {
                navButton(
                    systemName: "chevron.left",
                    label: WeekFitLocalizedString("planner.week.previous"),
                    enabled: true
                ) {
                    moveWeek(by: -1)
                }
            }

            HStack(spacing: 4) {
                ForEach(visibleDays, id: \.self) { date in
                    dayPill(date, fillsWidth: !showsNavigation)
                }
            }
            .frame(maxWidth: showsNavigation ? nil : .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        guard abs(value.translation.width) > 34 else { return }
                        moveWeek(by: value.translation.width < 0 ? -1 : 1)
                    }
            )

            if showsNavigation {
                navButton(
                    systemName: "chevron.right",
                    label: WeekFitLocalizedString("planner.week.next"),
                    enabled: visibleWeekOffset < 0
                ) {
                    moveWeek(by: 1)
                }
            }
        }
    }

    private func dayPill(_ date: Date, fillsWidth: Bool) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: today)

        return Button {
            select(date)
        } label: {
            VStack(spacing: 3) {
                Text(dayLetter(for: date))
                    .nutritionReading(12, weight: .semibold, design: .rounded, relativeTo: .caption)
                    .foregroundStyle(isSelected ? palette.textPrimary : palette.textTertiary)
                    .lineLimit(1)

                Text(date.formatted(.dateTime.day()))
                    .nutritionReading(14, weight: .bold, design: .rounded, relativeTo: .callout)
                    .monospacedDigit()
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, fillsWidth ? 2 : 8)
            .frame(minWidth: fillsWidth ? 0 : 44, minHeight: 44)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .background {
                RoundedRectangle(cornerRadius: NutritionDetailsDesign.weekPillCorner, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(palette.isLight ? 0.16 : 0.18) : palette.cardSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: NutritionDetailsDesign.weekPillCorner, style: .continuous)
                    .strokeBorder(
                        isSelected ? accentColor.opacity(0.55) : palette.cardBorder,
                        lineWidth: isSelected ? 1 : 0.7
                    )
            }
            .overlay(alignment: .bottom) {
                if isToday && !isSelected {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 4, height: 4)
                        .padding(.bottom, 5)
                        .accessibilityHidden(true)
                }
            }
            .clipped()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDateLabel(date))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func navButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? palette.iconSecondary : palette.textDisabled)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(palette.cardSurface)
                }
                .overlay {
                    Circle()
                        .strokeBorder(palette.cardBorder, lineWidth: 0.7)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .frame(minWidth: 44, minHeight: 44)
    }

    private func select(_ date: Date) {
        let normalized = min(calendar.startOfDay(for: date), today)
        selectedDate = normalized
        onDateSelected?(normalized)
    }

    private func moveWeek(by delta: Int) {
        let nextOffset = min(0, visibleWeekOffset + delta)
        guard nextOffset != visibleWeekOffset else { return }
        let nextEnd = calendar.date(byAdding: .day, value: nextOffset * 7, to: today) ?? today
        visibleWeekOffset = nextOffset
        select(nextEnd)
    }

    private func syncVisibleWeek(toInclude date: Date) {
        let normalized = min(calendar.startOfDay(for: date), today)
        guard let daysAgo = calendar.dateComponents([.day], from: normalized, to: today).day else {
            visibleWeekOffset = 0
            return
        }
        visibleWeekOffset = -max(0, daysAgo / 7)
    }

    private func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date)
    }

    private func accessibilityDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        return formatter.string(from: date)
    }
}
