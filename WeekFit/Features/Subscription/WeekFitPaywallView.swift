import SwiftUI

struct WeekFitPaywallView: View {
    var source: SubscriptionAnalyticsSource = .root
    var allowsDismiss: Bool = false

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        ZStack {
            palette.appScreenBackground
                .ignoresSafeArea()
            ProfilePremiumBackground(accent: WeekFitTheme.brandGold.opacity(0.55))
                .ignoresSafeArea()

            ViewThatFits(in: .vertical) {
                paywallColumn(flexibleFooterGap: true)
                ScrollView(showsIndicators: false) {
                    paywallColumn(flexibleFooterGap: false)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .id(palette.appearanceInvalidationToken)
        .interactiveDismissDisabled(!allowsDismiss)
        .onAppear {
            SubscriptionAnalytics.paywallViewed(source: source)
        }
        .onChange(of: subscriptionManager.hasFullAccess) { _, hasAccess in
            if hasAccess, allowsDismiss {
                dismiss()
            }
        }
    }

    private enum Layout {
        static let navTopPadding: CGFloat = 6
        static let navBottomPadding: CGFloat = 2
        static let heroTitleToSubtitle: CGFloat = 10
        static let heroToBenefits: CGFloat = 18
        static let benefitsToPlans: CGFloat = 18
        static let benefitStackSpacing: CGFloat = 10
        static let benefitRowVertical: CGFloat = 12
        static let benefitRowHorizontal: CGFloat = 16
        static let benefitIconSize: CGFloat = 26
        static let benefitTitleToBody: CGFloat = 3
        static let planStackSpacing: CGFloat = 12
        static let planCardVertical: CGFloat = 14
        static let planCardLineSpacing: CGFloat = 5
        static let footerTop: CGFloat = 16
        static let footerBottom: CGFloat = 6
        static let footerStackSpacing: CGFloat = 10
        static let flexibleFooterGapMin: CGFloat = 14
        static let restoreMinHeight: CGFloat = 40
    }

    private func paywallColumn(flexibleFooterGap: Bool) -> some View {
        VStack(spacing: 0) {
            navBar
            VStack(alignment: .leading, spacing: 0) {
                OnboardingTitle(text: WeekFitLocalizedString("paywall.title"))
                OnboardingSubtitle(text: WeekFitLocalizedString("paywall.subtitle"))
                    .padding(.top, Layout.heroTitleToSubtitle)
                valueList
                    .padding(.top, Layout.heroToBenefits)
                planOptions
                    .padding(.top, Layout.benefitsToPlans)
                if let message = statusMessage {
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .accessibilityIdentifier("paywall.status")
                }
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
            .padding(.top, 2)

            if flexibleFooterGap {
                Spacer(minLength: Layout.flexibleFooterGapMin)
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: flexibleFooterGap ? .infinity : nil, alignment: .top)
    }

    private var navBar: some View {
        HStack {
            if allowsDismiss {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(
                            width: OnboardingLayout.navControlSize,
                            height: OnboardingLayout.navControlSize
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(WeekFitLocalizedString("common.action.close"))
                .accessibilityIdentifier("paywall.close")
            } else {
                Color.clear.frame(height: 0)
            }
            Spacer()
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.top, Layout.navTopPadding)
        .padding(.bottom, allowsDismiss ? Layout.navBottomPadding : 0)
    }

    private var valueList: some View {
        VStack(spacing: Layout.benefitStackSpacing) {
            valueRow(
                icon: "sparkles",
                title: WeekFitLocalizedString("paywall.value.coach.title"),
                subtitle: WeekFitLocalizedString("paywall.value.coach.body")
            )
            valueRow(
                icon: "calendar",
                title: WeekFitLocalizedString("paywall.value.plan.title"),
                subtitle: WeekFitLocalizedString("paywall.value.plan.body")
            )
            valueRow(
                icon: "chart.line.uptrend.xyaxis",
                title: WeekFitLocalizedString("paywall.value.insights.title"),
                subtitle: WeekFitLocalizedString("paywall.value.insights.body")
            )
        }
    }

    private func valueRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WeekFitTheme.brandGold)
                .frame(width: Layout.benefitIconSize, height: Layout.benefitIconSize)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Layout.benefitTitleToBody) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.benefitRowHorizontal)
        .padding(.vertical, Layout.benefitRowVertical)
        .weekFitPremiumCard(emphasis: .compact, cornerRadius: OnboardingLayout.cardCornerRadius)
        .accessibilityElement(children: .combine)
    }

    private var planOptions: some View {
        VStack(spacing: Layout.planStackSpacing) {
            if let annual = subscriptionManager.annualProduct {
                planCard(for: annual, kind: .annual)
            }
            if let monthly = subscriptionManager.monthlyProduct {
                planCard(for: monthly, kind: .monthly)
            }
            if subscriptionManager.productsFailedToLoad {
                Text(WeekFitLocalizedString("paywall.error.products"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(WeekFitLocalizedString("paywall.plans.accessibility"))
    }

    private func planCard(
        for product: WeekFitProductSnapshot,
        kind: WeekFitSubscriptionProductID
    ) -> some View {
        let selected = subscriptionManager.selectedProductID == product.id
        let trialDays = WeekFitPaywallCopy.introductoryDayCount(from: product.introductoryOffer)
        let savings = savingsPercent

        return Button {
            subscriptionManager.selectProduct(product.id)
        } label: {
            VStack(alignment: .leading, spacing: Layout.planCardLineSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(kind == .annual
                         ? WeekFitLocalizedString("paywall.plan.annual")
                         : WeekFitLocalizedString("paywall.plan.monthly"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                    if kind == .annual {
                        Text(WeekFitLocalizedString("paywall.plan.recommended"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(WeekFitTheme.brandGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background {
                                Capsule().fill(WeekFitTheme.brandGold.opacity(0.16))
                            }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selected ? WeekFitTheme.brandGold : palette.textTertiary)
                        .accessibilityHidden(true)
                }

                if kind == .annual, let trialDays {
                    Text(String(format: WeekFitLocalizedString("paywall.plan.trialFormat"), trialDays))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.brandGold)
                }

                Text(priceLine(for: product, kind: kind))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)

                if kind == .annual, let monthly = product.monthlyEquivalentDisplay {
                    Text(String(format: WeekFitLocalizedString("paywall.plan.monthlyEquivalentFormat"), monthly))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }

                if kind == .annual, let trialDays, let savings {
                    Text(String(format: WeekFitLocalizedString("paywall.plan.saveFormat"), savings))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, Layout.planCardVertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: OnboardingLayout.cardCornerRadius, style: .continuous)
                    .fill(palette.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: OnboardingLayout.cardCornerRadius, style: .continuous)
                            .stroke(
                                selected ? WeekFitTheme.brandGold : palette.borderSoft,
                                lineWidth: selected ? 1.5 : 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(kind == .annual ? "paywall.plan.yearly" : "paywall.plan.monthly")
        .accessibilityLabel(planAccessibilityLabel(product: product, kind: kind, trialDays: trialDays, savings: savings))
    }

    private var footer: some View {
        VStack(spacing: Layout.footerStackSpacing) {
            OnboardingPrimaryButton(
                title: purchaseCTATitle,
                isLoading: subscriptionManager.isPurchaseInFlight,
                isEnabled: subscriptionManager.selectedProduct != nil && !subscriptionManager.isRestoreInFlight
            ) {
                Task { await subscriptionManager.purchaseSelected() }
            }
            .accessibilityIdentifier("paywall.cta")

            #if DEBUG
            Text(
                """
                DEBUG accessState=\(subscriptionManager.accessState)
                hasFullAccess=\(subscriptionManager.hasFullAccess)
                productsFailedToLoad=\(subscriptionManager.productsFailedToLoad)
                lastOutcome=\(String(describing: subscriptionManager.lastOutcome))
                """
            )
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(palette.isLight ? WeekFitLightTokens.textSecondary.opacity(0.65) : .white.opacity(0.55))
            .multilineTextAlignment(.center)
            #endif

            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Text(restoreTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Layout.restoreMinHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(subscriptionManager.isRestoreInFlight || subscriptionManager.isPurchaseInFlight)
            .accessibilityIdentifier("paywall.restore")
            .accessibilityLabel(WeekFitLocalizedString("paywall.restore"))

            legalRow
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.top, Layout.footerTop)
        .padding(.bottom, Layout.footerBottom)
        .safeAreaPadding(.bottom, 2)
    }

    private var legalRow: some View {
        HStack(spacing: 6) {
            Button(WeekFitLocalizedString("paywall.legal.terms")) {
                openURL(WeekFitLegalURLs.terms)
            }
            Text(WeekFitLocalizedString("paywall.legal.separator"))
                .foregroundStyle(palette.textTertiary)
            Button(WeekFitLocalizedString("paywall.legal.privacy")) {
                openURL(WeekFitLegalURLs.privacy)
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(palette.textTertiary)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 28)
        .contentShape(Rectangle())
        .padding(.top, 0)
        .minimumScaleFactor(0.85)
        .lineLimit(1)
        .accessibilityElement(children: .contain)
    }

    private var purchaseCTATitle: String {
        if let days = WeekFitPaywallCopy.introductoryDayCount(
            from: subscriptionManager.selectedProduct?.introductoryOffer
        ) {
            return String(format: WeekFitLocalizedString("paywall.cta.startTrialFormat"), days)
        }
        return WeekFitLocalizedString("paywall.cta.continue")
    }

    private var restoreTitle: String {
        subscriptionManager.isRestoreInFlight
            ? WeekFitLocalizedString("paywall.restore.inProgress")
            : WeekFitLocalizedString("paywall.restore")
    }

    private var savingsPercent: Int? {
        guard let monthly = subscriptionManager.monthlyProduct,
              let annual = subscriptionManager.annualProduct,
              annual.introductoryOffer != nil
        else { return nil }
        return WeekFitPaywallCopy.savingsPercent(
            monthlyPrice: monthly.price,
            yearlyPrice: annual.price
        )
    }

    private func priceLine(for product: WeekFitProductSnapshot, kind: WeekFitSubscriptionProductID) -> String {
        let format = kind == .annual
            ? WeekFitLocalizedString("paywall.price.yearFormat")
            : WeekFitLocalizedString("paywall.price.monthFormat")
        return String(format: format, product.displayPrice)
    }

    private func planAccessibilityLabel(
        product: WeekFitProductSnapshot,
        kind: WeekFitSubscriptionProductID,
        trialDays: Int?,
        savings: Int?
    ) -> String {
        var parts = [
            kind == .annual
                ? WeekFitLocalizedString("paywall.plan.annual")
                : WeekFitLocalizedString("paywall.plan.monthly"),
            priceLine(for: product, kind: kind)
        ]
        if let trialDays {
            parts.append(String(format: WeekFitLocalizedString("paywall.plan.trialFormat"), trialDays))
        }
        if let savings {
            parts.append(String(format: WeekFitLocalizedString("paywall.plan.saveFormat"), savings))
        }
        return parts.joined(separator: ", ")
    }

    private var statusMessage: String? {
        switch subscriptionManager.lastOutcome {
        case .pending:
            return WeekFitLocalizedString("paywall.error.pending")
        case .failedVerification:
            return WeekFitLocalizedString("paywall.error.verification")
        case .failed, .productsUnavailable:
            return WeekFitLocalizedString("paywall.error.failed")
        case .cancelled, .success, .none:
            return nil
        }
    }
}

struct LegacyAccessThanksSheet: View {
    var onDismiss: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(WeekFitLocalizedString("paywall.legacy.title"))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(WeekFitLocalizedString("paywall.legacy.body"))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            OnboardingPrimaryButton(title: WeekFitLocalizedString("common.action.done")) {
                onDismiss()
            }
            .accessibilityIdentifier("paywall.legacy.done")
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(palette.appScreenBackground.ignoresSafeArea())
        .presentationDetents([.medium])
        .weekFitSheetChrome(cornerRadius: 36)
        .interactiveDismissDisabled(false)
    }
}
