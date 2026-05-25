import SwiftUI

struct InsightsView: View {

    @ObservedObject var authViewModel: AuthViewModel
    @State private var showContent = false
    @State private var showProfile = false
    @State private var selectedDate = Date()

    private let background = WeekFitTheme.background
    private let cardBackground = WeekFitTheme.cardBackground
    private let cardSecondary = WeekFitTheme.cardSecondary
    private let elevatedCard = WeekFitTheme.elevatedCard

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let textTertiary = WeekFitTheme.tertiaryText

    private let softShadow = WeekFitTheme.cardShadow
    private let cardShadow = WeekFitTheme.cardShadow

    private let weekDays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background.ignoresSafeArea()
                ambientBackground

                VStack(spacing: 6) {
                    heroHeaderSection
                        .padding(.top, 4)
                        .frame(width: proxy.size.width - 40)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 9) {
                            heroInsightCard
                            weeklyScoresSection
                            trendsSection
                            hydrationCorrelationCard
                            weeklyReflectionCard
                        }
                        .frame(width: proxy.size.width - 40)
                        .padding(.bottom, 200)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    }
                    .frame(width: proxy.size.width)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                showContent = true
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
            .presentationDetents([.large])
            .presentationCornerRadius(36)
            .presentationDragIndicator(.hidden)
        }
    }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [
                    WeekFitTheme.meal.opacity(0.07),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 320
            )

            RadialGradient(
                colors: [
                    WeekFitTheme.blue.opacity(0.04),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 70,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Header

private extension InsightsView {

    var heroHeaderSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Insights")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(textPrimary)

                Text(selectedDateTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textSecondary)
            }

            Spacer()

            avatarButton
                .scaleEffect(0.92)
        }
    }

    var avatarButton: some View {
        Button {
            showProfile = true
        } label: {
            WeekFitHeroHeader(
                selectedDateTitle: "",
                showContent: true,
                textPrimary: textPrimary,
                softShadow: cardShadow,
                onPreviousDay: {},
                onToday: {},
                onNextDay: {},
                onProfileTap: {}
            )
            .avatarButton
        }
        .buttonStyle(.plain)
    }

    var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: selectedDate)
    }
}

// MARK: - Hero

private extension InsightsView {

    var heroInsightCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    WeekFitTheme.meal.opacity(0.065),
                    WeekFitTheme.blue.opacity(0.03),
                    elevatedCard.opacity(0.90),
                    cardBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(WeekFitTheme.meal.opacity(0.08))
                .frame(width: 74, height: 74)
                .blur(radius: 20)
                .offset(x: 240, y: 8)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .semibold))

                    Text("AI INSIGHT")
                        .font(.system(size: 8.5, weight: .bold))
                }
                .foregroundStyle(WeekFitTheme.meal.opacity(0.82))

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your recovery is strongest on balanced sleep + hydration days")
                            .font(.system(size: 14.8, weight: .bold))
                            .foregroundStyle(textPrimary)
                            .lineLimit(3)
                            .minimumScaleFactor(0.76)

                        Text("You recover 23% better when hydration stays above 2.3L")
                            .font(.system(size: 10.4, weight: .semibold))
                            .foregroundStyle(textSecondary.opacity(0.76))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 2)

                    ZStack {
                        Circle()
                            .fill(WeekFitTheme.meal.opacity(0.10))
                            .frame(width: 42, height: 42)

                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            .frame(width: 42, height: 42)

                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(WeekFitTheme.meal.opacity(0.82))
                    }
                }

                Spacer(minLength: 0)

                heroGraph
            }
            .padding(13)
        }
        .frame(height: 188)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.6), radius: 14, y: 7)
    }

    var heroGraph: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack {
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height

                        path.move(to: CGPoint(x: 0, y: h * 0.72))
                        path.addCurve(to: CGPoint(x: w * 0.17, y: h * 0.42), control1: CGPoint(x: w * 0.06, y: h * 0.62), control2: CGPoint(x: w * 0.10, y: h * 0.34))
                        path.addCurve(to: CGPoint(x: w * 0.35, y: h * 0.62), control1: CGPoint(x: w * 0.24, y: h * 0.48), control2: CGPoint(x: w * 0.28, y: h * 0.68))
                        path.addCurve(to: CGPoint(x: w * 0.53, y: h * 0.35), control1: CGPoint(x: w * 0.43, y: h * 0.55), control2: CGPoint(x: w * 0.46, y: h * 0.32))
                        path.addCurve(to: CGPoint(x: w * 0.70, y: h * 0.30), control1: CGPoint(x: w * 0.60, y: h * 0.36), control2: CGPoint(x: w * 0.63, y: h * 0.27))
                        path.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.14), control1: CGPoint(x: w * 0.78, y: h * 0.26), control2: CGPoint(x: w * 0.84, y: h * 0.12))
                    }
                    .stroke(
                        WeekFitTheme.meal.opacity(0.68),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                    )

                    heroDot(x: 0.17, y: 0.42, geo: geo)
                    heroDot(x: 0.35, y: 0.62, geo: geo)
                    heroDot(x: 0.53, y: 0.35, geo: geo)
                    heroDot(x: 0.70, y: 0.30, geo: geo)

                    VStack(spacing: 0.5) {
                        Text("+23%")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(textPrimary.opacity(0.94))

                        Text("better recovery")
                            .font(.system(size: 7.5, weight: .semibold))
                            .foregroundStyle(textSecondary.opacity(0.74))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .position(x: geo.size.width * 0.86, y: geo.size.height * 0.55)
                }
            }
            .frame(height: 48)

            HStack(spacing: 0) {
                ForEach(weekDays.indices, id: \.self) { index in
                    Text(weekDays[index])
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(textSecondary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    func heroDot(x: CGFloat, y: CGFloat, geo: GeometryProxy) -> some View {
        Circle()
            .fill(textPrimary.opacity(0.86))
            .frame(width: 6, height: 6)
            .overlay {
                Circle()
                    .stroke(WeekFitTheme.meal.opacity(0.68), lineWidth: 1.2)
            }
            .position(x: geo.size.width * x, y: geo.size.height * y)
    }
}

// MARK: - Weekly Scores

private extension InsightsView {

    var weeklyScoresSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This week")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(textPrimary.opacity(0.96))

            HStack(spacing: 6) {
                insightMiniCard(icon: "heart.fill", iconColor: WeekFitTheme.meal, title: "Recovery", value: "82", trend: "↑", trendColor: WeekFitTheme.meal, progress: 0.78)

                insightMiniCard(icon: "moon.fill", iconColor: WeekFitTheme.purple, title: "Sleep", value: "74", trend: "→", trendColor: textTertiary, progress: 0.62)

                insightMiniCard(icon: "bolt.fill", iconColor: WeekFitTheme.orange, title: "Energy", value: "88", trend: "↑", trendColor: WeekFitTheme.meal, progress: 0.82)

                insightMiniCard(icon: "scope", iconColor: WeekFitTheme.blue, title: "Consistency", value: "69", trend: "↓", trendColor: .red.opacity(0.65), progress: 0.55)
            }
        }
    }

    func insightMiniCard(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        trend: String,
        trendColor: Color,
        progress: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.11))
                    .frame(width: 22, height: 22)

                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(iconColor.opacity(0.8))
            }

            Spacer(minLength: 1)

            Text(title)
                .font(.system(size: 8.8, weight: .semibold))
                .foregroundStyle(textSecondary.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(textPrimary.opacity(0.92))

                Text(trend)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(trendColor.opacity(0.7))
                    .offset(y: -1.5)
            }

            GeometryReader { geo in
                Capsule()
                    .fill(iconColor.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(iconColor.opacity(0.48))
                            .frame(width: geo.size.width * progress)
                    }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardSecondary.opacity(0.72),
                            cardBackground.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.035), lineWidth: 1)
        }
    }
}

// MARK: - Trends

private extension InsightsView {

    var trendsSection: some View {
        HStack(spacing: 8) {
            trendCard(
                accent: WeekFitTheme.purple,
                label: "SLEEP CONSISTENCY",
                title: "Sleep rhythm improved",
                subtitle: "Bedtime is more stable",
                icon: "bed.double.fill",
                graphType: .line
            )

            trendCard(
                accent: WeekFitTheme.meal,
                label: "RECOVERY PATTERN",
                title: "Lighter evenings help",
                subtitle: "Late workouts reduce readiness",
                icon: "chart.line.uptrend.xyaxis",
                graphType: .bars
            )
        }
    }

    enum TrendGraphType {
        case line
        case bars
    }

    func trendCard(
        accent: Color,
        label: String,
        title: String,
        subtitle: String,
        icon: String,
        graphType: TrendGraphType
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 7.8, weight: .bold))
                        .foregroundStyle(accent.opacity(0.76))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(title)
                        .font(.system(size: 11.2, weight: .bold))
                        .foregroundStyle(textPrimary.opacity(0.95))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(subtitle)
                        .font(.system(size: 8.6, weight: .semibold))
                        .foregroundStyle(textSecondary.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 2)

                ZStack {
                    Circle()
                        .fill(accent.opacity(0.10))
                        .frame(width: 28, height: 28)

                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(accent.opacity(0.80))
                }
            }

            Spacer(minLength: 7)

            if graphType == .line {
                miniLineGraph(accent: accent)
            } else {
                miniBarGraph(accent: accent)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.05),
                            cardBackground.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.48), radius: 8, y: 4)
    }

    func miniLineGraph(accent: Color) -> some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack {
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height

                        path.move(to: CGPoint(x: 0, y: h * 0.82))
                        path.addLine(to: CGPoint(x: w * 0.17, y: h * 0.58))
                        path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.72))
                        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.38))
                        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.48))
                        path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.28))
                        path.addLine(to: CGPoint(x: w, y: h * 0.40))
                    }
                    .stroke(
                        accent.opacity(0.64),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                    )

                    Path { path in
                        let h = geo.size.height
                        path.move(to: CGPoint(x: 0, y: h * 0.64))
                        path.addLine(to: CGPoint(x: geo.size.width, y: h * 0.64))
                    }
                    .stroke(accent.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .frame(height: 27)

            HStack(spacing: 0) {
                ForEach(weekDays.indices, id: \.self) { index in
                    Text(weekDays[index])
                        .font(.system(size: 6.8, weight: .medium))
                        .foregroundStyle(textSecondary.opacity(0.72))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(accent.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.028), lineWidth: 1)
        }
    }

    func miniBarGraph(accent: Color) -> some View {
        let greenBars: [Double] = [0.30, 0.42, 0.48, 0.62, 0.74, 0.50, 0.88, 0.55, 0.92, 0.46]
        let redBars: [Double] = [0.38, 0.26, 0.44]

        return VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(greenBars.indices, id: \.self) { index in
                    Capsule()
                        .fill(accent.opacity(0.25))
                        .frame(width: 4, height: CGFloat(30 * greenBars[index]))
                }

                Spacer(minLength: 3)

                ForEach(redBars.indices, id: \.self) { index in
                    Capsule()
                        .fill(Color.red.opacity(0.20))
                        .frame(width: 4, height: CGFloat(30 * redBars[index]))
                }
            }
            .frame(height: 31)

            HStack {
                Text("6 AM")
                Spacer()
                Text("12 PM")
                Spacer()
                Text("6 PM")
                Spacer()
                Text("12 AM")
            }
            .font(.system(size: 6.6, weight: .medium))
            .foregroundStyle(textSecondary.opacity(0.72))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(accent.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.028), lineWidth: 1)
        }
    }
}

// MARK: - Correlation

private extension InsightsView {

    var hydrationCorrelationCard: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HYDRATION IMPACT")
                    .font(.system(size: 8.2, weight: .bold))
                    .foregroundStyle(WeekFitTheme.blue.opacity(0.76))

                Text("Higher hydration correlates with stronger recovery scores")
                    .font(.system(size: 11.2, weight: .bold))
                    .foregroundStyle(textPrimary.opacity(0.95))
                    .lineLimit(3)
                    .minimumScaleFactor(0.76)

                Text("Based on your data from the last 4 weeks")
                    .font(.system(size: 8.6, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.72))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                compactCorrelationRow(
                    icon: "drop.fill",
                    title: "Hydration (L/day)",
                    values: ["2.1", "2.3", "2.6"],
                    color: WeekFitTheme.blue,
                    progress: 0.52
                )

                compactCorrelationRow(
                    icon: "heart.fill",
                    title: "Recovery Score",
                    values: ["64", "75", "88"],
                    color: WeekFitTheme.meal,
                    progress: 0.55
                )
            }
            .frame(width: 138, alignment: .top)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardSecondary.opacity(0.78),
                            cardBackground.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.48), radius: 8, y: 4)
    }

    func compactCorrelationRow(
        icon: String,
        title: String,
        values: [String],
        color: Color,
        progress: CGFloat
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.10))
                    .frame(width: 19, height: 19)

                Image(systemName: icon)
                    .font(.system(size: 8.4, weight: .semibold))
                    .foregroundStyle(color.opacity(0.80))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(textPrimary.opacity(0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                HStack(spacing: 0) {
                    ForEach(values.indices, id: \.self) { index in
                        Text(values[index])
                            .font(.system(size: 8.2, weight: .bold))
                            .foregroundStyle(textSecondary.opacity(0.72))
                            .frame(maxWidth: .infinity)
                    }
                }

                GeometryReader { geo in
                    Capsule()
                        .fill(color.opacity(0.10))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(color.opacity(0.32))
                                .frame(width: geo.size.width * 0.96)
                        }
                        .overlay {
                            Capsule()
                                .fill(color.opacity(0.72))
                                .frame(width: 3, height: 9)
                                .offset(x: geo.size.width * (progress - 0.5))
                        }
                }
                .frame(height: 5.5)
            }
        }
    }
}

// MARK: - Reflection

private extension InsightsView {

    var weeklyReflectionCard: some View {
        HStack(alignment: .center, spacing: 9) {
            VStack(alignment: .leading, spacing: 5) {
                Text("✨ WEEKLY REFLECTION")
                    .font(.system(size: 8.2, weight: .bold))
                    .foregroundStyle(WeekFitTheme.orange.opacity(0.76))

                Text("Training load was handled well this week. Hydration and sleep timing remain your biggest recovery levers.")
                    .font(.system(size: 9.6, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.74))
                    .lineSpacing(1)
                    .lineLimit(4)
            }

            Spacer(minLength: 3)

            mountainVisual
                .frame(width: 94, height: 58)
        }
        .padding(10)
        .frame(minHeight: 88)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.orange.opacity(0.05),
                            cardBackground.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.48), radius: 8, y: 4)
    }

    var mountainVisual: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WeekFitTheme.orange.opacity(0.09),
                    WeekFitTheme.meal.opacity(0.065)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(WeekFitTheme.orange.opacity(0.14))
                .frame(width: 28, height: 28)
                .offset(x: 10, y: -6)

            Path { path in
                path.move(to: CGPoint(x: 0, y: 43))
                path.addCurve(to: CGPoint(x: 32, y: 23), control1: CGPoint(x: 11, y: 34), control2: CGPoint(x: 21, y: 24))
                path.addCurve(to: CGPoint(x: 63, y: 42), control1: CGPoint(x: 44, y: 22), control2: CGPoint(x: 52, y: 39))
                path.addCurve(to: CGPoint(x: 94, y: 20), control1: CGPoint(x: 75, y: 45), control2: CGPoint(x: 85, y: 28))
                path.addLine(to: CGPoint(x: 94, y: 58))
                path.addLine(to: CGPoint(x: 0, y: 58))
                path.closeSubpath()
            }
            .fill(WeekFitTheme.meal.opacity(0.16))

            Path { path in
                path.move(to: CGPoint(x: 0, y: 47))
                path.addCurve(to: CGPoint(x: 35, y: 38), control1: CGPoint(x: 12, y: 46), control2: CGPoint(x: 24, y: 36))
                path.addCurve(to: CGPoint(x: 68, y: 47), control1: CGPoint(x: 47, y: 39), control2: CGPoint(x: 54, y: 51))
                path.addCurve(to: CGPoint(x: 94, y: 35), control1: CGPoint(x: 79, y: 45), control2: CGPoint(x: 86, y: 39))
                path.addLine(to: CGPoint(x: 94, y: 58))
                path.addLine(to: CGPoint(x: 0, y: 58))
                path.closeSubpath()
            }
            .fill(Color.black.opacity(0.15))
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.035), lineWidth: 1)
        }
    }
}
