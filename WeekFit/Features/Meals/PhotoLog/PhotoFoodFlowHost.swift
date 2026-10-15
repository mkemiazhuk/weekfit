import SwiftUI

/// Dedicated host so `@Observable` phase/draft changes always refresh UI.
struct PhotoFoodFlowHost: View {
    @Bindable var coordinator: PhotoFoodLogCoordinator
    /// Explicit first-frame preview so we never flash an empty dark screen.
    let previewImage: UIImage?
    let isLogging: Bool
    let errorMessage: String?
    let onDismiss: () -> Void
    let onLog: (PhotoFoodLogDraft) -> Void
    /// Presented when cloud AI requires a paid subscription.
    var onRequestPaidSubscription: (() -> Void)? = nil

    @Environment(\.weekFitPalette) private var palette

    private var foodAccent: Color { QuickFoodAccent.actionOrange }

    private var displayPreview: UIImage? {
        previewImage ?? coordinator.lastImage
    }

    var body: some View {
        Group {
            switch coordinator.phase {
            case .idle, .analyzing, .logging:
                analyzingView
            case .confirmation:
                if let draft = coordinator.draft {
                    PhotoFoodConfirmationSheet(
                        draft: draft,
                        isLogging: isLogging,
                        onLog: { onLog(draft) },
                        onDismiss: onDismiss,
                        onRetry: { coordinator.retryAnalysis() },
                        errorMessage: errorMessage
                    )
                } else {
                    analyzingView
                }
            case .error(let error):
                errorView(error)
            }
        }
        .background(QuickActionSheetDesign.Color.sheetBackground(for: .food).ignoresSafeArea())
        .onChange(of: coordinator.phase) { _, newPhase in
            let id = coordinator.lastAnalysisId ?? "none"
            PhotoFoodDiagnostics.event(
                "sheetPhase",
                clock: PhotoFoodDiagnostics.AnalysisClock(analysisId: id),
                detail: String(describing: newPhase)
            )
        }
    }

    // MARK: - Analyzing

    private var analyzingView: some View {
        VStack(spacing: 0) {
            photoFlowHeader(
                title: WeekFitLocalizedString("today.photoLog.analyzing.title"),
                subtitle: WeekFitLocalizedString("today.photoLog.analyzing.subtitle"),
                onClose: {
                    coordinator.cancelAnalysis()
                    onDismiss()
                }
            )

            Spacer(minLength: 12)

            heroPhoto(displayPreview, dimmed: false)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(foodAccent)

                Text(WeekFitLocalizedString(coordinator.progress.messageKey))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.2), value: coordinator.progress)

                Text(WeekFitLocalizedString("today.photoLog.analyzing.body"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.78))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)

            Button(WeekFitLocalizedString("common.action.cancel")) {
                coordinator.cancelAnalysis()
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.85))
            .padding(.top, 18)
            .disabled(coordinator.phase != .analyzing)

            Spacer(minLength: 20)
        }
    }

    // MARK: - Error

    private func errorView(_ error: PhotoFoodRecognitionError) -> some View {
        VStack(spacing: 0) {
            photoFlowHeader(
                title: WeekFitLocalizedString("today.photoLog.error.title"),
                subtitle: WeekFitLocalizedString(error.userMessageKey),
                onClose: onDismiss
            )

            Spacer(minLength: 12)

            heroPhoto(displayPreview, dimmed: true, emptySymbol: "exclamationmark.triangle.fill")
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                if error == .subscriptionRequired {
                    primaryActionButton(
                        title: WeekFitLocalizedString("today.photoLog.error.subscriptionRequired.cta")
                    ) {
                        onRequestPaidSubscription?()
                    }
                } else if displayPreview != nil {
                    primaryActionButton(
                        title: WeekFitLocalizedString("today.photoLog.confirm.retry")
                    ) {
                        coordinator.retryAnalysis()
                    }
                }

                Button(WeekFitLocalizedString("today.photoLog.error.manual")) {
                    coordinator.startManualFallback()
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText.opacity(0.92))
                .padding(.top, 2)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)

            Spacer(minLength: 20)
        }
        .background(QuickActionSheetDesign.Color.sheetBackground(for: .food).ignoresSafeArea())
        .onAppear {
            if error == .subscriptionRequired {
                onRequestPaidSubscription?()
            }
        }
    }

    // MARK: - Shared chrome

    private func photoFlowHeader(
        title: String,
        subtitle: String,
        onClose: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(
                    palette.isLight
                        ? WeekFitLightTokens.shadowContact.opacity(0.16)
                        : Color.white.opacity(0.14)
                )
                .frame(width: 36, height: 3.5)
                .padding(.top, 8)
                .padding(.bottom, 16)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(WeekFitLocalizedString("today.photoLog.flow.eyebrow"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(foodAccent.opacity(palette.isLight ? 0.92 : 0.95))

                    Text(title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .tracking(-1.1)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                WeekFitCloseButton(size: .regular, playsHaptic: false, action: onClose)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    private func heroPhoto(
        _ image: UIImage?,
        dimmed: Bool,
        emptySymbol: String = "fork.knife"
    ) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, 320)
            let radius: CGFloat = 30

            ZStack {
                // Soft warm wash so the photo feels anchored, not floating in void.
                RoundedRectangle(cornerRadius: radius + 10, style: .continuous)
                    .fill(foodAccent.opacity(palette.isLight ? 0.10 : 0.16))
                    .blur(radius: 28)
                    .scaleEffect(0.92)

                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .opacity(dimmed ? 0.88 : 1)
                    } else {
                        ZStack {
                            WeekFitTheme.secondaryText.opacity(palette.isLight ? 0.08 : 0.14)
                            Image(systemName: emptySymbol)
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(dimmed ? foodAccent : WeekFitTheme.secondaryText)
                        }
                    }
                }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(palette.isLight ? 0.55 : 0.22),
                                    foodAccent.opacity(palette.isLight ? 0.28 : 0.35),
                                    Color.white.opacity(palette.isLight ? 0.12 : 0.06),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.15
                        )
                )
                .shadow(
                    color: Color.black.opacity(palette.isLight ? 0.10 : 0.45),
                    radius: 22,
                    y: 14
                )
                .shadow(
                    color: foodAccent.opacity(palette.isLight ? 0.12 : 0.22),
                    radius: 28,
                    y: 10
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxHeight: 320)
    }

    private func primaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryCTAForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    Capsule().fill(foodAccent)
                }
        }
        .buttonStyle(.plain)
    }
}
