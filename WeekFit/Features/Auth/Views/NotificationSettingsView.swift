import SwiftUI
import SwiftData

enum NotificationPreferenceKey {
    static let activityReminders = "notifications.activityReminders"
    static let completionCheckIns = "notifications.completionCheckIns"
    static let recoverySuggestions = "notifications.recoverySuggestions"
    static let hydrationReminders = "notifications.hydrationReminders"
    static let sleepWindDown = "notifications.sleepWindDown"
}

struct NotificationSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var notificationsAuthorized = false

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    @AppStorage(NotificationPreferenceKey.activityReminders)
    private var activityRemindersEnabled = false

    @AppStorage(NotificationPreferenceKey.completionCheckIns)
    private var completionCheckInsEnabled = false

    @AppStorage(NotificationPreferenceKey.recoverySuggestions)
    private var recoverySuggestionsEnabled = true

    @AppStorage(NotificationPreferenceKey.hydrationReminders)
    private var hydrationRemindersEnabled = false

    @AppStorage(NotificationPreferenceKey.sleepWindDown)
    private var sleepWindDownEnabled = false

    private let background = Color.black
    private let cardBackground = Color(red: 24/255, green: 24/255, blue: 28/255)
    private let rowBackground = Color.white.opacity(0.065)

    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.54)
    private let sectionText = Color.white.opacity(0.34)

    private let accentGreen = Color(red: 170/255, green: 255/255, blue: 70/255)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ambientBackground

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    notificationSection(title: "ACTIVITY") {
                        notificationRow(
                            icon: "figure.run",
                            title: "Activity Reminders",
                            subtitle: "Scheduled activity reminders",
                            isOn: $activityRemindersEnabled
                        )

                        softDivider

                        notificationRow(
                            icon: "checkmark.circle.fill",
                            title: "Completion Check-ins",
                            subtitle: "Confirm completed or skipped",
                            isOn: $completionCheckInsEnabled
                        )
                    }

                    notificationSection(title: "WELLNESS") {
                        notificationRow(
                            icon: "heart.fill",
                            title: "Recovery Suggestions",
                            subtitle: "Guidance after active days",
                            isOn: $recoverySuggestionsEnabled
                        )

                        softDivider

                        notificationRow(
                            icon: "drop.fill",
                            title: "Hydration Reminders",
                            subtitle: "Light nudges to drink water",
                            isOn: $hydrationRemindersEnabled
                        )

//                        softDivider
//
//                        notificationRow(
//                            icon: "moon.fill",
//                            title: "Sleep Wind-down",
//                            subtitle: "Evening reminders to slow down",
//                            isOn: $sleepWindDownEnabled
//                        )
                    }

                    footerNote
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 36)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            refreshNotificationAuthorization()
        }
    }
    
    private func syncNotificationsForExistingActivities() {
        ActivityNotificationService.shared.syncNotifications(
            for: plannedActivities,
            activityRemindersEnabled: activityRemindersEnabled,
            completionCheckInsEnabled: completionCheckInsEnabled
        )
    }
}

private extension NotificationSettingsView {

    var ambientBackground: some View {
        VStack {
            Circle()
                .fill(accentGreen.opacity(0.06))
                .frame(width: 220, height: 220)
                .blur(radius: 120)
                .offset(x: 84, y: 22)

            Spacer()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    var headerSection: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(rowBackground)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.08), lineWidth: 1)
                        }

                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                }
                .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            Text("Notifications")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            Spacer()

            Color.clear
                .frame(width: 48, height: 48)
        }
    }

    func notificationSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(sectionText)
                .tracking(1.1)
                .padding(.horizontal, 8)

            VStack(spacing: 0) {
                content()
            }
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.04), lineWidth: 1)
                    }
            }
        }
    }

    var softDivider: some View {
        Divider()
            .overlay(.white.opacity(0.035))
            .padding(.leading, 68)
    }

    func notificationRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.white.opacity(0.045))

                Image(systemName: icon)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(accentGreen)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(subtitle)
                    .font(.system(size: 13.2, weight: .medium))
                    .foregroundStyle(textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: notificationBinding(isOn))
                .labelsHidden()
                .tint(accentGreen.opacity(0.88))
                .scaleEffect(0.86)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    var footerNote: some View {
        Text("Notifications help WeekFit keep your wellness routine visible without overwhelming your day.")
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.34))
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .padding(.horizontal, 16)
    }
    
    private func refreshNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsAuthorized =
                    settings.authorizationStatus == .authorized ||
                    settings.authorizationStatus == .provisional ||
                    settings.authorizationStatus == .ephemeral

                if !notificationsAuthorized {
                    activityRemindersEnabled = false
                    completionCheckInsEnabled = false
                    hydrationRemindersEnabled = false
                    sleepWindDownEnabled = false
                }
            }
        }
    }
    
    private func notificationBinding(
        _ storage: Binding<Bool>
    ) -> Binding<Bool> {
        Binding(
            get: {
                notificationsAuthorized && storage.wrappedValue
            },
            set: { newValue in
                if newValue {
                    requestNotificationAuthorization {
                        if notificationsAuthorized {
                            storage.wrappedValue = true
                            syncNotificationsForExistingActivities()
                        } else {
                            storage.wrappedValue = false
                            ActivityNotificationService.shared.cancelAllNotifications()
                        }
                    }
                } else {
                    storage.wrappedValue = false
                    syncNotificationsForExistingActivities()
                }
            }
        )
    }
    
    private func requestNotificationAuthorization(completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    notificationsAuthorized = true
                    completion()
                }

            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge]
                ) { granted, _ in
                    DispatchQueue.main.async {
                        notificationsAuthorized = granted
                        completion()
                    }
                }

            case .denied:
                DispatchQueue.main.async {
                    notificationsAuthorized = false
                    completion()
                }

            @unknown default:
                DispatchQueue.main.async {
                    notificationsAuthorized = false
                    completion()
                }
            }
        }
    }
}
