import CoreLocation
import Foundation

@MainActor
final class NightComfortLocationService: NSObject {

    static let cachedLatitudeKey = "weekfit.nightComfort.cachedLatitude"
    static let cachedLongitudeKey = "weekfit.nightComfort.cachedLongitude"

    private let manager = CLLocationManager()
    private weak var nightComfort: NightComfortController?
    private var lastAppliedCoordinate: CLLocationCoordinate2D?

    init(nightComfort: NightComfortController) {
        self.nightComfort = nightComfort
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        applyCachedCoordinate(logFreshCoordinate: false)
    }

    /// Uses cached coordinates or refreshes GPS only when permission was already granted.
    /// Never presents the system location prompt — use `requestWhenInUseAuthorizationIfNeeded()` after login.
    func refreshIfNeeded() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            applyCachedCoordinate(logFreshCoordinate: false)
        }
    }

    /// Stops location updates and clears cached coordinates after account deletion.
    /// Does not revoke the system Location permission (apps cannot revoke it).
    func stopAndClearForAccountDeletion() {
        manager.stopUpdatingLocation()
        Self.clearCachedLocation()
        lastAppliedCoordinate = nil
    }

    static func clearCachedLocation() {
        UserDefaults.standard.removeObject(forKey: cachedLatitudeKey)
        UserDefaults.standard.removeObject(forKey: cachedLongitudeKey)
    }

    func requestWhenInUseAuthorizationIfNeeded() {
        guard AccountSessionController.shared.mode == .realUser else { return }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    private func applyCachedCoordinate(logFreshCoordinate: Bool) {
        guard
            let latitude = UserDefaults.standard.object(forKey: Self.cachedLatitudeKey) as? Double,
            let longitude = UserDefaults.standard.object(forKey: Self.cachedLongitudeKey) as? Double
        else {
            return
        }

        applyCoordinateIfNeeded(
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            logFreshCoordinate: logFreshCoordinate
        )
    }

    private func storeCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let latitudeChanged = storedCoordinateValue(forKey: Self.cachedLatitudeKey) != coordinate.latitude
        let longitudeChanged = storedCoordinateValue(forKey: Self.cachedLongitudeKey) != coordinate.longitude

        if latitudeChanged {
            UserDefaults.standard.set(coordinate.latitude, forKey: Self.cachedLatitudeKey)
        }
        if longitudeChanged {
            UserDefaults.standard.set(coordinate.longitude, forKey: Self.cachedLongitudeKey)
        }

        applyCoordinateIfNeeded(coordinate, logFreshCoordinate: true)
    }

    private func applyCoordinateIfNeeded(
        _ coordinate: CLLocationCoordinate2D,
        logFreshCoordinate: Bool
    ) {
        guard !coordinatesEqual(lastAppliedCoordinate, coordinate) else { return }

        lastAppliedCoordinate = coordinate
        nightComfort?.updateSolarCoordinate(coordinate)

        #if DEBUG
        guard logFreshCoordinate else { return }
        NightComfortDebug.log(
            "solar coordinate lat=\(String(format: "%.4f", coordinate.latitude)) " +
                "lon=\(String(format: "%.4f", coordinate.longitude))"
        )
        #endif
    }

    private func storedCoordinateValue(forKey key: String) -> Double? {
        UserDefaults.standard.object(forKey: key) as? Double
    }

    private func coordinatesEqual(
        _ lhs: CLLocationCoordinate2D?,
        _ rhs: CLLocationCoordinate2D
    ) -> Bool {
        guard let lhs else { return false }
        return abs(lhs.latitude - rhs.latitude) < 0.0001 &&
            abs(lhs.longitude - rhs.longitude) < 0.0001
    }
}

extension NightComfortLocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            refreshIfNeeded()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            storeCoordinate(coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            applyCachedCoordinate(logFreshCoordinate: false)
            #if DEBUG
            NightComfortDebug.log("solar location failed fallback=cached error=\(error.localizedDescription)")
            #endif
        }
    }
}
