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
    private let rowBackground = WeekFitTheme.whiteOpacity(0.065)

    private var textPrimary: Color { WeekFitTheme.primaryText }
    private let textSecondary = WeekFitTheme.whiteOpacity(0.54)
    private let sectionText = WeekFitTheme.whiteOpacity(0.34)

    private let accentGreen = Color(red: 170/255, green: 255/255, blue: 70/255)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ProfilePremiumBackground(accent: accentGreen)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    notificationSection(title: AppText.Settings.Notifications.activitySection) {
                        notificationRow(
                            icon: "figure.run",
                            title: AppText.Settings.Notifications.activityRemindersTitle,
                            subtitle: AppText.Settings.Notifications.activityRemindersSubtitle,
                            isOn: $activityRemindersEnabled
                        )

                        softDivider

                        notificationRow(
                            icon: "checkmark.circle.fill",
                            title: AppText.Settings.Notifications.completionCheckInsTitle,
                            subtitle: AppText.Settings.Notifications.completionCheckInsSubtitle,
                            isOn: $completionCheckInsEnabled
                        )
                    }

                    notificationSection(title: AppText.Settings.Notifications.wellnessSection) {
                        notificationRow(
                            icon: "heart.fill",
                            title: AppText.Settings.Notifications.recoverySuggestionsTitle,
                            subtitle: AppText.Settings.Notifications.recoverySuggestionsSubtitle,
                            isOn: $recoverySuggestionsEnabled
                        )

                        softDivider

                        notificationRow(
                            icon: "drop.fill",
                            title: AppText.Settings.Notifications.hydrationRemindersTitle,
                            subtitle: AppText.Settings.Notifications.hydrationRemindersSubtitle,
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
        NotificationSyncCoordinator.syncAll(
            plannedActivities: plannedActivities,
            recoveryPercent: 0
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
        ProfilePremiumHeader(
            title: WeekFitLocalizedString("settings.notifications.title"),
            accent: accentGreen
        ) {
            dismiss()
        }
    }

    func notificationSection<Content: View>(
        title: LocalizedStringResource,
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
            .profilePremiumCard(cornerRadius: 24)
        }
    }

    var softDivider: some View {
        Divider()
            .overlay(.white.opacity(0.035))
            .padding(.leading, 68)
    }

    func notificationRow(
        icon: String,
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource,
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 13.2, weight: .medium))
                    .foregroundStyle(textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
        Text(AppText.Settings.Notifications.footerNote)
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.34))
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
                    recoverySuggestionsEnabled = false
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
