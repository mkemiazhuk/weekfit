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
        let formatter = weekFitDateFormatter(template: "EEEE")
        return formatter.string(from: date).capitalized(with: WeekFitCurrentLocale())
    }

    static func selectedDayDate(for date: Date) -> String {
        weekFitDateFormatter(template: "d MMM").string(from: date)
    }

    static func dayContextLine(for date: Date, calendar: Calendar = .current) -> String {
        String(
            format: WeekFitLocalizedString("planner.agenda.dayContextFormat"),
            selectedDayHeadline(for: date, calendar: calendar),
            selectedDayDate(for: date)
        )
    }

    static func monthYear(for date: Date) -> String {
        weekFitDateFormatter(template: "MMMM yyyy")
            .string(from: date)
            .capitalized(with: WeekFitCurrentLocale())
    }

    /// Locale + calendar both pinned to the in-app language (avoids RU weekdays on EN UI).
    private static func weekFitDateFormatter(template: String) -> DateFormatter {
        let locale = WeekFitCurrentLocale()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
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
    /// In-progress rows, kept out of Up next / Planned.
    let liveItems: [PlanTimelineItem]
    let primaryItems: [PlanTimelineItem]
    let earlierItems: [PlanTimelineItem]
    let completedItems: [PlanTimelineItem]

    var hasIncomplete: Bool {
        !liveItems.isEmpty || !primaryItems.isEmpty || !earlierItems.isEmpty
    }

    var isFullyComplete: Bool {
        !completedItems.isEmpty
            && liveItems.isEmpty
            && primaryItems.isEmpty
            && earlierItems.isEmpty
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

        var live: [PlanTimelineItem] = []
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
            case .live:
                live.append(item)
            case .upcoming:
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
            liveItems: live,
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
            // Finished rows stay informational — no tap-to-uncomplete.
            if isDone {
                return .informational(isCompleted: true)
            }
            if allowsManualToggle(activity) {
                return .interactive(isCompleted: false)
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
    /// Day-type chrome for the summary card (flat light fills; soft dark wash).
    var dayKind: PlanDayKind? = nil

    func body(content: Content) -> some View {
        content
            .padding(compact ? PlanAgendaLayout.calendarSectionPadding : PlanAgendaLayout.sectionPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: PlanAgendaLayout.sectionCornerRadius, style: .continuous)
                    .fill(sectionFill)
                    .overlay {
                        if let dayKind, !palette.isLight {
                            RoundedRectangle(
                                cornerRadius: PlanAgendaLayout.sectionCornerRadius,
                                style: .continuous
                            )
                            .fill(WeekFitPlanChromeTokens.daySummaryAccentOverlay(
                                kind: dayKind,
                                isLight: false
                            ))
                        }
                    }
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

    private var sectionFill: Color {
        if let dayKind {
            return WeekFitPlanChromeTokens.daySummaryFill(kind: dayKind, isLight: palette.isLight)
        }
        return palette.isLight
            ? Color.white.opacity(0.97)
            : WeekFitTheme.cardBackground
    }

    private var sectionStroke: Color {
        if let dayKind {
            return WeekFitPlanChromeTokens.daySummaryStroke(kind: dayKind, isLight: palette.isLight)
        }
        return palette.isLight
            ? Color.black.opacity(0.05)
            : WeekFitTheme.whiteOpacity(0.07)
    }
}

extension View {
    func planAgendaSectionSurface(
        compact: Bool = false,
        dayKind: PlanDayKind? = nil
    ) -> some View {
        modifier(PlanAgendaSectionSurface(
            compact: compact,
            dayKind: dayKind
        ))
    }
}

/// Compact day context + character + optional recommendation (no nested card).
struct PlanAgendaDaySummaryCard: View {
    let date: Date
    let kind: PlanDayKind
    /// When false, recommendation line is omitted (e.g. open day with no useful tip).
    var showsRecommendation: Bool = true

    @EnvironmentObject private var languageManager: AppLanguageManager
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
        let _ = languageManager.selectedLanguage
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
                            .fill(iconFill)
                            .frame(
                                width: PlanAgendaLayout.summaryIconSize,
                                height: PlanAgendaLayout.summaryIconSize
                            )

                        Image(systemName: character.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(iconForeground)
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
        .planAgendaSectionSurface(dayKind: kind)
        .accessibilityElement(children: .combine)
    }

    private var iconFill: Color {
        WeekFitPlanChromeTokens.daySummaryIconWell(kind: kind, isLight: palette.isLight)
    }

    private var iconForeground: Color {
        WeekFitPlanChromeTokens.daySummaryIcon(kind: kind, isLight: palette.isLight)
    }

    private var characterTitleRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: character.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconForeground)
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
    @EnvironmentObject private var languageManager: AppLanguageManager
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        let _ = languageManager.selectedLanguage
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WeekFitPlanChromeTokens.completed(isLight: palette.isLight))
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
    /// Pulsing mark for the in-progress section.
    var showsLiveMark: Bool = false

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var livePulse = false

    private let liveTint = Color(red: 1.0, green: 0.706, blue: 0.341)

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if showsLiveMark {
                Circle()
                    .fill(liveTint.opacity(livePulse ? 1 : 0.55))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(WeekFitType.cardTitle)
                .fontDesign(.rounded)
                .foregroundStyle(showsLiveMark ? liveTint : palette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.88)

            Spacer(minLength: 8)

            if let trailing {
                trailing
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            guard showsLiveMark, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                livePulse = true
            }
        }
    }
}
