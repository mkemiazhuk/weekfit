import SwiftUI
import WeatherKit

struct WeekFitWeatherDetailSheet: View {
    let summary: WeekFitWeatherSummary

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var unitsStore: WeekFitUnitsStore

    @State private var attribution: WeatherAttribution?
    @State private var attributionFetchFailed = false
    @State private var didFetchAttribution = false

    private var period: WeekFitWeatherPeriod { summary.resolvedPeriod }
    private var tokens: WeekFitWeatherTokens {
        summary.resolvedTokens(appAppearanceDark: !palette.isLight)
    }
    private var relevance: WeekFitWeatherRelevance.Content {
        WeekFitWeatherRelevance.content(for: summary, period: period)
    }

    private var locationLabel: String {
        summary.placeName
            ?? (WeekFitUsesRussianLanguage() ? "Рядом с вами" : "Near you")
    }

    var body: some View {
        ZStack {
            adaptiveCanvas.ignoresSafeArea()

            VStack(spacing: 12) {
                sheetHeader
                heroCard
                primaryMetrics
                secondaryMetricsGrid
                coachInsight
                attributionSection
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .presentationBackground(tokens.backgroundPrimary)
        .task {
            guard !didFetchAttribution else { return }
            didFetchAttribution = true
            await fetchAttribution()
        }
    }

    private var adaptiveCanvas: some View {
        LinearGradient(
            colors: [
                tokens.backgroundSecondary,
                tokens.backgroundPrimary,
                tokens.backgroundPrimary
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Header

private extension WeekFitWeatherDetailSheet {
    var sheetHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(WeekFitUsesRussianLanguage() ? "Погода" : "Weather")
                    .font(.system(size: 26, weight: .bold, design: .default))
                    .foregroundStyle(tokens.textPrimary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)

                Text(locationLabel)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(tokens.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            WeekFitCloseButton(size: .large) {
                dismiss()
            }
            .fixedSize()
        }
    }
}

// MARK: - Hero

private extension WeekFitWeatherDetailSheet {
    var heroCard: some View {
        let system = unitsStore.resolvedSystem
        let tempValue = WeekFitUnitPolicy.temperatureValueForBadge(summary.temperature, system: system)

        return ZStack(alignment: .bottomLeading) {
            WeekFitWeatherHeroAtmosphere(
                condition: summary.condition,
                period: period,
                tokens: tokens,
                temperatureC: summary.temperature.value,
                reduceMotion: reduceMotion
            )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tokens.heroReadabilityWash.opacity(0.05),
                            tokens.heroReadabilityWash.opacity(0.55),
                            tokens.heroReadabilityWash.opacity(0.82)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(tempValue)°")
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(tokens.textPrimary)
                            .tracking(-1.6)
                            .contentTransition(.numericText())

                        Image(systemName: summary.badgeSymbolName)
                            .font(.system(size: 26, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                tokens.heroIllustrationPrimary,
                                tokens.heroIllustrationSecondary
                            )
                            .shadow(
                                color: tokens.ambientGlow.opacity(0.55),
                                radius: reduceMotion ? 0 : 10,
                                y: 0
                            )
                            .offset(y: -1)
                    }

                    Text(summary.badgeShortLabel)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(tokens.textPrimary.opacity(0.88))
                }

                Text(relevance.contextSentence)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(tokens.textSecondary)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .frame(height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(tokens.cardStroke, lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(tokens.isNightAtmosphere ? 0.24 : 0.045), radius: 12, y: 5)
        .shadow(color: Color.black.opacity(tokens.isNightAtmosphere ? 0.08 : 0.018), radius: 2, y: 1)
    }
}

// MARK: - Metrics

private extension WeekFitWeatherDetailSheet {
    var primaryMetrics: some View {
        let kinds = WeekFitWeatherMetricsOrder.primaryMetrics(for: summary)
        return HStack(spacing: 10) {
            ForEach(kinds, id: \.self) { kind in
                metricCell(kind: kind, emphasized: true)
            }
        }
    }

    var secondaryMetricsGrid: some View {
        // Cap at 4 cells (2×2) so the sheet still fits one screen.
        let kinds = Array(
            WeekFitWeatherMetricsOrder.secondaryMetrics(for: summary, period: period).prefix(4)
        )
        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            ForEach(kinds, id: \.self) { kind in
                metricCell(kind: kind, emphasized: false)
            }
        }
    }

    func metricCell(kind: WeekFitWeatherMetricKind, emphasized: Bool) -> some View {
        let content = metricContent(for: kind)
        return VStack(alignment: .leading, spacing: 5) {
            Image(systemName: content.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(content.tint)

            Text(content.value)
                .font(.system(size: emphasized ? 18 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(tokens.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(content.label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(tokens.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tokens.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tokens.cardStroke, lineWidth: 0.7)
                }
                .shadow(
                    color: Color.black.opacity(tokens.isNightAtmosphere ? 0.16 : 0.032),
                    radius: 8,
                    y: 3
                )
                .shadow(
                    color: Color.black.opacity(tokens.isNightAtmosphere ? 0.06 : 0.014),
                    radius: 1.5,
                    y: 1
                )
        }
    }

    func metricContent(for kind: WeekFitWeatherMetricKind) -> (icon: String, label: String, value: String, tint: Color) {
        let isRu = WeekFitUsesRussianLanguage()
        let system = unitsStore.resolvedSystem
        let accent = tokens.primaryAccent
        let secondary = tokens.metricIconTint

        switch kind {
        case .feelsLike:
            let value = WeekFitUnitPolicy.temperatureValueForBadge(summary.feelsLike, system: system)
            return (
                "thermometer.medium",
                isRu ? "Ощущается" : "Feels like",
                "\(value)°",
                accent
            )

        case .highLow:
            let high = summary.highTemperature.map {
                "\(WeekFitUnitPolicy.temperatureValueForBadge($0, system: system))"
            } ?? "—"
            let low = summary.lowTemperature.map {
                "\(WeekFitUnitPolicy.temperatureValueForBadge($0, system: system))"
            } ?? "—"
            return (
                "thermometer.sun",
                isRu ? "Макс / Мин" : "High / Low",
                "\(high)° / \(low)°",
                Color(red: 0.90, green: 0.55, blue: 0.40)
            )

        case .humidity:
            return (
                "humidity",
                isRu ? "Влажность" : "Humidity",
                "\(summary.humidityPercent)%",
                Color(red: 0.35, green: 0.60, blue: 0.92)
            )

        case .wind:
            return (
                "wind",
                isRu ? "Ветер" : "Wind",
                WeekFitUnitPolicy.formatSpeed(summary.windSpeed, system: system),
                secondary
            )

        case .uvIndex:
            return (
                "sun.max",
                isRu ? "УФ-индекс" : "UV Index",
                uvLabel,
                Color(red: 0.96, green: 0.76, blue: 0.26)
            )

        case .rainChance:
            let chance = summary.precipitationChance ?? 0
            return (
                "cloud.rain",
                isRu ? "Осадки" : "Rain chance",
                "\(chance)%",
                tokens.primaryAccent
            )

        case .visibility:
            return (
                "eye",
                isRu ? "Видимость" : "Visibility",
                visibilityLabel(system: system),
                Color(red: 0.55, green: 0.65, blue: 0.78)
            )

        case .sunriseSunset:
            return (
                "sunrise.fill",
                isRu ? "Восход / Закат" : "Sunrise / Sunset",
                sunTimesLabel,
                Color(red: 0.95, green: 0.68, blue: 0.35)
            )
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

    func visibilityLabel(system: WeekFitResolvedUnitSystem) -> String {
        guard let km = summary.visibilityKilometers else {
            return "—"
        }
        if system == .us {
            let miles = km * 0.621371
            if miles < 1 {
                return String(format: "%.1f mi", miles)
            }
            return String(format: "%.0f mi", miles.rounded())
        }
        if km < 1 {
            return String(format: "%.0f m", km * 1000)
        }
        return String(format: "%.1f km", km)
    }

    var sunTimesLabel: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let rise = summary.sunrise.map { formatter.string(from: $0) } ?? "—"
        let set = summary.sunset.map { formatter.string(from: $0) } ?? "—"
        return "\(rise) / \(set)"
    }
}

// MARK: - Coach Insight

private extension WeekFitWeatherDetailSheet {
    var coachInsight: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(coachInsightAccent)

                Text(WeekFitUsesRussianLanguage() ? "Совет тренера" : "Coach Insight")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(coachInsightAccent)
            }

            Text(WeekFitWeatherCoachInsight.recommendation(for: summary, period: period))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(tokens.textPrimary.opacity(0.92))
                .lineSpacing(2)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(coachInsightFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(coachInsightStroke, lineWidth: 0.8)
                }
        }
    }

    private var coachInsightAccent: Color {
        tokens.isNightAtmosphere
            ? WeekFitLightTokens.coachPurple
            : Color(red: 0.52, green: 0.42, blue: 0.78)
    }

    private var coachInsightFill: Color {
        tokens.isNightAtmosphere
            ? WeekFitLightTokens.coachPurple.opacity(0.14)
            : Color(red: 0.92, green: 0.90, blue: 0.98).opacity(0.95)
    }

    private var coachInsightStroke: Color {
        coachInsightAccent.opacity(tokens.isNightAtmosphere ? 0.28 : 0.18)
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
                        url: tokens.isNightAtmosphere
                            ? attribution.combinedMarkDarkURL
                            : (colorScheme == .dark
                                ? attribution.combinedMarkDarkURL
                                : attribution.combinedMarkLightURL)
                    ) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 12)
                    } placeholder: {
                        Color.clear.frame(height: 12)
                    }
                    .accessibilityHidden(true)

                    Link(
                        WeekFitUsesRussianLanguage() ? "Источники погоды" : "Weather data sources",
                        destination: attribution.legalPageURL
                    )
                    .font(.caption2)
                    .foregroundStyle(tokens.textSecondary.opacity(0.85))
                }
            } else if attributionFetchFailed {
                Text(WeekFitUsesRussianLanguage() ? "Источник погодных данных недоступен." : "Weather data sources are unavailable.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(tokens.textSecondary.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Color.clear.frame(height: 12)
            }
        }
    }
}
