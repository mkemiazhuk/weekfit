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
                  calendar.isDate(activity.date, inSameDayAs: now)
            else { return false }

            let endLimit = calendar.date(
                byAdding: .minute,
                value: activity.durationMinutes,
                to: activity.date
            ) ?? activity.date

            return activity.date <= now && now <= endLimit
        }
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 14)

                if let liveItem = activeLiveActivity {
                    liveSessionCard(liveItem)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }

                segmentedControl
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                activityOptionsList
            }
        }
    }

    // Final design spec adjustments for absolute symmetry
    private var sheetHeader: some View {
        ZStack {
            Text(activeLiveActivity != nil ? "Active Tracker" : "Start Activity")
                .font(.system(size: 16.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))

            HStack {
                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Text("Close")
                        .font(.system(size: 13.0, weight: .bold))
                        .foregroundStyle(.white.opacity(0.70))
                        .frame(width: 68, height: 30) // Optimized for a refined, slim profile
                        .background(Capsule().fill(.white.opacity(0.05)))
                        .overlay(Capsule().stroke(.white.opacity(0.04), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16) // 🎯 Aligns perfectly with standard content card margins
            }
        }
        .frame(height: 46)
    }
    
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton("Workout")
            segmentButton("Recovery")
        }
        .padding(3)
        .frame(height: 38) // Слегка увеличили высоту для лучшего тап-таргета (HIG)
        .background(
            Capsule()
                .fill(.white.opacity(0.04)) // Сделали общую подложку еще более воздушной
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.03), lineWidth: 1)
        )
    }

    private func segmentButton(_ title: String) -> some View {
        let isSelected = currentSubTab == title

        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) { // Чуть ускорили отклик тапа
                currentSubTab = title
            }
        } label: {
            Text(title)
                .font(.system(size: 13.5, weight: isSelected ? .bold : .semibold)) // Выбранный текст делаем .bold
                .foregroundStyle(isSelected ? .white : .white.opacity(0.45)) // Увеличили контраст между состояниями
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .background {
                    if isSelected {
                        Capsule()
                            // Используем нативный системный блюр вместо тяжелой заливки
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    // Мягкое внутреннее свечение для выделения активной вкладки
                                    .stroke(.white.opacity(0.08), lineWidth: 1)
                            )
                            // Добавляем ультра-легкую белую альфу, чтобы на темных обложках таб не терялся
                            .background(Capsule().fill(.white.opacity(0.05)))
                            .matchedGeometryEffect(id: "activeTab", in: tabNamespace) // Если используешь Namespace для плавного переезда плашки
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var activityOptionsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                let options = currentSubTab == "Workout"
                    ? PlannerType.workout.options
                    : PlannerType.recovery.options

                let systemIcon = currentSubTab == "Workout"
                    ? PlannerType.workout.icon
                    : PlannerType.recovery.icon

                let baseAccentColor = currentSubTab == "Workout"
                    ? Color(red: 0.46, green: 0.72, blue: 0.82)
                    : Color(red: 0.66, green: 0.58, blue: 0.86)

                let visualAccentColor = baseAccentColor.opacity(0.82)

                ForEach(options, id: \.title) { option in
                    let isBlocked = activeLiveActivity != nil

                    PremiumActivityStartCard(
                        title: option.title,
                        subtitle: option.subtitle,
                        systemIcon: systemIcon,
                        imageName: option.imageName,
                        accentColor: visualAccentColor,
                        cardBackground: cardBackground,
                        textSecondary: textSecondary,
                        durationMinutes: 60,
                        plannerType: currentSubTab == "Workout" ? .workout : .recovery,
                        hasConflict: isBlocked
                    ) {
                        let newActivity = PlannedActivity(
                            id: UUID().uuidString,
                            date: Date(),
                            type: currentSubTab == "Workout" ? "workout" : "recovery",
                            title: option.title,
                            durationMinutes: 60,
                            icon: systemIcon,
                            imageName: option.imageName,
                            colorRed: currentSubTab == "Workout" ? 0.46 : 0.66,
                            colorGreen: currentSubTab == "Workout" ? 0.72 : 0.58,
                            colorBlue: currentSubTab == "Workout" ? 0.82 : 0.86,
                            calories: 0,
                            protein: 0,
                            carbs: 0,
                            fats: 0,
                            isCompleted: false,
                            isSkipped: false
                        )

                        modelContext.insert(newActivity)
                        try? modelContext.save()

                        isPresented = false
                        refreshID = UUID()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func liveSessionCard(_ liveItem: PlannedActivity) -> some View {
        let accentColor = liveItem.type.lowercased() == "workout"
            ? Color(red: 0.46, green: 0.72, blue: 0.82)
            : Color(red: 0.66, green: 0.58, blue: 0.86)

        return VStack(spacing: 7) {
            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                        .phaseAnimator([0.35, 1.0]) { content, phase in
                            content.opacity(phase)
                        } animation: { _ in
                            .easeInOut(duration: 0.85)
                        }

                    Text("LIVE SESSION")
                        .font(.system(size: 9.4, weight: .bold))
                        .tracking(0.55)
                        .foregroundStyle(accentColor.opacity(0.95))
                }

                Spacer()
            }

            HStack(alignment: .center, spacing: 11) {
                Image(systemName: liveItem.icon)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.96))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.055))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(liveItem.title)
                        .font(.system(size: 15.6, weight: .bold)) // Чуть уплотнили для уверенного веса в хабе
                        .foregroundStyle(.white.opacity(0.97))
                        .lineLimit(1)

                    // 🎯 ОБНОВЛЕНО: Динамический индикатор цвета категории + лаконичное автовыключение
                    HStack(spacing: 4) {
                        Text("Active now")
                            .font(.system(size: 11.2, weight: .semibold))
                            .foregroundStyle(liveItem.type.lowercased() == "workout"
                                             ? Color(red: 0.46, green: 0.72, blue: 0.82)
                                             : Color(red: 0.66, green: 0.58, blue: 0.86))
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    liveTimer(startedAt: liveItem.date)

                    liveProgressText(
                        startedAt: liveItem.date,
                        maxMinutes: liveItem.durationMinutes
                    )

                    Button {
                        stopLiveSession(liveItem)
                    } label: {
                        HStack(spacing: 5) {
                            Text("Stop")
                                .font(.system(size: 11.8, weight: .bold))

                            Image(systemName: "stop.fill")
                                .font(.system(size: 6.8, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.94))
                        .padding(.horizontal, 13)
                        .frame(height: 28)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.72))
                        )
                        .shadow(
                            color: Color.red.opacity(0.14),
                            radius: 5,
                            y: 2
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 3)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.09),
                            Color.white.opacity(0.018),
                            Color.white.opacity(0.009)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.28),
                            .white.opacity(0.05),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: accentColor.opacity(0.07),
            radius: 10,
            y: 3
        )
    }

    private func liveTimer(startedAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(startedAt)))
            let minutes = elapsed / 60
            let seconds = elapsed % 60
            let timeText = String(format: "%02d:%02d", minutes, seconds)

            Text(timeText)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.97))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 86, alignment: .trailing)
        }
    }

    private func liveProgressText(startedAt: Date, maxMinutes: Int) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(startedAt)))
            let elapsedMinutes = min(elapsed / 60, maxMinutes)

            Text("\(elapsedMinutes) / \(maxMinutes) min")
                .font(.system(size: 10.4, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.40))
                .lineLimit(1)
        }
    }

    private func stopLiveSession(_ activity: PlannedActivity) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring()) {
            activity.isCompleted = true

            let passedMinutes = Int(Date().timeIntervalSince(activity.date) / 60)
            activity.durationMinutes = max(1, min(passedMinutes, 60))

            try? modelContext.save()
            refreshID = UUID()
            isPresented = false
        }
    }
}
