import SwiftUI

struct CoachEveningSummarySection: View {
    @ObservedObject var coordinator: CoachEveningSummaryCoordinator
    let onRequestSummary: () -> Void
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy("Your day", "Итог дня", "今日总结"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textSecondary)

            if let summary = coordinator.summary {
                summaryContent(summary)
            } else if coordinator.isRefreshing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(loadingCopy)
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if coordinator.serverAttemptPending, coordinator.summary == nil, !coordinator.isRefreshing {
                Text(pendingCopy)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if coordinator.lastRefreshFailed, !coordinator.isRefreshing {
                Text(errorCopy)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .weekFitPrimaryCard(accent: WeekFitTheme.coachAccent)
        .accessibilityIdentifier("coach.eveningSummary")
    }

    @ViewBuilder
    private func summaryContent(_ summary: CoachEveningSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            passage(
                copy("Today", "Сегодня", "今天"),
                summary.today.text,
                emphasized: false
            )
            passage(
                copy("Now", "Сейчас", "现在"),
                summary.now.text,
                emphasized: true
            )
            passage(
                copy("Tomorrow", "Завтра", "明天"),
                summary.tomorrow.text,
                emphasized: false
            )
            if !summary.limitations.isEmpty {
                Text(summary.limitations.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 10) {
            if let receivedAt = coordinator.receivedAt {
                Text(formattedReceivedAt(receivedAt))
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
                    .accessibilityLabel(copy(
                        "Updated \(formattedReceivedAt(receivedAt))",
                        "Обновлено \(formattedReceivedAt(receivedAt))",
                        "更新于 \(formattedReceivedAt(receivedAt))"
                    ))
            } else if coordinator.summary == nil, !coordinator.isRefreshing {
                Text(copy("No summary yet", "Итога пока нет", "暂无总结"))
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            if coordinator.isRefreshing, coordinator.summary != nil {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(loadingCopy)
            }

            Button(action: onRequestSummary) {
                Text(buttonTitle)
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(WeekFitTheme.coachAccent)
            .controlSize(.small)
            .disabled(coordinator.isRefreshing || coordinator.summary != nil || coordinator.lastRefreshFailed || coordinator.serverAttemptPending)
        }
        .padding(.top, 2)
    }

    private var buttonTitle: String {
        if coordinator.summary == nil {
            return copy("Get summary", "Получить итог", "获取总结")
        }
        return copy("Refresh", "Обновить", "更新")
    }

    private var loadingCopy: String {
        copy("Putting together your day…", "Собираю итог дня…", "正在整理今天的总结…")
    }

    private var pendingCopy: String {
        copy(
            "Today's summary is still being saved. This check does not start a new one.",
            "Сегодняшний итог ещё сохраняется. Эта проверка не запускает новый запрос.",
            "今天的总结还在保存。这次查看不会重新生成。"
        )
    }

    private var errorCopy: String {
        if coordinator.summary == nil {
            return copy(
                "Today's summary wasn't ready. The next request is tomorrow evening.",
                "Сегодняшний итог не готов. Следующий запрос — завтра вечером.",
                "今天的总结没有生成。下次请求要到明天晚上。"
            )
        }
        return copy(
            "Today's summary stays as it is.",
            "Сегодняшний итог остаётся без повторного запроса.",
            "今天的总结保持不变。"
        )
    }

    private func passage(_ title: String, _ text: String, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(emphasized ? .caption.weight(.bold) : .caption.weight(.semibold))
                .foregroundStyle(emphasized ? WeekFitTheme.coachAccent : palette.textSecondary)
            Text(text)
                .font(emphasized ? .body.weight(.semibold) : .body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func formattedReceivedAt(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func copy(_ en: String, _ ru: String, _ zh: String) -> String {
        CoachState.localized(english: en, russian: ru, chinese: zh)
    }
}

#if DEBUG
private struct CoachEveningSummarySectionPreviewHost: View {
    @StateObject private var coordinator: CoachEveningSummaryCoordinator = {
        let store = CoachEveningSummaryStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let summary = CoachEveningSummary(
            headline: "unused",
            today: .init(
                text: "Короткий сон и силовая задали тон дню — сейчас важнее восстановиться, чем догонять объём.",
                evidenceIds: []
            ),
            now: .init(
                text: "Лягте на 30–40 минут раньше — это даст больше шансов на сон перед завтрашней тренировкой.",
                evidenceIds: []
            ),
            tomorrow: .init(
                text: "К силовой в 18:00 подготовьте лёгкий перекус за 60–90 минут.",
                evidenceIds: []
            ),
            limitations: [],
            day: "2026-10-12",
            locale: "ru",
            generatedAt: "2026-10-12T18:00:00Z",
            source: "ai"
        )
        try? store.saveCache(.init(summary: summary, receivedAt: Date()), owner: "preview")
        let coordinator = CoachEveningSummaryCoordinator(store: store) { _, _ in
            CoachEveningSummaryGenerationResult(summary: summary, requestId: "preview")
        }
        coordinator.restore(owner: "preview")
        return coordinator
    }()

    var body: some View {
        CoachEveningSummarySection(coordinator: coordinator, onRequestSummary: {})
            .padding()
    }
}

#Preview("Evening summary card") {
    CoachEveningSummarySectionPreviewHost()
}
#endif
