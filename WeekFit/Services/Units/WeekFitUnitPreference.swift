import Foundation

enum WeekFitUnitPreference: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case metric
    case uk
    case us

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic:
            return WeekFitLocalizedString("settings.units.option.automatic")
        case .metric:
            return WeekFitLocalizedString("settings.units.option.metric")
        case .uk:
            return WeekFitLocalizedString("settings.units.option.uk")
        case .us:
            return WeekFitLocalizedString("settings.units.option.us")
        }
    }

    var subtitle: String {
        switch self {
        case .automatic:
            return WeekFitLocalizedString("settings.units.option.automatic.subtitle")
        case .metric:
            return WeekFitLocalizedString("settings.units.option.metric.subtitle")
        case .uk:
            return WeekFitLocalizedString("settings.units.option.uk.subtitle")
        case .us:
            return WeekFitLocalizedString("settings.units.option.us.subtitle")
        }
    }
}

enum WeekFitResolvedUnitSystem: String, CaseIterable, Sendable {
    case metric
    case uk
    case us
}
