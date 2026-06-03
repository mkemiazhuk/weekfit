import SwiftUI

struct TermsPrivacyView: View {

    @Environment(\.dismiss) private var dismiss

    private let background = Color.black
    private let cardBackground = Color(red: 24/255, green: 24/255, blue: 28/255)

    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.58)
    private let textMuted = Color.white.opacity(0.42)

    private let accentGreen = Color(red: 170/255, green: 255/255, blue: 70/255)

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                fixedHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        legalCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 34)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - UI

private extension TermsPrivacyView {

    var fixedHeader: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 12)

            Rectangle()
                .fill(.white.opacity(0.055))
                .frame(height: 1)
        }
        .background(
            Color.black
                .ignoresSafeArea(edges: .top)
        )
    }

    var headerSection: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.065))
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

            Text("Terms & Privacy")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            Spacer()

            Color.clear
                .frame(width: 48, height: 48)
        }
    }

    var legalCard: some View {
        VStack(alignment: .leading, spacing: 22) {

            topIcon

            introSection

            sectionDivider

            legalSection(
                title: "About WeekFit",
                paragraphs: [
                    "WeekFit is a personal training, recovery, nutrition, hydration, sleep, and routine planning app.",
                    "The app helps you organize your day, review health-related metrics, and receive coaching-style suggestions before, during, and after workouts.",
                    "WeekFit is intended for personal wellness, fitness planning, habit tracking, and lifestyle support. It is not intended for emergency use or clinical decision-making."
                ]
            )

            sectionDivider

            legalSection(
                title: "Terms of Use",
                paragraphs: [
                    "By using WeekFit, you agree to use the app only for lawful, personal, non-commercial wellness and fitness purposes.",
                    "You are responsible for your own activity choices, workout intensity, nutrition decisions, hydration habits, recovery approach, and use of any information shown in the app.",
                    "WeekFit may provide suggestions based on the data available to the app, but those suggestions are not a guarantee of performance, recovery, health, fitness, or wellness results.",
                    "You should stop any activity and seek appropriate professional help if you feel pain, dizziness, shortness of breath, unusual discomfort, or any other concerning symptoms."
                ]
            )

            sectionDivider

            legalSection(
                title: "Health, Fitness & Nutrition Disclaimer",
                paragraphs: [
                    "WeekFit provides general wellness, fitness, recovery, hydration, sleep, and nutrition information for educational and informational purposes only.",
                    "WeekFit does not provide medical advice, diagnosis, treatment, prescription, therapy, or professional healthcare services.",
                    "Coaching insights, nutrition suggestions, recovery guidance, reminders, activity status, and metric summaries are not a substitute for advice from a doctor, dietitian, physiotherapist, or other qualified professional.",
                    "Always consult a qualified healthcare professional before making health-related decisions, starting a new training program, changing your diet, or relying on app-based guidance if you have any medical condition, injury, pregnancy, medication use, or other health concern."
                ]
            )

            sectionDivider

            legalSection(
                title: "Apple Health & Device Data",
                paragraphs: [
                    "WeekFit may use data from Apple Health, Apple Watch, iPhone sensors, and information you enter manually inside the app.",
                    "This may include activity, workouts, sleep, energy, hydration, nutrition, body metrics, recovery-related signals, and other wellness data depending on the permissions you grant.",
                    "Some features may be limited, unavailable, or less accurate if Apple Health access is not granted, if Apple Watch is not used, or if the underlying data is missing, delayed, incomplete, or inaccurate."
                ]
            )

            sectionDivider

            legalSection(
                title: "Apple Health Permissions",
                paragraphs: [
                    "WeekFit only accesses Apple Health categories that you explicitly allow through Apple Health permissions.",
                    "You can review, modify, or revoke Apple Health permissions at any time in the Apple Health app or iOS Settings.",
                    "If permissions are removed, WeekFit may no longer be able to update related metrics, sync completed workouts, personalize Coach suggestions, or show certain insights."
                ]
            )

            sectionDivider

            legalSection(
                title: "How WeekFit Uses Data",
                paragraphs: [
                    "WeekFit uses available activity, workout, nutrition, hydration, sleep, recovery, body, and planner data to provide app functionality and personalize your experience.",
                    "This data may be used to show metrics, update Plan statuses, import completed workouts, calculate daily context, generate Coach suggestions, support reminders, and help you understand your routine.",
                    "The accuracy of insights depends on the accuracy, completeness, and timing of the data available to WeekFit."
                ]
            )

            sectionDivider

            legalSection(
                title: "Privacy & Data Protection",
                paragraphs: [
                    "Your health and wellness information remains under your control.",
                    "WeekFit does not sell personal health information and does not share Apple Health data with advertisers or data brokers.",
                    "Where possible, data processing is performed on device to reduce unnecessary data transfer and collection.",
                    "If future features require external processing, account services, cloud sync, analytics, or support diagnostics, those features should be disclosed separately and handled according to the app privacy policy and applicable App Store requirements."
                ]
            )

            sectionDivider

            legalSection(
                title: "User-Entered Data",
                paragraphs: [
                    "You may add, edit, complete, skip, or delete activities, meals, hydration, recovery routines, sleep routines, and other planned items inside WeekFit.",
                    "User-entered data is used to update your plan, metrics, Coach context, and daily guidance.",
                    "You are responsible for the accuracy of information you enter manually."
                ]
            )

            sectionDivider

            legalSection(
                title: "Notifications & Reminders",
                paragraphs: [
                    "WeekFit may send reminders for planned activities, meals, hydration, recovery routines, completion check-ins, or other app-related actions if you enable notifications.",
                    "Notifications are optional and can be changed in WeekFit settings or iOS Settings.",
                    "Reminder timing may be affected by device settings, Focus modes, notification permissions, and system limitations."
                ]
            )

            sectionDivider

            legalSection(
                title: "Data Retention & Deletion",
                paragraphs: [
                    "WeekFit retains app data only as needed to provide functionality, maintain your plan, show metrics, and personalize the experience.",
                    "Deleting activities, removing permissions, or deleting app data may reduce or remove related features, insights, and historical context.",
                    "You can manage Apple Health permissions at any time through Apple Health or iOS Settings."
                ]
            )

            sectionDivider

            legalSection(
                title: "No Warranty",
                paragraphs: [
                    "WeekFit is provided as is and as available, without guarantees that the app will always be uninterrupted, error-free, fully accurate, or suitable for every individual situation.",
                    "Health, activity, sleep, nutrition, hydration, and recovery data may be delayed, incomplete, estimated, or unavailable depending on your device, permissions, third-party sources, and Apple Health data availability."
                ]
            )

            footerLink
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.04), lineWidth: 1)
                }
        }
    }

    var topIcon: some View {
        HStack {
            Spacer()

            ZStack {
                Circle()
                    .fill(accentGreen.opacity(0.08))
                    .blur(radius: 28)
                    .frame(width: 88, height: 88)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                accentGreen,
                                accentGreen.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 84, height: 84)

            Spacer()
        }
        .padding(.top, 2)
    }

    var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Your data stays in your control")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(textPrimary)

            Text("WeekFit uses the health, activity, nutrition, recovery, and planner data you allow or enter to make the app more useful. You can change Apple Health permissions anytime in Apple Health or iOS Settings.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(textSecondary)
                .lineSpacing(2.5)

            Text("Last updated: May 2026")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(textMuted)
                .padding(.top, 4)
        }
    }

    func legalSection(
        title: String,
        paragraphs: [String]
    ) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(textSecondary)
                        .lineSpacing(2.5)
                }
            }
        }
    }

    var sectionDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.05))
            .frame(height: 1)
    }

    var footerLink: some View {
        HStack(alignment: .top, spacing: 10) {

            Image(systemName: "info.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accentGreen.opacity(0.82))

            Text("Manage Apple Health permissions anytime in Apple Health or iOS Settings.")
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(accentGreen.opacity(0.82))
                .lineSpacing(2)
        }
        .padding(.top, 2)
    }
}
