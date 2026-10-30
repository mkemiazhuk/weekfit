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
    @Published private(set) var muted = false
    @Published private(set) var webView: WKWebView?
    @Published private(set) var receipt: PlanVoiceReceipt?
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
    private var started = false
    private var ended = false
    private var lineTicket: String?
    private var receiptIDs = Set<String>()
    private var connectTask: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var callLanguage = "ru"
    private var reconnecting = false
    private var keepsReceipt = false
    private var receiptHide: Task<Void, Never>?
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
        connectTask?.cancel()
        heartbeat?.cancel()
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

    func receive(_ body: Any) {
        guard let payload = body as? [String: Any], let type = payload["type"] as? String else { return }
        switch type {
        case "state":
            applyState(payload)
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
            guard !ended else {
                await client.leaveLine(ticket: ticket)
                return
            }
            self.secret = secret
            startHeartbeat(ticket)
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
        } catch PlanRealtimeClientError.lineFull {
            guard !ended else { return }
            ringback.stop()
            phase = .failed(WeekFitLocalizedString("planner.voice.lineFull"))
        } catch PlanRealtimeClientError.transport {
            guard !ended else { return }
            ringback.stop()
            phase = .failed(WeekFitLocalizedString("planner.voice.offline"))
        } catch {
            guard !ended else { return }
            ringback.stop()
            phase = .failed(WeekFitLocalizedString("planner.voice.connectionLost"))
        }
    }

    func showFixture(_ name: String) {
        started = true
        keepsReceipt = true
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
            receipt = PlanVoiceReceipt(
                id: "fixture-receipt",
                title: String(format: WeekFitLocalizedString("planner.voice.receipt.added"), PlannerOptionLocalization.localizedTitle(for: "Walk")),
                detail: "Today · 18:00–18:30",
                success: true
            )
        case "error":
            phase = .failed(WeekFitLocalizedString("planner.voice.connectionLost"))
            receipt = PlanVoiceReceipt(
                id: "fixture-error",
                title: WeekFitLocalizedString("planner.voice.receipt.failed"),
                detail: WeekFitLocalizedString("planner.voice.error.continue"),
                success: false
            )
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
        receipt = PlanVoiceReceipt(id: id, title: title, detail: detail, success: success)
        receiptHide?.cancel()
        guard success, !keepsReceipt else { return }
        receiptHide = Task { [weak self] in
            let pause: UInt64 = UIAccessibility.isVoiceOverRunning ? 8_000_000_000 : 4_500_000_000
            try? await Task.sleep(nanoseconds: pause)
            guard !Task.isCancelled else { return }
            if self?.receipt?.id == id { self?.receipt = nil }
        }
    }

    private func noteSaved(id: String, spoken: String, start: Date, minutes: Int, kind: String) {
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
        noteReceipt(
            id: id,
            title: String(format: WeekFitLocalizedString(key), spoken),
            detail: "\(day) · \(startText)–\(endText)",
            success: true
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
                guard let client = try? await makeClient() else { return }
                await client.beatLine(ticket: ticket)
            }
        }
    }

    private func leaveLine(_ ticket: String) async {
        guard let client = try? await makeClient() else { return }
        await client.leaveLine(ticket: ticket)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !ended, let secret, let options = json(secret) else { return }
        webView.evaluateJavaScript("window.weekfit.start(\(options))")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        ringback.stop()
        phase = .failed(WeekFitLocalizedString("planner.voice.sessionFailed"))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        ringback.stop()
        phase = .failed(WeekFitLocalizedString("planner.voice.sessionFailed"))
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
        switch payload["value"] as? String {
        case "connecting":
            phase = .connecting
        case "connected":
            phase = .connecting
        case "listening":
            phase = .listening
        case "speaking":
            if connectedAt == nil {
                ringback.stop()
                connectedAt = Date()
                webView?.evaluateJavaScript("window.weekfit && window.weekfit.answered()")
            }
            phase = .speaking
        case "acting":
            phase = .acting
        case "ending":
            phase = .ending
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
                noteSaved(id: key, spoken: PlannerOptionLocalization.localizedTitle(for: item.catalogTitle), start: start, minutes: item.durationMinutes, kind: "added")
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
                noteReceipt(
                    id: entry.activityID,
                    title: String(format: WeekFitLocalizedString("planner.voice.receipt.removed"), entry.spoken),
                    detail: dayLabel(entry.day, today: today, tomorrow: tomorrow),
                    success: true
                )
                return encode(PlanRealtimeToolReply(
                    ok: true,
                    saved: true,
                    speak: planRealtimeRemovedSpeak(
                        spoken: entry.spoken,
                        day: dayLabel(entry.day, today: today, tomorrow: tomorrow),
                        language: callLanguage
                    ),
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
                noteSaved(id: activity.id + time, spoken: spoken, start: start, minutes: duration, kind: "moved")
                return encode(PlanRealtimeToolReply(
                    ok: true,
                    saved: true,
                    speak: planRealtimeMovedSpeak(
                        spoken: spoken,
                        day: dayLabel(day, today: today, tomorrow: tomorrow),
                        time: time,
                        language: callLanguage
                    ),
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
    private var player: AVAudioPlayer?

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)
        guard player == nil, let sound = try? AVAudioPlayer(data: Self.tone) else { return }
        sound.numberOfLoops = -1
        sound.volume = 1
        sound.prepareToPlay()
        sound.play()
        player = sound
    }

    func stop() {
        player?.stop()
        player = nil
    }

    // A phone ring: two short bursts, then silence, until the assistant answers.
    private static let tone: Data = {
        let rate = 16_000
        let count = rate * 3
        var wave = Data(capacity: 44 + count * 2)
        func word(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { wave.append(contentsOf: $0) }
        }
        func halfWord(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { wave.append(contentsOf: $0) }
        }
        wave.append(contentsOf: "RIFF".utf8)
        word(UInt32(36 + count * 2))
        wave.append(contentsOf: "WAVEfmt ".utf8)
        word(16)
        halfWord(1)
        halfWord(1)
        word(UInt32(rate))
        word(UInt32(rate * 2))
        halfWord(2)
        halfWord(16)
        wave.append(contentsOf: "data".utf8)
        word(UInt32(count * 2))
        for index in 0..<count {
            let seconds = Double(index) / Double(rate)
            let ringing = (seconds < 0.4) || (seconds >= 0.6 && seconds < 1.0)
            let sample = ringing
                ? (sin(2 * .pi * 440 * seconds) + sin(2 * .pi * 480 * seconds)) * 0.28
                : 0
            var value = Int16((sample * Double(Int16.max)).rounded()).littleEndian
            withUnsafeBytes(of: &value) { wave.append(contentsOf: $0) }
        }
        return wave
    }()
}

struct PlanVoiceReceipt: Equatable {
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
    @State private var routeRevision = 0

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

        VStack(spacing: 18) {
            header
            mark
            Spacer(minLength: 0)
            if let webView = controller.webView {
                PlanRealtimeWebHost(webView: webView)
                    .frame(height: 1)
                    .opacity(0.01)
                    .accessibilityHidden(true)
            }
            controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WeekFitTheme.backgroundColor.ignoresSafeArea())
        .accessibilityIdentifier("planner.voice.realtime")
        .onAppear {
            if let phase = WeekFitUITestSupport.mayaPreviewPhase {
                controller.showFixture(phase)
            } else {
                controller.begin()
            }
        }
        .onDisappear { controller.end() }
        .onChange(of: controller.phase) { _, phase in
            if phase == .ended { dismiss() }
        }
        .onChange(of: controller.receipt?.id) { _, _ in
            guard let receipt = controller.receipt else { return }
            let announcement = receipt.detail.isEmpty ? receipt.title : "\(receipt.title). \(receipt.detail)"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
            routeRevision += 1
        }
    }

    private var accent: Color {
        palette.isLight ? Color(red: 0.55, green: 0.48, blue: 0.72) : palette.textPrimary
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(WeekFitLocalizedString("planner.voice.maya"))
                .font(.title.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .minimumScaleFactor(0.7)
            Text(WeekFitLocalizedString("planner.voice.coachLine"))
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            Text(statusText)
                .font(.body.weight(.medium))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("planner.voice.realtime.status")
            if let queueDetail {
                Text(queueDetail)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if controller.muted, controller.connectedAt != nil {
                Label(WeekFitLocalizedString("planner.voice.micOff"), systemImage: "mic.slash")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }
            if let connectedAt = controller.connectedAt {
                TimelineView(.periodic(from: connectedAt, by: 1)) { context in
                    let seconds = max(0, Int(context.date.timeIntervalSince(connectedAt)))
                    Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(palette.textSecondary)
                }
            }
            if case .failed(let message) = controller.phase {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                Button(WeekFitLocalizedString("planner.voice.retry")) {
                    controller.retry()
                }
                .font(.body.weight(.semibold))
                .padding(.top, 4)
                if controller.microphoneDenied {
                    Button(WeekFitLocalizedString("planner.voice.openSettings")) {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
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

    private var mark: some View {
        let level = markLevel
        let connecting = !motionReduced && {
            switch controller.phase {
            case .connecting, .queued: return true
            default: return false
            }
        }()
        return TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !connecting)) { context in
            let breath = connecting
                ? 0.92 + 0.08 * (0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 1.2))
                : 1.0
            ZStack {
                Circle()
                    .fill(accent.opacity((palette.isLight ? 0.16 : 0.22) * breath))
                    .frame(width: 108, height: 108)
                Circle()
                    .strokeBorder(accent.opacity(0.55), lineWidth: 1.5)
                    .frame(width: 108, height: 108)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.95), accent.opacity(palette.isLight ? 0.42 : 0.7)],
                            center: UnitPoint(x: 0.35, y: 0.32),
                            startRadius: 2,
                            endRadius: 46
                        )
                    )
                    .frame(width: 72, height: 72)
                    .scaleEffect(motionReduced ? 1 : 1 + level * 0.16)
                Circle()
                    .fill(Color.white.opacity(palette.isLight ? 0.38 : 0.2))
                    .frame(width: 16, height: 16)
                    .offset(x: -12, y: -14)
                    .allowsHitTesting(false)
            }
        }
        .animation(motionReduced ? nil : .easeOut(duration: 0.12), value: level)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var receiptCard: some View {
        if let receipt = controller.receipt {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: receipt.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(receipt.success ? accent : Color(red: 0.91, green: 0.19, blue: 0.22))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(receipt.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                    if !receipt.detail.isEmpty {
                        Text(receipt.detail)
                            .font(.footnote)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(palette.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("planner.voice.realtime.receipt")
        }
    }

    private var controls: some View {
        HStack(alignment: .top, spacing: 28) {
            labeledControl(
                title: WeekFitLocalizedString(controller.muted ? "planner.voice.micEnable" : "planner.voice.micDisable"),
                identifier: "planner.voice.realtime.mute"
            ) {
                Button {
                    controller.toggleMute()
                } label: {
                    Image(systemName: controller.muted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(palette.cardSurface))
                        .frame(height: 76)
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
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(Color(red: 0.91, green: 0.19, blue: 0.22)))
                }
            }

            labeledControl(
                title: WeekFitLocalizedString("planner.voice.audioRoute"),
                identifier: "planner.voice.realtime.route",
                value: externalRouteName
            ) {
                PlanRealtimeRouteButton(tint: UIColor(palette.textPrimary))
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(palette.cardSurface))
                    .frame(height: 76)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .overlay(alignment: .top) {
            receiptCard
                .padding(.horizontal, 8)
                .offset(y: -88)
                .animation(motionReduced ? nil : .easeOut(duration: 0.35), value: controller.receipt?.id)
        }
    }

    /// Built-in speaker already has the «Звук» caption. Show a second line only for headphones, a car, or another route.
    private var externalRouteName: String? {
        let _ = routeRevision
        guard let output = AVAudioSession.sharedInstance().currentRoute.outputs.first else { return nil }
        switch output.portType {
        case .builtInSpeaker, .builtInReceiver:
            return nil
        default:
            let name = output.portName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
    }

    private func labeledControl<Content: View>(
        title: String,
        identifier: String,
        value: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 8) {
            content()
            Text(title)
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(value?.isEmpty == false ? (value ?? "") : " ")
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .opacity(value?.isEmpty == false ? 1 : 0)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(Text(value ?? ""))
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
