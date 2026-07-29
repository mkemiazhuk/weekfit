import SwiftUI

struct WeekFitWeatherBadge: View {

    enum State: Equatable, Sendable {
        case loading
        case loaded(WeekFitWeatherSummary)
        case hidden
    }

    let state: State
    var onTap: (() -> Void)?

    @Environment(\.sizeCategory) private var sizeCategory
    @EnvironmentObject private var unitsStore: WeekFitUnitsStore

    private let pillHeight: CGFloat = 34
    private let pillCornerRadius: CGFloat = 16

    var body: some View {
        switch state {
        case .hidden:
            Color.clear
                .frame(height: pillHeight)
                .frame(width: reservedWidth)

        case .loading:
            badgeContent(
                temperatureText: "—°",
                symbolName: nil,
                condition: nil,
                conditionWord: nil,
                accessibilitySentence: nil
            )
                .frame(width: reservedWidth)

        case .loaded(let summary):
            let showConditionWord = sizeCategory < .accessibilityMedium
            let system = unitsStore.resolvedSystem
            let tempValue = WeekFitUnitPolicy.temperatureValueForBadge(summary.temperature, system: system)
            badgeContent(
                temperatureText: "\(tempValue)°",
                symbolName: summary.condition.premiumBadgeSymbolName,
                condition: summary.condition,
                conditionWord: showConditionWord ? summary.condition.shortLabel : nil,
                accessibilitySentence: "Current weather, \(tempValue) degrees \(WeekFitUnitPolicy.accessibilityTemperatureUnitName(for: system)), \(summary.condition.shortLabel.lowercased())"
            )
            .frame(width: reservedWidth)
        }
    }

    private func badgeContent(
        temperatureText: String,
        symbolName: String?,
        condition: WeekFitWeatherCondition?,
        conditionWord: String?,
        accessibilitySentence: String?
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            if let symbolName, let condition {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(condition.badgeIconPrimary, condition.badgeIconSecondary)
                    .shadow(color: condition.naturalColor.opacity(0.28), radius: 4, y: 0)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }

            Text(temperatureText)
                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)

            if let conditionWord {
                Text(conditionWord)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.60))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: pillHeight, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                .fill(WeekFitTheme.cardTertiary.opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                        .stroke(WeekFitTheme.borderSoft.opacity(0.9), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySentence ?? "Current weather unavailable"))
        .accessibilityHint(
            onTap != nil
                ? Text(WeekFitUsesRussianLanguage() ? "Открывает детали погоды и источник данных" : "Opens weather details and data attribution")
                : Text("")
        )
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
        .onTapGesture {
            guard let onTap else { return }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onTap()
        }
        .scaleEffect(1.0)
    }

    private var reservedWidth: CGFloat { 132 }
}
