import Foundation

/// Compact relevance badge + short contextual sentence for the Weather hero.
enum WeekFitWeatherRelevance {

    struct Content: Equatable, Sendable {
        let badge: String
        let contextSentence: String
    }

    static func content(
        for summary: WeekFitWeatherSummary,
        period: WeekFitWeatherPeriod
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
                badge: WeekFitTrilingual("Stay indoors for now", "Останьтесь в помещении", "暂时留在室内"),
                contextSentence: WeekFitTrilingual(
                    "Thunderstorm conditions make outdoor activity unsafe.",
                    "Гроза делает уличную активность небезопасной.",
                    "雷暴天气下户外活动不安全。"
                )
            )
        }

        if condition == .fog || (visibilityKm ?? 20) < 1.2 {
            return Content(
                badge: WeekFitTrilingual("Poor visibility right now", "Плохая видимость", "当前能见度较差"),
                contextSentence: WeekFitTrilingual(
                    "Fog is reducing visibility — stick to familiar, well-lit routes.",
                    "Туман снижает видимость — выбирайте знакомые и освещённые маршруты.",
                    "大雾影响能见度——选择熟悉、照明良好的路线。"
                )
            )
        }

        if precip >= 55 || condition == .rain {
            return Content(
                badge: WeekFitTrilingual("Rain expected soon", "Скоро возможен дождь", "即将下雨"),
                contextSentence: WeekFitTrilingual(
                    "Precipitation may make outdoor training less comfortable.",
                    "Осадки могут сделать уличную тренировку менее комфортной.",
                    "降雨可能让户外训练不太舒适。"
                )
            )
        }

        if condition == .snow {
            return Content(
                badge: WeekFitTrilingual("Slippery outdoor surfaces", "Скользко на улице", "室外路面湿滑"),
                contextSentence: WeekFitTrilingual(
                    "Snow and cold surfaces need extra care outdoors.",
                    "Снег и холод требуют осторожности на улице.",
                    "冰雪与低温路面需格外小心。"
                )
            )
        }

        if tempC >= 33 {
            return Content(
                badge: WeekFitTrilingual("Extreme heat outside", "Сильная жара", "户外酷热"),
                contextSentence: WeekFitTrilingual(
                    "Heat raises perceived effort — hydrate and ease intensity.",
                    "Жара повышает нагрузку — пейте воду и снижайте интенсивность.",
                    "炎热会提高主观强度——注意补水并降低强度。"
                )
            )
        }

        if summary.uvIndex >= 8 && !period.isNightLike {
            return Content(
                badge: WeekFitTrilingual("High UV until later", "Высокий УФ сегодня", "紫外线偏高"),
                contextSentence: WeekFitTrilingual(
                    "Strong sun through the afternoon — use protection and shade.",
                    "Сильное солнце до вечера — используйте защиту и тень.",
                    "午后阳光强烈——做好防晒并尽量待在阴凉处。"
                )
            )
        }

        if tempC <= 0 || (feelsC <= 2 && windKmh >= 25) {
            return Content(
                badge: WeekFitTrilingual("Cold and windy outside", "Холодно и ветрено", "外面又冷又有风"),
                contextSentence: WeekFitTrilingual(
                    "Wind makes it feel colder — dress in layers.",
                    "Ощущается холоднее из‑за ветра — одевайтесь слоями.",
                    "风会让体感更冷——请分层穿衣。"
                )
            )
        }

        if windKmh >= 40 {
            return Content(
                badge: WeekFitTrilingual("Strong wind outside", "Сильный ветер", "外面风很大"),
                contextSentence: WeekFitTrilingual(
                    "Wind reduces comfort on open outdoor routes.",
                    "Ветер снижает комфорт на открытых маршрутах.",
                    "开阔路线上风会降低舒适度。"
                )
            )
        }

        if period == .night && condition == .clear {
            return Content(
                badge: WeekFitTrilingual("Clear night skies", "Ясная ночь", "夜空晴朗"),
                contextSentence: WeekFitTrilingual(
                    "Calm conditions, but visibility is lower — choose a well-lit route.",
                    "Спокойные условия, но видимость ниже — выбирайте освещённый маршрут.",
                    "条件平稳，但能见度较低——选择照明良好的路线。"
                )
            )
        }

        if period == .goldenHour || period == .dusk {
            if tempC >= 12 && tempC <= 26 && precip < 30 {
                return Content(
                    badge: WeekFitTrilingual("Good for an evening run", "Хорошо для вечернего бега", "适合晚间跑步"),
                    contextSentence: WeekFitTrilingual(
                        "Soft light and comfortable temperatures for outdoor activity.",
                        "Мягкий свет и комфортная температура для активности на улице.",
                        "光线柔和、气温舒适，适合户外活动。"
                    )
                )
            }
        }

        if condition == .clear && tempC >= 14 && tempC <= 26 && windKmh < 25 && precip < 30 {
            return Content(
                badge: WeekFitTrilingual("Perfect for an outdoor walk", "Идеально для прогулки", "很适合户外散步"),
                contextSentence: WeekFitTrilingual(
                    "Clear and comfortable — a great moment to get outside.",
                    "Ясно и комфортно — отличный момент выйти на улицу.",
                    "晴朗舒适——很适合出门。"
                )
            )
        }

        if condition == .partlyCloudy || condition == .cloudy {
            return Content(
                badge: WeekFitTrilingual("Comfortable outdoor conditions", "Мягкие условия", "户外条件舒适"),
                contextSentence: WeekFitTrilingual(
                    "Diffused light often feels more comfortable for training.",
                    "Рассеянный свет обычно комфортнее для тренировки.",
                    "散射光通常更适合训练。"
                )
            )
        }

        if period == .dawn {
            return Content(
                badge: WeekFitTrilingual("Calm morning conditions", "Спокойное утро", "清晨条件平稳"),
                contextSentence: WeekFitTrilingual(
                    "Soft dawn light — a good window for light activity.",
                    "Мягкий свет рассвета — хорошее время для лёгкой активности.",
                    "柔和晨光——轻度活动的好时机。"
                )
            )
        }

        return Content(
            badge: WeekFitTrilingual("Outdoor conditions now", "Условия на улице", "当前户外状况"),
            contextSentence: WeekFitTrilingual(
                "Factor temperature and wind into how you train today.",
                "Учитывайте температуру и ветер, выбирая формат тренировки.",
                "今天训练时，把气温和风力考虑进去。"
            )
        )
    }
}
