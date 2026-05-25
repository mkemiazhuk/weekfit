import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel

    @State private var showHero = false
    @State private var showPanel = false
    @State private var showCards = false
    @State private var ambientMotion = false

    private let brandGreen = Color(red: 0.33, green: 0.58, blue: 0.43)
    private let sageGreen = Color(red: 0.54, green: 0.88, blue: 0.65)
    private let champagneGold = Color(red: 0.96, green: 0.75, blue: 0.36)

    private let mutedPurple = Color(red: 0.50, green: 0.36, blue: 0.88)
    private let mutedOrange = Color(red: 0.96, green: 0.56, blue: 0.26)

    var body: some View {
        ZStack {
            Image("weekfit-bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .scaleEffect(showHero ? (ambientMotion ? 1.075 : 1.058) : 1.105)
                .offset(x: ambientMotion ? -8 : 3, y: ambientMotion ? -18 : -10)
                .brightness(-0.02)
                .contrast(1.28)
                .saturation(1.06)
                .blur(radius: showHero ? 0 : 4)
                .opacity(showHero ? 1 : 0.78)
                .animation(.easeOut(duration: 1.35), value: showHero)
                .animation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true), value: ambientMotion)

            cinematicOverlays

            VStack(spacing: 0) {
                heroText
                    .padding(.top, 44)
                    .padding(.horizontal, 34)
                    .opacity(showHero ? 1 : 0)
                    .offset(y: showHero ? 0 : 18)

                insightCards
                    .padding(.horizontal, 34)
                    .padding(.top, 24)
                    .opacity(showCards ? 1 : 0)
                    .offset(y: showCards ? 0 : 16)

                Spacer(minLength: 28)

                bottomAuthPanel
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)
                    .opacity(showPanel ? 1 : 0)
                    .offset(y: showPanel ? 0 : 30)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                showHero = true
            }

            withAnimation(.spring(response: 0.78, dampingFraction: 0.88).delay(0.16)) {
                showCards = true
            }

            withAnimation(.spring(response: 0.76, dampingFraction: 0.9).delay(0.30)) {
                showPanel = true
            }

            ambientMotion = true
        }
    }

    private var cinematicOverlays: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .black.opacity(0.24),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .frame(maxHeight: .infinity, alignment: .top)

            LinearGradient(
                colors: [
                    .black.opacity(0.66),
                    .black.opacity(0.34),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            LinearGradient(
                colors: [
                    .black.opacity(0.64),
                    .black.opacity(0.27),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.16),
                    .black.opacity(0.58),
                    .black.opacity(0.88)
                ],
                startPoint: .center,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.18),
                    .black.opacity(0.42)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)

            RadialGradient(
                colors: [
                    .black.opacity(0.26),
                    .clear
                ],
                center: .init(x: 0.16, y: 0.43),
                startRadius: 20,
                endRadius: 290
            )
            
            RadialGradient(
                colors: [
                    .black.opacity(0.34),
                    .clear
                ],
                center: .init(x: 0.10, y: 0.86),
                startRadius: 20,
                endRadius: 180
            )

            RadialGradient(
                colors: [
                    champagneGold.opacity(0.095),
                    .clear
                ],
                center: .init(x: 0.25, y: 0.32),
                startRadius: 20,
                endRadius: 290
            )

            RadialGradient(
                colors: [
                    brandGreen.opacity(ambientMotion ? 0.11 : 0.065),
                    .clear
                ],
                center: .init(x: 0.78, y: 0.73),
                startRadius: 20,
                endRadius: 340
            )

            RadialGradient(
                colors: [
                    .white.opacity(0.032),
                    .clear
                ],
                center: .init(x: 0.82, y: 0.54),
                startRadius: 30,
                endRadius: 230
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    .clear,
                    .black.opacity(0.18)
                ],
                center: .center,
                startRadius: 120,
                endRadius: 520
            )

            subtleGrainOverlay
                .blendMode(.softLight)
                .opacity(0.032)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var subtleGrainOverlay: some View {
        Canvas { context, size in
            for index in 0..<120 {
                let x = abs(sin(Double(index) * 12.9898)) * size.width
                let y = abs(sin(Double(index) * 78.233)) * size.height

                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(0.50))
                )
            }
        }
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Week\(Text("Fit").foregroundStyle(brandGreen))")
                .foregroundStyle(.white)
                .font(.system(size: 23.5, weight: .bold))
                .tracking(-0.35)
                .shadow(color: brandGreen.opacity(0.16), radius: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text("Feel ready")
                    .foregroundStyle(.white)
                    .font(.system(size: 26.5, weight: .bold))
                    .tracking(-0.45)
                    .shadow(color: .black.opacity(0.30), radius: 10, x: 0, y: 3)

                Text("before you train.")
                    .foregroundStyle(brandGreen.opacity(0.88))
                    .font(.system(size: 26.5, weight: .bold))
                    .tracking(-0.45)
                    .shadow(color: .black.opacity(0.24), radius: 10, x: 0, y: 3)
                .shadow(color: brandGreen.opacity(ambientMotion ? 0.09 : 0.05), radius: 8)
            }

            Text("Recovery, movement and nutrition\nadapted to your day.")
                .font(.system(size: 15.0, weight: .semibold))
                .foregroundStyle(.white.opacity(0.84))
                .lineSpacing(5)
                .padding(.top, 1)
                .frame(maxWidth: 300, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var insightCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            insightCard(
                icon: "heart.fill",
                iconColor: sageGreen,
                title: "Recovery",
                value: "82%",
                subtitle: "Good to go",
                accessory: .ecg,
                width: 185,
                opacity: 0.88,
                depth: 0.92
            )
            .offset(x: -4, y: ambientMotion ? -2 : 2)
            .zIndex(3)

            insightCard(
                icon: "moon.fill",
                iconColor: mutedPurple,
                title: "Sleep",
                value: "Optimized",
                subtitle: "7h 23m",
                accessory: .bars,
                width: 198,
                opacity: 0.82,
                depth: 0.76
            )
            .offset(x: 14, y: ambientMotion ? 2 : -1)
            .zIndex(2)

            insightCard(
                icon: "figure.mind.and.body",
                iconColor: mutedOrange,
                title: "Workout",
                value: "Adjusted",
                subtitle: "Cardio focus",
                accessory: .spark,
                width: 180,
                opacity: 0.74,
                depth: 0.58
            )
            .offset(x: 28, y: ambientMotion ? -1 : 2)
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .leading) {
            LinearGradient(
                colors: [
                    .black.opacity(0.24),
                    .black.opacity(0.09),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 292, height: 226)
            .blur(radius: 28)
            .offset(x: -56, y: 8)
            .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true), value: ambientMotion)
    }

    private func insightCard(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        subtitle: String,
        accessory: InsightAccessory,
        width: CGFloat,
        opacity: Double,
        depth: Double
    ) -> some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 29, height: 29)

                Image(systemName: icon)
                    .font(.system(size: 11.3, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: -1) {
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.74))

                Text(value)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.98))

                Text(subtitle)
                    .font(.system(size: 9.2, weight: .semibold))
                    .foregroundStyle(iconColor.opacity(0.96))
            }

            Spacer(minLength: 2)

            accessoryView(accessory, color: iconColor)
                .scaleEffect(0.66)
                .frame(width: 24)
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: 49)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.48))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(.black.opacity(0.40 + 0.05 * depth))
                }
                .overlay(alignment: .topLeading) {
                    LinearGradient(
                        colors: [
                            .white.opacity(0.095),
                            .white.opacity(0.024),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(.white.opacity(0.085), lineWidth: 0.8)
                }
        }
        .shadow(color: iconColor.opacity(0.055 * depth), radius: 11, x: 0, y: 5)
        .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 12)
        .opacity(opacity)
    }

    private enum InsightAccessory {
        case ecg
        case bars
        case spark
    }

    @ViewBuilder
    private func accessoryView(_ accessory: InsightAccessory, color: Color) -> some View {
        switch accessory {
        case .ecg:
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color.opacity(0.78))
                .frame(width: 34)

        case .bars:
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.76))
                        .frame(
                            width: 4.5,
                            height: CGFloat(8 + index * 4)
                        )
                }
            }

        case .spark:
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color.opacity(0.88))
                .frame(width: 34)
        }
    }

    private var bottomAuthPanel: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await authViewModel.signIn(with: .email)
                }
            } label: {
                HStack {
                    Spacer()

                    Text("Open WeekFit")
                        .font(.system(size: 15.0, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 27, height: 27)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 13.2, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 48)
                .padding(.horizontal, 11)
                .background {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.41, green: 0.68, blue: 0.52),
                                    Color(red: 0.29, green: 0.53, blue: 0.39),
                                    Color(red: 0.21, green: 0.39, blue: 0.30)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.17),
                                            champagneGold.opacity(0.04),
                                            .clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                                .frame(height: 22)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .stroke(.white.opacity(0.19), lineWidth: 1)
                        }
                }
                .shadow(color: brandGreen.opacity(ambientMotion ? 0.12 : 0.08), radius: 12, x: 0, y: 5)
                .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 8)
            }
            .padding(.horizontal, 14)
            .scaleEffect(ambientMotion ? 1.003 : 1.0)
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: ambientMotion)

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10.2, weight: .semibold))

                    Text("Apple Health helps WeekFit work more accurately.")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.66))

                Text("Connect it when you're ready.")
                    .font(.system(size: 11.1, weight: .regular))
                    .foregroundStyle(.white.opacity(0.52))
            }
            .multilineTextAlignment(.center)
            .padding(.top, 2)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var line: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 1)
    }

    private func authButton(
        title: String,
        systemImage: String,
        provider: AuthProvider
    ) -> some View {
        Button {
            Task {
                await authViewModel.signIn(with: provider)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .offset(y: -0.5)

                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.96))
            .frame(maxWidth: .infinity)
            .frame(height: 43)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.42))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.black.opacity(0.30))
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.10),
                                        .white.opacity(0.025),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.13), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.30), radius: 14, x: 0, y: 7)
        }
    }

    private var termsText: some View {
        VStack(spacing: 2) {
            Text("By continuing, you agree to WeekFit’s")
                .font(.system(size: 9.8, weight: .regular))
                .foregroundStyle(.white.opacity(0.48))

            HStack(spacing: 4) {
                Text("Terms of Service")
                    .font(.system(size: 10.2, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))

                Text("and")
                    .font(.system(size: 9.8))
                    .foregroundStyle(.white.opacity(0.46))

                Text("Privacy Policy")
                    .font(.system(size: 10.2, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
        .multilineTextAlignment(.center)
    }
}
