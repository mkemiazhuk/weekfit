import Foundation

public struct WorkoutRoutePoint: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let verticalAccuracy: Double?
    public let timestamp: Date

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        verticalAccuracy: Double?,
        timestamp: Date
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.verticalAccuracy = verticalAccuracy
        self.timestamp = timestamp
    }
}
