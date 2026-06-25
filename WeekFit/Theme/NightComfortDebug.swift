import Foundation

#if DEBUG
enum NightComfortDebug {
    static func log(_ message: String) {
        print("[NightComfort] \(message)")
    }

    static func logState(
        preference: NightComfortPreference,
        blend: CGFloat,
        reason: String,
        solarAvailable: Bool = false,
        solarTimes: NightComfortSolarTimeProvider.SolarTimes? = nil
    ) {
        var message =
            "preference=\(preference.rawValue) blend=\(String(format: "%.3f", blend)) " +
            "solar=\(solarAvailable ? "yes" : "fallback") reason=\(reason)"

        if let solarTimes {
            message +=
                " sunset=\(formatLocalTime(solarTimes.sunset)) " +
                "sunrise=\(formatLocalTime(solarTimes.sunrise))"
        }

        log(message)
    }

    private static func formatLocalTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}
#endif
