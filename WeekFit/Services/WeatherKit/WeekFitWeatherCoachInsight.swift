import Foundation

enum WeekFitWeatherCoachInsight {
    static func recommendation(
        for summary: WeekFitWeatherSummary,
        period: WeekFitWeatherPeriod? = nil,
        isRussian: Bool = WeekFitUsesRussianLanguage()
    ) -> String {
        let resolvedPeriod = period ?? summary.resolvedPeriod
        let tempC = summary.temperature.value
        let feelsC = summary.feelsLike.value
        let windKmh = summary.windSpeed.value
        let precipChance = summary.precipitationChance ?? 0
        let visibilityKm = summary.visibilityKilometers

        if summary.condition == .storm {
            return isRussian
                ? "Пропустите активность на улице, пока гроза не пройдёт."
                : "Skip outdoor activity until the storm has passed."
        }

        if summary.condition == .fog || (visibilityKm ?? 20) < 1.2 {
            return isRussian
                ? "Видимость низкая. Выбирайте знакомый и хорошо освещённый маршрут или перенесите тренировку в зал."
                : "Visibility is low. Choose a familiar, well-lit route or move the session indoors."
        }

        if precipChance >= 55 || summary.condition == .rain {
            return isRussian
                ? "На улице может быть некомфортно. Рассмотрите зал или подождите, пока дождь ослабнет."
                : "Outdoor activity may be uncomfortable. Consider an indoor workout or wait until the rain eases."
        }

        if summary.condition == .snow {
            return isRussian
                ? "Холодно и скользко. Сократите интенсивность и уделите внимание разминке и сцеплению."
                : "Cold and slippery. Ease intensity and prioritize warm-up and footing."
        }

        if windKmh > 40 {
            return isRussian
                ? "Сильный ветер снижает комфорт. Выбирайте более защищённые маршруты и короче интервалы."
                : "Strong wind lowers comfort. Prefer sheltered routes and shorter outdoor intervals."
        }

        if tempC >= 33 {
            return isRussian
                ? "Хорошие условия для лёгкой активности. Пейте воду заранее и избегайте самого жаркого солнца."
                : "Good conditions for light activity. Hydrate before heading out and avoid the strongest sun."
        }

        if tempC <= 0 || (feelsC <= 2 && windKmh >= 22) {
            return isRussian
                ? "Одевайтесь слоями и начните с более длинной разминки."
                : "Dress in layers and start with a longer warm-up."
        }

        if summary.uvIndex >= 8 && !resolvedPeriod.isNightLike {
            return isRussian
                ? "УФ высокий. Используйте защиту от солнца и по возможности тренируйтесь в тени."
                : "UV is high. Use sun protection and prefer shaded routes while outdoors."
        }

        if resolvedPeriod.isNightLike {
            return isRussian
                ? "Условия спокойные, но видимость ниже. Выбирайте хорошо освещённый маршрут."
                : "Conditions are calm, but visibility is lower. Choose a well-lit route."
        }

        if summary.condition == .clear && tempC > 15 && tempC < 28 && windKmh < 28 {
            return isRussian
                ? "Отличные условия для лёгкой активности на улице. Держите темп комфортным."
                : "Excellent conditions for light outdoor activity. Keep the effort comfortable."
        }

        if summary.condition == .partlyCloudy || summary.condition == .cloudy {
            return isRussian
                ? "Мягкий рассеянный свет — обычно комфортнее для тренировки на улице."
                : "Soft diffused light is usually comfortable for outdoor training."
        }

        if resolvedPeriod == .goldenHour || resolvedPeriod == .dusk {
            return isRussian
                ? "Мягкий свет и спокойные условия — хорошее окно для вечерней активности."
                : "Soft light and calm conditions — a strong window for evening activity."
        }

        return isRussian
            ? "Подстройте одежду и интенсивность под текущую температуру и ветер."
            : "Match clothing and intensity to the current temperature and wind."
    }
}
