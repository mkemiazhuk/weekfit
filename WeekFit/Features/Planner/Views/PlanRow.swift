import SwiftUI

struct PlanRow: View {
    let activity: PlannedActivity
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: activity.date)
    }
    
    private var subtitleString: String {
        let typeLower = activity.type.lowercased()
        if typeLower == "food" || activity.calories > 0 {
            return String(format: WeekFitLocalizedString("planner.activitySubtitle.mealCaloriesFormat"), activity.calories)
        } else {
            return String(format: WeekFitLocalizedString("planner.duration.summaryFormat"), activity.durationMinutes)
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            
            // MARK: - Левая колонка: Таймлайн
            HStack(spacing: 0) {
                // Время
                Text(timeString)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.gray.opacity(0.8))
                    .frame(width: 46, alignment: .leading)
                
                // Линия и точка
                ZStack {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(WeekFitTheme.whiteOpacity(0.08))
                            .frame(width: 1.5)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    
                    Circle()
                        .fill(activity.color)
                        .frame(width: 7, height: 7)
                }
                .frame(width: 24)
            }
            .frame(maxHeight: .infinity) // Растягивает линию на всю высоту карточки
            
            // MARK: - Правая колонка: Карточка
            HStack(spacing: 12) {
                // Иконка
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(WeekFitTheme.whiteOpacity(0.03))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: activity.icon.isEmpty ? "sparkles" : activity.icon)
                        .font(.system(size: 18))
                        .foregroundColor(activity.color)
                }
                
                // Текст
                VStack(alignment: .leading, spacing: 3) {
                    Text(PlannerOptionLocalization.localizedTitle(for: activity.title))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(subtitleString)
                        .font(.system(size: 13))
                        .foregroundColor(Color.gray.opacity(0.7))
                }
                
                Spacer()
                
                // Статус "Logged"
                if activity.isCompleted {
                    Text(WeekFitLocalizedString("planner.logged"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.44, green: 0.77, blue: 0.53))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.44, green: 0.77, blue: 0.53).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(red: 0.07, green: 0.08, blue: 0.09)) // Очень темный серый
            .cornerRadius(16)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 16)
        // Фиксируем высоту строки, чтобы линия таймлайна стыковалась без зазоров
        .frame(height: 76)
    }
}
