import SwiftUI
import HealthKit
import UIKit

struct HealthAccessView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthManager: HealthManager
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("weekfit.healthAccessRequested")
    private var healthAccessRequested = false

    @State private var accessState: HealthAccessState
    @State private var didAppear = false
    @State private var contentVisible = false
    @State private var buttonPressed = false

    private enum HealthAccessState {
        case notRequested
        case requesting
        case connected
        case needsSettings
        case unavailable
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
                            .padding(.top, 10)

                        benefitSection
                            .padding(.top, 2)

                        privacySection
                            .padding(.top, 2)

                        actionSection
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
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
        .task {
            guard !didAppear else { return }
            didAppear = true
            refreshStateWithoutAnimation()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                contentVisible = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshStateWithoutAnimation()
        }
        // MARK: 🛠 ИСПРАВЛЕНО: Мгновенная реактивная перестройка экрана при изменении прав в HealthManager
        .onChange(of: healthManager.isHealthAccessGranted) { _, _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                refreshStateWithAnimation()
            }
        }
    }
}

// MARK: - Layout

private extension HealthAccessView {

    var backgroundLayer: some View {
        ZStack {
            WeekFitTheme.background

            RadialGradient(
                colors: [
                    softGreen.opacity(0.07),
                    softGreen.opacity(0.018),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 390
            )
            .offset(x: 90, y: -110)

            RadialGradient(
                colors: [
                    WeekFitTheme.meal.opacity(0.055),
                    WeekFitTheme.meal.opacity(0.014),
                    .clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 430
            )
            .offset(x: -120, y: -90)

            LinearGradient(
                colors: [
                    .white.opacity(0.014),
                    .clear,
                    .black.opacity(0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    var topBar: some View {
        ZStack {
            Text("Apple Health")
                .font(.system(size: 17, weight: .semibold))
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
                .accessibilityLabel("Back")

                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    var heroSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 14) {
                appleHealthIcon

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(heroTitle)
                            .font(.system(size: 21, weight: .bold))
                            .tracking(-0.45)
                            .foregroundStyle(WeekFitTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .allowsTightening(true)

                        if accessState == .connected {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(softGreen)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Text(heroSubtitle)
                        .font(.system(size: 14.2, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.68))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)
            }

            statusPill
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroCardBackground)
        .overlay(heroCardBorder)
        .shadow(color: .black.opacity(0.25), radius: 20, y: 14)
    }

    var heroCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.cardSecondary.opacity(0.90),
                            WeekFitTheme.cardBackground.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 30)
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

            RoundedRectangle(cornerRadius: 30)
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.045),
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
        RoundedRectangle(cornerRadius: 30)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0.13),
                        .white.opacity(0.045),
                        softGreen.opacity(accessState == .connected ? 0.16 : 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    var appleHealthIcon: some View {
        ZStack {
            Circle()
                .fill(softGreen.opacity(0.12))
                .frame(width: 66, height: 66)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.98),
                            .white.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.20), radius: 12, y: 7)

            Image(systemName: "heart.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.95),
                            Color.pink.opacity(0.80)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .accessibilityHidden(true)
    }

    var statusPill: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 12, weight: .bold))

            Text(statusText)
                .font(.system(size: 13.2, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)
        }
        .foregroundStyle(statusTint)
        .padding(.horizontal, 13)
        .frame(height: 30)
        .background(
            Capsule()
                .fill(statusTint.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(statusTint.opacity(0.18), lineWidth: 1)
        )
    }

    var benefitSection: some View {
        VStack(spacing: 11) {
            sectionHeader(title: "What becomes more personal", subtitle: "WeekFit adapts using activity and recovery patterns.")

            benefitRow(
                icon: "figure.walk",
                title: "Activity-aware planning",
                subtitle: "Steps, workouts and active energy help WeekFit understand how hard your day really was.",
                tint: softGreen,
                tintOpacity: 0.14
            )

            benefitRow(
                icon: "flame.fill",
                title: "Better calorie accuracy",
                subtitle: "Your meal targets can react to movement instead of staying static.",
                tint: Color.orange.opacity(0.92),
                tintOpacity: 0.12
            )

            benefitRow(
                icon: "moon.fill",
                title: "Recovery context",
                subtitle: "Sleep and recovery data help balance training, food and daily intensity.",
                tint: Color.purple.opacity(0.92),
                tintOpacity: 0.13
            )
        }
    }

    func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.25)
                    .foregroundStyle(WeekFitTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.56))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    var privacySection: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(softGreen.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(softGreen)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Private by design")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(WeekFitTheme.primaryText.opacity(0.94))

                Text("You choose what to share. Permissions stay managed by Apple Health.")
                    .font(.system(size: 12.8, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.cardBackground.opacity(0.56),
                            WeekFitTheme.cardBackground.opacity(0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.055), lineWidth: 1)
        )
    }

    var actionSection: some View {
        VStack(spacing: 10) {
            Button {
                handleHealthButtonTap()
            } label: {
                HStack(spacing: 10) {
                    Spacer(minLength: 0)

                    if accessState == .requesting {
                        ProgressView()
                            .scaleEffect(0.66)
                            .tint(softGreen.opacity(0.86))
                    } else {
                        Image(systemName: actionIcon)
                            .font(.system(size: 14, weight: .bold))
                    }

                    Text(actionTitle)
                        .font(.system(size: 14.1, weight: .bold))
                        .tracking(-0.08)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 0)
                }
                .foregroundStyle(softGreen.opacity(0.92))
                .frame(maxWidth: .infinity)
                .frame(height: 43)
                .weekFitMealActionBackground(softGreen)
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

            // РАЗБЛОКИРОВАНО: Красивая кнопка "Done" появляется для быстрого закрытия, когда статус подключен!
            if accessState == .connected {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(softGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Components

private extension HealthAccessView {

    func benefitRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        tintOpacity: Double
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(tintOpacity))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15.8, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.primaryText.opacity(0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .allowsTightening(true)

                Text(subtitle)
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.62))
                    .lineSpacing(1.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: [
                                WeekFitTheme.cardBackground.opacity(0.72),
                                WeekFitTheme.cardBackground.opacity(0.48)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        RadialGradient(
                            colors: [
                                tint.opacity(0.045),
                                .clear
                            ],
                            center: .leading,
                            startRadius: 8,
                            endRadius: 190
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.075),
                            .white.opacity(0.026),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Text / State

private extension HealthAccessView {

    var softGreen: Color {
        Color(red: 0.55, green: 0.80, blue: 0.58)
    }

    var heroGlowOpacity: Double {
        switch accessState {
        case .connected: return 0.16
        case .needsSettings: return 0.09
        case .requesting: return 0.12
        case .notRequested: return 0.11
        case .unavailable: return 0.04
        }
    }

    var statusTint: Color {
        switch accessState {
        case .connected: return softGreen
        case .needsSettings: return Color.orange.opacity(0.90)
        case .requesting: return softGreen
        case .unavailable: return Color.red.opacity(0.82)
        case .notRequested: return softGreen
        }
    }

    var statusIcon: String {
        switch accessState {
        case .connected: return "checkmark.seal.fill"
        case .needsSettings: return "slider.horizontal.3"
        case .requesting: return "heart.fill"
        case .unavailable: return "exclamationmark.triangle.fill"
        case .notRequested: return "sparkles"
        }
    }

    var statusText: String {
        switch accessState {
        case .connected: return "Health data is connected"
        case .needsSettings: return "Review permissions in Settings"
        case .requesting: return "Waiting for Apple Health confirmation"
        case .unavailable: return "HealthKit is unavailable on this device"
        case .notRequested: return "Connect once. WeekFit gets smarter every day."
        }
    }

    var heroTitle: String {
        switch accessState {
        case .connected: return "Health is connected"
        case .needsSettings: return "Permission needed"
        case .unavailable: return "Health unavailable"
        case .requesting: return "Opening Health"
        case .notRequested: return "Connect Apple Health"
        }
    }

    var heroSubtitle: String {
        switch accessState {
        case .connected: return "WeekFit can use activity and recovery signals to personalize your daily plan."
        case .needsSettings: return "Allow steps, workouts, active energy and sleep to unlock smarter guidance."
        case .unavailable: return "This device does not support Apple Health data access."
        case .requesting: return "Confirm access in Apple Health, then return to WeekFit."
        case .notRequested: return "Let WeekFit adapt meals, calories and recovery guidance to your real day."
        }
    }

    var actionTitle: String {
        switch accessState {
        case .notRequested: return "Connect Apple Health"
        case .requesting: return "Opening Apple Health..."
        case .connected, .needsSettings: return "Open Health Settings"
        case .unavailable: return "Health Unavailable"
        }
    }

    var actionIcon: String {
        switch accessState {
        case .connected, .needsSettings, .requesting, .notRequested: return "heart.fill"
        case .unavailable: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - HealthKit

// MARK: - HealthKit (ИСПРАВЛЕНО: Асинхронный проброс реального статуса чтения данных)

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
            // 1. Вызываем нативное окно Apple Health с галочками
            await healthManager.requestAuthorization()
            
            // 2. Делаем тестовое микро-чтение, чтобы узнать реальный выбор пользователя
            let isRealGranted = await healthManager.checkReadAuthorizationStatus()
            
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    // Обновляем глобальный менеджер и локальный стейт экрана
                    healthManager.isHealthAccessGranted = isRealGranted
                    if isRealGranted {
                        accessState = .connected
                    } else {
                        accessState = .needsSettings
                    }
                }
            }
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

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
