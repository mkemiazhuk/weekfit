import SwiftUI

struct LoginInsightCardsView: View {
    let cards: [LoginInsightCardData]
    let animateRecoveryWaveform: Bool
    let ambientMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let layout = LoginInsightCardLayout.metrics(for: card)

                LoginInsightCardView(
                    card: card,
                    layout: layout,
                    animateWaveform: card.id == "recovery" && animateRecoveryWaveform
                )
                .offset(
                    x: layout.offsetX,
                    y: ambientYOffset(for: index)
                )
                .zIndex(Double(cards.count - index))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(
            .easeInOut(duration: 4.8).repeatForever(autoreverses: true),
            value: ambientMotion
        )
        .accessibilityElement(children: .contain)
    }

    private func ambientYOffset(for index: Int) -> CGFloat {
        switch index {
        case 0:
            return ambientMotion ? -2 : 2
        case 1:
            return ambientMotion ? 2 : -1
        default:
            return ambientMotion ? -1 : 2
        }
    }
}

struct LoginInsightCardLayout: Equatable {
    let width: CGFloat
    /// Relative visual depth — darker glass, quieter border; does not dim text opacity.
    let depth: Double
    let offsetX: CGFloat

    static func metrics(for card: LoginInsightCardData) -> LoginInsightCardLayout {
        switch card.prominence {
        case .primary:
            return LoginInsightCardLayout(
                width: 185,
                depth: 1.0,
                offsetX: -4
            )
        case .supporting(1):
            return LoginInsightCardLayout(
                width: 198,
                depth: 0.86,
                offsetX: 14
            )
        case .supporting(2):
            return LoginInsightCardLayout(
                width: 180,
                depth: 0.74,
                offsetX: 28
            )
        case .supporting:
            return LoginInsightCardLayout(
                width: 180,
                depth: 0.74,
                offsetX: 20
            )
        }
    }
}

struct LoginInsightCardView: View {
    let card: LoginInsightCardData
    let layout: LoginInsightCardLayout
    let animateWaveform: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 9.5
    @ScaledMetric(relativeTo: .body) private var valueSize: CGFloat = 13.5
    @ScaledMetric(relativeTo: .caption2) private var subtitleSize: CGFloat = 9.2
    @ScaledMetric(relativeTo: .caption) private var iconContainerSize: CGFloat = 29
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 49

    private let cornerRadius: CGFloat = 17

    private var isPrimary: Bool {
        if case .primary = card.prominence { return true }
        return false
    }

    private var prefersIncreasedContrast: Bool {
        colorSchemeContrast == .increased
    }

    var body: some View {
        HStack(spacing: 9) {
            icon

            VStack(alignment: .leading, spacing: 0) {
                Text(card.title)
                    .font(.system(size: labelSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(prefersIncreasedContrast ? 0.78 : 0.64))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Text(card.value)
                    .font(.system(size: valueSize, weight: .bold))
                    .foregroundStyle(.white.opacity(prefersIncreasedContrast ? 1.0 : 0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .padding(.top, 1)

                Text(card.subtitle)
                    .font(.system(size: subtitleSize, weight: .semibold))
                    .foregroundStyle(card.accent.iconColor.opacity(prefersIncreasedContrast ? 0.92 : 0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .padding(.top, 1)
            }

            Spacer(minLength: 2)

            accessory
                .scaleEffect(0.66)
                .frame(width: 24)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .frame(width: layout.width, height: rowHeight, alignment: .leading)
        .background { cardSurface }
        .shadow(color: .black.opacity(0.14 * layout.depth), radius: 12, x: 0, y: 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title). \(card.value). \(card.subtitle)")
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(card.accent.iconColor.opacity(prefersIncreasedContrast ? 0.18 : 0.12))
                .frame(width: iconContainerSize, height: iconContainerSize)

            Image(systemName: card.accent.systemImage)
                .font(.system(size: 11.3, weight: .semibold))
                .foregroundStyle(card.accent.iconColor.opacity(prefersIncreasedContrast ? 1.0 : 0.92))
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var accessory: some View {
        switch card.accessory {
        case .ecg:
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(card.accent.iconColor.opacity(isPrimary ? 0.42 : 0.34))
                .symbolEffect(
                    .variableColor.iterative,
                    options: .repeating.speed(0.45),
                    isActive: animateWaveform
                )
                .frame(width: 34)

        case .bars:
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(card.accent.iconColor.opacity(isPrimary ? 0.42 : 0.34))
                        .frame(
                            width: 4.5,
                            height: CGFloat(8 + index * 4)
                        )
                }
            }

        case .spark:
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(card.accent.iconColor.opacity(isPrimary ? 0.42 : 0.34))
                .frame(width: 34)
        }
    }

    private var cardSurface: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        // Dark glass fill carries quietness — do not dim the whole card (and its text).
        let glassFill = reduceTransparency
            ? 0.62 + 0.08 * layout.depth
            : 0.40 + 0.08 * layout.depth
        let materialOpacity = reduceTransparency ? 0.0 : 0.55
        let borderOpacity = prefersIncreasedContrast ? 0.12 : 0.075

        return shape
            .fill(.ultraThinMaterial.opacity(materialOpacity))
            .overlay {
                shape.fill(.black.opacity(glassFill))
            }
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        .white.opacity(prefersIncreasedContrast ? 0.08 : 0.055),
                        .white.opacity(0.012),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            }
            .overlay {
                shape.stroke(.white.opacity(borderOpacity), lineWidth: 0.6)
            }
    }
}

enum LoginMetrics {
    static let horizontal: CGFloat = 28
    static let safeBottom: CGFloat = 16

    static let brandToHeadline: CGFloat = 18
    static let headlineLineGap: CGFloat = -1
    static let headlineToSubtitle: CGFloat = 14
    static let subtitleToCards: CGFloat = 32
    static let cardsToAuth: CGFloat = 28

    static let authStack: CGFloat = 14
    static let authCornerRadius: CGFloat = 14
    static let dividerSpacing: CGFloat = 12
    static let footerTop: CGFloat = 20
    static let footerBottom: CGFloat = 4
    static let footerLineSpacing: CGFloat = 6
}
