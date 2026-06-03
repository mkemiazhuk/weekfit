import SwiftUI
import UIKit

struct HelpSupportView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var showSupportSheet = false
    @State private var showCopiedToast = false

    @State private var showFAQView = false
    @State private var showGuidesView = false

    private let supportEmail = "mkemiazhuk@gmail.com"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            backgroundGlow

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection
                    quickHelpSection
//                    resourcesSection
                    footerSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 22)
            }

            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showFAQView) {
            FAQView()
        }
        .navigationDestination(isPresented: $showGuidesView) {
            GuidesView()
        }
        .sheet(isPresented: $showSupportSheet) {
            supportSheet
                .presentationDetents([.height(286)])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
                .presentationBackground(.black.opacity(0.96))
                .presentationBackgroundInteraction(.enabled)
        }
    }
}

// MARK: - Main UI

private extension HelpSupportView {

    var backgroundGlow: some View {
        VStack {
            Circle()
                .fill(WeekFitStyle.brandGreen.opacity(0.075))
                .frame(width: 220, height: 220)
                .blur(radius: 120)
                .offset(x: 84, y: 22)

            Spacer()
        }
        .ignoresSafeArea()
    }

    var heroSection: some View {
        VStack(alignment: .leading, spacing: 26) {
            headerSection

            VStack(alignment: .leading, spacing: 7) {
                Text("Need help with WeekFit?")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .padding(.top, 2)
        }
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

            Text("Help & Support")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 48, height: 48)
        }
    }

    var quickHelpSection: some View {
        supportSection(title: "Quick Help") {
            SupportRow(
                icon: "message.fill",
                iconColor: WeekFitStyle.brandGreen,
                title: "Contact Support",
                subtitle: "Questions, bugs, or feedback"
            ) {
                showSupportSheet = true
            }

            SupportRow(
                icon: "questionmark",
                iconColor: .cyan,
                title: "FAQ",
                subtitle: "Answers about syncing, planning, and metrics"
            ) {
                showFAQView = true
            }

            SupportRow(
                icon: "doc.text.fill",
                iconColor: .teal,
                title: "Guides",
                subtitle: "How to use WeekFit day to day"
            ) {
                showGuidesView = true
            }
        }
    }

    var resourcesSection: some View {
        supportSection(title: "Resources") {
            SupportRow(
                icon: "heart.text.square.fill",
                iconColor: .mint,
                title: "Health Access",
                subtitle: "Manage Apple Health permissions"
            ) {
                openAppSettings()
            }

            SupportRow(
                icon: "lock.shield.fill",
                iconColor: .indigo,
                title: "Privacy",
                subtitle: "Review data and privacy settings"
            ) {
                openAppSettings()
            }

            SupportRow(
                icon: "doc.plaintext.fill",
                iconColor: .orange,
                title: "Terms",
                subtitle: "Usage terms and wellness disclaimer"
            ) {
                openAppSettings()
            }
        }
    }

    func supportSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 11) {
                content()
            }
        }
    }

    var footerSection: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(.white.opacity(0.08))
                .frame(width: 44, height: 5)

            VStack(spacing: 4) {
                Text("WeekFit Support")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.36))

                Text("We usually reply within a day")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.24))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 18)
    }
}

// MARK: - Support Sheet

private extension HelpSupportView {

    var supportSheet: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(WeekFitStyle.brandGreen.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "message.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(WeekFitStyle.brandGreen)
                }

                VStack(spacing: 5) {
                    Text("Contact Support")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Something not working right? Reach out anytime.")
                        .font(.system(size: 13.2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.54))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button {
                        openEmailApp()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                            Text("Open Email App")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            WeekFitStyle.brandGreen,
                                            WeekFitStyle.brandGreen.opacity(0.84)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button {
                        copySupportEmail()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.on.doc.fill")
                            Text("Copy Email Address")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            Capsule()
                                .fill(.white.opacity(0.07))
                                .overlay {
                                    Capsule()
                                        .stroke(.white.opacity(0.09), lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }

    var copiedToast: some View {
        VStack {
            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(WeekFitStyle.brandGreen)

                Text("Email copied")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background {
                Capsule()
                    .fill(.black.opacity(0.88))
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.11), lineWidth: 1)
                    }
            }
            .padding(.bottom, 34)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Actions

private extension HelpSupportView {

    func openEmailApp() {
        let subject = "WeekFit Support"
        let body = """
        Hi WeekFit Team,

        I need help with:

        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let url = URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)") else {
            copySupportEmail()
            return
        }

        UIApplication.shared.open(url) { success in
            if !success {
                copySupportEmail()
            }
        }
    }

    func copySupportEmail() {
        UIPasteboard.general.string = supportEmail
        showSupportSheet = false

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            showCopiedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.22)) {
                showCopiedToast = false
            }
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Reusable Row

private struct SupportRow: View {

    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 13.2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.22))
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 12)
            .frame(minHeight: 74)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.055),
                                Color.white.opacity(0.025)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(.white.opacity(0.07), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Pressable Button Style

private struct PressableButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - FAQ View

struct FAQView: View {

    @Environment(\.dismiss) private var dismiss

    private let items: [(String, String)] = [

        (
            "What is WeekFit?",
            "WeekFit is your personal training and recovery coach. It helps you plan workouts, meals, hydration, sleep, and routines in one place, while guiding you throughout the day using your activity, recovery, and health data."
        ),

        (
            "How does WeekFit work day to day?",
            "Plan helps you organize your upcoming week ahead. Today reacts to what is actually happening during the day. Coach then adapts suggestions based on your activity, recovery, meals, hydration, sleep, and timing."
        ),

        (
            "What is the difference between Today and Plan?",
            "Today focuses on your current day, metrics, and live activity. Plan is where you organize workouts, meals, recovery, sleep, and routines ahead of time."
        ),

        (
            "What is the difference between planning and logging?",
            "Plan helps you organize things ahead of time. Logging is for things that already happened during the day — like meals, coffee, water, workouts, recovery, or sleep routines."
        ),

        (
            "Why are my metrics empty?",
            "WeekFit shows data that already exists in Apple Health. Check Health permissions and make sure Apple Health has data for the selected day."
        ),

        (
            "Do I need an Apple Watch?",
            "No. You can use WeekFit without Apple Watch. But sleep, workouts, recovery, and activity data may be missing or less accurate, which can affect coaching insights and recommendations."
        ),

        (
            "What is Daily Status?",
            "Daily Status gives a simple overview of your activity, nutrition, recovery, sleep, hydration, and Apple Health data throughout the day."
        ),

        (
            "What do the percentages mean?",
            "The percentages help you understand balance during the day. They are not meant to be perfect scores or goals to chase."
        ),

        (
            "Why can Activity go above 100%?",
            "Activity can go above 100% when your movement, workouts, exercise minutes, or daily activity go beyond your current activity goal."
        ),

        (
            "How are your Activity and Nutrition targets calculated?",
            "WeekFit looks at your workouts, movement, recovery, body data, meals, and Apple Health information to build personalized Activity and Nutrition targets. As your day changes, targets can also adjust to better reflect your current energy and recovery needs."
        ),

        (
            "What is BMR?",
            "BMR (Basal Metabolic Rate) is your estimated base energy need — the calories your body uses at rest."
        ),

        (
            "What is TDEE?",
            "TDEE (Total Daily Energy Expenditure) combines your base metabolism with movement, workouts, and daily activity to estimate your daily energy needs."
        ),

        (
            "How are Nutrition targets calculated?",
            "WeekFit starts with your estimated BMR, then builds a dynamic TDEE using workouts, movement, active calories, recovery, and daily activity. Calories, protein, carbs, fats, and water targets then adapt based on your selected goal."
        ),

        (
            "How does WeekFit estimate calories?",
            "WeekFit roughly follows:\n\nBMR + Activity + Workouts = Daily Energy Need\n\nYour selected goal then adjusts calories, protein, carbs, fats, and hydration targets."
        ),

        (
            "How are protein, carbs, and fats calculated?",
            "Protein is mainly based on body weight and your selected goal. Fats use a percentage of your calorie target. Carbs are calculated from the remaining calories after protein and fats."
        ),

        (
            "How is water target calculated?",
            "Water target is based mainly on body weight, with extra hydration added when your activity and active calories are higher."
        ),

        (
            "Why do targets change during the day?",
            "WeekFit uses adaptive targets that react to workouts, movement, recovery, meals, and newly available Apple Health data throughout the day."
        ),

        (
            "Why does Nutrition progress feel different in the morning?",
            "WeekFit uses time-adaptive targets during the day. Morning targets are intentionally lighter so progress reflects where your day realistically is instead of expecting full-day nutrition too early."
        ),

        (
            "Are nutrition values exact?",
            "WeekFit uses ingredients, portions, and meal combinations to estimate calories, protein, carbs, and fats for your meals. While values can vary depending on how meals are built, the goal is to help you clearly understand your overall nutrition, energy balance, and meal composition throughout the day."
        ),

        (
            "What does Left mean in Nutrition?",
            "Left shows a rough estimate of remaining calories based on your current activity, workouts, and logged meals."
        ),

        (
            "What are P, C, and F?",
            "P stands for protein, C for carbs, and F for fats."
        ),

        (
            "What can I do in Meals?",
            "Meals lets you create your own dishes, combine ingredients, and plan nutrition around workouts, recovery, and daily routines. WeekFit gives estimates for calories, protein, carbs, and fats to help you stay aware of your nutrition without making tracking feel overwhelming."
        ),

        (
            "Why does nutrition show zero?",
            "Nutrition appears after you log a meal or add it in Planner and confirm it as completed. If nothing was logged or confirmed, the values stay at zero."
        ),

        (
            "Should I always hit my calorie target?",
            "Not necessarily. WeekFit focuses more on balance, recovery, consistency, and awareness than hitting perfect numbers every day."
        ),

        (
            "Why can targets change after a workout?",
            "Workouts and activity can increase your estimated energy needs, which may affect activity progress, recovery, and nutrition targets."
        ),

        (
            "Why did my workout appear in Plan?",
            "Completed Apple Health workouts can be imported into Plan automatically. WeekFit uses them to help keep your day accurate."
        ),

        (
            "What does Synced mean?",
            "Synced means the activity came from Apple Health or Apple Watch and was automatically added to your plan."
        ),

        (
            "What do the Plan statuses mean?",
            "Upcoming is later today. Live is happening now. Pending means the planned time already passed. Done means you completed it in WeekFit. Synced means it came from Apple Health."
        ),

        (
            "What does Live mean in Plan?",
            "Live means the activity is currently happening based on the planned time or synced workout timing."
        ),

        (
            "What does Pending mean?",
            "Pending means the planned activity time already passed, but the activity was not completed or synced yet."
        ),

        (
            "How do I log an activity?",
            "Open Plan, tap plus, choose the activity, and save it. If the activity already happened, you can mark it completed or let Apple Health sync it automatically."
        ),

        (
            "How should I plan my week?",
            "Start with workouts, then add recovery, meals, hydration, and sleep routines around them. Keep the plan realistic and sustainable."
        ),

        (
            "Can I use WeekFit without planning?",
            "Yes. You can simply log meals, water, workouts, recovery, or routines during the day and let Coach react to your activity."
        ),

        (
            "Can I use WeekFit without logging?",
            "Yes. Apple Health and synced workouts can still provide activity and recovery data, but logging helps Coach understand your day more accurately."
        ),

        (
            "How does Coach work?",
            "Coach adapts throughout the day based on your activity, recovery, sleep, hydration, meals, and routines. Suggestions may change as your day changes."
        ),

        (
            "Why does Coach suggest water or tea?",
            "Coach looks at your activity, hydration, recovery, timing, and routines. After light movement or recovery activities, it may suggest simple actions like hydration or rest."
        ),

        (
            "Why do recommendations change during the day?",
            "Workouts, meals, hydration, sleep, recovery, routines, and synced Apple Health data can all affect Coach suggestions throughout the day."
        ),

        (
            "Why is sleep data missing?",
            "Sleep usually appears only when Apple Health has sleep data available. On iPhone, Sleep Focus or another sleep tracker may be needed."
        ),

        (
            "What is HRV?",
            "HRV stands for heart rate variability. WeekFit uses it as one of several recovery signals from Apple Health."
        ),

        (
            "What is RHR?",
            "RHR stands for resting heart rate. Lower resting heart rate can sometimes reflect better recovery or lower stress."
        ),

        (
            "Why can Recovery change during the day?",
            "Recovery reacts to sleep, workouts, stress, hydration, recovery activities, and overall daily load."
        ),

        (
            "Why am I not getting reminders?",
            "Check notification permissions in iPhone Settings and make sure reminders are turned on inside WeekFit."
        ),

        (
            "Can I change Health permissions?",
            "Yes. You can review, change, or remove Apple Health permissions anytime in Apple Health or iPhone Settings."
        )
    ]

    var body: some View {
        SupportDetailView(
            title: "FAQ",
            subtitle: "Answers to the questions you may have while using WeekFit.",
            icon: "questionmark",
            iconColor: .cyan,
            items: items,
            dismiss: dismiss
        )
    }
}

// MARK: - Guides View

struct GuidesView: View {

    @Environment(\.dismiss) private var dismiss

    private let items: [(String, String)] = [
        (
            "Start with Apple Health",
            "First, connect Apple Health and allow the data WeekFit needs. Activity, sleep, workouts, heart data, hydration, and body metrics help the app understand your day better."
        ),
        (
            "Check Today first",
            "Today is your live dashboard. Start there to see your current activity, nutrition, recovery, hydration, sleep, and coaching status."
        ),
        (
            "Read Daily Status",
            "Daily Status gives a quick view of how your day is going. Look at Activity, Nutrition, and Recovery to understand whether the day is balanced, light, or already demanding."
        ),
        (
            "Understand Activity",
            "Activity shows how much you have moved compared to your current goal. Walks, workouts, exercise minutes, and Apple Watch activity can all move this number."
        ),
        (
            "Understand Nutrition",
            "Nutrition shows your food progress for the day. It uses meals you log or complete and gives a high-level view of calories, protein, carbs, and fats."
        ),
        (
            "Understand Recovery",
            "Recovery helps you see whether your body may need an easier day. Sleep, recent workouts, daily load, HRV, resting heart rate, and recovery routines can all affect it."
        ),
        (
            "Use Coach as your next step",
            "Coach looks at what is happening now and suggests what may help next — before training, during activity, after workouts, after sauna, or when recovery looks pressured."
        ),
        (
            "Use Plan for what comes next",
            "Plan is for organizing your day or week ahead. Add workouts, meals, hydration, recovery, sleep, and routines before they happen."
        ),
        (
            "Plan a realistic week",
            "Add the workouts you actually want to do, then leave space for recovery, meals, water, and sleep."
        ),
        (
            "Use Plan as your day map",
            "Plan shows what is coming, what is happening now, and what was already completed, missed, or synced from Apple Health."
        ),
        (
            "Know the Plan statuses",
            "Upcoming means later today. Live means happening now. Pending means the planned time passed. Done means completed in WeekFit. Synced means imported from Apple Health."
        ),
        (
            "Log what already happened",
            "Logging is for real things that happened during the day — coffee, water, meals, workouts, recovery, sauna, breathing, stretching, or sleep routines."
        ),
        (
            "Plan before, log after",
            "Use Plan when something is ahead of you. Use logging when something already happened. Both help Coach understand your day better."
        ),
        (
            "Create meals from ingredients",
            "Build your own meals, combine ingredients, and plan nutrition throughout the day. WeekFit helps connect meals with training, recovery, hydration, and energy needs."
        ),
        (
            "Use Meals for rough nutrition awareness",
            "Meals gives you a high-level view of calories, protein, carbs, and fats based on ingredients and portions. It helps you understand meal balance without making food tracking too complicated."
        ),
        (
            "Plan nutrition around workouts",
            "Use meals and snacks to support your day. Before training, you may want lighter fuel. After training, meals can help recovery and energy balance."
        ),
        (
            "Log simple things too",
            "Water, tea, coffee, meals, stretching, sauna, breathing, and sleep routines all help Coach understand your day better."
        ),
        (
            "Let workouts sync",
            "If you use Apple Watch or another app that writes workouts to Apple Health, WeekFit can add completed workouts to your plan."
        ),
        (
            "Use Apple Watch if you have one",
            "WeekFit works without Apple Watch, but workouts, sleep, activity, recovery, HRV, and resting heart rate are usually better when Apple Watch or another tracker writes data to Apple Health."
        ),
        (
            "Balance hard and easy days",
            "Recovery matters as much as training. Try not to stack too many hard sessions without an easier day."
        ),
        (
            "Use recovery routines",
            "Breathing, stretching, mobility, walking, sauna, and sleep routines can all help WeekFit understand recovery and daily load."
        ),
        (
            "Use reminders if you need them",
            "Simple reminders can help you follow the plan during busy days."
        ),
        (
            "Look for patterns",
            "Your week matters more than one perfect day. Use trends to adjust the next week."
        ),
        (
            "Do not chase perfect numbers",
            "Percentages and targets are there to guide awareness, not to create pressure. Some days will be higher, lower, easier, or more demanding."
        ),
        (
            "Start simple",
            "For the first few days, connect Health, plan one or two workouts, log meals and water, and check Coach after activity. WeekFit gets more useful as your data builds."
        )
    ]

    var body: some View {
        SupportDetailView(
            title: "Guides",
            subtitle: "A few simple ways to use WeekFit better.",
            icon: "doc.text.fill",
            iconColor: .teal,
            items: items,
            dismiss: dismiss
        )
    }
}

// MARK: - Shared Detail View

struct SupportDetailView: View {

    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let items: [(String, String)]
    let dismiss: DismissAction

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            backgroundGlow

            VStack(spacing: 0) {

                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    introSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 18)
                .background(Color.black)

                ScrollView(showsIndicators: false) {
                    contentSection
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private extension SupportDetailView {

    var backgroundGlow: some View {
        VStack {
            Circle()
                .fill(iconColor.opacity(0.075))
                .frame(width: 220, height: 220)
                .blur(radius: 120)
                .offset(x: 84, y: 22)

            Spacer()
        }
        .ignoresSafeArea()
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
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Back")

            Spacer()

            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 48, height: 48)
        }
    }

    var introSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()

                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.07))
                        .blur(radius: 22)
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 54, height: 54)

                Spacer()
            }

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
        }
    }

    var contentSection: some View {
        VStack(spacing: 11) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                infoCard(title: item.0, text: item.1)
            }
        }
    }

    func infoCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundStyle(.white)

            Text(text)
                .font(.system(size: 13.2, weight: .medium))
                .foregroundStyle(.white.opacity(0.54))
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.045),
                            Color.white.opacity(0.024)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                }
        }
    }
}
