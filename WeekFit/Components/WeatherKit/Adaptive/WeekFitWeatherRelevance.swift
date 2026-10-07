import Foundation

/// Compact relevance badge + short contextual sentence for the Weather hero.
enum WeekFitWeatherRelevance {

    struct Content: Equatable, Sendable {
        let badge: String
        let contextSentence: String
    }


    private static func t(_ english: String, _ russian: String, _ chinese: String, isRussian: Bool) -> String {
        if WeekFitUsesChineseSimplifiedLanguage() { return chinese }
        return isRussian ? russian : english
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
                badge: t("Stay indoors for now", "Останьтесь в помещении", "暂时留在室内", isRussian: isRussian),
                contextSentence: t("Thunderstorm conditions make outdoor activity unsafe.", "Гроза делает уличную активность небезопасной.", "雷暴天气下户外活动不安全。", isRussian: isRussian)
            )
        }

        if condition == .fog || (visibilityKm ?? 20) < 1.2 {
            return Content(
                badge: t("Poor visibility right now", "Плохая видимость", "当前能见度较差", isRussian: isRussian),
                contextSentence: t("Fog is reducing visibility — stick to familiar, well-lit routes.", "Туман снижает видимость — выбирайте знакомые и освещённые маршруты.", "大雾影响能见度——选择熟悉、照明良好的路线。", isRussian: isRussian)
            )
        }

        if precip >= 55 || condition == .rain {
            return Content(
                badge: t("Rain expected soon", "Скоро возможен дождь", "即将下雨", isRussian: isRussian),
                contextSentence: t("Precipitation may make outdoor training less comfortable.", "Осадки могут сделать уличную тренировку менее комфортной.", "降雨可能让户外训练不太舒适。", isRussian: isRussian)
            )
        }

        if condition == .snow {
            return Content(
                badge: t("Slippery outdoor surfaces", "Скользко на улице", "室外路面湿滑", isRussian: isRussian),
                contextSentence: t("Snow and cold surfaces need extra care outdoors.", "Снег и холод требуют осторожности на улице.", "冰雪与低温路面需格外小心。", isRussian: isRussian)
            )
        }

        if tempC >= 33 {
            return Content(
                badge: t("Extreme heat outside", "Сильная жара", "户外酷热", isRussian: isRussian),
                contextSentence: t("Heat raises perceived effort — hydrate and ease intensity.", "Жара повышает нагрузку — пейте воду и снижайте интенсивность.", "炎热会提高主观强度——注意补水并降低强度。", isRussian: isRussian)
            )
        }

        if summary.uvIndex >= 8 && !period.isNightLike {
            return Content(
                badge: t("High UV until later", "Высокий УФ сегодня", "紫外线偏高", isRussian: isRussian),
                contextSentence: t("Strong sun through the afternoon — use protection and shade.", "Сильное солнце до вечера — используйте защиту и тень.", "午后阳光强烈——做好防晒并尽量待在阴凉处。", isRussian: isRussian)
            )
        }

        if tempC <= 0 || (feelsC <= 2 && windKmh >= 25) {
            return Content(
                badge: t("Cold and windy outside", "Холодно и ветрено", "外面又冷又有风", isRussian: isRussian),
                contextSentence: t("Wind makes it feel colder — dress in layers.", "Ощущается холоднее из‑за ветра — одевайтесь слоями.", "风会让体感更冷——请分层穿衣。", isRussian: isRussian)
            )
        }

        if windKmh >= 40 {
            return Content(
                badge: t("Strong wind outside", "Сильный ветер", "外面风很大", isRussian: isRussian),
                contextSentence: t("Wind reduces comfort on open outdoor routes.", "Ветер снижает комфорт на открытых маршрутах.", "开阔路线上风会降低舒适度。", isRussian: isRussian)
            )
        }

        if period == .night && condition == .clear {
            return Content(
                badge: t("Clear night skies", "Ясная ночь", "夜空晴朗", isRussian: isRussian),
                contextSentence: t("Calm conditions, but visibility is lower — choose a well-lit route.", "Спокойные условия, но видимость ниже — выбирайте освещённый маршрут.", "条件平稳，但能见度较低——选择照明良好的路线。", isRussian: isRussian)
            )
        }

        if period == .goldenHour || period == .dusk {
            if tempC >= 12 && tempC <= 26 && precip < 30 {
                return Content(
                    badge: t("Good for an evening run", "Хорошо для вечернего бега", "适合晚间跑步", isRussian: isRussian),
                    contextSentence: t("Soft light and comfortable temperatures for outdoor activity.", "Мягкий свет и комфортная температура для активности на улице.", "光线柔和、气温舒适，适合户外活动。", isRussian: isRussian)
                )
            }
        }

        if condition == .clear && tempC >= 14 && tempC <= 26 && windKmh < 25 && precip < 30 {
            return Content(
                badge: t("Perfect for an outdoor walk", "Идеально для прогулки", "很适合户外散步", isRussian: isRussian),
                contextSentence: t("Clear and comfortable — a great moment to get outside.", "Ясно и комфортно — отличный момент выйти на улицу.", "晴朗舒适——很适合出门。", isRussian: isRussian)
            )
        }

        if condition == .partlyCloudy || condition == .cloudy {
            return Content(
                badge: t("Comfortable outdoor conditions", "Мягкие условия", "户外条件舒适", isRussian: isRussian),
                contextSentence: t("Diffused light often feels more comfortable for training.", "Рассеянный свет обычно комфортнее для тренировки.", "散射光通常更适合训练。", isRussian: isRussian)
            )
        }

        if period == .dawn {
            return Content(
                badge: t("Calm morning conditions", "Спокойное утро", "清晨条件平稳", isRussian: isRussian),
                contextSentence: t("Soft dawn light — a good window for light activity.", "Мягкий свет рассвета — хорошее время для лёгкой активности.", "柔和晨光——轻度活动的好时机。", isRussian: isRussian)
            )
        }

        return Content(
            badge: t("Outdoor conditions now", "Условия на улице", "当前户外状况", isRussian: isRussian),
            contextSentence: t("Factor temperature and wind into how you train today.", "Учитывайте температуру и ветер, выбирая формат тренировки.", "今天训练时，把气温和风力考虑进去。", isRussian: isRussian)
        )
    }
}
