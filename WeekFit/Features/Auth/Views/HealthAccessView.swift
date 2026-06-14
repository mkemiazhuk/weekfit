import SwiftUI
import HealthKit
import UIKit
import WatchConnectivity

struct HealthAccessView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthManager: HealthManager
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("weekfit.healthAccessRequested")
    private var healthAccessRequested = false

    @AppStorage("weekfit.lastHealthReadinessSync")
    private var lastReadinessSyncTimestamp: Double = 0

    @State private var accessState: HealthAccessState
    @State private var readiness = HealthReadiness.snapshot()
    @State private var didAppear = false
    @State private var contentVisible = false
    @State private var buttonPressed = false
    @State private var showSleepHelp = false

    private let healthStore = HKHealthStore()

    private enum HealthAccessState {
        case notRequested
        case requesting
        case connected
        case needsSettings
        case unavailable
    }

    private struct HealthReadiness {
        var isWatchPaired: Bool = false
        var isWatchAppInstalled: Bool = false
        var hasRecentWorkout: Bool = false
        var hasRecentSleep: Bool = false
        var hasRecentHeartRate: Bool = false
        var backgroundRefreshEnabled: Bool = false
        var lastSyncDate: Date?

        static func snapshot() -> HealthReadiness {
            HealthReadiness()
        }

        var qualityScore: Int {
            var score = 0

            if isWatchPaired || hasRecentHeartRate || hasRecentSleep {
                score += 1
            }

            if hasRecentWorkout {
                score += 1
            }

            if hasRecentHeartRate {
                score += 1
            }

            if hasRecentSleep {
                score += 1
            }

            if backgroundRefreshEnabled {
                score += 1
            }

            return score
        }

        var qualityLabel: String {
            if qualityScore >= 4 && hasRecentSleep {
                return "Excellent"
            }

            if qualityScore >= 3 {
                return "Good"
            }

            if qualityScore >= 2 {
                return "Partial"
            }

            return "Setup needed"
        }

        var qualityTint: Color {
            if qualityScore >= 4 && hasRecentSleep {
                return Color(red: 0.55, green: 0.80, blue: 0.58)
            }

            if qualityScore >= 3 {
                return Color(red: 0.78, green: 0.66, blue: 0.48)
            }

            if qualityScore >= 2 {
                return Color(red: 0.78, green: 0.60, blue: 0.38)
            }

            return Color(red: 0.74, green: 0.42, blue: 0.42)
        }
    }

    init() {
        if !HKHealthStore.isHealthDataAvailable() {
            _accessState = State(initialValue: .unavailable)
        } else {
            _accessState = State(initialValue: .notRequested)
        }
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroSection
                            .padding(.top, 8)

                        readinessSection

                        enablementSection

                        actionSection
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 6)
                    .animation(
                        .interpolatingSpring(stiffness: 190, damping: 26),
                        value: contentVisible
                    )
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .transaction { $0.animation = nil }
        .sheet(isPresented: $showSleepHelp) {
            SleepSetupHelpSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .task {
            guard !didAppear else { return }
            didAppear = true

            refreshStateWithoutAnimation()
            await refreshReadiness()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                contentVisible = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            refreshStateWithoutAnimation()

            Task {
                await refreshReadiness()
            }
        }
        .onChange(of: healthManager.isHealthAccessGranted) { _, _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                refreshStateWithAnimation()
            }

            Task {
                await refreshReadiness()
            }
        }
    }
}

// MARK: - Layout

private extension HealthAccessView {

    var backgroundLayer: some View {
        ZStack {
            WeekFitTheme.backgroundColor

            RadialGradient(
                colors: [
                    softGreen.opacity(0.016),
                    softGreen.opacity(0.004),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 390
            )
            .offset(x: 90, y: -110)

            RadialGradient(
                colors: [
                    softBlue.opacity(0.018),
                    softBlue.opacity(0.005),
                    .clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 430
            )
            .offset(x: -120, y: -90)

            LinearGradient(
                colors: [
                    .white.opacity(0.008),
                    .clear,
                    .black.opacity(0.30)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    var topBar: some View {
        ZStack {
            Text(WeekFitLocalizedString("healthAccess.healthSignals"))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText.opacity(0.92))

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .frame(width: 46, height: 46)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            WeekFitTheme.cardBackground.opacity(0.82),
                                            WeekFitTheme.cardSecondary.opacity(0.58)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.075), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.24), radius: 14, y: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(AppText.Common.Action.back))

                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    var heroSection: some View {
        HStack(alignment: .center, spacing: 15) {
            appleHealthIcon

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(heroTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .tracking(-0.35)
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)

                    if accessState == .connected {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(softGreen.opacity(0.88))
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(heroSubtitle)
                    .font(.system(size: 13.2, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.64))
                    .lineSpacing(2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroCardBackground)
        .overlay(heroCardBorder)
        .shadow(color: .black.opacity(0.20), radius: 16, y: 10)
    }

    var heroCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.cardBackground.opacity(0.70),
                            WeekFitTheme.cardBackground.opacity(0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            softGreen.opacity(heroGlowOpacity),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 230
                    )
                )

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.020),
                            .clear
                        ],
                        center: .topTrailing,
                        startRadius: 20,
                        endRadius: 220
                    )
                )
        }
    }

    var heroCardBorder: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0.082),
                        .white.opacity(0.034),
                        softGreen.opacity(accessState == .connected ? 0.060 : 0.026)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    var appleHealthIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.99),
                            Color(red: 0.96, green: 0.96, blue: 0.97)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 54, height: 54)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(.white.opacity(0.55), lineWidth: 0.8)
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.34),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 16)
                        .blur(radius: 1)
                }
                .shadow(
                    color: .black.opacity(0.16),
                    radius: 10,
                    y: 6
                )

            Image(systemName: "heart.fill")
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.25, blue: 0.55),
                            Color(red: 1.0, green: 0.12, blue: 0.32)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(
                    color: Color(red: 1.0, green: 0.20, blue: 0.45).opacity(0.16),
                    radius: 3,
                    y: 1
                )
                .offset(x: 3.5, y: -3.5)
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }
    
    
    var readinessSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text(WeekFitLocalizedString("healthAccess.signalReadiness"))
                    .font(.system(size: 13.6, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText.opacity(0.92))

                Spacer()

                qualityBadge
            }
            .padding(.bottom, 2)

            readinessRow(
                icon: "applewatch",
                title: "Apple Watch",
                status: watchStatusText,
                tint: statusTint(for: watchStatusKind),
                kind: watchStatusKind
            )

            readinessRow(
                icon: "figure.run",
                title: "Workout sync",
                status: workoutStatusText,
                tint: statusTint(for: workoutStatusKind),
                kind: workoutStatusKind
            )

            readinessRow(
                icon: "heart.text.square.fill",
                title: "Heart data",
                status: heartRateStatusText,
                tint: statusTint(for: heartRateStatusKind),
                kind: heartRateStatusKind
            )

            readinessRow(
                icon: "moon.fill",
                title: "Sleep data",
                status: sleepStatusText,
                tint: statusTint(for: sleepStatusKind),
                kind: sleepStatusKind,
                showInfo: accessState == .connected && !readiness.hasRecentSleep
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showSleepHelp = true
            }

            readinessRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Last sync",
                status: syncStatusText,
                tint: statusTint(for: syncStatusKind),
                kind: syncStatusKind
            )
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(sectionCardBackground(cornerRadius: 24, opacity: 0.48))
    }

    var qualityBadge: some View {
        Text(readiness.qualityLabel)
            .font(.system(size: 12.1, weight: .bold, design: .rounded))
            .foregroundStyle(readiness.qualityTint.opacity(0.86))
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(
                Capsule()
                    .fill(readiness.qualityTint.opacity(0.060))
            )
            .overlay(
                Capsule()
                    .stroke(readiness.qualityTint.opacity(0.105), lineWidth: 1)
            )
    }

    func readinessRow(
        icon: String,
        title: String,
        status: String,
        tint: Color,
        kind: StatusKind,
        showInfo: Bool = false,
        infoAction: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.045))
                    .frame(width: 29, height: 29)

                Image(systemName: icon)
                    .font(.system(size: 12.4, weight: .bold))
                    .foregroundStyle(readinessIconTint(for: kind))
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 13.7, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText.opacity(0.92))
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 7) {
                if showInfo, let infoAction {
                    Button {
                        infoAction()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(tint.opacity(0.66))
                            .frame(width: 23, height: 23)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.040))
                            )
                            .overlay(
                                Circle()
                                    .stroke(tint.opacity(0.075), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(WeekFitLocalizedString("healthAccess.sleepSetupHelp")))
                }

                HStack(spacing: 5) {
                    if kind == .positive {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(softGreen.opacity(0.82))
                    }

                    Text(status)
                        .font(.system(size: 11.7, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusTextTint(for: kind))
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                }
                .frame(height: 23)
            }
        }
        .frame(height: 34)
    }
    
    func statusTextTint(for kind: StatusKind) -> Color {
        switch kind {
        case .positive:
            return Color.white.opacity(0.58)
        case .neutral:
            return Color.white.opacity(0.46)
        case .warning:
            return softAmber.opacity(0.82)
        case .danger:
            return softRose.opacity(0.82)
        }
    }

    var enablementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("healthAccess.whatThisEnables"))
                .font(.system(size: 13.6, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText.opacity(0.92))
                .padding(.horizontal, 2)

            VStack(spacing: 8) {
                compactBenefitRow(
                    icon: "sparkles",
                    title: "Smarter daily planning",
                    subtitle: "Your plan reacts to workouts, steps and recovery.",
                    tint: softBlue
                )

                compactBenefitRow(
                    icon: "flame.fill",
                    title: "Adaptive calorie targets",
                    subtitle: "Calories adjust after real activity.",
                    tint: Color.orange.opacity(0.86)
                )

                compactBenefitRow(
                    icon: "lock.fill",
                    title: "Private by design",
                    subtitle: "Permissions stay managed by Apple Health.",
                    tint: softGreen
                )
            }
        }
    }

    func compactBenefitRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.082))
                    .frame(width: 37, height: 37)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint.opacity(0.86))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.2, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                Text(subtitle)
                    .font(.system(size: 12.2, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.54))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(sectionCardBackground(cornerRadius: 22, opacity: 0.44))
    }

    func sectionCardBackground(
        cornerRadius: CGFloat,
        opacity: Double = 0.48
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        WeekFitTheme.cardBackground.opacity(opacity),
                        WeekFitTheme.cardBackground.opacity(opacity * 0.74)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.043), lineWidth: 1)
            )
    }

    var actionSection: some View {
        Button {
            handleHealthButtonTap()
        } label: {
            HStack(spacing: 8) {
                Spacer(minLength: 0)

                if accessState == .requesting {
                    ProgressView()
                        .scaleEffect(0.66)
                        .tint(actionTint.opacity(0.68))
                } else {
                    Image(systemName: actionIcon)
                        .font(.system(size: 13.5, weight: .bold))
                }

                Text(actionTitle)
                    .font(.system(size: 13.8, weight: .bold, design: .rounded))
                    .tracking(-0.05)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .foregroundStyle(actionTint.opacity(0.68))
            .frame(maxWidth: .infinity)
            .frame(height: 43)
            .background(
                Capsule()
                    .fill(actionTint.opacity(actionFillOpacity))
            )
            .overlay(
                Capsule()
                    .stroke(actionTint.opacity(actionStrokeOpacity), lineWidth: 1)
            )
            .scaleEffect(buttonPressed ? 0.985 : 1)
        }
        .buttonStyle(.plain)
        .disabled(accessState == .requesting || accessState == .unavailable)
        .opacity(accessState == .unavailable ? 0.55 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in buttonPressed = true }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                        buttonPressed = false
                    }
                }
        )
        .accessibilityLabel(actionTitle)
    }
}

// MARK: - Dynamic Text

private extension HealthAccessView {

    enum StatusKind {
        case positive
        case neutral
        case warning
        case danger
    }

    var softGreen: Color {
        Color(red: 0.55, green: 0.80, blue: 0.58)
    }

    var softBlue: Color {
        Color(red: 0.56, green: 0.66, blue: 0.82)
    }

    var softRose: Color {
        Color(red: 0.82, green: 0.45, blue: 0.54)
    }

    var softAmber: Color {
        Color(red: 0.78, green: 0.60, blue: 0.38)
    }

    var neutralTint: Color {
        Color.white.opacity(0.56)
    }

    func statusTint(for kind: StatusKind) -> Color {
        switch kind {
        case .positive:
            return softGreen
        case .neutral:
            return neutralTint
        case .warning:
            return softAmber
        case .danger:
            return softRose
        }
    }

    func readinessIconTint(for kind: StatusKind) -> Color {
        switch kind {
        case .positive:
            return Color.white.opacity(0.62)
        case .neutral:
            return Color.white.opacity(0.46)
        case .warning:
            return softAmber.opacity(0.72)
        case .danger:
            return softRose.opacity(0.72)
        }
    }

    var watchStatusKind: StatusKind {
        guard accessState == .connected else { return .neutral }

        return readiness.isWatchPaired || readiness.hasRecentHeartRate || readiness.hasRecentSleep || readiness.hasRecentWorkout
            ? .positive
            : .warning
    }

    var workoutStatusKind: StatusKind {
        guard accessState == .connected else { return .neutral }
        return readiness.hasRecentWorkout ? .positive : .warning
    }

    var heartRateStatusKind: StatusKind {
        guard accessState == .connected else { return .neutral }
        return readiness.hasRecentHeartRate ? .positive : .warning
    }

    var sleepStatusKind: StatusKind {
        guard accessState == .connected else { return .neutral }
        return readiness.hasRecentSleep ? .positive : .warning
    }

    var syncStatusKind: StatusKind {
        accessState == .connected ? .positive : .neutral
    }

    var watchStatusText: String {
        guard accessState == .connected else { return "After access" }

        if readiness.isWatchPaired {
            return "Paired"
        }

        if readiness.hasRecentHeartRate || readiness.hasRecentSleep || readiness.hasRecentWorkout {
            return "Data found"
        }

        return "Not detected"
    }

    var workoutStatusText: String {
        guard accessState == .connected else { return "Needs access" }
        return readiness.hasRecentWorkout ? "Ready" : "No workout"
    }

    var heartRateStatusText: String {
        guard accessState == .connected else { return "Needs access" }
        return readiness.hasRecentHeartRate ? "Available" : "Missing"
    }

    var sleepStatusText: String {
        guard accessState == .connected else { return "Needs access" }
        return readiness.hasRecentSleep ? "Available" : "Needs setup"
    }

    var syncStatusText: String {
        guard accessState == .connected else { return "Not synced" }
        return formattedLastSync(readiness.lastSyncDate)
    }

    func formattedLastSync(_ date: Date?) -> String {
        guard let date else { return "Not synced yet" }

        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "Just now"
        }

        let minutes = seconds / 60

        if minutes < 60 {
            return "\(minutes)m ago"
        }

        let hours = minutes / 60

        if hours < 24 {
            return "\(hours)h ago"
        }

        return "Needs refresh"
    }
}

// MARK: - Text / State

private extension HealthAccessView {

    var heroGlowOpacity: Double {
        switch accessState {
        case .connected: return 0.026
        case .needsSettings: return 0.020
        case .requesting: return 0.022
        case .notRequested: return 0.022
        case .unavailable: return 0.014
        }
    }

    var heroTitle: String {
        switch accessState {
        case .connected:
            return "Health signals active"
        case .needsSettings:
            return "Health needs access"
        case .unavailable:
            return "Health unavailable"
        case .requesting:
            return "Opening Health"
        case .notRequested:
            return "Connect Health Signals"
        }
    }

    var heroSubtitle: String {
        switch accessState {
        case .connected:
            return connectedHeroSubtitle
        case .needsSettings:
            return "Allow workouts, sleep, heart data and steps to unlock smarter guidance."
        case .unavailable:
            return "This device does not support Apple Health data access."
        case .requesting:
            return "Confirm access in Apple Health, then return to WeekFit."
        case .notRequested:
            return "Let WeekFit adapt planning, calories and recovery to your real day."
        }
    }

    var connectedHeroSubtitle: String {
        let score = readiness.qualityScore

        if score >= 4 && readiness.hasRecentSleep {
            return "Sleep, workouts and recovery are connected."
        }

        if score >= 3 {
            return "WeekFit can personalize your plan. Sleep may need setup."
        }

        if score >= 2 {
            return "Some signals are connected. A few sources still need attention."
        }

        return "Health is connected, but WeekFit needs more data for better insights."
    }

    var actionTitle: String {
        switch accessState {
        case .notRequested:
            return "Connect Health Signals"
        case .requesting:
            return "Opening Apple Health..."
        case .connected, .needsSettings:
            return "Manage in Apple Health"
        case .unavailable:
            return "Health Unavailable"
        }
    }

    var actionIcon: String {
        switch accessState {
        case .connected, .needsSettings:
            return "slider.horizontal.3"
        case .requesting, .notRequested:
            return "heart.fill"
        case .unavailable:
            return "exclamationmark.triangle.fill"
        }
    }

    var actionTint: Color {
        switch accessState {
        case .connected:
            return softGreen
        case .needsSettings:
            return softAmber
        case .notRequested, .requesting:
            return softGreen
        case .unavailable:
            return neutralTint
        }
    }

    var actionFillOpacity: Double {
        switch accessState {
        case .connected:
            return 0.030
        case .needsSettings:
            return 0.052
        case .notRequested, .requesting:
            return 0.074
        case .unavailable:
            return 0.034
        }
    }

    var actionStrokeOpacity: Double {
        switch accessState {
        case .connected:
            return 0.075
        case .needsSettings:
            return 0.11
        case .notRequested, .requesting:
            return 0.13
        case .unavailable:
            return 0.07
        }
    }
}

// MARK: - HealthKit / Readiness

private extension HealthAccessView {

    func handleHealthButtonTap() {
        switch accessState {
        case .notRequested:
            requestHealthAccess()
        case .connected, .needsSettings:
            openAppSettings()
        case .requesting, .unavailable:
            break
        }
    }

    func requestHealthAccess() {
        guard HKHealthStore.isHealthDataAvailable() else {
            accessState = .unavailable
            return
        }

        accessState = .requesting
        healthAccessRequested = true

        Task {
            await healthManager.requestAuthorization()

            let isRealGranted = await healthManager.checkReadAuthorizationStatus()

            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    healthManager.isHealthAccessGranted = isRealGranted
                    accessState = isRealGranted ? .connected : .needsSettings
                }
            }

            await refreshReadiness()
        }
    }

    func refreshStateWithoutAnimation() {
        Task {
            let isRealGranted = await healthManager.checkReadAuthorizationStatus()

            await MainActor.run {
                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    healthManager.isHealthAccessGranted = isRealGranted

                    if isRealGranted {
                        accessState = .connected
                    } else if healthAccessRequested {
                        accessState = .needsSettings
                    } else {
                        accessState = .notRequested
                    }
                }
            }
        }
    }

    func refreshStateWithAnimation() {
        Task {
            let isRealGranted = await healthManager.checkReadAuthorizationStatus()

            await MainActor.run {
                healthManager.isHealthAccessGranted = isRealGranted

                if isRealGranted {
                    accessState = .connected
                } else if healthAccessRequested {
                    accessState = .needsSettings
                } else {
                    accessState = .notRequested
                }
            }
        }
    }

    func refreshReadiness() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            await MainActor.run {
                readiness = HealthReadiness.snapshot()
            }
            return
        }

        let isGranted = await healthManager.checkReadAuthorizationStatus()

        let watchInfo = await readWatchInfo()
        let backgroundEnabled = await readBackgroundRefreshStatus()

        async let workoutAvailableTask = hasRecentWorkoutSample()
        async let sleepAvailableTask = hasRecentSleepSample()
        async let heartRateAvailableTask = hasRecentHeartRateSample()

        let workoutAvailable = await workoutAvailableTask
        let sleepAvailable = await sleepAvailableTask
        let heartRateAvailable = await heartRateAvailableTask

        let nextReadiness = HealthReadiness(
            isWatchPaired: watchInfo.isPaired,
            isWatchAppInstalled: watchInfo.isAppInstalled,
            hasRecentWorkout: isGranted && workoutAvailable,
            hasRecentSleep: isGranted && sleepAvailable,
            hasRecentHeartRate: isGranted && heartRateAvailable,
            backgroundRefreshEnabled: backgroundEnabled,
            lastSyncDate: isGranted ? Date() : nil
        )

        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                readiness = nextReadiness
                lastReadinessSyncTimestamp = nextReadiness.lastSyncDate?.timeIntervalSince1970 ?? 0
            }
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Dynamic Checks

private extension HealthAccessView {

    func readWatchInfo() async -> (isPaired: Bool, isAppInstalled: Bool) {
        await MainActor.run {
            guard WCSession.isSupported() else {
                return (false, false)
            }

            let session = WCSession.default

            guard session.activationState == .activated else {
                return (false, false)
            }

            guard session.isPaired else {
                return (false, false)
            }

            guard session.isWatchAppInstalled else {
                return (true, false)
            }

            return (true, true)
        }
    }

    func readBackgroundRefreshStatus() async -> Bool {
        await MainActor.run {
            UIApplication.shared.backgroundRefreshStatus == .available
        }
    }

    func hasRecentWorkoutSample() async -> Bool {
        let workoutType = HKObjectType.workoutType()

        return await hasSample(
            type: workoutType,
            since: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        )
    }

    func hasRecentSleepSample() async -> Bool {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return false
        }

        return await hasSample(
            type: sleepType,
            since: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        )
    }

    func hasRecentHeartRateSample() async -> Bool {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return false
        }

        return await hasSample(
            type: heartRateType,
            since: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        )
    }

    func hasSample(type: HKSampleType, since startDate: Date) async -> Bool {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: Date(),
                options: .strictStartDate
            )

            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                ]
            ) { _, samples, error in
                if error != nil {
                    continuation.resume(returning: false)
                    return
                }

                continuation.resume(returning: !(samples?.isEmpty ?? true))
            }

            healthStore.execute(query)
        }
    }
}

// MARK: - Sleep Help Sheet

private struct SleepSetupHelpSheet: View {

    @Environment(\.dismiss) private var dismiss

    private let accent = Color(red: 0.78, green: 0.60, blue: 0.38)

    var body: some View {
        ZStack {
            WeekFitTheme.backgroundColor
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    VStack(alignment: .leading, spacing: 12) {
                        Text(WeekFitLocalizedString("healthAccess.setupChecklist"))
                            .font(.system(size: 13.8, weight: .bold, design: .rounded))
                            .foregroundStyle(WeekFitTheme.primaryText.opacity(0.92))

                        sleepSection(
                            icon: "bed.double.fill",
                            title: "Set a Sleep Schedule",
                            detail: "iPhone → Settings → Focus → Sleep\nSet your bedtime and wake-up schedule."
                        )

                        sleepSection(
                            icon: "moon.fill",
                            title: "Enable Sleep Focus",
                            detail: "Use Sleep Focus overnight so Apple can classify sleep correctly."
                        )

                        sleepSection(
                            icon: "applewatch",
                            title: "Turn on Sleep Tracking",
                            detail: "Watch app → Sleep\nEnable Track Sleep with Apple Watch."
                        )

                        sleepSection(
                            icon: "lock.fill",
                            title: "Enable Wrist Detection",
                            detail: "Watch app → Passcode\nTurn on Wrist Detection."
                        )

                        sleepSection(
                            icon: "battery.75percent",
                            title: "Wear the watch overnight",
                            detail: "Keep battery above 30% and avoid Low Power Mode while sleeping."
                        )

                        sleepSection(
                            icon: "list.bullet.rectangle",
                            title: "Still no data?",
                            detail: "Health → Browse → Sleep → Show All Data\nIf no new entries appear, Apple Watch is not recording sleep yet."
                        )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(WeekFitTheme.cardBackground.opacity(0.52))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.046), lineWidth: 1)
                    )

                    Text(WeekFitLocalizedString("healthAccess.sleepStagesAndRecoveryInsightsMayTakeAFew"))
                        .font(.system(size: 12.8, weight: .medium, design: .rounded))
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.60))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        dismiss()
                    } label: {
                        Text(WeekFitLocalizedString("healthAccess.gotIt"))
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(accent.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                Capsule()
                                    .fill(accent.opacity(0.060))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(accent.opacity(0.105), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.080))
                    .frame(width: 54, height: 54)

                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(accent.opacity(0.82))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(WeekFitLocalizedString("healthAccess.sleepDataNotAppearing"))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)

                Text(WeekFitLocalizedString("healthAccess.weekfitReliesOnAppleHealthAndAppleWatchSleep"))
                    .font(.system(size: 13.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.68))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.70))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.06))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.06), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func sleepSection(
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.060))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(accent.opacity(0.80))
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.9, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText.opacity(0.92))

                Text(detail)
                    .font(.system(size: 12.7, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.68))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
