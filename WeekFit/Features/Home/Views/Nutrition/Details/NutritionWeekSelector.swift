import SwiftUI

/// Compact week day pills matched to the Nutrition Details Light reference.
struct NutritionWeekSelector: View {
    @Binding var selectedDate: Date
    var accentColor: Color = NutritionDetailsDesign.nutritionAccent
    var onDateSelected: ((Date) -> Void)?

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
        HStack(spacing: 6) {
            navButton(
                systemName: "chevron.left",
                label: WeekFitLocalizedString("planner.week.previous"),
                enabled: true
            ) {
                moveWeek(by: -1)
            }

            HStack(spacing: 4) {
                ForEach(visibleDays, id: \.self) { date in
                    dayPill(date)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        guard abs(value.translation.width) > 34 else { return }
                        moveWeek(by: value.translation.width < 0 ? -1 : 1)
                    }
            )

            navButton(
                systemName: "chevron.right",
                label: WeekFitLocalizedString("planner.week.next"),
                enabled: visibleWeekOffset < 0
            ) {
                moveWeek(by: 1)
            }
        }
        .onAppear { syncVisibleWeek(toInclude: selectedDate) }
        .onChange(of: selectedDate) { _, newDate in
            syncVisibleWeek(toInclude: newDate)
        }
        .accessibilityElement(children: .contain)
    }

    private func dayPill(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: today)

        return Button {
            select(date)
        } label: {
            VStack(spacing: 4) {
                Text(dayLetter(for: date))
                    .font(NutritionDetailsDesign.Typography.weekDay)
                    .foregroundStyle(
                        isSelected
                            ? WeekFitLightTokens.textSecondary
                            : WeekFitLightTokens.textQuaternary
                    )

                ZStack(alignment: .top) {
                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 3.5, height: 3.5)
                            .offset(y: -5)
                            .accessibilityHidden(true)
                    }

                    Text(date.formatted(.dateTime.day()))
                        .font(NutritionDetailsDesign.Typography.weekDate)
                        .monospacedDigit()
                        .foregroundStyle(WeekFitLightTokens.textPrimary)
                }
                .frame(height: 18)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: NutritionDetailsDesign.weekPillCorner, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.14) : NutritionDetailsDesign.cardSurface)
                    .shadow(
                        color: Color.black.opacity(isSelected ? 0.015 : 0.035),
                        radius: isSelected ? 1 : 5,
                        y: isSelected ? 1 : 2
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: NutritionDetailsDesign.weekPillCorner, style: .continuous)
                    .strokeBorder(
                        isSelected ? accentColor.opacity(0.55) : Color.black.opacity(0.045),
                        lineWidth: isSelected ? 1 : 0.7
                    )
            }
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
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(
                    enabled
                        ? WeekFitLightTokens.iconSecondary
                        : WeekFitLightTokens.textDisabled
                )
                .frame(width: 26, height: 42)
                .background {
                    Circle()
                        .fill(NutritionDetailsDesign.cardSurface)
                        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.045), lineWidth: 0.7)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .frame(minWidth: 40, minHeight: 40)
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
