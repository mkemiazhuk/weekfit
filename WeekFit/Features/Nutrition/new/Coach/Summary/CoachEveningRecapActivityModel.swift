import Foundation
import HealthKit
import WeekFitPlanner

/// Compact activity rows for the evening Coach recap.
struct CoachEveningRecapActivityRow: Equatable, Identifiable, Sendable {
    enum Kind: String, Sendable {
        case walking
        case walkingAndRunning
        case running
        case cycling
        case strength
        case recovery
        case other
    }

    let id: String
    let kind: Kind
    let title: String
    let primaryValue: String
    let secondaryValue: String?
    let systemImage: String
    /// Deduped workout sessions merged into this row (0 for day walking without workouts).
    let sessionCount: Int
    /// e.g. "5 recorded walks" when sessionCount > 1.
    let sessionCaption: String?
}

/// Featured activity for the evening card hero.
struct CoachEveningRecapHero: Equatable, Sendable {
    enum Kind: String, Sendable {
        case walking
        case walkingAndRunning
        case running
        case cycling
        case strength
        case recovery
        case other
    }

    let kind: Kind
    /// Large number text, e.g. "18.9".
    let valueText: String
    /// Smaller unit beside the number, e.g. "km". Nil when primary is duration/steps-only.
    let unitText: String?
    /// Raw km when the hero is distance-based — re-format on language / unit change.
    let distanceKilometers: Double?
    /// Raw steps for secondary line re-format.
    let steps: Int?
    let caption: String
    let secondaryValue: String?
    let sessionCaption: String?
    let systemImage: String

    var accessibilityPrimary: String {
        if let unitText, !unitText.isEmpty {
            return "\(valueText) \(unitText)"
        }
        return valueText
    }

    func localizedCaption() -> String {
        switch kind {
        case .walking: return WeekFitLocalizedString("coach.eveningRecap.hero.walkedToday")
        case .walkingAndRunning: return WeekFitLocalizedString("coach.eveningRecap.hero.movedToday")
        case .running: return WeekFitLocalizedString("coach.eveningRecap.hero.ranToday")
        case .cycling: return WeekFitLocalizedString("coach.eveningRecap.hero.cycledToday")
        case .strength: return WeekFitLocalizedString("coach.eveningRecap.hero.strengthToday")
        case .recovery: return WeekFitLocalizedString("coach.eveningRecap.hero.recoveryToday")
        case .other: return WeekFitLocalizedString("coach.eveningRecap.hero.trainedToday")
        }
    }

    func localizedValueParts(unitSystem: WeekFitResolvedUnitSystem) -> (value: String, unit: String?) {
        if let distanceKilometers, distanceKilometers > 0.05 {
            let parts = CoachEveningRecapFormatting.distanceParts(
                kilometers: distanceKilometers,
                system: unitSystem
            )
            return (parts.value, parts.unit)
        }
        if kind == .walking || kind == .walkingAndRunning, let steps, steps > 0, distanceKilometers == nil {
            return (
                CoachEveningRecapFormatting.formatInteger(steps),
                WeekFitLocalizedString("coach.eveningRecap.unit.steps")
            )
        }
        return (valueText, unitText)
    }

    func localizedSecondary(unitSystem: WeekFitResolvedUnitSystem) -> String? {
        if let distanceKilometers, distanceKilometers > 0.05, let steps, steps > 0 {
            return CoachEveningRecapFormatting.formatSteps(steps)
        }
        return secondaryValue
    }
}

enum CoachEveningRecapDayTone: String, Sendable {
    case active
    case quiet
}

struct CoachEveningRecapActivitySummary: Equatable, Sendable {
    var hero: CoachEveningRecapHero?
    var rows: [CoachEveningRecapActivityRow]
    var workoutCount: Int
    var workoutMinutes: Int
    var healthAccessGranted: Bool
    var hasAnyActivitySignal: Bool
    var dayTone: CoachEveningRecapDayTone
    var workoutSessionIDs: [String]
    /// Raw comparison — localize at display so language/unit changes stay in sync.
    var dayComparison: CoachEveningRecapDayComparison.Result?

    func dayComparisonDisplay(unitSystem: WeekFitResolvedUnitSystem) -> String? {
        dayComparison?.displayText(unitSystem: unitSystem)
    }

    static let emptyWithoutHealth = CoachEveningRecapActivitySummary(
        hero: nil,
        rows: [],
        workoutCount: 0,
        workoutMinutes: 0,
        healthAccessGranted: false,
        hasAnyActivitySignal: false,
        dayTone: .quiet,
        workoutSessionIDs: [],
        dayComparison: nil
    )

    var workoutSummaryLine: String? {
        guard workoutCount > 0, workoutMinutes > 0 else { return nil }
        let workouts = WeekFitLocalizedQuantityFormat(
            "coach.eveningRecap.workoutsCountFormat",
            count: workoutCount,
            locale: CoachEveningRecapFormatting.locale
        )
        let duration = CoachEveningRecapFormatting.formatNaturalDuration(workoutMinutes)
        return "\(workouts) · \(duration)"
    }
}

enum CoachEveningRecapActivityAggregator {

    static func fingerprint(
        steps: Int,
        distanceKm: Double,
        sessions: [ActivitySessionSnapshot],
        comparisonDeltaKm: Double? = nil
    ) -> String {
        let deduped = dedupe(sessions)
        let sessionKey = deduped
            .map { session in
                let km = session.detail?.distanceKm.map { String(format: "%.2f", $0) } ?? "-"
                let type = session.detail?.activityType.rawValue ?? 0
                return "\(session.workoutID?.uuidString ?? session.id.uuidString)|\(type)|\(session.durationMinutes)|\(km)"
            }
            .sorted()
            .joined(separator: ",")
        let cmp = comparisonDeltaKm.map { String(format: "%.1f", $0) } ?? "-"
        return "s=\(steps)#d=\(String(format: "%.2f", distanceKm))#w=\(sessionKey)#c=\(cmp)"
    }

    static func build(
        steps: Int,
        dayWalkingRunningDistanceKm: Double,
        sessions: [ActivitySessionSnapshot],
        healthAccessGranted: Bool,
        unitSystem: WeekFitResolvedUnitSystem,
        dayComparison: CoachEveningRecapDayComparison.Result? = nil
    ) -> CoachEveningRecapActivitySummary {
        guard healthAccessGranted else { return .emptyWithoutHealth }

        let deduped = dedupe(sessions)
        var runningDistance = 0.0
        var runningMinutes = 0
        var runningSessions = 0
        var cyclingDistance = 0.0
        var cyclingMinutes = 0
        var cyclingSessions = 0
        var strengthMinutes = 0
        var strengthSessions = 0
        var walkingWorkoutMinutes = 0
        var walkingWorkoutSessions = 0
        var recoveryByTitle: [String: (minutes: Int, icon: String, count: Int)] = [:]
        var otherByTitle: [String: (minutes: Int, distance: Double?, icon: String, count: Int)] = [:]
        var workoutCount = 0
        var workoutMinutes = 0
        var workoutSessionIDs: [String] = []

        for session in deduped {
            let minutes = max(session.durationMinutes, 0)
            guard minutes > 0 || (session.detail?.distanceKm ?? 0) > 0 else { continue }
            let type = session.detail?.activityType
            let distance = session.detail?.distanceKm
            let sessionID = session.workoutID?.uuidString ?? session.id.uuidString
            let icon = session.icon

            switch classify(type, title: session.title, icon: icon) {
            case .walking:
                walkingWorkoutMinutes += minutes
                walkingWorkoutSessions += 1
                workoutCount += 1
                workoutMinutes += minutes
                workoutSessionIDs.append(sessionID)
            case .running:
                runningMinutes += minutes
                runningSessions += 1
                if let distance, distance > 0 { runningDistance += distance }
                workoutCount += 1
                workoutMinutes += minutes
                workoutSessionIDs.append(sessionID)
            case .cycling:
                cyclingMinutes += minutes
                cyclingSessions += 1
                if let distance, distance > 0 { cyclingDistance += distance }
                workoutCount += 1
                workoutMinutes += minutes
                workoutSessionIDs.append(sessionID)
            case .strength:
                strengthMinutes += minutes
                strengthSessions += 1
                workoutCount += 1
                workoutMinutes += minutes
                workoutSessionIDs.append(sessionID)
            case .recovery:
                let key = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = key.isEmpty
                    ? WeekFitLocalizedString("coach.eveningRecap.row.recovery")
                    : key
                var entry = recoveryByTitle[title] ?? (0, recoveryIcon(type, title: title, fallback: icon), 0)
                entry.minutes += minutes
                entry.count += 1
                recoveryByTitle[title] = entry
                workoutCount += 1
                workoutMinutes += minutes
                workoutSessionIDs.append(sessionID)
            case .other:
                let key = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = key.isEmpty
                    ? WeekFitLocalizedString("coach.eveningRecap.row.other")
                    : key
                var entry = otherByTitle[title] ?? (0, nil, session.icon, 0)
                entry.minutes += minutes
                entry.count += 1
                if let distance, distance > 0 {
                    entry.distance = (entry.distance ?? 0) + distance
                }
                otherByTitle[title] = entry
                workoutCount += 1
                workoutMinutes += minutes
                workoutSessionIDs.append(sessionID)
            case .walkingAndRunning:
                break
            }
        }

        let dayDistance = dayWalkingRunningDistanceKm
        let hasSeparatedRun = runningDistance > 0.05 || runningMinutes > 0
        var allRows: [CoachEveningRecapActivityRow] = []

        if steps > 0 || dayDistance > 0.05 || walkingWorkoutMinutes > 0 {
            if hasSeparatedRun {
                allRows.append(
                    makeDistanceRow(
                        id: "walkingAndRunning",
                        kind: .walkingAndRunning,
                        title: WeekFitLocalizedString("coach.eveningRecap.row.walkingAndRunning"),
                        distanceKm: dayDistance,
                        steps: steps,
                        sessionCount: walkingWorkoutSessions,
                        sessionCaptionKey: "coach.eveningRecap.recordedWalksFormat",
                        systemImage: "figure.walk",
                        unitSystem: unitSystem
                    )
                )
            } else if dayDistance > 0.05 || steps > 0 {
                allRows.append(
                    makeDistanceRow(
                        id: "walking",
                        kind: .walking,
                        title: WeekFitLocalizedString("coach.eveningRecap.row.walking"),
                        distanceKm: dayDistance,
                        steps: steps,
                        sessionCount: walkingWorkoutSessions,
                        sessionCaptionKey: "coach.eveningRecap.recordedWalksFormat",
                        systemImage: "figure.walk",
                        unitSystem: unitSystem
                    )
                )
            }
        }

        if hasSeparatedRun {
            allRows.append(
                makeWorkoutRow(
                    id: "running",
                    kind: .running,
                    title: WeekFitLocalizedString("coach.eveningRecap.row.running"),
                    distanceKm: runningDistance,
                    minutes: runningMinutes,
                    sessionCount: runningSessions,
                    sessionCaptionKey: "coach.eveningRecap.recordedRunsFormat",
                    systemImage: "figure.run",
                    unitSystem: unitSystem
                )
            )
        }

        if cyclingMinutes > 0 || cyclingDistance > 0.05 {
            allRows.append(
                makeWorkoutRow(
                    id: "cycling",
                    kind: .cycling,
                    title: WeekFitLocalizedString("coach.eveningRecap.row.cycling"),
                    distanceKm: cyclingDistance,
                    minutes: cyclingMinutes,
                    sessionCount: cyclingSessions,
                    sessionCaptionKey: "coach.eveningRecap.recordedRidesFormat",
                    systemImage: "bicycle",
                    unitSystem: unitSystem
                )
            )
        }

        if strengthMinutes > 0 {
            allRows.append(
                CoachEveningRecapActivityRow(
                    id: "strength",
                    kind: .strength,
                    title: WeekFitLocalizedString("coach.eveningRecap.row.strength"),
                    primaryValue: CoachEveningRecapFormatting.formatNaturalDuration(strengthMinutes),
                    secondaryValue: nil,
                    systemImage: "dumbbell.fill",
                    sessionCount: strengthSessions,
                    sessionCaption: sessionCaption(
                        count: strengthSessions,
                        key: "coach.eveningRecap.recordedStrengthFormat"
                    )
                )
            )
        }

        for (title, entry) in recoveryByTitle.sorted(by: { $0.value.minutes > $1.value.minutes }) {
            allRows.append(
                CoachEveningRecapActivityRow(
                    id: "recovery.\(title)",
                    kind: .recovery,
                    title: title,
                    primaryValue: CoachEveningRecapFormatting.formatNaturalDuration(entry.minutes),
                    secondaryValue: nil,
                    systemImage: entry.icon,
                    sessionCount: entry.count,
                    sessionCaption: sessionCaption(
                        count: entry.count,
                        key: "coach.eveningRecap.recordedSessionsFormat"
                    )
                )
            )
        }

        for (title, entry) in otherByTitle.sorted(by: { $0.key < $1.key }) {
            let primary: String
            let secondary: String?
            if let distance = entry.distance, distance > 0.05 {
                primary = CoachEveningRecapFormatting.formatDistance(kilometers: distance, system: unitSystem)
                secondary = entry.minutes > 0
                    ? CoachEveningRecapFormatting.formatNaturalDuration(entry.minutes)
                    : nil
            } else {
                primary = CoachEveningRecapFormatting.formatNaturalDuration(entry.minutes)
                secondary = nil
            }
            allRows.append(
                CoachEveningRecapActivityRow(
                    id: "other.\(title)",
                    kind: .other,
                    title: title,
                    primaryValue: primary,
                    secondaryValue: secondary,
                    systemImage: entry.icon.isEmpty ? "figure.mixed.cardio" : entry.icon,
                    sessionCount: entry.count,
                    sessionCaption: sessionCaption(
                        count: entry.count,
                        key: "coach.eveningRecap.recordedSessionsFormat"
                    )
                )
            )
        }

        let hero = selectHero(
            rows: allRows,
            dayDistanceKm: dayDistance,
            steps: steps,
            runningMinutes: runningMinutes,
            cyclingMinutes: cyclingMinutes,
            strengthMinutes: strengthMinutes,
            walkingWorkoutMinutes: walkingWorkoutMinutes,
            recoveryMinutes: recoveryByTitle.values.map(\.minutes).max() ?? 0,
            otherMinutes: otherByTitle.values.map(\.minutes).max() ?? 0,
            unitSystem: unitSystem
        )

        let compactRows = rowsExcludingHero(allRows, hero: hero)

        let hasSignal = !allRows.isEmpty || workoutCount > 0 || steps > 0 || dayDistance > 0.05
        let tone: CoachEveningRecapDayTone =
            (workoutCount > 0 || dayDistance >= 3.0 || steps >= 6_000) ? .active : .quiet

        return CoachEveningRecapActivitySummary(
            hero: hero,
            rows: compactRows,
            workoutCount: workoutCount,
            workoutMinutes: workoutMinutes,
            healthAccessGranted: true,
            hasAnyActivitySignal: hasSignal,
            dayTone: tone,
            workoutSessionIDs: workoutSessionIDs,
            dayComparison: dayComparison
        )
    }

    // MARK: - Rows

    private static func makeDistanceRow(
        id: String,
        kind: CoachEveningRecapActivityRow.Kind,
        title: String,
        distanceKm: Double,
        steps: Int,
        sessionCount: Int,
        sessionCaptionKey: String,
        systemImage: String,
        unitSystem: WeekFitResolvedUnitSystem
    ) -> CoachEveningRecapActivityRow {
        let primary: String
        let secondary: String?
        if distanceKm > 0.05 {
            primary = CoachEveningRecapFormatting.formatDistance(kilometers: distanceKm, system: unitSystem)
            secondary = steps > 0 ? CoachEveningRecapFormatting.formatSteps(steps) : nil
        } else {
            primary = CoachEveningRecapFormatting.formatSteps(steps)
            secondary = nil
        }
        return CoachEveningRecapActivityRow(
            id: id,
            kind: kind,
            title: title,
            primaryValue: primary,
            secondaryValue: secondary,
            systemImage: systemImage,
            sessionCount: sessionCount,
            sessionCaption: sessionCaption(count: sessionCount, key: sessionCaptionKey)
        )
    }

    private static func makeWorkoutRow(
        id: String,
        kind: CoachEveningRecapActivityRow.Kind,
        title: String,
        distanceKm: Double,
        minutes: Int,
        sessionCount: Int,
        sessionCaptionKey: String,
        systemImage: String,
        unitSystem: WeekFitResolvedUnitSystem
    ) -> CoachEveningRecapActivityRow {
        let primary: String
        let secondary: String?
        if distanceKm > 0.05 {
            primary = CoachEveningRecapFormatting.formatDistance(kilometers: distanceKm, system: unitSystem)
            secondary = minutes > 0 ? CoachEveningRecapFormatting.formatNaturalDuration(minutes) : nil
        } else {
            primary = CoachEveningRecapFormatting.formatNaturalDuration(minutes)
            secondary = nil
        }
        return CoachEveningRecapActivityRow(
            id: id,
            kind: kind,
            title: title,
            primaryValue: primary,
            secondaryValue: secondary,
            systemImage: systemImage,
            sessionCount: sessionCount,
            sessionCaption: sessionCaption(count: sessionCount, key: sessionCaptionKey)
        )
    }

    private static func sessionCaption(count: Int, key: String) -> String? {
        guard count > 1 else { return nil }
        return String(
            format: WeekFitLocalizedString(key),
            locale: CoachEveningRecapFormatting.locale,
            arguments: [Int64(count) as CVarArg]
        )
    }

    // MARK: - Hero

    private static func selectHero(
        rows: [CoachEveningRecapActivityRow],
        dayDistanceKm: Double,
        steps: Int,
        runningMinutes: Int,
        cyclingMinutes: Int,
        strengthMinutes: Int,
        walkingWorkoutMinutes: Int,
        recoveryMinutes: Int,
        otherMinutes: Int,
        unitSystem: WeekFitResolvedUnitSystem
    ) -> CoachEveningRecapHero? {
        struct Candidate {
            let kind: CoachEveningRecapHero.Kind
            let minutes: Int
            let priority: Int
        }

        // Training / movement first. Recovery never steals the hero from a
        // meaningful walk or a real workout — it stays a supporting signal.
        var workoutCandidates: [Candidate] = []
        if cyclingMinutes > 0 {
            workoutCandidates.append(.init(kind: .cycling, minutes: cyclingMinutes, priority: 0))
        }
        if runningMinutes > 0 {
            workoutCandidates.append(.init(kind: .running, minutes: runningMinutes, priority: 1))
        }
        if strengthMinutes > 0 {
            workoutCandidates.append(.init(kind: .strength, minutes: strengthMinutes, priority: 2))
        }
        if walkingWorkoutMinutes > 0 {
            workoutCandidates.append(.init(kind: .walking, minutes: walkingWorkoutMinutes, priority: 3))
        }
        if otherMinutes > 0 {
            workoutCandidates.append(.init(kind: .other, minutes: otherMinutes, priority: 4))
        }

        let bestWorkout = workoutCandidates.max {
            if $0.minutes != $1.minutes { return $0.minutes < $1.minutes }
            return $0.priority > $1.priority
        }

        let meaningfulWalk = dayDistanceKm >= 2.0 || steps >= 4_000
        if meaningfulWalk, (bestWorkout?.minutes ?? 0) < 25 {
            if let walkRow = rows.first(where: { $0.kind == .walking || $0.kind == .walkingAndRunning }) {
                return heroFromWalkRow(walkRow, dayDistanceKm: dayDistanceKm, steps: steps, unitSystem: unitSystem)
            }
        }

        if let best = bestWorkout, let row = rows.first(where: { rowKindMatchesHero($0.kind, heroKind: best.kind) }) {
            return heroFromWorkoutRow(row, kind: best.kind, unitSystem: unitSystem)
        }

        if meaningfulWalk,
           let walkRow = rows.first(where: { $0.kind == .walking || $0.kind == .walkingAndRunning }) {
            return heroFromWalkRow(walkRow, dayDistanceKm: dayDistanceKm, steps: steps, unitSystem: unitSystem)
        }

        if let best = bestWorkout, let row = rows.first(where: { rowKindMatchesHero($0.kind, heroKind: best.kind) }) {
            return heroFromWorkoutRow(row, kind: best.kind, unitSystem: unitSystem)
        }

        if recoveryMinutes > 0,
           let recoveryRow = rows.first(where: { $0.kind == .recovery }) {
            return heroFromWorkoutRow(recoveryRow, kind: .recovery, unitSystem: unitSystem)
        }

        return nil
    }

    private static func heroFromWalkRow(
        _ row: CoachEveningRecapActivityRow,
        dayDistanceKm: Double,
        steps: Int,
        unitSystem: WeekFitResolvedUnitSystem
    ) -> CoachEveningRecapHero {
        let captionKey = row.kind == .walkingAndRunning
            ? "coach.eveningRecap.hero.movedToday"
            : "coach.eveningRecap.hero.walkedToday"
        if dayDistanceKm > 0.05 {
            let parts = CoachEveningRecapFormatting.distanceParts(
                kilometers: dayDistanceKm,
                system: unitSystem
            )
            return CoachEveningRecapHero(
                kind: row.kind == .walkingAndRunning ? .walkingAndRunning : .walking,
                valueText: parts.value,
                unitText: parts.unit,
                distanceKilometers: dayDistanceKm,
                steps: steps > 0 ? steps : nil,
                caption: WeekFitLocalizedString(captionKey),
                secondaryValue: steps > 0 ? CoachEveningRecapFormatting.formatSteps(steps) : nil,
                sessionCaption: row.sessionCaption,
                systemImage: row.systemImage
            )
        }
        return CoachEveningRecapHero(
            kind: .walking,
            valueText: CoachEveningRecapFormatting.formatInteger(steps),
            unitText: WeekFitLocalizedString("coach.eveningRecap.unit.steps"),
            distanceKilometers: nil,
            steps: steps,
            caption: WeekFitLocalizedString(captionKey),
            secondaryValue: nil,
            sessionCaption: row.sessionCaption,
            systemImage: row.systemImage
        )
    }

    private static func heroFromWorkoutRow(
        _ row: CoachEveningRecapActivityRow,
        kind: CoachEveningRecapHero.Kind,
        unitSystem: WeekFitResolvedUnitSystem
    ) -> CoachEveningRecapHero {
        let captionKey: String
        switch kind {
        case .running: captionKey = "coach.eveningRecap.hero.ranToday"
        case .cycling: captionKey = "coach.eveningRecap.hero.cycledToday"
        case .strength: captionKey = "coach.eveningRecap.hero.strengthToday"
        case .walking, .walkingAndRunning: captionKey = "coach.eveningRecap.hero.walkedToday"
        case .recovery: captionKey = "coach.eveningRecap.hero.recoveryToday"
        case .other: captionKey = "coach.eveningRecap.hero.trainedToday"
        }

        // Prefer splitting distance when primary looks like a distance string.
        if let km = parseLeadingDistanceKm(from: row.primaryValue, system: unitSystem) {
            let parts = CoachEveningRecapFormatting.distanceParts(kilometers: km, system: unitSystem)
            return CoachEveningRecapHero(
                kind: kind,
                valueText: parts.value,
                unitText: parts.unit,
                distanceKilometers: km,
                steps: nil,
                caption: WeekFitLocalizedString(captionKey),
                secondaryValue: row.secondaryValue,
                sessionCaption: row.sessionCaption,
                systemImage: row.systemImage
            )
        }

        return CoachEveningRecapHero(
            kind: kind,
            valueText: row.primaryValue,
            unitText: nil,
            distanceKilometers: nil,
            steps: nil,
            caption: WeekFitLocalizedString(captionKey),
            secondaryValue: row.secondaryValue,
            sessionCaption: row.sessionCaption,
            systemImage: row.systemImage
        )
    }

    /// Best-effort: recover km from a just-formatted distance for hero split.
    private static func parseLeadingDistanceKm(
        from text: String,
        system: WeekFitResolvedUnitSystem
    ) -> Double? {
        let unit = WeekFitUnitPolicy.distanceUnitLabel(for: system)
        guard text.contains(unit) else { return nil }
        let numberPart = text
            .replacingOccurrences(of: unit, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = NumberFormatter()
        formatter.locale = CoachEveningRecapFormatting.locale
        formatter.numberStyle = .decimal
        guard let value = formatter.number(from: numberPart)?.doubleValue else { return nil }
        switch system {
        case .metric:
            return value
        case .uk, .us:
            return Measurement(value: value, unit: UnitLength.miles)
                .converted(to: .kilometers).value
        }
    }

    private static func rowKindMatchesHero(
        _ rowKind: CoachEveningRecapActivityRow.Kind,
        heroKind: CoachEveningRecapHero.Kind
    ) -> Bool {
        switch (rowKind, heroKind) {
        case (.walking, .walking), (.walkingAndRunning, .walkingAndRunning),
             (.running, .running), (.cycling, .cycling),
             (.strength, .strength), (.recovery, .recovery), (.other, .other),
             (.walking, .walkingAndRunning), (.walkingAndRunning, .walking):
            return true
        default:
            return false
        }
    }

    /// When hero is a specific recovery session, only that row is featured —
    /// other recovery rows stay as supporting signals.
    private static func rowsExcludingHero(
        _ allRows: [CoachEveningRecapActivityRow],
        hero: CoachEveningRecapHero?
    ) -> [CoachEveningRecapActivityRow] {
        guard let hero else { return allRows }
        if hero.kind == .recovery {
            // Drop only the featured recovery row (matched by duration/title via first match).
            var droppedFeatured = false
            return allRows.filter { row in
                guard row.kind == .recovery else { return true }
                if !droppedFeatured, row.primaryValue == hero.valueText {
                    droppedFeatured = true
                    return false
                }
                return true
            }
        }
        return allRows.filter { !rowKindMatchesHero($0.kind, heroKind: hero.kind) }
    }

    // MARK: - Dedupe

    /// UUID duplicates, overlapping same-type sessions, and local rows shadowed by HealthKit.
    static func dedupe(_ sessions: [ActivitySessionSnapshot]) -> [ActivitySessionSnapshot] {
        var byID = Set<String>()
        var unique: [ActivitySessionSnapshot] = []
        for session in sessions.sorted(by: { $0.startDate < $1.startDate }) {
            let key = session.workoutID?.uuidString ?? "local:\(session.id.uuidString)"
            guard byID.insert(key).inserted else { continue }
            unique.append(session)
        }

        // Prefer HealthKit-backed rows when a local Quick Start overlaps the same window.
        var result: [ActivitySessionSnapshot] = []
        for session in unique {
            if let index = result.firstIndex(where: { overlapsAsDuplicate($0, session) }) {
                let existing = result[index]
                result[index] = preferred(existing, session)
            } else {
                result.append(session)
            }
        }
        return result
    }

    private static func preferred(
        _ a: ActivitySessionSnapshot,
        _ b: ActivitySessionSnapshot
    ) -> ActivitySessionSnapshot {
        let aHK = a.workoutID != nil
        let bHK = b.workoutID != nil
        if aHK != bHK { return aHK ? a : b }
        let aScore = a.durationMinutes + (a.detail?.distanceKm != nil ? 2 : 0)
        let bScore = b.durationMinutes + (b.detail?.distanceKm != nil ? 2 : 0)
        return bScore > aScore ? b : a
    }

    private static func overlapsAsDuplicate(
        _ a: ActivitySessionSnapshot,
        _ b: ActivitySessionSnapshot
    ) -> Bool {
        let aType = a.detail?.activityType
        let bType = b.detail?.activityType
        if let aType, let bType, aType != bType { return false }
        if aType == nil || bType == nil {
            if classify(aType, title: a.title, icon: a.icon)
                != classify(bType, title: b.title, icon: b.icon) {
                return false
            }
        }

        let aEnd = endDate(of: a)
        let bEnd = endDate(of: b)
        let overlapStart = max(a.startDate, b.startDate)
        let overlapEnd = min(aEnd, bEnd)
        let overlap = overlapEnd.timeIntervalSince(overlapStart)
        guard overlap > 0 else {
            let startDelta = abs(a.startDate.timeIntervalSince(b.startDate))
            let durationDelta = abs(a.durationMinutes - b.durationMinutes)
            return startDelta <= 180
                && durationDelta <= max(5, Int(Double(max(a.durationMinutes, b.durationMinutes)) * 0.25))
        }
        let shorter = min(aEnd.timeIntervalSince(a.startDate), bEnd.timeIntervalSince(b.startDate))
        return shorter > 0 && overlap / shorter >= 0.55
    }

    private static func endDate(of session: ActivitySessionSnapshot) -> Date {
        session.detail?.endDate
            ?? Calendar.current.date(byAdding: .minute, value: max(session.durationMinutes, 0), to: session.startDate)
            ?? session.startDate
    }

    // MARK: - Classify

    private static func classify(
        _ type: HKWorkoutActivityType?,
        title: String,
        icon: String = ""
    ) -> CoachEveningRecapActivityRow.Kind {
        if let type {
            switch type {
            case .walking, .hiking:
                return .walking
            case .running:
                return .running
            case .cycling, .handCycling:
                return .cycling
            case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
                return .strength
            case .yoga, .pilates, .mindAndBody, .flexibility, .cooldown, .preparationAndRecovery:
                return .recovery
            default:
                break
            }
        }

        let haystack = "\(title) \(icon)".lowercased()
        // Walk/run first so "recovery walk" stays in the day-distance story.
        if haystack.contains("walk") || haystack.contains("ход") || haystack.contains("прогул")
            || haystack.contains("hike") || haystack.contains("поход") || haystack.contains("хайкинг") {
            return .walking
        }
        if haystack.contains("run") || haystack.contains("бег") || haystack.contains("jog") {
            return .running
        }
        if haystack.contains("cycl") || haystack.contains("bike") || haystack.contains("ride")
            || haystack.contains("вело") {
            return .cycling
        }
        if haystack.contains("strength") || haystack.contains("сил") || haystack.contains("gym")
            || haystack.contains("weight") {
            return .strength
        }
        // Soft recovery sessions — yoga, stretch, breath, sauna — as supporting rows.
        if isRecoveryTitle(haystack) {
            return .recovery
        }
        return .other
    }

    private static func isRecoveryTitle(_ haystack: String) -> Bool {
        haystack.contains("yoga")
            || haystack.contains("йога")
            || haystack.contains("瑜伽")
            || haystack.contains("pilates")
            || haystack.contains("пилатес")
            || haystack.contains("stretch")
            || haystack.contains("растяж")
            || haystack.contains("拉伸")
            || haystack.contains("cooldown")
            || haystack.contains("breath")
            || haystack.contains("дых")
            || haystack.contains("呼吸")
            || haystack.contains("mobility")
            || haystack.contains("мобильн")
            || haystack.contains("sauna")
            || haystack.contains("саун")
            || haystack.contains("桑拿")
            || haystack.contains("mind and body")
            || haystack.contains("mindfulness")
            || haystack.contains("восстанов")
            || haystack.contains("recovery")
            || haystack.contains("figure.yoga")
            || haystack.contains("figure.pilates")
            || haystack.contains("figure.cooldown")
            || haystack.contains("figure.mind.and.body")
            || haystack.contains("figure.flexibility")
    }

    private static func recoveryIcon(
        _ type: HKWorkoutActivityType?,
        title: String,
        fallback: String
    ) -> String {
        let haystack = title.lowercased()
        if type == .yoga || haystack.contains("yoga") || haystack.contains("йога") || haystack.contains("瑜伽") {
            return "figure.yoga"
        }
        if type == .pilates || haystack.contains("pilates") || haystack.contains("пилатес") {
            return "figure.pilates"
        }
        if haystack.contains("stretch") || haystack.contains("растяж") || haystack.contains("拉伸")
            || haystack.contains("cooldown") || type == .cooldown || type == .flexibility {
            return "figure.cooldown"
        }
        if haystack.contains("breath") || haystack.contains("дых") || haystack.contains("呼吸")
            || haystack.contains("mind") {
            return "wind"
        }
        if haystack.contains("sauna") || haystack.contains("саун") || haystack.contains("桑拿") {
            return "thermometer.sun.fill"
        }
        if !fallback.isEmpty { return fallback }
        return "leaf.fill"
    }
}
