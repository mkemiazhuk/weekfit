import SwiftUI
import WeatherKit

struct WeekFitWeatherDetailSheet: View {
    let summary: WeekFitWeatherSummary

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var unitsStore: WeekFitUnitsStore

    @State private var attribution: WeatherAttribution?
    @State private var attributionFetchFailed = false
    @State private var didFetchAttribution = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    detailsGrid
                    coachInsight
                    attributionSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .task {
            guard !didFetchAttribution else { return }
            didFetchAttribution = true
            await fetchAttribution()
        }
    }
}

// MARK: - Header

private extension WeekFitWeatherDetailSheet {
    var header: some View {
        VStack(spacing: 22) {
            HStack(spacing: 13) {
                Text(WeekFitUsesRussianLanguage() ? "Погода" : "Weather")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(WeekFitTheme.whiteOpacity(0.075)))
                        .overlay {
                            Circle().stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .fixedSize()
            }

            heroCondition
        }
    }

    var heroCondition: some View {
        let system = unitsStore.resolvedSystem
        let tempValue = WeekFitUnitPolicy.temperatureValueForBadge(summary.temperature, system: system)

        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: summary.condition.premiumBadgeSymbolName)
                .font(.system(size: 40, weight: .medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    summary.condition.badgeIconPrimary,
                    summary.condition.badgeIconSecondary
                )
                .shadow(color: summary.condition.naturalColor.opacity(0.45), radius: 10, y: 0)
                .frame(width: 56, height: 56)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(tempValue)°")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(-1.5)

                Text(summary.condition.shortLabel)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.65))
            }

            Spacer()
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(WeekFitTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(WeekFitTheme.cardBorder, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 14, y: 5)
        }
    }
}

// MARK: - Details Grid

private extension WeekFitWeatherDetailSheet {
    var detailsGrid: some View {
        let isRu = WeekFitUsesRussianLanguage()
        let system = unitsStore.resolvedSystem

        let feelsLikeValue = WeekFitUnitPolicy.temperatureValueForBadge(summary.feelsLike, system: system)
        let windText = WeekFitUnitPolicy.formatSpeed(summary.windSpeed, system: system)

        var cells: [(icon: String, label: String, value: String, color: Color)] = [
            (
                "thermometer.medium",
                isRu ? "Ощущается" : "Feels like",
                "\(feelsLikeValue)°",
                Color(red: 0.96, green: 0.60, blue: 0.30)
            ),
            (
                "humidity",
                isRu ? "Влажность" : "Humidity",
                "\(summary.humidityPercent)%",
                Color(red: 0.35, green: 0.60, blue: 0.92)
            ),
            (
                "wind",
                isRu ? "Ветер" : "Wind",
                windText,
                Color(red: 0.55, green: 0.65, blue: 0.75)
            ),
            (
                "sun.max",
                isRu ? "УФ-индекс" : "UV Index",
                uvLabel,
                Color(red: 0.96, green: 0.76, blue: 0.26)
            ),
        ]

        if let high = summary.highTemperature, let low = summary.lowTemperature {
            let highValue = WeekFitUnitPolicy.temperatureValueForBadge(high, system: system)
            let lowValue = WeekFitUnitPolicy.temperatureValueForBadge(low, system: system)
            cells.insert(
                (
                    "thermometer.sun",
                    isRu ? "Макс / Мин" : "High / Low",
                    "\(highValue)° / \(lowValue)°",
                    Color(red: 0.90, green: 0.50, blue: 0.40)
                ),
                at: 1
            )
        }

        if let chance = summary.precipitationChance {
            cells.append(
                (
                    "cloud.rain",
                    isRu ? "Осадки" : "Rain chance",
                    "\(chance)%",
                    Color(red: 0.40, green: 0.65, blue: 0.95)
                )
            )
        }

        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                detailCell(icon: cell.icon, label: cell.label, value: cell.value, tint: cell.color)
            }
        }
    }

    func detailCell(icon: String, label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.50))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WeekFitTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WeekFitTheme.cardBorder, lineWidth: 1)
                }
        }
    }

    var uvLabel: String {
        let isRu = WeekFitUsesRussianLanguage()
        let val = summary.uvIndex
        let descriptor: String
        switch val {
        case 0...2:  descriptor = isRu ? "Низкий" : "Low"
        case 3...5:  descriptor = isRu ? "Средний" : "Moderate"
        case 6...7:  descriptor = isRu ? "Высокий" : "High"
        case 8...10: descriptor = isRu ? "Очень высокий" : "Very High"
        default:     descriptor = isRu ? "Экстремальный" : "Extreme"
        }
        return "\(val) · \(descriptor)"
    }
}

// MARK: - Coach Insight

private extension WeekFitWeatherDetailSheet {
    var coachInsight: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.coachAccent)

                Text(WeekFitUsesRussianLanguage() ? "Рекомендация" : "Coach Insight")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.coachAccent)
            }

            Text(coachRecommendation)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.82))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WeekFitTheme.coachAccent.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(WeekFitTheme.coachAccent.opacity(0.18), lineWidth: 1)
                }
        }
    }

    var coachRecommendation: String {
        WeekFitWeatherCoachInsight.recommendation(for: summary)
    }
}

// MARK: - Attribution

private extension WeekFitWeatherDetailSheet {
    func fetchAttribution() async {
        do {
            attribution = try await WeatherService.shared.attribution
        } catch {
            attributionFetchFailed = true
        }
    }

    var attributionSection: some View {
        Group {
            if let attribution {
                HStack(spacing: 8) {
                    AsyncImage(
                        url: colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL
                    ) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 14)
                    } placeholder: {
                        Color.clear.frame(height: 14)
                    }
                    .accessibilityHidden(true)

                    Link(
                        WeekFitUsesRussianLanguage() ? "Источники погоды" : "Weather data sources",
                        destination: attribution.legalPageURL
                    )
                    .font(.caption2)
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.72))
                }
                .padding(.vertical, 8)
            } else if attributionFetchFailed {
                Text(WeekFitUsesRussianLanguage() ? "Источник погодных данных недоступен." : "Weather data sources are unavailable.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.28))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                // While loading attribution, keep spacing stable.
                Text("")
                    .frame(height: 22)
            }
        }
    }
}
