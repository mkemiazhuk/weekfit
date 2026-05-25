import SwiftUI

/// Структура-контракт, которая отдает в UI готовые премиум-токены для карточки Coach Insight
struct CoachInsightState {
    let icon: String
    let color: Color
    let subtitle: String
    // 👍 Добавляем ссылку на конкретную активность, которая вызвала аларм
    let missedActivity: PlannedActivity?
}

enum AICoachEngine {
    
    enum TodayPriorityKind {
        case emptyDay
        case missedActivity(PlannedActivity)
        case liveActivity(PlannedActivity)
        case sleepLow
        case hydrationLow
        case recoveryLow
        case workoutSoon(PlannedActivity)
        case mealSoon(PlannedActivity)
        case nextStep(PlannedActivity)
        case doneForToday
        case steadyRhythm
    }
    
    /// Главная точка входа: анализирует состояние дня и возвращает готовый стейт для UI
    static func evaluateSmartInsight(
        selectedDate: Date,
        activities: [PlannedActivity],
        metrics: DailyNutritionMetrics?,
        name: String
    ) -> CoachInsightState {
        
        let priority = determinePriority(selectedDate: selectedDate, activities: activities, metrics: metrics)
        
        // Извлекаем missedActivity, если движок встал на этот кейс
        var missed: PlannedActivity? = nil
        if case .missedActivity(let activity) = priority {
            missed = activity
        }
        
        return CoachInsightState(
            icon: fetchIcon(for: priority),
            color: fetchColor(for: priority),
            subtitle: fetchSubtitle(for: priority, allActivities: activities, metrics: metrics, name: name),
            missedActivity: missed // Передаем наверх в UI
        )
    }
    
    // MARK: - Internal Logic Trees
    
    private static func determinePriority(
        selectedDate: Date,
        activities: [PlannedActivity],
        metrics: DailyNutritionMetrics?
    ) -> TodayPriorityKind {
        let now = Date()
        let calendar = Calendar.current
        
        guard calendar.isDateInToday(selectedDate) else {
            if activities.isEmpty { return .emptyDay }
            if let first = activities.first(where: { !$0.isCompleted && !$0.isSkipped }) {
                return .nextStep(first)
            }
            return .doneForToday
        }
        
        if activities.isEmpty { return .emptyDay }
        
        // 1. ИСПРАВЛЕНО: Проверяем текущие активные процессы (Live) В ПЕРВУЮ ОЧЕРЕДЬ!
        // Если активность идет прямо сейчас, то это не пропуск, юзер находится внутри временного окна.
        if let liveActivity = activities.first(where: { activity in
            guard calendar.isDateInToday(activity.date) else { return false }
            let start = activity.date
            
            // Вычисляем реальный конец активности на основе её durationMinutes
            let durationInSeconds = TimeInterval(activity.durationMinutes * 60)
            let end = start.addingTimeInterval(durationInSeconds)
            
            // Мы внутри окна? (Например: 18:30 <= 18:32 и 18:32 <= 19:00)
            return now >= start && now <= end && !activity.isCompleted && !activity.isSkipped
        }) {
            // Если это мелкая рутина типа Stretching, не забиваем ею главный инсайт, даем пройти ниже.
            // Но для полноценных тренировок и еды (как Walk или Braised Chicken) — это честный Live!
            if liveActivity.title.lowercased() != "stretching" {
                return .liveActivity(liveActivity)
            }
        }
        
        // 2. ИСПРАВЛЕНО: ЖЕСТКИЙ АЛАРМ загорается ТОЛЬКО когда время активности ПОЛНОСТЬЮ истекло,
        // а подтверждения (isCompleted) или скипа (isSkipped) в базе так и не появилось.
        if let unconfirmedActivity = activities.first(where: { activity in
            guard activity.imageName != "hydration" else { return false }
            if activity.isCompleted || activity.isSkipped { return false }
            
            let durationInSeconds = TimeInterval(activity.durationMinutes * 60)
            let endTime = activity.date.addingTimeInterval(durationInSeconds)
            
            // Время полностью вышло? (Например: на часах 19:01, а конец был в 19:00)
            return now > endTime
        }) {
            return .missedActivity(unconfirmedActivity)
        }
        
        // 3. Проверяем критические биометрические дефициты
        if let metrics = metrics {
            if metrics.sleepHours > 0 && metrics.sleepHours < 6.0 { return .sleepLow }
            if metrics.waterLiters > 0 && metrics.waterLiters < 1.5 { return .hydrationLow }
        }
        
        // 4. Проверяем скорые приближающиеся события
        if let workout = activities.first(where: {
            $0.type.lowercased() == "workout" && $0.date > now &&
            $0.date <= calendar.date(byAdding: .hour, value: 3, to: now) ?? now &&
            !$0.isCompleted && !$0.isSkipped
        }) {
            return .workoutSoon(workout)
        }
        
        if let meal = activities.first(where: {
            $0.type.lowercased() == "meal" && $0.date > now &&
            $0.date <= calendar.date(byAdding: .hour, value: 2, to: now) ?? now &&
            !$0.isCompleted && !$0.isSkipped
        }) {
            return .mealSoon(meal)
        }
        
        // 5. Следующий открытый шаг по таймлайну
        if let nextActivity = activities.first(where: { $0.date > now && !$0.isCompleted && !$0.isSkipped }) {
            return .nextStep(nextActivity)
        }
        
        // 6. Всё закрыто и подтверждено
        if !activities.isEmpty && activities.allSatisfy({ $0.isCompleted || $0.isSkipped }) {
            return .doneForToday
        }
        
        return .steadyRhythm
    }
    
    private static func fetchColor(for priority: TodayPriorityKind) -> Color {
        switch priority {
        case .emptyDay:                    return Color(red: 0.55, green: 0.40, blue: 0.85)
        case .missedActivity:              return Color(red: 0.88, green: 0.30, blue: 0.26)
        case .liveActivity(let a), .workoutSoon(let a), .mealSoon(let a), .nextStep(let a): return a.color
        case .sleepLow:                    return Color(red: 0.18, green: 0.74, blue: 0.89)
        case .hydrationLow:                return Color(red: 0.25, green: 0.55, blue: 0.95)
        case .recoveryLow:                 return Color(red: 0.18, green: 0.74, blue: 0.89)
        case .doneForToday, .steadyRhythm: return Color(red: 0.16, green: 0.80, blue: 0.43)
        }
    }
    
    private static func fetchIcon(for priority: TodayPriorityKind) -> String {
        switch priority {
        case .emptyDay:       return "calendar.badge.plus"
        case .missedActivity: return "bell.fill"
        case .liveActivity:   return "play.fill"
        case .sleepLow:       return "moon.fill"
        case .hydrationLow:   return "drop.fill"
        case .recoveryLow:    return "leaf.fill"
        case .workoutSoon:    return "figure.run"
        case .mealSoon:       return "fork.knife"
        case .nextStep:       return "arrow.right"
        case .doneForToday:   return "checkmark.seal.fill"
        case .steadyRhythm:   return "sparkles"
        }
    }
    
    private static func fetchSubtitle(for priority: TodayPriorityKind, allActivities: [PlannedActivity], metrics: DailyNutritionMetrics?, name: String) -> String {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isEvening = currentHour >= 18
        let isLateNight = currentHour >= 22 || currentHour < 5
        
        // Считаем факты дня для аналитики
        let completedWorkouts = allActivities.filter { $0.type.lowercased() == "workout" && $0.isCompleted }.count
        let totalWater = metrics?.waterLiters ?? 0
        let totalCalories = metrics?.calories ?? 0
        let activeCalories = metrics?.activeCalories ?? 0
        
        switch priority {
        case .emptyDay:
            return "Add a meal, workout or recovery activity to your timeline."
            
        case .missedActivity(let activity):
            // Анализируем тип пропуска и даем рекомендацию "Что делать"
            if activity.type.lowercased() == "meal" {
                return "You missed \(activity.title). DON'T overeat on your next meal to compensate. Instead, spread the missing \(Int(activity.calories)) kcal across tomorrow's layout."
            }
            return "Activity window closed. Let's review \(activity.title.lowercased()) when you are ready to adjust your macros."
            
        case .liveActivity(let activity):
            let titleLower = activity.title.lowercased()
            
            // 🚶‍♂️ Полностью динамический инсайт для Прогулки (Walk) / Восстановления
            if titleLower.contains("walk") || activity.type.lowercased() == "recovery" {
                if totalWater < 1.5 {
                    // 👍 ИСПРАВЛЕНО: Вместо "0.8L" теперь подставляется ТЕКУЩИЙ реальный объем выпитой воды!
                    let waterString = String(format: "%.1f", totalWater)
                    return "Analyzing your day: You have only \(waterString)L of water logged with \(completedWorkouts) workouts done. Low-intensity volume will increase vascular dehydration. DO NOT wait until evening — log 350ml right now."
                }
                if activeCalories > 2000 {
                    return "Current state: Ultra-high energy expenditure today (\(Int(activeCalories)) kcal). Keep this walk strictly low-intensity. DO NOT spike your heart rate; focus on active neural drainage."
                }
                return "Cruising through your \(activity.title). Perfect opportunity to downregulate central nervous system fatigue and steady your cardiovascular matrix."
            }
            
            if activity.type.lowercased() == "workout" {
                return "Push through \(activity.title). Focus on intra-session pacing. Post-workout glycogen re-feed protocols are already staging."
            } else if activity.type.lowercased() == "meal" {
                return "Inside \(activity.title) window. Mindful chewing downregulates cortisol and spikes nutrient absorption efficiency."
            }
            return "\(activity.title) session is currently active."
            
            if activity.type.lowercased() == "workout" {
                return "Push through \(activity.title). Focus on intra-session pacing. Post-workout glycogen re-feed protocols are already staging."
            } else if activity.type.lowercased() == "meal" {
                return "Inside \(activity.title) window. Mindful chewing downregulates cortisol and spikes nutrient absorption efficiency."
            }
            return "\(activity.title) session is currently active."
            
        case .sleepLow:
            return isEvening || isLateNight ? "Severe sleep deficit detected. DO NOT engage in late-night screen time or heavy macro loading. Wind down early tonight." : "Sleep baseline is low. Restrict training volume today. Avoid high-stimulant caffeine after 14:00."
            
        case .hydrationLow:
            // Коуч анализирует нагрузку и даёт конкретную цифру
            if activeCalories > 1800 {
                return "Critical lag: You burned \(Int(activeCalories)) kcal but only drank \(String(format: "%.1f", totalWater))L. Your blood viscosity is elevated. DRINK 500ml of mineralized water within the next hour. Avoid diuretics like coffee."
            }
            return "Cellular hydration is critically lagging behind pace. Aim for steady fluid inputs toward your target ceiling."
            
        case .recoveryLow:
            return "Systemic nervous recovery is reduced. Shifting intensity downward or tactical stretching is highly advised."
            
        case .workoutSoon(let workout):
            return "Prepare for \(workout.title). Sip 300ml of hydration fuel now to prep your vascular matrix for the upcoming workload."
            
        case .mealSoon(let meal):
            return "\(meal.title) nutrition window is approaching. Ideal opportunity to stage amino assets and steady your glucose baseline."
            
        case .nextStep(let activity):
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "Next focus: \(formatter.string(from: activity.date)) • \(activity.title). Keep your momentum clean."
            
        case .doneForToday:
            if totalWater < 2.5 {
                return "Timeline cleared, but hydration failed (\(String(format: "%.1f", totalWater))L). DO NOT go to sleep dehydrated. Sip 300ml of water now to stabilize night recovery."
            }
            // 👍 Подставляем имя вместо хардкода
            return isEvening || isLateNight ? "Timeline 100% cleared! Exceptional adherence, \(name). Rest easy tonight." : "All targets crushed early. Great pacing — focus on steady active recovery blocks."
            
        case .steadyRhythm:
            if isEvening && totalCalories < 2000 {
                return "Flawless rhythm, but you are under-fueled for today's metabolic demand. Prioritize a dense protein-fat block before window closure."
            }
            return "Timeline rhythm looks flawless. Macronutrients, movement, and recovery structures are perfectly balanced."
        }
    }
}
