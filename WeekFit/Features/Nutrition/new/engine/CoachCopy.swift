import Foundation

enum CoachCopy {

    static func headline(
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> String {
        if !brain.hasAnyFoodLogged {
            return fastingAwareHeadline(brain: brain)
        }

        switch decision.primaryStrategy {
        case .overload:
            return "Extreme Energy Overload"

        case .supercompensation:
            return "High Metabolic Strain"

        case .protectRecovery:
            return "Recovery Under Pressure"

        case .logFood:
            return "Nutrition Data Needed"

        case .prepareWorkout:
            return "Pre-Workout Fueling"

        case .rehydrate:
            if decision.needsElectrolytesInsteadOfWater ||
                brain.hydration == .completed ||
                brain.hydration == .excessive {
                return "Minerals May Help"
            }

            return "Hydration Deficit"

        case .refuel:
            return "Energy Intake Behind"

        case .addProtein:
            return "Protein Support Needed"

        case .maintain:
            return "Balanced Day"
        }
    }

    static func summary(
        brain: HumanBrain.State,
        decision: CoachDecision,
        complianceScore: Double
    ) -> String {
        if !brain.hasAnyFoodLogged {
            return fastingAwareSummary(
                brain: brain,
                decision: decision
            )
        }

        switch decision.primaryStrategy {

        case .supercompensation:
            return "Your muscular load is exceptionally high today. Prioritize slow protein for overnight repair and avoid pushing training intensity before bed."

        case .overload:
            if brain.hydration == .completed ||
                brain.hydration == .excessive ||
                decision.suppressHydrationAdvice {
                return "Energy intake is already high and activity strain is elevated. Keep the evening light, avoid more food, and prioritize recovery."
            }

            return "Energy intake and activity strain are elevated. Keep food light, hydrate steadily, and protect recovery."

        case .protectRecovery:
            if brain.sleep == .short || brain.sleep == .veryShort {
                return "Sleep was shorter than needed and recovery signals need support. Keep intensity lower and wind down earlier."
            }

            return "Recovery needs support today. Keep activity controlled and focus on calm pacing."

        case .rehydrate:
            if decision.needsElectrolytesInsteadOfWater ||
                brain.hydration == .completed ||
                brain.hydration == .excessive {
                return "Plain water is already enough. Focus on minerals and recovery support instead of drinking more."
            }

            return "Hydration is behind for this point of the day. Build steady intake now."

        case .refuel:
            return "Your body needs fuel support after today’s load. Add a balanced recovery snack."

        case .addProtein:
            return "Protein is behind. Add protein to support repair and stable energy."

        case .prepareWorkout:
            if !brain.hasAnyFoodLogged {
                return "You have activity ahead. If you train before your first meal, keep intensity controlled and hydrate steadily."
            }

            return "You have activity ahead. Prepare with light fuel and keep intensity aligned with recovery."

        case .maintain:
            if complianceScore >= 82.0 {
                return "Food, hydration, activity and recovery are aligned. Keep the rhythm steady."
            }

            return "Your day is mostly balanced. Keep the next step simple and steady."

        case .logFood:
            return fastingAwareSummary(
                brain: brain,
                decision: decision
            )
        }
    }

    static func shortInsight(
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> String {
        if !brain.hasAnyFoodLogged {
            return fastingAwareShortInsight(
                brain: brain,
                decision: decision
            )
        }

        switch decision.primaryStrategy {

        case .overload:
            if brain.hydration == .completed ||
                brain.hydration == .excessive ||
                decision.suppressHydrationAdvice {
                return "System load is high. Avoid more food and protect recovery tonight."
            }

            return "System load is high. Keep food light, hydrate steadily, and recover."

        case .supercompensation:
            return "High workload detected. Prioritize slow protein and wind down for recovery."

        case .protectRecovery:
            return "Recovery capacity is low. Reduce workout intensity and sleep earlier tonight."

        case .rehydrate:
            if decision.needsElectrolytesInsteadOfWater ||
                brain.hydration == .completed ||
                brain.hydration == .excessive {
                return "Water is already covered. Focus on minerals and recovery support."
            }

            return "Hydration gap detected. Drink steady amounts of fluids now."

        case .refuel:
            return "Energy intake is behind your strain. Add a balanced recovery snack."

        case .addProtein:
            return "Protein target is behind. Add clean protein sources to your next meal."

        case .prepareWorkout:
            return "Upcoming activity ahead. Fuel lightly and keep intensity controlled."

        case .maintain:
            return "Your metrics are balanced. Keep maintaining this steady rhythm."

        case .logFood:
            return fastingAwareShortInsight(
                brain: brain,
                decision: decision
            )
        }
    }
}

// MARK: - Fasting-aware copy

private extension CoachCopy {

    static func fastingAwareHeadline(
        brain: HumanBrain.State
    ) -> String {
        if brain.currentHour < 11 {
            return "Morning Baseline"
        }

        if brain.currentHour < 14 {
            return "First Meal Pending"
        }

        return "Nutrition Data Needed"
    }

    static func fastingAwareSummary(
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> String {
        if brain.currentHour < 11 {
            if brain.future.hasWorkoutSoon {
                return "No food logged yet. If you train before your first meal, keep intensity controlled and hydrate steadily."
            }

            if brain.readiness == .excellent || brain.readiness == .good {
                return "Recovery looks strong this morning. Keep hydration steady and follow your normal meal timing."
            }

            return "Start light this morning. Keep hydration steady and avoid pushing intensity before your first meal."
        }

        if brain.currentHour < 14 {
            if brain.future.hasWorkoutSoon {
                return "Your first meal is still pending. With activity coming up, consider light fuel or keep intensity controlled."
            }

            return "No food logged yet. If your first meal is planned later, keep hydration steady and avoid unnecessary snacking."
        }

        return "No food logged yet. Log your first meal so Coach can balance the rest of your day."
    }

    static func fastingAwareShortInsight(
        brain: HumanBrain.State,
        decision: CoachDecision
    ) -> String {
        if brain.currentHour < 11 {
            if brain.future.hasWorkoutSoon {
                return "Morning baseline. Train light if you stay fasted."
            }

            if brain.readiness == .excellent || brain.readiness == .good {
                return "Morning baseline looks strong. Keep hydration steady."
            }

            return "Morning baseline needs care. Start light and hydrate steadily."
        }

        if brain.currentHour < 14 {
            return "First meal pending. Stay steady and avoid unnecessary snacking."
        }

        return "No food logged yet. Track your first meal to unlock better Coach guidance."
    }
}
