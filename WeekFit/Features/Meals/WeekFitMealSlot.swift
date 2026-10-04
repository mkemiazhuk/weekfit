import SwiftUI

enum WeekFitMealSlot: String {
    case breakfast
    case lunch
    case snack
    case dinner

    var title: String {
        switch self {
        case .breakfast:
            return WeekFitLocalizedString("meals.breakfast")

        case .lunch:
            return WeekFitLocalizedString("meals.lunch")

        case .snack:
            return WeekFitLocalizedString("meals.snack")

        case .dinner:
            return WeekFitLocalizedString("meals.dinner")
        }
    }

    var icon: String {
        switch self {
        case .breakfast:
            return "sun.max.fill"

        case .lunch:
            return "fork.knife"

        case .snack:
            return "leaf.fill"

        case .dinner:
            return "moon.fill"
        }
    }

    var color: Color {
        switch self {
        case .breakfast:
            return WeekFitTheme.orange

        case .lunch:
            return WeekFitTheme.green

        case .snack:
            return WeekFitTheme.blue

        case .dinner:
            return WeekFitTheme.purple
        }
    }
}

/// Library grouping for View All Meals — breakfast, lunch, dinner only.
enum MealLibraryPeriod: String, CaseIterable, Identifiable, Codable {
    case breakfast
    case lunch
    case dinner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast:
            return WeekFitLocalizedString("meals.breakfast")
        case .lunch:
            return WeekFitLocalizedString("meals.lunch")
        case .dinner:
            return WeekFitLocalizedString("meals.dinner")
        }
    }

    var icon: String {
        switch self {
        case .breakfast:
            return "sun.max.fill"
        case .lunch:
            return "fork.knife"
        case .dinner:
            return "moon.fill"
        }
    }

    /// Default `suggestedTime` so slot/coach heuristics stay aligned with the chosen category.
    var defaultSuggestedTime: String {
        switch self {
        case .breakfast:
            return "08:30"
        case .lunch:
            return "13:00"
        case .dinner:
            return "19:00"
        }
    }

    var weekFitMealSlot: WeekFitMealSlot {
        switch self {
        case .breakfast:
            return .breakfast
        case .lunch:
            return .lunch
        case .dinner:
            return .dinner
        }
    }

    /// Period that matches the View All grouping windows.
    static func period(at hour: Int) -> MealLibraryPeriod {
        switch hour {
        case 0..<11:
            return .breakfast
        case 11..<16:
            return .lunch
        default:
            return .dinner
        }
    }

    static var current: MealLibraryPeriod {
        period(at: Calendar.current.component(.hour, from: Date()))
    }

    static func groupedSections(from meals: [Meals]) -> [(period: MealLibraryPeriod, meals: [Meals])] {
        allCases.compactMap { period in
            let items = meals.filter { $0.libraryPeriod == period }
            guard !items.isEmpty else { return nil }
            return (period, items)
        }
    }
}

/// Compact breakfast / lunch / dinner picker for meal creation.
struct MealLibraryPeriodPicker: View {
    @Binding var selection: MealLibraryPeriod

    @Environment(\.weekFitPalette) private var palette

    private var accent: Color { WeekFitTheme.meal }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WeekFitLocalizedString("meals.builder.period.title"))
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.86))

            HStack(spacing: 8) {
                ForEach(MealLibraryPeriod.allCases) { period in
                    periodChip(period)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func periodChip(_ period: MealLibraryPeriod) -> some View {
        let selected = selection == period

        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = period
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: period.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(period.title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(
                selected
                    ? (palette.isLight ? WeekFitTheme.primaryText : Color.white.opacity(0.94))
                    : WeekFitTheme.secondaryText.opacity(0.82)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        selected
                            ? accent.opacity(palette.isLight ? 0.16 : 0.20)
                            : WeekFitTheme.whiteOpacity(palette.isLight ? 0.04 : 0.06)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        selected
                            ? accent.opacity(palette.isLight ? 0.42 : 0.48)
                            : WeekFitTheme.whiteOpacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(period.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
