import Foundation
internal import Combine

@MainActor
final class CoachEveningSummaryCoordinator: ObservableObject {
    @Published private(set) var summary: CoachEveningSummary?
    @Published private(set) var receivedAt: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshFailed = false
    @Published private(set) var cachedFingerprint: String?

    private let store: CoachEveningSummaryStore
    private let generate: (CoachEveningSummaryInput, String) async throws -> CoachEveningSummary
    private var owner: String?
    private var task: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    /// Fingerprint of the in-flight or last accepted generation — rejects stale AI replies.
    private var generationFingerprint: String?

    init(store: CoachEveningSummaryStore? = nil,
         generate: @escaping (CoachEveningSummaryInput, String) async throws -> CoachEveningSummary = CoachEveningSummaryService.generate) {
        self.store = store ?? CoachEveningSummaryStore()
        self.generate = generate
    }

    var displayCommentary: String? {
        summary.map(CoachEveningSummaryPolicy.displayCommentary(from:))
    }

    /// Restore lasting cache for the owner. Does not call AI.
    /// Independent of HealthKit, coach snapshot, clock, evening window, and daily claims.
    func restore(owner: String) {
        let tag = CoachEveningSummaryDiagnostics.ownerTag(owner)
        if self.owner != owner {
            CoachEveningSummaryDiagnostics.event(
                "restore.ownerChange",
                detail: "owner=\(tag) hadSummary=\(summary != nil) wasRefreshing=\(isRefreshing)"
            )
            task?.cancel()
            deadline?.cancel()
            isRefreshing = false
            lastRefreshFailed = false
            self.owner = owner
        }
        do {
            if let cache = try store.loadCache(owner: owner) {
                summary = cache.summary
                receivedAt = cache.receivedAt
                cachedFingerprint = cache.inputFingerprint
                lastRefreshFailed = false
                CoachEveningSummaryDiagnostics.event(
                    "cache.hit",
                    detail: "owner=\(tag) day=\(cache.summary.day) locale=\(cache.summary.locale) receivedAt=\(ISO8601DateFormatter().string(from: cache.receivedAt)) uiApplied=true"
                )
            } else if isRefreshing {
                // Keep whatever is already on screen while a refresh is in flight.
                CoachEveningSummaryDiagnostics.event(
                    "cache.miss",
                    detail: "owner=\(tag) keepVisible=true reason=refreshInFlight"
                )
            } else {
                let hadSummary = summary != nil
                summary = nil
                receivedAt = nil
                cachedFingerprint = nil
                CoachEveningSummaryDiagnostics.event(
                    "cache.miss",
                    detail: "owner=\(tag) clearedInMemory=\(hadSummary) uiApplied=true"
                )
            }
        } catch {
            CoachEveningSummaryDiagnostics.error(
                "cache.readError",
                detail: "owner=\(tag) keepVisible=\(summary != nil) error=\(String(describing: type(of: error)))"
            )
            if summary == nil {
                lastRefreshFailed = true
            }
        }
    }

    func cancelForWorkspaceReset() {
        CoachEveningSummaryDiagnostics.event("workspaceReset")
        task?.cancel()
        deadline?.cancel()
        owner = nil
        summary = nil
        receivedAt = nil
        cachedFingerprint = nil
        generationFingerprint = nil
        isRefreshing = false
        lastRefreshFailed = false
    }

    /// Auto path for evening recap: restore cache, then generate when missing or fingerprint changed.
    func ensureUpToDate(
        input: CoachEveningSummaryInput,
        owner: String,
        fingerprint: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        isStillEligible: @escaping () -> Bool
    ) {
        let tag = CoachEveningSummaryDiagnostics.ownerTag(owner)
        restore(owner: owner)

        guard CoachEveningSummaryPolicy.allowsGeneration(at: now, calendar: calendar),
              input.day == CoachEveningSummaryPolicy.dayKey(now, calendar: calendar) else {
            CoachEveningSummaryDiagnostics.event(
                "ensure.blocked",
                detail: "owner=\(tag) reason=generationNotAllowed"
            )
            return
        }

        if let summary,
           summary.day == input.day,
           cachedFingerprint == fingerprint {
            CoachEveningSummaryDiagnostics.event(
                "ensure.cacheFresh",
                detail: "owner=\(tag) day=\(input.day)"
            )
            return
        }

        guard !isRefreshing else {
            CoachEveningSummaryDiagnostics.event("ensure.ignored", detail: "owner=\(tag) reason=alreadyRefreshing")
            return
        }

        guard isStillEligible() else {
            CoachEveningSummaryDiagnostics.event("ensure.blocked", detail: "owner=\(tag) reason=notEligible")
            return
        }

        // Fingerprint owns freshness so a new completed workout can regenerate after 20:00.
        beginGeneration(
            input: input,
            owner: owner,
            now: now,
            fingerprint: fingerprint,
            persistClaim: false,
            isStillEligible: isStillEligible
        )
    }

    /// Day snapshot was not ready; keep any lasting summary and show a retryable error.
    func noteInputUnavailable(owner: String, reason: String) {
        CoachEveningSummaryDiagnostics.error(
            "refresh.blocked",
            detail: "owner=\(CoachEveningSummaryDiagnostics.ownerTag(owner)) reason=\(reason) hadSummary=\(summary != nil)"
        )
        restore(owner: owner)
        guard !isRefreshing else { return }
        lastRefreshFailed = true
    }

    /// Manual Coach button: always hits AI in test mode; ignores daily claims.
    func refresh(input: CoachEveningSummaryInput, owner: String, now: Date = Date(),
                 calendar: Calendar = .current) {
        let tag = CoachEveningSummaryDiagnostics.ownerTag(owner)
        guard !isRefreshing else {
            CoachEveningSummaryDiagnostics.event("refresh.ignored", detail: "owner=\(tag) reason=alreadyRefreshing")
            return
        }
        if self.owner != owner {
            restore(owner: owner)
        } else {
            self.owner = owner
        }

        CoachEveningSummaryDiagnostics.event(
            "refresh.start",
            detail: "owner=\(tag) day=\(input.day) locale=\(input.locale) hadSummary=\(summary != nil) oncePerDay=\(CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow)"
        )

        guard CoachEveningSummaryPolicy.allowsGeneration(at: now, calendar: calendar) else {
            CoachEveningSummaryDiagnostics.event("refresh.blocked", detail: "owner=\(tag) reason=generationNotAllowed")
            return
        }
        // Manual refresh always hits AI when evening window allows it.
        beginGeneration(
            input: input,
            owner: owner,
            now: now,
            fingerprint: "manual:\(UUID().uuidString)",
            persistClaim: false,
            isStillEligible: { true }
        )
    }

    /// Production auto path (behind `enforcesOncePerDayAndEveningWindow`).
    func startIfNeeded(input: CoachEveningSummaryInput, owner: String, now: Date = Date(),
                       calendar: Calendar = .current) {
        guard CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow else { return }
        ensureUpToDate(
            input: input,
            owner: owner,
            fingerprint: "day:\(input.day)",
            now: now,
            calendar: calendar,
            isStillEligible: { true }
        )
    }

    private func beginGeneration(
        input: CoachEveningSummaryInput,
        owner: String,
        now: Date,
        fingerprint: String?,
        persistClaim: Bool,
        isStillEligible: @escaping () -> Bool
    ) {
        isRefreshing = true
        lastRefreshFailed = false
        generationFingerprint = fingerprint
        let generationOwner = owner
        let generationFP = fingerprint
        let tag = CoachEveningSummaryDiagnostics.ownerTag(owner)
        task?.cancel()
        deadline?.cancel()
        CoachEveningSummaryDiagnostics.event(
            "generate.begin",
            detail: "owner=\(tag) day=\(input.day) persistClaim=\(persistClaim) keepVisible=\(summary != nil)"
        )
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.owner == generationOwner {
                    isRefreshing = false
                    deadline?.cancel()
                }
            }
            do {
                let summary = try await generate(input, generationOwner)
                try Task.checkCancellation()
                guard self.owner == generationOwner, isRefreshing else {
                    CoachEveningSummaryDiagnostics.event(
                        "generate.discarded",
                        detail: "owner=\(tag) reason=scopeChanged"
                    )
                    return
                }
                if let generationFP, self.generationFingerprint != generationFP {
                    CoachEveningSummaryDiagnostics.event(
                        "generate.discarded",
                        detail: "owner=\(tag) reason=staleFingerprint"
                    )
                    return
                }
                guard isStillEligible() else {
                    CoachEveningSummaryDiagnostics.event(
                        "generate.discarded",
                        detail: "owner=\(tag) reason=noLongerEligible"
                    )
                    return
                }
                guard summary.isValid(for: input) else {
                    throw CoachEveningSummaryServiceError.invalidResponse
                }
                let received = Date()
                try store.saveCache(
                    .init(summary: summary, receivedAt: received, inputFingerprint: generationFP),
                    owner: generationOwner
                )
                CoachEveningSummaryDiagnostics.event(
                    "cache.saved",
                    detail: "owner=\(tag) day=\(summary.day) locale=\(summary.locale)"
                )
                if persistClaim {
                    try store.saveClaim(.init(day: input.day, summary: summary), owner: generationOwner)
                }
                self.summary = summary
                self.receivedAt = received
                self.cachedFingerprint = generationFP
                lastRefreshFailed = false
                CoachEveningSummaryDiagnostics.event(
                    "ui.ready",
                    detail: "owner=\(tag) day=\(summary.day) headlineLen=\(summary.headline.count)"
                )
            } catch is CancellationError {
                CoachEveningSummaryDiagnostics.event("generate.cancelled", detail: "owner=\(tag)")
            } catch {
                let code: String
                if let service = error as? CoachEveningSummaryServiceError {
                    switch service {
                    case .unavailable: code = "unavailable"
                    case .invalidResponse: code = "invalidResponse"
                    case .server(let status): code = "server.\(status)"
                    }
                } else {
                    code = String(describing: type(of: error))
                }
                CoachEveningSummaryDiagnostics.error(
                    "generate.failed",
                    detail: "owner=\(tag) code=\(code) keepVisible=\(self.summary != nil)"
                )
                if self.owner == generationOwner, isRefreshing {
                    lastRefreshFailed = true
                }
            }
        }
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            guard let self, self.owner == generationOwner, isRefreshing else { return }
            CoachEveningSummaryDiagnostics.error(
                "generate.timeout",
                detail: "owner=\(tag) keepVisible=\(summary != nil)"
            )
            lastRefreshFailed = true
            isRefreshing = false
            task?.cancel()
        }
    }
}
