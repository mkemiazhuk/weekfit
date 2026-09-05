import SwiftUI
import WeatherKit

/// Apple Weather attribution using WeatherKit's provided marks and legal URL.
///
/// Do not substitute a custom Apple Weather logo — always use
/// `WeatherAttribution.combinedMarkLightURL` / `combinedMarkDarkURL`.
struct WeekFitWeatherAttributionView: View {
    enum Style {
        /// Detail sheet / review: mark + legal link.
        case standard
        /// Compact strip suitable for Today header.
        case compact
    }

    var style: Style = .standard
    /// When set, overrides `colorScheme` for mark selection (e.g. weather night canvas).
    var preferDarkMark: Bool? = nil
    var secondaryForeground: Color = .secondary

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @ObservedObject private var store = WeekFitWeatherAttributionStore.shared

    @ScaledMetric(relativeTo: .caption2) private var standardMarkHeight: CGFloat = 16
    @ScaledMetric(relativeTo: .caption2) private var compactMarkHeight: CGFloat = 12

    private var usesDarkMark: Bool {
        preferDarkMark ?? (colorScheme == .dark)
    }

    private var markHeight: CGFloat {
        switch style {
        case .standard: return standardMarkHeight
        case .compact: return compactMarkHeight
        }
    }

    var body: some View {
        Group {
            if let attribution = store.attribution {
                attributionButton(attribution)
            } else if store.loadFailed {
                // Soft fallback — never blocks weather UI.
                Text(failureText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(secondaryForeground.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(Text(failureText))
            } else {
                Color.clear
                    .frame(height: markHeight)
                    .accessibilityHidden(true)
            }
        }
        .task {
            store.ensureLoaded()
        }
    }

    private func attributionButton(_ attribution: WeatherAttribution) -> some View {
        Button {
            openURL(attribution.legalPageURL)
        } label: {
            HStack(spacing: style == .compact ? 6 : 8) {
                AsyncImage(url: markURL(for: attribution)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: markHeight)
                    case .failure:
                        Text(attribution.serviceName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(secondaryForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    case .empty:
                        Color.clear.frame(height: markHeight)
                    @unknown default:
                        Color.clear.frame(height: markHeight)
                    }
                }
                .accessibilityHidden(true)

                if style == .standard {
                    Text(legalLinkTitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(secondaryForeground.opacity(0.92))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityTitle(for: attribution)))
        .accessibilityHint(Text(accessibilityHint))
        .accessibilityAddTraits(.isLink)
        .accessibilityIdentifier("weather.attribution")
    }

    private func markURL(for attribution: WeatherAttribution) -> URL {
        usesDarkMark
            ? attribution.combinedMarkDarkURL
            : attribution.combinedMarkLightURL
    }

    private var legalLinkTitle: String {
        WeekFitUsesRussianLanguage() ? "Источники погоды" : "Weather data sources"
    }

    private func accessibilityTitle(for attribution: WeatherAttribution) -> String {
        let service = attribution.serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if service.isEmpty {
            return "Apple Weather"
        }
        return service
    }

    private var accessibilityHint: String {
        WeekFitUsesRussianLanguage()
            ? "Открывает страницу с источниками погодных данных."
            : "Opens the weather data sources page."
    }

    private var failureText: String {
        WeekFitUsesRussianLanguage()
            ? "Источник погодных данных недоступен."
            : "Weather data sources are unavailable."
    }
}
