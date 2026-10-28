internal import Combine
import SwiftUI
import WebKit

@MainActor
final class PlanRealtimeSessionController: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    enum Phase: Equatable {
        case connecting
        case listening
        case speaking
        case acting
        case ended
        case failed(String)
    }

    struct Line: Identifiable, Equatable {
        enum Role: Equatable { case person, assistant, result }
        let id = UUID()
        let role: Role
        let text: String
    }

    @Published private(set) var phase: Phase = .connecting
    @Published private(set) var lines: [Line] = []
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

    func begin() {
        guard webView == nil, !started else { return }
        started = true
        phase = .connecting
        Task { await connect() }
    }

    func end() {
        guard !ended else { return }
        ended = true
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
        case "transcript":
            guard let text = payload["text"] as? String, !text.isEmpty else { return }
            let role: Line.Role = (payload["role"] as? String) == "user" ? .person : .assistant
            lines.append(Line(role: role, text: text))
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
                planningDay: planRealtimeDayString(planningDay, calendar: calendar)
            )
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
            phase = .failed(WeekFitLocalizedString("planner.voice.sessionFailed"))
        } catch {
            phase = .failed(WeekFitLocalizedString("planner.voice.sessionFailed"))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let secret, let options = json(secret) else { return }
        webView.evaluateJavaScript("window.weekfit.start(\(options))")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        phase = .failed(WeekFitLocalizedString("planner.voice.sessionFailed"))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
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
        case "listening":
            phase = .listening
        case "speaking":
            phase = .speaking
        case "acting":
            phase = .acting
        case "ended":
            guard !ended else { return }
            let idle = (payload["reason"] as? String) == "idle"
            if idle {
                lines.append(Line(role: .result, text: WeekFitLocalizedString("planner.voice.idleEnded")))
            }
            end()
        case "failed":
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
            if let speak = commit.speak {
                lines.append(Line(role: .result, text: speak))
            }
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
                if let speak = commit.speak {
                    lines.append(Line(role: .result, text: speak))
                }
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

struct PlanRealtimeVoiceSheet: View {
    var planningDay: Date
    var activities: [PlannedActivity]
    var onSave: (PlanVoiceCreateRequest) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var languageManager: AppLanguageManager
    @StateObject private var controller = PlanRealtimeSessionController()

    var body: some View {
        let _ = languageManager.selectedLanguage
        let _ = controller.update(planningDay: planningDay, activities: activities, onSave: onSave)

        VStack(spacing: 0) {
            header
            status
            transcript
            if let webView = controller.webView {
                PlanRealtimeWebHost(webView: webView)
                    .frame(height: 1)
                    .opacity(0.01)
                    .accessibilityHidden(true)
            }
            endButton
        }
        .accessibilityIdentifier("planner.voice.realtime")
        .onAppear { controller.begin() }
        .onDisappear { controller.end() }
    }

    private var header: some View {
        Text(WeekFitLocalizedString("planner.voice.talk"))
            .font(WeekFitType.cardTitle)
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }

    private var status: some View {
        Text(statusText)
            .font(WeekFitType.secondary.weight(.semibold))
            .foregroundStyle(palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
            .accessibilityIdentifier("planner.voice.realtime.status")
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(controller.lines) { line in
                        Text(line.text)
                            .font(WeekFitType.body)
                            .foregroundStyle(palette.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(line.role == .person
                                          ? WeekFitTheme.workout.opacity(palette.isLight ? 0.16 : 0.28)
                                          : palette.cardSurface)
                            }
                            .frame(maxWidth: .infinity, alignment: line.role == .person ? .trailing : .leading)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                .padding(.vertical, 12)
            }
            .onChange(of: controller.lines.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var endButton: some View {
        Button {
            controller.end()
            dismiss()
        } label: {
            Text(WeekFitLocalizedString("planner.voice.endTalk"))
                .font(WeekFitType.button)
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.cardSurface)
                }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
        .padding(.bottom, 12)
        .accessibilityIdentifier("planner.voice.realtime.end")
    }

    private var statusText: String {
        switch controller.phase {
        case .connecting:
            return WeekFitLocalizedString("planner.voice.state.connecting")
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
