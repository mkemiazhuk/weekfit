import Foundation

// MARK: - Duration models (do not merge)

/// User-facing **activity** duration class for walks/hikes.
///
/// Thresholds: `<30` short · `30–89` standard · `90–179` long · `≥180` extended.
///
/// - Important: This is **not** the same concept as app-layer `CoachDurationBand`.
///   `CoachDurationBand` drives nutrition / scenario pacing with different cutovers
///   (`<30` / `30–59` / `60–89` / `≥90`). Keep the two models separate so they can
///   evolve independently. Do not retune one to match the other.
public enum CoachWalkDurationClass: String, Sendable, Equatable, CaseIterable {
    case short
    case standard
    case long
    case extended

    public static func from(minutes: Int) -> CoachWalkDurationClass {
        switch max(minutes, 0) {
        case ..<30:
            return .short
        case 30..<90:
            return .standard
        case 90..<180:
            return .long
        default:
            return .extended
        }
    }

    /// True when duration alone is enough to consider hydration / fueling / next-day advice
    /// in later phases — without asserting physiological “volume” or “training stress”.
    public var isLongOrExtended: Bool {
        self == .long || self == .extended
    }
}

/// Intensity is independent of duration and volume.
/// Prefer `.unknown` when HR, pace, or clear title cues are absent.
public enum CoachActivityIntensityClass: String, Sendable, Equatable, CaseIterable {
    case easy
    case moderate
    case brisk
    case hard
    case unknown
}

/// Total activity volume / load estimate.
/// Stay on `.unknown` unless supporting signals justify a confident call.
/// Duration alone must **not** imply `.meaningful` or `.high`.
public enum CoachActivityVolumeClass: String, Sendable, Equatable, CaseIterable {
    case low
    case meaningful
    case high
    case unknown
}

public enum CoachLabeledLocomotionKind: String, Sendable, Equatable {
    case walk
    case hike
}

/// Optional richer signals. Phase B uses duration + calories + title tokens;
/// HR / distance / elevation / pace are reserved for Phase E and only affect
/// whether supporting load data is considered present.
public struct CoachActivityLabelSignals: Sendable, Equatable {
    public let durationMinutes: Int
    public let title: String
    public let type: String
    public let icon: String
    public let imageName: String
    /// `nil` means calories were not provided; `0` means provided but zero.
    public let activeCalories: Int?
    public let averageHeartRate: Double?
    public let distanceKm: Double?
    public let elevationGainMeters: Double?
    public let averagePaceMinPerKm: Double?

    public init(
        durationMinutes: Int,
        title: String,
        type: String = "",
        icon: String = "",
        imageName: String = "",
        activeCalories: Int? = nil,
        averageHeartRate: Double? = nil,
        distanceKm: Double? = nil,
        elevationGainMeters: Double? = nil,
        averagePaceMinPerKm: Double? = nil
    ) {
        self.durationMinutes = durationMinutes
        self.title = title
        self.type = type
        self.icon = icon
        self.imageName = imageName
        self.activeCalories = activeCalories
        self.averageHeartRate = averageHeartRate
        self.distanceKm = distanceKm
        self.elevationGainMeters = elevationGainMeters
        self.averagePaceMinPerKm = averagePaceMinPerKm
    }

    public var tokenText: String {
        [type, title, icon, imageName]
            .joined(separator: " ")
            .lowercased()
    }

    /// Calories (when known and > 0), HR, distance, elevation, or pace.
    public var hasSupportingLoadSignals: Bool {
        if let activeCalories, activeCalories > 0 { return true }
        if let averageHeartRate, averageHeartRate > 0 { return true }
        if let distanceKm, distanceKm > 0 { return true }
        if let elevationGainMeters, elevationGainMeters > 0 { return true }
        if let averagePaceMinPerKm, averagePaceMinPerKm > 0 { return true }
        return false
    }
}

/// Composed classification for display. Intensity, duration, and volume stay separate fields.
public struct CoachActivityLabelDescriptor: Sendable, Equatable {
    public let locomotion: CoachLabeledLocomotionKind
    public let durationClass: CoachWalkDurationClass
    public let intensityClass: CoachActivityIntensityClass
    public let volumeClass: CoachActivityVolumeClass
    public let englishLabel: String
    public let russianLabel: String

    public init(
        locomotion: CoachLabeledLocomotionKind,
        durationClass: CoachWalkDurationClass,
        intensityClass: CoachActivityIntensityClass,
        volumeClass: CoachActivityVolumeClass,
        englishLabel: String,
        russianLabel: String
    ) {
        self.locomotion = locomotion
        self.durationClass = durationClass
        self.intensityClass = intensityClass
        self.volumeClass = volumeClass
        self.englishLabel = englishLabel
        self.russianLabel = russianLabel
    }

    public func localizedLabel(russian: Bool) -> String {
        russian ? russianLabel : englishLabel
    }
}

/// Builds walk/hike labels without collapsing intensity into the whole activity name.
/// Never emits a bare “Easy walk” for long / extended outings.
public enum CoachActivityLabelBuilder {

    public static func descriptor(
        for signals: CoachActivityLabelSignals
    ) -> CoachActivityLabelDescriptor? {
        guard let locomotion = locomotionKind(for: signals) else { return nil }

        let durationClass = CoachWalkDurationClass.from(minutes: signals.durationMinutes)
        let intensityClass = intensityClass(for: signals)
        let volumeClass = volumeClass(for: signals, durationClass: durationClass)
        let english = englishLabel(
            locomotion: locomotion,
            duration: durationClass,
            intensity: intensityClass,
            volume: volumeClass
        )
        let russian = russianLabel(
            locomotion: locomotion,
            duration: durationClass,
            intensity: intensityClass,
            volume: volumeClass
        )

        return CoachActivityLabelDescriptor(
            locomotion: locomotion,
            durationClass: durationClass,
            intensityClass: intensityClass,
            volumeClass: volumeClass,
            englishLabel: english,
            russianLabel: russian
        )
    }

    // MARK: - Classification

    public static func locomotionKind(
        for signals: CoachActivityLabelSignals
    ) -> CoachLabeledLocomotionKind? {
        let tokens = signals.tokenText
        if CoachActivityClassification.isHikeLike(
            CoachActivityDescriptor(
                type: signals.type,
                title: signals.title,
                icon: signals.icon,
                imageName: signals.imageName
            )
        ) {
            return .hike
        }
        if CoachActivityClassification.isWalkLike(
            CoachActivityDescriptor(
                type: signals.type,
                title: signals.title,
                icon: signals.icon,
                imageName: signals.imageName
            )
        ) {
            return .walk
        }
        // Token fallback if descriptor helpers miss edge titles.
        if tokens.contains("hike") ||
            tokens.contains("hiking") ||
            tokens.contains("figure.hiking") ||
            tokens.contains("поход") ||
            tokens.contains("хайкинг") {
            return .hike
        }
        if tokens.contains("walk") || tokens.contains("walking") || tokens.contains("прогул") {
            return .walk
        }
        return nil
    }

    public static func intensityClass(
        for signals: CoachActivityLabelSignals
    ) -> CoachActivityIntensityClass {
        let tokens = signals.tokenText

        if containsAny(tokens, ["interval", "tempo", "threshold", "vo2", "race", "hard", "тяжёл", "тяжел", "интенсив"]) {
            return .hard
        }
        if containsAny(tokens, ["brisk", "быстр", "энергич"]) {
            return .brisk
        }
        if containsAny(tokens, ["moderate", "умере"]) {
            return .moderate
        }
        if containsAny(tokens, ["easy", "recovery", "лёгк", "легк", "спокойн", "gentle"]) {
            return .easy
        }

        // No HR / pace inference in Phase B — stay unknown without title cues.
        return .unknown
    }

    public static func volumeClass(
        for signals: CoachActivityLabelSignals,
        durationClass: CoachWalkDurationClass
    ) -> CoachActivityVolumeClass {
        // Duration alone is never enough to assert volume.
        guard signals.hasSupportingLoadSignals else {
            return .unknown
        }

        let calories = signals.activeCalories ?? 0

        if calories >= 900 || (durationClass == .extended && calories >= 600) {
            return .high
        }

        if calories >= 400 && signals.durationMinutes >= 60 {
            return .meaningful
        }

        if durationClass == .short && calories > 0 && calories < 150 {
            return .low
        }

        // Supporting signal present but inconclusive — do not invent volume.
        return .unknown
    }

    // MARK: - Labels

    private static func englishLabel(
        locomotion: CoachLabeledLocomotionKind,
        duration: CoachWalkDurationClass,
        intensity: CoachActivityIntensityClass,
        volume: CoachActivityVolumeClass
    ) -> String {
        let noun = locomotion == .hike ? "hike" : "walk"
        let base: String

        switch duration {
        case .short:
            switch intensity {
            case .easy:
                base = "Short easy \(noun)"
            case .moderate:
                base = "Short moderate \(noun)"
            case .brisk:
                base = "Short brisk \(noun)"
            case .hard:
                base = "Short hard \(noun)"
            case .unknown:
                base = "Short \(noun)"
            }
        case .standard:
            // Avoid bare "Easy walk" — intensity is paced, not the whole outing.
            switch intensity {
            case .easy:
                base = "Easy-pace \(noun)"
            case .moderate:
                base = "Steady \(noun)"
            case .brisk:
                base = "Brisk \(noun)"
            case .hard:
                base = "Hard-pace \(noun)"
            case .unknown:
                base = noun == "hike" ? "Hike" : "Walk"
            }
        case .long:
            switch intensity {
            case .easy:
                base = "Long low-intensity \(noun)"
            case .moderate:
                base = "Long moderate \(noun)"
            case .brisk:
                base = "Long brisk \(noun)"
            case .hard:
                base = "Long hard-pace \(noun)"
            case .unknown:
                base = "Long \(noun)"
            }
        case .extended:
            switch intensity {
            case .easy:
                base = "Extended low-intensity \(noun)"
            case .moderate:
                base = "Extended steady \(noun)"
            case .brisk:
                base = "Extended brisk \(noun)"
            case .hard:
                base = "Extended hard-pace \(noun)"
            case .unknown:
                base = "Extended \(noun)"
            }
        }

        return appendVolumeEnglish(base, volume: volume)
    }

    private static func russianLabel(
        locomotion: CoachLabeledLocomotionKind,
        duration: CoachWalkDurationClass,
        intensity: CoachActivityIntensityClass,
        volume: CoachActivityVolumeClass
    ) -> String {
        let noun = locomotion == .hike ? "поход" : "прогулка"
        let base: String

        switch duration {
        case .short:
            switch intensity {
            case .easy:
                base = "Короткая лёгкая \(noun)"
            case .moderate:
                base = "Короткая умеренная \(noun)"
            case .brisk:
                base = "Короткая быстрая \(noun)"
            case .hard:
                base = "Короткая интенсивная \(noun)"
            case .unknown:
                base = "Короткая \(noun)"
            }
        case .standard:
            switch intensity {
            case .easy:
                base = locomotion == .hike ? "Поход в лёгком темпе" : "Прогулка в лёгком темпе"
            case .moderate:
                base = locomotion == .hike ? "Спокойный поход" : "Спокойная прогулка"
            case .brisk:
                base = locomotion == .hike ? "Быстрый поход" : "Быстрая прогулка"
            case .hard:
                base = locomotion == .hike ? "Интенсивный поход" : "Интенсивная прогулка"
            case .unknown:
                base = locomotion == .hike ? "Поход" : "Прогулка"
            }
        case .long:
            switch intensity {
            case .easy:
                base = "Длительная \(noun) низкой интенсивности"
            case .moderate:
                base = "Длительная умеренная \(noun)"
            case .brisk:
                base = "Длительная быстрая \(noun)"
            case .hard:
                base = "Длительная интенсивная \(noun)"
            case .unknown:
                base = "Длительная \(noun)"
            }
        case .extended:
            switch intensity {
            case .easy:
                base = "Очень длительная \(noun) низкой интенсивности"
            case .moderate:
                base = "Очень длительная спокойная \(noun)"
            case .brisk:
                base = "Очень длительная быстрая \(noun)"
            case .hard:
                base = "Очень длительная интенсивная \(noun)"
            case .unknown:
                base = "Очень длительная \(noun)"
            }
        }

        return appendVolumeRussian(base, volume: volume)
    }

    private static func appendVolumeEnglish(_ base: String, volume: CoachActivityVolumeClass) -> String {
        switch volume {
        case .meaningful:
            return "\(base) with meaningful activity volume"
        case .high:
            return "\(base) with high activity volume"
        case .low, .unknown:
            return base
        }
    }

    private static func appendVolumeRussian(_ base: String, volume: CoachActivityVolumeClass) -> String {
        switch volume {
        case .meaningful:
            return "\(base) с заметным объёмом нагрузки"
        case .high:
            return "\(base) с высоким объёмом нагрузки"
        case .low, .unknown:
            return base
        }
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}
