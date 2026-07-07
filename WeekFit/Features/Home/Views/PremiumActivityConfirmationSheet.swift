import SwiftUI

struct PremiumActivityConfirmationSheet: View {
    let icon: String
    let accentColor: Color
    let title: String
    let messageFormat: String
    let highlightedName: String
    let confirmTitle: String
    let skipTitle: String
    let onConfirm: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.14))
                .frame(width: 42, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 18)

            VStack(spacing: 22) {
                iconBadge

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.96))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)

                    messageText
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)

                VStack(spacing: 10) {
                    confirmButton
                    skipButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(QuickActionSheetDesign.Color.sheetBackground.ignoresSafeArea())
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.16))
                .frame(width: 56, height: 56)
                .blur(radius: 8)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.22),
                            WeekFitTheme.whiteOpacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle()
                        .stroke(accentColor.opacity(0.28), lineWidth: 1)
                }
                .frame(width: 52, height: 52)

            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accentColor.opacity(0.96))
        }
    }

    @ViewBuilder
    private var messageText: some View {
        let formatted = String(format: messageFormat, highlightedName)
        if let attributed = try? AttributedString(
            markdown: formatted,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
        } else {
            Text(formatted)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
        }
    }

    private var confirmButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onConfirm()
        } label: {
            Text(confirmTitle)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.black.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.98),
                                    accentColor.opacity(0.88)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(accentColor.opacity(0.34), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(PremiumSheetButtonStyle())
    }

    private var skipButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onSkip()
        } label: {
            Text(skipTitle)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(WeekFitTheme.whiteOpacity(0.055))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(WeekFitTheme.whiteOpacity(0.06), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(PremiumSheetButtonStyle())
    }
}

private struct PremiumSheetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
