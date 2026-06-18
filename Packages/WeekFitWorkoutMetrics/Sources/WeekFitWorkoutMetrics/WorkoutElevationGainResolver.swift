import Foundation
import HealthKit

public enum WorkoutElevationGainResolver {
    public static func resolve(from workout: HKWorkout, routePoints: [WorkoutRoutePoint]) -> Double? {
        if let metadataGain = fromWorkoutMetadata(workout.metadata) {
            return metadataGain
        }

        return WorkoutElevationGainCalculator.calculate(from: routePoints)
    }

    public static func fromWorkoutMetadata(_ metadata: [String: Any]?) -> Double? {
        guard let metadata else { return nil }

        if let quantity = metadata[HKMetadataKeyElevationAscended] as? HKQuantity {
            return positiveMeters(from: quantity)
        }

        return nil
    }

    private static func positiveMeters(from quantity: HKQuantity) -> Double? {
        let meters = quantity.doubleValue(for: .meter())
        return meters > 0 ? meters : nil
    }
}
