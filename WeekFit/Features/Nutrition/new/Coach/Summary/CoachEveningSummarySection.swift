import SwiftUI

struct CoachEveningSummarySection: View {
    @ObservedObject var coordinator: CoachEveningSummaryCoordinator
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        Group {
            switch coordinator.status {
            case .idle:
                EmptyView()
            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                    Text(copy("Putting together your day…", "Собираю итог дня…", "正在整理今天的总结…"))
                        .font(.body)
                        .foregroundStyle(palette.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .weekFitPrimaryCard(accent: WeekFitTheme.coachAccent)
            case .failed:
                Text(copy("Today's summary couldn't be prepared. We'll try again tomorrow.",
                          "Сегодня не удалось подготовить итог. Следующая попытка — завтра.",
                          "今天未能生成总结，明天再试。"))
                    .font(.body)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .weekFitPrimaryCard(accent: WeekFitTheme.coachAccent)
            case .ready(let summary):
                VStack(alignment: .leading, spacing: 16) {
                    Text(copy("Your day", "Итог дня", "今日总结"))
                        .font(.headline)
                        .foregroundStyle(palette.textSecondary)
                    Text(summary.headline)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                    passage(copy("Today", "Сегодня", "今天"), summary.today.text)
                    passage(copy("Now", "Сейчас", "现在"), summary.now.text)
                    passage(copy("Tomorrow", "Завтра", "明天"), summary.tomorrow.text)
                    if !summary.limitations.isEmpty {
                        Text(summary.limitations.joined(separator: " "))
                            .font(.footnote)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .weekFitPrimaryCard(accent: WeekFitTheme.coachAccent)
            }
        }
        .accessibilityIdentifier("coach.eveningSummary")
    }

    private func passage(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(palette.textSecondary)
            Text(text).font(.body).foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func copy(_ en: String, _ ru: String, _ zh: String) -> String {
        CoachState.localized(english: en, russian: ru, chinese: zh)
    }
}
