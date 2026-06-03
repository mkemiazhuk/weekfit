//import Foundation
//
//enum ActivityStatus {
//    case upcoming
//    case live
//    case pendingConfirmation // Время прошло, но мы всё еще ждем пользователя
//    case completed
//    case skipped
//    case missed // Время прошло давно, задача официально провалена
//}
//
//enum ActivityStatusEvaluator {
//    
//    /// Настоящий снайперский расчет статуса для любого экрана системы
//    static func evaluate(_ activity: PlannedActivity, gracePeriodMinutes: Int = 120) -> ActivityStatus {
//        if activity.isCompleted { return .completed }
//        if activity.isSkipped { return .skipped }
//        
//        let now = Date()
//        let startTime = activity.date
//        let duration = TimeInterval(activity.durationMinutes * 60)
//        let endTime = startTime.addingTimeInterval(duration)
//        
//        // 1. Если время начала еще не пришло
//        if startTime > now {
//            return .upcoming
//        }
//        
//        // 2. Если процесс идет прямо сейчас
//        if now >= startTime && now <= endTime {
//            return .live
//        }
//        
//        // 3. Время прошло, но укладывается в окно вежливости (Grace Period)
//        let gracePeriod = TimeInterval(gracePeriodMinutes * 60)
//        let expirationTime = endTime.addingTimeInterval(gracePeriod)
//        
//        if now > endTime && now <= expirationTime {
//            return .pendingConfirmation
//        }
//        
//        // 4. Окно вежливости закрылось, пользователь проигнорировал задачу
//        return .missed
//    }
//}
