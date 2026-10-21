import SwiftUI
import WeekFitPlanner

/// Shared geometry and copy for the Plan agenda redesign.
enum PlanAgendaLayout {
    static let horizontalPadding: CGFloat = WeekFitScreenLayout.horizontalPadding
    /// Calendar → day summary.
    static let calendarToSummary: CGFloat = 18
    /// Day summary → compact all-done line.
    static let summaryToAllDone: CGFloat = 14
    /// All-done / summary → schedule sections.
    static let summaryToSchedule: CGFloat = 22
    /// Legacy alias used by a few call sites.
    static let sectionSpacing: CGFloat = summaryToSchedule
    static let innerSpacing: CGFloat = 8
    static let cardSpacing: CGFloat = 11
    static let cardPadding: CGFloat = 15
    static let cardCornerRadius: CGFloat = 22
    static let sectionCornerRadius: CGFloat = 20
    static let sectionPadding: CGFloat = 16
    static let calendarSectionPadding: CGFloat = 10
    static let iconSize: CGFloat = 42
    static let summaryIconSize: CGFloat = 38
    static let scheduleHeaderToEvents: CGFloat = 12
    /// Visual capsule height; hit target stays `minHitSize`.
    static let dayCapsuleMinHeight: CGFloat = 48
    static let minHitSize: CGFloat = 44
    static let monthTitleSize: CGFloat = 16
}

struct PlanAgendaDayCharacter {
    let titleKey: String
    let detailKey: String
    let systemImage: String

    static func character(for kind: PlanDayKind) -> PlanAgendaDayCharacter {
        switch kind {
        case .recovery:
            return PlanAgendaDayCharacter(
                titleKey: "planner.agenda.character.recovery",
                detailKey: "planner.agenda.character.detail.recovery",
                systemImage: "leaf.fill"
            )
        case .endurance:
            return PlanAgendaDayCharacter(
                titleKey: "planner.agenda.character.endurance",
                detailKey: "planner.agenda.character.detail.endurance",
                systemImage: "figure.run"
            )
        case .load:
            return PlanAgendaDayCharacter(
                titleKey: "planner.agenda.character.strength",
                detailKey: "planner.agenda.character.detail.strength",
                systemImage: "dumbbell.fill"
            )
        case .mixed:
            return PlanAgendaDayCharacter(
                titleKey: "planner.agenda.character.mixed",
                detailKey: "planner.agenda.character.detail.mixed",
                systemImage: "circle.grid.cross.fill"
            )
        case .open:
            return PlanAgendaDayCharacter(
                titleKey: "planner.agenda.character.open",
                detailKey: "planner.agenda.character.detail.open",
                systemImage: "calendar"
            )
        }
    }

    var title: String { WeekFitLocalizedString(titleKey) }
    var detail: String { WeekFitLocalizedString(detailKey) }
}

enum PlanAgendaDateCopy {
    static func selectedDayHeadline(for date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return WeekFitLocalizedString("planner.sheet.todayLabel")
        }
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date).capitalized(with: WeekFitCurrentLocale())
    }

    static func selectedDayDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    static func dayContextLine(for date: Date, calendar: Calendar = .current) -> String {
        String(
            format: WeekFitLocalizedString("planner.agenda.dayContextFormat"),
            selectedDayHeadline(for: date, calendar: calendar),
            selectedDayDate(for: date)
        )
    }

    static func monthYear(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date).capitalized(with: WeekFitCurrentLocale())
    }
}

/// How incomplete / complete events are titled for the selected day.
enum PlanAgendaPrimarySectionKind: Equatable {
    case upNext
    case planned
    case notCompleted

    var title: String {
        switch self {
        case .upNext:
            return WeekFitLocalizedString("planner.agenda.upNext")
        case .planned:
            return WeekFitLocalizedString("planner.agenda.planned")
        case .notCompleted:
            return WeekFitLocalizedString("planner.agenda.notCompleted")
        }
    }
}

struct PlanAgendaDaySections {
    let primaryKind: PlanAgendaPrimarySectionKind
    let primaryItems: [PlanTimelineItem]
    let earlierItems: [PlanTimelineItem]
    let completedItems: [PlanTimelineItem]

    var hasIncomplete: Bool {
        !primaryItems.isEmpty || !earlierItems.isEmpty
    }

    var isFullyComplete: Bool {
        !completedItems.isEmpty && primaryItems.isEmpty && earlierItems.isEmpty
    }

    static func make(
        from items: [PlanTimelineItem],
        selectedDate: Date,
        statusFor: (PlannedActivity) -> PlanActivityStatus,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> PlanAgendaDaySections {
        let dayStart = calendar.startOfDay(for: selectedDate)
        let todayStart = calendar.startOfDay(for: now)

        var primary: [PlanTimelineItem] = []
        var earlier: [PlanTimelineItem] = []
        var completed: [PlanTimelineItem] = []

        for item in items {
            let activity = item.representative
            if activity.isSkipped { continue }

            let status = statusFor(activity)
            switch status {
            case .completed, .logged:
                completed.append(item)
            case .pending:
                if calendar.isDate(dayStart, inSameDayAs: todayStart) {
                    earlier.append(item)
                } else {
                    primary.append(item)
                }
            case .upcoming, .live:
                primary.append(item)
            case .skipped:
                continue
            }
        }

        let primaryKind: PlanAgendaPrimarySectionKind
        if dayStart == todayStart {
            primaryKind = .upNext
        } else if dayStart > todayStart {
            primaryKind = .planned
        } else {
            primaryKind = .notCompleted
        }

        return PlanAgendaDaySections(
            primaryKind: primaryKind,
            primaryItems: primary,
            earlierItems: earlier,
            completedItems: completed
        )
    }
}

enum PlanAgendaCompletionControl: Equatable {
    case none
    case interactive(isCompleted: Bool)
    case informational(isCompleted: Bool)

    static func control(
        for item: PlanTimelineItem,
        status: PlanActivityStatus
    ) -> PlanAgendaCompletionControl {
        switch item {
        case .waterGroup:
            if status == .completed || status == .logged {
                return .informational(isCompleted: true)
            }
            return .none

        case .single(let activity):
            let isDone = status == .completed || status == .logged
            if allowsManualToggle(activity) {
                return .interactive(isCompleted: isDone)
            }
            if isDone {
                return .informational(isCompleted: true)
            }
            return .none
        }
    }

    /// User-planned rows can toggle; HealthKit / Watch imports stay informational.
    private static func allowsManualToggle(_ activity: PlannedActivity) -> Bool {
        if activity.isSkipped { return false }
        let source = activity.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if source == "appleworkout" || source == "applewatch" || source == "healthkit" {
            return false
        }
        // Imported session stubs keep a workout UUID and are not manually unchecked here.
        if let uuid = activity.healthKitWorkoutUUID,
           !uuid.isEmpty,
           source != "planner",
           source != "today" {
            return false
        }
        return true
    }
}

struct PlanAgendaSectionSurface: ViewModifier {
    @Environment(\.weekFitPalette) private var palette
    var compact: Bool = false
    var emphasizesGold: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(compact ? PlanAgendaLayout.calendarSectionPadding : PlanAgendaLayout.sectionPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: PlanAgendaLayout.sectionCornerRadius, style: .continuous)
                    .fill(sectionFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: PlanAgendaLayout.sectionCornerRadius, style: .continuous)
                    .strokeBorder(sectionStroke, lineWidth: 0.6)
            }
            .shadow(
                color: palette.isLight ? Color.black.opacity(0.03) : Color.black.opacity(0.16),
                radius: palette.isLight ? 2 : 3,
                y: 1
            )
    }

    private var sectionFill: some ShapeStyle {
        if emphasizesGold {
            if palette.isLight {
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.99),
                            WeekFitLightTokens.brandGoldSoft.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        WeekFitTheme.cardBackground,
                        WeekFitTheme.brandGold.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        if palette.isLight {
            return AnyShapeStyle(Color.white.opacity(0.97))
        }
        return AnyShapeStyle(WeekFitTheme.cardBackground)
    }

    private var sectionStroke: Color {
        if emphasizesGold {
            return WeekFitTheme.brandGold.opacity(palette.isLight ? 0.12 : 0.14)
        }
        return palette.isLight
            ? Color.black.opacity(0.05)
            : WeekFitTheme.whiteOpacity(0.07)
    }
}

extension View {
    func planAgendaSectionSurface(
        compact: Bool = false,
        emphasizesGold: Bool = false
    ) -> some View {
        modifier(PlanAgendaSectionSurface(
            compact: compact,
            emphasizesGold: emphasizesGold
        ))
    }
}

/// Compact day context + character + optional recommendation (no nested card).
struct PlanAgendaDaySummaryCard: View {
    let date: Date
    let kind: PlanDayKind
    /// When false, recommendation line is omitted (e.g. open day with no useful tip).
    var showsRecommendation: Bool = true

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var character: PlanAgendaDayCharacter {
        PlanAgendaDayCharacter.character(for: kind)
    }

    private var recommendation: String? {
        guard showsRecommendation else { return nil }
        // Open-day detail is an add prompt, not a day recommendation — omit when empty plan tip.
        if kind == .open { return nil }
        let text = character.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PlanAgendaLayout.innerSpacing) {
            Text(PlanAgendaDateCopy.dayContextLine(for: date))
                .font(WeekFitType.secondary.weight(.medium))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if dynamicTypeSize >= .accessibility2 {
                VStack(alignment: .leading, spacing: 6) {
                    characterTitleRow
                    if let recommendation {
                        Text(recommendation)
                            .font(WeekFitType.secondary)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(WeekFitTheme.brandGold.opacity(palette.isLight ? 0.14 : 0.18))
                            .frame(
                                width: PlanAgendaLayout.summaryIconSize,
                                height: PlanAgendaLayout.summaryIconSize
                            )

                        Image(systemName: character.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(WeekFitTheme.brandGold.opacity(palette.isLight ? 0.95 : 0.90))
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(character.title)
                            .font(WeekFitType.body.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let recommendation {
                            Text(recommendation)
                                .font(WeekFitType.secondary)
                                .foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .planAgendaSectionSurface(emphasizesGold: true)
        .accessibilityElement(children: .combine)
    }

    private var characterTitleRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: character.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WeekFitTheme.brandGold.opacity(palette.isLight ? 0.94 : 0.90))
            Text(character.title)
                .font(WeekFitType.body.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Compact completion cue under the day summary — no card chrome.
struct PlanAgendaAllDoneLine: View {
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WeekFitTheme.brandGold)
                .accessibilityHidden(true)

            Text(WeekFitLocalizedString("planner.agenda.allDoneMessage"))
                .font(WeekFitType.secondary.weight(.medium))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct PlanAgendaSectionHeader: View {
    let title: String
    var trailing: AnyView? = nil

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(WeekFitType.cardTitle)
                .fontDesign(.rounded)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.88)

            Spacer(minLength: 8)

            if let trailing {
                trailing
            }
        }
        .accessibilityElement(children: .contain)
    }
}
