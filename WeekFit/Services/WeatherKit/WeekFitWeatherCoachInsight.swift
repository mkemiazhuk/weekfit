import Foundation

enum WeekFitWeatherCoachInsight {
    static func recommendation(
        for summary: WeekFitWeatherSummary,
        period: WeekFitWeatherPeriod? = nil,
        isRussian: Bool = WeekFitUsesRussianLanguage()
    ) -> String {
        _ = isRussian
        let resolvedPeriod = period ?? summary.resolvedPeriod
        let tempC = summary.temperature.value
        let feelsC = summary.feelsLike.value
        let windKmh = summary.windSpeed.value
        let precipChance = summary.precipitationChance ?? 0
        let visibilityKm = summary.visibilityKilometers

        if summary.condition == .storm {
            return WeekFitTrilingual(
                "Skip outdoor activity until the storm has passed.",
                "Пропустите активность на улице, пока гроза не пройдёт.",
                "等雷暴过去后再进行户外活动。"
            )
        }

        if summary.condition == .fog || (visibilityKm ?? 20) < 1.2 {
            return WeekFitTrilingual(
                "Visibility is low. Choose a familiar, well-lit route or move the session indoors.",
                "Видимость низкая. Выбирайте знакомый и хорошо освещённый маршрут или перенесите тренировку в зал.",
                "能见度较低。选择熟悉、照明良好的路线，或改为室内训练。"
            )
        }

        if precipChance >= 55 || summary.condition == .rain {
            return WeekFitTrilingual(
                "Outdoor activity may be uncomfortable. Consider an indoor workout or wait until the rain eases.",
                "На улице может быть некомфортно. Рассмотрите зал или подождите, пока дождь ослабнет.",
                "户外可能不太舒适。可考虑室内训练，或等雨势减弱。"
            )
        }

        if summary.condition == .snow {
            return WeekFitTrilingual(
                "Cold and slippery. Ease intensity and prioritize warm-up and footing.",
                "Холодно и скользко. Сократите интенсивность и уделите внимание разминке и сцеплению.",
                "又冷又滑。降低强度，重视热身与脚下抓地。"
            )
        }

        if windKmh > 40 {
            return WeekFitTrilingual(
                "Strong wind lowers comfort. Prefer sheltered routes and shorter outdoor intervals.",
                "Сильный ветер снижает комфорт. Выбирайте более защищённые маршруты и короче интервалы.",
                "大风会降低舒适度。优先选避风路线，并缩短户外间歇。"
            )
        }

        if tempC >= 33 {
            return WeekFitTrilingual(
                "Good conditions for light activity. Hydrate before heading out and avoid the strongest sun.",
                "Хорошие условия для лёгкой активности. Пейте воду заранее и избегайте самого жаркого солнца.",
                "适合轻度活动。出门前补水，并避开最烈的阳光。"
            )
        }

        if tempC <= 0 || (feelsC <= 2 && windKmh >= 22) {
            return WeekFitTrilingual(
                "Dress in layers and start with a longer warm-up.",
                "Одевайтесь слоями и начните с более длинной разминки.",
                "分层穿衣，并做更充分的热身。"
            )
        }

        if summary.uvIndex >= 8 && !resolvedPeriod.isNightLike {
            return WeekFitTrilingual(
                "UV is high. Use sun protection and prefer shaded routes while outdoors.",
                "УФ высокий. Используйте защиту от солнца и по возможности тренируйтесь в тени.",
                "紫外线偏高。做好防晒，户外尽量选阴凉路线。"
            )
        }

        if resolvedPeriod.isNightLike {
            return WeekFitTrilingual(
                "Conditions are calm, but visibility is lower. Choose a well-lit route.",
                "Условия спокойные, но видимость ниже. Выбирайте хорошо освещённый маршрут.",
                "条件平稳，但能见度较低。选择照明良好的路线。"
            )
        }

        if summary.condition == .clear && tempC > 15 && tempC < 28 && windKmh < 28 {
            return WeekFitTrilingual(
                "Excellent conditions for light outdoor activity. Keep the effort comfortable.",
                "Отличные условия для лёгкой активности на улице. Держите темп комфортным.",
                "很适合轻度户外活动。把强度保持在舒适范围。"
            )
        }

        if summary.condition == .partlyCloudy || summary.condition == .cloudy {
            return WeekFitTrilingual(
                "Soft diffused light is usually comfortable for outdoor training.",
                "Мягкий рассеянный свет — обычно комфортнее для тренировки на улице.",
                "柔和散射光通常更适合户外训练。"
            )
        }

        if resolvedPeriod == .goldenHour || resolvedPeriod == .dusk {
            return WeekFitTrilingual(
                "Soft light and calm conditions — a strong window for evening activity.",
                "Мягкий свет и спокойные условия — хорошее окно для вечерней активности.",
                "光线柔和、条件平稳——晚间活动的好时机。"
            )
        }

        return WeekFitTrilingual(
            "Match clothing and intensity to the current temperature and wind.",
            "Подстройте одежду и интенсивность под текущую температуру и ветер.",
            "根据当前气温和风力调整穿着与强度。"
        )
    }
}
