import SwiftUI

struct CoachEveningReviewSection: View {

    let summary: CoachEveningReviewSummary
    let plan: CoachEveningReviewPlan
    let readiness: CoachTomorrowReadiness

    private let cardBackground = WeekFitTheme.cardBackground
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText

    private let achievementAccent = CoachReviewPalette.achievement
    private let neutralStroke = Color.white.opacity(0.045)
    private let neutralFill = Color.white.opacity(0.026)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            scoreHero
            planSection
            tomorrowReadinessSection
        }
        .padding(15)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardBackground.opacity(0.42),
                            cardBackground.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.045), lineWidth: 1)
                }
        }
    }

    // MARK: - Score Hero

    private var scoreHero: some View {
        VStack(spacing: 10) {
            ZStack {
//                Circle()
//                    .fill(scoreColor.opacity(0.10))
//                    .frame(width: 68, height: 68)
//
//                Circle()
//                    .stroke(scoreColor.opacity(0.22), lineWidth: 1)
//                    .frame(width: 68, height: 68)

                Text(dayMood.emoji)
                    .font(.system(size: 26))
            }

            VStack(spacing: 5) {
                Text(dayMoodTitle)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.45)
                    .multilineTextAlignment(.center)

                Text(primarySummaryLine)
                    .font(.system(size: 12.6, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.68))
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !summary.achievement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    achievementInline
                        .padding(.top, 5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private var achievementInline: some View {
        HStack(spacing: 7) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(achievementAccent)

            Text(inlineAchievementText)
                .font(.system(size: 12.2, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule(style: .continuous)
                .fill(achievementAccent.opacity(0.075))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(achievementAccent.opacity(0.10), lineWidth: 1)
                }
        }
    }

    private var inlineAchievementText: String {
        let text = summary.achievement.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.lowercased().contains("cycling") {
            return text
                .replacingOccurrences(of: "Cycling —", with: "Longest session:")
                .replacingOccurrences(of: "completed.", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text
            .replacingOccurrences(of: "completed.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var dayMood: (emoji: String, label: String) {
        switch summary.score {
        case 90...100:
            return ("🤩", "EXCELLENT")
        case 75..<90:
            return ("😊", "STRONG")
        case 60..<75:
            return ("🙂", "SOLID")
        case 40..<60:
            return ("😐", "MIXED")
        default:
            return ("😴", "RESET")
        }
    }

    private var dayMoodTitle: String {
        summary.title
    }

    // MARK: - Plan

    private var planSection: some View {
        let isPerfect = plan.planned > 0 && plan.completed >= plan.planned && plan.skipped == 0
        let progressText = plan.planned > 0
            ? "\(plan.completed) of \(plan.planned) completed"
            : "No planned activities"

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "calendar",
                title: "Plan execution",
                subtitle: ""
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: isPerfect ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(
                            isPerfect
                                ? .green
                                : .white.opacity(0.42)
                        )

                    Text(isPerfect ? "Completed all planned activities" : progressText)
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }

                HStack(spacing: 7) {
                    compactPlanMetric(value: "\(plan.planned)", title: "planned")
                    separatorDot
                    compactPlanMetric(value: "\(plan.completed)", title: "done")

                    if plan.skipped > 0 {
                        separatorDot
                        compactPlanMetric(value: "\(plan.skipped)", title: "skipped")
                    }
                }
                .foregroundStyle(.white.opacity(0.58))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.15))
            }
        }
        .padding(12)
        .background(sectionBackground)
    }

    private func compactPlanMetric(value: String, title: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16.5, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)

            Text(title)
                .font(.system(size: 12.2, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.62))
        }
    }

    private var separatorDot: some View {
        Circle()
            .fill(textSecondary.opacity(0.34))
            .frame(width: 3.5, height: 3.5)
    }

    // MARK: - Readiness Summary

    private var tomorrowReadinessSection: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(readiness.color.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: readiness.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(readiness.color)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Tomorrow Readiness")
                    .font(.system(size: 11.8, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.56))

                Text(readinessDisplayTitle)
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.22)
                    .lineSpacing(1)
                    .lineLimit(2)

                Text(readiness.metrics)
                    .font(.system(size: 12.2, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.66))
                    .lineLimit(2)

                if !readiness.recommendation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended")
                            .font(.system(size: 10.4, weight: .bold, design: .rounded))
                            .foregroundStyle(textSecondary.opacity(0.46))

                        Text(readiness.recommendation)
                            .font(.system(size: 12.2, weight: .bold, design: .rounded))
                            .foregroundStyle(readiness.color.opacity(0.92))
                            .lineLimit(2)
                    }
                    .padding(.top, 3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            readiness.color.opacity(0.065),
                            Color.white.opacity(0.014)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(readiness.color.opacity(0.09), lineWidth: 1)
                }
        }
    }

    private var readinessDisplayTitle: String {
        let metrics = readiness.metrics.lowercased()

        if metrics.contains("recovery") {
            if metrics.contains("8") || metrics.contains("9") || metrics.contains("100") {
                return "Ready for tomorrow"
            }

            if metrics.contains("6") || metrics.contains("7") {
                return "Keep it moderate"
            }

            return "Recovery day recommended"
        }

        return readiness.title
    }

    // MARK: - Shared

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.065))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(textSecondary.opacity(0.72))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14.2, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(subtitle)
                    .font(.system(size: 10.8, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.50))
            }

            Spacer(minLength: 0)
        }
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(neutralFill)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(neutralStroke, lineWidth: 1)
            }
    }

    private var primarySummaryLine: String {
        let line = summary.message
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? summary.message

        let parts = line
            .components(separatedBy: "•")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if let duration = parts.first(where: {
            $0.lowercased().contains("active time")
        }) {
            return duration
        }

        return line
    }

    private var scoreColor: Color {
        switch summary.score {
        case 90...100:
            return CoachReviewPalette.excellent
        case 75..<90:
            return CoachReviewPalette.good
        case 60..<75:
            return CoachReviewPalette.warning
        default:
            return CoachReviewPalette.low
        }
    }
}

// MARK: - Models

struct CoachEveningReviewSummary {
    let title: String
    let message: String
    let achievement: String
    let score: Int
}

struct CoachEveningReviewPlan {
    let planned: Int
    let completed: Int
    let skipped: Int

    var subtitle: String {
        if planned == 0 {
            return "No activities were planned"
        }

        if completed >= planned && skipped == 0 {
            return "Everything planned was completed"
        }

        if completed > 0 {
            return "\(completed) of \(planned) completed"
        }

        return "Nothing completed from today’s plan"
    }
}

struct CoachTomorrowReadiness {
    let title: String
    let metrics: String
    let recommendation: String
    let icon: String
    let color: Color
}

private enum CoachReviewPalette {
    static let excellent = Color(red: 0.52, green: 0.90, blue: 0.70)
    static let good = Color(red: 0.40, green: 0.72, blue: 0.98)
    static let warning = Color(red: 1.00, green: 0.76, blue: 0.26)
    static let low = Color(red: 1.00, green: 0.47, blue: 0.47)

    static let achievement = Color(red: 0.72, green: 0.62, blue: 1.00)
    static let activity = Color(red: 0.40, green: 0.72, blue: 0.98)
    static let recovery = Color(red: 0.72, green: 0.62, blue: 1.00)
    static let calories = Color(red: 1.00, green: 0.62, blue: 0.35)
}
