internal import Combine
import AVFoundation
import SwiftUI
import WebKit

@MainActor
final class PlanRealtimeSessionController: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    enum Phase: Equatable {
        case connecting
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

    var planningDay = Date()
    var activities: [PlannedActivity] = []
    var onSave: ((PlanVoiceCreateRequest) throws -> Void)?

    private let bridge = PlanRealtimeScriptBridge()
    private var gate = PlanRealtimeCallGate()
    private var applied: Set<String> = []
    private var secret: PlanRealtimeSessionSecret?
    private var started = false
    private var ended = false
    private let calendar = Calendar.current
    private let ringback = PlanVoiceRingback()

    func begin() {
        guard webView == nil, !started else { return }
        started = true
        phase = .connecting
        ringback.start()
        Task { await connect() }
    }

    func toggleMute() {
        muted.toggle()
        webView?.evaluateJavaScript("window.weekfit && window.weekfit.setMuted(\(muted ? "true" : "false"))")
    }

    func end() {
        guard !ended else { return }
        ended = true
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
            let arguments = payload["arguments"] as? String ?? "{}"
            Task { await handleTool(callId: callId, arguments: arguments) }
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
        do {
            let client = try await makeClient()
            let secret = try await client.openSession(
                timeZone: calendar.timeZone.identifier,
                now: Date(),
                planningDay: planRealtimeDayString(planningDay, calendar: calendar),
                givenName: ProfileService.resolvedGivenName()
            )
            guard !ended else { return }
            self.secret = secret
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
        } catch PlanRealtimeClientError.forbidden {
            ringback.stop()
            phase = .failed(WeekFitLocalizedString("planner.voice.sessionFailed"))
        } catch {
            ringback.stop()
            phase = .failed(WeekFitLocalizedString("planner.voice.sessionFailed"))
        }
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
            ringback.stop()
            connectedAt = Date()
            phase = .connected
        case "listening":
            phase = .listening
        case "speaking":
            phase = .speaking
        case "acting":
            phase = .acting
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

    private func handleTool(callId: String, arguments: String) async {
        switch gate.begin(callId) {
        case .wait:
            return
        case .replay(let reply):
            deliver(callId: callId, reply: reply)
            return
        case .start:
            break
        }
        let reply = await performTool(callId: callId, arguments: arguments)
        gate.finish(callId, reply: reply)
        deliver(callId: callId, reply: reply)
    }

    private func performTool(callId: String, arguments: String) async -> String {
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
            return planRealtimeToolReply(action: action, speak: nil)
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
                try onSave(request)
                applied.insert(key)
                return planRealtimeToolReply(action: .insert, speak: commit.speak)
            } catch {
                return planRealtimeToolReply(action: .reject("save_failed"), speak: nil)
            }
        }
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
        ]
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
        guard player == nil, let sound = try? AVAudioPlayer(data: Self.tone) else { return }
        sound.numberOfLoops = -1
        sound.prepareToPlay()
        sound.play()
        player = sound
    }

    func stop() {
        player?.stop()
        player = nil
    }

    // Two seconds of a soft dual tone followed by four seconds of silence.
    private static let tone: Data = {
        let rate = 16_000
        let count = rate * 6
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
            let fade = min(1, seconds * 25, (2 - seconds) * 25)
            let sample = seconds < 2
                ? (sin(2 * .pi * 440 * seconds) + sin(2 * .pi * 480 * seconds)) * 0.14 * max(0, fade)
                : 0
            var value = Int16((sample * Double(Int16.max)).rounded()).littleEndian
            withUnsafeBytes(of: &value) { wave.append(contentsOf: $0) }
        }
        return wave
    }()
}

struct PlanRealtimeVoiceSheet: View {
    var planningDay: Date
    var activities: [PlannedActivity]
    var onSave: (PlanVoiceCreateRequest) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: AppLanguageManager
    @StateObject private var controller = PlanRealtimeSessionController()

    var body: some View {
        let _ = languageManager.selectedLanguage
        let _ = controller.update(planningDay: planningDay, activities: activities, onSave: onSave)

        VStack(spacing: 0) {
            header
            Spacer()
            avatar
            if case .failed(let message) = controller.phase {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 24)
            }
            Spacer()
            if let webView = controller.webView {
                PlanRealtimeWebHost(webView: webView)
                    .frame(height: 1)
                    .opacity(0.01)
                    .accessibilityHidden(true)
            }
            controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.055, green: 0.075, blue: 0.11).ignoresSafeArea())
        .accessibilityIdentifier("planner.voice.realtime")
        .onAppear { controller.begin() }
        .onDisappear { controller.end() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("WeekFit")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            if let connectedAt = controller.connectedAt {
                TimelineView(.periodic(from: connectedAt, by: 1)) { context in
                    let seconds = max(0, Int(context.date.timeIntervalSince(connectedAt)))
                    Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.65))
                }
            } else {
                Text(statusText)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .font(.system(size: 17, weight: .medium))
        .padding(.top, 55)
        .accessibilityIdentifier("planner.voice.realtime.status")
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.07), lineWidth: 1)
                .frame(width: 245, height: 245)
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 1)
                .frame(width: 205, height: 205)
            Circle()
                .fill(Color(red: 0.13, green: 0.19, blue: 0.28))
                .frame(width: 160, height: 160)
            Image(systemName: controller.phase == .speaking ? "waveform" : "person.crop.circle.fill")
                .font(.system(size: 76, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.9))
        }
        .accessibilityHidden(true)
    }

    private var controls: some View {
        HStack(spacing: 70) {
            Button {
                controller.toggleMute()
            } label: {
                Image(systemName: controller.muted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(.white.opacity(controller.muted ? 0.3 : 0.15)))
            }
            .disabled(controller.connectedAt == nil)
            .accessibilityLabel(controller.muted ? "Включить микрофон" : "Выключить микрофон")
            .accessibilityIdentifier("planner.voice.realtime.mute")

            Button {
                controller.end()
                dismiss()
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Color(red: 0.91, green: 0.19, blue: 0.22)))
            }
            .accessibilityLabel(WeekFitLocalizedString("planner.voice.endTalk"))
            .accessibilityIdentifier("planner.voice.realtime.end")
        }
        .buttonStyle(.plain)
        .padding(.bottom, 52)
    }

    private var statusText: String {
        switch controller.phase {
        case .connecting:
            return WeekFitLocalizedString("planner.voice.state.connecting")
        case .connected:
            return WeekFitLocalizedString("planner.voice.listening")
        case .listening:
            return WeekFitLocalizedString("planner.voice.listening")
        case .speaking:
            return WeekFitLocalizedString("planner.voice.state.speaking")
        case .acting:
            return WeekFitLocalizedString("planner.voice.state.acting")
        case .ended:
            return WeekFitLocalizedString("planner.voice.state.ended")
        case .failed(let text):
            return text
        }
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
        onSave: @escaping (PlanVoiceCreateRequest) throws -> Void
    ) {
        self.planningDay = planningDay
        self.activities = activities
        self.onSave = onSave
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
