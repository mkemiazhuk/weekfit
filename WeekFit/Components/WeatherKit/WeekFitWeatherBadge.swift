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

    var body: some View {
        switch state {
        case .hidden:
            Color.clear
                .frame(height: pillHeight)

        case .loading:
            badgeContent(
                temperatureText: "—°",
                symbolName: nil,
                condition: nil,
                conditionWord: nil,
                accessibilitySentence: nil
            )

        case .loaded(let summary):
            let showConditionWord = sizeCategory < .accessibilityMedium
            let system = unitsStore.resolvedSystem
            let tempValue = WeekFitUnitPolicy.temperatureValueForBadge(summary.temperature, system: system)
            badgeContent(
                temperatureText: "\(tempValue)°",
                symbolName: summary.badgeSymbolName,
                condition: summary.condition,
                isDaylight: summary.isDaylight,
                conditionWord: showConditionWord ? summary.badgeCompactLabel : nil,
                accessibilitySentence: "Current weather, \(tempValue) degrees \(WeekFitUnitPolicy.accessibilityTemperatureUnitName(for: system)), \(summary.badgeShortLabel.lowercased())"
            )
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
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)

            if let conditionWord {
                Text(conditionWord)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.72))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: pillHeight, alignment: .center)
        .fixedSize(horizontal: true, vertical: false)
        .background {
            weatherBadgeChrome
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySentence ?? "Current weather unavailable"))
        .accessibilityHint(
            onTap != nil
                ? Text(WeekFitTrilingual("Opens weather details and data attribution", "Открывает детали погоды и источник данных", "打开天气详情与数据来源"))
                : Text("")
        )
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
        .onTapGesture {
            guard let onTap else { return }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onTap()
        }
    }

    @ViewBuilder
    private var weatherBadgeChrome: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule(style: .continuous)
                    .fill(palette.isLight ? Color.white.opacity(0.85) : Color.black.opacity(0.28))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(palette.isLight ? 0.9 : 0.28),
                                Color.black.opacity(palette.isLight ? 0.04 : 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(palette.isLight ? 0.04 : 0.28), radius: 12, y: 6)
    }
}
