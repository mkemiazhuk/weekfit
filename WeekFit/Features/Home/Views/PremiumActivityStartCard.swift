import SwiftUI
import SwiftData

struct PremiumActivityStartCard: View {
    let title: String
    let subtitle: String
    let systemIcon: String
    let imageName: String
    let accentColor: Color
    let cardBackground: Color
    let textSecondary: Color
    let durationMinutes: Int
    let plannerType: PlannerType

    let hasConflict: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !hasConflict else { return }
            action()
        } label: {
            HStack(spacing: 13) {
                activityImage

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(metadataText)
                        .font(.system(size: 12.2, weight: .semibold))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                actionBadge
            }
            .padding(.leading, 12)
            .padding(.trailing, 13)
            .frame(height: 64)
            .background(cardSurface)
            .overlay(cardStroke)
            .shadow(
                color: .black.opacity(hasConflict ? 0.04 : 0.08),
                radius: hasConflict ? 3 : 6,
                y: hasConflict ? 1 : 2
            )
            .opacity(hasConflict ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .disabled(hasConflict)
    }

    private var activityImage: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: 72, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                LinearGradient(
                    colors: [
                        .black.opacity(0.05),
                        .black.opacity(0.28)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(hasConflict ? 0.025 : 0.07), lineWidth: 1)
            }
            .opacity(hasConflict ? 0.42 : 1)
    }

    private var actionBadge: some View {
        Group {
            if hasConflict {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8.5, weight: .bold))

                    Text("Locked")
                        .font(.system(size: 10.5, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.28))
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(.white.opacity(0.035))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.035), lineWidth: 1)
                )
            } else {
                HStack(spacing: 5) {
                    Text("Start")
                        .font(.system(size: 11.5, weight: .semibold))

                    Image(systemName: "play.fill")
                        .font(.system(size: 7.8, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.94))
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(
                    Capsule()
                        .fill(accentColor.opacity(0.72))
                        .overlay {
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.18),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(Capsule())
                        }
                )
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(
                    color: accentColor.opacity(0.16),
                    radius: 5,
                    y: 2
                )
            }
        }
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: hasConflict
                    ? [
                        cardBackground.opacity(0.13),
                        cardBackground.opacity(0.08)
                    ]
                    : [
                        cardBackground.opacity(0.46),
                        cardBackground.opacity(0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: hasConflict
                            ? [
                                .white.opacity(0.006),
                                .clear
                            ]
                            : [
                                .white.opacity(0.045),
                                .white.opacity(0.012)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: hasConflict
                    ? [
                        .white.opacity(0.025),
                        .clear
                    ]
                    : [
                        .white.opacity(0.08),
                        .clear,
                        accentColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var metadataText: String {
        if durationMinutes > 0 {
            return "\(subtitle) • \(durationMinutes) min"
        } else {
            return subtitle
        }
    }

    private var titleColor: Color {
        hasConflict ? .white.opacity(0.36) : .white.opacity(0.96)
    }

    private var subtitleColor: Color {
        hasConflict ? .white.opacity(0.22) : textSecondary.opacity(0.72)
    }
}
