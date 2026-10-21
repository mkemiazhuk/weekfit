import Foundation
internal import Combine

/// Result of one generation attempt (HTTP or test double).
struct CoachEveningSummaryGenerationResult: Sendable {
    let summary: CoachEveningSummary
    let requestId: String
}

@MainActor
final class CoachEveningSummaryCoordinator: ObservableObject {
    @Published private(set) var summary: CoachEveningSummary?
    @Published private(set) var receivedAt: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshFailed = false
    @Published private(set) var cachedFingerprint: String?

    private let store: CoachEveningSummaryStore
    private let generate: (CoachEveningSummaryInput, String) async throws -> CoachEveningSummaryGenerationResult
    private let timeoutSeconds: TimeInterval
    private var owner: String?

    /// Single in-flight HTTP generation keyed by (owner, localDay). Waiter cancel / UI timeout must not clear this.
    private var inFlight: InFlight?
    private var deadline: Task<Void, Never>?

    private struct FlightKey: Hashable {
        let owner: String
        let day: String
    }

    private final class InFlight {
        let key: FlightKey
        let clientRequestId: String
        let fingerprint: String?
        var task: Task<Void, Never>
        var waiterSources: [String] = []

        init(key: FlightKey, clientRequestId: String, fingerprint: String?, task: Task<Void, Never>) {
            self.key = key
            self.clientRequestId = clientRequestId
            self.fingerprint = fingerprint
            self.task = task
        }
    }

    init(
        store: CoachEveningSummaryStore? = nil,
        timeoutSeconds: TimeInterval = 20,
        generate: @escaping (CoachEveningSummaryInput, String) async throws -> CoachEveningSummaryGenerationResult = { input, owner in
            try await CoachEveningSummaryService.generate(input, owner: owner)
        }
    ) {
        self.store = store ?? CoachEveningSummaryStore()
        self.timeoutSeconds = timeoutSeconds
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
                detail: "owner=\(tag) hadSummary=\(summary != nil) wasRefreshing=\(isRefreshing) hadFlight=\(inFlight != nil)"
            )
            cancelInFlight(reason: "ownerChange")
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
                    detail: CoachEveningSummaryDiagnostics.flightDetail(
                        owner: owner,
                        day: cache.summary.day,
                        source: "restore",
                        extra: "hit=disk receivedAt=\(ISO8601DateFormatter().string(from: cache.receivedAt))"
                    )
                )
            } else if let summary, self.owner == owner {
                // In-memory success (e.g. disk write failed earlier) — treat as session cache hit.
                CoachEveningSummaryDiagnostics.event(
                    "cache.hit",
                    detail: CoachEveningSummaryDiagnostics.flightDetail(
                        owner: owner,
                        day: summary.day,
                        source: "restore",
                        extra: "hit=memory"
                    )
                )
            } else if inFlight?.key.owner == owner {
                CoachEveningSummaryDiagnostics.event(
                    "cache.miss",
                    detail: CoachEveningSummaryDiagnostics.flightDetail(
                        owner: owner,
                        day: inFlight?.key.day ?? "-",
                        source: "restore",
                        extra: "hit=miss keepVisible=true reason=refreshInFlight"
                    )
                )
            } else {
                let hadSummary = summary != nil
                summary = nil
                receivedAt = nil
                cachedFingerprint = nil
                CoachEveningSummaryDiagnostics.event(
                    "cache.miss",
                    detail: CoachEveningSummaryDiagnostics.flightDetail(
                        owner: owner,
                        day: "-",
                        source: "restore",
                        extra: "hit=miss clearedInMemory=\(hadSummary)"
                    )
                )
            }
        } catch {
            CoachEveningSummaryDiagnostics.error(
                "cache.readError",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner,
                    day: "-",
                    source: "restore",
                    extra: "keepVisible=\(summary != nil) error=\(String(describing: type(of: error)))"
                )
            )
            if summary == nil {
                lastRefreshFailed = true
            }
        }
    }

    func cancelForWorkspaceReset() {
        CoachEveningSummaryDiagnostics.event("workspaceReset")
        cancelInFlight(reason: "workspaceReset")
        owner = nil
        summary = nil
        receivedAt = nil
        cachedFingerprint = nil
        lastRefreshFailed = false
    }

    /// Auto path for evening recap: restore cache, generate at most once per local day.
    func ensureUpToDate(
        input: CoachEveningSummaryInput,
        owner: String,
        fingerprint: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        source: String = "coach",
        isStillEligible: @escaping () -> Bool
    ) {
        restore(owner: owner)

        guard CoachEveningSummaryPolicy.allowsGeneration(at: now, calendar: calendar),
              input.day == CoachEveningSummaryPolicy.dayKey(now, calendar: calendar) else {
            CoachEveningSummaryDiagnostics.event(
                "ensure.blocked",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: source, extra: "reason=generationNotAllowed"
                )
            )
            return
        }

        // Once-per-day: any successful summary for this local day wins — ignore fingerprint churn.
        if CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow,
           let summary,
           summary.day == input.day {
            CoachEveningSummaryDiagnostics.event(
                "ensure.cacheFresh",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: source, extra: "hit=memory reason=oncePerDay"
                )
            )
            return
        }

        if let summary,
           summary.day == input.day,
           cachedFingerprint == fingerprint {
            CoachEveningSummaryDiagnostics.event(
                "ensure.cacheFresh",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: source, extra: "hit=memory reason=fingerprintMatch"
                )
            )
            return
        }

        // Eligibility gates starting a new flight; join of an existing flight is always allowed
        // so Root/Coach coalesce onto one HTTP.
        if inFlight == nil, !isStillEligible() {
            CoachEveningSummaryDiagnostics.event(
                "ensure.blocked",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: source, extra: "reason=notEligible"
                )
            )
            return
        }

        let dayFingerprint = "day:\(input.day)"
        beginOrJoinGeneration(
            input: input,
            owner: owner,
            fingerprint: CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow
                ? dayFingerprint
                : fingerprint,
            source: source,
            isStillEligible: isStillEligible
        )
    }

    /// Day snapshot was not ready; keep any lasting summary and show a retryable error.
    func noteInputUnavailable(owner: String, reason: String) {
        CoachEveningSummaryDiagnostics.error(
            "refresh.blocked",
            detail: CoachEveningSummaryDiagnostics.flightDetail(
                owner: owner,
                day: "-",
                source: "coach",
                extra: "reason=\(reason) hadSummary=\(summary != nil)"
            )
        )
        restore(owner: owner)
        guard inFlight == nil else { return }
        lastRefreshFailed = true
    }

    /// Manual Coach button. Once-per-day mode reuses today's cached answer; otherwise hits AI.
    func refresh(
        input: CoachEveningSummaryInput,
        owner: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        source: String = "manual"
    ) {
        restore(owner: owner)

        CoachEveningSummaryDiagnostics.event(
            "refresh.start",
            detail: CoachEveningSummaryDiagnostics.flightDetail(
                owner: owner,
                day: input.day,
                source: source,
                extra: "hadSummary=\(summary != nil) oncePerDay=\(CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow)"
            )
        )

        guard CoachEveningSummaryPolicy.allowsGeneration(at: now, calendar: calendar) else {
            CoachEveningSummaryDiagnostics.event(
                "refresh.blocked",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: source, extra: "reason=generationNotAllowed"
                )
            )
            return
        }

        if CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow,
           let summary,
           summary.day == input.day {
            CoachEveningSummaryDiagnostics.event(
                "refresh.reused",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner, day: input.day, source: source, extra: "hit=memory reason=oncePerDay"
                )
            )
            lastRefreshFailed = false
            return
        }

        beginOrJoinGeneration(
            input: input,
            owner: owner,
            fingerprint: CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow
                ? "day:\(input.day)"
                : "manual:\(UUID().uuidString)",
            source: source,
            isStillEligible: { true }
        )
    }

    /// Production auto path (behind `enforcesOncePerDayAndEveningWindow`).
    func startIfNeeded(
        input: CoachEveningSummaryInput,
        owner: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        source: String = "root"
    ) {
        guard CoachEveningSummaryPolicy.enforcesOncePerDayAndEveningWindow else { return }
        ensureUpToDate(
            input: input,
            owner: owner,
            fingerprint: "day:\(input.day)",
            now: now,
            calendar: calendar,
            source: source,
            isStillEligible: { true }
        )
    }

    // MARK: - Single-flight

    private func beginOrJoinGeneration(
        input: CoachEveningSummaryInput,
        owner: String,
        fingerprint: String?,
        source: String,
        isStillEligible: @escaping () -> Bool
    ) {
        let key = FlightKey(owner: owner, day: input.day)

        if let flight = inFlight {
            if flight.key == key {
                flight.waiterSources.append(source)
                isRefreshing = true
                lastRefreshFailed = false
                CoachEveningSummaryDiagnostics.event(
                    "generation.joined",
                    detail: CoachEveningSummaryDiagnostics.flightDetail(
                        owner: owner,
                        day: input.day,
                        source: source,
                        requestId: flight.clientRequestId,
                        extra: "waiters=\(flight.waiterSources.count)"
                    )
                )
                return
            }
            // Different owner/day — abandon previous flight's UI claim; underlying task still
            // checks key before applying so a late response cannot cross owners/days.
            CoachEveningSummaryDiagnostics.event(
                "generation.superseded",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: owner,
                    day: input.day,
                    source: source,
                    requestId: flight.clientRequestId,
                    extra: "previousDay=\(flight.key.day) previousOwner=\(CoachEveningSummaryDiagnostics.ownerTag(flight.key.owner))"
                )
            )
            cancelInFlight(reason: "superseded")
        }

        let clientRequestId = UUID().uuidString
        isRefreshing = true
        lastRefreshFailed = false
        self.owner = owner

        CoachEveningSummaryDiagnostics.event(
            "generation.started",
            detail: CoachEveningSummaryDiagnostics.flightDetail(
                owner: owner,
                day: input.day,
                source: source,
                requestId: clientRequestId,
                extra: "hit=miss keepVisible=\(summary != nil)"
            )
        )

        // Assign flight before the Task body can race completion on a fast stub.
        let flight = InFlight(key: key, clientRequestId: clientRequestId, fingerprint: fingerprint, task: Task {})
        flight.waiterSources = [source]
        inFlight = flight

        let task = Task { [weak self] in
            guard let self else { return }
            await self.runGeneration(
                input: input,
                key: key,
                clientRequestId: clientRequestId,
                fingerprint: fingerprint,
                isStillEligible: isStillEligible
            )
        }
        flight.task = task

        deadline?.cancel()
        let timeout = timeoutSeconds
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(timeout)) } catch { return }
            await self?.handleGenerationTimeout(key: key, clientRequestId: clientRequestId, source: source)
        }
    }

    private func runGeneration(
        input: CoachEveningSummaryInput,
        key: FlightKey,
        clientRequestId: String,
        fingerprint: String?,
        isStillEligible: @escaping () -> Bool
    ) async {
        defer {
            // Only the current flight for this key clears itself.
            if inFlight?.clientRequestId == clientRequestId {
                inFlight = nil
                deadline?.cancel()
                deadline = nil
                if owner == key.owner {
                    isRefreshing = false
                }
            }
        }

        do {
            let result = try await generate(input, key.owner)
            let requestId = result.requestId.isEmpty ? clientRequestId : result.requestId

            // Owner/day must still match — never apply a response to another user or day.
            // Flight may still be present after UX timeout; that is intentional.
            guard owner == key.owner else {
                CoachEveningSummaryDiagnostics.event(
                    "generation.discarded",
                    detail: CoachEveningSummaryDiagnostics.flightDetail(
                        owner: key.owner, day: key.day, source: "flight",
                        requestId: requestId, extra: "reason=ownerMismatch"
                    )
                )
                return
            }
            guard result.summary.day == key.day, result.summary.day == input.day else {
                CoachEveningSummaryDiagnostics.event(
                    "generation.discarded",
                    detail: CoachEveningSummaryDiagnostics.flightDetail(
                        owner: key.owner, day: key.day, source: "flight",
                        requestId: requestId, extra: "reason=dayMismatch responseDay=\(result.summary.day)"
                    )
                )
                return
            }
            // If a newer flight replaced this one, do not overwrite its state.
            if let current = inFlight, current.clientRequestId != clientRequestId {
                CoachEveningSummaryDiagnostics.event(
                    "generation.discarded",
                    detail: CoachEveningSummaryDiagnostics.flightDetail(
                        owner: key.owner, day: key.day, source: "flight",
                        requestId: requestId, extra: "reason=staleFlight"
                    )
                )
                return
            }
            guard result.summary.isValid(for: input) else {
                throw CoachEveningSummaryServiceError.invalidResponse
            }

            let received = Date()
            // Memory first — disk failure must not force another generation this session.
            summary = result.summary
            receivedAt = received
            cachedFingerprint = fingerprint
            lastRefreshFailed = false

            var diskSaved = true
            do {
                try store.saveCache(
                    .init(summary: result.summary, receivedAt: received, inputFingerprint: fingerprint),
                    owner: key.owner
                )
                CoachEveningSummaryDiagnostics.event(
                    "cache.saved",
                    detail: CoachEveningSummaryDiagnostics.flightDetail(
                        owner: key.owner, day: result.summary.day, source: "flight",
                        requestId: requestId, extra: "disk=ok"
                    )
                )
            } catch {
                diskSaved = false
                CoachEveningSummaryDiagnostics.error(
                    "cache.saveError",
                    detail: CoachEveningSummaryDiagnostics.flightDetail(
                        owner: key.owner, day: result.summary.day, source: "flight",
                        requestId: requestId,
                        extra: "disk=fail keepMemory=true error=\(String(describing: type(of: error)))"
                    )
                )
            }

            let applied = isStillEligible()
            CoachEveningSummaryDiagnostics.event(
                "generation.completed",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: key.owner,
                    day: result.summary.day,
                    source: "flight",
                    requestId: requestId,
                    extra: "diskSaved=\(diskSaved) ui=\(applied ? "applied" : "hidden") headlineLen=\(result.summary.headline.count)"
                )
            )
            CoachEveningSummaryDiagnostics.event(
                applied ? "ui.applied" : "ui.hidden",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: key.owner, day: result.summary.day, source: "flight", requestId: requestId
                )
            )
        } catch is CancellationError {
            CoachEveningSummaryDiagnostics.event(
                "generation.cancelled",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: key.owner, day: key.day, source: "flight", requestId: clientRequestId
                )
            )
            // Cancellation of the flight itself (owner change / workspace reset) — not a retryable UI error
            // unless nothing is visible.
            if owner == key.owner, summary == nil {
                lastRefreshFailed = true
            }
        } catch {
            let code = Self.errorCode(error)
            CoachEveningSummaryDiagnostics.error(
                "generation.failed",
                detail: CoachEveningSummaryDiagnostics.flightDetail(
                    owner: key.owner, day: key.day, source: "flight",
                    requestId: clientRequestId,
                    extra: "code=\(code) keepVisible=\(summary != nil)"
                )
            )
            if owner == key.owner {
                lastRefreshFailed = true
            }
        }
    }

    /// UX timeout: stop spinner and allow the user to see a failure state, but do **not** cancel the
    /// in-flight HTTP or clear the flight mutex — joiners must not mint a second request.
    private func handleGenerationTimeout(key: FlightKey, clientRequestId: String, source: String) {
        guard let flight = inFlight,
              flight.clientRequestId == clientRequestId,
              flight.key == key else { return }
        CoachEveningSummaryDiagnostics.error(
            "generation.timeout",
            detail: CoachEveningSummaryDiagnostics.flightDetail(
                owner: key.owner, day: key.day, source: source,
                requestId: clientRequestId,
                extra: "keepFlight=true keepVisible=\(summary != nil)"
            )
        )
        if owner == key.owner {
            lastRefreshFailed = true
            isRefreshing = false
        }
    }

    private func cancelInFlight(reason: String) {
        guard let flight = inFlight else {
            deadline?.cancel()
            deadline = nil
            isRefreshing = false
            return
        }
        CoachEveningSummaryDiagnostics.event(
            "generation.cancel",
            detail: CoachEveningSummaryDiagnostics.flightDetail(
                owner: flight.key.owner,
                day: flight.key.day,
                source: reason,
                requestId: flight.clientRequestId
            )
        )
        flight.task.cancel()
        inFlight = nil
        deadline?.cancel()
        deadline = nil
        isRefreshing = false
    }

    private static func errorCode(_ error: Error) -> String {
        if let service = error as? CoachEveningSummaryServiceError {
            switch service {
            case .unavailable: return "unavailable"
            case .invalidResponse: return "invalidResponse"
            case .server(let status): return "server.\(status)"
            }
        }
        return String(describing: type(of: error))
    }
}
