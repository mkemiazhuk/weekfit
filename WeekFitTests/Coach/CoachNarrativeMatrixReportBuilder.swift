import Foundation

enum CoachNarrativeMatrixReportBuilder {

    static let reportPath = "/tmp/WeekFitCoachNarrativePhase3Audit.md"

    static func buildReport(rows: [CoachNarrativeMatrixAuditRow]) -> String {
        let fails = rows.filter { $0.result.severity == .fail }
        let warns = rows.filter { $0.result.severity == .warn }
        let passes = rows.filter { $0.result.severity == .pass }
        let p0 = rows.flatMap(\.result.p0Findings)
        let p1 = rows.flatMap(\.result.p1Findings)
        let duplicateClusters = CoachNarrativeContractAuditor.classifyDuplicateClusters(rows: rows)
        let contradictionClusters = clusterFindings(rows: rows, severity: .fail, flags: [
            .internalCopyContradiction, .todayCoachMisalignment, .recoverySeverityViolation
        ])

        var lines: [String] = []
        lines.append("# Coach Narrative Phase 3 Audit")
        lines.append("")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")
        lines.append("## Executive Summary")
        lines.append("")
        lines.append("- Scenarios run: \(rows.count)")
        lines.append("- Pass: \(passes.count)")
        lines.append("- Warn: \(warns.count)")
        lines.append("- Fail: \(fails.count)")
        lines.append("- P0 blockers: \(Set(p0.map(\.detail)).count) unique findings across \(fails.count) scenarios")
        lines.append("- P1 copy quality issues: \(Set(p1.map(\.detail)).count) unique findings")
        lines.append("")

        if !fails.isEmpty {
            lines.append("## P0 Blockers")
            lines.append("")
            for item in fails.sorted(by: { $0.scenario.id < $1.scenario.id }) {
                let flags = item.result.findings.filter { $0.severity == .fail }.map(\.flag.rawValue).joined(separator: "; ")
                lines.append("- **\(item.scenario.id). \(item.scenario.name)** [\(item.scenario.group.rawValue)]: \(flags)")
            }
            lines.append("")
        }

        if !warns.isEmpty {
            lines.append("## P1 Copy Quality / Context Issues")
            lines.append("")
            for item in warns.prefix(25) {
                let flags = item.result.findings.filter { $0.severity == .warn }.map(\.flag.rawValue).joined(separator: "; ")
                lines.append("- **\(item.scenario.id). \(item.scenario.name)**: \(flags)")
            }
            if warns.count > 25 {
                lines.append("- …and \(warns.count - 25) more warned scenarios")
            }
            lines.append("")
        }

        lines.append("## P2 Polish Items")
        lines.append("")
        let polish = rows.flatMap { row in
            row.result.findings.filter {
                $0.severity == .warn &&
                ($0.flag == .rawMetricRepetition || $0.flag == .roboticCopy || $0.flag == .duplicateTemplate)
            }.map { (row.scenario.id, $0) }
        }
        if polish.isEmpty {
            lines.append("- None flagged beyond P1.")
        } else {
            for (id, finding) in polish.prefix(20) {
                lines.append("- Scenario \(id): \(finding.flag.rawValue) — \(finding.detail)")
            }
        }
        lines.append("")

        if !contradictionClusters.isEmpty {
            lines.append("## Contradiction Clusters")
            lines.append("")
            for cluster in contradictionClusters.prefix(10) {
                lines.append("- **\(cluster.flag.rawValue)** (\(cluster.scenarioIDs.count) scenarios): \(cluster.sampleDetail)")
            }
            lines.append("")
        }

        if !duplicateClusters.isEmpty {
            lines.append("## Duplicate Copy Clusters")
            lines.append("")
            for cluster in duplicateClusters.prefix(15) {
                lines.append("- \"\(cluster.text)\" reused in scenarios \(cluster.scenarioIDs.map(String.init).joined(separator: ", ")) across groups: \(cluster.groups.joined(separator: ", "))")
            }
            lines.append("")
        }

        lines.append("## Scenario Table")
        lines.append("")
        lines.append("| ID | Group | Verdict | Owner | Badge | Title |")
        lines.append("| --- | --- | --- | --- | --- | --- |")
        for row in rows.sorted(by: { $0.scenario.id < $1.scenario.id }) {
            let snap = row.result.snapshot
            lines.append("| \(row.scenario.id) | \(escape(row.scenario.group.rawValue)) | \(row.result.severity.rawValue.uppercased()) | \(escape(snap.owner)) | \(escape(snap.badge)) | \(escape(snap.title)) |")
        }
        lines.append("")

        lines.append("## Full Story Dump")
        lines.append("")
        for row in rows.sorted(by: { $0.scenario.id < $1.scenario.id }) {
            lines.append(formatScenario(row))
        }

        return lines.joined(separator: "\n")
    }

    static func writeReport(_ report: String) {
        let urls = [
            URL(fileURLWithPath: reportPath),
            URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("WeekFitCoachNarrativePhase3Audit.md")
        ]
        for url in urls {
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func encodeRows(_ rows: [CoachNarrativeMatrixAuditRow]) -> Data? {
        let payload: [[String: Any]] = rows.map { row in
            [
                "id": row.scenario.id,
                "group": row.scenario.group.rawValue,
                "name": row.scenario.name,
                "inputSummary": row.scenario.inputSummary,
                "intent": row.scenario.intent,
                "runBatch": row.scenario.runBatch.rawValue,
                "snapshot": snapshotPayload(row.result.snapshot),
                "findings": row.result.findings.map { finding in
                    [
                        "flag": finding.flag.rawValue,
                        "severity": finding.severity.rawValue,
                        "issueClass": finding.issueClass.rawValue,
                        "detail": finding.detail
                    ]
                }
            ]
        }
        guard JSONSerialization.isValidJSONObject(payload) else { return nil }
        return try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
    }

    static func decodeRows(from data: Data, scenarios: [CoachNarrativeMatrixScenario]) -> [CoachNarrativeMatrixAuditRow] {
        let lookup = Dictionary(uniqueKeysWithValues: scenarios.map { ($0.id, $0) })
        let raw = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        return raw.compactMap { entry in
            guard let id = entry["id"] as? Int,
                  let scenario = lookup[id],
                  let snapshotRaw = entry["snapshot"] as? [String: Any],
                  let findingsRaw = entry["findings"] as? [[String: Any]] else {
                return nil
            }
            let snapshot = decodeSnapshot(snapshotRaw)
            let findings = findingsRaw.compactMap(decodeFinding)
            return CoachNarrativeMatrixAuditRow(
                scenario: scenario,
                result: CoachNarrativeContractAuditResult(snapshot: snapshot, findings: findings)
            )
        }
    }

    private static func formatScenario(_ row: CoachNarrativeMatrixAuditRow) -> String {
        let snap = row.result.snapshot
        var lines: [String] = []
        lines.append("### \(row.scenario.id). \(row.scenario.name)")
        lines.append("")
        lines.append("**Group:** \(row.scenario.group.rawValue)")
        lines.append("**Input:** \(row.scenario.inputSummary)")
        lines.append("**Intent:** \(row.scenario.intent)")
        lines.append("**Verdict:** \(row.result.severity.rawValue.uppercased())")
        lines.append("")
        lines.append("| Field | Value |")
        lines.append("| --- | --- |")
        lines.append("| phase | \(escape(snap.phase)) |")
        lines.append("| priority | \(escape(snap.priority)) |")
        lines.append("| owner | \(escape(snap.owner)) |")
        lines.append("| badge | \(escape(snap.badge)) |")
        lines.append("| title | \(escape(snap.title)) |")
        lines.append("| read | \(escape(snap.read)) |")
        lines.append("| recommendation | \(escape(snap.recommendation)) |")
        lines.append("| careful | \(escape(snap.careful)) |")
        lines.append("| why | \(escape(snap.why.joined(separator: " · "))) |")
        lines.append("| support | \(escape(snap.supportItems.joined(separator: " · "))) |")
        lines.append("| Today title | \(escape(snap.todayTitle)) |")
        lines.append("| Today subtitle | \(escape(snap.todaySubtitle)) |")
        lines.append("| Coach title | \(escape(snap.coachTitle)) |")
        lines.append("| Coach read | \(escape(snap.coachRead)) |")
        lines.append("| Coach recommendation | \(escape(snap.coachRecommendation)) |")
        lines.append("| Coach careful | \(escape(snap.coachCareful)) |")
        lines.append("| Coach why | \(escape(snap.coachWhy.joined(separator: " · "))) |")
        lines.append("")
        if row.result.findings.isEmpty {
            lines.append("**Findings:** none")
        } else {
            lines.append("**Findings:**")
            for finding in row.result.findings {
                lines.append("- [\(finding.severity.rawValue.uppercased())] [\(finding.issueClass.rawValue)] \(finding.flag.rawValue): \(finding.detail)")
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func snapshotPayload(_ snapshot: CoachNarrativeFullStorySnapshot) -> [String: Any] {
        [
            "phase": snapshot.phase,
            "priority": snapshot.priority,
            "owner": snapshot.owner,
            "intent": snapshot.intent,
            "badge": snapshot.badge,
            "title": snapshot.title,
            "read": snapshot.read,
            "recommendation": snapshot.recommendation,
            "careful": snapshot.careful,
            "why": snapshot.why,
            "supportItems": snapshot.supportItems,
            "todayTitle": snapshot.todayTitle,
            "todaySubtitle": snapshot.todaySubtitle,
            "coachTitle": snapshot.coachTitle,
            "coachRead": snapshot.coachRead,
            "coachRecommendation": snapshot.coachRecommendation,
            "coachCareful": snapshot.coachCareful,
            "coachWhy": snapshot.coachWhy
        ]
    }

    private static func decodeSnapshot(_ raw: [String: Any]) -> CoachNarrativeFullStorySnapshot {
        CoachNarrativeFullStorySnapshot(
            phase: raw["phase"] as? String ?? "",
            priority: raw["priority"] as? String ?? "",
            owner: raw["owner"] as? String ?? "",
            intent: raw["intent"] as? String ?? "",
            badge: raw["badge"] as? String ?? "",
            title: raw["title"] as? String ?? "",
            read: raw["read"] as? String ?? "",
            recommendation: raw["recommendation"] as? String ?? "",
            careful: raw["careful"] as? String ?? "",
            why: raw["why"] as? [String] ?? [],
            supportItems: raw["supportItems"] as? [String] ?? [],
            todayTitle: raw["todayTitle"] as? String ?? "",
            todaySubtitle: raw["todaySubtitle"] as? String ?? "",
            coachTitle: raw["coachTitle"] as? String ?? "",
            coachRead: raw["coachRead"] as? String ?? "",
            coachRecommendation: raw["coachRecommendation"] as? String ?? "",
            coachCareful: raw["coachCareful"] as? String ?? "",
            coachWhy: raw["coachWhy"] as? [String] ?? []
        )
    }

    private static func decodeFinding(_ raw: [String: Any]) -> CoachNarrativeContractFinding? {
        guard let flagRaw = raw["flag"] as? String,
              let severityRaw = raw["severity"] as? String,
              let issueClassRaw = raw["issueClass"] as? String,
              let detail = raw["detail"] as? String,
              let flag = CoachNarrativeContractFlag.allCases.first(where: { $0.rawValue == flagRaw }),
              let severity = CoachNarrativeAuditSeverity(rawValue: severityRaw),
              let issueClass = CoachNarrativeIssueClass(rawValue: issueClassRaw) else {
            return nil
        }
        return CoachNarrativeContractFinding(flag: flag, severity: severity, issueClass: issueClass, detail: detail)
    }

    private static func clusterFindings(
        rows: [CoachNarrativeMatrixAuditRow],
        severity: CoachNarrativeAuditSeverity,
        flags: [CoachNarrativeContractFlag]
    ) -> [(flag: CoachNarrativeContractFlag, scenarioIDs: [Int], sampleDetail: String)] {
        var buckets: [CoachNarrativeContractFlag: (ids: [Int], detail: String)] = [:]
        for row in rows {
            for finding in row.result.findings where finding.severity == severity && flags.contains(finding.flag) {
                var bucket = buckets[finding.flag] ?? (ids: [], detail: finding.detail)
                bucket.ids.append(row.scenario.id)
                buckets[finding.flag] = bucket
            }
        }
        return buckets.map { flag, value in
            (flag: flag, scenarioIDs: value.ids.sorted(), sampleDetail: value.detail)
        }.sorted { $0.scenarioIDs.count > $1.scenarioIDs.count }
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
    }
}
