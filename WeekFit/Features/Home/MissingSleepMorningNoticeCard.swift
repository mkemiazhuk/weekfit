import SwiftUI

struct MissingSleepMorningNoticeHost: View {
    let surface: MissingSleepNoticeSurface
    let now: Date
    let isHealthAccessGranted: Bool
    let hasSettledMetrics: Bool
    let isLoadingMetrics: Bool
    let sleepReadConfirmed: Bool
    let hasSleepRecords: Bool
    let isScreenActive: Bool
    let onCheckConnection: () -> Void

    @ObservedObject private var session = MissingSleepMorningNoticeSession.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if showsCard {
                MissingSleepMorningNoticeCard(
                    onGotIt: { session.end(surface) },
                    onCheckConnection: {
                        session.end(surface)
                        onCheckConnection()
                    }
                )
                .onAppear {
                    session.noteAppeared(surface: surface, owner: ownerID, dayKey: dayKey)
                }
            }
        }
        .onChange(of: showsCard) { _, visible in
            if !visible { session.end(surface) }
        }
        .onChange(of: isScreenActive) { _, active in
            if !active { session.end(surface) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { session.end(surface) }
        }
    }

    private var showsCard: Bool {
        guard isScreenActive else { return false }
        let input = MissingSleepMorningNoticeInput(
            now: now,
            isHealthAccessGranted: isHealthAccessGranted,
            hasSettledMetrics: hasSettledMetrics,
            isLoadingMetrics: isLoadingMetrics,
            sleepReadConfirmed: sleepReadConfirmed,
            hasSleepRecords: hasSleepRecords,
            hasShownToday: session.hasShown(owner: ownerID, dayKey: dayKey),
            isHeldOnScreen: session.isHeld(by: surface)
        )
        return MissingSleepMorningNoticePolicy.phase(input) == .show
    }

    private var ownerID: String {
        WorkspaceOwnerStore.currentIdentityToken() ?? WorkspaceOwnerStore.localOwnerID
    }

    private var dayKey: String {
        MissingSleepMorningNoticePolicy.dayKey(for: now)
    }
}

struct MissingSleepMorningNoticeCard: View {
    let onGotIt: () -> Void
    let onCheckConnection: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(palette.textSecondary.opacity(palette.isLight ? 0.10 : 0.16))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(WeekFitLocalizedString("today.missingSleepNotice.title"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(WeekFitLocalizedString("today.missingSleepNotice.body"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button(action: onGotIt) {
                        Text(WeekFitLocalizedString("today.missingSleepNotice.gotIt"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.isLight ? Color.white : Color.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(WeekFitTheme.coachAccent))
                    }
                    .buttonStyle(.plain)

                    Button(action: onCheckConnection) {
                        Text(WeekFitLocalizedString("today.missingSleepNotice.checkConnection"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WeekFitTheme.coachAccent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .standard, accent: nil, cornerRadius: 16)
        .accessibilityElement(children: .contain)
    }
}
