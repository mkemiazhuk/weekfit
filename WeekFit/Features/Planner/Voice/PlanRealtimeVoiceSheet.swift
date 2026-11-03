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
    @Published private(set) var inputLevel: Double = 0
    @Published private(set) var outputLevel: Double = 0

    var planningDay = Date()
    var activities: [PlannedActivity] = []
    var dayContext = PlanVoiceDayContext()
    var onSave: ((PlanVoiceCreateRequest) throws -> String)?
    var onUpdate: ((PlanVoiceUpdateRequest) throws -> Void)?
    var onDelete: ((String) throws -> Void)?
    var languageCode = "ru"

    private let bridge = PlanRealtimeScriptBridge()
    private var gate = PlanRealtimeCallGate()
    private var applied: Set<String> = []
    private var refBook = PlanRealtimeRefBook()
    private var removedIDs = Set<String>()
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
        // Retry builds a new page; begin() refuses while the old one is still attached.
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "plannerVoice")
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView = nil
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
        let startClock = planRealtimeSpokenClock(startText, language: callLanguage)
        let endClock = planRealtimeSpokenClock(endText, language: callLanguage)
        noteReceipt(
            id: id,
            title: title,
            detail: "\(day) · \(startClock)–\(endClock)",
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
        if name != "create_activity" {
            return performPlanTool(name: name, arguments: arguments)
        }
        guard let draft = planRealtimeDraft(arguments) else {
            return encode(planRealtimeToolReply(action: .reject("unknown_activity"), speak: nil))
        }
        let key = planRealtimeIdempotencyKey(callId)
        do {
            let client = try await makeClient()
            let commit = try await commit(client: client, key: key, draft: draft, transportFailed: false, lookedUp: false)
            return encode(apply(commit, key: key))
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
                _ = try onSave(request)
                applied.insert(key)
                noteSaved(
                    id: key,
                    spoken: PlannerOptionLocalization.localizedTitle(for: item.catalogTitle),
                    start: start,
                    minutes: item.durationMinutes,
                    kind: "added",
                    reply: commit.speak ?? ""
                )
                return planRealtimeToolReply(action: .insert, speak: commit.speak)
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
                saved: true,
                speak: planRealtimeListSpeak(scope: scope, items: items, language: callLanguage),
                error: nil
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
            do {
                try onDelete(entry.activityID)
                removedIDs.insert(entry.activityID)
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
                    error: nil
                ))
            } catch PlanViewModel.VoiceSaveError.alreadyDone {
                return encode(notice("already_done"))
            } catch {
                return encode(planRealtimeToolReply(action: .reject("save_failed"), speak: nil))
            }
        case "update_activity":
            guard let draft = planRealtimeEditDraft(arguments),
                  let entry = agenda.first(where: { $0.ref == draft.ref }),
                  let activity = activities.first(where: { $0.id == entry.activityID }),
                  let onUpdate else {
                return encode(notice("missing"))
            }
            if activity.isCompleted {
                return encode(notice("already_done"))
            }
            let sameKind = draft.catalogTitle.isEmpty || draft.catalogTitle == activity.title
            if draft.date.isEmpty && draft.startTime.isEmpty && draft.durationMinutes == 0 && sameKind {
                return encode(notice("unchanged"))
            }
            guard let start = planRealtimeMergedStart(
                day: draft.date,
                time: draft.startTime,
                original: activity.date,
                calendar: calendar
            ) else {
                return encode(notice("missing"))
            }
            if draft.durationMinutes != 0 && (draft.durationMinutes < 1 || draft.durationMinutes > 360) {
                return encode(notice("missing"))
            }
            let duration = draft.durationMinutes == 0 ? activity.durationMinutes : draft.durationMinutes
            do {
                try onUpdate(PlanVoiceUpdateRequest(
                    activityID: activity.id,
                    start: start,
                    durationMinutes: duration,
                    catalogTitle: draft.catalogTitle.isEmpty ? nil : draft.catalogTitle
                ))
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
                noteSaved(id: activity.id + time, spoken: spoken, start: start, minutes: duration, kind: "moved", reply: reply)
                return encode(PlanRealtimeToolReply(
                    ok: true,
                    saved: true,
                    speak: reply,
                    error: nil
                ))
            } catch PlanViewModel.VoiceSaveError.timeConflict {
                let spoken = conflictSpeak(start: start, minutes: duration, excluding: activity.id)
                noteReceipt(id: activity.id + "-conflict", title: WeekFitLocalizedString("planner.voice.receipt.failed"), detail: spoken, success: false)
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
        planRealtimeAgenda(
            activities.compactMap { activity in
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
            },
            now: Date(),
            calendar: calendar,
            book: &refBook,
            spoken: PlannerOptionLocalization.localizedTitle(for:)
        )
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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var languageManager: AppLanguageManager
    @StateObject private var controller = PlanRealtimeSessionController()
    @State private var showAIUsage = false

    var body: some View {
        let _ = languageManager.selectedLanguage
        let _ = controller.update(
            planningDay: planningDay,
            activities: activities,
            onSave: onSave,
            onUpdate: onUpdate,
            onDelete: onDelete,
            languageCode: languageManager.selectedLanguage.rawValue,
            dayContext: dayContext
        )

        ZStack {
            callCanvas.ignoresSafeArea()
            VStack(spacing: 0) {
                callHeader
                callStatus
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 22) {
                            portrait
                            waveform
                            if WeekFitAIBilling.enabled, case .failed = controller.phase {
                                Button(WeekFitLocalizedString("ai.usage.title")) { showAIUsage = true }
                            }
                            failureBlock
                            if !controller.turns.isEmpty || !controller.notices.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(controller.turns) { turn in
                                        callTurn(turn)
                                    }
                                    ForEach(controller.notices) { notice in
                                        receiptCard(notice)
                                    }
                                }
                            }
                            Color.clear.frame(height: 1).id("call-bottom")
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 6)
                        .padding(.bottom, 16)
                    }
                    .onChange(of: controller.turns.count) { _, _ in
                        scrollCall(proxy)
                    }
                    .onChange(of: controller.notices.count) { _, _ in
                        scrollCall(proxy)
                    }
                }
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
            if phase == .ended { dismiss() }
        }
        .onChange(of: controller.receipt?.id) { _, _ in
            guard let receipt = controller.receipt else { return }
            let announcement = receipt.detail.isEmpty ? receipt.title : "\(receipt.title). \(receipt.detail)"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }

    private var accent: Color {
        Color(red: 0.72, green: 0.58, blue: 0.32)
    }

    private var callCanvas: Color {
        palette.isLight ? Color(red: 0.988, green: 0.973, blue: 0.945) : palette.appScreenBackground
    }

    private var chipFill: Color {
        palette.isLight ? Color.white.opacity(0.72) : Color.white.opacity(0.08)
    }

    private var callHeader: some View {
        ZStack {
            Text(WeekFitLocalizedString("planner.voice.maya"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
            HStack {
                callCircleButton(systemName: "chevron.left", identifier: "planner.voice.realtime.back") {
                    controller.end()
                    dismiss()
                }
                Spacer(minLength: 0)
                PlanRealtimeRouteButton(tint: UIColor(palette.textPrimary))
                    .frame(width: 22, height: 22)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(chipFill))
                    .accessibilityIdentifier("planner.voice.realtime.route")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
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
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(controller.connectedAt == nil ? palette.textSecondary.opacity(0.45) : Color(red: 0.25, green: 0.62, blue: 0.36))
                    .frame(width: 7, height: 7)
                if let connectedAt = controller.connectedAt {
                    TimelineView(.periodic(from: connectedAt, by: 1)) { context in
                        let shown = min(context.date, controller.endingAt ?? context.date)
                        let seconds = max(0, Int(shown.timeIntervalSince(connectedAt)))
                        Text("\(statusText) · \(String(format: "%02d:%02d", seconds / 60, seconds % 60))")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(palette.textSecondary)
                    }
                } else {
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("planner.voice.realtime.status")
            if let queueDetail {
                Text(queueDetail)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let seconds = controller.remainingSeconds, seconds <= 60 {
                Text(WeekFitLocalizedString("ai.usage.lastMinute"))
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 24)
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
            }
        }
    }

    private var portrait: some View {
        Image("maya-portrait")
            .resizable()
            .scaledToFill()
            .frame(width: 228, height: 228)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(Color.white.opacity(palette.isLight ? 0.9 : 0.2), lineWidth: 2)
            }
            .shadow(color: Color(red: 0.45, green: 0.32, blue: 0.16).opacity(palette.isLight ? 0.12 : 0.28), radius: 16, y: 8)
            .padding(.top, 12)
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
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<37, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(accent.opacity(0.9))
                        .frame(width: 1.5, height: waveHeight(index: index, time: time))
                }
            }
            .frame(height: 76)
        }
        .accessibilityHidden(true)
    }

    private func waveHeight(index: Int, time: TimeInterval) -> CGFloat {
        let mid = 18.0
        let window = 0.45 + 0.55 * (1 - abs(Double(index) - mid) / mid)
        let sample: Double
        if motionReduced {
            sample = abs(sin(Double(index) * 1.7)) * 0.55 + abs(sin(Double(index) * 0.63)) * 0.3
        } else {
            let position = Double(index)
            let voice = sin(time * 11.0 + position * 0.92)
            let harmonic = sin(time * 17.4 + position * 1.63)
            let breath = sin(time * 5.2 + position * 0.31)
            sample = abs(0.62 * voice + 0.26 * harmonic + 0.12 * breath)
        }
        let loud = min(1, max(0.28, markLevel * 2.4))
        let shape = 0.72 + 0.28 * window
        return 6 + 68 * loud * shape * (0.55 + 0.45 * sample)
    }

    private func scrollCall(_ proxy: ScrollViewProxy) {
        if motionReduced {
            proxy.scrollTo("call-bottom", anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.35)) {
                proxy.scrollTo("call-bottom", anchor: .bottom)
            }
        }
    }

    private func callTurn(_ turn: PlanVoiceTurn) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if turn.role == .user {
                Image(systemName: "person.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(chipFill))
                    .accessibilityHidden(true)
            } else {
                Image("maya-portrait")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }
            Text(turn.text)
                .font(.subheadline)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(turnBubble(turn.role))
                }
            Spacer(minLength: 28)
        }
        .accessibilityElement(children: .combine)
    }

    private func turnBubble(_ role: PlanVoiceTurn.Role) -> Color {
        if role == .user {
            return palette.isLight ? Color.white : palette.cardSurface
        }
        return palette.isLight ? Color(red: 0.94, green: 0.91, blue: 0.97) : palette.cardSurface
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
                    .fixedSize(horizontal: false, vertical: true)
                if !receipt.detail.isEmpty {
                    Text(receipt.detail)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
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
        HStack(alignment: .top, spacing: 36) {
            labeledControl(
                title: WeekFitLocalizedString(controller.muted ? "planner.voice.micEnable" : "planner.voice.micDisable"),
                identifier: "planner.voice.realtime.mute"
            ) {
                Button {
                    controller.toggleMute()
                } label: {
                    Image(systemName: controller.muted ? "mic.slash.fill" : "mic.slash")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(palette.textPrimary.opacity(controller.connectedAt == nil ? 0.35 : 0.8))
                        .frame(width: 68, height: 68)
                        .background(Circle().fill(chipFill))
                }
                .disabled(controller.connectedAt == nil)
                .accessibilityValue(Text(controller.muted ? WeekFitLocalizedString("planner.voice.micOff") : statusText))
            }

            labeledControl(
                title: WeekFitLocalizedString(controller.connectedAt == nil ? "planner.voice.cancel" : "planner.voice.endTalk"),
                identifier: "planner.voice.realtime.end"
            ) {
                Button {
                    controller.end()
                    dismiss()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 74)
                        .background(Circle().fill(Color(red: 0.86, green: 0.27, blue: 0.27)))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 48)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .animation(motionReduced ? nil : .easeOut(duration: 0.35), value: controller.receipt?.id)
    }

    private func labeledControl<Content: View>(
        title: String,
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 8) {
            content()
            Text(title)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
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
            return WeekFitLocalizedString("planner.voice.status.speaking")
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
        languageCode: String,
        dayContext: PlanVoiceDayContext
    ) {
        self.planningDay = planningDay
        self.activities = activities
        self.onSave = onSave
        self.onUpdate = onUpdate
        self.onDelete = onDelete
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
        durationMinutes: object["durationMinutes"] as? Int ?? 0
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
