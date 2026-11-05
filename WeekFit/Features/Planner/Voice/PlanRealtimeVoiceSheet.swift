internal import Combine
import AVFoundation
import AVKit
import SwiftUI
import WebKit

@MainActor
final class PlanRealtimeSessionController: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    enum Phase: Equatable {
        case connecting
        case queued(Int)
        case ending
        case connected
        case listening
        case speaking
        case acting
        case ended
        case failed(String)
    }

    @Published private(set) var phase: Phase = .connecting
    @Published private(set) var connectedAt: Date?
    @Published private(set) var endingAt: Date?
    @Published private(set) var remainingSeconds: Int?
    @Published private(set) var muted = false
    @Published private(set) var webView: WKWebView?
    @Published private(set) var receipt: PlanVoiceReceipt?
    @Published private(set) var turns: [PlanVoiceTurn] = []
    @Published private(set) var notices: [PlanVoiceReceipt] = []
    @Published private(set) var microphoneDenied = false
    @Published private(set) var offerOtherEngine = false
    @Published private(set) var inputLevel: Double = 0
    @Published private(set) var outputLevel: Double = 0

    var planningDay = Date()
    var activities: [PlannedActivity] = []
    var dayContext = PlanVoiceDayContext()
    var onSave: ((PlanVoiceCreateRequest) throws -> String)?
    var onUpdate: ((PlanVoiceUpdateRequest) throws -> Void)?
    var onDelete: ((String) throws -> Void)?
    var onLogWater: ((Int) throws -> Int)?
    var onRemindWater: ((Date, Int) throws -> Void)?
    var languageCode = "ru"
    var engine = PlanVoiceEngine.current

    private let bridge = PlanRealtimeScriptBridge()
    private var gate = PlanRealtimeCallGate()
    private var applied: Set<String> = []
    private var savedReplies: [String: (reply: String, at: Date)] = [:]
    private var refBook = PlanRealtimeRefBook()
    private var removedIDs = Set<String>()
    private var voicedSources: [String: PlanRealtimeSourceActivity] = [:]
    private var secret: PlanRealtimeSessionSecret?
    private var pageReady = false
    private var pageStarted = false
    private var toneFallback: Task<Void, Never>?
    private var awaitsGreeting = true
    private var started = false
    private var ended = false
    private var lineTicket: String?
    private var receiptIDs = Set<String>()
    private var connectTask: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var callLanguage = "ru"
    private var reconnecting = false
    private var endingWatchdog: Task<Void, Never>?
    private let calendar = Calendar.current
    private let ringback = PlanVoiceRingback()

    func begin() {
        guard webView == nil, !started else { return }
        started = true
        callLanguage = languageCode
        refBook = PlanRealtimeRefBook()
        removedIDs = []
        phase = .connecting
        connectTask = Task { await connect() }
    }

    func toggleMute() {
        muted.toggle()
        webView?.evaluateJavaScript("window.weekfit && window.weekfit.setMuted(\(muted ? "true" : "false"))")
    }

    func end() {
        guard !ended else { return }
        ended = true
        if let id = secret?.sessionId {
            WeekFitVoiceStopLedger.remember(id)
        }
        connectTask?.cancel()
        heartbeat?.cancel()
        endingWatchdog?.cancel()
        toneFallback?.cancel()
        toneFallback = nil
        if secret?.sessionId != nil {
            Task { await WeekFitVoiceStopQueue.shared.flush() }
        }
        let ticket = lineTicket
        lineTicket = nil
        if let ticket {
            Task { await leaveLine(ticket) }
        }
        ringback.stop()
        webView?.evaluateJavaScript("window.weekfit && window.weekfit.stop()")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "plannerVoice")
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView = nil
        if case .failed = phase { return }
        phase = .ended
    }

    private func rememberVoiceStop(_ sessionId: String?) {
        guard let sessionId else { return }
        WeekFitVoiceStopLedger.remember(sessionId)
        Task { await WeekFitVoiceStopQueue.shared.flush() }
    }

    func receive(_ body: Any) {
        guard let payload = body as? [String: Any], let type = payload["type"] as? String else { return }
        switch type {
        case "state":
            applyState(payload)
        case "sdp":
            guard let sdp = payload["sdp"] as? String, let id = secret?.sessionId else { return }
            Task {
                do {
                    struct Answer: Decodable { let sdp: String }
                    let answer: Answer = try await WeekFitAIClient().request(path: "v2/ai/voice/connect",
                        body: JSONEncoder().encode(["sessionId": id, "sdp": sdp]))
                    _ = try await webView?.evaluateJavaScript("window.weekfit.sdpAnswer(\(jsLiteral(answer.sdp)))")
                } catch {
                    phase = .failed(WeekFitAIErrorMessage(error))
                    offerOtherEngine = true
                    end()
                }
            }
        case "tool":
            guard let callId = payload["callId"] as? String else { return }
            let name = payload["name"] as? String ?? "create_activity"
            let arguments = payload["arguments"] as? String ?? "{}"
            Task { await handleTool(callId: callId, name: name, arguments: arguments) }
        case "level":
            if let input = payload["input"] as? Double {
                inputLevel = input
            } else if let input = payload["input"] as? NSNumber {
                inputLevel = input.doubleValue
            }
            if let output = payload["output"] as? Double {
                outputLevel = output
            } else if let output = payload["output"] as? NSNumber {
                outputLevel = output.doubleValue
            }
        case "usage":
            let responseId = payload["responseId"] as? String ?? ""
            let input = payload["inputTokens"] as? Int ?? 0
            let output = payload["outputTokens"] as? Int ?? 0
            Task {
                guard let client = try? await self.makeClient() else { return }
                await client.reportUsage(responseId: responseId, inputTokens: input, outputTokens: output)
            }
        default:
            break
        }
    }

    private func connect() async {
        if WeekFitAIBilling.refused {
            phase = .failed(WeekFitLocalizedString("ai.usage.sandboxMisconfigured"))
            return
        }
        guard await ensureMicrophone() else { return }
        engine = PlanVoiceEngine.current
        do {
            let client = try await makeClient()
            let ticket = try await waitForLine(client)
            guard !ended else { return }
            let alreadyIntroduced = PlanRealtimeMayaMemory.introduced
            let reconnect = reconnecting
            PlanRealtimeMayaMemory.markIntroduced()
            ringback.start()
            phase = .connecting
            // The call page loads while the session is opened, not after it.
            loadConsole(client)
            let secret = try await client.openSession(
                timeZone: calendar.timeZone.identifier,
                now: Date(),
                planningDay: planRealtimeDayString(planningDay, calendar: calendar),
                givenName: ProfileService.resolvedGivenName(),
                language: callLanguage,
                plan: currentAgenda().map {
                    [
                        "ref": $0.ref,
                        "scope": $0.scope,
                        "title": $0.title,
                        "startTime": $0.startTime,
                        "durationMinutes": $0.durationMinutes,
                    ]
                },
                dayContext: dayContext.jsonObject(),
                ticket: ticket,
                introduced: alreadyIntroduced,
                reconnected: reconnect
            )
            self.secret = secret
            guard !ended else {
                rememberVoiceStop(secret.sessionId)
                await client.leaveLine(ticket: ticket)
                return
            }
            remainingSeconds = secret.budgetSeconds
            startHeartbeat(ticket)
            startConsoleIfReady()
        } catch let error as WeekFitAIUsageError {
            failConnecting(WeekFitAIErrorMessage(error))
        } catch PlanRealtimeClientError.lineFull {
            failConnecting(WeekFitLocalizedString("planner.voice.lineFull"))
        } catch PlanRealtimeClientError.transport {
            failConnecting(WeekFitLocalizedString("planner.voice.offline"))
        } catch {
            failConnecting(WeekFitLocalizedString("planner.voice.connectionLost"))
        }
    }

    private func loadConsole(_ client: PlanRealtimeClient) {
        secret = nil
        pageReady = false
        pageStarted = false
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        bridge.owner = self
        configuration.userContentController.add(bridge, name: "plannerVoice")
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 48), configuration: configuration)
        view.navigationDelegate = self
        view.uiDelegate = self
        webView = view
        var request = URLRequest(url: client.baseURL.appending(path: "v1/planner-voice/console"))
        request.setValue("Bearer \(client.token)", forHTTPHeaderField: "Authorization")
        view.load(request)
    }

    /// Starts the call once both the page and the session are ready, whichever finishes last.
    private func startConsoleIfReady() {
        guard !ended, pageReady, !pageStarted, let secret else { return }
        awaitsGreeting = !reconnecting
        guard let options = json(secret) else { return }
        pageStarted = true
        webView?.evaluateJavaScript("window.weekfit.start(\(options))")
    }

    private func failConnecting(_ message: String) {
        guard !ended else { return }
        ringback.stop()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "plannerVoice")
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView = nil
        offerOtherEngine = true
        phase = .failed(message)
    }

    func showFixture(_ name: String) {
        started = true
        let startedAt = Date().addingTimeInterval(-75)
        switch name {
        case "listening":
            phase = .listening
            connectedAt = startedAt
            inputLevel = 0.62
        case "speaking":
            phase = .speaking
            connectedAt = startedAt
            outputLevel = 0.74
        case "acting":
            phase = .acting
            connectedAt = startedAt
        case "ending":
            phase = .ending
            connectedAt = startedAt
        case "receipt":
            phase = .listening
            connectedAt = startedAt
            let spoken = PlannerOptionLocalization.localizedTitle(for: "Walk")
            let now = Date()
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            let day = planRealtimeDayLabel(
                day: planRealtimeDayString(tomorrow, calendar: calendar),
                today: planRealtimeDayString(now, calendar: calendar),
                tomorrow: planRealtimeDayString(tomorrow, calendar: calendar),
                language: languageCode,
                calendar: calendar
            )
            let title = String(format: WeekFitLocalizedString("planner.voice.receipt.moved"), spoken)
            let detail = "\(day) · 09:00"
            turns = [
                PlanVoiceTurn(
                    id: "fixture-you",
                    role: .user,
                    text: planRealtimeAsked(kind: "moved", spoken: spoken, day: day, time: "09:00", language: languageCode)
                ),
                PlanVoiceTurn(
                    id: "fixture-maya",
                    role: .maya,
                    text: planRealtimeMovedSpeak(spoken: spoken, day: day, time: "09:00", language: languageCode)
                )
            ]
            receipt = PlanVoiceReceipt(id: "fixture-receipt", title: title, detail: detail, success: true)
            notices = [receipt].compactMap { $0 }
        case "error":
            phase = .failed(WeekFitLocalizedString("planner.voice.connectionLost"))
            receipt = PlanVoiceReceipt(
                id: "fixture-error",
                title: WeekFitLocalizedString("planner.voice.receipt.failed"),
                detail: WeekFitLocalizedString("planner.voice.error.continue"),
                success: false
            )
            notices = [receipt].compactMap { $0 }
        default:
            phase = .connecting
        }
    }

    func retry() {
        guard case .failed = phase else { return }
        ended = false
        started = false
        reconnecting = true
        receipt = nil
        turns = []
        notices = []
        microphoneDenied = false
        offerOtherEngine = false
        phase = .connecting
        begin()
    }

    private func ensureMicrophone() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            microphoneDenied = false
            return true
        case .denied:
            microphoneDenied = true
            phase = .failed(WeekFitLocalizedString("planner.voice.micDenied"))
            return false
        case .undetermined:
            let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
            if !granted, !ended {
                microphoneDenied = true
                phase = .failed(WeekFitLocalizedString("planner.voice.micDenied"))
            }
            return granted && !ended
        @unknown default:
            return true
        }
    }

    private func noteReceipt(id: String, title: String, detail: String, success: Bool) {
        guard receiptIDs.insert(id).inserted else { return }
        let item = PlanVoiceReceipt(id: id, title: title, detail: detail, success: success)
        notices.append(item)
        receipt = item
    }

    private func noteExchange(id: String, request: String, reply: String) {
        let trimmedRequest = request.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRequest.isEmpty {
            turns.append(PlanVoiceTurn(id: id + "-you", role: .user, text: trimmedRequest))
        }
        if !trimmedReply.isEmpty {
            turns.append(PlanVoiceTurn(id: id + "-maya", role: .maya, text: trimmedReply))
        }
    }

    private func noteSaved(id: String, spoken: String, start: Date, minutes: Int, kind: String, reply: String) {
        let key = kind == "moved" ? "planner.voice.receipt.moved" : "planner.voice.receipt.added"
        let end = calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
        let startText = String(format: "%02d:%02d", calendar.component(.hour, from: start), calendar.component(.minute, from: start))
        let endText = String(format: "%02d:%02d", calendar.component(.hour, from: end), calendar.component(.minute, from: end))
        let now = Date()
        let today = planRealtimeDayString(now, calendar: calendar)
        let tomorrow = planRealtimeDayString(calendar.date(byAdding: .day, value: 1, to: now) ?? now, calendar: calendar)
        let day = planRealtimeDayLabel(
            day: planRealtimeDayString(start, calendar: calendar),
            today: today,
            tomorrow: tomorrow,
            language: callLanguage,
            calendar: calendar
        )
        let title = String(format: WeekFitLocalizedString(key), spoken)
        noteReceipt(
            id: id,
            title: title,
            detail: "\(day) · \(startText)–\(endText)",
            success: true
        )
        noteExchange(
            id: id,
            request: planRealtimeAsked(kind: kind, spoken: spoken, day: day, time: startText, language: callLanguage),
            reply: reply.isEmpty ? title : reply
        )
    }

    private func waitForLine(_ client: PlanRealtimeClient) async throws -> String {
        while !ended {
            try Task.checkCancellation()
            let line = try await client.placeInLine()
            lineTicket = line.ticket
            if line.state == "active" {
                await client.leaveLine(ticket: line.ticket)
                try await Task.sleep(nanoseconds: 500_000_000)
                continue
            }
            if line.state == "ready" {
                return line.ticket
            }
            phase = .queued(max(line.position, 1))
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        throw CancellationError()
    }

    private func startHeartbeat(_ ticket: String) {
        heartbeat?.cancel()
        heartbeat = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if Task.isCancelled { return }
                // A missed check is not a hangup. The call stays up until they end it.
                guard let client = try? await makeClient() else { continue }
                await client.beatLine(ticket: ticket)
                if let id = secret?.sessionId {
                    do {
                        struct Status: Decodable { let active: Bool; let remainingSeconds: Int }
                        let status: Status = try await WeekFitAIClient().request(path: "v2/ai/voice/status",
                            body: JSONEncoder().encode(["sessionId": id]))
                        remainingSeconds = status.remainingSeconds
                        if !status.active { end(); return }
                    } catch {
                        continue
                    }
                }
            }
        }
    }

    private func leaveLine(_ ticket: String) async {
        guard let client = try? await makeClient() else { return }
        await client.leaveLine(ticket: ticket)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
        startConsoleIfReady()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        ringback.stop()
        phase = .failed(WeekFitLocalizedString("planner.voice.sessionFailed"))
        end()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        ringback.stop()
        phase = .failed(WeekFitLocalizedString("planner.voice.sessionFailed"))
        end()
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(type == .microphone ? .grant : .deny)
    }

    private func applyState(_ payload: [String: Any]) {
        let value = payload["value"] as? String
        if value != "ending", value != "ended" {
            endingWatchdog?.cancel()
            endingWatchdog = nil
            endingAt = nil
        }
        switch value {
        case "connecting":
            phase = .connecting
        case "connected":
            phase = .connecting
        case "answered":
            // The tone keeps playing until Maya's greeting is audible; a reconnect has no greeting.
            if awaitsGreeting { armToneFallback() } else { pickUp() }
        case "voice":
            pickUp()
            phase = .speaking
        case "listening":
            pickUp()
            phase = .listening
        case "speaking":
            if connectedAt != nil { phase = .speaking }
        case "acting":
            phase = .acting
        case "ending":
            phase = .ending
            if endingAt == nil { endingAt = Date() }
            armEndingWatchdog()
        case "ended":
            guard !ended else { return }
            end()
        case "failed":
            ringback.stop()
            phase = .failed(WeekFitLocalizedString("planner.voice.sessionFailed"))
            end()
        default:
            break
        }
    }

    private func pickUp() {
        guard connectedAt == nil else { return }
        toneFallback?.cancel()
        toneFallback = nil
        ringback.stop()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        connectedAt = Date()
        webView?.evaluateJavaScript("window.weekfit && window.weekfit.answered()")
    }

    /// A greeting that never becomes audible must not leave the tone playing over the call.
    private func armToneFallback() {
        guard toneFallback == nil, connectedAt == nil else { return }
        toneFallback = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled, let self, !self.ended else { return }
            self.pickUp()
            if self.phase == .connecting { self.phase = .speaking }
        }
    }

    /// The page hangs up after the goodbye plays; if its timers stall (backgrounded web
    /// content, a lost audio event) the call must still end and stop billing.
    private func armEndingWatchdog() {
        guard endingWatchdog == nil else { return }
        endingWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled, let self, self.phase == .ending else { return }
            self.end()
        }
    }

    private func handleTool(callId: String, name: String, arguments: String) async {
        switch gate.begin(callId) {
        case .wait:
            return
        case .replay(let reply):
            deliver(callId: callId, reply: reply)
            return
        case .start:
            break
        }
        let reply = await performTool(callId: callId, name: name, arguments: arguments)
        gate.finish(callId, reply: reply)
        deliver(callId: callId, reply: reply)
    }

    private func performTool(callId: String, name: String, arguments: String) async -> String {
        switch name {
        case "set_call_language":
            if let language = planRealtimeCallLanguage(arguments) {
                callLanguage = language
            }
            return encode(PlanRealtimeToolReply(
                ok: true,
                saved: false,
                speak: planVoiceLanguageSwitch(callLanguage),
                error: nil
            ))
        case "log_water":
            return logWater(arguments)
        case "remind_water":
            return remindWater(arguments)
        case "create_activity":
            break
        default:
            return performPlanTool(name: name, arguments: arguments)
        }
        guard var draft = planRealtimeDraft(arguments) else {
            return encode(planRealtimeToolReply(action: .reject("unknown_activity"), speak: nil))
        }
        if draft.startTime.isEmpty, draft.place == "before" || draft.place == "after" {
            switch resolveAnchor(place: draft.place, anchorRef: draft.anchorRef, duration: draft.durationMinutes > 0 ? draft.durationMinutes : planRealtimeDefaultDuration(draft.catalogTitle)) {
            case .save(let day, let time, let duration):
                draft.date = day
                draft.startTime = time
                draft.durationMinutes = duration
            case .suggest(let day, let time, let duration):
                let spoken = placementSpeech(day: day, time: time, duration: duration)
                return encode(PlanRealtimeToolReply(ok: false, saved: false, speak: spoken, error: "time_conflict"))
            case .missing:
                return encode(notice("missing"))
            case .ambiguous:
                return encode(notice("missing"))
            }
        }
        guard !draft.startTime.isEmpty else {
            let ask = callLanguage.hasPrefix("ru") ? "Во сколько?" : "What time?"
            return encode(PlanRealtimeToolReply(ok: false, saved: false, speak: ask, error: "start_time_required"))
        }
        if let start = planRealtimeClockDate(day: draft.date, time: draft.startTime, calendar: calendar) {
            let today = planRealtimeDayString(Date(), calendar: calendar)
            if engine == "live", !planRealtimeLiveChangeAllowed(day: draft.date, today: today, start: start, now: Date()) {
                let otherDay = !draft.date.isEmpty && draft.date != today
                let spoken = planVoiceEngineLimit(language: callLanguage, past: !otherDay)
                return encode(PlanRealtimeToolReply(ok: false, saved: false, speak: spoken, error: "live_limit"))
            }
            let fingerprint = planRealtimeSaveFingerprint(
                catalogTitle: draft.catalogTitle,
                start: start,
                durationMinutes: draft.durationMinutes
            )
            if let replay = replayedSave(fingerprint, within: nil) {
                return replay
            }
            if let existing = activities.first(where: {
                $0.title == draft.catalogTitle
                    && $0.durationMinutes == draft.durationMinutes
                    && abs($0.date.timeIntervalSince(start)) < 1
            }) {
                let reply = encode(PlanRealtimeToolReply(ok: true, saved: true, speak: savedActivitySpeech(existing), error: nil))
                rememberSave(fingerprint, reply: reply)
                return reply
            }
        }
        let key = planRealtimeIdempotencyKey(callId)
        do {
            let client = try await makeClient()
            let commit = try await commit(client: client, key: key, draft: draft, transportFailed: false, lookedUp: false)
            let spoken = apply(commit, key: key)
            let reply = encode(spoken)
            if spoken.saved,
               let start = planRealtimeClockDate(day: draft.date, time: draft.startTime, calendar: calendar) {
                rememberSave(
                    planRealtimeSaveFingerprint(
                        catalogTitle: draft.catalogTitle,
                        start: start,
                        durationMinutes: draft.durationMinutes
                    ),
                    reply: reply
                )
            }
            return reply
        } catch PlanRealtimeClientError.transport {
            return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
        } catch {
            return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
        }
    }

    private func commit(
        client: PlanRealtimeClient,
        key: String,
        draft: PlanRealtimeActivityDraft,
        transportFailed: Bool,
        lookedUp: Bool
    ) async throws -> PlanRealtimeCommit {
        if planRealtimeTransportStep(transportFailed: transportFailed, lookedUp: lookedUp) == .lookup {
            do {
                return try await client.lookup(idempotencyKey: key)
            } catch PlanRealtimeClientError.notFound {
                return try await commit(client: client, key: key, draft: draft, transportFailed: false, lookedUp: true)
            }
        }
        let body: [String: Any] = [
            "idempotencyKey": key,
            "catalogTitle": draft.catalogTitle,
            "date": draft.date,
            "startTime": draft.startTime,
            "durationMinutes": draft.durationMinutes,
            "timeZone": calendar.timeZone.identifier,
            "now": ISO8601DateFormatter().string(from: Date()),
            "planningDay": planRealtimeDayString(planningDay, calendar: calendar),
            "language": callLanguage,
            "existing": planRealtimeBusyIntervals(activities, calendar: calendar),
        ]
        do {
            return try await client.commit(body)
        } catch PlanRealtimeClientError.transport {
            if lookedUp { throw PlanRealtimeClientError.transport }
            return try await commit(client: client, key: key, draft: draft, transportFailed: true, lookedUp: false)
        }
    }

    private func apply(_ commit: PlanRealtimeCommit, key: String) -> PlanRealtimeToolReply {
        let onPlan = commit.activity.flatMap { item -> Bool? in
            guard let start = planRealtimeInstant(item.start) else { return nil }
            return activities.contains {
                $0.title == item.catalogTitle
                    && $0.durationMinutes == item.durationMinutes
                    && abs($0.date.timeIntervalSince(start)) < 1
            }
        } ?? false
        let action = planRealtimeLocalAction(
            saved: commit.saved,
            alreadyApplied: applied.contains(key),
            alreadyOnPlan: onPlan,
            error: commit.error
        )
        switch action {
        case .reject:
            return planRealtimeToolReply(action: action, speak: commit.speak)
        case .alreadyPresent:
            return planRealtimeToolReply(action: action, speak: commit.speak)
        case .insert:
            guard let item = commit.activity,
                  let start = planRealtimeInstant(item.start),
                  let onSave else {
                return planRealtimeToolReply(action: .reject("save_failed"), speak: nil)
            }
            let request = PlanVoiceCreateRequest(
                catalogTitle: item.catalogTitle,
                plannerTypeTitle: item.plannerTypeTitle,
                start: start,
                durationMinutes: item.durationMinutes,
                idempotencyKey: key
            )
            do {
                let savedID = try onSave(request)
                applied.insert(key)
                voicedSources[savedID] = PlanRealtimeSourceActivity(
                    id: savedID,
                    title: item.catalogTitle,
                    date: start,
                    durationMinutes: item.durationMinutes,
                    completed: false,
                    skipped: false,
                    voice: true
                )
                noteSaved(
                    id: key,
                    spoken: PlannerOptionLocalization.localizedTitle(for: item.catalogTitle),
                    start: start,
                    minutes: item.durationMinutes,
                    kind: "added",
                    reply: commit.speak ?? ""
                )
                return PlanRealtimeToolReply(
                    ok: true,
                    saved: true,
                    speak: commit.speak,
                    error: nil,
                    schedule: todaySchedule()
                )
            } catch PlanViewModel.VoiceSaveError.timeConflict {
                let spoken = conflictSpeak(start: start, minutes: item.durationMinutes, excluding: nil)
                noteReceipt(id: key + "-conflict", title: WeekFitLocalizedString("planner.voice.receipt.failed"), detail: spoken, success: false)
                return PlanRealtimeToolReply(ok: false, saved: false, speak: spoken, error: "time_conflict")
            } catch {
                let again = WeekFitLocalizedString("planner.voice.error.continue")
                noteReceipt(id: key + "-failed", title: WeekFitLocalizedString("planner.voice.receipt.failed"), detail: again, success: false)
                return planRealtimeToolReply(action: .reject("save_failed"), speak: nil)
            }
        }
    }

    private func performPlanTool(name: String, arguments: String) -> String {
        let agenda = currentAgenda()
        let now = Date()
        let today = planRealtimeDayString(now, calendar: calendar)
        let tomorrow = planRealtimeDayString(
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now,
            calendar: calendar
        )
        switch name {
        case "list_plan":
            guard let scope = planRealtimeListScope(arguments) else {
                return encode(notice("missing"))
            }
            let items = agenda
                .filter { $0.scope == scope }
                .map { (spoken: $0.spoken, startTime: $0.startTime) }
            return encode(PlanRealtimeToolReply(
                ok: true,
                saved: false,
                speak: planRealtimeListSpeak(scope: scope, items: items, language: callLanguage),
                error: nil,
                schedule: agenda.filter { $0.scope == scope }.map {
                    PlanRealtimeScheduleRow(
                        ref: $0.ref,
                        title: $0.title,
                        startTime: $0.startTime,
                        durationMinutes: $0.durationMinutes,
                        done: $0.scope == "today_done"
                    )
                }
            ))
        case "delete_activity":
            guard let ref = planRealtimeDeleteRef(arguments),
                  let entry = agenda.first(where: { $0.ref == ref }),
                  let onDelete else {
                return encode(notice("missing"))
            }
            if activities.first(where: { $0.id == entry.activityID })?.isCompleted == true {
                return encode(notice("already_done"))
            }
            if engine == "live", entry.day != planRealtimeDayString(Date(), calendar: calendar) {
                return encode(PlanRealtimeToolReply(ok: false, saved: false, speak: planVoiceEngineLimit(language: callLanguage, past: false), error: "live_limit"))
            }
            do {
                try onDelete(entry.activityID)
                removedIDs.insert(entry.activityID)
                voicedSources.removeValue(forKey: entry.activityID)
                let day = dayLabel(entry.day, today: today, tomorrow: tomorrow)
                let reply = planRealtimeRemovedSpeak(spoken: entry.spoken, day: day, language: callLanguage)
                noteReceipt(
                    id: entry.activityID,
                    title: String(format: WeekFitLocalizedString("planner.voice.receipt.removed"), entry.spoken),
                    detail: day,
                    success: true
                )
                noteExchange(
                    id: entry.activityID,
                    request: planRealtimeAsked(kind: "removed", spoken: entry.spoken, day: day, time: "", language: callLanguage),
                    reply: reply
                )
                return encode(PlanRealtimeToolReply(
                    ok: true,
                    saved: true,
                    speak: reply,
                    error: nil,
                    schedule: todaySchedule()
                ))
            } catch PlanViewModel.VoiceSaveError.alreadyDone {
                return encode(notice("already_done"))
            } catch {
                return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
            }
        case "update_activity":
            guard let draft = planRealtimeEditDraft(arguments),
                  let entry = agenda.first(where: { $0.ref == draft.ref }),
                  let onUpdate else {
                return encode(notice("missing"))
            }
            let activity = activities.first(where: { $0.id == entry.activityID })
            let remembered = voicedSources[entry.activityID]
            if activity == nil, remembered == nil {
                return encode(notice("missing"))
            }
            if activity?.isCompleted == true {
                return encode(notice("already_done"))
            }
            let activityID = activity?.id ?? entry.activityID
            let originalDate = activity?.date ?? remembered?.date ?? Date()
            let originalTitle = activity?.title ?? remembered?.title ?? entry.title
            let originalDuration = activity?.durationMinutes ?? remembered?.durationMinutes ?? entry.durationMinutes
            if engine == "live" {
                let today = planRealtimeDayString(Date(), calendar: calendar)
                let day = draft.date.isEmpty ? planRealtimeDayString(originalDate, calendar: calendar) : draft.date
                if !planRealtimeLiveChangeAllowed(day: day, today: today, start: nil, now: Date()), day != today {
                    return encode(PlanRealtimeToolReply(ok: false, saved: false, speak: planVoiceEngineLimit(language: callLanguage, past: false), error: "live_limit"))
                }
            }
            let sameKind = draft.catalogTitle.isEmpty || draft.catalogTitle == originalTitle
            if draft.date.isEmpty && draft.startTime.isEmpty && draft.durationMinutes == 0 && sameKind {
                return encode(notice("unchanged"))
            }
            guard let start = planRealtimeMergedStart(
                day: draft.date,
                time: draft.startTime,
                original: originalDate,
                calendar: calendar
            ) else {
                return encode(notice("missing"))
            }
            if draft.durationMinutes != 0 && (draft.durationMinutes < 1 || draft.durationMinutes > 360) {
                return encode(notice("missing"))
            }
            let duration = draft.durationMinutes == 0 ? originalDuration : draft.durationMinutes
            if engine == "live", !planRealtimeLiveChangeAllowed(day: planRealtimeDayString(start, calendar: calendar), today: planRealtimeDayString(Date(), calendar: calendar), start: start, now: Date()) {
                let today = planRealtimeDayString(Date(), calendar: calendar)
                let past = planRealtimeDayString(start, calendar: calendar) == today
                return encode(PlanRealtimeToolReply(ok: false, saved: false, speak: planVoiceEngineLimit(language: callLanguage, past: past), error: "live_limit"))
            }
            do {
                try onUpdate(PlanVoiceUpdateRequest(
                    activityID: activityID,
                    start: start,
                    durationMinutes: duration,
                    catalogTitle: draft.catalogTitle.isEmpty ? nil : draft.catalogTitle
                ))
                if let activity {
                    activity.date = start
                    activity.durationMinutes = duration
                    if !draft.catalogTitle.isEmpty { activity.title = draft.catalogTitle }
                }
                voicedSources[activityID] = PlanRealtimeSourceActivity(
                    id: activityID,
                    title: draft.catalogTitle.isEmpty ? originalTitle : draft.catalogTitle,
                    date: start,
                    durationMinutes: duration,
                    completed: false,
                    skipped: false,
                    voice: true
                )
                let day = planRealtimeDayString(start, calendar: calendar)
                let parts = calendar.dateComponents([.hour, .minute], from: start)
                let time = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
                let spoken = draft.catalogTitle.isEmpty ? entry.spoken : PlannerOptionLocalization.localizedTitle(for: draft.catalogTitle)
                let reply = planRealtimeMovedSpeak(
                    spoken: spoken,
                    day: dayLabel(day, today: today, tomorrow: tomorrow),
                    time: time,
                    language: callLanguage
                )
                noteSaved(id: activityID + time, spoken: spoken, start: start, minutes: duration, kind: "moved", reply: reply)
                return encode(PlanRealtimeToolReply(
                    ok: true,
                    saved: true,
                    speak: reply,
                    error: nil,
                    schedule: todaySchedule()
                ))
            } catch PlanViewModel.VoiceSaveError.timeConflict {
                let spoken = conflictSpeak(start: start, minutes: duration, excluding: activityID)
                noteReceipt(id: activityID + "-conflict", title: WeekFitLocalizedString("planner.voice.receipt.failed"), detail: spoken, success: false)
                return encode(PlanRealtimeToolReply(ok: false, saved: false, speak: spoken, error: "time_conflict"))
            } catch PlanViewModel.VoiceSaveError.alreadyDone {
                return encode(notice("already_done"))
            } catch {
                return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
            }
        default:
            return encode(planRealtimeToolReply(action: .reject("unknown_activity"), speak: nil))
        }
    }

    private func replayedSave(_ fingerprint: String, within seconds: TimeInterval?) -> String? {
        guard let item = savedReplies[fingerprint] else { return nil }
        return planRealtimeReplayReply(reply: item.reply, savedAt: item.at, now: Date(), within: seconds)
    }

    private func rememberSave(_ fingerprint: String, reply: String) {
        savedReplies[fingerprint] = (reply, Date())
    }

    private func savedActivitySpeech(_ activity: PlannedActivity) -> String {
        let title = PlannerOptionLocalization.localizedTitle(for: activity.title)
        let end = calendar.date(byAdding: .minute, value: activity.durationMinutes, to: activity.date) ?? activity.date
        if callLanguage.hasPrefix("ru") {
            let from = planRealtimeRussianRangeClock(
                hour: calendar.component(.hour, from: activity.date),
                minute: calendar.component(.minute, from: activity.date)
            )
            let to = planRealtimeRussianRangeClock(
                hour: calendar.component(.hour, from: end),
                minute: calendar.component(.minute, from: end)
            )
            return "Записала \(title.lowercased()) на \(savedDayLabel(activity.date)), с \(from) до \(to)."
        }
        return "Saved \(title) at \(planRealtimeClockText(activity.date, calendar: calendar))."
    }

    private func savedDayLabel(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return callLanguage.hasPrefix("ru") ? "сегодня" : "today" }
        if calendar.isDateInTomorrow(date) { return callLanguage.hasPrefix("ru") ? "завтра" : "tomorrow" }
        return planRealtimeDayString(date, calendar: calendar)
    }

    private func conflictSpeak(start: Date, minutes: Int, excluding: String?) -> String {
        let end = start.addingTimeInterval(TimeInterval(max(minutes, 1) * 60))
        let other = activities.first { activity in
            guard activity.id != excluding, !removedIDs.contains(activity.id) else { return false }
            let otherEnd = activity.date.addingTimeInterval(TimeInterval(max(activity.durationMinutes, 1) * 60))
            return activity.date < end && otherEnd > start
        }
        if let other {
            let title = PlannerOptionLocalization.localizedTitle(for: other.title)
            return String(format: WeekFitLocalizedString("planner.voice.conflict.with"), title)
        }
        return planRealtimePlanNotice("conflict", language: callLanguage)
    }

    private func logWater(_ arguments: String) -> String {
        guard let milliliters = planRealtimeWaterMilliliters(arguments) else {
            let ask = callLanguage.hasPrefix("ru") ? "Сколько миллилитров?" : "How many milliliters?"
            return encode(PlanRealtimeToolReply(ok: false, saved: false, speak: ask, error: "amount_required"))
        }
        guard let onLogWater else {
            return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
        }
        do {
            if let replay = replayedSave("water|\(milliliters)", within: 60) {
                return replay
            }
            let stored = try onLogWater(milliliters)
            guard stored >= 50 else {
                return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
            }
            let speak = callLanguage.hasPrefix("ru")
                ? "Записала \(stored) миллилитров уже выпитой воды."
                : "Logged \(stored) milliliters of water already drunk."
            noteReceipt(id: "water-\(stored)", title: speak, detail: "\(stored) мл", success: true)
            let reply = encode(PlanRealtimeToolReply(ok: true, saved: true, speak: speak, error: nil))
            rememberSave("water|\(milliliters)", reply: reply)
            rememberSave("water|\(stored)", reply: reply)
            return reply
        } catch {
            return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
        }
    }

    private func remindWater(_ arguments: String) -> String {
        guard let draft = planRealtimeRemindDraft(arguments) else {
            return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
        }
        let placed: (day: String, time: String, duration: Int)
        if draft.startTime.isEmpty, draft.place == "before" || draft.place == "after" {
            switch resolveAnchor(place: draft.place, anchorRef: draft.anchorRef, duration: 5) {
            case .save(let day, let time, let duration):
                placed = (day, time, duration)
            case .suggest(let day, let time, let duration):
                return encode(PlanRealtimeToolReply(ok: false, saved: false, speak: placementSpeech(day: day, time: time, duration: duration), error: "time_conflict"))
            case .missing, .ambiguous:
                return encode(notice("missing"))
            }
        } else if !draft.startTime.isEmpty {
            let day = draft.date.isEmpty ? planRealtimeDayString(Date(), calendar: calendar) : draft.date
            guard let start = planRealtimeClockDate(day: day, time: draft.startTime, calendar: calendar) else {
                return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
            }
            if anchorBusy(start, duration: 5) {
                return encode(PlanRealtimeToolReply(ok: false, saved: false, speak: planRealtimePlanNotice("conflict", language: callLanguage), error: "time_conflict"))
            }
            placed = (day, draft.startTime, 5)
        } else {
            let ask = callLanguage.hasPrefix("ru") ? "Во сколько напомнить?" : "What time should I remind you?"
            return encode(PlanRealtimeToolReply(ok: false, saved: false, speak: ask, error: "start_time_required"))
        }
        guard let start = planRealtimeClockDate(day: placed.day, time: placed.time, calendar: calendar),
              let onRemindWater else {
            return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
        }
        let fingerprint = planRealtimeSaveFingerprint(catalogTitle: "Drink Water", start: start, durationMinutes: placed.duration)
        if let replay = replayedSave(fingerprint, within: nil) {
            return replay
        }
        if activities.contains(where: {
            $0.title == "Drink Water" && $0.durationMinutes <= 5 && abs($0.date.timeIntervalSince(start)) < 1
        }) {
            let speak = anchorSpeech(day: placed.day, time: placed.time, duration: placed.duration, saved: true)
            let reply = encode(PlanRealtimeToolReply(ok: true, saved: true, speak: speak, error: nil))
            rememberSave(fingerprint, reply: reply)
            return reply
        }
        do {
            try onRemindWater(start, placed.duration)
            let speak = anchorSpeech(day: placed.day, time: placed.time, duration: placed.duration, saved: true)
            noteReceipt(id: "remind-\(placed.day)-\(placed.time)", title: speak, detail: placed.time, success: true)
            let reply = encode(PlanRealtimeToolReply(ok: true, saved: true, speak: speak, error: nil))
            rememberSave(fingerprint, reply: reply)
            return reply
        } catch {
            return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
        }
    }

    private func resolveAnchor(place: String, anchorRef: String, duration: Int) -> PlanRealtimeAnchorResult {
        planRealtimeResolveAnchor(
            place: place,
            anchorRef: anchorRef,
            durationMinutes: duration,
            agenda: currentAgenda(),
            calendar: calendar
        )
    }

    private func anchorBusy(_ start: Date, duration: Int) -> Bool {
        let busy = currentAgenda().compactMap { entry -> (Date, Date)? in
            guard let itemStart = planRealtimeClockDate(day: entry.day, time: entry.startTime, calendar: calendar) else { return nil }
            let end = calendar.date(byAdding: .minute, value: max(entry.durationMinutes, 1), to: itemStart) ?? itemStart
            return (itemStart, end)
        }
        return planRealtimeOverlaps(start, duration: duration, busy: busy, calendar: calendar)
    }

    private func placementSpeech(day: String, time: String, duration: Int) -> String {
        guard let start = planRealtimeClockDate(day: day, time: time, calendar: calendar) else { return time }
        let end = calendar.date(byAdding: .minute, value: duration, to: start) ?? start
        let startParts = calendar.dateComponents([.hour, .minute], from: start)
        let endParts = calendar.dateComponents([.hour, .minute], from: end)
        if callLanguage.hasPrefix("ru") {
            let from = planRealtimeRussianRangeClock(hour: startParts.hour ?? 0, minute: startParts.minute ?? 0)
            let to = planRealtimeRussianRangeClock(hour: endParts.hour ?? 0, minute: endParts.minute ?? 0)
            return "Это время занято. Ближайшее свободное — с \(from) до \(to). Поставить?"
        }
        let from = String(format: "%02d:%02d", startParts.hour ?? 0, startParts.minute ?? 0)
        let to = String(format: "%02d:%02d", endParts.hour ?? 0, endParts.minute ?? 0)
        return "That time is taken. The nearest free time is \(from) to \(to). Should I use it?"
    }

    private func anchorSpeech(day: String, time: String, duration: Int, saved: Bool) -> String {
        guard let start = planRealtimeClockDate(day: day, time: time, calendar: calendar) else { return time }
        let end = calendar.date(byAdding: .minute, value: duration, to: start) ?? start
        let startParts = calendar.dateComponents([.hour, .minute], from: start)
        let endParts = calendar.dateComponents([.hour, .minute], from: end)
        if callLanguage.hasPrefix("ru") {
            let from = planRealtimeRussianRangeClock(hour: startParts.hour ?? 0, minute: startParts.minute ?? 0)
            let to = planRealtimeRussianRangeClock(hour: endParts.hour ?? 0, minute: endParts.minute ?? 0)
            if saved {
                return "Поставила напоминание выпить воду с \(from) до \(to). Это не выпитая вода."
            }
            return "Рядом это время занято. Ближайшее свободное — с \(from) до \(to). Поставить?"
        }
        let from = String(format: "%02d:%02d", startParts.hour ?? 0, startParts.minute ?? 0)
        let to = String(format: "%02d:%02d", endParts.hour ?? 0, endParts.minute ?? 0)
        if saved {
            return "Set a reminder to drink water from \(from) to \(to). That is not water already drunk."
        }
        return "That time is taken. The nearest free time is \(from) to \(to). Should I use it?"
    }

    private func notice(_ kind: String) -> PlanRealtimeToolReply {
        PlanRealtimeToolReply(
            ok: kind == "unchanged",
            saved: kind == "unchanged",
            speak: planRealtimePlanNotice(kind, language: callLanguage),
            error: kind == "unchanged" ? nil : kind
        )
    }

    private func dayLabel(_ day: String, today: String, tomorrow: String) -> String {
        planRealtimeDayLabel(day: day, today: today, tomorrow: tomorrow, language: callLanguage, calendar: calendar)
    }

    private func currentAgenda() -> [PlanRealtimeAgendaEntry] {
        var sources = activities.compactMap { activity -> PlanRealtimeSourceActivity? in
            guard !removedIDs.contains(activity.id) else { return nil }
            return PlanRealtimeSourceActivity(
                id: activity.id,
                title: activity.title,
                date: activity.date,
                durationMinutes: activity.durationMinutes,
                completed: activity.isCompleted,
                skipped: activity.isSkipped,
                voice: planRealtimeVoiceInclude(activity)
            )
        }
        let known = Set(sources.map(\.id))
        for (id, extra) in voicedSources where !known.contains(id) && !removedIDs.contains(id) {
            sources.append(extra)
        }
        return planRealtimeAgenda(
            sources,
            now: Date(),
            calendar: calendar,
            book: &refBook,
            spoken: PlannerOptionLocalization.localizedTitle(for:)
        )
    }

    private func todaySchedule() -> [PlanRealtimeScheduleRow] {
        currentAgenda().filter { $0.scope == "today_planned" || $0.scope == "today_done" }.map {
            PlanRealtimeScheduleRow(
                ref: $0.ref,
                title: $0.title,
                startTime: $0.startTime,
                durationMinutes: $0.durationMinutes,
                done: $0.scope == "today_done"
            )
        }
    }

    private func deliver(callId: String, reply: String) {
        guard let webView else { return }
        webView.evaluateJavaScript("window.weekfit.toolResult(\(jsLiteral(callId)), \(reply))")
    }

    private func makeClient() async throws -> PlanRealtimeClient {
        if WeekFitAIBilling.refused { throw WeekFitAIUsageError.misconfigured }
        let token = try await PhotoFoodFirebaseAuth.idToken()
        return PlanRealtimeClient(baseURL: WeekFitCloudAPI.foodPhotoBaseURL, token: token)
    }

    private func encode(_ reply: PlanRealtimeToolReply) -> String {
        let data = try? JSONSerialization.data(withJSONObject: reply.jsonObject)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? #"{"ok":false,"saved":false,"error":"save_failed"}"#
    }

    private func json(_ secret: PlanRealtimeSessionSecret) -> String? {
        let object: [String: Any] = [
            "ephemeralKey": secret.value,
            "managed": secret.managed ?? false,
            "idleSeconds": secret.idleSeconds,
            "language": callLanguage,
            "givenName": ProfileService.resolvedGivenName(),
            "reconnected": reconnecting,
            "engine": engine,
        ]
        reconnecting = false
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(data: data, encoding: .utf8)
    }

}

private func jsLiteral(_ value: String) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: [value]),
          let text = String(data: data, encoding: .utf8),
          text.count >= 2 else { return "\"\"" }
    return String(text.dropFirst().dropLast())
}

private final class PlanRealtimeScriptBridge: NSObject, WKScriptMessageHandler {
    weak var owner: PlanRealtimeSessionController?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        owner?.receive(message.body)
    }
}

@MainActor
private final class PlanVoiceRingback {
    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)
    }

    func stop() {}
}

struct PlanVoiceTurn: Equatable, Identifiable {
    enum Role: Equatable { case user, maya }
    var id: String
    var role: Role
    var text: String
}

struct PlanVoiceReceipt: Equatable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var success: Bool
}

struct PlanRealtimeVoiceSheet: View {
    var planningDay: Date
    var activities: [PlannedActivity]
    var dayContext: PlanVoiceDayContext = PlanVoiceDayContext()
    var onSave: (PlanVoiceCreateRequest) throws -> String
    var onUpdate: (PlanVoiceUpdateRequest) throws -> Void
    var onDelete: (String) throws -> Void
    var onLogWater: (Int) throws -> Int = { _ in throw PlanViewModel.VoiceSaveError.persistence }
    var onRemindWater: (Date, Int) throws -> Void = { _, _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var languageManager: AppLanguageManager
    @StateObject private var controller = PlanRealtimeSessionController()
    @State private var showAIUsage = false
    @State private var speakerOn = true

    var body: some View {
        let _ = languageManager.selectedLanguage
        let _ = controller.update(
            planningDay: planningDay,
            activities: activities,
            onSave: onSave,
            onUpdate: onUpdate,
        onDelete: onDelete,
        onLogWater: onLogWater,
        onRemindWater: onRemindWater,
        languageCode: languageManager.selectedLanguage.rawValue,
            dayContext: dayContext
        )

        ZStack {
            callCanvas.ignoresSafeArea()
            VStack(spacing: 0) {
                callHeader
                callIdentity
                portrait
                waveform
                    .padding(.top, 14)
                callStatus
                    .padding(.top, 10)
                if WeekFitAIBilling.enabled, case .failed = controller.phase {
                    Button(WeekFitLocalizedString("ai.usage.title")) { showAIUsage = true }
                        .padding(.top, 12)
                }
                failureBlock
                    .padding(.top, 12)
                callMessages
                controls
            }
            if let webView = controller.webView {
                PlanRealtimeWebHost(webView: webView)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("planner.voice.realtime")
        .onAppear {
            if let phase = WeekFitUITestSupport.mayaPreviewPhase {
                controller.showFixture(phase)
            } else {
                controller.begin()
            }
        }
        .sheet(isPresented: $showAIUsage) { WeekFitAIBalanceSheet() }
        .onDisappear { controller.end() }
        .onChange(of: controller.phase) { _, phase in
            if phase == .ended {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { dismiss() }
            }
        }
        .onChange(of: controller.receipt?.id) { _, _ in
            guard let receipt = controller.receipt else { return }
            let announcement = receipt.detail.isEmpty ? receipt.title : "\(receipt.title). \(receipt.detail)"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }

    private var callCanvas: Color {
        palette.isLight
            ? Color(red: 0.965, green: 0.945, blue: 0.925)
            : Color(red: 0.075, green: 0.072, blue: 0.068)
    }

    private var chipFill: Color {
        palette.isLight ? Color.white.opacity(0.72) : Color.white.opacity(0.08)
    }

    private var callInk: Color {
        palette.isLight ? Color(red: 0.14, green: 0.12, blue: 0.11) : Color(red: 0.96, green: 0.94, blue: 0.90)
    }

    private var callMuted: Color {
        palette.isLight ? Color(red: 0.45, green: 0.40, blue: 0.36) : Color.white.opacity(0.55)
    }

    private var callHeader: some View {
        HStack {
            callCircleButton(systemName: "chevron.left", identifier: "planner.voice.realtime.back") {
                controller.end()
                dismiss()
            }
            Spacer(minLength: 0)
            PlanRealtimeRouteButton(tint: UIColor(callInk))
                .frame(width: 18, height: 18)
                .frame(width: 40, height: 40)
                .background(Circle().fill(chipFill))
                .accessibilityIdentifier("planner.voice.realtime.route")
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private var callIdentity: some View {
        VStack(spacing: 6) {
            Text(WeekFitLocalizedString("planner.voice.call.brand"))
                .font(.system(size: 12, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(callMuted)
            Text(WeekFitLocalizedString("planner.voice.maya"))
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(callInk)
            Text(WeekFitLocalizedString("planner.voice.call.role"))
                .font(.system(size: 16))
                .foregroundStyle(callMuted)
        }
        .padding(.top, 2)
    }

    private func callCircleButton(systemName: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(chipFill))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var callStatus: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusDot)
                    .frame(width: 7, height: 7)
                Text(statusText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(callInk)
            }
            if let connectedAt = controller.connectedAt {
                TimelineView(.periodic(from: connectedAt, by: 1)) { context in
                    let shown = min(context.date, controller.endingAt ?? context.date)
                    let seconds = max(0, Int(shown.timeIntervalSince(connectedAt)))
                    Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                        .font(.system(size: 16, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(callMuted)
                }
            }
            Text(WeekFitLocalizedString("planner.voice.call.pace"))
                .font(.system(size: 15))
                .foregroundStyle(callMuted)
                .padding(.top, 8)
            if let queueDetail {
                Text(queueDetail)
                    .font(.footnote)
                    .foregroundStyle(callMuted)
                    .multilineTextAlignment(.center)
            }
            if let seconds = controller.remainingSeconds, seconds <= 60 {
                Text(WeekFitLocalizedString("ai.usage.lastMinute"))
                    .font(.footnote)
                    .foregroundStyle(callMuted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("planner.voice.realtime.status")
        .padding(.horizontal, 24)
    }

    private var statusDot: Color {
        switch controller.phase {
        case .speaking, .listening, .acting, .connected:
            return Color(red: 0.78, green: 0.64, blue: 0.42)
        default:
            return callMuted.opacity(0.7)
        }
    }

    @ViewBuilder
    private var failureBlock: some View {
        if case .failed(let message) = controller.phase {
            VStack(spacing: 8) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                Button(WeekFitLocalizedString("planner.voice.retry")) {
                    controller.retry()
                }
                .font(.body.weight(.semibold))
                if controller.microphoneDenied {
                    Button(WeekFitLocalizedString("planner.voice.openSettings")) {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .font(.body.weight(.semibold))
                }
                if controller.offerOtherEngine {
                    Button(planVoiceEngineOffer(PlanVoiceEngine.alternate, language: languageManager.selectedLanguage.rawValue)) {
                        PlanVoiceEngine.choose(PlanVoiceEngine.alternate)
                        controller.retry()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }

    private var portrait: some View {
        Image("maya-portrait")
            .resizable()
            .scaledToFill()
            .frame(width: 168, height: 168)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(
                    Color(red: 0.78, green: 0.66, blue: 0.48).opacity(palette.isLight ? 0.45 : 0.9),
                    lineWidth: 1.5
                )
            }
            .shadow(color: Color(red: 0.72, green: 0.55, blue: 0.32).opacity(palette.isLight ? 0.16 : 0.55), radius: palette.isLight ? 18 : 28)
            .padding(.top, 10)
            .accessibilityHidden(true)
    }

    private var motionReduced: Bool {
        reduceMotion || WeekFitUITestSupport.forcesReduceMotion
    }

    private var markLevel: CGFloat {
        switch controller.phase {
        case .listening:
            return CGFloat(controller.inputLevel)
        case .speaking:
            return CGFloat(controller.outputLevel)
        default:
            return 0
        }
    }

    private var waveform: some View {
        let active = !motionReduced && {
            switch controller.phase {
            case .listening, .speaking, .connecting, .queued: return true
            default: return false
            }
        }()
        return TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !active)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.4) {
                ForEach(0..<waveShape.count, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(waveColor)
                        .frame(width: 1.6, height: waveHeight(index: index, time: time))
                }
            }
            .frame(height: 46)
        }
        .accessibilityHidden(true)
    }

    private var waveColor: Color {
        palette.isLight
            ? Color(red: 0.55, green: 0.42, blue: 0.35)
            : Color(red: 0.77, green: 0.64, blue: 0.46)
    }

    /// Fixed silhouette from the call mock, so neighboring lines stay different heights.
    private var waveShape: [CGFloat] {
        [0.16, 0.28, 0.46, 0.22, 0.58, 0.82, 0.36, 0.64, 0.94, 0.48,
         0.30, 0.72, 1.00, 0.54, 0.38, 0.86, 0.62, 0.44, 0.90, 0.70,
         0.34, 0.78, 0.52, 0.26, 0.66, 0.42, 0.22, 0.50, 0.32, 0.18, 0.28, 0.14]
    }

    private func waveHeight(index: Int, time: TimeInterval) -> CGFloat {
        let shape = Double(waveShape[index])
        let sample: Double
        if motionReduced {
            sample = shape
        } else {
            let flutter = 0.78 + 0.22 * abs(sin(time * 7.2 + Double(index) * 1.15))
            sample = shape * flutter
        }
        let loud = min(1, max(0.42, markLevel * 1.7))
        return max(2, 42 * loud * sample)
    }

    /// The slot is always there, so the portrait does not move when the result appears.
    private var callMessages: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            ZStack(alignment: .bottom) {
                Color.clear
                if let receipt = controller.receipt {
                    receiptCard(receipt)
                }
            }
            .frame(height: 116)
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .animation(nil, value: controller.receipt?.id)
    }

    private func receiptCard(_ receipt: PlanVoiceReceipt) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: receipt.success ? "calendar" : "exclamationmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(receipt.success ? Color(red: 0.62, green: 0.46, blue: 0.22) : Color(red: 0.91, green: 0.19, blue: 0.22))
                .frame(width: 42, height: 42)
                .background {
                    Circle().fill(receipt.success ? Color(red: 0.96, green: 0.90, blue: 0.78) : Color(red: 0.91, green: 0.19, blue: 0.22).opacity(0.12))
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !receipt.detail.isEmpty {
                    Text(receipt.detail)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.isLight ? Color(red: 1, green: 0.99, blue: 0.975) : palette.cardSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color(red: 0.45, green: 0.38, blue: 0.30).opacity(palette.isLight ? 0.10 : 0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("planner.voice.realtime.receipt")
    }

    private var controls: some View {
        HStack(alignment: .center, spacing: 0) {
            labeledControl(
                title: WeekFitLocalizedString("planner.voice.call.mic"),
                identifier: "planner.voice.realtime.mute"
            ) {
                Button {
                    controller.toggleMute()
                } label: {
                    Image(systemName: controller.muted ? "mic.slash" : "mic")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(callInk.opacity(controller.connectedAt == nil ? 0.35 : 0.9))
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(chipFill))
                }
                .disabled(controller.connectedAt == nil)
                .accessibilityValue(Text(controller.muted ? WeekFitLocalizedString("planner.voice.micOff") : statusText))
            }

            labeledControl(
                title: WeekFitLocalizedString("planner.voice.call.end"),
                identifier: "planner.voice.realtime.end",
                titleColor: callInk
            ) {
                Button {
                    controller.end()
                    dismiss()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 74)
                        .background(Circle().fill(Color(red: 0.90, green: 0.29, blue: 0.27)))
                }
            }

            labeledControl(
                title: WeekFitLocalizedString("planner.voice.call.speaker"),
                identifier: "planner.voice.realtime.speaker"
            ) {
                Button {
                    speakerOn.toggle()
                    try? AVAudioSession.sharedInstance().overrideOutputAudioPort(speakerOn ? .speaker : .none)
                } label: {
                    Image(systemName: speakerOn ? "speaker.wave.2" : "speaker.slash")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(callInk.opacity(0.9))
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(chipFill))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.isLight ? Color.white.opacity(0.72) : Color.white.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(palette.isLight ? 0.8 : 0.08), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func labeledControl<Content: View>(
        title: String,
        identifier: String,
        titleColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 8) {
            content()
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(titleColor ?? callMuted)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    private var queueDetail: String? {
        guard case .queued(let position) = controller.phase, position > 1 else { return nil }
        return String(format: WeekFitLocalizedString("planner.voice.queue.ahead"), position - 1)
    }

    private var statusText: String {
        switch controller.phase {
        case .connecting:
            return WeekFitLocalizedString("planner.voice.status.connecting")
        case .queued:
            return WeekFitLocalizedString("planner.voice.queue.waiting")
        case .connected, .listening:
            return WeekFitLocalizedString("planner.voice.status.listening")
        case .speaking:
            return WeekFitLocalizedString("planner.voice.call.speaking")
        case .acting:
            return WeekFitLocalizedString("planner.voice.status.thinking")
        case .ending:
            return WeekFitLocalizedString("planner.voice.status.ending")
        case .ended:
            return WeekFitLocalizedString("planner.voice.state.ended")
        case .failed:
            return WeekFitLocalizedString("planner.voice.connectionLost")
        }
    }

}

private struct PlanRealtimeRouteButton: UIViewRepresentable {
    var tint: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = tint
        view.activeTintColor = tint
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tint
        uiView.activeTintColor = tint
    }
}

private struct PlanRealtimeWebHost: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

extension PlanRealtimeSessionController {
    func update(
        planningDay: Date,
        activities: [PlannedActivity],
        onSave: @escaping (PlanVoiceCreateRequest) throws -> String,
        onUpdate: @escaping (PlanVoiceUpdateRequest) throws -> Void,
        onDelete: @escaping (String) throws -> Void,
        onLogWater: @escaping (Int) throws -> Int,
        onRemindWater: @escaping (Date, Int) throws -> Void,
        languageCode: String,
        dayContext: PlanVoiceDayContext
    ) {
        self.planningDay = planningDay
        self.activities = activities
        self.onSave = onSave
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onLogWater = onLogWater
        self.onRemindWater = onRemindWater
        self.languageCode = languageCode
        self.dayContext = dayContext
    }
}

func planRealtimeVoiceInclude(_ activity: PlannedActivity) -> Bool {
    switch activity.timelineEventKind {
    case .food, .drink, .bodyWeight, .mood, .coachNote:
        return false
    case .workout, .recovery, .sauna, .calendar, .sleep, .plannedActivity:
        return true
    }
}

nonisolated func planRealtimeDayString(_ date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}

nonisolated func planRealtimeInstant(_ text: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: text) { return date }
    return ISO8601DateFormatter().date(from: text)
}

nonisolated func planRealtimeDraft(_ arguments: String) -> PlanRealtimeActivityDraft? {
    guard let data = arguments.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let title = object["catalogTitle"] as? String,
          !title.isEmpty else { return nil }
    return PlanRealtimeActivityDraft(
        catalogTitle: title,
        date: object["date"] as? String ?? "",
        startTime: object["startTime"] as? String ?? "",
        durationMinutes: object["durationMinutes"] as? Int ?? 0,
        place: object["place"] as? String ?? "",
        anchorRef: object["anchorRef"] as? String ?? ""
    )
}

func planRealtimeBusyIntervals(
    _ activities: [PlannedActivity],
    calendar: Calendar
) -> [[String: Any]] {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return activities.compactMap { activity in
        guard !activity.isSkipped else { return nil }
        let end = calendar.date(byAdding: .minute, value: max(activity.durationMinutes, 15), to: activity.date) ?? activity.date
        return [
            "start": formatter.string(from: activity.date),
            "end": formatter.string(from: end),
            "blocks": activity.blocksPlannerTime,
        ]
    }
}
