import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    @State private var showBrand = false
    @State private var showHeadline = false
    @State private var showSubtitle = false
    @State private var showCards = false
    @State private var showPanel = false
    @State private var backgroundSettled = false
    @State private var animateRecoveryWaveform = false
    @State private var ambientMotion = false
    @State private var showEmailSignIn = false

    @ScaledMetric(relativeTo: .title3) private var brandFontSize: CGFloat = 22
    @ScaledMetric(relativeTo: .largeTitle) private var headlineFontSize: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var subtitleFontSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var authButtonHeight: CGFloat = 50
    @ScaledMetric(relativeTo: .footnote) private var noteFontSize: CGFloat = 12

    private let brandGreen = Color(red: 0.33, green: 0.58, blue: 0.43)

    private let insightCardsData = LoginOnboardingInsights.loginScreenCards

    private var usesCompactLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var prefersIncreasedContrast: Bool {
        colorSchemeContrast == .increased
    }

    /// Keep copy in the left content column so it never crosses the figure.
    private var heroCopyMaxWidth: CGFloat {
        if usesCompactLayout { return .infinity }
        // Russian headlines wrap longer; widen softly without invading the person.
        if locale.language.languageCode?.identifier == "ru" { return 340 }
        return 320
    }

    var body: some View {
        GeometryReader { geometry in
            let isShortScreen = geometry.size.height < 760
            let topInset = geometry.safeAreaInsets.top + (isShortScreen ? 8 : 12)

            ZStack {
                cinematicBackground

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            heroText
                                .padding(.top, topInset)

                            insightCards
                                .padding(.top, isShortScreen ? LoginMetrics.subtitleToCards - 8 : LoginMetrics.subtitleToCards)
                                .padding(.bottom, isShortScreen ? LoginMetrics.cardsToAuth - 6 : LoginMetrics.cardsToAuth)
                        }
                        .padding(.horizontal, LoginMetrics.horizontal)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)

                    bottomAuthPanel
                        .padding(.horizontal, LoginMetrics.horizontal - 2)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, LoginMetrics.safeBottom))
                        .opacity(showPanel ? 1 : 0)
                        .offset(y: showPanel ? 0 : (reduceMotion ? 0 : 14))
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        // Light status-bar content over the warm photo + soft top wash.
        .preferredColorScheme(.dark)
        .onAppear {
            runEntranceAnimation()
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmailLoginSheet(authViewModel: authViewModel, brandGreen: brandGreen)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Background

    private var cinematicBackground: some View {
        ZStack {
            Image("weekfit-bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .scaleEffect(backgroundSettled ? 1.035 : 1.06)
                .offset(x: backgroundSettled ? -3 : 1, y: backgroundSettled ? -10 : -16)
                .animation(reduceMotion ? nil : .easeOut(duration: 1.2), value: backgroundSettled)

            LoginReadabilityScrim(increasedContrast: prefersIncreasedContrast)

            // Existing bottom auth lift — kept restrained so the photo stays warm above.
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.08),
                    .black.opacity(0.28),
                    .black.opacity(0.52)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.58),
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: - Hero

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Week\(Text("Fit").foregroundStyle(brandGreen))")
                .foregroundStyle(.white)
                .font(.system(size: brandFontSize, weight: .bold, design: .rounded))
                .tracking(-0.3)
                .opacity(showBrand ? 1 : 0)
                .offset(y: showBrand ? 0 : (reduceMotion ? 0 : 8))
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: LoginMetrics.headlineLineGap) {
                Text(WeekFitLocalizedString("login.hero.title.line1"))
                    .foregroundStyle(.white)
                    .font(.system(size: headlineFontSize, weight: .bold))
                    .tracking(-0.55)
                    .lineLimit(usesCompactLayout ? 3 : 2)
                    .minimumScaleFactor(0.84)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(prefersIncreasedContrast ? 0.34 : 0.22), radius: 8, x: 0, y: 2)

                Text(WeekFitLocalizedString("login.hero.title.line2"))
                    .foregroundStyle(brandGreen.opacity(prefersIncreasedContrast ? 1.0 : 0.94))
                    .font(.system(size: headlineFontSize, weight: .bold))
                    .tracking(-0.55)
                    .lineLimit(usesCompactLayout ? 3 : 2)
                    .minimumScaleFactor(0.84)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 2)
            }
            .padding(.top, LoginMetrics.brandToHeadline)
            .opacity(showHeadline ? 1 : 0)
            .offset(y: showHeadline ? 0 : (reduceMotion ? 0 : 10))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Text(WeekFitLocalizedString("login.hero.subtitle"))
                .font(.system(size: subtitleFontSize, weight: .medium))
                .foregroundStyle(WeekFitTheme.whiteOpacity(prefersIncreasedContrast ? 0.96 : 0.90))
                .lineSpacing(4)
                .lineLimit(usesCompactLayout ? 5 : 3)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(prefersIncreasedContrast ? 0.40 : 0.28), radius: 6, x: 0, y: 1)
                .padding(.top, LoginMetrics.headlineToSubtitle)
                .frame(maxWidth: heroCopyMaxWidth, alignment: .leading)
                .opacity(showSubtitle ? 1 : 0)
                .offset(y: showSubtitle ? 0 : (reduceMotion ? 0 : 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Insight Cards

    private var insightCards: some View {
        LoginInsightCardsView(
            cards: insightCardsData,
            animateRecoveryWaveform: animateRecoveryWaveform,
            ambientMotion: ambientMotion
        )
        .opacity(showCards ? 1 : 0)
        .offset(y: showCards ? 0 : (reduceMotion ? 0 : 8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Authentication

    private var bottomAuthPanel: some View {
        VStack(spacing: LoginMetrics.authStack) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task {
                    await authViewModel.handleAppleSignIn(result)
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: authButtonHeight)
            .clipShape(RoundedRectangle(cornerRadius: LoginMetrics.authCornerRadius, style: .continuous))
            .accessibilityIdentifier("login.appleSignIn")

            authDivider

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showEmailSignIn = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "envelope")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))

                    Text(WeekFitLocalizedString("login.action.signIn"))
                        .font(.system(size: subtitleFontSize, weight: .medium))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: max(authButtonHeight - 6, 44))
                .background {
                    let shape = RoundedRectangle(cornerRadius: LoginMetrics.authCornerRadius, style: .continuous)
                    Group {
                        if reduceTransparency {
                            shape.fill(Color.black.opacity(0.42))
                        } else {
                            shape.fill(.ultraThinMaterial.opacity(0.20))
                        }
                    }
                    .overlay {
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(prefersIncreasedContrast ? 0.14 : 0.08),
                                    .white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                    }
                }
            }
            .buttonStyle(LoginSecondaryButtonStyle())
            .accessibilityIdentifier("login.signIn")
            .accessibilityHint(WeekFitLocalizedString("login.action.signIn.hint"))

            appleHealthFooter
        }
    }

    private var appleHealthFooter: some View {
        VStack(spacing: LoginMetrics.footerLineSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.72))
                    .symbolRenderingMode(.hierarchical)
                    .alignmentGuide(.firstTextBaseline) { dimensions in
                        dimensions[.bottom] - 1
                    }
                    .accessibilityHidden(true)

                Text(WeekFitLocalizedString("login.note.appleHealth.line1"))
                    .font(.system(size: noteFontSize, weight: .medium))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.82))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text(WeekFitLocalizedString("login.note.appleHealth.line2"))
                .font(.system(size: noteFontSize, weight: .regular))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.62))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity)
        .padding(.top, LoginMetrics.footerTop)
        .padding(.bottom, LoginMetrics.footerBottom)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(WeekFitLocalizedString("login.note.appleHealth.line1")) \(WeekFitLocalizedString("login.note.appleHealth.line2"))"
        )
    }

    private var authDivider: some View {
        HStack(spacing: 10) {
            dividerLine
            Text(WeekFitLocalizedString("login.or"))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.34))
            dividerLine
        }
        .padding(.vertical, LoginMetrics.dividerSpacing)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(.white.opacity(0.07))
            .frame(height: 0.5)
    }

    // MARK: - Motion

    private func runEntranceAnimation() {
        backgroundSettled = true

        if reduceMotion {
            showBrand = true
            showHeadline = true
            showSubtitle = true
            showCards = true
            showPanel = true
            return
        }

        withAnimation(.easeOut(duration: 0.55)) {
            showBrand = true
        }

        withAnimation(.easeOut(duration: 0.58).delay(0.08)) {
            showHeadline = true
        }

        withAnimation(.easeOut(duration: 0.52).delay(0.16)) {
            showSubtitle = true
        }

        withAnimation(.easeOut(duration: 0.48).delay(0.26)) {
            showCards = true
        }

        withAnimation(.easeOut(duration: 0.50).delay(0.40)) {
            showPanel = true
        }

        withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true).delay(0.9)) {
            ambientMotion = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard !reduceMotion else { return }
            animateRecoveryWaveform = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                animateRecoveryWaveform = false
            }
        }
    }
}

#Preview("Login") {
    LoginView(authViewModel: AuthViewModel())
}

// MARK: - Readability Scrim

/// Soft upper-left content scrim. Sits above the photo, below text/cards/controls.
/// Fades to transparent toward the figure and open landscape — never a global wash.
private struct LoginReadabilityScrim: View {
    let increasedContrast: Bool

    var body: some View {
        let peak = increasedContrast ? 0.46 : 0.40
        let mid = increasedContrast ? 0.20 : 0.16

        ZStack {
            // Status-bar legibility only — thin wash, not a vignette.
            LinearGradient(
                colors: [.black.opacity(increasedContrast ? 0.22 : 0.16), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 108)
            .frame(maxHeight: .infinity, alignment: .top)

            // Soft content-column veil: strongest upper-left, transparent at person/scenery.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(peak), location: 0),
                    .init(color: .black.opacity(mid), location: 0.34),
                    .init(color: .black.opacity(0.06), location: 0.62),
                    .init(color: .clear, location: 1)
                ],
                startPoint: UnitPoint(x: 0.08, y: 0.04),
                endPoint: UnitPoint(x: 0.08, y: 0.68)
            )
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white.opacity(0.85), location: 0.42),
                        .init(color: .white.opacity(0.28), location: 0.68),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: UnitPoint(x: 0.72, y: 0.42)
                )
            }

            // Gentle elliptical center that dissolves into the bright mid-frame —
            // softens headline/subtitle/cards without a hard dark rectangle.
            RadialGradient(
                stops: [
                    .init(color: .black.opacity(mid), location: 0),
                    .init(color: .black.opacity(0.05), location: 0.55),
                    .init(color: .clear, location: 1)
                ],
                center: UnitPoint(x: 0.18, y: 0.22),
                startRadius: 12,
                endRadius: 380
            )
            .scaleEffect(x: 1.15, y: 1.0, anchor: .leading)
            .opacity(0.85)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Button Styles

private struct LoginSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
