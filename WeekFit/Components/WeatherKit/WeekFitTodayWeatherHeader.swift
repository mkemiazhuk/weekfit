import SwiftUI
import CoreLocation

struct WeekFitTodayWeatherHeader: View {
    let title: String
    let subtitle: String
    let initials: String
    var hasProfileName: Bool = false
    let onAvatarTap: () -> Void

    @State private var badgeState: WeekFitWeatherBadge.State = .loading
    @State private var didStart = false
    @State private var showWeatherSheet = false
    @State private var badgeTapScale: CGFloat = 1.0
    @State private var showEnableLocalWeather = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .tracking(-0.65)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }
                .layoutPriority(1)

                Spacer(minLength: 20)

                HStack(alignment: .center, spacing: 8) {
                    if showEnableLocalWeather {
                        enableLocalWeatherPill
                    } else {
                        WeekFitWeatherBadge(state: badgeState) {
                            if !reduceMotion {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    badgeTapScale = 0.92
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        badgeTapScale = 1.0
                                    }
                                }
                            }
                            showWeatherSheet = true
                        }
                        .scaleEffect(badgeTapScale)
                    }

                    WeekFitAvatarButton(
                        initials: initials,
                        hasProfileName: hasProfileName,
                        action: onAvatarTap
                    )
                    .accessibilityIdentifier("settings.open")
                }
            }
            .frame(minHeight: 48)
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true

            Task {
                let provider = WeekFitWeatherProvider.shared
                let (cached, isFresh) = await provider.cachedSummaryAndFreshness()

                if let cached {
                    showEnableLocalWeather = false
                    badgeState = .loaded(cached)

                    guard !isFresh else { return }

                    // Cached exists; permission is expected to already be in a usable state.
                    let fresh = await provider.refreshWeather()
                    badgeState = fresh.map { .loaded($0) } ?? .loaded(cached)
                    return
                }

                // No cached weather: keep Today usable without prompting for location.
                badgeState = .hidden
                showEnableLocalWeather = false

                switch CLLocationManager.authorizationStatus() {
                case .notDetermined:
                    // Do not trigger the system prompt silently.
                    showEnableLocalWeather = true
                case .authorizedWhenInUse, .authorizedAlways:
                    badgeState = .loading
                    let fresh = await provider.refreshWeather()
                    badgeState = fresh.map { .loaded($0) } ?? .hidden
                default:
                    // Denied / restricted / unknown: hide badge.
                    showEnableLocalWeather = false
                    badgeState = .hidden
                }
            }
        }
        .sheet(isPresented: $showWeatherSheet) {
            if case .loaded(let summary) = badgeState {
                WeekFitWeatherDetailSheet(summary: summary)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .weekFitSheetChrome(cornerRadius: 28)
            }
        }
    }

    private var enableLocalWeatherPill: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showEnableLocalWeather = false
            badgeState = .loading

            Task {
                let provider = WeekFitWeatherProvider.shared
                let fresh = await provider.refreshWeather()
                badgeState = fresh.map { .loaded($0) } ?? .hidden
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.primaryText)

                Text(WeekFitUsesRussianLanguage() ? "Включить погоду" : "Enable Local Weather")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(WeekFitTheme.cardTertiary.opacity(0.35))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(WeekFitTheme.borderSoft.opacity(0.9), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
            }
            .accessibilityLabel(
                Text(WeekFitUsesRussianLanguage() ? "Включить местную погоду" : "Enable Local Weather")
            )
            .accessibilityHint(
                Text(WeekFitUsesRussianLanguage()
                    ? "Запросит разрешение на использование геолокации."
                    : "Requests When In Use location permission.")
            )
        }
        .buttonStyle(.plain)
    }
}
