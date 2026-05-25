    import SwiftUI

    struct WeekFitHeroHeader: View {

        let selectedDateTitle: String
        let showContent: Bool

        let textPrimary: Color
        let softShadow: Color

        let onPreviousDay: () -> Void
        let onToday: () -> Void
        let onNextDay: () -> Void
        let onProfileTap: () -> Void

        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                Text(selectedDateTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(textPrimary.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                dateControl

                Button(action: onProfileTap) {
                    avatarButton
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 0)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 10)
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: showContent)
        }

        private var dateControl: some View {
            HStack(spacing: 10) {
                Button(action: onPreviousDay) {
                    Image(systemName: "chevron.left")
                }

                Button(action: onToday) {
                    Text("Today")
                        .font(.system(size: 14, weight: .semibold))
                }

                Button(action: onNextDay) {
                    Image(systemName: "chevron.right")
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(WeekFitTheme.primaryText.opacity(0.84))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.065))
                    }
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(WeekFitTheme.borderSoft, lineWidth: 1)
            }
            .shadow(color: softShadow.opacity(0.75), radius: 12, y: 6)
        }

        public var avatarButton: some View {
            ZStack {

                Circle()
                    .fill(WeekFitTheme.primaryGreen.opacity(0.16))
                    .blur(radius: 16)
                    .frame(width: 62, height: 62)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                WeekFitTheme.primaryGreen.opacity(0.72),
                                .white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.6
                    )
                    .frame(width: 52, height: 52)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 246 / 255, green: 231 / 255, blue: 200 / 255),
                                Color(red: 214 / 255, green: 176 / 255, blue: 106 / 255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 44, height: 44)

                Text("MK")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(width: 52, height: 52)
            .contentShape(Circle())
            .shadow(
                color: .black.opacity(0.32),
                radius: 12,
                y: 8
            )
        }
    }
