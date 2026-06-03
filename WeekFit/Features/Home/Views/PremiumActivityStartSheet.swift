import SwiftUI
import SwiftData

struct PremiumActivityStartSheet: View {

    let background: Color
    let cardBackground: Color
    let textSecondary: Color

    @Binding var isPresented: Bool
    @Binding var refreshID: UUID

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var allPlannedActivities: [PlannedActivity]

    @State private var currentSubTab: String = "Workout"

    @Namespace private var tabNamespace

    private var activeLiveActivity: PlannedActivity? {
        let now = Date()
        let calendar = Calendar.current

        return allPlannedActivities.first { activity in
            guard !activity.isCompleted,
                  !activity.isSkipped,
                  calendar.isDate(activity.date, inSameDayAs: now),
                  isTrackableLiveActivity(activity)
            else { return false }

            let endLimit = calendar.date(
                byAdding: .minute,
                value: max(activity.durationMinutes, 1),
                to: activity.date
            ) ?? activity.date

            return activity.date <= now && now <= endLimit
        }
    }

    private var selectedPlannerType: PlannerType {
        currentSubTab == "Workout" ? .workout : .recovery
    }

    private var selectedAccent: Color {
        currentSubTab == "Workout"
            ? Color(red: 0.46, green: 0.72, blue: 0.82)
            : Color(red: 0.66, green: 0.58, blue: 0.86)
    }

    private var selectedAccentComponents: (red: Double, green: Double, blue: Double) {
        currentSubTab == "Workout"
            ? (0.46, 0.72, 0.82)
            : (0.66, 0.58, 0.86)
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

//            ambientGlow

            VStack(spacing: 0) {
//                grabber
//                    .padding(.top, 8)

                PremiumBottomSheetHeader(
                    title: activeLiveActivity != nil
                        ? "Active Session"
                        : "Start Activity",

                    subtitle: activeLiveActivity != nil
                        ? "Finish current session before starting another"
                        : "Choose what fits your body right now"
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isPresented = false
                }

                if let liveItem = activeLiveActivity {
                    liveSessionCard(liveItem)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
                }

                segmentedControl
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)

                contextLine
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                activityOptionsList
            }
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(.white.opacity(0.18))
            .frame(width: 42, height: 4)
    }

    private var ambientGlow: some View {
        VStack {
            Circle()
                .fill(selectedAccent.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(y: -110)

            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var sheetHeader: some View {
        ZStack {
            VStack(spacing: 3) {
                Text(activeLiveActivity != nil ? "Active Session" : "Start Activity")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))

                Text(activeLiveActivity != nil ? "Finish current session before starting another" : "Choose what fits your body right now")
                    .font(.system(size: 11.8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
            }

            HStack {
                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.055))
                        )
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.055), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 48)
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton("Workout")
            segmentButton("Recovery")
        }
        .padding(3)
        .frame(height: 38)
        .background(
            Capsule()
                .fill(.white.opacity(0.036))
        )
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.040), lineWidth: 1)
        }
    }

    private func segmentButton(_ title: String) -> some View {
        let isSelected = currentSubTab == title

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                currentSubTab = title
            }
        } label: {
            Text(title)
                .font(.system(size: 13.4, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white.opacity(0.96) : .white.opacity(0.42))
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.white.opacity(0.105))
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.075), lineWidth: 1)
                            }
                            .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var contextLine: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(selectedAccent.opacity(0.78))
                .frame(width: 5, height: 5)

            Text(currentSubTab == "Workout" ? "Quick start training sessions" : "Low-friction recovery options")
                .font(.system(size: 11.8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))

            Spacer()
        }
    }

    private var activityOptionsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(selectedPlannerType.options, id: \.title) { option in
                    let isBlocked = activeLiveActivity != nil
                    let duration = defaultDuration(for: option, type: selectedPlannerType)

                    PremiumActivityStartCard(
                        title: option.title,
                        subtitle: option.subtitle,
                        imageName: option.imageName,
                        systemIcon: selectedPlannerType.icon,
                        accentColor: selectedAccent,
                        cardBackground: cardBackground,
                        textSecondary: textSecondary,
                        durationMinutes: duration,
                        plannerType: selectedPlannerType,
                        badge: smartBadge(for: option, type: selectedPlannerType),
                        hasConflict: isBlocked
                    ) {
                        start(option: option, duration: duration)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 2)
            .padding(.bottom, 24)
        }
    }

    private func start(option: PlannerOption, duration: Int) {
        guard activeLiveActivity == nil else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let components = selectedAccentComponents

        let newActivity = PlannedActivity(
            id: UUID().uuidString,
            date: Date(),
            type: selectedPlannerType.title.lowercased(),
            title: option.title,
            durationMinutes: duration,
            icon: selectedPlannerType.icon,
            imageName: option.imageName,
            colorRed: components.red,
            colorGreen: components.green,
            colorBlue: components.blue,
            calories: 0,
            protein: 0,
            carbs: 0,
            fats: 0,
            isCompleted: false,
            isSkipped: false,
            source: "today"
        )

        modelContext.insert(newActivity)
        try? modelContext.save()

        isPresented = false
        refreshID = UUID()
    }

    private func isTrackableLiveActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        return type == "workout" || type == "recovery"
    }

    private func defaultDuration(for option: PlannerOption, type: PlannerType) -> Int {
        let title = option.title.lowercased()

        if title.contains("sleep") || title.contains("bedtime") {
            return 480
        }

        if title.contains("breath") || title.contains("breathing") {
            return 10
        }

        if title.contains("stretch") || title.contains("mobility") {
            return 20
        }

        if title.contains("sauna") {
            return 20
        }

        if type == .recovery {
            return 20
        }

        return 60
    }

    private func smartBadge(for option: PlannerOption, type: PlannerType) -> String? {
        let title = option.title.lowercased()

        if title.contains("sleep") || title.contains("bedtime") {
            return "EVENING"
        }

        if title.contains("yoga") || title.contains("stretch") || title.contains("mobility") {
            return "LOW IMPACT"
        }

        if title.contains("breath") {
            return "RESET"
        }

        if title.contains("run") || title.contains("cycling") || title.contains("cardio") {
            return "CARDIO"
        }

        if title.contains("upper") || title.contains("strength") || title.contains("body") {
            return "STRENGTH"
        }

        return type == .recovery ? "RECOVERY" : nil
    }

    private func liveSessionCard(_ liveItem: PlannedActivity) -> some View {
        let accentColor = liveItem.type.lowercased() == "workout"
            ? Color(red: 0.46, green: 0.72, blue: 0.82)
            : Color(red: 0.66, green: 0.58, blue: 0.86)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 42, height: 42)

                Image(systemName: liveItem.icon.isEmpty ? "figure.run" : liveItem.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor.opacity(0.95))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 5, height: 5)
                        .phaseAnimator([0.35, 1.0]) { content, phase in
                            content.opacity(phase)
                        } animation: { _ in
                            .easeInOut(duration: 0.9)
                        }

                    Text("LIVE NOW")
                        .font(.system(size: 9.4, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(accentColor.opacity(0.92))
                }

                Text(liveItem.title)
                    .font(.system(size: 15.2, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                    .lineLimit(1)

                liveProgressText(startedAt: liveItem.date, maxMinutes: liveItem.durationMinutes)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                liveTimer(startedAt: liveItem.date)

                Button {
                    stopLiveSession(liveItem)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.68))
                        )
                        .shadow(color: Color.red.opacity(0.16), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.105),
                            .white.opacity(0.026),
                            .white.opacity(0.012)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.28),
                            .white.opacity(0.055),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: accentColor.opacity(0.07), radius: 14, y: 5)
    }

    private func liveTimer(startedAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(startedAt)))
            let minutes = elapsed / 60
            let seconds = elapsed % 60
            let timeText = String(format: "%02d:%02d", minutes, seconds)

            Text(timeText)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.96))
                .frame(width: 82, alignment: .trailing)
        }
    }

    private func liveProgressText(startedAt: Date, maxMinutes: Int) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(startedAt)))
            let elapsedMinutes = min(elapsed / 60, max(maxMinutes, 1))

            Text("\(elapsedMinutes) / \(maxMinutes) min")
                .font(.system(size: 10.6, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
        }
    }

    private func stopLiveSession(_ activity: PlannedActivity) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            activity.isCompleted = true

            let passedMinutes = Int(Date().timeIntervalSince(activity.date) / 60)
            activity.durationMinutes = max(1, min(passedMinutes, max(activity.durationMinutes, 1)))

            try? modelContext.save()

            refreshID = UUID()
            isPresented = false
        }
    }
}
