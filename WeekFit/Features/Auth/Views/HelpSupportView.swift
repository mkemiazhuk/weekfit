import SwiftUI
import UIKit

struct HelpSupportView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var showSupportSheet = false
    @State private var showCopiedToast = false

    @State private var showFAQView = false
    @State private var showGuidesView = false

    private let supportEmail = "support@weekfit.app"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProfilePremiumBackground(accent: WeekFitStyle.brandGreen)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection
                    quickHelpSection
//                    resourcesSection
                    footerSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 22)
            }

            if showSupportSheet {
                supportSheetOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showFAQView) {
            FAQView()
        }
        .navigationDestination(isPresented: $showGuidesView) {
            GuidesView()
        }
        // No nested .sheet — Help lives inside Settings sheet already.
    }
}

// MARK: - Main UI

private extension HelpSupportView {

    var backgroundGlow: some View {
        VStack {
            Circle()
                .fill(WeekFitStyle.brandGreen.opacity(0.075))
                .frame(width: 220, height: 220)
                .blur(radius: 120)
                .offset(x: 84, y: 22)

            Spacer()
        }
        .ignoresSafeArea()
    }

    var heroSection: some View {
        VStack(alignment: .leading, spacing: 26) {
            headerSection

            VStack(alignment: .leading, spacing: 7) {
                Text(WeekFitLocalizedString("support.help.hero"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
            }
            .padding(.top, 2)
        }
    }

    var headerSection: some View {
        ProfilePremiumHeader(
            title: WeekFitLocalizedString("support.help.title"),
            accent: WeekFitStyle.brandGreen
        ) {
            dismiss()
        }
    }

    var quickHelpSection: some View {
        supportSection(title: WeekFitLocalizedString("support.help.quickHelp")) {
            SupportRow(
                icon: "message.fill",
                iconColor: WeekFitStyle.brandGreen,
                title: WeekFitLocalizedString("support.contactSupport"),
                subtitle: WeekFitLocalizedString("support.contactSupport.subtitle")
            ) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                    showSupportSheet = true
                }
            }

            SupportRow(
                icon: "questionmark",
                iconColor: .cyan,
                title: WeekFitLocalizedString("support.faq.title"),
                subtitle: WeekFitLocalizedString("support.faq.subtitle")
            ) {
                showFAQView = true
            }

            SupportRow(
                icon: "doc.text.fill",
                iconColor: .teal,
                title: WeekFitLocalizedString("support.guides.title"),
                subtitle: WeekFitLocalizedString("support.guides.subtitle")
            ) {
                showGuidesView = true
            }
        }
    }

    var resourcesSection: some View {
        supportSection(title: WeekFitLocalizedString("support.help.resources")) {
            SupportRow(
                icon: "heart.text.square.fill",
                iconColor: .mint,
                title: WeekFitLocalizedString("settings.profile.item.healthSignals"),
                subtitle: WeekFitLocalizedString("settings.profile.item.healthSignals.subtitle")
            ) {
                openAppSettings()
            }

            SupportRow(
                icon: "lock.shield.fill",
                iconColor: .indigo,
                title: WeekFitLocalizedString("settings.profile.item.privacy"),
                subtitle: WeekFitLocalizedString("settings.profile.item.privacy.subtitle")
            ) {
                openAppSettings()
            }

            SupportRow(
                icon: "doc.plaintext.fill",
                iconColor: .orange,
                title: WeekFitLocalizedString("settings.profile.item.termsPrivacy"),
                subtitle: WeekFitLocalizedString("settings.profile.item.termsPrivacy.subtitle")
            ) {
                openAppSettings()
            }
        }
    }

    func supportSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 11) {
                content()
            }
        }
    }

    var footerSection: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(.white.opacity(0.08))
                .frame(width: 44, height: 5)

            VStack(spacing: 4) {
                Text(WeekFitLocalizedString("support.help.footerTitle"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.36))

                Text(WeekFitLocalizedString("support.help.footerSubtitle"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.24))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 18)
    }
}

// MARK: - Support Sheet

private extension HelpSupportView {

    var supportSheetOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.52)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.90)) {
                        showSupportSheet = false
                    }
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(WeekFitTheme.whiteOpacity(0.18))
                    .frame(width: 38, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                supportSheet
                    .frame(maxWidth: .infinity)
                    .frame(height: 286)
            }
            .frame(maxWidth: .infinity)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: 32,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 32,
                    style: .continuous
                )
                .fill(WeekFitTheme.backgroundColor)
                .ignoresSafeArea(edges: .bottom)
            }
            .preferredColorScheme(.dark)
        }
    }

    var supportSheet: some View {
        ZStack {
            Color.clear

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(WeekFitStyle.brandGreen.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "message.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(WeekFitStyle.brandGreen)
                }

                VStack(spacing: 5) {
                    Text(WeekFitLocalizedString("support.contactSupport"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(WeekFitLocalizedString("support.sheet.subtitle"))
                        .font(.system(size: 13.2, weight: .medium))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.54))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button {
                        openEmailApp()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                            Text(WeekFitLocalizedString("support.sheet.openEmail"))
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            WeekFitStyle.brandGreen,
                                            WeekFitStyle.brandGreen.opacity(0.84)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button {
                        copySupportEmail()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.on.doc.fill")
                            Text(WeekFitLocalizedString("support.copyEmailAddress"))
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            Capsule()
                                .fill(.white.opacity(0.07))
                                .overlay {
                                    Capsule()
                                        .stroke(.white.opacity(0.09), lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }

    var copiedToast: some View {
        VStack {
            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(WeekFitStyle.brandGreen)

                Text(WeekFitLocalizedString("support.emailCopied"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background {
                Capsule()
                    .fill(.black.opacity(0.88))
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.11), lineWidth: 1)
                    }
            }
            .padding(.bottom, 34)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Actions

private extension HelpSupportView {

    func openEmailApp() {
        let subject = "WeekFit Support"
        let body = """
        Hi WeekFit Team,

        I need help with:

        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let url = URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)") else {
            copySupportEmail()
            return
        }

        UIApplication.shared.open(url) { success in
            if !success {
                copySupportEmail()
            }
        }
    }

    func copySupportEmail() {
        UIPasteboard.general.string = supportEmail
        withAnimation(.spring(response: 0.32, dampingFraction: 0.90)) {
            showSupportSheet = false
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            showCopiedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.22)) {
                showCopiedToast = false
            }
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Reusable Row

private struct SupportRow: View {

    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(size: 13.2, weight: .medium))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.54))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.22))
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 12)
            .frame(minHeight: 78)
            .profilePremiumCard(cornerRadius: 26, glow: iconColor.opacity(0.020))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Pressable Button Style

private struct PressableButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}


private func localizedSupportItems(prefix: String, count: Int) -> [(String, String)] {
    (1...count).compactMap { index in
        let item = String(format: "%02d", index)
        let titleKey = "\(prefix).item\(item).title"
        let textKey = "\(prefix).item\(item).text"
        let title = WeekFitLocalizedString(titleKey)
        let text = WeekFitLocalizedString(textKey)
        guard title != titleKey, text != textKey else { return nil }
        return (title, text)
    }
}

// MARK: - FAQ View

struct FAQView: View {

    @Environment(\.dismiss) private var dismiss

    private var items: [(String, String)] {
        localizedSupportItems(prefix: "support.faq", count: 43)
    }

    var body: some View {
        SupportDetailView(
            title: WeekFitLocalizedString("support.faq.title"),
            subtitle: WeekFitLocalizedString("support.faq.subtitle"),
            icon: "questionmark",
            iconColor: .cyan,
            items: items,
            dismiss: dismiss
        )
    }
}

// MARK: - Guides View

struct GuidesView: View {

    @Environment(\.dismiss) private var dismiss

    private var items: [(String, String)] {
        localizedSupportItems(prefix: "support.guides", count: 25)
    }

    var body: some View {
        SupportDetailView(
            title: WeekFitLocalizedString("support.guides.title"),
            subtitle: WeekFitLocalizedString("support.guides.subtitle"),
            icon: "doc.text.fill",
            iconColor: .teal,
            items: items,
            dismiss: dismiss
        )
    }
}

// MARK: - Shared Detail View

struct SupportDetailView: View {

    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let items: [(String, String)]
    let dismiss: DismissAction

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProfilePremiumBackground(accent: iconColor)

            VStack(spacing: 0) {

                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    introSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 18)
                .background(Color.black)

                ScrollView(showsIndicators: false) {
                    contentSection
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private extension SupportDetailView {

    var backgroundGlow: some View {
        VStack {
            Circle()
                .fill(iconColor.opacity(0.075))
                .frame(width: 220, height: 220)
                .blur(radius: 120)
                .offset(x: 84, y: 22)

            Spacer()
        }
        .ignoresSafeArea()
    }

    var headerSection: some View {
        ProfilePremiumHeader(
            title: title,
            accent: iconColor
        ) {
            dismiss()
        }
    }

    var introSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()

                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.07))
                        .blur(radius: 22)
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 54, height: 54)

                Spacer()
            }

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
        }
    }

    var contentSection: some View {
        VStack(spacing: 11) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                infoCard(title: item.0, text: item.1)
            }
        }
    }

    func infoCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(text)
                .font(.system(size: 13.2, weight: .medium))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.54))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            Color.clear
                .profilePremiumCard(cornerRadius: 22, glow: iconColor.opacity(0.020))
        }
    }
}
