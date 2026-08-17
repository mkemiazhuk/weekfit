import SwiftUI
import UIKit

struct ConfirmationDialogView: View {
    let icon: String
    let iconTint: Color
    let title: String
    let message: String
    let secondaryTitle: String?
    let primaryTitle: String
    var isPrimaryDestructive = false
    var dismissOnBackgroundTap = true
    let onSecondary: (() -> Void)?
    let onPrimary: () -> Void

    @Environment(\.weekFitPalette) private var palette

    private let destructiveRed = Color(red: 255/255, green: 83/255, blue: 88/255)
    private let buttonMinHeight: CGFloat = 48

    init(
        icon: String,
        iconTint: Color,
        title: String,
        message: String,
        secondaryTitle: String? = nil,
        primaryTitle: String,
        isPrimaryDestructive: Bool = false,
        dismissOnBackgroundTap: Bool = true,
        onSecondary: (() -> Void)? = nil,
        onPrimary: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconTint = iconTint
        self.title = title
        self.message = message
        self.secondaryTitle = secondaryTitle
        self.primaryTitle = primaryTitle
        self.isPrimaryDestructive = isPrimaryDestructive
        self.dismissOnBackgroundTap = dismissOnBackgroundTap
        self.onSecondary = onSecondary
        self.onPrimary = onPrimary
    }

    var body: some View {
        ZStack {
            Button {
                guard dismissOnBackgroundTap else { return }
                onSecondary?()
            } label: {
                Color.black.opacity(palette.isLight ? 0.22 : 0.58)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            dialogCard
                .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                .frame(maxWidth: .infinity)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .zIndex(20)
    }

    private var dialogCard: some View {
        VStack(alignment: .center, spacing: 18) {
            iconView
                .frame(maxWidth: .infinity)

            VStack(alignment: .center, spacing: 9) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .tracking(-0.25)
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text(message)
                    .font(.system(size: 13.4, weight: .medium, design: .rounded))
                    .lineSpacing(3)
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            actionRow
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial.opacity(palette.isLight ? 0.88 : 0.62))
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: palette.isLight
                                    ? [
                                        Color.white.opacity(0.96),
                                        WeekFitTheme.cardSurfaceElevated,
                                        WeekFitTheme.cardSurface
                                    ]
                                    : [
                                        WeekFitTheme.whiteOpacity(0.092),
                                        WeekFitTheme.backgroundColor.opacity(0.96),
                                        Color.black.opacity(0.78)
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    WeekFitTheme.whiteOpacity(0.13),
                                    iconTint.opacity(0.13),
                                    WeekFitTheme.whiteOpacity(0.035)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: WeekFitTheme.cardShadow, radius: 30, y: 18)
        .shadow(color: iconTint.opacity(0.06), radius: 18, y: 8)
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(iconTint.opacity(0.14))
                .frame(width: 58, height: 58)
                .blur(radius: 10)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            iconTint.opacity(0.18),
                            WeekFitTheme.whiteOpacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle()
                        .stroke(iconTint.opacity(0.24), lineWidth: 1)
                }
                .frame(width: 54, height: 54)

            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconTint.opacity(0.96))
                // Optical center for triangle glyphs (SF Symbol sits slightly high/left).
                .offset(x: 0.5, y: 0.5)
        }
        .frame(width: 58, height: 58)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var actionRow: some View {
        if let secondaryTitle {
            HStack(alignment: .center, spacing: 10) {
                dialogButton(
                    title: secondaryTitle,
                    foreground: WeekFitTheme.primaryText.opacity(0.82),
                    background: palette.isLight
                        ? Color.black.opacity(0.06)
                        : WeekFitTheme.whiteOpacity(0.065),
                    border: palette.isLight
                        ? Color.black.opacity(0.04)
                        : WeekFitTheme.whiteOpacity(0.060),
                    action: { onSecondary?() }
                )

                dialogButton(
                    title: primaryTitle,
                    foreground: .white.opacity(0.96),
                    background: primaryColor.opacity(isPrimaryDestructive ? 0.78 : 0.82),
                    border: primaryColor.opacity(0.22),
                    action: onPrimary
                )
            }
            .frame(maxWidth: .infinity)
            // Match heights when the primary title wraps to two lines.
            .fixedSize(horizontal: false, vertical: true)
        } else {
            dialogButton(
                title: primaryTitle,
                foreground: .black.opacity(0.82),
                background: WeekFitTheme.meal.opacity(0.90),
                border: WeekFitTheme.meal.opacity(0.22),
                action: onPrimary
            )
        }
    }

    private var primaryColor: Color {
        isPrimaryDestructive ? destructiveRed : WeekFitTheme.meal
    }

    private func dialogButton(
        title: String,
        foreground: Color,
        background: Color,
        border: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.system(size: 14.2, weight: .bold, design: .rounded))
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(background)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(border, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(WeekFitDialogButtonStyle())
        .frame(maxWidth: .infinity, minHeight: buttonMinHeight, maxHeight: .infinity)
    }
}

private struct WeekFitDialogButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
