import Foundation
import SwiftUI

enum CoachInsightFactory {
    
    static func generateInsights(
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> [DynamicInsight] {
        
        var insights: [DynamicInsight] = []
        
        appendPrimaryStrategyInsight(
            brain: brain,
            decision: decision,
            to: &insights
        )
        
        appendSecondaryPriorityInsights(
            brain: brain,
            decision: decision,
            to: &insights
        )
        
        appendScheduleInsightIfNeeded(
            brain: brain,
            decision: decision,
            to: &insights
        )
        
        let resolved = resolveConflicts(
            insights,
            brain: brain,
            decision: decision
        )
        
        return prioritize(resolved)
    }
}

// MARK: - Primary Strategy

private extension CoachInsightFactory {
    
    static func appendPrimaryStrategyInsight(
        brain: HumanBrain.State,
        decision: CoachDecision,
        to insights: inout [DynamicInsight]
    ) {
        switch decision.primaryStrategy {
            
        case .supercompensation:
            insights.append(
                DynamicInsight(
                    icon: "flame.circle.fill",
                    title: "High Metabolic Strain Detected.",
                    text: "Your workout load created massive muscular demand today. Prioritize slow proteins and restful wind-down rituals to maximize supercompensation overnight.",
                    color: .indigo,
                    actionLabel: "Protect Recovery",
                    tags: [.recovery, .protein]
                )
            )
            
        case .logFood:
            insights.append(
                DynamicInsight(
                    icon: "fork.knife.circle.fill",
                    title: "Log your first meal.",
                    text: "Log your food so the coach can balance energy, protein and recovery from real intake.",
                    color: .green,
                    actionLabel: "Log Meal",
                    tags: [.protein, .carbs]
                )
            )
            
        case .protectRecovery:
            insights.append(
                DynamicInsight(
                    icon: "heart.text.square.fill",
                    title: "Recovery comes first.",
                    text: protectRecoveryText(
                        brain: brain,
                        decision: decision
                    ),
                    color: .indigo,
                    actionLabel: "Protect Recovery",
                    tags: tagsFromPriorities(
                        decision.secondaryPriorities,
                        fallback: [.recovery, .protein]
                    )
                )
            )
            
        case .prepareWorkout:
            guard let workout = brain.future.nextWorkout else { return }
            
            insights.append(
                DynamicInsight(
                    icon: "bolt.fill",
                    title: "Fuel the next session.",
                    text: workoutText(
                        workoutTitle: workout.title,
                        decision: decision
                    ),
                    color: .orange,
                    actionLabel: "Add Carbs",
                    tags: tagsFromPriorities(
                        decision.secondaryPriorities,
                        fallback: [.carbs]
                    )
                )
            )
            
        case .rehydrate:
            guard !decision.suppressHydrationAdvice else { return }
            
            insights.append(
                DynamicInsight(
                    icon: "drop.fill",
                    title: "Hydration is behind.",
                    text: "Hydration is behind for this point of the day. Build steady intake now instead of catching up late.",
                    color: .blue,
                    actionLabel: "+500 ml",
                    tags: [.hydration]
                )
            )
            
        case .refuel:
            insights.append(
                DynamicInsight(
                    icon: "flame.fill",
                    title: "You need fuel now.",
                    text: refuelText(
                        brain: brain,
                        decision: decision
                    ),
                    color: .orange,
                    actionLabel: "Refuel Now",
                    tags: tagsFromPriorities(
                        decision.secondaryPriorities,
                        fallback: [.protein, .carbs, .recovery]
                    )
                )
            )
            
        case .addProtein:
            insights.append(
                DynamicInsight(
                    icon: "bolt.shield.fill",
                    title: "Protein is behind.",
                    text: proteinText(
                        brain: brain,
                        decision: decision
                    ),
                    color: .purple,
                    actionLabel: "Add Protein",
                    tags: tagsFromPriorities(
                        decision.secondaryPriorities,
                        fallback: [.protein, .recovery]
                    )
                )
            )
            
        case .overload:
            insights.append(
                DynamicInsight(
                    icon: "exclamationmark.shield.fill",
                    title: "Extreme Energy Overload.",
                    text: "Your calorie and carbohydrate intake has heavily crossed the daily limits. Give your digestion a complete rest—focus strictly on clean hydration.",
                    color: .red,
                    actionLabel: "Stop Eating",
                    tags: [.digestion, .hydration]
                )
            )
     
        case .maintain:
            if decision.needsElectrolytesInsteadOfWater {
                insights.append(
                    DynamicInsight(
                        icon: "drop.triangle.fill",
                        title: "Water target is already high.",
                        text: "Plain water is already covered. Focus on minerals, protein and steady recovery instead.",
                        color: .blue,
                        actionLabel: "Add Minerals",
                        tags: [.minerals, .protein, .recovery]
                    )
                )
            } else {
                insights.append(
                    DynamicInsight(
                        icon: "waveform.path.ecg.rectangle.fill",
                        title: "Everything is moving well.",
                        text: "Your food, water, activity and recovery are aligned today. Keep this steady rhythm.",
                        color: .green,
                        actionLabel: "Stay Consistent",
                        tags: [.consistency]
                    )
                )
            }
        }
    }
    
    private static func overloadText(
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> String {
        var parts: [String] = []

        switch brain.recovery {
        case .compromised:
            parts.append("Your recovery capacity is under significant strain")
        case .vulnerable:
            parts.append("Your body is showing elevated fatigue signals")
        case .stable:
            parts.append("Recovery is stable, but load is starting to accumulate")
        case .strong:
            parts.append("Your body is handling load well, but the current load still needs support")
        }

        switch brain.sleep {
        case .veryShort:
            parts.append("very short sleep is limiting adaptation")
        case .short:
            parts.append("short sleep may reduce recovery quality")
        case .okay, .strong, .unknown:
            break
        }

        switch brain.hydration {
        case .depleted:
            parts.append("hydration is also impacting recovery")
        case .behind:
            parts.append("fluid balance is slightly behind")
        case .optimal, .completed, .excessive:
            break
        }

        switch brain.fuel {
        case .underfueled:
            parts.append("energy intake is not covering today’s load")
        case .light:
            parts.append("fuel is a bit light for the current strain")
        case .overfueled:
            parts.append("energy intake is already high, so keep the next step light")
        case .good:
            break
        }

        switch brain.strain {
        case .veryHigh:
            parts.append("activity strain is very high today")
        case .high:
            parts.append("activity strain is elevated today")
        case .normal, .low:
            break
        }

        if decision.suppressWorkoutPush {
            parts.append("so pushing intensity higher today is not recommended")
        }

        if parts.isEmpty {
            return "Your body is showing signs of accumulated load. Prioritize recovery, hydration and sleep quality today."
        }

        let first = parts.removeFirst()

        if parts.isEmpty {
            return "\(first)."
        }

        return "\(first), and \(parts.joined(separator: ", "))."
    }
}

// MARK: - Secondary Priorities

private extension CoachInsightFactory {
    
    static func appendSecondaryPriorityInsights(
        brain: HumanBrain.State,
        decision: CoachDecision,
        to insights: inout [DynamicInsight]
    ) {
        if decision.secondaryPriorities.contains(.protein) {
            appendProteinSupportInsightIfNeeded(
                brain: brain,
                decision: decision,
                to: &insights
            )
        }
        
        if decision.secondaryPriorities.contains(.carbs) {
            appendCarbSupportInsightIfNeeded(
                brain: brain,
                decision: decision,
                to: &insights
            )
        }
        
        if decision.secondaryPriorities.contains(.hydration) {
            appendHydrationSupportInsightIfNeeded(
                brain: brain,
                decision: decision,
                to: &insights
            )
        }
        
        if decision.secondaryPriorities.contains(.minerals) {
            appendMineralSupportInsightIfNeeded(
                brain: brain,
                decision: decision,
                to: &insights
            )
        }
        
        if decision.secondaryPriorities.contains(.sleep) {
            appendSleepSupportInsightIfNeeded(
                brain: brain,
                decision: decision,
                to: &insights
            )
        }
        
        appendPostWorkoutInsightIfNeeded(
            brain: brain,
            decision: decision,
            to: &insights
        )
        
        appendFatBalanceInsightIfNeeded(
            brain: brain,
            decision: decision,
            to: &insights
        )
        
        appendLateNightInsightIfNeeded(
            brain: brain,
            decision: decision,
            to: &insights
        )
    }
    
    static func appendProteinSupportInsightIfNeeded(
        brain: HumanBrain.State,
        decision: CoachDecision,
        to insights: inout [DynamicInsight]
    ) {
        guard brain.protein != .good else { return }
        guard decision.primaryStrategy != .addProtein else { return }
        guard decision.primaryStrategy != .refuel else { return }
        
        insights.append(
            DynamicInsight(
                icon: "bolt.shield.fill",
                title: "Protein can help next.",
                text: "Add protein to support repair and keep your energy more stable.",
                color: .purple,
                actionLabel: "Add Protein",
                tags: [.protein, .recovery]
            )
        )
    }
    
    static func appendCarbSupportInsightIfNeeded(
        brain: HumanBrain.State,
        decision: CoachDecision,
        to insights: inout [DynamicInsight]
    ) {
        guard decision.primaryStrategy != .prepareWorkout else { return }
        guard decision.primaryStrategy != .refuel else { return }
        guard !decision.suppressedActions.contains(.fastCarbs) else { return }
        guard brain.fuel == .underfueled || brain.fuel == .light || brain.future.hasWorkoutSoon else { return }
        
        insights.append(
            DynamicInsight(
                icon: "bolt.fill",
                title: "Easy fuel can help.",
                text: "Add simple fuel if you need steady energy, especially before activity.",
                color: .orange,
                actionLabel: "Add Carbs",
                tags: [.carbs]
            )
        )
    }
    
    static func appendHydrationSupportInsightIfNeeded(
        brain: HumanBrain.State,
        decision: CoachDecision,
        to insights: inout [DynamicInsight]
    ) {
        guard !decision.suppressHydrationAdvice else { return }
        guard decision.primaryStrategy != .rehydrate else { return }
        guard brain.hydration == .depleted || brain.hydration == .behind else { return }
        
        insights.append(
            DynamicInsight(
                icon: "drop.fill",
                title: "Hydration still matters.",
                text: "Keep fluid intake steady, but do not let it replace food or recovery support.",
                color: .blue,
                actionLabel: "+500 ml",
                tags: [.hydration]
            )
        )
    }
    
    static func appendMineralSupportInsightIfNeeded(
        brain: HumanBrain.State,
        decision: CoachDecision,
        to insights: inout [DynamicInsight]
    ) {
        guard decision.needsElectrolytesInsteadOfWater else { return }
        guard decision.primaryStrategy != .maintain else { return }
        
        insights.append(
            DynamicInsight(
                icon: "sparkles",
                title: "Choose minerals, not more water.",
                text: "Water is already covered. Mineral support is a better next step than more plain water.",
                color: .blue,
                actionLabel: "Add Minerals",
                tags: [.minerals]
            )
        )
    }
    
    static func appendSleepSupportInsightIfNeeded(
        brain: HumanBrain.State,
        decision: CoachDecision,
        to insights: inout [DynamicInsight]
    ) {
        guard brain.sleep == .short || brain.sleep == .veryShort else { return }
        guard decision.primaryStrategy != .protectRecovery else { return }
        
        insights.append(
            DynamicInsight(
                icon: "bed.double.fill",
                title: "Lower recovery capacity.",
                text: "Sleep was shorter than needed. Keep meals steady and avoid pushing workout intensity today.",
                color: .indigo,
                actionLabel: "Protect Recovery",
                tags: [.sleep, .recovery]
            )
        )
    }
    
    static func appendPostWorkoutInsightIfNeeded(
        brain: HumanBrain.State,
        decision: CoachDecision,
        to insights: inout [DynamicInsight]
    ) {
        guard brain.past.completedWorkoutsCount > 0 else { return }
        guard brain.strain == .high || brain.strain == .veryHigh else { return }
        guard decision.primaryStrategy != .refuel else { return }
        guard decision.primaryStrategy != .protectRecovery else { return }
        
        insights.append(
            DynamicInsight(
                icon: "flame.fill",
                title: "Recovery needs fuel.",
                text: "Your activity load created recovery demand. Add easy protein now.",
                color: .orange,
                actionLabel: "Refuel Now",
                tags: [.protein, .recovery]
            )
        )
    }
    
    static func appendFatBalanceInsightIfNeeded(
        brain: HumanBrain.State,
        decision: CoachDecision,
        to insights: inout [DynamicInsight]
    ) {
        guard brain.current.fatsProgress > 1.25 else { return }
        guard !decision.suppressHeavyFoodAdvice else { return }
        
        insights.append(
            DynamicInsight(
                icon: "exclamationmark.triangle.fill",
                title: "Keep next meal lighter.",
                text: "Fat intake is high today. Choose leaner foods next to keep digestion smooth.",
                color: .red,
                actionLabel: "Balance Meals",
                tags: [.digestion]
            )
        )
    }
    
    static func appendLateNightInsightIfNeeded(
        brain: HumanBrain.State,
        decision: CoachDecision,
        to insights: inout [DynamicInsight]
    ) {
        guard brain.current.isLateNight else { return }
        guard brain.profile.goal == .fatLoss else { return }
        guard decision.primaryStrategy != .protectRecovery else { return }
        
        insights.append(
            DynamicInsight(
                icon: "moon.zzz.fill",
                title: "Keep tonight lighter.",
                text: "Wind down with light recovery support. Avoid heavy meals and avoid forcing more water before sleep.",
                color: .indigo,
                actionLabel: "Wind Down",
                tags: [.sleep, .recovery, .digestion]
            )
        )
    }
    
    static func appendScheduleInsightIfNeeded(
        brain: HumanBrain.State,
        decision: CoachDecision,
        to insights: inout [DynamicInsight]
    ) {
        guard brain.past.missedItemsCount > 0 else { return }
        
        insights.append(
            DynamicInsight(
                icon: "clock.badge.exclamationmark.fill",
                title: "Update your schedule.",
                text: "Some scheduled tasks passed without updates. Mark them completed or skipped so the coach can adapt.",
                color: .orange,
                actionLabel: "Update Schedule",
                tags: [.schedule]
            )
        )
    }
}

// MARK: - Conflict Resolution

private extension CoachInsightFactory {
    
    static func resolveConflicts(
        _ insights: [DynamicInsight],
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> [DynamicInsight] {
        
        var result = insights
        
        if decision.primaryStrategy == .overload {
            result.removeAll {
                $0.actionLabel == "Add Protein" ||
                $0.actionLabel == "Add Carbs" ||
                $0.actionLabel == "Refuel Now"
            }
        }
        
        if decision.suppressHydrationAdvice {
            result.removeAll {
                isDirectWaterAdvice($0)
            }
        }
        
        if decision.suppressedActions.contains(.fastCarbs) {
            result.removeAll {
                $0.actionLabel == "Add Carbs"
            }
        }
        
        if decision.suppressWorkoutPush {
            result.removeAll {
                $0.actionLabel == "Prepare Session" ||
                ($0.actionLabel == "Add Carbs" && brain.recovery == .compromised)
            }
        }
        
        if decision.suppressHeavyFoodAdvice {
            result.removeAll {
                $0.actionLabel == "Balance Meals" ||
                $0.text.lowercased().contains("heavy meal")
            }
        }
        
        if brain.fuel == .underfueled &&
            (brain.strain == .high || brain.strain == .veryHigh) {
            result.removeAll {
                $0.actionLabel == "Hydration Done"
            }
        }
        
        result = removeDuplicateActionLabels(result)
        result = limitPrimaryConflicts(
            result,
            brain: brain,
            decision: decision
        )
        
        if result.isEmpty {
            result.append(
                fallbackInsight(
                    brain: brain,
                    decision: decision
                )
            )
        }
        
        return result
    }
    
    static func isDirectWaterAdvice(
        _ insight: DynamicInsight
    ) -> Bool {
        let text = insight.text.lowercased()
        
        return insight.actionLabel == "+500 ml" ||
        text.contains("drink water") ||
        text.contains("sip water") ||
        text.contains("more plain water")
    }
    
    static func removeDuplicateActionLabels(
        _ insights: [DynamicInsight]
    ) -> [DynamicInsight] {
        var seen = Set<String>()
        var result: [DynamicInsight] = []
        
        for insight in insights {
            guard !seen.contains(insight.actionLabel) else {
                continue
            }
            
            seen.insert(insight.actionLabel)
            result.append(insight)
        }
        
        return result
    }
    
    static func limitPrimaryConflicts(
        _ insights: [DynamicInsight],
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> [DynamicInsight] {
        let sorted = prioritize(insights)
        var result: [DynamicInsight] = []
        
        for insight in sorted {
            guard result.count < 4 else { break }
            
            if conflictsWithPrimaryStrategy(
                insight,
                brain: brain,
                decision: decision
            ) {
                continue
            }
            
            result.append(insight)
        }
        
        return result
    }
    
    static func conflictsWithPrimaryStrategy(
        _ insight: DynamicInsight,
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> Bool {
        // ✅ ИСПРАВЛЕНО: Добавлен дефолтный кейс, защищающий от ошибки компиляции компрометации перечислений
        switch decision.primaryStrategy {
            
        case .supercompensation:
            if insight.actionLabel == "Add Carbs" || insight.actionLabel == "Add Protein" || insight.actionLabel == "Refuel Now" {
                return true
            }
            
        case .protectRecovery:
            if insight.actionLabel == "Add Carbs" &&
                brain.recovery == .compromised {
                return true
            }
            
        case .prepareWorkout:
            if insight.actionLabel == "Wind Down" {
                return true
            }
            
        case .rehydrate:
            if decision.suppressHydrationAdvice &&
                insight.actionLabel == "+500 ml" {
                return true
            }
            
        case .refuel:
            if insight.actionLabel == "Hydration Done" {
                return true
            }
            
        case .maintain:
            if insight.actionLabel == "+500 ml" &&
                decision.suppressHydrationAdvice {
                return true
            }
            
        default:
            break
        }
        
        return false
    }
    
    static func fallbackInsight(
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> DynamicInsight {
        
        // ✅ ИСПРАВЛЕНО: Разделяем фолбэки по цветам и смыслу
        if decision.primaryStrategy == .overload {
            return DynamicInsight(
                icon: "exclamationmark.shield.fill",
                title: "System Rest Required",
                text: "Your current physical load is extremely high. Shift focus entirely to clean hydration and recovery pacing.",
                color: .red,
                actionLabel: "Stop Eating",
                tags: [.recovery, .hydration]
            )
        }
        
        if decision.primaryStrategy == .supercompensation {
            return DynamicInsight(
                icon: "flame.circle.fill",
                title: "High Metabolic Strain",
                text: "Your muscle workload is exceptionally high today. Focus on restful wind-down rituals and overnight recovery support.",
                color: .indigo, // Родной фиолетовый цвет инсайта
                actionLabel: "Protect Recovery",
                tags: [.recovery, .protein]
            )
        }
        
        if brain.recovery == .compromised ||
            brain.readiness == .compromised {
            return DynamicInsight(
                icon: "heart.text.square.fill",
                title: "Recovery comes first.",
                text: protectRecoveryText(
                    brain: brain,
                    decision: decision
                ),
                color: .indigo,
                actionLabel: "Protect Recovery",
                tags: [.recovery, .protein]
            )
        }
        
        if brain.fuel == .underfueled {
            return DynamicInsight(
                icon: "flame.fill",
                title: "You need fuel now.",
                text: refuelText(
                    brain: brain,
                    decision: decision
                ),
                color: .orange,
                actionLabel: "Refuel Now",
                tags: [.protein, .carbs, .recovery]
            )
        }
        
        if decision.needsElectrolytesInsteadOfWater {
            return DynamicInsight(
                icon: "drop.triangle.fill",
                title: "Water is already high.",
                text: "Slow down plain water and focus on minerals, protein and recovery.",
                color: .blue,
                actionLabel: "Add Minerals",
                tags: [.minerals, .protein]
            )
        }
        
        return DynamicInsight(
            icon: "waveform.path.ecg.rectangle.fill",
            title: "Keep the rhythm steady.",
            text: "Your coach has no urgent conflict to solve right now. Keep food, activity and recovery balanced.",
            color: .green,
            actionLabel: "Stay Consistent",
            tags: [.consistency]
        )
    }
    
    static func prioritize(
        _ insights: [DynamicInsight]
    ) -> [DynamicInsight] {
        insights.sorted {
            priority(for: $0) > priority(for: $1)
        }
    }
    
    static func priority(
        for insight: DynamicInsight
    ) -> Int {
        switch insight.actionLabel {
        case "Protect Recovery": return 130
        case "Refuel Now":       return 120
        case "Add Protein":      return 105
        case "Add Carbs":        return 95
        case "+500 ml":          return 90
        case "Log Meal":         return 88
        case "Balance Meals":    return 82
        case "Wind Down":        return 80
        case "Update Schedule":  return 70
        case "Add Minerals":     return 45
        case "Hydration Done":   return 25
        case "Stay Consistent":  return 10
        default:                 return 0
        }
    }
}

// MARK: - Copy

private extension CoachInsightFactory {
    
    static func protectRecoveryText(
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> String {
        var parts: [String] = []
        
        parts.append(recoveryReason(brain))
        
        if decision.secondaryPriorities.contains(.protein) {
            parts.append("Add protein to support repair.")
        }
        
        if decision.secondaryPriorities.contains(.hydration) &&
            !decision.suppressHydrationAdvice {
            parts.append("Keep hydration steady.")
        }
        
        if decision.secondaryPriorities.contains(.sleep) {
            parts.append("Avoid pushing intensity today.")
        }
        
        if decision.needsElectrolytesInsteadOfWater {
            parts.append("Choose minerals instead of more plain water.")
        }
        
        return parts.joined(separator: " ")
    }
    
    static func workoutText(
        workoutTitle: String,
        decision: CoachDecision
    ) -> String {
        var text = "\(workoutTitle) is coming soon. Add easy fuel for stable energy."
        
        if decision.suppressHydrationAdvice {
            text += " Hydration already looks covered."
        } else if decision.secondaryPriorities.contains(.hydration) {
            text += " Keep fluids steady."
        }
        
        return text
    }
    
    static func refuelText(
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> String {
        if brain.strain == .high || brain.strain == .veryHigh {
            return "Activity load is high and energy intake is behind. Add protein and easy carbs now, then keep intensity controlled."
        }
        
        if decision.secondaryPriorities.contains(.protein) &&
            decision.secondaryPriorities.contains(.carbs) {
            return "Nutrition is behind for this point of the day. Add protein and simple fuel to support recovery and stable energy."
        }
        
        if decision.secondaryPriorities.contains(.protein) {
            return "Energy is light, but protein is the most useful next step for recovery and stability."
        }
        
        return "Energy intake is behind today’s needs. Add a simple meal or snack now."
    }
    
    static func proteinText(
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> String {
        if decision.secondaryPriorities.contains(.recovery) {
            return "Your body would benefit from more protein now, especially for recovery and stable energy."
        }
        
        return "Add protein to your next meal to support muscle maintenance and keep energy stable."
    }
    
    static func recoveryReason(
        _ brain: HumanBrain.State
    ) -> String {
        if brain.sleep == .veryShort {
            return "Sleep was very short and your body carries extra load."
        }
        
        if brain.sleep == .short {
            return "Sleep was shorter than needed."
        }
        
        if brain.strain == .veryHigh {
            return "Your activity load is high today."
        }
        
        if brain.fuel == .underfueled {
            return "Your body needs more energy support."
        }
        
        return "Your recovery signals are under pressure."
    }
}

// MARK: - Tags, Fallback, Priority

private extension CoachInsightFactory {
    
    static func tagsFromPriorities(
        _ priorities: [CoachPriority],
        fallback: Set<CoachTag>
    ) -> Set<CoachTag> {
        var tags = Set<CoachTag>()
        
        for priority in priorities {
            switch priority {
            case .hydration: tags.insert(.hydration)
            case .protein:   tags.insert(.protein)
            case .carbs:     tags.insert(.carbs)
            case .recovery:  tags.insert(.recovery)
            case .sleep:     tags.insert(.sleep)
            case .minerals:  tags.insert(.minerals)
            case .schedule:  tags.insert(.schedule)
            }
        }
        
        return tags.isEmpty ? fallback : tags
    }
}
