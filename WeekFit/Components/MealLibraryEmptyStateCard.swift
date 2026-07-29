import SwiftUI

struct MealLibraryEmptyStateCard: View {
    enum Presentation {
        case compact
        case expanded
    }

    struct BenefitRow: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
    }

    let title: String
    let message: String
    let ctaTitle: String
    let benefits: [BenefitRow]
    let presentation: Presentation
    let action: () -> Void

    private var isExpanded: Bool { presentation == .expanded }

    private var gold: Color { WeekFitTheme.brandGold }
    private var goldDeep: Color { WeekFitTheme.brandGoldDeep }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 18) {
            header

            if isExpanded && !benefits.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(benefits) { benefit in
                        benefitRow(benefit)
                    }
                }
                .padding(.top, 2)
            }

            ctaButton
                .padding(.top, isExpanded ? 2 : 10)
        }
        .padding(.horizontal, isExpanded ? 18 : 18)
        .padding(.vertical, isExpanded ? 16 : 18)
        .weekFitPremiumCard(
            emphasis: isExpanded ? .elevated : .standard,
            accent: gold,
            cornerRadius: cornerRadius
        )
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: isExpanded ? 12 : 14) {
            iconBadge
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: isExpanded ? 5 : 6) {
                Text(title)
                    .font(.system(size: isExpanded ? 21 : 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(.system(size: isExpanded ? 14 : 14, weight: .regular))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(isExpanded ? 0.72 : 0.70))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var iconBadge: some View {
        let size: CGFloat = isExpanded ? 46 : 56
        let symbolSize: CGFloat = isExpanded ? 17 : 24

        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            gold.opacity(isExpanded ? 0.12 : 0.14),
                            goldDeep.opacity(isExpanded ? 0.07 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            gold.opacity(isExpanded ? 0.38 : 0.42),
                            goldDeep.opacity(isExpanded ? 0.18 : 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )

            Image(systemName: "fork.knife")
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(gold.opacity(0.92))
        }
        .frame(width: size, height: size)
        .shadow(color: gold.opacity(isExpanded ? 0.06 : 0.05), radius: 5, y: 1)
    }

    // MARK: - Benefits (expanded only)

    private func benefitRow(_ benefit: BenefitRow) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: benefit.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(gold.opacity(0.78))
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(WeekFitTheme.whiteOpacity(0.03))
                }
                .overlay {
                    Circle()
                        .stroke(gold.opacity(0.18), lineWidth: 0.8)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(benefit.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText.opacity(0.94))

                Text(benefit.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: action) {
            Text(ctaTitle)
                .font(.system(size: isExpanded ? 16 : 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.84))
                .frame(maxWidth: .infinity)
                .frame(minHeight: isExpanded ? 48 : 48)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(WeekFitTheme.meal.opacity(0.92))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ctaTitle)
        .accessibilityHint(Text(WeekFitLocalizedString("planner.add.meal")))
        .accessibilityIdentifier("meals.create")
    }


    private var cornerRadius: CGFloat {
        isExpanded ? 24 : 22
    }
}

#if DEBUG
#Preview("Meal Empty Compact") {
    MealLibraryEmptyStateCard(
        title: "No saved meals yet",
        message: "Create reusable meals once.\nLog them in one tap anytime.",
        ctaTitle: "Create meal",
        benefits: [],
        presentation: .compact,
        action: {}
    )
    .padding()
    .background(WeekFitTheme.backgroundColor)
    .preferredColorScheme(.dark)
}

#Preview("Meal Empty Expanded") {
    MealLibraryEmptyStateCard(
        title: "Build your meal library",
        message: "Create meals once, then log them in seconds whenever you eat them again.",
        ctaTitle: "Create your first meal",
        benefits: [
            .init(id: "build", icon: "fork.knife", title: "Build meals in seconds", subtitle: "Combine foods into reusable meals"),
            .init(id: "scan", icon: "barcode.viewfinder", title: "Scan and add quickly", subtitle: "Use barcode scanning for packaged foods"),
            .init(id: "reuse", icon: "arrow.triangle.2.circlepath", title: "Reuse anytime", subtitle: "Your saved meals stay ready to log")
        ],
        presentation: .expanded,
        action: {}
    )
    .padding()
    .background(WeekFitTheme.backgroundColor)
    .preferredColorScheme(.dark)
}

#Preview("Meal Empty Expanded AX") {
    MealLibraryEmptyStateCard(
        title: "Build your meal library",
        message: "Create meals once, then log them in seconds whenever you eat them again.",
        ctaTitle: "Create your first meal",
        benefits: [
            .init(id: "build", icon: "fork.knife", title: "Build meals in seconds", subtitle: "Combine foods into reusable meals"),
            .init(id: "scan", icon: "barcode.viewfinder", title: "Scan and add quickly", subtitle: "Use barcode scanning for packaged foods"),
            .init(id: "reuse", icon: "arrow.triangle.2.circlepath", title: "Reuse anytime", subtitle: "Your saved meals stay ready to log")
        ],
        presentation: .expanded,
        action: {}
    )
    .padding()
    .background(WeekFitTheme.backgroundColor)
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Meal Empty RU") {
    MealLibraryEmptyStateCard(
        title: "Создайте свою коллекцию блюд",
        message: "Сохраняйте блюда один раз, чтобы затем добавлять их в дневник за несколько секунд.",
        ctaTitle: "Создать первое блюдо",
        benefits: [
            .init(id: "build", icon: "fork.knife", title: "Создавайте блюда за секунды", subtitle: "Объединяйте продукты в готовые блюда"),
            .init(id: "scan", icon: "barcode.viewfinder", title: "Сканируйте и добавляйте", subtitle: "Используйте штрихкод для упакованных продуктов"),
            .init(id: "reuse", icon: "arrow.triangle.2.circlepath", title: "Используйте снова", subtitle: "Сохранённые блюда всегда готовы к добавлению")
        ],
        presentation: .expanded,
        action: {}
    )
    .padding()
    .background(WeekFitTheme.backgroundColor)
    .preferredColorScheme(.dark)
}
#endif
