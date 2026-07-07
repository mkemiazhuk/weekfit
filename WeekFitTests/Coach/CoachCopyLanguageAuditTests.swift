import XCTest
@testable import WeekFit

final class CoachCopyLanguageAuditTests: XCTestCase {

    func testBaselinePacksHaveNoLanguageMixing() {
        var failures: [String] = []

        for scenario in CoachScenarioKey.allCases {
            let input = CoachCopyQualityTests.baselineInput(for: scenario)
            guard let pack = CoachCopyRegistry.resolve(input) else { continue }

            let report = CoachCopyLanguageAudit.audit(pack: pack)
            if !report.isClean {
                failures.append("\(scenario.rawValue): \(format(report))")
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testMorningBriefPacksHaveNoLanguageMixing() {
        let variants: [(String, CoachMorningBriefFacts)] = [
            ("good", CoachMorningBriefFactsBuilder.synthetic(
                dayReadiness: CoachDayReadiness(
                    recoveryPercent: 89,
                    sleepHours: 7.8,
                    recoveryBand: .good,
                    hadHeavyYesterday: false,
                    sleepIsLow: false
                )
            )),
            ("lowRecovery", CoachMorningBriefFactsBuilder.synthetic(
                dayReadiness: CoachDayReadiness(
                    recoveryPercent: 38,
                    sleepHours: 4.5,
                    recoveryBand: .low,
                    hadHeavyYesterday: true,
                    sleepIsLow: true
                )
            ))
        ]

        var failures: [String] = []

        for (label, facts) in variants {
            let pack = CoachMorningBriefCopyPolicy.morningReadinessPack(for: facts)
            let sections: [(String, CoachBilingualText)] = [
                ("assessment", pack.assessment),
                ("recommendation", pack.recommendation),
                ("avoid", pack.avoid),
                ("nextAction", pack.nextAction)
            ]

            for (section, bilingual) in sections {
                let findings = CoachCopyLanguageAudit.audit(bilingual: bilingual, section: section)
                if !findings.isEmpty {
                    failures.append("\(label).\(section): \(format(findings))")
                }
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testLimitedRecoveryOverlayHasNoLanguageMixing() {
        let input = CoachCopyQualityTests.baselineInput(for: .morningReadiness)
        let basePack = CoachCopyRegistry.resolve(input)!
        let pack = CoachLimitedRecoveryCopyPolicy.apply(to: basePack)
        let report = CoachCopyLanguageAudit.audit(pack: pack)

        XCTAssertTrue(report.isClean, format(report))
    }

    private func format(_ report: CoachCopyLanguageAudit.Report) -> String {
        report.findings.map { "\($0.section) [\($0.language)] \($0.reason)" }.joined(separator: "; ")
    }

    private func format(_ findings: [CoachCopyLanguageAudit.Finding]) -> String {
        findings.map { "\($0.section) [\($0.language)] \($0.reason)" }.joined(separator: "; ")
    }
}
