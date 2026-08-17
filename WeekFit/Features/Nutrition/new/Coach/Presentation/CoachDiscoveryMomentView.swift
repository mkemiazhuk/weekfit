import SwiftUI

/// Standalone Discovery spotlight under the Coach card — short-lived Tell moment with entrance/exit motion.
struct CoachDiscoverySpotlightSection: View {

    let offer: CoachDiscoveryOffer
    let onDismissed: () -> Void

    @State private var phase: Phase = .hidden
    @State private var glowPulse = false
    @State private var dismissTask: Task<Void, Never>?

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let accent = WeekFitTheme.coachAccent

    private enum Phase {
        case hidden
        case visible
        case exiting
    }

    private var content: CoachDiscoveryCopy.Content {
        CoachDiscoveryCopy.content(for: offer)
    }

    private var valence: CoachDiscoveryValence {
        offer.beliefID.discoveryValence
    }

    private var valenceAccent: Color {
        switch valence {
        case .positive:
            return accent
        case .caution:
            return Color(red: 0.78, green: 0.52, blue: 0.28)
        case .neutral:
            return accent.opacity(0.85)
        }
    }

    private var symbolName: String {
        switch offer.beliefID.discoveryFamily {
        case .sleep:
            return "moon.stars.fill"
        case .training:
            return "figure.run"
        case .nutrition:
            return "fork.knife"
        case .timing:
            return "clock.fill"
        }
    }

    var body: some View {
        Group {
            if phase != .hidden {
                spotlightCard
                    .opacity(phase == .visible ? 1 : 0)
                    .offset(y: phase == .visible ? 0 : 18)
                    .scaleEffect(phase == .visible ? 1 : 0.96)
                    .accessibilityIdentifier("coach.discovery.spotlight")
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(CoachDiscoveryCopy.noticedEyebrow). \(content.title). \(content.body)")
            }
        }
        .onAppear {
            if phase == .hidden {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    phase = .visible
                }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
            if phase != .exiting {
                scheduleAutoDismiss()
            }
        }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
    }

    private var spotlightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                symbolBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(CoachDiscoveryCopy.noticedEyebrow)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(valenceAccent.opacity(0.92))

                    Text(CoachDiscoveryCopy.familyLabel(for: offer.beliefID.discoveryFamily).uppercased())
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(textSecondary.opacity(0.42))
                }

                Spacer(minLength: 8)

                Button(action: dismissNow) {
                    Text(CoachDiscoveryCopy.gotItAction)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary.opacity(0.72))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(WeekFitTheme.cardBackground.opacity(0.72))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(textSecondary.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coach.discovery.spotlight.dismiss")
            }

            Text(content.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
                .tracking(-0.4)
                .fixedSize(horizontal: false, vertical: true)

            Text(content.body)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.86))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(content.proof)
                .font(.system(size: 12.5, weight: .regular, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(WeekFitTheme.cardBackground)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                valenceAccent.opacity(glowPulse ? 0.16 : 0.08),
                                valenceAccent.opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Soft watermark
                Image(systemName: "sparkles")
                    .font(.system(size: 84, weight: .light))
                    .foregroundStyle(valenceAccent.opacity(glowPulse ? 0.10 : 0.05))
                    .offset(x: 96, y: -8)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            valenceAccent.opacity(glowPulse ? 0.42 : 0.22),
                            valenceAccent.opacity(0.08),
                            valenceAccent.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .shadow(color: valenceAccent.opacity(glowPulse ? 0.18 : 0.08), radius: glowPulse ? 22 : 14, y: 8)
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
    }

    private var symbolBadge: some View {
        ZStack {
            Circle()
                .fill(valenceAccent.opacity(0.14))
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .stroke(valenceAccent.opacity(0.22), lineWidth: 1)
                }
                .scaleEffect(glowPulse ? 1.05 : 1.0)

            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(valenceAccent)
        }
        .accessibilityHidden(true)
    }

    private func scheduleAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 7_500_000_000)
            guard !Task.isCancelled else { return }
            dismissNow()
        }
    }

    private func dismissNow() {
        dismissTask?.cancel()
        dismissTask = nil
        guard phase == .visible else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.38)) {
            phase = .exiting
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 380_000_000)
            phase = .hidden
            onDismissed()
        }
    }
}
