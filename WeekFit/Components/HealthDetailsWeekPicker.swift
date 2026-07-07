import SwiftUI

struct HealthDetailsWeekPicker: View {
    @Binding var selectedDate: Date

    let accentColor: Color
    var onDateSelected: ((Date) -> Void)?

    @State private var visibleWeekOffset = 0

    private let calendar = Calendar.current

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var visibleDays: [Date] {
        let endDay = calendar.date(
            byAdding: .day,
            value: visibleWeekOffset * 7,
            to: today
        ) ?? today

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
        HStack(spacing: 8) {
            weekNavigationButton(systemName: "chevron.left", isEnabled: true) {
                moveWeek(by: -1)
            }

            HStack(spacing: 6) {
                ForEach(visibleDays, id: \.self) { date in
                    dayCell(date)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        guard abs(value.translation.width) > 34 else { return }

                        if value.translation.width < 0 {
                            moveWeek(by: -1)
                        } else {
                            moveWeek(by: 1)
                        }
                    }
            )

            weekNavigationButton(systemName: "chevron.right", isEnabled: visibleWeekOffset < 0) {
                moveWeek(by: 1)
            }
        }
        .onAppear {
            syncVisibleWeek(toInclude: selectedDate)
        }
        .onChange(of: selectedDate) { _, newDate in
            syncVisibleWeek(toInclude: newDate)
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: today)

        return Button {
            select(date)
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 3) {
                    Text(dayTitle(for: date))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    if isToday {
                        Circle()
                            .fill(isSelected ? .white.opacity(0.92) : accentColor.opacity(0.90))
                            .frame(width: 3.5, height: 3.5)
                    }
                }
                .foregroundStyle(isSelected ? .white : .white.opacity(0.44))

                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .black : .white.opacity(isToday ? 0.86 : 0.68))
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(dayNumberBackground(isSelected: isSelected, isToday: isToday))
                    }
                    .overlay {
                        if isToday && !isSelected {
                            Circle()
                                .stroke(accentColor.opacity(0.50), lineWidth: 1)
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.12) : WeekFitTheme.whiteOpacity(isToday ? 0.038 : 0.020))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? accentColor.opacity(0.28) : WeekFitTheme.whiteOpacity(isToday ? 0.07 : 0.035),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func weekNavigationButton(
        systemName: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isEnabled ? .white.opacity(0.70) : .white.opacity(0.16))
                .frame(width: 28, height: 48)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(WeekFitTheme.whiteOpacity(isEnabled ? 0.035 : 0.014))
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func select(_ date: Date) {
        let normalizedDate = min(calendar.startOfDay(for: date), today)
        selectedDate = normalizedDate
        onDateSelected?(normalizedDate)
    }

    private func moveWeek(by delta: Int) {
        let nextOffset = min(0, visibleWeekOffset + delta)
        guard nextOffset != visibleWeekOffset else { return }

        let nextEndDay = calendar.date(
            byAdding: .day,
            value: nextOffset * 7,
            to: today
        ) ?? today

        visibleWeekOffset = nextOffset

        select(nextEndDay)
    }

    private func syncVisibleWeek(toInclude date: Date) {
        let normalizedDate = min(calendar.startOfDay(for: date), today)
        guard let daysAgo = calendar.dateComponents([.day], from: normalizedDate, to: today).day else {
            visibleWeekOffset = 0
            return
        }

        visibleWeekOffset = -max(0, daysAgo / 7)
    }

    private func dayTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date)
    }

    private func dayNumberBackground(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return accentColor
        }

        if isToday {
            return accentColor.opacity(0.13)
        }

        return WeekFitTheme.whiteOpacity(0.050)
    }
}
