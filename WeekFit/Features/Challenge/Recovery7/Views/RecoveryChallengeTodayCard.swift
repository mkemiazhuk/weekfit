import SwiftUI

/// Compact Today promo / progress card for the 7-Day Recovery Challenge.
struct RecoveryChallengeTodayCard: View {
    let kind: RecoveryChallengeTodayCardKind
    let onOpen: () -> Void
    let onDismissFinished: (() -> Void)?

    @Environment(\.weekFitPalette) private var palette

    private var accent: Color { WeekFitTheme.recovery }

    var body: some View {
        switch kind {
        case .hidden:
            EmptyView()
        case .intro:
            cardChrome {
                VStack(alignment: .leading, spacing: 12) {
                    header(
                        eyebrow: WeekFitLocalizedString("challenge.recovery7.card.eyebrow"),
                        title: WeekFitLocalizedString("challenge.recovery7.title")
                    )
                    Text(WeekFitLocalizedString("challenge.recovery7.card.introBody"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    cta(WeekFitLocalizedString("challenge.recovery7.card.viewCTA"))
                }
            }
            .onAppear { RecoveryChallengeAnalytics.cardViewed(kind: "intro") }
        case .participating(let dayIndex, let todayCompleted, let completedCount):
            cardChrome {
                VStack(alignment: .leading, spacing: 12) {
                    header(
                        eyebrow: WeekFitLocalizedString("challenge.recovery7.card.eyebrow"),
                        title: String(
                            format: WeekFitLocalizedString("challenge.recovery7.dayOf"),
                            dayIndex,
                            RecoveryChallengeConfig.dayCount
                        )
                    )
                    Text(taskSummary(dayIndex: dayIndex, todayCompleted: todayCompleted))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    progressLine(completedCount: completedCount)

                    cta(
                        todayCompleted
                            ? WeekFitLocalizedString("challenge.recovery7.card.openCTA")
                            : WeekFitLocalizedString("challenge.recovery7.card.continueCTA")
                    )
                }
            }
            .onAppear { RecoveryChallengeAnalytics.cardViewed(kind: todayCompleted ? "day_done" : "active") }
        case .finished(let completedCount):
            cardChrome {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            header(
                                eyebrow: WeekFitLocalizedString("challenge.recovery7.card.eyebrow"),
                                title: WeekFitLocalizedString("challenge.recovery7.card.finishedTitle")
                            )
                            Text(
                                String(
                                    format: WeekFitLocalizedString("challenge.recovery7.summary.count"),
                                    completedCount,
                                    RecoveryChallengeConfig.dayCount
                                )
                            )
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(WeekFitTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let onDismissFinished {
                            WeekFitCloseButton(size: .compact, usesBorderlessStyle: true) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onDismissFinished()
                            }
                        }
                    }

                    cta(WeekFitLocalizedString("challenge.recovery7.card.summaryCTA"))
                }
            }
            .onAppear { RecoveryChallengeAnalytics.cardViewed(kind: "finished") }
        }
    }

    private func taskSummary(dayIndex: Int, todayCompleted: Bool) -> String {
        if todayCompleted {
            return WeekFitLocalizedString("challenge.recovery7.card.completedTodayBody")
        }
        let key = RecoveryChallengeTaskID(rawValue: dayIndex)?.localizationTaskKey
            ?? "challenge.recovery7.task.1.title"
        return WeekFitLocalizedString(key)
    }

    private func header(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(.caption2.weight(.bold))
                .fontDesign(.rounded)
                .tracking(1.2)
                .foregroundStyle(accent.opacity(0.84))
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func progressLine(completedCount: Int) -> some View {
        Text(
            String(
                format: WeekFitLocalizedString("challenge.recovery7.progress.count"),
                completedCount,
                RecoveryChallengeConfig.dayCount
            )
        )
        .font(.caption.weight(.semibold))
        .fontDesign(.rounded)
        .foregroundStyle(accent.opacity(0.9))
    }

    private func cta(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(accent.opacity(0.95))
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent.opacity(0.72))
        }
    }

    private func cardChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onOpen()
        }) {
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .weekFitPremiumCard(emphasis: .elevated, accent: accent, cornerRadius: WeekFitSurface.primaryRadius)
        .accessibilityElement(children: .combine)
    }
}
