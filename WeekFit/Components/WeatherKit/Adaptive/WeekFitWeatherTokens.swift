import SwiftUI

/// Semantic weather tokens. Resolve once from period + condition + temperature —
/// never scatter condition-specific colors across individual views.
struct WeekFitWeatherTokens: Equatable {
    var backgroundPrimary: Color
    var backgroundSecondary: Color
    var heroSurface: Color
    var primaryAccent: Color
    var secondaryAccent: Color
    var textPrimary: Color
    var textSecondary: Color
    var cardSurface: Color
    var cardStroke: Color
    var ambientGlow: Color
    var metricIconTint: Color
    var heroReadabilityWash: Color
    var heroIllustrationPrimary: Color
    var heroIllustrationSecondary: Color
    var isNightAtmosphere: Bool

    /// Visual intensity modifiers layered on top of base condition.
    enum ClimateModifier: Equatable, Sendable {
        case none
        case extremeHeat
        case veryCold
        case lowVisibility
    }

    static func resolve(
        period: WeekFitWeatherPeriod,
        condition: WeekFitWeatherCondition,
        temperatureC: Double,
        visibilityKm: Double?,
        precipitationChance: Int?,
        appAppearanceDark: Bool = false
    ) -> WeekFitWeatherTokens {
        let modifier = climateModifier(
            temperatureC: temperatureC,
            visibilityKm: visibilityKm,
            condition: condition
        )
        let base = baseTokens(period: period, condition: condition, modifier: modifier)
        let refined = refine(
            base,
            condition: condition,
            period: period,
            precipitationChance: precipitationChance,
            modifier: modifier
        )
        if appAppearanceDark {
            return adaptForDarkAppAppearance(refined, period: period, condition: condition)
        }
        return adaptForLightAppAppearance(refined, period: period, condition: condition)
    }

    /// Daytime weather chrome is cream by design for outdoor atmosphere.
    /// In app dark mode, remap canvas/text/cards to dark while keeping weather accents.
    private static func adaptForDarkAppAppearance(
        _ tokens: WeekFitWeatherTokens,
        period: WeekFitWeatherPeriod,
        condition: WeekFitWeatherCondition
    ) -> WeekFitWeatherTokens {
        guard !period.isNightLike else { return tokens }

        var adapted = tokens
        adapted.backgroundPrimary = Color(red: 0.09, green: 0.10, blue: 0.12)
        adapted.backgroundSecondary = Color(red: 0.13, green: 0.14, blue: 0.18)
        adapted.heroSurface = Color(red: 0.14, green: 0.15, blue: 0.19)
        adapted.textPrimary = Color(red: 0.95, green: 0.96, blue: 0.97)
        adapted.textSecondary = Color(red: 0.70, green: 0.72, blue: 0.78)
        adapted.cardSurface = Color(red: 0.16, green: 0.17, blue: 0.21).opacity(0.94)
        adapted.cardStroke = Color.white.opacity(0.08)
        adapted.heroReadabilityWash = Color.black.opacity(0.48)
        adapted.ambientGlow = adapted.ambientGlow.opacity(0.50)
        adapted.metricIconTint = adapted.primaryAccent
        adapted.isNightAtmosphere = true

        // Soft condition tint on the upper wash so dark mode still feels weather-led.
        switch condition {
        case .clear, .partlyCloudy:
            adapted.backgroundSecondary = Color(red: 0.14, green: 0.16, blue: 0.22)
        case .rain, .storm:
            adapted.backgroundSecondary = Color(red: 0.12, green: 0.15, blue: 0.22)
        case .snow:
            adapted.backgroundSecondary = Color(red: 0.14, green: 0.17, blue: 0.23)
        case .cloudy, .fog, .windy, .other:
            break
        }

        return adapted
    }

    /// Evening/night weather tokens are dark by atmosphere. In app light mode that reads
    /// as a heavy purple sheet on cream chrome — remap to a soft dusk wash with dark text.
    private static func adaptForLightAppAppearance(
        _ tokens: WeekFitWeatherTokens,
        period: WeekFitWeatherPeriod,
        condition: WeekFitWeatherCondition
    ) -> WeekFitWeatherTokens {
        guard period.isNightLike else { return tokens }

        var adapted = tokens
        adapted.backgroundPrimary = Color(red: 0.965, green: 0.955, blue: 0.975)
        adapted.backgroundSecondary = Color(red: 0.920, green: 0.910, blue: 0.955)
        adapted.heroSurface = Color(red: 0.985, green: 0.980, blue: 0.995)
        adapted.textPrimary = Color(red: 0.18, green: 0.16, blue: 0.24)
        adapted.textSecondary = Color(red: 0.42, green: 0.40, blue: 0.50)
        adapted.cardSurface = Color.white.opacity(0.94)
        adapted.cardStroke = Color.black.opacity(0.055)
        adapted.heroReadabilityWash = Color(red: 0.96, green: 0.95, blue: 0.99).opacity(0.72)
        adapted.ambientGlow = Color(red: 0.62, green: 0.55, blue: 0.92).opacity(0.28)
        adapted.metricIconTint = Color(red: 0.55, green: 0.48, blue: 0.82)
        adapted.primaryAccent = Color(red: 0.58, green: 0.50, blue: 0.88)
        adapted.secondaryAccent = Color(red: 0.48, green: 0.58, blue: 0.88)
        adapted.heroIllustrationPrimary = Color(red: 0.42, green: 0.40, blue: 0.72)
        adapted.heroIllustrationSecondary = Color(red: 0.55, green: 0.58, blue: 0.88)
        adapted.isNightAtmosphere = false

        switch condition {
        case .clear, .partlyCloudy:
            adapted.backgroundSecondary = Color(red: 0.900, green: 0.905, blue: 0.960)
            adapted.ambientGlow = Color(red: 0.55, green: 0.58, blue: 0.95).opacity(0.30)
        case .rain, .storm:
            adapted.backgroundPrimary = Color(red: 0.940, green: 0.945, blue: 0.970)
            adapted.backgroundSecondary = Color(red: 0.880, green: 0.895, blue: 0.950)
            adapted.primaryAccent = Color(red: 0.42, green: 0.55, blue: 0.90)
        case .snow:
            adapted.backgroundPrimary = Color(red: 0.950, green: 0.960, blue: 0.985)
            adapted.backgroundSecondary = Color(red: 0.910, green: 0.930, blue: 0.980)
        case .fog:
            adapted.backgroundPrimary = Color(red: 0.940, green: 0.940, blue: 0.950)
            adapted.backgroundSecondary = Color(red: 0.900, green: 0.905, blue: 0.925)
        case .cloudy, .windy, .other:
            break
        }

        return adapted
    }

    static func climateModifier(
        temperatureC: Double,
        visibilityKm: Double?,
        condition: WeekFitWeatherCondition
    ) -> ClimateModifier {
        if condition == .fog || (visibilityKm ?? 20) < 1.5 {
            return .lowVisibility
        }
        if temperatureC >= 33 {
            return .extremeHeat
        }
        if temperatureC <= 0 {
            return .veryCold
        }
        return .none
    }

    // MARK: - Base palettes by period

    private static func baseTokens(
        period: WeekFitWeatherPeriod,
        condition: WeekFitWeatherCondition,
        modifier: ClimateModifier
    ) -> WeekFitWeatherTokens {
        switch period {
        case .dawn:
            return dawnTokens(condition: condition, modifier: modifier)
        case .day:
            return dayTokens(condition: condition, modifier: modifier)
        case .goldenHour:
            return goldenHourTokens(condition: condition, modifier: modifier)
        case .dusk:
            return duskTokens(condition: condition, modifier: modifier)
        case .night:
            return nightTokens(condition: condition, modifier: modifier)
        }
    }

    private static func dawnTokens(
        condition: WeekFitWeatherCondition,
        modifier: ClimateModifier
    ) -> WeekFitWeatherTokens {
        var tokens = WeekFitWeatherTokens(
            backgroundPrimary: Color(red: 0.965, green: 0.945, blue: 0.925),
            backgroundSecondary: Color(red: 0.945, green: 0.930, blue: 0.955),
            heroSurface: Color(red: 0.990, green: 0.975, blue: 0.960),
            primaryAccent: Color(red: 0.92, green: 0.62, blue: 0.42),
            secondaryAccent: Color(red: 0.72, green: 0.68, blue: 0.88),
            textPrimary: Color(red: 0.18, green: 0.17, blue: 0.20),
            textSecondary: Color(red: 0.42, green: 0.40, blue: 0.44),
            cardSurface: Color(red: 0.995, green: 0.990, blue: 0.985).opacity(0.94),
            cardStroke: Color.black.opacity(0.045),
            ambientGlow: Color(red: 1.00, green: 0.78, blue: 0.55).opacity(0.55),
            metricIconTint: Color(red: 0.78, green: 0.52, blue: 0.38),
            heroReadabilityWash: Color(red: 0.99, green: 0.97, blue: 0.94).opacity(0.72),
            heroIllustrationPrimary: Color(red: 1.00, green: 0.78, blue: 0.42),
            heroIllustrationSecondary: Color(red: 0.78, green: 0.68, blue: 0.92),
            isNightAtmosphere: false
        )
        applyCondition(to: &tokens, condition: condition, period: .dawn, modifier: modifier)
        return tokens
    }

    private static func dayTokens(
        condition: WeekFitWeatherCondition,
        modifier: ClimateModifier
    ) -> WeekFitWeatherTokens {
        var tokens = WeekFitWeatherTokens(
            backgroundPrimary: Color(red: 0.965, green: 0.958, blue: 0.945),
            backgroundSecondary: Color(red: 0.930, green: 0.948, blue: 0.970),
            heroSurface: Color(red: 0.990, green: 0.988, blue: 0.982),
            primaryAccent: Color(red: 0.95, green: 0.72, blue: 0.28),
            secondaryAccent: Color(red: 0.55, green: 0.72, blue: 0.92),
            textPrimary: Color(red: 0.165, green: 0.157, blue: 0.145),
            textSecondary: Color(red: 0.388, green: 0.388, blue: 0.400),
            cardSurface: Color(red: 0.998, green: 0.996, blue: 0.992).opacity(0.96),
            cardStroke: Color.black.opacity(0.045),
            ambientGlow: Color(red: 1.00, green: 0.88, blue: 0.55).opacity(0.45),
            metricIconTint: Color(red: 0.55, green: 0.62, blue: 0.72),
            heroReadabilityWash: Color.white.opacity(0.55),
            heroIllustrationPrimary: Color(red: 1.00, green: 0.82, blue: 0.35),
            heroIllustrationSecondary: Color(red: 0.55, green: 0.75, blue: 0.95),
            isNightAtmosphere: false
        )
        applyCondition(to: &tokens, condition: condition, period: .day, modifier: modifier)
        return tokens
    }

    private static func goldenHourTokens(
        condition: WeekFitWeatherCondition,
        modifier: ClimateModifier
    ) -> WeekFitWeatherTokens {
        var tokens = WeekFitWeatherTokens(
            backgroundPrimary: Color(red: 0.965, green: 0.935, blue: 0.910),
            backgroundSecondary: Color(red: 0.930, green: 0.910, blue: 0.945),
            heroSurface: Color(red: 0.985, green: 0.955, blue: 0.930),
            primaryAccent: Color(red: 0.90, green: 0.62, blue: 0.48),
            secondaryAccent: Color(red: 0.70, green: 0.62, blue: 0.88),
            textPrimary: Color(red: 0.20, green: 0.16, blue: 0.18),
            textSecondary: Color(red: 0.45, green: 0.38, blue: 0.40),
            cardSurface: Color(red: 0.995, green: 0.980, blue: 0.965).opacity(0.94),
            cardStroke: Color.black.opacity(0.050),
            ambientGlow: Color(red: 0.98, green: 0.72, blue: 0.55).opacity(0.42),
            metricIconTint: Color(red: 0.78, green: 0.52, blue: 0.42),
            heroReadabilityWash: Color(red: 0.99, green: 0.94, blue: 0.90).opacity(0.68),
            heroIllustrationPrimary: Color(red: 0.98, green: 0.68, blue: 0.45),
            heroIllustrationSecondary: Color(red: 0.72, green: 0.62, blue: 0.90),
            isNightAtmosphere: false
        )
        applyCondition(to: &tokens, condition: condition, period: .goldenHour, modifier: modifier)
        return tokens
    }

    private static func duskTokens(
        condition: WeekFitWeatherCondition,
        modifier: ClimateModifier
    ) -> WeekFitWeatherTokens {
        var tokens = WeekFitWeatherTokens(
            backgroundPrimary: Color(red: 0.22, green: 0.22, blue: 0.30),
            backgroundSecondary: Color(red: 0.28, green: 0.24, blue: 0.36),
            heroSurface: Color(red: 0.26, green: 0.25, blue: 0.34),
            primaryAccent: Color(red: 0.88, green: 0.68, blue: 0.78),
            secondaryAccent: Color(red: 0.58, green: 0.62, blue: 0.88),
            textPrimary: Color(red: 0.96, green: 0.95, blue: 0.97),
            textSecondary: Color(red: 0.78, green: 0.76, blue: 0.84),
            cardSurface: Color(red: 0.30, green: 0.29, blue: 0.38).opacity(0.92),
            cardStroke: Color.white.opacity(0.08),
            ambientGlow: Color(red: 0.72, green: 0.52, blue: 0.78).opacity(0.35),
            metricIconTint: Color(red: 0.82, green: 0.72, blue: 0.92),
            heroReadabilityWash: Color(red: 0.16, green: 0.15, blue: 0.24).opacity(0.55),
            heroIllustrationPrimary: Color(red: 0.92, green: 0.70, blue: 0.78),
            heroIllustrationSecondary: Color(red: 0.55, green: 0.58, blue: 0.88),
            isNightAtmosphere: true
        )
        applyCondition(to: &tokens, condition: condition, period: .dusk, modifier: modifier)
        return tokens
    }

    private static func nightTokens(
        condition: WeekFitWeatherCondition,
        modifier: ClimateModifier
    ) -> WeekFitWeatherTokens {
        var tokens = WeekFitWeatherTokens(
            backgroundPrimary: Color(red: 0.12, green: 0.13, blue: 0.18),
            backgroundSecondary: Color(red: 0.16, green: 0.18, blue: 0.28),
            heroSurface: Color(red: 0.16, green: 0.18, blue: 0.26),
            primaryAccent: Color(red: 0.72, green: 0.80, blue: 0.98),
            secondaryAccent: Color(red: 0.48, green: 0.55, blue: 0.82),
            textPrimary: Color(red: 0.95, green: 0.96, blue: 0.98),
            textSecondary: Color(red: 0.72, green: 0.76, blue: 0.86),
            cardSurface: Color(red: 0.18, green: 0.20, blue: 0.28).opacity(0.94),
            cardStroke: Color.white.opacity(0.07),
            ambientGlow: Color(red: 0.42, green: 0.52, blue: 0.88).opacity(0.40),
            metricIconTint: Color(red: 0.70, green: 0.78, blue: 0.95),
            heroReadabilityWash: Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.58),
            heroIllustrationPrimary: Color(red: 0.86, green: 0.90, blue: 1.00),
            heroIllustrationSecondary: Color(red: 0.42, green: 0.52, blue: 0.88),
            isNightAtmosphere: true
        )
        applyCondition(to: &tokens, condition: condition, period: .night, modifier: modifier)
        return tokens
    }

    // MARK: - Condition overlays

    private static func applyCondition(
        to tokens: inout WeekFitWeatherTokens,
        condition: WeekFitWeatherCondition,
        period: WeekFitWeatherPeriod,
        modifier: ClimateModifier
    ) {
        let night = period.isNightLike

        switch condition {
        case .clear:
            if night {
                tokens.backgroundPrimary = Color(red: 0.10, green: 0.12, blue: 0.22)
                tokens.backgroundSecondary = Color(red: 0.14, green: 0.16, blue: 0.30)
                tokens.ambientGlow = Color(red: 0.55, green: 0.65, blue: 0.95).opacity(0.38)
            } else {
                tokens.backgroundSecondary = Color(red: 0.90, green: 0.94, blue: 0.98)
                tokens.ambientGlow = Color(red: 1.00, green: 0.86, blue: 0.42).opacity(0.50)
            }

        case .partlyCloudy:
            tokens.primaryAccent = night
                ? Color(red: 0.78, green: 0.82, blue: 0.95)
                : Color(red: 0.70, green: 0.78, blue: 0.92)
            tokens.ambientGlow = tokens.ambientGlow.opacity(0.70)
            tokens.heroIllustrationPrimary = night
                ? Color(red: 0.82, green: 0.86, blue: 0.96)
                : Color(red: 0.95, green: 0.82, blue: 0.45)

        case .cloudy:
            if night {
                tokens.backgroundPrimary = Color(red: 0.14, green: 0.15, blue: 0.20)
                tokens.backgroundSecondary = Color(red: 0.18, green: 0.20, blue: 0.26)
                tokens.cardSurface = Color(red: 0.20, green: 0.22, blue: 0.28).opacity(0.95)
            } else {
                tokens.backgroundPrimary = Color(red: 0.940, green: 0.945, blue: 0.955)
                tokens.backgroundSecondary = Color(red: 0.900, green: 0.915, blue: 0.940)
                tokens.primaryAccent = Color(red: 0.58, green: 0.66, blue: 0.80)
                // Keep depth without going dull/gray
                tokens.ambientGlow = Color(red: 0.70, green: 0.78, blue: 0.92).opacity(0.35)
            }
            tokens.heroIllustrationPrimary = Color(red: 0.72, green: 0.78, blue: 0.88)
            tokens.heroIllustrationSecondary = Color(red: 0.52, green: 0.60, blue: 0.78)

        case .rain:
            if night {
                tokens.backgroundPrimary = Color(red: 0.10, green: 0.13, blue: 0.20)
                tokens.backgroundSecondary = Color(red: 0.14, green: 0.18, blue: 0.28)
            } else {
                tokens.backgroundPrimary = Color(red: 0.900, green: 0.920, blue: 0.945)
                tokens.backgroundSecondary = Color(red: 0.850, green: 0.890, blue: 0.940)
            }
            tokens.primaryAccent = Color(red: 0.42, green: 0.68, blue: 0.95)
            tokens.secondaryAccent = Color(red: 0.35, green: 0.55, blue: 0.82)
            tokens.ambientGlow = Color(red: 0.40, green: 0.60, blue: 0.90).opacity(0.32)
            tokens.heroIllustrationPrimary = Color(red: 0.55, green: 0.75, blue: 0.98)
            tokens.heroIllustrationSecondary = Color(red: 0.30, green: 0.48, blue: 0.82)
            tokens.metricIconTint = Color(red: 0.42, green: 0.68, blue: 0.95)

        case .storm:
            tokens.backgroundPrimary = night
                ? Color(red: 0.08, green: 0.09, blue: 0.16)
                : Color(red: 0.82, green: 0.84, blue: 0.90)
            tokens.backgroundSecondary = night
                ? Color(red: 0.14, green: 0.12, blue: 0.26)
                : Color(red: 0.72, green: 0.74, blue: 0.86)
            tokens.primaryAccent = Color(red: 0.68, green: 0.58, blue: 0.95)
            tokens.secondaryAccent = Color(red: 0.45, green: 0.40, blue: 0.82)
            tokens.ambientGlow = Color(red: 0.55, green: 0.45, blue: 0.95).opacity(0.28)
            tokens.heroIllustrationPrimary = Color(red: 0.78, green: 0.70, blue: 1.00)
            tokens.heroIllustrationSecondary = Color(red: 0.40, green: 0.32, blue: 0.82)
            if !night {
                tokens.textPrimary = Color(red: 0.16, green: 0.15, blue: 0.22)
                tokens.textSecondary = Color(red: 0.38, green: 0.36, blue: 0.46)
                tokens.cardSurface = Color(red: 0.95, green: 0.95, blue: 0.98).opacity(0.94)
                tokens.cardStroke = Color.black.opacity(0.06)
                tokens.heroReadabilityWash = Color.white.opacity(0.62)
            }

        case .snow:
            if night {
                tokens.backgroundPrimary = Color(red: 0.12, green: 0.14, blue: 0.20)
                tokens.backgroundSecondary = Color(red: 0.18, green: 0.22, blue: 0.30)
                tokens.cardSurface = Color(red: 0.20, green: 0.23, blue: 0.30).opacity(0.95)
                tokens.cardStroke = Color.white.opacity(0.10)
            } else {
                tokens.backgroundPrimary = Color(red: 0.945, green: 0.960, blue: 0.980)
                tokens.backgroundSecondary = Color(red: 0.910, green: 0.940, blue: 0.980)
                tokens.cardSurface = Color.white.opacity(0.92)
                tokens.cardStroke = Color.black.opacity(0.070)
                tokens.textPrimary = Color(red: 0.16, green: 0.18, blue: 0.24)
            }
            tokens.primaryAccent = Color(red: 0.62, green: 0.78, blue: 0.96)
            tokens.ambientGlow = Color(red: 0.85, green: 0.92, blue: 1.00).opacity(0.45)
            tokens.heroIllustrationPrimary = Color(red: 0.88, green: 0.93, blue: 1.00)
            tokens.heroIllustrationSecondary = Color(red: 0.55, green: 0.72, blue: 0.95)

        case .fog:
            if night {
                tokens.backgroundPrimary = Color(red: 0.16, green: 0.17, blue: 0.20)
                tokens.backgroundSecondary = Color(red: 0.22, green: 0.23, blue: 0.26)
            } else {
                tokens.backgroundPrimary = Color(red: 0.910, green: 0.915, blue: 0.920)
                tokens.backgroundSecondary = Color(red: 0.880, green: 0.885, blue: 0.900)
            }
            tokens.primaryAccent = Color(red: 0.62, green: 0.68, blue: 0.76)
            tokens.ambientGlow = Color.white.opacity(night ? 0.12 : 0.35)
            tokens.heroIllustrationPrimary = Color(red: 0.75, green: 0.78, blue: 0.84)
            tokens.heroIllustrationSecondary = Color(red: 0.55, green: 0.58, blue: 0.66)
            // Stronger foreground definition against muted scenery
            tokens.cardSurface = night
                ? Color(red: 0.22, green: 0.23, blue: 0.28).opacity(0.96)
                : Color.white.opacity(0.94)
            tokens.cardStroke = night ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
            tokens.heroReadabilityWash = night
                ? Color.black.opacity(0.45)
                : Color.white.opacity(0.72)

        case .windy:
            tokens.primaryAccent = Color(red: 0.55, green: 0.70, blue: 0.85)
            tokens.heroIllustrationPrimary = Color(red: 0.70, green: 0.82, blue: 0.94)
            tokens.heroIllustrationSecondary = Color(red: 0.42, green: 0.58, blue: 0.78)

        case .other:
            break
        }

        switch modifier {
        case .extremeHeat:
            tokens.primaryAccent = Color(red: 0.95, green: 0.62, blue: 0.32)
            tokens.ambientGlow = Color(red: 1.00, green: 0.82, blue: 0.45).opacity(0.48)
            tokens.backgroundSecondary = Color(red: 0.980, green: 0.945, blue: 0.900)
            // Warm daylight without aggressive red/orange overlays
            if !night {
                tokens.backgroundPrimary = Color(red: 0.975, green: 0.955, blue: 0.925)
            }

        case .veryCold:
            tokens.primaryAccent = Color(red: 0.48, green: 0.70, blue: 0.92)
            tokens.ambientGlow = Color(red: 0.70, green: 0.85, blue: 1.00).opacity(0.40)
            if !night {
                tokens.backgroundPrimary = Color(red: 0.930, green: 0.945, blue: 0.970)
                tokens.backgroundSecondary = Color(red: 0.890, green: 0.920, blue: 0.960)
            }

        case .lowVisibility:
            tokens.ambientGlow = tokens.ambientGlow.opacity(0.45)
            tokens.heroReadabilityWash = night
                ? Color.black.opacity(0.50)
                : Color.white.opacity(0.78)

        case .none:
            break
        }
    }

    private static func refine(
        _ tokens: WeekFitWeatherTokens,
        condition: WeekFitWeatherCondition,
        period: WeekFitWeatherPeriod,
        precipitationChance: Int?,
        modifier: ClimateModifier
    ) -> WeekFitWeatherTokens {
        var refined = tokens
        if condition == .rain || (precipitationChance ?? 0) >= 55 {
            refined.metricIconTint = refined.primaryAccent
        }
        if modifier == .extremeHeat {
            refined.metricIconTint = refined.primaryAccent
        }
        _ = period
        return refined
    }
}
