import Foundation
@testable import WeekFit

enum CoachNarrativeAuditSeverity: String, Codable {
    case pass
    case warn
    case fail
}

enum CoachNarrativeAuditFlag: String, CaseIterable {
    case titleMismatch = "Title does not fit the scenario state"
    case recommendationMismatch = "Recommendation does not fit the scenario state"
    case duplicateInformation = "Duplicate information across sections"
    case contradiction = "Contradictory guidance"
    case workoutLanguageWithoutContext = "Workout language without workout context"
    case recoveryLanguageWithoutEvidence = "Recovery language without recovery evidence"
    case roboticCopy = "Robotic or template-like copy"
    case repetitiveCopy = "Repetitive phrasing"
    case genericCopy = "Generic filler copy"
    case inconsistentCopy = "Inconsistent tone or facts"
    case emptyVisibleSection = "Expected visible section is empty"
    case rawLocalizationKey = "Raw localization key leaked"
}

struct CoachNarrativeStorySnapshot: Equatable {
    let owner: String
    let priority: String
    let badge: String
    let title: String
    let read: String
    let recommendation: String
    let careful: String
    let why: [String]
    let supportReasons: [String]
}

struct CoachNarrativeAuditFinding: Equatable {
    let flag: CoachNarrativeAuditFlag
    let severity: CoachNarrativeAuditSeverity
    let detail: String
}

struct CoachNarrativeScenarioExpectation {
    enum RecoveryTier {
        case high
        case moderate
        case low
        case depleted
    }

    enum SleepTier {
        case excellent
        case adequate
        case deficit
        case fragmented
    }

    let hasWorkoutContext: Bool
    let hasActiveSession: Bool
    let hasCompletedWorkout: Bool
    let recoveryTier: RecoveryTier
    let sleepTier: SleepTier
    let hasHydrationGap: Bool
    let hasFuelGap: Bool
    let hasTomorrowDemand: Bool
    let allowedOwners: [CoachFinalStoryOwner]
}

struct CoachNarrativeAuditResult: Equatable {
    let snapshot: CoachNarrativeStorySnapshot
    let findings: [CoachNarrativeAuditFinding]

    var severity: CoachNarrativeAuditSeverity {
        if findings.contains(where: { $0.severity == .fail }) { return .fail }
        if findings.contains(where: { $0.severity == .warn }) { return .warn }
        return .pass
    }

    var isWeakStory: Bool {
        severity != .pass
    }
}

enum CoachNarrativeAuditor {
    static func snapshot(from state: CoachState) -> CoachNarrativeStorySnapshot? {
        guard let story = state.finalStory else { return nil }
        let render = CoachFinalStoryRenderModel(story: story)
        return CoachNarrativeStorySnapshot(
            owner: story.owner.rawValue,
            priority: String(describing: story.primaryFocus),
            badge: render.badge,
            title: render.title,
            read: render.displaySubtitle.isEmpty ? render.subtitle : render.displaySubtitle,
            recommendation: render.primaryRecommendation,
            careful: render.displayAvoid.isEmpty ? render.avoidRecommendation : render.displayAvoid,
            why: render.whyRows.map(\.title),
            supportReasons: render.supportSignals.map { "\($0.kind.rawValue): \($0.title)" }
        )
    }

    static func audit(
        state: CoachState,
        expectation: CoachNarrativeScenarioExpectation
    ) -> CoachNarrativeAuditResult? {
        guard let story = state.finalStory,
              let snapshot = snapshot(from: state) else {
            return nil
        }
        let render = CoachFinalStoryRenderModel(story: story)
        var findings: [CoachNarrativeAuditFinding] = []

        findings += localizationFindings(in: snapshot)
        findings += ownerFindings(story: story, render: render, expectation: expectation)
        findings += sectionPresenceFindings(render: render, story: story)
        findings += duplicateFindings(render: render, story: story)
        findings += workoutContextFindings(story: story, render: render, expectation: expectation)
        findings += recoveryContextFindings(render: render, expectation: expectation)
        findings += contradictionFindings(render: render, expectation: expectation)
        findings += titleFitFindings(render: render, story: story, expectation: expectation)
        findings += recommendationFitFindings(render: render, story: story, expectation: expectation)
        findings += voiceFindings(render: render, story: story)

        return CoachNarrativeAuditResult(snapshot: snapshot, findings: findings)
    }

    static func formatReport(
        scenarioID: Int,
        group: String,
        name: String,
        context: String,
        result: CoachNarrativeAuditResult
    ) -> String {
        var lines: [String] = []
        lines.append("### \(scenarioID). \(name)")
        lines.append("")
        lines.append("**Group:** \(group)")
        lines.append("**Context:** \(context)")
        lines.append("**Verdict:** \(result.severity.rawValue.uppercased())")
        lines.append("")
        lines.append("| Field | Value |")
        lines.append("| --- | --- |")
        lines.append("| owner | \(escape(result.snapshot.owner)) |")
        lines.append("| priority | \(escape(result.snapshot.priority)) |")
        lines.append("| badge | \(escape(result.snapshot.badge)) |")
        lines.append("| title | \(escape(result.snapshot.title)) |")
        lines.append("| read | \(escape(result.snapshot.read)) |")
        lines.append("| recommendation | \(escape(result.snapshot.recommendation)) |")
        lines.append("| careful | \(escape(result.snapshot.careful)) |")
        lines.append("| why | \(escape(result.snapshot.why.joined(separator: " · "))) |")
        lines.append("| support reasons | \(escape(result.snapshot.supportReasons.joined(separator: " · "))) |")
        lines.append("")

        if result.findings.isEmpty {
            lines.append("**Findings:** none")
        } else {
            lines.append("**Findings:**")
            for finding in result.findings {
                lines.append("- [\(finding.severity.rawValue.uppercased())] \(finding.flag.rawValue): \(finding.detail)")
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    static func formatSummary(
        results: [(id: Int, group: String, name: String, result: CoachNarrativeAuditResult)]
    ) -> String {
        let weak = results.filter { $0.result.isWeakStory }
        let fails = weak.filter { $0.result.severity == .fail }
        let warns = weak.filter { $0.result.severity == .warn }

        var lines: [String] = []
        lines.append("# Coach Narrative Validation Audit")
        lines.append("")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")
        lines.append("## Summary")
        lines.append("")
        lines.append("- Scenarios run: \(results.count)")
        lines.append("- Clean stories: \(results.count - weak.count)")
        lines.append("- Weak stories: \(weak.count) (\(fails.count) fail, \(warns.count) warn)")
        lines.append("")

        if !weak.isEmpty {
            lines.append("## Weak Stories")
            lines.append("")
            for item in weak.sorted(by: { $0.id < $1.id }) {
                let flags = item.result.findings.map(\.flag.rawValue).joined(separator: "; ")
                lines.append("- **\(item.id). \(item.name)** [\(item.result.severity.rawValue)]: \(flags)")
            }
            lines.append("")
        }

        let grouped = Dictionary(grouping: results, by: \.group)
        for group in grouped.keys.sorted() {
            lines.append("## \(group)")
            lines.append("")
            for item in grouped[group]?.sorted(by: { $0.id < $1.id }) ?? [] {
                lines.append(formatReport(
                    scenarioID: item.id,
                    group: item.group,
                    name: item.name,
                    context: "",
                    result: item.result
                ))
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func localizationFindings(in snapshot: CoachNarrativeStorySnapshot) -> [CoachNarrativeAuditFinding] {
        let all = [
            snapshot.badge,
            snapshot.title,
            snapshot.read,
            snapshot.recommendation,
            snapshot.careful
        ] + snapshot.why + snapshot.supportReasons

        return all.compactMap { text in
            guard text.contains("coach.final.") else { return nil }
            return CoachNarrativeAuditFinding(
                flag: .rawLocalizationKey,
                severity: .fail,
                detail: text
            )
        }
    }

    private static func ownerFindings(
        story: CoachFinalStory,
        render: CoachFinalStoryRenderModel,
        expectation: CoachNarrativeScenarioExpectation
    ) -> [CoachNarrativeAuditFinding] {
        guard !expectation.allowedOwners.contains(story.owner) else { return [] }
        if allowsReadinessOwnerForHydrationSupport(
            story: story,
            render: render,
            expectation: expectation
        ) {
            return []
        }
        return [
            CoachNarrativeAuditFinding(
                flag: .inconsistentCopy,
                severity: .warn,
                detail: "owner=\(story.owner.rawValue), expected one of \(expectation.allowedOwners.map(\.rawValue).joined(separator: ", "))"
            )
        ]
    }

    private static func allowsReadinessOwnerForHydrationSupport(
        story: CoachFinalStory,
        render: CoachFinalStoryRenderModel,
        expectation: CoachNarrativeScenarioExpectation
    ) -> Bool {
        guard expectation.hasHydrationGap,
              story.owner == .readiness,
              story.primaryFocus == .trainingReadinessWarning else {
            return false
        }
        return hydrationEvidenceVisibleInSupportSections(render: render)
    }

    private static func hydrationEvidenceVisibleInSupportSections(
        render: CoachFinalStoryRenderModel
    ) -> Bool {
        let visible = (
            [
                render.primaryRecommendation,
                render.displayAvoid.isEmpty ? render.avoidRecommendation : render.displayAvoid
            ] + render.whyRows.map(\.title)
        )
            .joined(separator: " ")
            .lowercased()
        let hydrationPhrases = ["water", "hydration", "drink", "fluid", "sip", "dehydrated", "low on water"]
        return hydrationPhrases.contains(where: { visible.contains($0) })
    }

    private static func encouragesIntensity(_ text: String) -> Bool {
        let permissive = ["push intensity", "go harder", "turn it up", "train normally"]
        if permissive.contains(where: { text.contains($0) }) {
            return true
        }
        guard text.contains("add intensity") else {
            return false
        }
        let negated = [
            "do not add intensity",
            "don't add intensity",
            "avoid adding intensity",
            "not add intensity"
        ]
        return !negated.contains(where: { text.contains($0) })
    }

    private static func sectionPresenceFindings(
        render: CoachFinalStoryRenderModel,
        story: CoachFinalStory
    ) -> [CoachNarrativeAuditFinding] {
        var findings: [CoachNarrativeAuditFinding] = []
        let required = [
            ("title", render.title),
            ("badge", render.badge),
            ("recommendation", render.primaryRecommendation)
        ]
        for (label, value) in required where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            findings.append(
                CoachNarrativeAuditFinding(
                    flag: .emptyVisibleSection,
                    severity: .fail,
                    detail: "\(label) is empty for owner=\(story.owner.rawValue)"
                )
            )
        }

        if story.owner != .postActivityRecovery && render.whyRows.isEmpty {
            findings.append(
                CoachNarrativeAuditFinding(
                    flag: .emptyVisibleSection,
                    severity: .warn,
                    detail: "Why section is empty outside post-activity recovery"
                )
            )
        }

        if story.owner == .postActivityRecovery && render.displaySubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            findings.append(
                CoachNarrativeAuditFinding(
                    flag: .emptyVisibleSection,
                    severity: .fail,
                    detail: "Post-workout story should show My Read"
                )
            )
        }

        return findings
    }

    private static func duplicateFindings(
        render: CoachFinalStoryRenderModel,
        story: CoachFinalStory
    ) -> [CoachNarrativeAuditFinding] {
        struct Section {
            let name: String
            let text: String
        }

        let sections = [
            Section(name: "title", text: render.title),
            Section(name: "read", text: render.displaySubtitle.isEmpty ? render.subtitle : render.displaySubtitle),
            Section(name: "recommendation", text: render.primaryRecommendation),
            Section(name: "careful", text: render.displayAvoid.isEmpty ? render.avoidRecommendation : render.displayAvoid)
        ] + render.whyRows.map { Section(name: "why", text: $0.title) }
            + render.supportSignals.map { Section(name: "support", text: $0.title) }

        var findings: [CoachNarrativeAuditFinding] = []
        let normalizedSections = sections
            .map { (name: $0.name, normalized: normalizedCopy($0.text)) }
            .filter { !$0.normalized.isEmpty }

        for index in normalizedSections.indices {
            let first = normalizedSections[index]
            guard first.normalized.count >= 10 else { continue }
            for second in normalizedSections.dropFirst(index + 1) where first.name != second.name {
                guard second.normalized.count >= 10 else { continue }
                if first.normalized == second.normalized ||
                    first.normalized.contains(second.normalized) ||
                    second.normalized.contains(first.normalized) {
                    findings.append(
                        CoachNarrativeAuditFinding(
                            flag: .duplicateInformation,
                            severity: .fail,
                            detail: "\(first.name) repeats \(second.name)"
                        )
                    )
                }
            }
        }

        let heroTriad = [
            render.subtitle,
            render.primaryRecommendation,
            render.avoidRecommendation
        ].map(normalizedCopy).filter { !$0.isEmpty }
        if Set(heroTriad).count != heroTriad.count {
            findings.append(
                CoachNarrativeAuditFinding(
                    flag: .duplicateInformation,
                    severity: .fail,
                    detail: "Hero triad repeats itself"
                )
            )
        }

        if findings.isEmpty,
           story.supportActions.map({ normalizedCopy($0.title) }).filter({ !$0.isEmpty }).count !=
            Set(story.supportActions.map { normalizedCopy($0.title) }).count {
            findings.append(
                CoachNarrativeAuditFinding(
                    flag: .repetitiveCopy,
                    severity: .warn,
                    detail: "Support actions repeat titles"
                )
            )
        }

        return findings
    }

    private static func workoutContextFindings(
        story: CoachFinalStory,
        render: CoachFinalStoryRenderModel,
        expectation: CoachNarrativeScenarioExpectation
    ) -> [CoachNarrativeAuditFinding] {
        guard !expectation.hasWorkoutContext && !expectation.hasActiveSession && !expectation.hasCompletedWorkout else {
            return []
        }

        let workoutPhrases = [
            "warm up", "warm-up", "prepare for training", "prepare for workout",
            "next activity", "next planned effort", "session is active", "first 15 minutes",
            "workout readiness", "before training", "before the session", "during the session",
            "finish the session", "control the session", "coming soon"
        ]
        let visible = visibleText(render: render, story: story).lowercased()
        let hits = workoutPhrases.filter { visible.contains($0) }
        guard !hits.isEmpty else { return [] }

        return [
            CoachNarrativeAuditFinding(
                flag: .workoutLanguageWithoutContext,
                severity: .fail,
                detail: "Found workout phrasing without activity context: \(hits.joined(separator: ", "))"
            )
        ]
    }

    private static func recoveryContextFindings(
        render: CoachFinalStoryRenderModel,
        expectation: CoachNarrativeScenarioExpectation
    ) -> [CoachNarrativeAuditFinding] {
        guard expectation.recoveryTier == .high,
              expectation.sleepTier == .excellent || expectation.sleepTier == .adequate,
              !expectation.hasCompletedWorkout else {
            return []
        }

        let recoveryPhrases = [
            "recovery day", "protect recovery", "rest day", "go easy today",
            "body still rebuilding", "still recovering", "recovery remains important",
            "take it easy today", "easy day"
        ]
        let visible = [
            render.title,
            render.primaryRecommendation,
            render.displaySubtitle,
            render.displayAvoid
        ].joined(separator: " ").lowercased()

        let hits = recoveryPhrases.filter { visible.contains($0) }
        guard !hits.isEmpty else { return [] }

        return [
            CoachNarrativeAuditFinding(
                flag: .recoveryLanguageWithoutEvidence,
                severity: .warn,
                detail: "Recovery framing on a high-readiness calm day: \(hits.joined(separator: ", "))"
            )
        ]
    }

    private static func contradictionFindings(
        render: CoachFinalStoryRenderModel,
        expectation: CoachNarrativeScenarioExpectation
    ) -> [CoachNarrativeAuditFinding] {
        var findings: [CoachNarrativeAuditFinding] = []
        let visible = [
            render.title,
            render.primaryRecommendation,
            render.displayAvoid,
            render.displaySubtitle
        ].joined(separator: " ").lowercased()

        if expectation.recoveryTier == .low || expectation.recoveryTier == .depleted {
            if encouragesIntensity(visible) {
                findings.append(
                    CoachNarrativeAuditFinding(
                        flag: .contradiction,
                        severity: .fail,
                        detail: "Encourages intensity despite low recovery"
                    )
                )
            }
        }

        if !expectation.hasWorkoutContext && !expectation.hasActiveSession {
            let prepPhrases = ["prepare for training", "before training", "before the ride", "before the run"]
            if prepPhrases.contains(where: { visible.contains($0) }) {
                findings.append(
                    CoachNarrativeAuditFinding(
                        flag: .contradiction,
                        severity: .fail,
                        detail: "Prep language without planned workout"
                    )
                )
            }
        }

        let rec = render.primaryRecommendation.lowercased()
        let careful = (render.displayAvoid.isEmpty ? render.avoidRecommendation : render.displayAvoid).lowercased()
        if !rec.isEmpty, !careful.isEmpty, normalizedCopy(rec) == normalizedCopy(careful) {
            findings.append(
                CoachNarrativeAuditFinding(
                    flag: .contradiction,
                    severity: .fail,
                    detail: "Recommendation and careful say the same thing"
                )
            )
        }

        return findings
    }

    private static func titleFitFindings(
        render: CoachFinalStoryRenderModel,
        story: CoachFinalStory,
        expectation: CoachNarrativeScenarioExpectation
    ) -> [CoachNarrativeAuditFinding] {
        let title = render.title.lowercased()

        if expectation.hasActiveSession {
            let activeHints = [
                "session", "active", "underway", "now", "minutes", "pace", "settle", "warm",
                "hold", "steady", "rhythm", "controlled", "strength", "relaxed", "walk", "keep"
            ]
            if !activeHints.contains(where: { title.contains($0) }) &&
                story.owner != .hydrationExecution &&
                story.owner != .fuelingDuringActivity &&
                story.owner != .activeActivity {
                return [
                    CoachNarrativeAuditFinding(
                        flag: .titleMismatch,
                        severity: .warn,
                        detail: "Active session title does not signal in-session coaching"
                    )
                ]
            }
        }

        if expectation.hasCompletedWorkout && story.owner == .postActivityRecovery {
            let postHints = ["done", "finished", "after", "recovery", "session", "ride", "run", "walk", "workout", "strength"]
            if !postHints.contains(where: { title.contains($0) }) {
                return [
                    CoachNarrativeAuditFinding(
                        flag: .titleMismatch,
                        severity: .warn,
                        detail: "Post-workout title does not acknowledge completed load"
                    )
                ]
            }
        }

        if expectation.hasHydrationGap && (story.owner == .hydration || story.primaryFocus == .hydrationBehind) {
            let hydrationHints = ["water", "hydration", "drink", "fluid", "sip"]
            if !hydrationHints.contains(where: { title.contains($0) }) {
                return [
                    CoachNarrativeAuditFinding(
                        flag: .titleMismatch,
                        severity: .warn,
                        detail: "Hydration-owned story title does not mention fluids"
                    )
                ]
            }
        }

        if expectation.hasFuelGap && (story.owner == .fuel || story.primaryFocus == .fuelBehind) {
            let fuelHints = ["fuel", "food", "eat", "carb", "snack", "meal", "nutrition"]
            if !fuelHints.contains(where: { title.contains($0) }) {
                return [
                    CoachNarrativeAuditFinding(
                        flag: .titleMismatch,
                        severity: .warn,
                        detail: "Fuel-owned story title does not mention nutrition"
                    )
                ]
            }
        }

        return []
    }

    private static func recommendationFitFindings(
        render: CoachFinalStoryRenderModel,
        story: CoachFinalStory,
        expectation: CoachNarrativeScenarioExpectation
    ) -> [CoachNarrativeAuditFinding] {
        let recommendation = render.primaryRecommendation.lowercased()

        if expectation.hasActiveSession && story.owner == .pacingExecution {
            let pacingHints = ["easy", "settle", "warm", "first", "minutes", "pace", "control"]
            if !pacingHints.contains(where: { recommendation.contains($0) }) {
                return [
                    CoachNarrativeAuditFinding(
                        flag: .recommendationMismatch,
                        severity: .warn,
                        detail: "Early active-session recommendation lacks pacing guidance"
                    )
                ]
            }
        }

        if expectation.hasTomorrowDemand && story.owner == .tomorrowProtection {
            let tomorrowHints = ["tomorrow", "sleep", "tonight", "evening", "protect", "plan"]
            if !tomorrowHints.contains(where: { recommendation.contains($0) }) {
                return [
                    CoachNarrativeAuditFinding(
                        flag: .recommendationMismatch,
                        severity: .warn,
                        detail: "Tomorrow-protection recommendation does not protect the next day"
                    )
                ]
            }
        }

        if expectation.hasHydrationGap && story.owner == .hydration {
            let hydrationHints = ["water", "drink", "hydration", "sip", "fluid"]
            if !hydrationHints.contains(where: { recommendation.contains($0) }) {
                return [
                    CoachNarrativeAuditFinding(
                        flag: .recommendationMismatch,
                        severity: .warn,
                        detail: "Hydration recommendation does not mention drinking"
                    )
                ]
            }
        }

        return []
    }

    private static func voiceFindings(
        render: CoachFinalStoryRenderModel,
        story: CoachFinalStory
    ) -> [CoachNarrativeAuditFinding] {
        var findings: [CoachNarrativeAuditFinding] = []
        let visible = visibleText(render: render, story: story).lowercased()

        let roboticPhrases = [
            "stay aware",
            "finish with reserve",
            "use conversational effort",
            "do not increase intensity yet",
            "no extra fix is needed",
            "control effort and finish with reserve",
            "training adaptation",
            "energy systems",
            "performance limiter",
            "recovery optimization",
            "maintain sustainable pacing",
            "supports this story",
            "is part of the decision",
            "rebuild the basics"
        ]
        for phrase in roboticPhrases where visible.contains(phrase) {
            findings.append(
                CoachNarrativeAuditFinding(
                    flag: .roboticCopy,
                    severity: .fail,
                    detail: phrase
                )
            )
        }

        let genericPhrases = [
            "stay with the plan",
            "keep things steady",
            "nothing useful to change",
            "no useful change",
            "stay consistent"
        ]
        for phrase in genericPhrases where visible.contains(phrase) {
            findings.append(
                CoachNarrativeAuditFinding(
                    flag: .genericCopy,
                    severity: .warn,
                    detail: phrase
                )
            )
        }

        for row in render.whyRows {
            let title = row.title.lowercased()
            if title.contains("%") || title.contains("kcal") {
                findings.append(
                    CoachNarrativeAuditFinding(
                        flag: .roboticCopy,
                        severity: .fail,
                        detail: "Why row exposes raw metrics: \(row.title)"
                    )
                )
            }
        }

        if render.title.count < 8 || render.primaryRecommendation.count < 12 {
            findings.append(
                CoachNarrativeAuditFinding(
                    flag: .genericCopy,
                    severity: .warn,
                    detail: "Hero copy is unusually short"
                )
            )
        }

        if story.owner == .stableOverview || story.owner == .readiness {
            let title = render.title.lowercased()
            if title.contains("critical") || title.contains("urgent") || title.contains("danger") {
                findings.append(
                    CoachNarrativeAuditFinding(
                        flag: .inconsistentCopy,
                        severity: .warn,
                        detail: "Alarmist title on a stable overview owner"
                    )
                )
            }
        }

        return findings
    }

    private static func visibleText(render: CoachFinalStoryRenderModel, story: CoachFinalStory) -> String {
        ([
            render.title,
            render.subtitle,
            render.displaySubtitle,
            render.primaryRecommendation,
            render.avoidRecommendation,
            render.displayAvoid,
            story.whatHappened.resolved,
            story.whatMattersNow.resolved,
            story.whatToDoNext.resolved,
            story.whatToAvoid.resolved
        ] + render.whyRows.map(\.title)
            + render.supportSignals.map(\.title)
            + render.supportActions.flatMap { [$0.title, $0.subtitle] })
            .joined(separator: " ")
    }

    private static func normalizedCopy(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
