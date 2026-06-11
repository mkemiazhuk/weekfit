import SwiftUI
import SwiftData

struct PremiumActivityStartCard: View {

    let title: String
    let subtitle: String
    let imageName: String
    let systemIcon: String
    let accentColor: Color
    let cardBackground: Color
    let textSecondary: Color
    let durationMinutes: Int
    let plannerType: PlannerType
    let badge: String?
    let hasConflict: Bool
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                imageBlock

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let badge {
                            Text(badge)
                                .font(.system(size: 8.8, weight: .bold))
                                .tracking(0.45)
                                .foregroundStyle(accentColor.opacity(0.86))
                                .padding(.horizontal, 7)
                                .frame(height: 18)
                                .background(
                                    Capsule()
                                        .fill(accentColor.opacity(0.10))
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(accentColor.opacity(0.12), lineWidth: 1)
                                }
                        }

                        Spacer(minLength: 0)
                    }

                    Text(title)
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(hasConflict ? 0.46 : 0.96))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(cleanSubtitle)
                            .lineLimit(1)

                        Circle()
                            .fill(textSecondary.opacity(0.28))
                            .frame(width: 3, height: 3)

                        Text(formattedDuration(durationMinutes))
                            .monospacedDigit()
                    }
                    .font(.system(size: 11.8, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(hasConflict ? 0.34 : 0.66))
                    .lineLimit(1)
                }

                Spacer(minLength: 6)

                startControl
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                cardBackground.opacity(0.98),
                                Color.white.opacity(0.030)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(hasConflict ? 0.035 : 0.105),
                                .white.opacity(0.045),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: accentColor.opacity(hasConflict ? 0.0 : 0.045),
                radius: 12,
                y: 5
            )
            .scaleEffect(pressed ? 0.985 : 1.0)
            .opacity(hasConflict ? 0.52 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(hasConflict)
//        .simultaneousGesture(
//            DragGesture(minimumDistance: 0)
//                .onChanged { _ in pressed = true }
//                .onEnded { _ in
//                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
//                        pressed = false
//                    }
//                }
//        )
    }

    private var imageBlock: some View {
        ZStack {
            if !imageName.isEmpty, UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accentColor.opacity(0.105))

                Image(systemName: systemIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accentColor.opacity(0.78))
            }

            LinearGradient(
                colors: [
                    .black.opacity(0.0),
                    .black.opacity(0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.055), lineWidth: 1)
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var startControl: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(hasConflict ? 0.08 : 0.22))
                .frame(width: 42, height: 42)

            Circle()
                .stroke(accentColor.opacity(hasConflict ? 0.08 : 0.18), lineWidth: 1)

            Image(systemName: hasConflict ? "lock.fill" : "play.fill")
                .font(.system(size: hasConflict ? 12 : 13, weight: .bold))
                .foregroundStyle(hasConflict ? .white.opacity(0.28) : .white.opacity(0.94))
                .offset(x: hasConflict ? 0 : 1)
        }
        .frame(width: 42, height: 42)
    }

    private var cleanSubtitle: String {
        if subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plannerType == .workout ? "Training" : "Recovery"
        }

        return subtitle
            .replacingOccurrences(of: "• 60 min", with: "")
            .replacingOccurrences(of: "60 min", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formattedDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60

            if remainingMinutes == 0 {
                return "\(hours)h"
            }

            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(minutes) min"
    }
}
