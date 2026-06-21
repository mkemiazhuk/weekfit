import Foundation
@testable import WeekFit

enum CoachNarrativeContractAuditor {

    static func fullSnapshot(from state: CoachState) -> CoachNarrativeFullStorySnapshot? {
        guard let story = state.finalStory else { return nil }
        let render = CoachFinalStoryRenderModel(story: story)
        let phase = state.guidance.map { String(describing: $0.phase) } ?? "unknown"
        let intent = String(describing: story.primaryFocus)
        let read = render.displaySubtitle.isEmpty ? render.subtitle : render.displaySubtitle
        let careful = render.displayAvoid.isEmpty ? render.avoidRecommendation : render.displayAvoid
        let supportItems = render.supportActions.map { "\($0.title) — \($0.subtitle)" }
            + render.supportSignals.map { "\($0.kind.rawValue): \($0.title)" }

        return CoachNarrativeFullStorySnapshot(
            phase: phase,
            priority: intent,
            owner: story.owner.rawValue,
            intent: intent,
            badge: render.badge,
            title: render.title,
            read: read,
            recommendation: render.primaryRecommendation,
            careful: careful,
            why: render.whyRows.map(\.title),
            supportItems: supportItems,
            todayTitle: render.title,
            todaySubtitle: render.subtitle,
            coachTitle: render.title,
            coachRead: read,
            coachRecommendation: render.primaryRecommendation,
            coachCareful: careful,
            coachWhy: render.whyRows.map(\.title)
        )
    }

    static func audit(
        state: CoachState,
        scenario: CoachNarrativeMatrixScenario
    ) -> CoachNarrativeContractAuditResult? {
        guard let story = state.finalStory,
              let snapshot = fullSnapshot(from: state) else {
            return nil
        }
        let render = CoachFinalStoryRenderModel(story: story)
        var findings: [CoachNarrativeContractFinding] = []

        findings += localizationFindings(snapshot: snapshot)
        findings += ownerPriorityFindings(story: story, snapshot: snapshot)
        findings += badgeFindings(story: story, snapshot: snapshot, context: scenario.context)
        findings += activeContextFindings(story: story, render: render, snapshot: snapshot, context: scenario.context)
        findings += plannedWorkoutFindings(render: render, snapshot: snapshot, context: scenario.context)
        findings += noWorkoutContextFindings(render: render, snapshot: snapshot, context: scenario.context)
        findings += recoverySeverityFindings(render: render, snapshot: snapshot, context: scenario.context)
        findings += nutritionTimingFindings(render: render, snapshot: snapshot, context: scenario.context)
        findings += hydrationTimingFindings(render: render, snapshot: snapshot, context: scenario.context)
        findings += sleepRecoveryEvidenceFindings(render: render, snapshot: snapshot, context: scenario.context)
        findings += internalContradictionFindings(render: render, snapshot: snapshot, context: scenario.context)
        findings += todayCoachAlignmentFindings(snapshot: snapshot)
        findings += rawMetricFindings(render: render, snapshot: snapshot)
        findings += activityMismatchFindings(render: render, snapshot: snapshot, context: scenario.context)
        findings += syncEdgeCaseFindings(story: story, render: render, snapshot: snapshot, context: scenario.context)
        findings += voiceFindings(render: render, snapshot: snapshot)
        findings += sectionPresenceFindings(render: render, story: story)

        return CoachNarrativeContractAuditResult(snapshot: snapshot, findings: deduped(findings))
    }

    static func classifyDuplicateClusters(
        rows: [CoachNarrativeMatrixAuditRow]
    ) -> [(text: String, scenarioIDs: [Int], groups: [String])] {
        var buckets: [String: [(id: Int, group: String)]] = [:]
        for row in rows where row.result.severity == .pass || row.result.severity == .warn {
            let fields = [
                row.result.snapshot.recommendation,
                row.result.snapshot.careful,
                row.result.snapshot.title
            ] + row.result.snapshot.why
            for field in fields {
                let normalized = normalizedCopy(field)
                guard normalized.count >= 16 else { continue }
                buckets[normalized, default: []].append((row.scenario.id, row.scenario.group.rawValue))
            }
        }
        return buckets
            .filter { $0.value.count >= 3 }
            .map { key, values in
                (
                    text: key,
                    scenarioIDs: values.map(\.id).sorted(),
                    groups: Array(Set(values.map(\.group))).sorted()
                )
            }
            .sorted { $0.scenarioIDs.count > $1.scenarioIDs.count }
    }

    // MARK: - Contract checks

    private static func localizationFindings(snapshot: CoachNarrativeFullStorySnapshot) -> [CoachNarrativeContractFinding] {
        let all = [
            snapshot.badge, snapshot.title, snapshot.read, snapshot.recommendation, snapshot.careful,
            snapshot.todayTitle, snapshot.todaySubtitle
        ] + snapshot.why + snapshot.supportItems
        return all.compactMap { text in
            guard text.contains("coach.final.") else { return nil }
            return finding(.rawLocalizationKey, .fail, .contextSelectionBug, text)
        }
    }

    private static func ownerPriorityFindings(
        story: CoachFinalStory,
        snapshot: CoachNarrativeFullStorySnapshot
    ) -> [CoachNarrativeContractFinding] {
        var findings: [CoachNarrativeContractFinding] = []
        let activeOwners: Set<CoachFinalStoryOwner> = [
            .activeActivity, .pacingExecution, .sustainableExecution,
            .fuelingDuringActivity, .hydrationExecution
        ]
        if story.primaryFocus == .activeActivity && !activeOwners.contains(story.owner) && story.owner != .recovery {
            findings.append(finding(
                .ownerPriorityMismatch, .fail, .stateOwnerBug,
                "priority=activeActivity but owner=\(story.owner.rawValue)"
            ))
        }
        if story.owner == .stableOverview && story.primaryFocus == .activeActivity {
            findings.append(finding(
                .ownerPriorityMismatch, .fail, .stateOwnerBug,
                "active priority with stableOverview owner"
            ))
        }
        if story.owner == .postActivityRecovery && story.primaryFocus == .dailyOverview {
            findings.append(finding(
                .ownerPriorityMismatch, .warn, .stateOwnerBug,
                "postActivityRecovery owner with dailyOverview priority"
            ))
        }
        if snapshot.owner == "recovery" && snapshot.priority.contains("dailyOverview") {
            findings.append(finding(
                .ownerPriorityMismatch, .warn, .stateOwnerBug,
                "recovery owner with dailyOverview priority"
            ))
        }
        return findings
    }

    private static func badgeFindings(
        story: CoachFinalStory,
        snapshot: CoachNarrativeFullStorySnapshot,
        context: CoachNarrativeMatrixContext
    ) -> [CoachNarrativeContractFinding] {
        var findings: [CoachNarrativeContractFinding] = []
        let badge = snapshot.badge.lowercased()
        if context.hasActiveSession {
            if !badge.contains("live") && story.owner != .hydrationExecution && story.owner != .fuelingDuringActivity {
                findings.append(finding(
                    .badgeMismatch, .fail, .stateOwnerBug,
                    "Active session but badge=\(snapshot.badge)"
                ))
            }
        }
        if story.owner == .recovery || story.owner == .postActivityRecovery {
            if badge.contains("on track") {
                findings.append(finding(
                    .badgeMismatch, .warn, .stateOwnerBug,
                    "Recovery owner with ON TRACK badge"
                ))
            }
        }
        return findings
    }

    private static func activeContextFindings(
        story: CoachFinalStory,
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot,
        context: CoachNarrativeMatrixContext
    ) -> [CoachNarrativeContractFinding] {
        guard context.hasActiveSession else { return [] }
        var findings: [CoachNarrativeContractFinding] = []
        let allowedOwners: Set<CoachFinalStoryOwner> = [
            .activeActivity, .pacingExecution, .sustainableExecution,
            .fuelingDuringActivity, .hydrationExecution, .recovery
        ]
        if context.activity != .activeSauna && !allowedOwners.contains(story.owner) {
            findings.append(finding(
                .activeContextViolation, .fail, .stateOwnerBug,
                "Active session owner=\(story.owner.rawValue)"
            ))
        }
        if context.activity == .activeSauna && story.owner == .stableOverview {
            findings.append(finding(
                .activeContextViolation, .fail, .stateOwnerBug,
                "Active sauna fell into stableOverview"
            ))
        }

        let visible = visibleText(snapshot).lowercased()
        let forbidden = [
            "no activities planned", "pretty quiet day", "morning's going fine",
            "today's going fine", "stay with today's plan"
        ]
        for phrase in forbidden where visible.contains(phrase) {
            findings.append(finding(
                .activeContextViolation, .fail, .copyQuality,
                "Active session used calm-day copy: \(phrase)"
            ))
        }

        let activeHints = ["walk", "run", "ride", "strength", "sauna", "session", "pace", "settle", "keep", "hold", "relaxed", "controlled", "steady", "rhythm", "live"]
        if !activeHints.contains(where: { snapshot.title.lowercased().contains($0) }) &&
            story.owner != .hydrationExecution && story.owner != .fuelingDuringActivity {
            findings.append(finding(
                .activeContextViolation, .warn, .copyQuality,
                "Active session title does not acknowledge in-session coaching"
            ))
        }
        return findings
    }

    private static func plannedWorkoutFindings(
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot,
        context: CoachNarrativeMatrixContext
    ) -> [CoachNarrativeContractFinding] {
        guard context.hasPlannedWorkoutInPrepWindow else { return [] }
        var findings: [CoachNarrativeContractFinding] = []
        let visible = visibleText(snapshot).lowercased()
        let planned = context.plannedActivityKind ?? "workout"
        let acknowledgementHints = [planned, "plan starts", "next up", "prepare", "before", "ready for"]
        if !acknowledgementHints.contains(where: { visible.contains($0) }) {
            findings.append(finding(
                .plannedWorkoutViolation, .warn, .contextSelectionBug,
                "Planned \(planned) in prep window not acknowledged"
            ))
        }

        if planned == "run" && visible.contains("walk 20-40") {
            findings.append(finding(
                .activityMismatch, .fail, .copyQuality,
                "Run planned but recommendation suggests generic walk"
            ))
        }
        if planned == "run" && snapshot.recommendation.lowercased().contains("walk") &&
            !snapshot.recommendation.lowercased().contains("run") &&
            !snapshot.recommendation.lowercased().contains("ready for") {
            findings.append(finding(
                .plannedWorkoutViolation, .fail, .copyQuality,
                "Prep recommendation mismatches planned run"
            ))
        }
        let calmForbidden = ["morning's going fine", "pretty quiet day", "stay with today's plan"]
        for phrase in calmForbidden where visible.contains(phrase) && context.recoveryBand != .excellent {
            findings.append(finding(
                .plannedWorkoutViolation, .warn, .copyQuality,
                "Prep window used calm-day copy: \(phrase)"
            ))
        }
        return findings
    }

    private static func noWorkoutContextFindings(
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot,
        context: CoachNarrativeMatrixContext
    ) -> [CoachNarrativeContractFinding] {
        guard !context.hasWorkoutContext && !context.hasActiveSession else { return [] }
        let workoutPhrases = [
            "main set", "reps in reserve", "fuel during the ride", "pace the run",
            "before the ride", "before the run", "during the session", "finish the session",
            "prepare for training", "warm up", "warm-up", "next activity", "workout readiness"
        ]
        let visible = visibleText(snapshot).lowercased()
        let hits = workoutPhrases.filter { visible.contains($0) }
        guard !hits.isEmpty else { return [] }
        return [
            finding(
                .noWorkoutContextViolation, .fail, .contextSelectionBug,
                "Workout phrasing without activity context: \(hits.joined(separator: ", "))"
            )
        ]
    }

    private static func recoverySeverityFindings(
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot,
        context: CoachNarrativeMatrixContext
    ) -> [CoachNarrativeContractFinding] {
        let visible = visibleText(snapshot).lowercased()
        var findings: [CoachNarrativeContractFinding] = []

        switch context.recoveryBand {
        case .excellent, .good:
            let restrictive = [
                "holding back", "take it easy today", "go gently", "recovery day",
                "rest catches up", "save the work", "do not add load"
            ]
            if restrictive.contains(where: { visible.contains($0) }) && !context.hasCompletedWorkout {
                findings.append(finding(
                    .recoverySeverityViolation, .warn, .copyQuality,
                    "High recovery day sounds overly restrictive"
                ))
            }
        case .moderate:
            let dramatic = ["depleted", "critical", "danger", "cannot train", "stop training"]
            if dramatic.contains(where: { visible.contains($0) }) {
                findings.append(finding(
                    .recoverySeverityViolation, .warn, .copyQuality,
                    "Moderate recovery uses dramatic language"
                ))
            }
        case .low, .veryLow:
            let permissive = ["push intensity", "go harder", "turn it up", "train normally"]
            let severityText = context.hasActiveSession
                ? [snapshot.recommendation, snapshot.careful, snapshot.title].joined(separator: " ").lowercased()
                : visible
            func encouragesIntensity(_ text: String) -> Bool {
                if permissive.contains(where: { text.contains($0) }) { return true }
                guard text.contains("add intensity") else { return false }
                let negated = [
                    "do not add intensity",
                    "don't add intensity",
                    "avoid adding intensity",
                    "not add intensity"
                ]
                return !negated.contains(where: { text.contains($0) })
            }
            if encouragesIntensity(severityText) {
                findings.append(finding(
                    .recoverySeverityViolation, .fail, .evidenceMismatch,
                    "Low recovery encourages intensity"
                ))
            }
            if context.recoveryBand == .veryLow {
                let missingRecoveryTone = !visible.contains("easy") &&
                    !visible.contains("gentle") &&
                    !visible.contains("rest") &&
                    !visible.contains("recovery") &&
                    !visible.contains("lighter")
                if missingRecoveryTone && snapshot.owner == "stableOverview" {
                    findings.append(finding(
                        .recoverySeverityViolation, .warn, .stateOwnerBug,
                        "Very low recovery fell into unrestricted stableOverview"
                    ))
                }
            }
        }
        return findings
    }

    private static func nutritionTimingFindings(
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot,
        context: CoachNarrativeMatrixContext
    ) -> [CoachNarrativeContractFinding] {
        var findings: [CoachNarrativeContractFinding] = []
        let visible = visibleText(snapshot).lowercased()
        let fuelMention = ["fuel", "eat", "food", "meal", "breakfast", "snack", "protein", "calories"].contains { visible.contains($0) }

        switch context.nutrition {
        case .emptyEarlyMorning:
            if context.time.isEarlyMorning && !context.hasPlannedWorkoutInPrepWindow && fuelMention &&
                (visible.contains("must") || visible.contains("critical") || visible.contains("urgent")) {
                findings.append(finding(
                    .nutritionTimingViolation, .warn, .copyQuality,
                    "Early morning empty nutrition warning too strong"
                ))
            }
            if context.activity == .easyWalkPlanned && fuelMention &&
                snapshot.recommendation.lowercased().contains("eat something before the day builds") &&
                context.activityTiming == .startsIn2Hours {
                // acceptable gentle mention - no finding
            } else if context.time == .earlyMorning && fuelMention && !context.hasPlannedWorkoutInPrepWindow &&
                        snapshot.owner == "fuel" {
                findings.append(finding(
                    .nutritionTimingViolation, .warn, .heuristicFalsePositive,
                    "Fuel owner on early morning with no imminent workout"
                ))
            }
        case .emptyAfternoon:
            if !fuelMention {
                return [finding(
                    .nutritionTimingViolation, .warn, .contextSelectionBug,
                    "Afternoon empty nutrition not reflected in story"
                )]
            }
        case .underFueledAfterWorkout:
            if context.hasCompletedWorkout &&
                !visible.contains("protein") && !visible.contains("eat") && !visible.contains("fuel") && !visible.contains("meal") {
                findings.append(finding(
                    .nutritionTimingViolation, .warn, .copyQuality,
                    "Under-fueled post-workout without refuel guidance"
                ))
            }
        case .strongAdherence:
            if visible.contains("underfueled") || visible.contains("need protein now") || visible.contains("refuel after strength") {
                findings.append(finding(
                    .nutritionTimingViolation, .warn, .evidenceMismatch,
                    "Strong nutrition adherence but story still alarms on fuel"
                ))
            }
        default:
            break
        }
        return findings
    }

    private static func hydrationTimingFindings(
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot,
        context: CoachNarrativeMatrixContext
    ) -> [CoachNarrativeContractFinding] {
        let visible = visibleText(snapshot).lowercased()
        let hydrationMention = ["water", "hydration", "drink", "fluid", "sip"].contains { visible.contains($0) }

        switch context.hydration {
        case .normal:
            if hydrationMention && (visible.contains("low on water") || visible.contains("dehydrated") || visible.contains("haven't logged water")) {
                return [finding(
                    .hydrationTimingViolation, .warn, .evidenceMismatch,
                    "Normal hydration framed as a problem"
                )]
            }
        case .noWaterEarlyMorning:
            if context.time == .earlyMorning && snapshot.owner == "hydration" && !context.hasPlannedWorkoutInPrepWindow {
                return [finding(
                    .hydrationTimingViolation, .warn, .heuristicFalsePositive,
                    "Hydration owner dominating early morning without imminent demand"
                )]
            }
        case .lowBeforeEndurance, .lowBeforeSauna, .heatDayLowWater:
            if !hydrationMention && !context.hasActiveSession {
                return [finding(
                    .hydrationTimingViolation, .warn, .contextSelectionBug,
                    "Hydration gap before demand not reflected"
                )]
            }
        default:
            break
        }
        return []
    }

    private static func sleepRecoveryEvidenceFindings(
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot,
        context: CoachNarrativeMatrixContext
    ) -> [CoachNarrativeContractFinding] {
        var findings: [CoachNarrativeContractFinding] = []
        let visible = visibleText(snapshot).lowercased()

        func containsPoorSleepClaim(_ text: String) -> Bool {
            let deficitClaims = [
                "didn't sleep enough",
                "not enough sleep",
                "sleep was poor",
                "sleep deficit",
                "shorter than ideal",
                "very short sleep",
                "short sleep is limiting",
                "short sleep may reduce",
                "short sleep lowers",
                "sleep is reducing"
            ]
            if deficitClaims.contains(where: { text.contains($0) }) { return true }
            return text.range(of: #"\bshort sleep\b"#, options: .regularExpression) != nil
        }

        func containsSleepProtectionCopy(_ text: String) -> Bool {
            let allowed = [
                "protect sleep",
                "wind down",
                "wind the day down",
                "keep the evening quiet",
                "keep the evening calm",
                "let sleep do the next part",
                "close the day calmly",
                "sleep protection"
            ]
            return allowed.contains(where: { text.contains($0) })
        }

        if context.recoveryDriver == .balanced || context.recoveryDriver == .goodSleepLowReadiness {
            if containsPoorSleepClaim(visible) {
                if context.recoveryDriver == .balanced &&
                    (context.recoveryBand == .excellent || context.recoveryBand == .good) {
                    findings.append(finding(
                        .sleepRecoveryEvidenceViolation, .fail, .evidenceMismatch,
                        "Claims poor sleep despite balanced sleep evidence"
                    ))
                }
            }
        }
        if context.recoveryDriver == .missingSleepData &&
            containsPoorSleepClaim(visible) {
            findings.append(finding(
                .sleepRecoveryEvidenceViolation, .fail, .evidenceMismatch,
                "Sleep deficit claimed without sleep data"
            ))
        }
        if context.recoveryDriver == .missingRecoveryScore &&
            visible.contains("recovery is at 0%") {
            findings.append(finding(
                .sleepRecoveryEvidenceViolation, .warn, .copyQuality,
                "Missing recovery score surfaced as 0% metric"
            ))
        }
        if (context.recoveryBand == .low || context.recoveryBand == .veryLow) &&
            (visible.contains("recovery looks solid") || visible.contains("recovery looks good")) {
            findings.append(finding(
                .sleepRecoveryEvidenceViolation, .fail, .evidenceMismatch,
                "Low recovery score described as solid/good"
            ))
        }
        if visible.contains("hrv") && context.recoveryDriver == .balanced && context.recoveryBand == .excellent {
            findings.append(finding(
                .sleepRecoveryEvidenceViolation, .warn, .copyQuality,
                "HRV limiting language on excellent recovery calm day"
            ))
        }
        return findings
    }

    private static func internalContradictionFindings(
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot,
        context: CoachNarrativeMatrixContext
    ) -> [CoachNarrativeContractFinding] {
        var findings: [CoachNarrativeContractFinding] = []
        let title = snapshot.title.lowercased()
        let rec = snapshot.recommendation.lowercased()
        let careful = snapshot.careful.lowercased()
        let read = snapshot.read.lowercased()
        let why = snapshot.why.joined(separator: " ").lowercased()

        if (title.contains("going fine") || title.contains("quiet day")) &&
            (rec.contains("take it easy") || rec.contains("rest before") || rec.contains("go gently")) {
            findings.append(finding(
                .internalCopyContradiction, .warn, .copyQuality,
                "Calm title with restrictive recommendation"
            ))
        }
        if snapshot.badge.uppercased().contains("ON TRACK") &&
            careful.contains("avoid hard work") && !read.contains("recovery") && !read.contains("sleep") {
            findings.append(finding(
                .internalCopyContradiction, .warn, .copyQuality,
                "ON TRACK badge with hard-work avoidance and no reason in read"
            ))
        }
        if read.contains("recovery looks solid") && why.contains("not complete") {
            findings.append(finding(
                .internalCopyContradiction, .fail, .copyQuality,
                "Read says solid recovery but why says incomplete"
            ))
        }
        if normalizedCopy(rec) == normalizedCopy(careful) && !rec.isEmpty {
            findings.append(finding(
                .internalCopyContradiction, .fail, .copyQuality,
                "Recommendation and careful say the same thing"
            ))
        }
        return findings
    }

    private static func todayCoachAlignmentFindings(snapshot: CoachNarrativeFullStorySnapshot) -> [CoachNarrativeContractFinding] {
        var findings: [CoachNarrativeContractFinding] = []
        if snapshot.todayTitle != snapshot.coachTitle {
            findings.append(finding(
                .todayCoachMisalignment, .warn, .contextSelectionBug,
                "Today title differs from Coach title"
            ))
        }
        let today = snapshot.todaySubtitle.lowercased()
        let coach = snapshot.coachRead.lowercased()
        if !today.isEmpty && !coach.isEmpty {
            let todayRestrictive = today.contains("take it easy") || today.contains("recovery day")
            let coachCalm = snapshot.coachTitle.lowercased().contains("going fine")
            if todayRestrictive && coachCalm {
                findings.append(finding(
                    .todayCoachMisalignment, .fail, .contextSelectionBug,
                    "Today card restrictive while Coach title is calm"
                ))
            }
            let coachRestrictive = snapshot.coachTitle.lowercased().contains("go gently") ||
                snapshot.coachRecommendation.lowercased().contains("rest before")
            let todayCalm = today.contains("going fine") || today.contains("on track")
            if todayCalm && coachRestrictive {
                findings.append(finding(
                    .todayCoachMisalignment, .fail, .contextSelectionBug,
                    "Today card calm while Coach screen is restrictive"
                ))
            }
        }
        return findings
    }

    private static func rawMetricFindings(
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot
    ) -> [CoachNarrativeContractFinding] {
        var findings: [CoachNarrativeContractFinding] = []
        let patterns = [
            #"recovery is at \d+%"#,
            #"recovery is only at \d+%"#,
            #"sleep is \d+\.?\d* h"#,
            #"sleep is \d+\.?\d* hours"#,
            #"\d+% today"#
        ]
        let all = [snapshot.read, snapshot.recommendation] + snapshot.why
        for text in all {
            for pattern in patterns {
                if text.range(of: pattern, options: .regularExpression) != nil {
                    findings.append(finding(
                        .rawMetricRepetition, .warn, .copyQuality,
                        "Raw metric in visible copy: \(text)"
                    ))
                }
            }
        }
        return findings
    }

    private static func activityMismatchFindings(
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot,
        context: CoachNarrativeMatrixContext
    ) -> [CoachNarrativeContractFinding] {
        guard let planned = context.plannedActivityKind else { return [] }
        let rec = snapshot.recommendation.lowercased()
        var findings: [CoachNarrativeContractFinding] = []

        if planned == "strength" && (rec.contains("ride") || rec.contains("run")) && !rec.contains("strength") {
            findings.append(finding(.activityMismatch, .fail, .copyQuality, "Strength context but endurance recommendation"))
        }
        if planned == "ride" && rec.contains("walk 20-40") {
            findings.append(finding(.activityMismatch, .fail, .copyQuality, "Ride context but walk recommendation"))
        }
        if context.hasActiveSession && context.plannedActivityKind == "walk" &&
            !snapshot.title.lowercased().contains("walk") &&
            !snapshot.title.lowercased().contains("relaxed") &&
            !snapshot.title.lowercased().contains("movement") {
            findings.append(finding(.activityMismatch, .warn, .copyQuality, "Active walk without walk/movement title"))
        }
        if context.hasCompletedWorkout && context.activity == .easyWalkCompleted &&
            (snapshot.title.lowercased().contains("going fine") || snapshot.title.lowercased().contains("quiet day")) {
            findings.append(finding(.activityMismatch, .warn, .copyQuality, "Completed walk ignored by title"))
        }
        return findings
    }

    private static func syncEdgeCaseFindings(
        story: CoachFinalStory,
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot,
        context: CoachNarrativeMatrixContext
    ) -> [CoachNarrativeContractFinding] {
        guard [.syncedWalkNoPlanMatch, .syncedWalkFutureCoffeeCandidate, .syncedWalkFuturePlannedWalk].contains(context.activity) else {
            return []
        }
        var findings: [CoachNarrativeContractFinding] = []
        let visible = visibleText(snapshot).lowercased()

        if visible.contains("coffee") && (visible.contains("prepare") || visible.contains("workout prep")) {
            findings.append(finding(
                .syncEdgeCaseViolation, .fail, .contextSelectionBug,
                "Coffee treated as fitness prep context"
            ))
        }
        if story.primaryFocus == .recoveryNeeded || story.primaryFocus == .prepareForActivity {
            if context.activity == .syncedWalkNoPlanMatch && context.recoveryBand == .good {
                findings.append(finding(
                    .syncEdgeCaseViolation, .fail, .stateOwnerBug,
                    "Synced easy walk escalated to \(story.primaryFocus)"
                ))
            }
        }
        if context.activity == .syncedWalkFutureCoffeeCandidate && visible.contains("next up: coffee") {
            findings.append(finding(
                .syncEdgeCaseViolation, .fail, .contextSelectionBug,
                "Future Coffee surfaced as next workout"
            ))
        }
        if context.activity == .syncedWalkNoPlanMatch &&
            !visible.contains("walk") && !visible.contains("logged") && !visible.contains("calm") &&
            !visible.contains("plan starts") {
            findings.append(finding(
                .syncEdgeCaseViolation, .warn, .copyQuality,
                "Synced walk not acknowledged at all"
            ))
        }
        return findings
    }

    private static func voiceFindings(
        render: CoachFinalStoryRenderModel,
        snapshot: CoachNarrativeFullStorySnapshot
    ) -> [CoachNarrativeContractFinding] {
        let visible = visibleText(snapshot).lowercased()
        var findings: [CoachNarrativeContractFinding] = []
        let robotic = [
            "stay aware", "performance limiter", "recovery optimization", "energy systems",
            "supports this story", "is part of the decision", "maintain sustainable pacing",
            "dashboard", "metric threshold"
        ]
        for phrase in robotic where visible.contains(phrase) {
            findings.append(finding(.roboticCopy, .fail, .copyQuality, phrase))
        }
        let generic = ["stay with the plan", "keep things steady", "nothing useful to change", "stay consistent"]
        for phrase in generic where visible.contains(phrase) {
            findings.append(finding(.roboticCopy, .warn, .copyQuality, phrase))
        }
        return findings
    }

    private static func sectionPresenceFindings(
        render: CoachFinalStoryRenderModel,
        story: CoachFinalStory
    ) -> [CoachNarrativeContractFinding] {
        var findings: [CoachNarrativeContractFinding] = []
        if render.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            findings.append(finding(.emptyVisibleSection, .fail, .contextSelectionBug, "title is empty"))
        }
        if render.primaryRecommendation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            findings.append(finding(.emptyVisibleSection, .fail, .contextSelectionBug, "recommendation is empty"))
        }
        if story.owner != .postActivityRecovery && render.whyRows.isEmpty {
            findings.append(finding(.emptyVisibleSection, .warn, .copyQuality, "why section empty"))
        }
        return findings
    }

    // MARK: - Helpers

    private static func finding(
        _ flag: CoachNarrativeContractFlag,
        _ severity: CoachNarrativeAuditSeverity,
        _ issueClass: CoachNarrativeIssueClass,
        _ detail: String
    ) -> CoachNarrativeContractFinding {
        CoachNarrativeContractFinding(flag: flag, severity: severity, issueClass: issueClass, detail: detail)
    }

    private static func visibleText(_ snapshot: CoachNarrativeFullStorySnapshot) -> String {
        ([
            snapshot.title, snapshot.read, snapshot.recommendation, snapshot.careful,
            snapshot.todayTitle, snapshot.todaySubtitle
        ] + snapshot.why + snapshot.supportItems).joined(separator: " ")
    }

    private static func normalizedCopy(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func deduped(_ findings: [CoachNarrativeContractFinding]) -> [CoachNarrativeContractFinding] {
        var seen = Set<String>()
        return findings.filter { finding in
            let key = "\(finding.flag.rawValue)|\(finding.detail)"
            return seen.insert(key).inserted
        }
    }
}

private extension CoachNarrativeMatrixContext {
    var groupLabel: String {
        switch nutrition {
        case .emptyAfternoon: return "I. Nutrition-led support"
        default: return ""
        }
    }
}
