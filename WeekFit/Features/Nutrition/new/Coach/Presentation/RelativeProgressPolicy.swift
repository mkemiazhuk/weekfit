import Foundation

/// Presentation-only nutrition pace — avoids false «behind» Why rows when the day still has room.
enum RelativeProgressPolicy {

    struct Evaluation: Equatable, Sendable {
        let hydrationRelativelyBehind: Bool
        let fuelRelativelyBehind: Bool
        let shouldSurfaceHydrationWhyRow: Bool
        let shouldSurfaceFuelWhyRow: Bool
    }

    static func evaluate(input: CoachCopyBuildInput) -> Evaluation {
        let paceHydrationBehind = input.modifiers.hydrationBehind || input.hydrationState.isBehind
        let paceFuelBehind = input.modifiers.fuelBehind || input.fuelState.isBehind
        let hydrationCritical = input.hydrationState == .critical || input.safetyAlert == .hydrationCritical
        let fuelCritical = input.fuelState == .critical || input.safetyAlert == .fuelCritical
        let horizon = input.presentationHorizon

        let hydrationBehind = relativelyBehindForPresentation(
            paceBehind: paceHydrationBehind,
            isCritical: hydrationCritical,
            horizon: horizon
        )
        let fuelBehind = relativelyBehindForPresentation(
            paceBehind: paceFuelBehind,
            isCritical: fuelCritical,
            horizon: horizon
        )

        return Evaluation(
            hydrationRelativelyBehind: hydrationBehind,
            fuelRelativelyBehind: fuelBehind,
            shouldSurfaceHydrationWhyRow: shouldSurfaceHydrationWhyRow(
                paceBehind: paceHydrationBehind,
                relativelyBehind: hydrationBehind,
                isCritical: hydrationCritical,
                horizon: horizon,
                dehydrationRisk: input.dehydrationRisk
            ),
            shouldSurfaceFuelWhyRow: shouldSurfaceFuelWhyRow(
                paceBehind: paceFuelBehind,
                relativelyBehind: fuelBehind,
                isCritical: fuelCritical,
                horizon: horizon,
                mealWindowOpen: input.mealWindowOpen
            )
        )
    }

    static func evaluate(
        nutrition: CoachNutritionContext,
        hour: Int,
        horizon: CoachPresentationHorizon,
        activityFamily: CoachActivityFamily = .recovery,
        durationBand: CoachDurationBand = .short,
        activityState: CoachActivityState = .upcoming,
        mealWindowOpen: Bool = true,
        dehydrationRisk: Bool = false
    ) -> Evaluation {
        let hydrationState = CoachNutritionPace.hydrationState(
            nutrition: nutrition,
            hour: hour,
            activityFamily: activityFamily,
            durationBand: durationBand,
            activityState: activityState
        )
        let fuelState = CoachNutritionPace.fuelState(
            nutrition: nutrition,
            hour: hour,
            activityFamily: activityFamily,
            durationBand: durationBand
        )

        let paceHydrationBehind = hydrationState.isBehind || hydrationState == .critical
        let paceFuelBehind = fuelState.isBehind || fuelState == .critical
        let hydrationCritical = hydrationState == .critical
        let fuelCritical = fuelState == .critical

        let hydrationBehind = relativelyBehindForPresentation(
            paceBehind: paceHydrationBehind,
            isCritical: hydrationCritical,
            horizon: horizon
        )
        let fuelBehind = relativelyBehindForPresentation(
            paceBehind: paceFuelBehind,
            isCritical: fuelCritical,
            horizon: horizon
        )

        return Evaluation(
            hydrationRelativelyBehind: hydrationBehind,
            fuelRelativelyBehind: fuelBehind,
            shouldSurfaceHydrationWhyRow: shouldSurfaceHydrationWhyRow(
                paceBehind: paceHydrationBehind,
                relativelyBehind: hydrationBehind,
                isCritical: hydrationCritical,
                horizon: horizon,
                dehydrationRisk: dehydrationRisk
            ),
            shouldSurfaceFuelWhyRow: shouldSurfaceFuelWhyRow(
                paceBehind: paceFuelBehind,
                relativelyBehind: fuelBehind,
                isCritical: fuelCritical,
                horizon: horizon,
                mealWindowOpen: mealWindowOpen
            )
        )
    }

    // MARK: - Private

    private static func relativelyBehindForPresentation(
        paceBehind: Bool,
        isCritical: Bool,
        horizon: CoachPresentationHorizon
    ) -> Bool {
        guard paceBehind || isCritical else { return false }
        if horizon == .nextHours { return false }
        return true
    }

    private static func shouldSurfaceHydrationWhyRow(
        paceBehind: Bool,
        relativelyBehind: Bool,
        isCritical: Bool,
        horizon: CoachPresentationHorizon,
        dehydrationRisk: Bool
    ) -> Bool {
        if dehydrationRisk && (paceBehind || isCritical) { return true }
        guard relativelyBehind else { return false }
        switch horizon {
        case .now, .evening, .tomorrow, .laterToday:
            return true
        case .nextHours:
            return false
        }
    }

    private static func shouldSurfaceFuelWhyRow(
        paceBehind: Bool,
        relativelyBehind: Bool,
        isCritical: Bool,
        horizon: CoachPresentationHorizon,
        mealWindowOpen: Bool
    ) -> Bool {
        if isCritical { return true }
        guard relativelyBehind else { return false }
        if !mealWindowOpen { return false }
        switch horizon {
        case .now, .evening, .tomorrow, .laterToday:
            return true
        case .nextHours:
            return false
        }
    }
}
