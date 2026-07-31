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
    @Environment(\.weekFitPalette) private var palette
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
                symbolName: summary.badgeSymbolName,
                condition: summary.condition,
                isDaylight: summary.isDaylight,
                conditionWord: showConditionWord ? summary.badgeShortLabel : nil,
                accessibilitySentence: "Current weather, \(tempValue) degrees \(WeekFitUnitPolicy.accessibilityTemperatureUnitName(for: system)), \(summary.badgeShortLabel.lowercased())"
            )
            .frame(width: reservedWidth)
        }
    }

    private func badgeContent(
        temperatureText: String,
        symbolName: String?,
        condition: WeekFitWeatherCondition?,
        isDaylight: Bool = true,
        conditionWord: String?,
        accessibilitySentence: String?
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            if let symbolName, let condition {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        condition.badgeIconPrimary(isDaylight: isDaylight),
                        condition.badgeIconSecondary(isDaylight: isDaylight)
                    )
                    .shadow(color: condition.naturalColor(isDaylight: isDaylight).opacity(0.28), radius: 4, y: 0)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }

            Text(temperatureText)
                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)

            if let conditionWord {
                Text(conditionWord)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: pillHeight, alignment: .leading)
        .background {
            weatherBadgeChrome
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

    @ViewBuilder
    private var weatherBadgeChrome: some View {
        if palette.isLight {
            RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color.white.opacity(0.55)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.softLight)
                        .opacity(0.55)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.75)
                }
                .shadow(color: WeekFitLightTokens.shadowAmbient.opacity(0.06), radius: 1.5, y: 0.5)
                .shadow(color: WeekFitLightTokens.shadowAmbient.opacity(0.10), radius: 12, y: 4)
        } else {
            RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                .fill(WeekFitTheme.cardTertiary.opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                        .stroke(WeekFitTheme.borderSoft.opacity(0.9), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        }
    }
}
