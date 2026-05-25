import SwiftUI

struct TermsPrivacyView: View {

    @Environment(\.dismiss) private var dismiss

    private let background = Color.black

    private let cardBackground = Color(red: 24/255, green: 24/255, blue: 28/255)


    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.58)

    private let accentGreen = Color(red: 170/255, green: 255/255, blue: 70/255)

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    headerSection

                    legalCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 34)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - UI

private extension TermsPrivacyView {

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
                title: "Terms of Use",
                paragraphs: [
                    "By using WeekFit, you agree to use the app for personal wellness, fitness, recovery, and lifestyle purposes only.",

                    "WeekFit supports healthy routines, activity planning, hydration tracking, recovery insights, and wellness experiences.",

                    "The app does not guarantee specific medical, wellness, or fitness outcomes.",

                    "Users remain responsible for workout intensity, nutrition choices, and personal health decisions."
                ]
            )

            sectionDivider

            legalSection(
                title: "How WeekFit Uses Data",
                paragraphs: [
                    "WeekFit uses activity, nutrition, hydration, recovery, and Apple Health information to personalize your in-app experience.",

                    "Data helps provide insights, reminders, recommendations, and wellness experiences tailored to your routine.",

                    "Health information is used only for app functionality and personalization."
                ]
            )

            sectionDivider

            legalSection(
                title: "Apple Health Permissions",
                paragraphs: [
                    "WeekFit only accesses Apple Health categories you explicitly allow through Apple Health permissions.",

                    "Permissions can be reviewed, modified, or revoked anytime inside Apple Health or iOS Settings."
                ]
            )

            sectionDivider

            legalSection(
                title: "Privacy & Data Protection",
                paragraphs: [
                    "Your wellness and Apple Health information remain under your control at all times.",

                    "WeekFit does not sell, rent, or share personal health information with advertisers or unrelated third parties.",

                    "Whenever possible, processing happens directly on your device to reduce unnecessary data collection."
                ]
            )

            sectionDivider

            legalSection(
                title: "Retention",
                paragraphs: [
                    "Information is retained only for as long as necessary to support app functionality and user experience.",

                    "Removing permissions or deleting app data may limit certain features and wellness experiences."
                ]
            )

            sectionDivider

            legalSection(
                title: "Wellness Disclaimer",
                paragraphs: [
                    "WeekFit provides wellness and fitness guidance for informational purposes only.",

                    "The app does not provide medical advice, diagnosis, or treatment.",

                    "Always consult qualified healthcare professionals for medical concerns or health-related decisions."
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

                Image(systemName: "person.2.fill")
                    .font(.system(size: 40, weight: .semibold))
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

            Text("Data & Privacy")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(textPrimary)

            Text("""
            WeekFit is designed with a privacy-first approach. Your wellness, activity, and Apple Health information remain under your control at all times.
            """)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(textSecondary)
            .lineSpacing(2.5)
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
