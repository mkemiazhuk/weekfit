#if DEBUG
import SwiftUI

/// Developer-only inspector focused on what Coach currently knows about the athlete.
struct CoachBeliefDebugView: View {

    let coachState: CoachState

    @State private var snapshot = CoachBeliefDebugInspector.Snapshot(
        beliefs: [],
        eventQueue: [],
        reflection: CoachBeliefDebugInspector.ReflectionState(
            pause: false,
            pauseReason: "",
            blockedBy: nil,
            nextUnspokenEventID: nil,
            nextUnspokenBeliefID: nil,
            reflectionOfferID: nil,
            reflectionOfferBeliefID: nil,
            isReflectionOfferDisplayed: false,
            noReflectionReason: nil
        ),
        understandingSummary: CoachBeliefSynthesisAudit.Result(
            dominantRecoveryDriver: .unknown,
            strongestEstablishedPattern: nil,
            strongestEmergingPattern: nil,
            conflictingPatterns: [],
            insufficientDomains: [],
            formsCoherentProfile: false,
            understandingConfidence: CoachBeliefSynthesisAudit.CoachUnderstandingConfidence(
                understandingConfidenceScore: 0,
                understandingConfidenceLabel: .low,
                understandingCoverageByDomain: CoachBeliefSynthesisAudit.DomainCoverageSnapshot(
                    sleep: 0,
                    trainingLoad: 0,
                    nutrition: 0
                ),
                diagnosticExplanation: ""
            ),
            diagnostics: []
        ),
        observationCount: 0,
        nutritionCoverage: CoachBeliefDebugInspector.ObservationNutritionCoverage(
            populatedCount: 0,
            missingCount: 0,
            latestDayKey: nil,
            latestNutritionStatus: "no observations"
        ),
        capturedAt: Date()
    )

    private var executiveSummary: CoachUnderstandingInspectorPresentation.ExecutiveSummary {
        CoachUnderstandingInspectorPresentation.executiveSummary(from: snapshot)
    }

    private var domainSummaries: [CoachUnderstandingInspectorPresentation.DomainSummary] {
        CoachUnderstandingInspectorPresentation.domainSummaries(from: snapshot)
    }

    var body: some View {
        List {
            coachUnderstandingSection
            domainSummariesSection
            individualBeliefsSection
            reflectionSection
            eventQueueSection
            dataContextSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Coach Understanding")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") {
                    refresh()
                }
            }
        }
        .onAppear {
            refresh()
        }
    }

    // MARK: - 1. Coach Understanding

    private var coachUnderstandingSection: some View {
        Section("Coach Understanding") {
            ForEach(executiveSummary.domainHeadlines, id: \.self) { headline in
                Label(headline, systemImage: headlineIcon(for: headline))
                    .font(.subheadline)
            }

            LabeledContent(
                "Overall confidence",
                value: "\(executiveSummary.confidencePercent)% (\(executiveSummary.confidenceLabel))"
            )
            LabeledContent("Dominant recovery driver", value: executiveSummary.dominantDriver)
            LabeledContent(
                "Coherent profile",
                value: executiveSummary.coherentProfile ? "yes" : "no"
            )

            if let established = executiveSummary.strongestEstablished {
                LabeledContent("Strongest established", value: established)
            }

            if let emerging = executiveSummary.strongestEmerging {
                LabeledContent("Strongest emerging", value: emerging)
            }

            if !executiveSummary.conflictSummaries.isEmpty {
                LabeledContent(
                    "Conflicts",
                    value: executiveSummary.conflictSummaries.joined(separator: "; ")
                )
            }

            Text(snapshot.understandingSummary.understandingConfidence.diagnosticExplanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 2. Domain summaries

    private var domainSummariesSection: some View {
        Section("Domain summaries") {
            ForEach(domainSummaries) { domain in
                VStack(alignment: .leading, spacing: 8) {
                    Text(domain.title)
                        .font(.headline)

                    Text(domain.headline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LabeledContent("Maturity", value: domain.maturitySummary)
                    LabeledContent("Status", value: domain.status.rawValue)
                    LabeledContent("Confidence", value: domain.confidenceSummary)
                    LabeledContent("Coverage", value: "\(domain.coveragePercent)%")

                    if !domain.establishedBeliefs.isEmpty {
                        LabeledContent(
                            "Established",
                            value: domain.establishedBeliefs.joined(separator: ", ")
                        )
                    }

                    if !domain.emergingBeliefs.isEmpty {
                        LabeledContent(
                            "Emerging",
                            value: domain.emergingBeliefs.joined(separator: ", ")
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Missing knowledge")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(domain.missingKnowledge, id: \.self) { gap in
                            Text("• \(gap)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - 3. Individual beliefs

    @ViewBuilder
    private var individualBeliefsSection: some View {
        ForEach(domainSummaries) { domain in
            Section("\(domain.title) — beliefs") {
                ForEach(
                    CoachUnderstandingInspectorPresentation.beliefs(in: domain.domain, from: snapshot)
                ) { belief in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            LabeledContent("Maturity", value: belief.maturity.rawValue)
                            LabeledContent("Last transition", value: belief.lastTransition)
                            LabeledContent("Confidence", value: String(format: "%.2f", belief.confidence))
                            LabeledContent("Effect size", value: String(format: "%.1f", belief.effectSize))
                            LabeledContent("Samples", value: belief.sampleSize)
                            LabeledContent("Evidence window", value: belief.evidenceWindow)
                            boolRow("Pending event", belief.hasPendingEvent)
                            boolRow("Spoken", belief.hasSpokenEvent)
                            if let lifecycle = belief.lifecycleState {
                                LabeledContent("Lifecycle", value: lifecycle)
                            }
                            if let blockingReason = belief.blockingReason {
                                LabeledContent("Blocking reason", value: blockingReason.inspectorCategory)
                            }
                            Text(belief.noEventReason)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(belief.beliefID.rawValue)
                                .font(.subheadline.weight(.semibold))
                            Text("\(belief.maturity.rawValue) · confidence \(String(format: "%.0f%%", belief.confidence * 100))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 4. Reflection

    private var reflectionSection: some View {
        Section("Reflection") {
            boolRow("Pause", snapshot.reflection.pause)
            LabeledContent("Pause reason", value: snapshot.reflection.pauseReason)
            LabeledContent("Blocked by", value: snapshot.reflection.blockedBy ?? "none")
            LabeledContent("Next unspoken", value: snapshot.reflection.nextUnspokenEventID ?? "nil")
            if let beliefID = snapshot.reflection.nextUnspokenBeliefID {
                LabeledContent("Next belief", value: beliefID.rawValue)
            }
            LabeledContent("Offer", value: snapshot.reflection.reflectionOfferID ?? "nil")
            if let beliefID = snapshot.reflection.reflectionOfferBeliefID {
                LabeledContent("Offer belief", value: beliefID)
            }
            boolRow("Marked displayed", snapshot.reflection.isReflectionOfferDisplayed)
            if let reason = snapshot.reflection.noReflectionReason {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 5. Event queue

    private var eventQueueSection: some View {
        Section("Pending event queue") {
            if snapshot.eventQueue.isEmpty {
                Text("Queue empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.eventQueue) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.id)
                            .font(.caption.monospaced())
                        LabeledContent("Belief", value: event.beliefID.rawValue)
                        LabeledContent("Change", value: event.change.rawValue)
                        LabeledContent("Maturity", value: event.maturity.rawValue)
                        boolRow("Spoken", event.isSpoken)
                        boolRow("Next unspoken", event.isNextUnspoken)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Data context

    private var dataContextSection: some View {
        Section("Data context") {
            LabeledContent("Observations", value: "\(snapshot.observationCount)")
            LabeledContent("Beliefs tracked", value: "\(snapshot.beliefs.count)")
            LabeledContent("Nutrition populated", value: "\(snapshot.nutritionCoverage.populatedCount)")
            LabeledContent("Nutrition missing", value: "\(snapshot.nutritionCoverage.missingCount)")
            if let dayKey = snapshot.nutritionCoverage.latestDayKey {
                LabeledContent("Latest day", value: dayKey)
            }
            LabeledContent("Latest nutrition", value: snapshot.nutritionCoverage.latestNutritionStatus)
            LabeledContent("Captured", value: formattedDate(snapshot.capturedAt))

            if !snapshot.understandingSummary.diagnostics.isEmpty {
                DisclosureGroup("Synthesis diagnostics") {
                    ForEach(Array(snapshot.understandingSummary.diagnostics.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func boolRow(_ title: String, _ value: Bool) -> some View {
        LabeledContent(title, value: value ? "yes" : "no")
    }

    private func refresh() {
        snapshot = CoachBeliefDebugInspector.build(coachState: coachState)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }

    private func headlineIcon(for headline: String) -> String {
        if headline.contains("well") {
            return "checkmark.circle.fill"
        }
        if headline.contains("emerging") {
            return "arrow.triangle.2.circlepath"
        }
        return "hourglass"
    }
}
#endif
