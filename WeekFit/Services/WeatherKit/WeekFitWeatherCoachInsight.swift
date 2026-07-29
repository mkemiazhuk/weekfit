import Foundation

enum WeekFitWeatherCoachInsight {
    static func recommendation(for summary: WeekFitWeatherSummary, isRussian: Bool = WeekFitUsesRussianLanguage()) -> String {
        let tempC = summary.temperature.value // canonical
        let windKmh = summary.windSpeed.value // canonical
        let precipChance = summary.precipitationChance ?? 0

        if precipChance >= 60 {
            return isRussian
                ? "Возможны осадки позже сегодня. Если планировали тренировку на улице, рассмотрите более раннее время или зал."
                : "Rain is expected later today. If you planned an outdoor workout, consider moving it earlier or switching indoors."
        }

        if summary.condition == .storm {
            return isRussian
                ? "Ожидаются грозовые условия. Рассмотрите занятие в помещении и уделите внимание безопасности."
                : "Storm conditions are possible. Consider an indoor session and use caution."
        }

        if windKmh > 40 {
            return isRussian
                ? "Ветер может быть сильным и сделать пробежки или велотренировки менее комфортными. Выбирайте более защищённые маршруты."
                : "Wind conditions may make cycling less comfortable today. Choose sheltered routes."
        }

        if tempC > 33 {
            return isRussian
                ? "Тепло может повысить воспринимаемую нагрузку. Сделайте сессию полегче и уделите внимание гидратации."
                : "Warm conditions may increase perceived effort. Consider an easier outdoor session and hydrate well."
        }

        if tempC < 0 {
            return isRussian
                ? "Прохладно — не забудьте тщательную разминку и слой за слоем. Так вам будет комфортнее."
                : "Cool conditions can feel sharper. Warm up thoroughly and dress in layers."
        }

        if summary.uvIndex >= 8 {
            return isRussian
                ? "УФ-индекс высокий. Используйте солнцезащитный крем и по возможности тренируйтесь в тени."
                : "Very high UV. Wear sunscreen and prefer shaded routes for outdoor training."
        }

        if summary.condition == .clear && tempC > 15 && tempC < 28 {
            return isRussian
                ? "Отличные условия для тренировки на свежем воздухе. Хорошей сессии!"
                : "Excellent conditions for outdoor training. Enjoy your session."
        }

        if summary.condition == .cloudy {
            return isRussian
                ? "Облачная погода — обычно комфортнее для тренировки."
                : "Overcast skies can be comfortable for training, with less glare."
        }

        return isRussian
            ? "Перед выходом проверьте погодные условия и выбирайте одежду по погоде."
            : "Check conditions before heading out and dress accordingly."
    }
}

