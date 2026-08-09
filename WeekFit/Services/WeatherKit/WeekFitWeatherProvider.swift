import Foundation
import CoreLocation
import SwiftUI
import WeatherKit

/// Lightweight WeatherKit integration for WeekFit UI.
/// - Caches last successful result for 45 minutes
/// - Single-flight: avoids duplicate simultaneous WeatherKit requests
/// - Reuses cached coordinates from `NightComfortLocationService` if available
final class WeekFitWeatherProvider {

    static let shared = WeekFitWeatherProvider()

    private let store = WeekFitWeatherCacheStore()
    private let locationProvider = LocationProvider()

    private init() {}

    /// Returns cached weather immediately if fresh; otherwise fetches (and updates cache).
    /// - Note: Returns `nil` if weather is unavailable or permissions are denied.
    func currentWeatherSummary() async -> WeekFitWeatherSummary? {
        let now = Date()
        if let cached = await store.cachedIfFresh(now: now) {
            return cached
        }

        return await fetchAndUpdate(now: now)
    }

    /// Returns cached weather even if stale, plus whether it is still within the TTL window.
    /// - Used for silent refresh: show cached immediately, refresh only when expired.
    func cachedSummaryAndFreshness() async -> (summary: WeekFitWeatherSummary?, isFresh: Bool) {
        let now = Date()
        return await store.cachedSummaryAndFreshness(now: now)
    }

    /// Forces a refresh (and updates cache on success).
    func refreshWeather() async -> WeekFitWeatherSummary? {
        await fetchAndUpdate(now: Date())
    }

    private func fetchAndUpdate(now: Date) async -> WeekFitWeatherSummary? {
        let taskName = "weather.fetchAndUpdate"
        let run = UUID()
        StartupDiagnostics.taskBegin(taskName, detail: "run=\(run.uuidString.prefix(8))")
        let result = await store.fetchAndUpdate(now: now) { [weak self] in
            guard let self else { return nil }

            guard let coordinate = await locationProvider.coordinateIfAvailableOrRequest() else {
                return nil
            }

            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let service = WeatherService.shared

            async let currentReq = try? service.weather(for: location, including: .current)
            async let dailyReq = try? service.weather(for: location, including: .daily)
            async let hourlyReq = try? service.weather(for: location, including: .hourly)

            let current = await currentReq
            let daily = await dailyReq
            let hourly = await hourlyReq

            guard let current else { return nil }

            let todayForecast = daily?.first
            let nextHourPrecip = hourly?
                .first(where: { $0.date >= Date() })?
                .precipitationChance

            let placeName = await locationProvider.cachedPlaceNameIfAvailable()

            return WeekFitWeatherSummary.from(
                currentWeather: current,
                dailyForecast: todayForecast,
                hourlyPrecipChance: nextHourPrecip,
                placeName: placeName
            )
        }
        if Task.isCancelled {
            StartupDiagnostics.taskCancelled(taskName, detail: "run=\(run.uuidString.prefix(8))")
        } else {
            StartupDiagnostics.taskSuccess(taskName, detail: "run=\(run.uuidString.prefix(8)) hasSummary=\(result != nil)")
        }
        return result
    }
}

// MARK: - Models

struct WeekFitWeatherSummary: Equatable, Sendable {
    // Canonical values (independent from unit preference):
    // - Temperature: Celsius
    // - Wind speed: kilometres per hour
    // - Visibility: kilometres
    let temperature: Measurement<UnitTemperature>
    let feelsLike: Measurement<UnitTemperature>
    let highTemperature: Measurement<UnitTemperature>?
    let lowTemperature: Measurement<UnitTemperature>?

    let symbolName: String
    let condition: WeekFitWeatherCondition
    /// WeatherKit daylight flag — drives sun vs moon presentation for clear skies.
    let isDaylight: Bool

    let humidityPercent: Int
    let windSpeed: Measurement<UnitSpeed>
    let uvIndex: Int
    let precipitationChance: Int?

    /// Horizontal visibility in kilometres when WeatherKit provides it.
    let visibilityKilometers: Double?
    let sunrise: Date?
    let sunset: Date?
    /// Short place label (city / locality) when reverse-geocode is available.
    let placeName: String?

    var badgeSymbolName: String {
        condition.premiumBadgeSymbolName(isDaylight: isDaylight)
    }

    var badgeShortLabel: String {
        condition.shortLabel(isDaylight: isDaylight)
    }

    /// Compact pill label — shorter than `badgeShortLabel` for tight Today chrome.
    var badgeCompactLabel: String {
        condition.compactBadgeLabel(isDaylight: isDaylight)
    }

    var badgeIconPrimary: Color {
        condition.badgeIconPrimary(isDaylight: isDaylight)
    }

    var badgeIconSecondary: Color {
        condition.badgeIconSecondary(isDaylight: isDaylight)
    }

    var badgeNaturalColor: Color {
        condition.naturalColor(isDaylight: isDaylight)
    }

    var resolvedPeriod: WeekFitWeatherPeriod {
        WeekFitWeatherPeriod.resolve(
            sunrise: sunrise,
            sunset: sunset,
            isDaylightHint: isDaylight
        )
    }

    var resolvedTokens: WeekFitWeatherTokens {
        resolvedTokens(appAppearanceDark: false)
    }

    func resolvedTokens(appAppearanceDark: Bool) -> WeekFitWeatherTokens {
        WeekFitWeatherTokens.resolve(
            period: resolvedPeriod,
            condition: condition,
            temperatureC: temperature.value,
            visibilityKm: visibilityKilometers,
            precipitationChance: precipitationChance,
            appAppearanceDark: appAppearanceDark
        )
    }

    init(
        temperature: Measurement<UnitTemperature>,
        feelsLike: Measurement<UnitTemperature>,
        highTemperature: Measurement<UnitTemperature>?,
        lowTemperature: Measurement<UnitTemperature>?,
        symbolName: String,
        condition: WeekFitWeatherCondition,
        isDaylight: Bool = true,
        humidityPercent: Int,
        windSpeed: Measurement<UnitSpeed>,
        uvIndex: Int,
        precipitationChance: Int?,
        visibilityKilometers: Double? = nil,
        sunrise: Date? = nil,
        sunset: Date? = nil,
        placeName: String? = nil
    ) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.highTemperature = highTemperature
        self.lowTemperature = lowTemperature
        self.symbolName = symbolName
        self.condition = condition
        self.isDaylight = isDaylight
        self.humidityPercent = humidityPercent
        self.windSpeed = windSpeed
        self.uvIndex = uvIndex
        self.precipitationChance = precipitationChance
        self.visibilityKilometers = visibilityKilometers
        self.sunrise = sunrise
        self.sunset = sunset
        self.placeName = placeName
    }

    static func from(
        currentWeather: CurrentWeather,
        dailyForecast: DayWeather? = nil,
        hourlyPrecipChance: Double? = nil,
        placeName: String? = nil
    ) -> WeekFitWeatherSummary? {
        guard !currentWeather.symbolName.isEmpty else { return nil }

        let condition = WeekFitWeatherCondition.from(
            symbolName: currentWeather.symbolName,
            rawDescription: currentWeather.condition.rawValue
        )

        let temperature = currentWeather.temperature.converted(to: .celsius)
        let feelsLike = currentWeather.apparentTemperature.converted(to: .celsius)
        let windSpeed = currentWeather.wind.speed.converted(to: .kilometersPerHour)

        var highTemperature: Measurement<UnitTemperature>?
        var lowTemperature: Measurement<UnitTemperature>?
        var sunrise: Date?
        var sunset: Date?
        if let day = dailyForecast {
            highTemperature = day.highTemperature.converted(to: .celsius)
            lowTemperature = day.lowTemperature.converted(to: .celsius)
            sunrise = day.sun.sunrise
            sunset = day.sun.sunset
        }

        let humidityPercent = Int((currentWeather.humidity * 100).rounded())

        let precipChance: Int?
        if let chance = hourlyPrecipChance {
            precipChance = Int((chance * 100).rounded())
        } else if let day = dailyForecast {
            precipChance = Int((day.precipitationChance * 100).rounded())
        } else {
            precipChance = nil
        }

        let visibilityKm = currentWeather.visibility.converted(to: .kilometers).value

        // Prefer WeatherKit daylight; moon glyphs are a hard night signal.
        let symbol = currentWeather.symbolName.lowercased()
        let isDaylight = symbol.contains("moon") ? false : currentWeather.isDaylight

        return WeekFitWeatherSummary(
            temperature: temperature,
            feelsLike: feelsLike,
            highTemperature: highTemperature,
            lowTemperature: lowTemperature,
            symbolName: currentWeather.symbolName,
            condition: condition,
            isDaylight: isDaylight,
            humidityPercent: humidityPercent,
            windSpeed: windSpeed,
            uvIndex: currentWeather.uvIndex.value,
            precipitationChance: precipChance,
            visibilityKilometers: visibilityKm.isFinite ? visibilityKm : nil,
            sunrise: sunrise,
            sunset: sunset,
            placeName: placeName
        )
    }
}

enum WeekFitWeatherCondition: String, Sendable {
    case clear
    case partlyCloudy
    case cloudy
    case rain
    case snow
    case storm
    case windy
    case fog
    case other

    func shortLabel(isDaylight: Bool = true) -> String {
        if WeekFitUsesRussianLanguage() {
            switch self {
            case .clear: return isDaylight ? "Солнечно" : "Ясно"
            case .partlyCloudy: return "Переменная облачность"
            case .cloudy: return "Облачно"
            case .rain: return "Дождь"
            case .snow: return "Снег"
            case .storm: return "Гроза"
            case .windy: return "Ветрено"
            case .fog: return "Туман"
            case .other: return "Другое"
            }
        }

        switch self {
        case .clear: return isDaylight ? "Sunny" : "Clear"
        case .partlyCloudy: return "Partly cloudy"
        case .cloudy: return "Cloudy"
        case .rain: return "Rain"
        case .snow: return "Snow"
        case .storm: return "Storm"
        case .windy: return "Windy"
        case .fog: return "Fog"
        case .other: return "Other"
        }
    }

    /// Tight Today-header pill copy. Prefer short words that fit beside the avatar.
    func compactBadgeLabel(isDaylight: Bool = true) -> String {
        if WeekFitUsesRussianLanguage() {
            switch self {
            case .clear: return isDaylight ? "Солнечно" : "Ясно"
            case .partlyCloudy: return "Перем."
            case .cloudy: return "Облачно"
            case .rain: return "Дождь"
            case .snow: return "Снег"
            case .storm: return "Гроза"
            case .windy: return "Ветер"
            case .fog: return "Туман"
            case .other: return "Погода"
            }
        }

        switch self {
        case .clear: return isDaylight ? "Sunny" : "Clear"
        case .partlyCloudy: return "Partly"
        case .cloudy: return "Cloudy"
        case .rain: return "Rain"
        case .snow: return "Snow"
        case .storm: return "Storm"
        case .windy: return "Windy"
        case .fog: return "Fog"
        case .other: return "Other"
        }
    }

    func naturalColor(isDaylight: Bool = true) -> Color {
        switch self {
        case .clear:
            return isDaylight
                ? Color(red: 1.00, green: 0.78, blue: 0.28)
                : Color(red: 0.72, green: 0.80, blue: 0.98)
        case .partlyCloudy:
            return isDaylight
                ? Color(red: 0.85, green: 0.78, blue: 0.55)
                : Color(red: 0.70, green: 0.76, blue: 0.92)
        case .cloudy: return Color(red: 0.68, green: 0.78, blue: 0.94)
        case .rain:   return Color(red: 0.42, green: 0.68, blue: 0.98)
        case .snow:   return Color(red: 0.82, green: 0.90, blue: 1.00)
        case .storm:  return Color(red: 0.62, green: 0.52, blue: 0.98)
        case .windy:  return Color(red: 0.62, green: 0.74, blue: 0.88)
        case .fog:    return Color(red: 0.72, green: 0.78, blue: 0.86)
        case .other:  return Color(red: 0.70, green: 0.78, blue: 0.90)
        }
    }

    /// Filled SF Symbol for compact premium badges (avoids hollow outline glyphs).
    func premiumBadgeSymbolName(isDaylight: Bool = true) -> String {
        switch self {
        case .clear:  return isDaylight ? "sun.max.fill" : "moon.stars.fill"
        case .partlyCloudy: return isDaylight ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy: return isDaylight ? "cloud.fill" : "cloud.moon.fill"
        case .rain:   return "cloud.rain.fill"
        case .snow:   return "cloud.snow.fill"
        case .storm:  return "cloud.bolt.fill"
        case .windy:  return "wind"
        case .fog:    return "cloud.fog.fill"
        case .other:  return "cloud.fill"
        }
    }

    func badgeIconPrimary(isDaylight: Bool = true) -> Color {
        switch self {
        case .clear:
            return isDaylight
                ? Color(red: 1.00, green: 0.86, blue: 0.42)
                : Color(red: 0.86, green: 0.90, blue: 1.00)
        case .partlyCloudy:
            return isDaylight
                ? Color(red: 0.92, green: 0.82, blue: 0.48)
                : Color(red: 0.80, green: 0.84, blue: 0.96)
        case .cloudy: return Color(red: 0.62, green: 0.70, blue: 0.84)
        case .rain:   return Color(red: 0.62, green: 0.82, blue: 1.00)
        case .snow:   return Color(red: 0.78, green: 0.86, blue: 0.96)
        case .storm:  return Color(red: 0.82, green: 0.74, blue: 1.00)
        case .windy:  return Color(red: 0.70, green: 0.80, blue: 0.92)
        case .fog:    return Color(red: 0.68, green: 0.74, blue: 0.84)
        case .other:  return Color(red: 0.66, green: 0.74, blue: 0.88)
        }
    }

    func badgeIconSecondary(isDaylight: Bool = true) -> Color {
        switch self {
        case .clear:
            return isDaylight
                ? Color(red: 1.00, green: 0.58, blue: 0.18)
                : Color(red: 0.42, green: 0.52, blue: 0.88)
        case .partlyCloudy:
            return isDaylight
                ? Color(red: 0.55, green: 0.68, blue: 0.88)
                : Color(red: 0.45, green: 0.52, blue: 0.78)
        case .cloudy: return Color(red: 0.42, green: 0.56, blue: 0.82)
        case .rain:   return Color(red: 0.22, green: 0.46, blue: 0.92)
        case .snow:   return Color(red: 0.55, green: 0.72, blue: 0.95)
        case .storm:  return Color(red: 0.42, green: 0.32, blue: 0.88)
        case .windy:  return Color(red: 0.40, green: 0.55, blue: 0.74)
        case .fog:    return Color(red: 0.52, green: 0.58, blue: 0.68)
        case .other:  return Color(red: 0.45, green: 0.55, blue: 0.72)
        }
    }

    /// Small controlled vocabulary mapping.
    /// Uses symbolName + WeatherKit raw condition description (kept stable for mapping).
    static func from(symbolName: String, rawDescription: String) -> WeekFitWeatherCondition {
        let raw = rawDescription.lowercased()
        let sym = symbolName.lowercased()

        if raw.contains("storm") || raw.contains("thunder") || raw.contains("hail") || sym.contains("bolt") {
            return .storm
        }
        if raw.contains("snow") || raw.contains("blizzard") || raw.contains("sleet") || raw.contains("flurries") {
            return .snow
        }
        if raw.contains("rain") || raw.contains("drizzle") || raw.contains("shower") {
            return .rain
        }
        if raw.contains("fog") || raw.contains("haze") || raw.contains("smoke") || sym.contains("fog") {
            return .fog
        }
        if raw.contains("wind") || sym == "wind" {
            return .windy
        }
        if raw.contains("partly") || raw.contains("mostlyclear")
            || (sym.contains("sun") && sym.contains("cloud"))
            || (sym.contains("moon") && sym.contains("cloud")) {
            return .partlyCloudy
        }
        if raw.contains("mostlycloudy") || raw.contains("cloudy") || raw.contains("overcast")
            || (sym.contains("cloud") && !sym.contains("sun") && !sym.contains("moon")) {
            return .cloudy
        }
        if raw.contains("clear") || raw.contains("sun") || sym.contains("sun") || sym.contains("moon") {
            return .clear
        }
        if sym.contains("cloud") {
            return .cloudy
        }
        return .other
    }
}

// MARK: - Caching + single-flight

actor WeekFitWeatherCacheStore {
    private var cachedSummary: WeekFitWeatherSummary?
    private var cachedAt: Date?

    private var inFlight: Task<WeekFitWeatherSummary?, Never>?

    private let ttl: TimeInterval = 45 * 60

    // MARK: - Test hooks
    // Deterministically tests caching behavior without WeatherKit/network.
    func _testSetCache(summary: WeekFitWeatherSummary, now: Date) {
        setCache(summary: summary, now: now)
    }

    func _testClearCache() {
        cachedSummary = nil
        cachedAt = nil
    }

    func cachedIfFresh(now: Date) -> WeekFitWeatherSummary? {
        guard let cachedAt,
              let cachedSummary,
              now.timeIntervalSince(cachedAt) < ttl else {
            return nil
        }
        return cachedSummary
    }

    func cachedSummaryAndFreshness(now: Date) -> (WeekFitWeatherSummary?, Bool) {
        guard let cachedAt, let cachedSummary else {
            return (nil, false)
        }
        let isFresh = now.timeIntervalSince(cachedAt) < ttl
        return (cachedSummary, isFresh)
    }

    func fetchAndUpdate(
        now: Date,
        _ fetch: @escaping () async -> WeekFitWeatherSummary?
    ) async -> WeekFitWeatherSummary? {
        if let inFlight {
            return await inFlight.value
        }

        let task = Task { () -> WeekFitWeatherSummary? in
            let summary = await fetch()
            if let summary {
                // Update cache from within the actor context.
                self.setCache(summary: summary, now: now)
            }
            return summary
        }

        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }

    private func setCache(summary: WeekFitWeatherSummary, now: Date) {
        cachedSummary = summary
        cachedAt = now
    }
}

// MARK: - Location

private final class LocationProvider: NSObject, CLLocationManagerDelegate {

    private let locationManager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    private var isRequesting = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    /// Returns cached coordinates if available, otherwise requests When In Use permission
    /// and resolves a single coordinate (or nil on denial/unavailability).
    func coordinateIfAvailableOrRequest() async -> CLLocationCoordinate2D? {
        if let cached = cachedCoordinateIfAvailable() {
            return cached
        }

        return await withCheckedContinuation { (cont: CheckedContinuation<CLLocationCoordinate2D?, Never>) in
            self.continuation = cont

            // Prevent duplicate requests while WeatherKit is awaiting location.
            if isRequesting {
                self.continuation = nil
                cont.resume(returning: nil)
                return
            }
            isRequesting = true

            // Request When In Use only.
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            default:
                // Denied / restricted / etc.
                isRequesting = false
                cont.resume(returning: nil)
                return
            }
        }
    }

    private func cachedCoordinateIfAvailable() -> CLLocationCoordinate2D? {
        let defaults = UserDefaults.standard
        let lat = defaults.object(forKey: NightComfortLocationService.cachedLatitudeKey) as? Double
        let lon = defaults.object(forKey: NightComfortLocationService.cachedLongitudeKey) as? Double
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Best-effort locality label from the Night Comfort coordinate cache.
    func cachedPlaceNameIfAvailable() async -> String? {
        guard let coordinate = cachedCoordinateIfAvailable() else { return nil }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                let place = placemarks?.first
                let name = place?.locality ?? place?.subAdministrativeArea ?? place?.name
                cont.resume(returning: name)
            }
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // If authorization is granted, request a single fix.
        guard let continuation else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            // Permission denied or restricted.
            self.isRequesting = false
            self.continuation = nil
            continuation.resume(returning: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        guard let continuation else { return }

        self.isRequesting = false
        self.continuation = nil
        continuation.resume(returning: last.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation else { return }
        self.isRequesting = false
        self.continuation = nil
        continuation.resume(returning: nil)
    }
}

