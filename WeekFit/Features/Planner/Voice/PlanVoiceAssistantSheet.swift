import SwiftUI
import UIKit

/// Spoken plan chat. A pause ends the person's turn; the assistant then asks or the plan is updated.
struct PlanVoiceAssistantSheet: View {

    @ObservedObject var commands: PlanVoiceCommandController
    @ObservedObject var capture: PlanVoiceCapture

    let calendar: Calendar
    let planningDay: Date
    let onCommit: () -> Void
    let onRetry: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var languageManager: AppLanguageManager

    @State private var isOpen = true
    @State private var isStartingListen = false

    var body: some View {
        let _ = languageManager.selectedLanguage

        VStack(spacing: 0) {
            header
            conversation
            composer
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("planner.voice.chat")
        .onAppear {
            capture.onUtteranceEnded = { text in
                submitTurn(text)
            }
            Task { await beginListening() }
        }
        .onDisappear {
            isOpen = false
            capture.onUtteranceEnded = nil
            Task { await capture.stop() }
        }
        .onChange(of: commands.phase) { _, _ in
            guard isOpen, commands.listensForReply, !capture.isRecording else { return }
            Task { await resumeAfterReply() }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(PlanVoiceCommandCopy.assistantTitle)
                .font(WeekFitType.cardTitle)
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 0)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(palette.cardSurfaceElevated.opacity(palette.isLight ? 0.9 : 0.55))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PlanVoiceCommandCopy.close)
        }
        .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    bubble(PlanVoiceCommandCopy.greeting, fromAssistant: true)
                        .id("greeting")

                    ForEach(commands.turns) { turn in
                        bubble(turn.text, fromAssistant: turn.speaker == .assistant)
                            .id(turn.id)
                    }

                    if capture.isRecording, !capture.liveTranscript.isEmpty {
                        bubble(capture.liveTranscript, fromAssistant: false)
                            .id("live")
                    }

                    if commands.canRetrySave {
                        Button(PlanVoiceCommandCopy.retry) {
                            onRetry()
                        }
                        .font(WeekFitType.secondary.weight(.semibold))
                        .foregroundStyle(WeekFitTheme.workout)
                        .accessibilityIdentifier("planner.voice.retry")
                        .id("retry")
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                .padding(.vertical, 12)
            }
            .onChange(of: commands.turns.count) { _, _ in
                scrollToEnd(proxy)
            }
            .onChange(of: capture.liveTranscript) { _, _ in
                scrollToEnd(proxy)
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 12) {
            Text(composerTitle)
                .font(WeekFitType.secondary)
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("planner.voice.status")

            Button {
                handleComposerMic()
            } label: {
                Image(systemName: capture.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(capture.isRecording
                                  ? WeekFitTheme.workout.opacity(palette.isLight ? 0.22 : 0.32)
                                  : palette.cardSurfaceElevated)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PlanVoiceCommandCopy.microphoneLabel)
            .accessibilityIdentifier("planner.voice.composer")
        }
        .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(palette.appScreenBackground)
    }

    private var composerTitle: String {
        if capture.isRecording { return PlanVoiceCommandCopy.listening }
        if case .processing = commands.phase { return PlanVoiceCommandCopy.processing }
        if case .recording = commands.phase { return PlanVoiceCommandCopy.listening }
        return PlanVoiceCommandCopy.speak
    }

    private func bubble(_ text: String, fromAssistant: Bool) -> some View {
        HStack {
            if !fromAssistant { Spacer(minLength: 36) }
            Text(text)
                .font(WeekFitType.body)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(fromAssistant ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(fromAssistant
                              ? palette.cardSurface
                              : WeekFitTheme.workout.opacity(palette.isLight ? 0.16 : 0.28))
                }
                .accessibilityIdentifier(fromAssistant ? "planner.voice.turn.assistant" : "planner.voice.turn.person")
            if fromAssistant { Spacer(minLength: 36) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func handleComposerMic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if capture.isRecording {
            Task {
                let transcript = await capture.stop()
                submitTurn(transcript)
            }
            return
        }
        Task { await beginListening() }
    }

    private func submitTurn(_ transcript: String) {
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else {
            commands.cancelRecording()
            return
        }
        commands.submit(
            transcript: spoken,
            now: Date(),
            calendar: calendar,
            planningDay: planningDay
        )
        onCommit()
    }

    private func beginListening() async {
        guard isOpen, !capture.isRecording, !isStartingListen else { return }
        isStartingListen = true
        defer { isStartingListen = false }
        commands.noteRecording()
        do {
            try await capture.start(locale: speechLocale)
        } catch {
            commands.noteDenied()
        }
    }

    private func resumeAfterReply() async {
        try? await Task.sleep(for: .milliseconds(350))
        guard isOpen, commands.listensForReply, !capture.isRecording else { return }
        await beginListening()
    }

    private var speechLocale: Locale {
        languageManager.selectedLanguage == .russian
            ? Locale(identifier: "ru-RU")
            : WeekFitCurrentLocale()
    }
}
