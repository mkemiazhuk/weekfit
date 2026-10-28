import AVFoundation
internal import Combine
import Foundation
import Speech

enum PlanVoiceCaptureError: Error {
    case speechDenied
    case microphoneDenied
    case unavailable
}

/// On-device speech to text. A pause after speech ends the turn; the transcript is all the interpreter sees.
@MainActor
final class PlanVoiceCapture: ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var liveTranscript = ""

    var onUtteranceEnded: ((String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var silence = PlanVoiceSilenceGate()
    private var silenceTask: Task<Void, Never>?
    private var turnOpen = false

    func start(locale: Locale) async throws {
        guard !isRecording else { return }
        let allowed = await Self.speechAllowed()
        guard allowed else { throw PlanVoiceCaptureError.speechDenied }
        let microphone = await Self.microphoneAllowed()
        guard microphone else { throw PlanVoiceCaptureError.microphoneDenied }

        let recognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer, recognizer.isAvailable else {
            throw PlanVoiceCaptureError.unavailable
        }

        silenceTask?.cancel()
        silence = PlanVoiceSilenceGate()
        latestTranscript = ""
        liveTranscript = ""
        turnOpen = true

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            turnOpen = false
            throw PlanVoiceCaptureError.unavailable
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor in
                self?.acceptPartial(text)
            }
        }
    }

    /// Manual stop. Does not deliver `onUtteranceEnded`; the caller submits the transcript.
    func stop() async -> String {
        await teardown(waitForFinal: true)
    }

    private func acceptPartial(_ text: String) {
        latestTranscript = text
        liveTranscript = text
        guard turnOpen else { return }
        guard let revision = silence.note(text) else { return }
        silenceTask?.cancel()
        silenceTask = Task { @MainActor in
            try? await Task.sleep(for: PlanVoiceSilenceGate.pause)
            guard !Task.isCancelled, self.turnOpen, self.silence.revision == revision else { return }
            await self.deliverUtterance()
        }
    }

    private func deliverUtterance() async {
        guard turnOpen else { return }
        let text = await teardown(waitForFinal: false)
        guard !text.isEmpty else { return }
        onUtteranceEnded?(text)
    }

    private func teardown(waitForFinal: Bool) async -> String {
        silenceTask?.cancel()
        turnOpen = false
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.reset()
        }
        request?.endAudio()
        task?.finish()
        if waitForFinal {
            try? await Task.sleep(for: .milliseconds(300))
        }
        let text = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        request = nil
        task = nil
        isRecording = false
        liveTranscript = ""
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return text
    }

    private static func speechAllowed() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private static func microphoneAllowed() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
}
