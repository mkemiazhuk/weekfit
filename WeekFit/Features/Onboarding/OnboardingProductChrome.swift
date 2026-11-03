import SwiftUI

enum OnboardingSampleData {
    /// Morning-ready body (Promise + Live Change start).
    static let morningRecoveryPercent = 82
    /// After midday drop (Live Change end + Today preview).
    static let afternoonRecoveryPercent = 61
    static let activityPercent = 67
    static let nutritionPercent = 42

    static var morningRecoveryProgress: CGFloat { CGFloat(morningRecoveryPercent) / 100 }
    static var afternoonRecoveryProgress: CGFloat { CGFloat(afternoonRecoveryPercent) / 100 }
    static var activityProgress: CGFloat { CGFloat(activityPercent) / 100 }
    static var nutritionProgress: CGFloat { CGFloat(nutritionPercent) / 100 }

    static let activityKcal = 445
    static let activityGoal = 660
    static let nutritionEaten = 720
    static let nutritionLeft = 999
    static let sleepHours = 6.5
    static let mealSampleKcal = 330
}

// MARK: - Causality chain (body → Health → WeekFit → Coach)

struct OnboardingCausalityStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0

    private let nodes: [(icon: String, color: Color, key: String)] = [
        ("figure.stand", WeekFitProgressRingColor.recovery, "onboarding.v10.causality.node.body"),
        ("heart.fill", Color(red: 1.0, green: 0.30, blue: 0.40), "onboarding.v10.causality.node.health"),
        ("sparkles", WeekFitTheme.primaryGreen, "onboarding.v10.causality.node.weekfit"),
        ("brain.head.profile", WeekFitTheme.coachAccent, "onboarding.v10.causality.node.coach")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
                causalityRow(icon: node.icon, color: node.color, key: node.key, index: index)
                if index < nodes.count - 1 {
                    causalityConnector(visible: revealed > index)
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear { runReveal() }
        .accessibilityElement(children: .combine)
    }

    private func causalityRow(icon: String, color: Color, key: String, index: Int) -> some View {
        let visible = revealed > index
        return HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.14))
                }

            Text(WeekFitLocalizedString(key))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WeekFitTheme.whiteOpacity(visible ? 0.06 : 0.02))
        }
        .opacity(visible ? 1 : 0.25)
        .offset(y: visible ? 0 : 8)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: revealed)
    }

    private func causalityConnector(visible: Bool) -> some View {
        Rectangle()
            .fill(WeekFitTheme.whiteOpacity(visible ? 0.18 : 0.06))
            .frame(width: 2, height: 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 35)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: revealed)
    }

    private func runReveal() {
        if reduceMotion {
            revealed = nodes.count
            return
        }
        for i in 1...nodes.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.28) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    revealed = i
                }
                if i == nodes.count {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
        }
    }
}

// MARK: - Live Change (hero demonstration)

struct OnboardingLiveChangeStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0
    /// Afternoon ring only — morning stays locked at sample morning recovery.
    @State private var afternoonRecovery = OnboardingSampleData.morningRecoveryPercent

    private var morningRecovery: Int { OnboardingSampleData.morningRecoveryPercent }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            morningCard
                .opacity(phase >= 0 ? 1 : 0)

            if phase >= 1 {
                connector
                afternoonCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if phase >= 2 {
                connector
                coachUpdateCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if phase >= 3 {
                HStack(spacing: 10) {
                    updateChip(
                        icon: "flame.fill",
                        color: WeekFitProgressRingColor.nutrition,
                        text: WeekFitLocalizedString("onboarding.v10.live.update.calories")
                    )
                    if phase >= 4 {
                        updateChip(
                            icon: "fork.knife",
                            color: WeekFitTheme.meal,
                            text: WeekFitLocalizedString("onboarding.v10.live.update.meals")
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear { runSequence() }
        .accessibilityElement(children: .combine)
    }

    private var morningCard: some View {
        timelineCard(
            time: WeekFitLocalizedString("onboarding.v10.live.morning.time"),
            accent: WeekFitProgressRingColor.recovery
        ) {
            HStack(spacing: 10) {
                recoveryBadge(morningRecovery)
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        String(
                            format: WeekFitLocalizedString("onboarding.v10.live.morning.recovery"),
                            morningRecovery
                        )
                    )
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    coachLine(WeekFitLocalizedString("onboarding.v10.live.morning.coach"))
                }
            }
        }
    }

    private var afternoonCard: some View {
        timelineCard(
            time: WeekFitLocalizedString("onboarding.v10.live.afternoon.time"),
            accent: WeekFitTheme.coachAccent
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(WeekFitLocalizedString("onboarding.v10.live.afternoon.recovery"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                HStack(spacing: 10) {
                    recoveryBadge(afternoonRecovery)
                    Text(
                        String(
                            format: WeekFitLocalizedString("onboarding.v10.live.afternoon.recoveryValueFormat"),
                            afternoonRecovery
                        )
                    )
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                }
            }
        }
    }

    private var coachUpdateCard: some View {
        timelineCard(
            time: nil,
            accent: WeekFitTheme.coachAccent
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(WeekFitLocalizedString("onboarding.v10.live.update.coach"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                } icon: {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(WeekFitTheme.coachAccent)

                Text(WeekFitLocalizedString("onboarding.v10.live.update.priority"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)

                Text(WeekFitLocalizedString("onboarding.v10.live.update.move"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
            }
        }
    }

    private var connector: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(WeekFitTheme.tertiaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
    }

    private func timelineCard(
        time: String?,
        accent: Color,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let time {
                Text(time)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.tertiaryText)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .leading)
                    .padding(.top, 14)
            } else {
                Color.clear.frame(width: 44)
            }

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .weekFitPremiumCard(accent: accent, cornerRadius: 18, featured: accent == WeekFitTheme.coachAccent)
        }
    }

    private func recoveryBadge(_ value: Int) -> some View {
        WeekFitProgressRing(
            progress: CGFloat(value) / 100,
            color: WeekFitProgressRingColor.recovery,
            size: 44,
            strokeWidth: 3.2
        ) {
            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
        }
    }

    private func coachLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WeekFitTheme.coachAccent)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func updateChip(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(accent: color, cornerRadius: 16, featured: false)
    }

    private func runSequence() {
        phase = 0
        afternoonRecovery = OnboardingSampleData.morningRecoveryPercent

        if reduceMotion {
            phase = 4
            afternoonRecovery = OnboardingSampleData.afternoonRecoveryPercent
            return
        }

        let steps: [(delay: Double, action: () -> Void)] = [
            (0.9, {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { phase = 1 }
            }),
            (1.5, {
                withAnimation(.easeInOut(duration: 0.55)) {
                    afternoonRecovery = OnboardingSampleData.afternoonRecoveryPercent
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }),
            (2.2, {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { phase = 2 }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }),
            (3.0, {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { phase = 3 }
            }),
            (3.55, {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { phase = 4 }
            })
        ]

        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                step.action()
            }
        }
    }
}

// MARK: - Today home + Coach bridge

struct OnboardingTodayExperience: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringProgress: CGFloat = 0
    @State private var coachVisible = false
    @State private var actionsVisible = false
    @State private var highlightAction: QuickAction? = .drinks
    @State private var selected: RingKind = .recovery

    enum RingKind: Int, CaseIterable {
        case recovery, activity, nutrition

        var color: Color {
            switch self {
            case .recovery: return WeekFitProgressRingColor.recovery
            case .activity: return WeekFitProgressRingColor.activity
            case .nutrition: return WeekFitProgressRingColor.nutrition
            }
        }

        var progress: CGFloat {
            switch self {
            case .recovery: return OnboardingSampleData.afternoonRecoveryProgress
            case .activity: return OnboardingSampleData.activityProgress
            case .nutrition: return OnboardingSampleData.nutritionProgress
            }
        }

        var percent: Int {
            switch self {
            case .recovery: return OnboardingSampleData.afternoonRecoveryPercent
            case .activity: return OnboardingSampleData.activityPercent
            case .nutrition: return OnboardingSampleData.nutritionPercent
            }
        }

        var center: String {
            String(
                format: WeekFitLocalizedString("onboarding.v10.promise.percentFormat"),
                percent
            )
        }

        var titleKey: String {
            switch self {
            case .recovery: return "today.status.recovery"
            case .activity: return "today.status.activity"
            case .nutrition: return "today.status.nutrition"
            }
        }
    }

    enum QuickAction: Int, CaseIterable {
        case drinks, food, activity

        var icon: String {
            switch self {
            case .drinks: return "drop.fill"
            case .food: return "fork.knife"
            case .activity: return "play.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .drinks: return WeekFitProgressRingColor.recovery
            case .food: return WeekFitProgressRingColor.nutrition
            case .activity: return WeekFitProgressRingColor.activity
            }
        }

        var labelKey: String {
            switch self {
            case .drinks: return "onboarding.v10.today.action.drinks"
            case .food: return "onboarding.v10.today.action.food"
            case .activity: return "onboarding.v10.today.action.activity"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            overview
            coachBridge
                .opacity(coachVisible ? 1 : 0)
                .offset(y: coachVisible ? 0 : 10)
            logQuickly
                .opacity(actionsVisible ? 1 : 0)
                .offset(y: actionsVisible ? 0 : 12)
        }
        .onAppear { runEntrance() }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(WeekFitLocalizedString("today.overview.title").uppercased())
                .font(.caption2.weight(.semibold))
                .fontDesign(.rounded)
                .tracking(1.2)
                .foregroundStyle(WeekFitTheme.tertiaryText)

            HStack(spacing: 8) {
                ForEach(RingKind.allCases, id: \.rawValue) { kind in
                    interactiveRing(kind)
                }
            }
        }
        .padding(14)
        .weekFitPremiumCard(accent: WeekFitProgressRingColor.activity, cornerRadius: 22, featured: true)
    }

    private var coachBridge: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WeekFitTheme.coachAccent)
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(WeekFitTheme.coachAccent.opacity(0.14))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(WeekFitLocalizedString("onboarding.v10.today.coachBridge").uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(WeekFitTheme.coachAccent.opacity(0.90))

                Text(WeekFitLocalizedString("onboarding.v10.live.update.move"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .weekFitPremiumCard(accent: WeekFitTheme.coachAccent, cornerRadius: 18, featured: true)
        .accessibilityElement(children: .combine)
    }

    private func interactiveRing(_ kind: RingKind) -> some View {
        let isSelected = selected == kind
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82)) {
                selected = kind
            }
        } label: {
            VStack(spacing: 6) {
                WeekFitProgressRing(
                    progress: ringProgress * kind.progress,
                    color: kind.color,
                    size: isSelected ? 62 : 54,
                    strokeWidth: isSelected ? 3.8 : 3.2
                ) {
                    Text(kind.center)
                        .font(.system(size: isSelected ? 12 : 11, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }
                .shadow(color: isSelected ? kind.color.opacity(0.35) : .clear, radius: 8, y: 1)

                Text(WeekFitLocalizedString(kind.titleKey))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? kind.color : WeekFitTheme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WeekFitLocalizedString(kind.titleKey))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var logQuickly: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("onboarding.v10.today.actionsTitle").uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(WeekFitTheme.tertiaryText)

            HStack(spacing: 8) {
                ForEach(QuickAction.allCases, id: \.rawValue) { action in
                    quick(action)
                }
            }

            Text(WeekFitLocalizedString("onboarding.v10.today.actionHint"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WeekFitTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .weekFitPremiumCard(accent: WeekFitTheme.workout, cornerRadius: 18, featured: true)
    }

    private func quick(_ action: QuickAction) -> some View {
        let highlighted = highlightAction == action
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.84)) {
                highlightAction = action
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(action.color)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(action.color.opacity(highlighted ? 0.22 : 0.12))
                    }
                    .overlay {
                        Circle()
                            .stroke(action.color.opacity(highlighted ? 0.55 : 0), lineWidth: 1.2)
                    }
                    .scaleEffect(highlighted ? 1.06 : 1)

                Text(WeekFitLocalizedString(action.labelKey))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(highlighted ? WeekFitTheme.primaryText : WeekFitTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WeekFitLocalizedString(action.labelKey))
        .accessibilityAddTraits(highlighted ? .isSelected : [])
    }

    private func runEntrance() {
        ringProgress = 0
        coachVisible = false
        actionsVisible = false
        highlightAction = .drinks
        if reduceMotion {
            ringProgress = 1
            coachVisible = true
            actionsVisible = true
            return
        }
        withAnimation(.easeOut(duration: 0.85)) {
            ringProgress = 1
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86).delay(0.35)) {
            coachVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86).delay(0.55)) {
            actionsVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                highlightAction = .activity
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                highlightAction = .drinks
            }
        }
    }
}

// MARK: - Coach (what / why / next)

struct OnboardingCoachHero: View {
    private let accent = WeekFitTheme.coachAccent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .semibold))
                Text(WeekFitLocalizedString("onboarding.v10.coach.badge").uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.5)
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background { Capsule().fill(accent.opacity(0.12)) }

            VStack(alignment: .leading, spacing: 16) {
                block(
                    WeekFitLocalizedString("onboarding.v10.coach.changed"),
                    WeekFitLocalizedString("onboarding.v10.coach.changed.value")
                )
                block(
                    WeekFitLocalizedString("onboarding.v10.coach.why"),
                    WeekFitLocalizedString("onboarding.v10.coach.why.value")
                )
                block(
                    WeekFitLocalizedString("onboarding.v10.coach.next"),
                    WeekFitLocalizedString("onboarding.v10.coach.next.value")
                )
            }
            .padding(.top, 18)

            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(WeekFitLocalizedString("onboarding.v10.coach.footer"))
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(WeekFitTheme.secondaryText)
            .padding(.top, 18)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.16),
                            WeekFitTheme.cardBackground.opacity(0.55),
                            WeekFitTheme.cardBackground.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: accent.opacity(0.18), radius: 24, y: 10)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                    appeared = true
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func block(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(WeekFitTheme.tertiaryText)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Ahead: Plan + Meals

struct OnboardingAheadComposition: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            planBlock
                .opacity(phase >= 1 ? 1 : 0)
                .offset(y: phase >= 1 ? 0 : 10)

            mealsBlock
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 ? 0 : 10)

            tipRow
                .opacity(phase >= 3 ? 1 : 0)
                .offset(y: phase >= 3 ? 0 : 8)
        }
        .onAppear { reveal() }
    }

    private var tipRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WeekFitTheme.primaryGreen)
                .padding(.top, 1)
            Text(WeekFitLocalizedString("onboarding.v10.ahead.tip"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .weekFitPremiumCard(accent: WeekFitTheme.primaryGreen, cornerRadius: 16, featured: false)
    }

    private var planBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("onboarding.v10.ahead.planLabel").uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(WeekFitTheme.workout.opacity(0.85))

            aheadRow(
                time: "18:00",
                title: WeekFitLocalizedString("onboarding.v3.plan.workout"),
                detail: WeekFitLocalizedString("onboarding.v7.plan.workoutDetail"),
                icon: "figure.strengthtraining.traditional",
                color: WeekFitProgressRingColor.activity
            )
            aheadRow(
                time: "21:00",
                title: WeekFitLocalizedString("onboarding.v3.plan.recovery"),
                detail: WeekFitLocalizedString("onboarding.v7.plan.recoveryDetail"),
                icon: "moon.zzz.fill",
                color: WeekFitTheme.workout
            )
        }
        .padding(14)
        .weekFitPremiumCard(accent: WeekFitTheme.workout, cornerRadius: 20, featured: false)
    }

    private var mealsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("onboarding.v10.ahead.mealsLabel").uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(WeekFitTheme.meal.opacity(0.90))

            HStack(spacing: 8) {
                chip(WeekFitLocalizedString("onboarding.v7.meals.ing.chicken"))
                chip(WeekFitLocalizedString("onboarding.v7.meals.ing.rice"))
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WeekFitTheme.tertiaryText)
                Text(
                    String(
                        format: WeekFitLocalizedString("onboarding.v10.ahead.kcalFormat"),
                        OnboardingSampleData.mealSampleKcal
                    )
                )
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitProgressRingColor.nutrition)
            }

            Text(WeekFitLocalizedString("onboarding.v10.ahead.mealsLine"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WeekFitTheme.secondaryText)
        }
        .padding(14)
        .weekFitPremiumCard(accent: WeekFitTheme.meal, cornerRadius: 20, featured: true)
    }

    private func aheadRow(
        time: String,
        title: String,
        detail: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 12) {
            Text(time)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.tertiaryText)
                .monospacedDigit()
                .frame(width: 42, alignment: .leading)

            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background { Circle().fill(color.opacity(0.14)) }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(WeekFitTheme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                Capsule().fill(WeekFitTheme.whiteOpacity(0.06))
            }
    }

    private func reveal() {
        if reduceMotion {
            phase = 3
            return
        }
        withAnimation(.easeOut(duration: 0.4)) { phase = 1 }
        withAnimation(.easeOut(duration: 0.4).delay(0.18)) { phase = 2 }
        withAnimation(.easeOut(duration: 0.4).delay(0.36)) { phase = 3 }
    }
}

// MARK: - Ready climax (payoff, not further education)

struct OnboardingReadyClimax: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weekFitPalette) private var palette

    let recoveryPercent: Int?
    let activityPercent: Int?
    let nutritionPercent: Int?
    let greetingTitle: String
    let reasoningLine: String
    let trainLine: String
    let mealLine: String
    let recoveryLine: String
    let footerLine: String

    @State private var visible = false

    private var recovery: Int {
        recoveryPercent ?? OnboardingSampleData.morningRecoveryPercent
    }

    private var activity: Int {
        activityPercent ?? OnboardingSampleData.activityPercent
    }

    private var nutrition: Int {
        nutritionPercent ?? OnboardingSampleData.nutritionPercent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingTitle(text: greetingTitle)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 8)

            OnboardingSubtitle(text: WeekFitLocalizedString("onboarding.v12.ready.subtitle.planReady"))
                .padding(.top, OnboardingLayout.titleToSubtitle)
                .opacity(visible ? 1 : 0)

            Text(reasoningLine)
                .font(.system(size: OnboardingLayout.CardSecondary.size, weight: .medium))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .opacity(visible ? 1 : 0)

            coachCard
                .padding(.top, OnboardingLayout.subtitleToContent)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 10)

            OnboardingHelper(text: WeekFitLocalizedString("onboarding.v16.ready.healthFootnote"))
                .padding(.top, OnboardingLayout.contentToHelper)
                .opacity(visible ? 1 : 0)

            OnboardingHelper(text: footerLine)
                .padding(.top, 6)
                .opacity(visible ? 1 : 0)

            Spacer(minLength: OnboardingLayout.minBreathingRoom)
        }
        .onAppear {
            if reduceMotion {
                visible = true
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    visible = true
                }
            }
        }
    }

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(WeekFitLocalizedString("onboarding.v12.ready.planLabel").uppercased())
                .font(.system(size: OnboardingLayout.Eyebrow.size, weight: .bold, design: .rounded))
                .tracking(OnboardingLayout.Eyebrow.tracking)
                .foregroundStyle(WeekFitTheme.coachAccent)

            VStack(alignment: .leading, spacing: 12) {
                coachRow(icon: "figure.run", color: WeekFitProgressRingColor.activity, text: trainLine)
                coachRow(icon: "fork.knife", color: WeekFitProgressRingColor.nutrition, text: mealLine)
                coachRow(icon: "moon.fill", color: WeekFitProgressRingColor.recovery, text: recoveryLine)
            }

            HStack(alignment: .top, spacing: 8) {
                OnboardingLabeledRing(
                    progress: CGFloat(activity) / 100,
                    color: OnboardingMetricKind.activity.color,
                    percentText: "\(activity)%",
                    icon: OnboardingMetricKind.activity.icon,
                    title: OnboardingMetricKind.activity.title,
                    size: 56,
                    strokeWidth: 3.6,
                    ink: WeekFitTheme.primaryText,
                    labelInk: WeekFitTheme.secondaryText
                )
                OnboardingLabeledRing(
                    progress: CGFloat(nutrition) / 100,
                    color: OnboardingMetricKind.nutrition.color,
                    percentText: "\(nutrition)%",
                    icon: OnboardingMetricKind.nutrition.icon,
                    title: OnboardingMetricKind.nutrition.title,
                    size: 56,
                    strokeWidth: 3.6,
                    ink: WeekFitTheme.primaryText,
                    labelInk: WeekFitTheme.secondaryText
                )
                OnboardingLabeledRing(
                    progress: CGFloat(recovery) / 100,
                    color: OnboardingMetricKind.recovery.color,
                    percentText: "\(recovery)%",
                    icon: OnboardingMetricKind.recovery.icon,
                    title: OnboardingMetricKind.recovery.title,
                    size: 56,
                    strokeWidth: 3.6,
                    ink: WeekFitTheme.primaryText,
                    labelInk: WeekFitTheme.secondaryText
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(OnboardingLayout.cardRowHorizontal)
        .weekFitPremiumCard(
            accent: WeekFitTheme.coachAccent,
            cornerRadius: OnboardingLayout.cardCornerRadius,
            featured: true
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            [
                WeekFitLocalizedString("onboarding.v12.ready.planLabel"),
                trainLine,
                mealLine,
                recoveryLine
            ].joined(separator: ". ")
        )
    }

    private func coachRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background {
                    Circle().fill(color.opacity(palette.isLight ? 0.12 : 0.14))
                }

            Text(text)
                .font(.system(size: OnboardingLayout.CardTitle.size, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

}

// MARK: - Begin: sacred calm climax

struct OnboardingBeginMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        ZStack {
            Circle()
                .fill(WeekFitTheme.brandGold.opacity(on ? 0.14 : 0.04))
                .frame(width: 120, height: 120)
                .blur(radius: 18)

            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(WeekFitTheme.brandGold)
                .opacity(on ? 1 : 0)
                .scaleEffect(on ? 1 : 0.8)
        }
        .frame(height: 120)
        .onAppear {
            if reduceMotion {
                on = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05)) {
                    on = true
                }
            }
        }
        .accessibilityHidden(true)
    }
}
