//import SwiftUI
//import SwiftData
//
//struct HomeView: View {
//
//    @ObservedObject var authViewModel: AuthViewModel
//    @EnvironmentObject private var appSession: AppSessionState
//    @Environment(\.modelContext) private var modelContext
//
//    @StateObject private var confirmationState = ActivityConfirmationState.shared
//    
//    @AppStorage(ProfileService.Keys.initials)
//    private var profileInitials: String = "P"
//    
//    @State private var healthRefreshID = UUID()
//
//    @Query(sort: \PlannedActivity.date, order: .forward)
//    private var plannedActivities: [PlannedActivity]
//
//    @EnvironmentObject private var healthManager: HealthManager
//    @StateObject private var nutritionViewModel = NutritionViewModel()
//
//    @State private var showProfile = false
//    @State private var selectedTab: WeekFitTab = .today
//    @State private var showContent = false
//    @State private var isEditingActivity = false
//    @State private var selectedDate = Date()
//    @State private var livePulse = false
//
//    private enum ActivityDisplayStatus {
//        case completed
//        case skipped
//        case live
//        case missed
//        case upcoming
//    }
//
//    private let background = WeekFitTheme.background
//    private let cardBackground = WeekFitTheme.cardBackground
//    private let cardSecondary = WeekFitTheme.cardSecondary
//    private let elevatedCard = WeekFitTheme.elevatedCard
//
//    private let textPrimary = WeekFitTheme.primaryText
//    private let textSecondary = WeekFitTheme.secondaryText
//    private let textTertiary = WeekFitTheme.tertiaryText
//
//    private let softShadow = WeekFitTheme.cardShadow
//    private let borderSoft = WeekFitTheme.borderSoft
//
//    private let missedColor = Color(red: 0.88, green: 0.30, blue: 0.26)
//    private let luxuryMeal = WeekFitTheme.meal.opacity(0.88)
//    private let luxuryWorkout = WeekFitTheme.workout.opacity(0.82)
//    private let luxuryRecovery = WeekFitTheme.recovery.opacity(0.80)
//    private let luxuryPurple = WeekFitTheme.purple.opacity(0.78)
//
//    private var readyProgress: CGFloat {
//        CGFloat(min(max(healthManager.readyScore / 10.0, 0), 1))
//    }
//
//    private var readyColor: Color {
//        switch healthManager.readyScore {
//        case 8...10: return luxuryMeal
//        case 6..<8: return luxuryWorkout
//        case 4..<6: return WeekFitTheme.orange.opacity(0.82)
//        default: return missedColor.opacity(0.82)
//        }
//    }
//
//    private var focusColor: Color {
//        switch healthManager.readyScore {
//        case 8...10: return luxuryMeal
//        case 6..<8: return luxuryWorkout
//        case 4..<6: return WeekFitTheme.orange.opacity(0.78)
//        default: return Color(red: 0.92, green: 0.58, blue: 0.52).opacity(0.84)
//        }
//    }
//
//    private var selectedDayActivities: [PlannedActivity] {
//        plannedActivities
//            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
//            .sorted { $0.date < $1.date }
//    }
//
//    var body: some View {
//        ZStack(alignment: .bottom) {
//            background.ignoresSafeArea()
//            ambientBackground
//
//            Group {
//                switch selectedTab {
//                case .today:
//                    summaryContent
//                    
//                case .coach: 
//                    NutritionView(authViewModel: authViewModel)
//                        .transition(.opacity)
//                        
//                case .meals:
//                    MealsView(
//                        authViewModel: authViewModel,
//                        nutritionResult: nutritionViewModel.nutritionResult
//                    )
//                    .transition(.opacity)
//                    
//                case .calendar:
//                    PlanWeekView(
//                        authViewModel: authViewModel,
//                        isEditingActivity: $isEditingActivity
//                    )
//                    .transition(.opacity)
//                }
//            }
//
//            WeekFitBottomBar(selectedTab: $selectedTab) {
//                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
//                    selectedTab = .calendar
//                }
//            }
//            .padding(.horizontal, 1)
//            .background(alignment: .top) {
//                Rectangle()
//                    .fill(
//                        LinearGradient(
//                            colors: [
//                                Color.white.opacity(0.035),
//                                Color.white.opacity(0.010),
//                                Color.clear
//                            ],
//                            startPoint: .top,
//                            endPoint: .bottom
//                        )
//                    )
//                    .frame(height: 1)
//                    .offset(y: -7)
//            }
//            .shadow(color: Color.black.opacity(0.30), radius: 20, y: -8)
//            .opacity(showContent && !isEditingActivity ? 1 : 0)
//            .offset(y: showContent && !isEditingActivity ? 0 : 120)
//
//            if let pendingActivity = confirmationState.pendingActivity {
//                Color.black.opacity(0.48)
//                    .ignoresSafeArea()
//                    .onTapGesture {
//                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
//                            confirmationState.pendingActivity = nil
//                        }
//                    }
//                    .zIndex(10)
//
//                missedConfirmationSheet(pendingActivity)
//                    .transition(.move(edge: .bottom).combined(with: .opacity))
//                    .zIndex(20)
//            }
//        }
//        .preferredColorScheme(.dark)
//        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: confirmationState.pendingActivity?.id)
//        .onAppear {
//            withAnimation(.spring(response: 0.62, dampingFraction: 0.88)) {
//                showContent = true
//            }
//
//            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
//                livePulse = true
//            }
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
//                healthRefreshID = UUID()
//            }
//        }
//        .task(id: healthRefreshID) {
//            await refreshHealthAndNutritionAsync()
//        }
//        .onChange(of: selectedDate) { _, _ in
//            healthRefreshID = UUID()
//        }
//        .onChange(of: appSession.returnToTodayTrigger) { _, _ in
//
//            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
//
//                selectedTab = .today
//                selectedDate = Date()
//            }
//        }
//        .onChange(of: appSession.healthRefreshTrigger) { _, _ in
//            Task {
//                await refreshHealthAndNutritionAsync()
//            }
//        }
//        .onReceive(NotificationCenter.default.publisher(for: .healthAccessDidChange)) { _ in
//            Task {
//                await refreshHealthAndNutritionAsync()
//            }
//        }
//        .sheet(
//            isPresented: $showProfile,
//            onDismiss: {
//                forceHomeHealthRefresh()
//            }
//        ) {
//            NavigationStack {
//                ProfileView()
//            }
//            .presentationDetents([.large])
//            .presentationCornerRadius(36)
//            .presentationDragIndicator(.hidden)
//        }
//    }
//
//    private var ambientBackground: some View {
//        ZStack {
//            RadialGradient(
//                colors: [
//                    readyColor.opacity(0.052),
//                    Color.clear
//                ],
//                center: .topTrailing,
//                startRadius: 30,
//                endRadius: 340
//            )
//
//            RadialGradient(
//                colors: [
//                    WeekFitTheme.meal.opacity(0.032),
//                    Color.clear
//                ],
//                center: .bottomLeading,
//                startRadius: 70,
//                endRadius: 380
//            )
//
//            LinearGradient(
//                colors: [
//                    Color.white.opacity(0.010),
//                    Color.clear,
//                    Color.black.opacity(0.14)
//                ],
//                startPoint: .top,
//                endPoint: .bottom
//            )
//        }
//        .ignoresSafeArea()
//        .allowsHitTesting(false)
//    }
//
//    private var summaryContent: some View {
//        VStack(spacing: 0) {
//            VStack(spacing: 12) {
//                heroHeaderSection
//                    .padding(.top, 10)
//                    .padding(.bottom, 4)
//
//                premiumReadyCard
//                todayPriorityCard
//                timelineTitle
//            }
//            .padding(.horizontal, 18)
//            .padding(.bottom, 4)
//            .background(background.opacity(0.965))
//
//            ScrollViewReader { proxy in
//                ScrollView(.vertical, showsIndicators: false) {
//                    timeline
//                        .padding(.horizontal, 18)
//                        .padding(.top, selectedDayActivities.isEmpty ? 22 : 30)
//                        .padding(.bottom, 118)
//                }
//                .onAppear {
//                    scrollToRelevantActivity(proxy)
//                }
//                .onChange(of: selectedDate) { _, _ in
//                    scrollToRelevantActivity(proxy)
//                }
//                .onChange(of: selectedDayActivities.map(\.id)) { _, _ in
//                    scrollToRelevantActivity(proxy)
//                }
//            }
//        }
//        .opacity(showContent ? 1 : 0)
//        .offset(y: showContent ? 0 : 8)
//    }
//
//    private var heroHeaderSection: some View {
//        HStack(alignment: .center) {
//            VStack(alignment: .leading, spacing: 2) {
//                Text(selectedDateTitle)
//                    .font(.system(size: 27, weight: .semibold))
//                    .foregroundStyle(textPrimary.opacity(0.98))
//                    .tracking(-0.65)
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.78)
//            }
//            .padding(.top, 2)
//
//            Spacer(minLength: 10)
//
//            HStack(spacing: 12) {
//                dayControl
//                avatarButton
//            }
//        }
//    }
//
//    private var dayControl: some View {
//        HStack(spacing: 12) {
//            Button {
//                changeDate(by: -1)
//            } label: {
//                Image(systemName: "chevron.left")
//                    .font(.system(size: 13.2, weight: .bold))
//                    .foregroundStyle(textPrimary.opacity(0.78))
//                    .frame(width: 20, height: 30)
//            }
//
//            Button {
//                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
//                    selectedDate = Date()
//                }
//            } label: {
//                Text("Today")
//                    .font(.system(size: 14, weight: .semibold))
//                    .foregroundStyle(textPrimary.opacity(0.86))
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.85)
//                    .frame(width: 54)
//            }
//
//            Button {
//                changeDate(by: 1)
//            } label: {
//                Image(systemName: "chevron.right")
//                    .font(.system(size: 13.2, weight: .bold))
//                    .foregroundStyle(textPrimary.opacity(0.78))
//                    .frame(width: 20, height: 30)
//            }
//        }
//        .frame(width: 132, height: 38)
//        .background {
//            Capsule()
//                .fill(Color.white.opacity(0.064))
//                .overlay {
//                    Capsule()
//                        .stroke(Color.white.opacity(0.052), lineWidth: 1)
//                }
//        }
//        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
//    }
//
//    private var avatarButton: some View {
//        Button {
//            UIImpactFeedbackGenerator(style: .light).impactOccurred()
//            showProfile = true
//        } label: {
//            ZStack {
//                Circle()
//                    .fill(
//                        LinearGradient(
//                            colors: [
//                                Color(red: 0.90, green: 0.75, blue: 0.48),
//                                Color(red: 0.72, green: 0.58, blue: 0.34)
//                            ],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        )
//                    )
//
//                Circle()
//                    .stroke(WeekFitTheme.meal.opacity(0.32), lineWidth: 2.5)
//
//                Circle()
//                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
//                    .padding(5)
//
//                Text(profileInitials)
//                    .font(.system(size: 15.2, weight: .bold))
//                    .foregroundStyle(.white.opacity(0.94))
//            }
//            .frame(width: 48, height: 48)
//            .shadow(color: WeekFitTheme.meal.opacity(0.075), radius: 11, y: 5)
//            .shadow(color: Color.black.opacity(0.22), radius: 8, y: 4)
//        }
//        .buttonStyle(.plain)
//        .accessibilityLabel("Open profile")
//    }
//
//    private var premiumReadyCard: some View {
//        VStack(spacing: 9) {
//            HStack(alignment: .center, spacing: 13) {
//                readinessRing
//                    .frame(width: 58, height: 58)
//
//                VStack(alignment: .leading, spacing: 5) {
//                    Text(readinessHeadline)
//                        .font(.system(size: 16.2, weight: .semibold))
//                        .foregroundStyle(textPrimary.opacity(0.98))
//                        .tracking(-0.12)
//                        .lineLimit(2)
//                        .minimumScaleFactor(0.80)
//
//                    Text(focusInsightText)
//                        .font(.system(size: 11.8, weight: .semibold))
//                        .foregroundStyle(focusColor.opacity(0.88))
//                        .lineLimit(2)
//                        .minimumScaleFactor(0.72)
//                }
//
//                Spacer(minLength: 0)
//            }
//
//            HStack(spacing: 7) {
//                metricPill(
//                    icon: "bolt.fill",
//                    title: "Energy",
//                    value: healthManager.energyStatus,
//                    color: luxuryWorkout
//                )
//
//                metricPill(
//                    icon: "flame.fill",
//                    title: "Recovery",
//                    value: healthManager.recoveryStatus,
//                    color: luxuryRecovery
//                )
//
//                metricPill(
//                    icon: "moon.fill",
//                    title: "Sleep",
//                    value: healthManager.sleepText,
//                    color: luxuryPurple
//                )
//            }
//        }
//        .padding(13)
//        .background {
//            RoundedRectangle(cornerRadius: 28, style: .continuous)
//                .fill(
//                    LinearGradient(
//                        colors: [
//                            readyColor.opacity(0.047),
//                            elevatedCard.opacity(0.96),
//                            cardBackground.opacity(0.985)
//                        ],
//                        startPoint: .topLeading,
//                        endPoint: .bottomTrailing
//                    )
//                )
//        }
//        .overlay(alignment: .topLeading) {
//            LinearGradient(
//                colors: [
//                    readyColor.opacity(0.10),
//                    .clear
//                ],
//                startPoint: .topLeading,
//                endPoint: .bottomTrailing
//            )
//            .frame(width: 180, height: 120)
//            .blur(radius: 20)
//        }
//        .overlay {
//            RoundedRectangle(cornerRadius: 28, style: .continuous)
//                .stroke(readyColor.opacity(0.060), lineWidth: 1)
//        }
//        .shadow(color: softShadow.opacity(0.60), radius: 13, y: 7)
//        .scaleEffect(showContent ? 1 : 0.97)
//        .opacity(showContent ? 1 : 0)
//    }
//
//    private var readinessRing: some View {
//        let hasScore = healthManager.readyScore > 0
//
//        return ZStack {
//            Circle()
//                .stroke(readyColor.opacity(hasScore ? 0.10 : 0.08), lineWidth: 5)
//
//            if hasScore {
//                Circle()
//                    .trim(from: 0, to: readyProgress)
//                    .stroke(
//                        AngularGradient(
//                            colors: [
//                                readyColor.opacity(0.48),
//                                readyColor.opacity(0.88),
//                                readyColor.opacity(0.62)
//                            ],
//                            center: .center
//                        ),
//                        style: StrokeStyle(lineWidth: 6.2, lineCap: .round)
//                    )
//                    .rotationEffect(.degrees(-90))
//            }
//
//            VStack(spacing: -1) {
//                Text(hasScore ? String(format: "%.1f", healthManager.readyScore) : "—")
//                    .font(.system(size: hasScore ? 19.5 : 24, weight: .semibold))
//                    .foregroundStyle(textPrimary.opacity(hasScore ? 1 : 0.82))
//
//                Text(hasScore ? readyStatusText : "Syncing")
//                    .font(.system(size: 8.6, weight: .medium))
//                    .foregroundStyle(readyColor.opacity(hasScore ? 0.86 : 0.62))
//            }
//            .offset(y: -1)
//        }
//    }
//
//    private func metricPill(
//        icon: String,
//        title: String,
//        value: String,
//        color: Color
//    ) -> some View {
//        HStack(spacing: 6) {
//            Circle()
//                .fill(color.opacity(0.105))
//                .frame(width: 22, height: 22)
//                .overlay {
//                    Image(systemName: icon)
//                        .font(.system(size: 10, weight: .bold))
//                        .foregroundStyle(color.opacity(0.86))
//                }
//
//            VStack(alignment: .leading, spacing: 1) {
//                Text(title)
//                    .font(.system(size: 8.2, weight: .semibold))
//                    .foregroundStyle(textSecondary.opacity(0.68))
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.65)
//
//                Text(value)
//                    .font(.system(size: 10.4, weight: .semibold))
//                    .foregroundStyle(color.opacity(0.86))
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.65)
//            }
//
//            Spacer(minLength: 0)
//        }
//        .padding(.horizontal, 8)
//        .frame(height: 35)
//        .background {
//            RoundedRectangle(cornerRadius: 15, style: .continuous)
//                .fill(color.opacity(0.038))
//        }
//        .overlay {
//            RoundedRectangle(cornerRadius: 15, style: .continuous)
//                .stroke(color.opacity(0.045), lineWidth: 1)
//        }
//    }
//
//    private var todayPriorityCard: some View {
//        HStack(spacing: 10) {
//            ZStack {
//                Circle()
//                    .fill(priorityColor.opacity(0.105))
//                    .frame(width: 35, height: 35)
//
//                Image(systemName: priorityIcon)
//                    .font(.system(size: 14.5, weight: .bold))
//                    .foregroundStyle(priorityColor.opacity(0.88))
//            }
//
//            VStack(alignment: .leading, spacing: 2) {
//                Text("Today priority")
//                    .font(.system(size: 10.5, weight: .semibold))
//                    .foregroundStyle(textSecondary.opacity(0.66))
//
//                Text(priorityTitle)
//                    .font(.system(size: 13.8, weight: .semibold))
//                    .foregroundStyle(textPrimary.opacity(0.96))
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.78)
//
//                Text(prioritySubtitle)
//                    .font(.system(size: 10.8, weight: .medium))
//                    .foregroundStyle(textSecondary.opacity(0.72))
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.76)
//            }
//
//            Spacer(minLength: 8)
//
//            Image(systemName: "arrow.right")
//                .font(.system(size: 12.5, weight: .bold))
//                .foregroundStyle(priorityColor.opacity(0.86))
//                .frame(width: 29, height: 29)
//                .background(priorityColor.opacity(0.080))
//                .clipShape(Circle())
//        }
//        .padding(.horizontal, 12)
//        .frame(height: 56)
//        .background {
//            RoundedRectangle(cornerRadius: 22, style: .continuous)
//                .fill(
//                    LinearGradient(
//                        colors: [
//                            priorityColor.opacity(0.052),
//                            cardBackground.opacity(0.985)
//                        ],
//                        startPoint: .topLeading,
//                        endPoint: .bottomTrailing
//                    )
//                )
//        }
//        .overlay {
//            RoundedRectangle(cornerRadius: 22, style: .continuous)
//                .stroke(priorityColor.opacity(0.058), lineWidth: 1)
//        }
//        .shadow(color: softShadow.opacity(0.56), radius: 11, y: 6)
//    }
//
//    private var timelineTitle: some View {
//        HStack(alignment: .center) {
//            Text("Today's flow")
//                .font(.system(size: 17.1, weight: .semibold))
//                .foregroundStyle(textPrimary.opacity(0.98))
//                .tracking(-0.26)
//
//            Spacer()
//
//            Text("\(selectedDayActivities.count) items")
//                .font(.system(size: 11.8, weight: .semibold))
//                .foregroundStyle(textSecondary.opacity(0.70))
//        }
//        .padding(.top, 1)
//    }
//
//    private var timeline: some View {
//        VStack(spacing: 0) {
//            if selectedDayActivities.isEmpty {
//                emptyTimeline
//            } else {
//                ForEach(Array(selectedDayActivities.enumerated()), id: \.element.id) { index, activity in
//                    timelineItem(
//                        activity,
//                        isFirst: index == 0,
//                        isLast: index == selectedDayActivities.count - 1
//                    )
//                    .id(activity.id)
//                }
//            }
//        }
//    }
//
//    private func timelineItem(
//        _ activity: PlannedActivity,
//        isFirst: Bool,
//        isLast: Bool
//    ) -> some View {
//        let status = displayStatus(for: activity)
//
//        return HStack(alignment: .top, spacing: 10) {
//            Text(activityTime(activity.date))
//                .font(.system(size: 12, weight: status == .live ? .bold : .semibold))
//                .foregroundStyle(timeColor(for: activity, status: status))
//                .monospacedDigit()
//                .frame(width: 42, alignment: .trailing)
//                .padding(.top, 16)
//
//            timelineNode(
//                activity: activity,
//                status: status,
//                isFirst: isFirst,
//                isLast: isLast
//            )
//            .frame(width: 22)
//
//            premiumActivityCard(
//                activity,
//                status: status
//            )
//            .padding(.top, 9)
//        }
//    }
//
//    private func premiumActivityCard(
//        _ activity: PlannedActivity,
//        status: ActivityDisplayStatus
//    ) -> some View {
//        let live = status == .live
//        let locked = status == .completed || status == .skipped
//
//        return HStack(spacing: 10) {
//            ZStack {
//                Circle()
//                    .fill(iconBackground(for: activity, status: status))
//                    .frame(width: 36, height: 36)
//
//                Image(systemName: activity.icon)
//                    .font(.system(size: 13.5, weight: .bold))
//                    .foregroundStyle(iconColor(for: activity, status: status))
//            }
//
//            VStack(alignment: .leading, spacing: 2) {
//                Text(activity.title)
//                    .font(.system(size: 13.8, weight: locked ? .medium : .semibold))
//                    .foregroundStyle(titleColor(for: status))
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.70)
//
//                activitySubtitleView(for: activity, status: status)
//            }
//            .layoutPriority(2)
//
//            Spacer(minLength: 4)
//
//            Image(systemName: locked ? "checkmark.seal.fill" : "line.3.horizontal")
//                .font(.system(size: 12.2, weight: .bold))
//                .foregroundStyle(locked ? iconColor(for: activity, status: status).opacity(0.55) : textTertiary.opacity(0.72))
//        }
//        .padding(.leading, 10)
//        .padding(.trailing, 13)
//        .frame(height: 52)
//        .background {
//            RoundedRectangle(cornerRadius: 20, style: .continuous)
//                .fill(cardBackgroundStyle(for: activity, status: status))
//        }
//        .overlay {
//            RoundedRectangle(cornerRadius: 20, style: .continuous)
//                .stroke(cardBorderColor(for: activity, status: status), lineWidth: cardBorderWidth(for: status))
//        }
//        .shadow(
//            color: live ? activity.color.opacity(livePulse ? 0.14 : 0.06) : WeekFitTheme.softShadow.opacity(locked ? 0.38 : 0.60),
//            radius: live ? (livePulse ? 10 : 8) : locked ? 5 : 9,
//            y: live ? 5 : locked ? 2 : 4
//        )
//        .opacity(cardOpacity(for: status))
//        .contentShape(Rectangle())
//        .onLongPressGesture(minimumDuration: 0.35) {
//            if status == .missed {
//                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
//
//                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
//                    confirmationState.pendingActivity = activity
//                }
//            }
//        }
//    }
//
//    @ViewBuilder
//    private func activitySubtitleView(
//        for activity: PlannedActivity,
//        status: ActivityDisplayStatus
//    ) -> some View {
//        Text(subtitle(for: activity, status: status))
//            .font(.system(size: 10.8, weight: status == .live ? .bold : .semibold))
//            .foregroundStyle(subtitleColor(for: status))
//            .lineLimit(1)
//            .minimumScaleFactor(0.70)
//    }
//
//    private func timelineNode(
//        activity: PlannedActivity,
//        status: ActivityDisplayStatus,
//        isFirst: Bool,
//        isLast: Bool
//    ) -> some View {
//        let live = status == .live
//        let completed = status == .completed
//        let skipped = status == .skipped
//        let missed = status == .missed
//
//        return VStack(spacing: 0) {
//            Rectangle()
//                .fill(isFirst ? .clear : Color.white.opacity(0.052))
//                .frame(width: 1, height: 17)
//
//            ZStack {
//                if live {
//                    Circle()
//                        .fill(activity.color.opacity(livePulse ? 0.14 : 0.06))
//                        .frame(width: livePulse ? 17 : 14, height: livePulse ? 17 : 14)
//                        .blur(radius: 1.1)
//                }
//
//                Circle()
//                    .fill(nodeFillColor(for: activity, status: status))
//                    .frame(
//                        width: live ? 8 : completed || skipped || missed ? 8 : 6,
//                        height: live ? 8 : completed || skipped || missed ? 8 : 6
//                    )
//                    .overlay {
//                        if completed {
//                            Image(systemName: "checkmark")
//                                .font(.system(size: 5.8, weight: .black))
//                                .foregroundStyle(.black.opacity(0.82))
//                        }
//
//                        if skipped {
//                            Image(systemName: "xmark")
//                                .font(.system(size: 5.4, weight: .black))
//                                .foregroundStyle(.black.opacity(0.72))
//                        }
//
//                        if missed {
//                            Image(systemName: "bell.fill")
//                                .font(.system(size: 5.1, weight: .black))
//                                .foregroundStyle(.black.opacity(0.78))
//                        }
//                    }
//                    .shadow(
//                        color: live ? activity.color.opacity(livePulse ? 0.24 : 0.10) : .clear,
//                        radius: live ? 5 : 0,
//                        y: 2
//                    )
//            }
//            .frame(width: 22, height: 12)
//
//            Rectangle()
//                .fill(isLast ? .clear : Color.white.opacity(0.052))
//                .frame(width: 1, height: 35)
//        }
//        .frame(width: 22, alignment: .center)
//    }
//
//    private var emptyTimeline: some View {
//        VStack(spacing: 12) {
//            Image(systemName: "calendar.badge.plus")
//                .font(.system(size: 25, weight: .semibold))
//                .foregroundStyle(luxuryMeal.opacity(0.88))
//
//            Text("Nothing planned yet")
//                .font(.system(size: 18, weight: .semibold))
//                .foregroundStyle(textPrimary.opacity(0.98))
//
//            Text("Add meals, workouts or recovery activities to build your day.")
//                .font(.system(size: 12.7, weight: .medium))
//                .foregroundStyle(textSecondary.opacity(0.70))
//                .multilineTextAlignment(.center)
//                .lineSpacing(2)
//                .frame(maxWidth: 290)
//
//            Button {
//                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
//                    selectedTab = .calendar
//                }
//            } label: {
//                Text("Plan your day")
//                    .font(.system(size: 13.8, weight: .semibold))
//                    .foregroundStyle(.black.opacity(0.84))
//                    .padding(.horizontal, 23)
//                    .padding(.vertical, 10)
//                    .background {
//                        Capsule()
//                            .fill(
//                                LinearGradient(
//                                    colors: [
//                                        WeekFitTheme.meal.opacity(0.90),
//                                        WeekFitTheme.meal.opacity(0.82)
//                                    ],
//                                    startPoint: .topLeading,
//                                    endPoint: .bottomTrailing
//                                )
//                            )
//                            .overlay(alignment: .top) {
//                                Capsule()
//                                    .fill(Color.white.opacity(0.075))
//                                    .frame(height: 16)
//                                    .blur(radius: 8)
//                            }
//                    }
//            }
//            .buttonStyle(.plain)
//            .padding(.top, 3)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 28)
//        .padding(.horizontal, 22)
//        .background {
//            RoundedRectangle(cornerRadius: 26, style: .continuous)
//                .fill(
//                    LinearGradient(
//                        colors: [
//                            elevatedCard.opacity(0.94),
//                            cardBackground.opacity(0.985)
//                        ],
//                        startPoint: .topLeading,
//                        endPoint: .bottomTrailing
//                    )
//                )
//        }
//        .overlay {
//            RoundedRectangle(cornerRadius: 26, style: .continuous)
//                .stroke(Color.white.opacity(0.040), lineWidth: 1)
//        }
//        .shadow(color: softShadow.opacity(0.58), radius: 13, y: 7)
//    }
//
//    private func missedConfirmationSheet(_ activity: PlannedActivity) -> some View {
//        VStack(alignment: .leading, spacing: 13) {
//            Capsule()
//                .fill(Color.white.opacity(0.14))
//                .frame(width: 40, height: 4)
//                .frame(maxWidth: .infinity)
//
//            HStack(spacing: 12) {
//                Circle()
//                    .fill(activity.color.opacity(0.13))
//                    .frame(width: 42, height: 42)
//                    .overlay {
//                        Image(systemName: activity.icon)
//                            .font(.system(size: 17, weight: .bold))
//                            .foregroundStyle(activity.color.opacity(0.94))
//                    }
//
//                VStack(alignment: .leading, spacing: 3) {
//                    Text(activity.title)
//                        .font(.system(size: 18, weight: .bold))
//                        .foregroundStyle(textPrimary)
//                        .lineLimit(1)
//
//                    Text("\(activityTime(activity.date)) • \(activity.durationMinutes) min")
//                        .font(.system(size: 12.6, weight: .semibold))
//                        .foregroundStyle(textSecondary.opacity(0.78))
//                }
//
//                Spacer()
//
//                Button {
//                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
//                        confirmationState.pendingActivity = nil
//                    }
//                } label: {
//                    Image(systemName: "xmark")
//                        .font(.system(size: 12.5, weight: .bold))
//                        .foregroundStyle(textSecondary)
//                        .frame(width: 30, height: 30)
//                        .background(Color.white.opacity(0.055))
//                        .clipShape(Circle())
//                }
//                .buttonStyle(.plain)
//            }
//
//            Text("Complete this activity?")
//                .font(.system(size: 14.2, weight: .semibold))
//                .foregroundStyle(textSecondary.opacity(0.78))
//
//            HStack(spacing: 10) {
//                Button {
//                    markActivityDone(activity)
//                } label: {
//                    HStack(spacing: 8) {
//                        Image(systemName: "checkmark.circle.fill")
//                        Text("Done")
//                    }
//                    .font(.system(size: 14.2, weight: .bold))
//                    .foregroundStyle(.black.opacity(0.84))
//                    .frame(maxWidth: .infinity)
//                    .frame(height: 44)
//                    .background(WeekFitTheme.meal.opacity(0.90))
//                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
//                }
//                .buttonStyle(.plain)
//
//                Button {
//                    markActivitySkipped(activity)
//                } label: {
//                    HStack(spacing: 8) {
//                        Image(systemName: "xmark.circle.fill")
//                        Text("Skip")
//                    }
//                    .font(.system(size: 14.2, weight: .bold))
//                    .foregroundStyle(textPrimary.opacity(0.82))
//                    .frame(maxWidth: .infinity)
//                    .frame(height: 44)
//                    .background(Color.white.opacity(0.06))
//                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
//                    .overlay {
//                        RoundedRectangle(cornerRadius: 15, style: .continuous)
//                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
//                    }
//                }
//                .buttonStyle(.plain)
//            }
//        }
//        .padding(.horizontal, 18)
//        .padding(.top, 12)
//        .padding(.bottom, 18)
//        .background {
//            RoundedRectangle(cornerRadius: 26, style: .continuous)
//                .fill(
//                    LinearGradient(
//                        colors: [
//                            Color(red: 0.11, green: 0.12, blue: 0.11),
//                            Color(red: 0.07, green: 0.08, blue: 0.075)
//                        ],
//                        startPoint: .topLeading,
//                        endPoint: .bottomTrailing
//                    )
//                )
//        }
//        .overlay {
//            RoundedRectangle(cornerRadius: 26, style: .continuous)
//                .stroke(activity.color.opacity(0.13), lineWidth: 1)
//        }
//        .shadow(color: Color.black.opacity(0.30), radius: 20, y: -8)
//        .padding(.horizontal, 12)
//        .padding(.bottom, 92)
//    }
//
//    private func markActivityDone(_ activity: PlannedActivity) {
//        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
//
//        activity.isCompleted = true
//        activity.isSkipped = false
//
//        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
//            confirmationState.pendingActivity = nil
//        }
//
//        do {
//            try modelContext.save()
//        } catch {
//            print("Failed to mark activity done:", error)
//        }
//    }
//
//    private func markActivitySkipped(_ activity: PlannedActivity) {
//        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//
//        activity.isCompleted = false
//        activity.isSkipped = true
//
//        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
//            confirmationState.pendingActivity = nil
//        }
//
//        do {
//            try modelContext.save()
//        } catch {
//            print("Failed to mark activity skipped:", error)
//        }
//    }
//
//    private func displayStatus(for activity: PlannedActivity) -> ActivityDisplayStatus {
//        if activity.isCompleted {
//            return .completed
//        }
//
//        if activity.isSkipped {
//            return .skipped
//        }
//
//        if isCurrentActivity(activity) {
//            return .live
//        }
//
//        if activity.date < Date(), Calendar.current.isDateInToday(activity.date) {
//            return .missed
//        }
//
//        return .upcoming
//    }
//
//    private func timeColor(
//        for activity: PlannedActivity,
//        status: ActivityDisplayStatus
//    ) -> Color {
//        switch status {
//        case .completed:
//            return activity.color.opacity(0.72)
//        case .skipped:
//            return textSecondary.opacity(0.34)
//        case .live:
//            return activity.color.opacity(0.92)
//        case .missed:
//            return missedColor.opacity(0.84)
//        case .upcoming:
//            return textSecondary.opacity(0.62)
//        }
//    }
//
//    private func subtitle(
//        for activity: PlannedActivity,
//        status: ActivityDisplayStatus
//    ) -> String {
//        switch status {
//        case .completed:
//            return "\(activity.durationMinutes) min • Completed"
//        case .skipped:
//            return "\(activity.durationMinutes) min • Skipped"
//        case .live:
//            return "\(activity.durationMinutes) min • Active now"
//        case .missed:
//            return "\(activity.durationMinutes) min • Needs attention"
//        case .upcoming:
//            return activitySubtitle(activity)
//        }
//    }
//
//    private func iconBackground(
//        for activity: PlannedActivity,
//        status: ActivityDisplayStatus
//    ) -> Color {
//        switch status {
//        case .completed:
//            return activity.color.opacity(0.11)
//        case .skipped:
//            return Color.gray.opacity(0.090)
//        case .live:
//            return activity.color.opacity(livePulse ? 0.21 : 0.15)
//        case .missed:
//            return activity.color.opacity(0.105)
//        case .upcoming:
//            return activity.color.opacity(0.10)
//        }
//    }
//
//    private func iconColor(
//        for activity: PlannedActivity,
//        status: ActivityDisplayStatus
//    ) -> Color {
//        switch status {
//        case .completed:
//            return activity.color.opacity(0.72)
//        case .skipped:
//            return Color.gray.opacity(0.54)
//        case .live:
//            return activity.color.opacity(0.92)
//        case .missed:
//            return activity.color.opacity(0.66)
//        case .upcoming:
//            return activity.color.opacity(0.86)
//        }
//    }
//
//    private func titleColor(for status: ActivityDisplayStatus) -> Color {
//        switch status {
//        case .completed:
//            return textPrimary.opacity(0.72)
//        case .skipped:
//            return textPrimary.opacity(0.36)
//        case .live:
//            return textPrimary.opacity(0.98)
//        case .missed:
//            return textPrimary.opacity(0.68)
//        case .upcoming:
//            return textPrimary.opacity(0.92)
//        }
//    }
//
//    private func subtitleColor(for status: ActivityDisplayStatus) -> Color {
//        switch status {
//        case .completed:
//            return textSecondary.opacity(0.64)
//        case .skipped:
//            return textSecondary.opacity(0.36)
//        case .live:
//            return textSecondary.opacity(0.84)
//        case .missed:
//            return missedColor.opacity(0.66)
//        case .upcoming:
//            return textSecondary.opacity(0.70)
//        }
//    }
//
//    private func cardBackgroundStyle(
//        for activity: PlannedActivity,
//        status: ActivityDisplayStatus
//    ) -> AnyShapeStyle {
//        switch status {
//        case .live:
//            return AnyShapeStyle(
//                LinearGradient(
//                    colors: [
//                        activity.color.opacity(livePulse ? 0.17 : 0.12),
//                        activity.color.opacity(0.070),
//                        cardBackground.opacity(0.985)
//                    ],
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                )
//            )
//
//        case .completed:
//            return AnyShapeStyle(
//                LinearGradient(
//                    colors: [
//                        activity.color.opacity(0.050),
//                        cardSecondary.opacity(0.72),
//                        cardBackground.opacity(0.88)
//                    ],
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                )
//            )
//
//        case .skipped:
//            return AnyShapeStyle(
//                LinearGradient(
//                    colors: [
//                        Color.gray.opacity(0.050),
//                        cardSecondary.opacity(0.44),
//                        cardBackground.opacity(0.56)
//                    ],
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                )
//            )
//
//        case .missed:
//            return AnyShapeStyle(
//                LinearGradient(
//                    colors: [
//                        missedColor.opacity(0.052),
//                        activity.color.opacity(0.035),
//                        cardBackground.opacity(0.76)
//                    ],
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                )
//            )
//
//        case .upcoming:
//            return AnyShapeStyle(
//                LinearGradient(
//                    colors: [
//                        cardSecondary.opacity(0.94),
//                        cardBackground.opacity(0.985)
//                    ],
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                )
//            )
//        }
//    }
//
//    private func cardBorderColor(
//        for activity: PlannedActivity,
//        status: ActivityDisplayStatus
//    ) -> Color {
//        switch status {
//        case .completed:
//            return activity.color.opacity(0.16)
//        case .skipped:
//            return Color.gray.opacity(0.13)
//        case .live:
//            return activity.color.opacity(livePulse ? 0.34 : 0.22)
//        case .missed:
//            return missedColor.opacity(0.26)
//        case .upcoming:
//            return Color.white.opacity(0.038)
//        }
//    }
//
//    private func cardBorderWidth(for status: ActivityDisplayStatus) -> CGFloat {
//        switch status {
//        case .live:
//            return 1.25
//        case .completed, .skipped, .missed:
//            return 1
//        case .upcoming:
//            return 1
//        }
//    }
//
//    private func cardOpacity(for status: ActivityDisplayStatus) -> Double {
//        switch status {
//        case .completed:
//            return 0.82
//        case .skipped:
//            return 0.56
//        case .live:
//            return 1.0
//        case .missed:
//            return 0.86
//        case .upcoming:
//            return 1.0
//        }
//    }
//
//    private func nodeFillColor(
//        for activity: PlannedActivity,
//        status: ActivityDisplayStatus
//    ) -> Color {
//        switch status {
//        case .completed:
//            return activity.color.opacity(0.86)
//        case .skipped:
//            return Color.gray.opacity(0.56)
//        case .live:
//            return activity.color.opacity(0.92)
//        case .missed:
//            return missedColor.opacity(0.84)
//        case .upcoming:
//            return activity.color.opacity(0.60)
//        }
//    }
//
//    private func scrollToRelevantActivity(_ proxy: ScrollViewProxy) {
//        let activities = selectedDayActivities.sorted { $0.date < $1.date }
//
//        guard !activities.isEmpty else { return }
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
//            if let current = activities.first(where: {
//                isCurrentActivity($0) && !$0.isCompleted && !$0.isSkipped
//            }) {
//                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
//                    proxy.scrollTo(current.id, anchor: .center)
//                }
//                return
//            }
//
//            if Calendar.current.isDateInToday(selectedDate),
//               let upcoming = activities.first(where: {
//                   $0.date > Date() && !$0.isCompleted && !$0.isSkipped
//               }) {
//                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
//                    proxy.scrollTo(upcoming.id, anchor: .center)
//                }
//                return
//            }
//
//            if let first = activities.first {
//                proxy.scrollTo(first.id, anchor: .top)
//            }
//        }
//    }
//
//    private func handleActivityNotificationAction(_ notification: Notification) {
//        guard
//            let activityId = notification.userInfo?[ActivityNotificationKey.activityId] as? String,
//            let actionRaw = notification.userInfo?["action"] as? String,
//            let action = ActivityNotificationAction(rawValue: actionRaw)
//        else {
//            print("Invalid notification action payload:", notification.userInfo ?? [:])
//            return
//        }
//
//        guard let activity = plannedActivities.first(where: { $0.id == activityId }) else {
//            print("Activity not found for notification id:", activityId)
//            return
//        }
//
//        switch action {
//        case .done:
//            activity.isCompleted = true
//            activity.isSkipped = false
//
//        case .skipped:
//            activity.isCompleted = false
//            activity.isSkipped = true
//
//        case .later:
//            confirmationState.pendingActivity = activity
//
//        case .open:
//            confirmationState.pendingActivity = activity
//        }
//
//        do {
//            try modelContext.save()
//        } catch {
//            print("Failed to save notification action:", error)
//        }
//    }
//
//    private func isCurrentActivity(_ activity: PlannedActivity) -> Bool {
//        guard Calendar.current.isDateInToday(activity.date) else { return false }
//
//        let start = activity.date
//        let end = Calendar.current.date(
//            byAdding: .minute,
//            value: max(activity.durationMinutes, 30),
//            to: start
//        ) ?? start
//
//        return Date() >= start && Date() <= end
//    }
//
//    private func activitySubtitle(_ activity: PlannedActivity) -> String {
//        switch activity.type.lowercased() {
//        case "meal":
//            return "\(activity.durationMinutes) min • Nutrition"
//        case "workout":
//            return "\(activity.durationMinutes) min • Movement"
//        case "recovery":
//            return "\(activity.durationMinutes) min • Recovery"
//        case "habit":
//            return "\(activity.durationMinutes) min • Routine"
//        default:
//            return "\(activity.durationMinutes) min • Planned"
//        }
//    }
//
//    private func activityTime(_ date: Date) -> String {
//        date.formatted(
//            .dateTime.hour(.twoDigits(amPM: .omitted))
//                .minute(.twoDigits)
//        )
//    }
//
//    private var currentHour: Int {
//        Calendar.current.component(.hour, from: Date())
//    }
//
//    private var isEvening: Bool {
//        currentHour >= 18
//    }
//
//    private var isLateNight: Bool {
//        currentHour >= 22 || currentHour < 5
//    }
//
//    private var readinessHeadline: String {
//        guard healthManager.readyScore > 0 else {
//            return "Health data is still syncing"
//        }
//
//        switch healthManager.readyScore {
//        case 8...10:
//            return currentHour < 18 ? "Energy looks strong today" : "Your energy stayed balanced"
//
//        case 6..<8:
//            return currentHour < 18 ? "Energy feels steady today" : "Recovery looks balanced"
//
//        case 4..<6:
//            return "Recovery is a bit lower today"
//
//        default:
//            return "Recovery should come first today"
//        }
//    }
//
//    private var focusInsightText: String {
//        guard healthManager.readyScore > 0 else {
//            return "WeekFit adapts as your health data becomes available"
//        }
//
//        if healthManager.readyScore < 5 {
//            return isEvening || isLateNight
//                ? "Recovery matters more tonight"
//                : "A lighter pace may help today"
//        }
//
//        switch currentHour {
//        case 5..<12:
//            return "Best focus later this afternoon"
//        case 12..<17:
//            return "This is a good time for deep work"
//        case 17..<21:
//            return "Evening is better for lighter tasks"
//        default:
//            return "Time to slow down now"
//        }
//    }
//
//    private var readyStatusText: String {
//        guard healthManager.readyScore > 0 else {
//            return "Syncing"
//        }
//
//        switch healthManager.readyScore {
//        case 8...10:
//            return "High"
//        case 6..<8:
//            return "Balanced"
//        case 4..<6:
//            return "Reduced"
//        default:
//            return "Low"
//        }
//    }
//
//    private enum TodayPriorityKind {
//        case emptyDay
//        case missedActivity(PlannedActivity)
//        case liveActivity(PlannedActivity)
//        case sleepLow
//        case hydrationLow
//        case recoveryLow
//        case workoutSoon(PlannedActivity)
//        case mealSoon(PlannedActivity)
//        case nextStep(PlannedActivity)
//        case doneForToday
//        case steadyRhythm
//    }
//
//    private var todayPriority: TodayPriorityKind {
//        let now = Date()
//
//        guard Calendar.current.isDateInToday(selectedDate) else {
//            if selectedDayActivities.isEmpty {
//                return .emptyDay
//            }
//
//            if let firstActivity = selectedDayActivities.first(where: {
//                !$0.isCompleted && !$0.isSkipped
//            }) {
//                return .nextStep(firstActivity)
//            }
//
//            return .doneForToday
//        }
//
//        if selectedDayActivities.isEmpty {
//            return .emptyDay
//        }
//
//        if let liveActivity = selectedDayActivities.first(where: {
//            isCurrentActivity($0) &&
//            !$0.isCompleted &&
//            !$0.isSkipped
//        }) {
//            return .liveActivity(liveActivity)
//        }
//
//        if let missedActivity = selectedDayActivities.first(where: {
//            $0.date < now &&
//            !$0.isCompleted &&
//            !$0.isSkipped
//        }) {
//            return .missedActivity(missedActivity)
//        }
//
//        if sleepLooksLow {
//            return .sleepLow
//        }
//
//        if hydrationLooksLow {
//            return .hydrationLow
//        }
//
//        if recoveryLooksLow {
//            return .recoveryLow
//        }
//
//        if let workout = upcomingWorkoutSoon {
//            return .workoutSoon(workout)
//        }
//
//        if let meal = upcomingMealSoon {
//            return .mealSoon(meal)
//        }
//
//        if let nextActivity = nextOpenActivityToday {
//            return .nextStep(nextActivity)
//        }
//
//        if allActivitiesAreClosedToday {
//            return .doneForToday
//        }
//
//        return .steadyRhythm
//    }
//
//    private var priorityColor: Color {
//        switch todayPriority {
//        case .emptyDay:
//            return luxuryMeal
//
//        case .missedActivity:
//            return missedColor.opacity(0.84)
//
//        case .liveActivity(let activity),
//             .workoutSoon(let activity),
//             .mealSoon(let activity),
//             .nextStep(let activity):
//            return activity.color.opacity(0.86)
//
//        case .sleepLow,
//             .recoveryLow:
//            return luxuryRecovery
//
//        case .hydrationLow:
//            return WeekFitTheme.habit.opacity(0.82)
//
//        case .doneForToday,
//             .steadyRhythm:
//            return luxuryMeal
//        }
//    }
//
//    private var priorityIcon: String {
//        switch todayPriority {
//        case .emptyDay:
//            return "calendar.badge.plus"
//
//        case .missedActivity:
//            return "bell.fill"
//
//        case .liveActivity:
//            return "play.fill"
//
//        case .sleepLow:
//            return "moon.fill"
//
//        case .hydrationLow:
//            return "drop.fill"
//
//        case .recoveryLow:
//            return "leaf.fill"
//
//        case .workoutSoon:
//            return "figure.run"
//
//        case .mealSoon:
//            return "fork.knife"
//
//        case .nextStep:
//            return "arrow.right"
//
//        case .doneForToday:
//            return "checkmark.seal.fill"
//
//        case .steadyRhythm:
//            return "sparkles"
//        }
//    }
//
//    private var priorityTitle: String {
//        switch todayPriority {
//        case .emptyDay:
//            return "Nothing planned yet"
//
//        case .missedActivity:
//            return "This still needs attention"
//
//        case .liveActivity:
//            return "Active now"
//
//        case .sleepLow:
//            return "Sleep recovery looks low"
//
//        case .hydrationLow:
//            return "Hydration needs attention"
//
//        case .recoveryLow:
//            return "Recovery should come first"
//
//        case .workoutSoon:
//            return "Workout coming up"
//
//        case .mealSoon:
//            return "Meal coming up"
//
//        case .nextStep:
//            return "Coming up next"
//
//        case .doneForToday:
//            if isEvening || isLateNight {
//                return "Your day is winding down"
//            }
//
//            return "Today is complete"
//
//        case .steadyRhythm:
//            return "Everything feels steady"
//        }
//    }
//
//    private var prioritySubtitle: String {
//        switch todayPriority {
//        case .emptyDay:
//            return "Add a meal, workout or recovery activity"
//
//        case .missedActivity(let activity):
//            return "Review \(activity.title.lowercased()) when ready"
//
//        case .liveActivity(let activity):
//            return "\(activity.title) is in progress"
//
//        case .sleepLow:
//            if isEvening || isLateNight {
//                return "A quieter evening may help recovery"
//            }
//
//            return "Keep intensity lower today"
//
//        case .hydrationLow:
//            return "A glass of water may help now"
//
//        case .recoveryLow:
//            return "Walking or stretching may feel better"
//
//        case .workoutSoon:
//            return "Hydration will help before training"
//
//        case .mealSoon(let meal):
//            return "\(meal.title) is approaching"
//
//        case .nextStep(let activity):
//            return "\(activityTime(activity.date)) • \(activity.title)"
//
//        case .doneForToday:
//            if isEvening || isLateNight {
//                return "The rest of the evening can stay light"
//            }
//
//            return "Recovery matters more now"
//
//        case .steadyRhythm:
//            return "Meals, movement and recovery look balanced"
//        }
//    }
//
//    private var nextOpenActivityToday: PlannedActivity? {
//        selectedDayActivities.first {
//            $0.date > Date() &&
//            !$0.isCompleted &&
//            !$0.isSkipped
//        }
//    }
//
//    private var upcomingWorkoutSoon: PlannedActivity? {
//        selectedDayActivities.first {
//            $0.type.lowercased() == "workout" &&
//            $0.date > Date() &&
//            $0.date <= Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date() &&
//            !$0.isCompleted &&
//            !$0.isSkipped
//        }
//    }
//
//    private var upcomingMealSoon: PlannedActivity? {
//        selectedDayActivities.first {
//            $0.type.lowercased() == "meal" &&
//            $0.date > Date() &&
//            $0.date <= Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date() &&
//            !$0.isCompleted &&
//            !$0.isSkipped
//        }
//    }
//
//    private var allActivitiesAreClosedToday: Bool {
//        !selectedDayActivities.isEmpty &&
//        selectedDayActivities.allSatisfy {
//            $0.isCompleted || $0.isSkipped
//        }
//    }
//
//    private var sleepLooksLow: Bool {
//        healthManager.sleepHours > 0 &&
//        healthManager.sleepHours < 6
//    }
//
//    private var hydrationLooksLow: Bool {
//        healthManager.waterLiters > 0 &&
//        healthManager.waterLiters < 1.5
//    }
//
//    private var recoveryLooksLow: Bool {
//        healthManager.readyScore > 0 &&
//        healthManager.readyScore < 5
//    }
//
//    private func changeDate(by days: Int) {
//        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
//            selectedDate = Calendar.current.date(
//                byAdding: .day,
//                value: days,
//                to: selectedDate
//            ) ?? selectedDate
//        }
//    }
//
//    private var selectedDateTitle: String {
//        let formatter = DateFormatter()
//        formatter.locale = Locale(identifier: "en_US")
//        formatter.dateFormat = "EEE, MMM d"
//        return formatter.string(from: selectedDate)
//    }
//
//    private func updateNutrition() {
//        let metrics = DailyNutritionMetrics(
//            protein: healthManager.protein,
//            carbs: healthManager.carbs,
//            fats: healthManager.fats,
//            calories: healthManager.calories,
//            waterLiters: healthManager.waterLiters,
//            activeCalories: healthManager.activeCalories,
//            sleepHours: healthManager.sleepHours,
//            weightKg: healthManager.weight
//        )
//
//        let profile = UserNutritionProfile(
//            weightKg: healthManager.weight,
//            heightCm: healthManager.heightCm,
//            age: healthManager.age,
//            sex: healthManager.biologicalSex == .male ? .male : .female,
//            goal: .maintenance
//        )
//
//        nutritionViewModel.updateNutrition(
//            metrics: metrics,
//            profile: profile,
//            plannedActivities: selectedDayActivities
//        )
//    }
//    
//    private func refreshHealthAndNutrition() {
//        Task {
//            await refreshHealthAndNutritionAsync()
//        }
//    }
//
//    private func refreshHealthAndNutritionAsync() async {
//        guard healthManager.isHealthAccessRequested else {
//            await MainActor.run {
//                updateNutrition()
//            }
//            return
//        }
//
//        await healthManager.loadHealthData(
//            for: selectedDate,
//            plannedActivities: selectedDayActivities
//        )
//
//        await MainActor.run {
//            updateNutrition()
//        }
//
//        print("🏠 Home refreshed")
//        print("🛌 sleep:", healthManager.sleepText)
//        print("🔥 activeCalories:", healthManager.activeCalories)
//        print("👟 steps:", healthManager.steps)
//    }
//    
//    private func forceHomeHealthRefresh() {
//        healthRefreshID = UUID()
//    }
//}
