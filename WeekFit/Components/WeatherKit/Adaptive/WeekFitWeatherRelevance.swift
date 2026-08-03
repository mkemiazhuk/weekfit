import Foundation

/// Compact relevance badge + short contextual sentence for the Weather hero.
enum WeekFitWeatherRelevance {

    struct Content: Equatable, Sendable {
        let badge: String
        let contextSentence: String
    }

    static func content(
        for summary: WeekFitWeatherSummary,
        period: WeekFitWeatherPeriod,
        isRussian: Bool = WeekFitUsesRussianLanguage()
    ) -> Content {
        let tempC = summary.temperature.value
        let feelsC = summary.feelsLike.value
        let windKmh = summary.windSpeed.value
        let precip = summary.precipitationChance ?? 0
        let visibilityKm = summary.visibilityKilometers
        let condition = summary.condition

        // Priority order: safety / severity first, then opportunity.
        if condition == .storm {
            return Content(
                badge: isRussian ? "Останьтесь в помещении" : "Stay indoors for now",
                contextSentence: isRussian
                    ? "Гроза делает уличную активность небезопасной."
                    : "Thunderstorm conditions make outdoor activity unsafe."
            )
        }

        if condition == .fog || (visibilityKm ?? 20) < 1.2 {
            return Content(
                badge: isRussian ? "Плохая видимость" : "Poor visibility right now",
                contextSentence: isRussian
                    ? "Туман снижает видимость — выбирайте знакомые и освещённые маршруты."
                    : "Fog is reducing visibility — stick to familiar, well-lit routes."
            )
        }

        if precip >= 55 || condition == .rain {
            return Content(
                badge: isRussian ? "Скоро возможен дождь" : "Rain expected soon",
                contextSentence: isRussian
                    ? "Осадки могут сделать уличную тренировку менее комфортной."
                    : "Precipitation may make outdoor training less comfortable."
            )
        }

        if condition == .snow {
            return Content(
                badge: isRussian ? "Скользко на улице" : "Slippery outdoor surfaces",
                contextSentence: isRussian
                    ? "Снег и холод требуют осторожности на улице."
                    : "Snow and cold surfaces need extra care outdoors."
            )
        }

        if tempC >= 33 {
            return Content(
                badge: isRussian ? "Сильная жара" : "Extreme heat outside",
                contextSentence: isRussian
                    ? "Жара повышает нагрузку — пейте воду и снижайте интенсивность."
                    : "Heat raises perceived effort — hydrate and ease intensity."
            )
        }

        if summary.uvIndex >= 8 && !period.isNightLike {
            return Content(
                badge: isRussian ? "Высокий УФ сегодня" : "High UV until later",
                contextSentence: isRussian
                    ? "Сильное солнце до вечера — используйте защиту и тень."
                    : "Strong sun through the afternoon — use protection and shade."
            )
        }

        if tempC <= 0 || (feelsC <= 2 && windKmh >= 25) {
            return Content(
                badge: isRussian ? "Холодно и ветрено" : "Cold and windy outside",
                contextSentence: isRussian
                    ? "Ощущается холоднее из‑за ветра — одевайтесь слоями."
                    : "Wind makes it feel colder — dress in layers."
            )
        }

        if windKmh >= 40 {
            return Content(
                badge: isRussian ? "Сильный ветер" : "Strong wind outside",
                contextSentence: isRussian
                    ? "Ветер снижает комфорт на открытых маршрутах."
                    : "Wind reduces comfort on open outdoor routes."
            )
        }

        if period == .night && condition == .clear {
            return Content(
                badge: isRussian ? "Ясная ночь" : "Clear night skies",
                contextSentence: isRussian
                    ? "Спокойные условия, но видимость ниже — выбирайте освещённый маршрут."
                    : "Calm conditions, but visibility is lower — choose a well-lit route."
            )
        }

        if period == .goldenHour || period == .dusk {
            if tempC >= 12 && tempC <= 26 && precip < 30 {
                return Content(
                    badge: isRussian ? "Хорошо для вечернего бега" : "Good for an evening run",
                    contextSentence: isRussian
                        ? "Мягкий свет и комфортная температура для активности на улице."
                        : "Soft light and comfortable temperatures for outdoor activity."
                )
            }
        }

        if condition == .clear && tempC >= 14 && tempC <= 26 && windKmh < 25 && precip < 30 {
            return Content(
                badge: isRussian ? "Идеально для прогулки" : "Perfect for an outdoor walk",
                contextSentence: isRussian
                    ? "Ясно и комфортно — отличный момент выйти на улицу."
                    : "Clear and comfortable — a great moment to get outside."
            )
        }

        if condition == .partlyCloudy || condition == .cloudy {
            return Content(
                badge: isRussian ? "Мягкие условия" : "Comfortable outdoor conditions",
                contextSentence: isRussian
                    ? "Рассеянный свет обычно комфортнее для тренировки."
                    : "Diffused light often feels more comfortable for training."
            )
        }

        if period == .dawn {
            return Content(
                badge: isRussian ? "Спокойное утро" : "Calm morning conditions",
                contextSentence: isRussian
                    ? "Мягкий свет рассвета — хорошее время для лёгкой активности."
                    : "Soft dawn light — a good window for light activity."
            )
        }

        return Content(
            badge: isRussian ? "Условия на улице" : "Outdoor conditions now",
            contextSentence: isRussian
                ? "Учитывайте температуру и ветер, выбирая формат тренировки."
                : "Factor temperature and wind into how you train today."
        )
    }
}
