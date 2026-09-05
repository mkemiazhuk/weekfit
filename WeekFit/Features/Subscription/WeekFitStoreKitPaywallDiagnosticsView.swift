import SwiftUI

/// Temporary DEBUG-only StoreKit price diagnostics for the paywall.
///
/// Uses the same `WeekFitProductSnapshot` instances as plan cards — no separate
/// product fetch. Remove after the Poland/USD storefront investigation.
struct WeekFitStoreKitPaywallDiagnosticsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var timelineDiagnostics = WeekFitStoreKitTimelineDiagnostics.shared
    @ObservedObject private var forcePaywall = WeekFitForcePaywallStore.shared
    @Environment(\.weekFitPalette) private var palette
    @State private var isExpanded = true

    /// When true, "Open Paywall" is useful (e.g. Access Status). On the root
    /// blocking paywall the button still re-signals manual presentation.
    var showsOpenPaywallButton: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                // Always show controls when this diagnostics surface is visible
                // (DEBUG only embeds this view). Status text alone
                // previously looked like a dead "Force Paywall: OFF" with no toggle.
                forcePaywallControls

                Text(diagnosticsText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(.top, 8)
        } label: {
            Text("StoreKit Diagnostics")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.borderSoft, lineWidth: 1)
                }
        }
        .accessibilityIdentifier("paywall.storekitDiagnostics")
    }

    @ViewBuilder
    private var forcePaywallControls: some View {
        if forcePaywall.isAvailable {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: forcePaywallEnabledBinding) {
                    Text("Force Paywall")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                }
                .tint(WeekFitTheme.brandGold)
                .accessibilityIdentifier("paywall.diagnostics.forcePaywall")

                Text(forcePaywallStatusText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("paywall.diagnostics.forcePaywallStatus")

                if showsOpenPaywallButton {
                    Button {
                        if !forcePaywall.isForcePaywallActive {
                            forcePaywall.setEnabled(true)
                        }
                        forcePaywall.requestOpenPaywall()
                    } label: {
                        Text(forcePaywall.isForcePaywallActive ? "Open Paywall" : "Enable & Open Paywall")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(WeekFitTheme.brandGold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(WeekFitTheme.brandGold.opacity(0.55), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("paywall.diagnostics.openPaywall")
                }
            }
            .padding(.bottom, 4)
        }
    }

    private var forcePaywallEnabledBinding: Binding<Bool> {
        Binding(
            get: { forcePaywall.isEnabled },
            set: { forcePaywall.setEnabled($0) }
        )
    }

    private var forcePaywallStatusText: String {
        let access = WeekFitStoreKitPaywallDiagnosticsFormatter.accessStateLabel(
            subscriptionManager.accessState
        )
        let force = forcePaywall.isForcePaywallActive ? "ON" : "OFF"
        let presented = forcePaywall.isManualPaywallPresented ? "yes" : "no"
        return """
        Real access state: \(access)
        Force Paywall: \(force)
        Forced presentation: \(presented)
        """
    }

    private var diagnosticsText: String {
        WeekFitStoreKitPaywallDiagnosticsFormatter.text(
            distribution: AppDistribution.current,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            storefrontCountryCode: subscriptionManager.storefrontCountryCode,
            storefrontID: subscriptionManager.storefrontID,
            rawReturnedCount: subscriptionManager.lastStoreProductsReturnedCount,
            products: subscriptionManager.products,
            productsFailedToLoad: subscriptionManager.productsFailedToLoad,
            accessState: subscriptionManager.accessState,
            forcePaywallActive: forcePaywall.isForcePaywallActive,
            timelineEvents: timelineDiagnostics.events
        )
    }
}

enum WeekFitStoreKitPaywallDiagnosticsFormatter {
    static func text(
        distribution: AppDistribution,
        appVersion: String?,
        appBuild: String?,
        storefrontCountryCode: String?,
        storefrontID: String?,
        rawReturnedCount: Int,
        products: [WeekFitProductSnapshot],
        productsFailedToLoad: Bool,
        accessState: WeekFitAccessState? = nil,
        forcePaywallActive: Bool = false,
        timelineEvents: [WeekFitStoreKitTimelineDiagnostics.Event] = []
    ) -> String {
        var lines: [String] = []
        lines.append("Build")
        lines.append("Distribution: \(distribution.analyticsValue)")
        lines.append("Version: \(appVersion ?? "—") (\(appBuild ?? "—"))")
        if let accessState {
            lines.append("Real access state: \(accessStateLabel(accessState))")
            lines.append("Force Paywall: \(forcePaywallActive ? "ON" : "OFF")")
        }
        lines.append("")
        lines.append("Storefront")
        lines.append("Country: \(storefrontCountryCode ?? "—")")
        lines.append("ID: \(storefrontID ?? "—")")
        lines.append("")
        lines.append("Products")
        lines.append("Product.products count: \(rawReturnedCount)")
        lines.append("Paywall snapshots: \(products.count)")
        lines.append("Failed to load: \(productsFailedToLoad ? "yes" : "no")")
        lines.append("Price source: \(products.isEmpty ? "none (no StoreKit snapshots)" : "StoreKit Product snapshots")")

        let ordered = orderedDiagnosticsProducts(products)
        if ordered.isEmpty {
            lines.append("")
            lines.append("No subscription products in paywall state.")
        } else {
            for product in ordered {
                lines.append("")
                lines.append(sectionTitle(for: product.id))
                lines.append("ID: \(product.id)")
                lines.append("Display price: \(product.displayPrice)")
                lines.append("Currency: \(product.currencyCode ?? "—")")
                lines.append("Numeric price: \(product.diagnosticsNumericPrice)")
                lines.append("Period: \(product.diagnosticsPeriodDescription)")
                if let monthly = product.monthlyEquivalentDisplay {
                    lines.append("Monthly equivalent: \(monthly)")
                }
                if let offer = product.introductoryOffer {
                    lines.append("Intro paymentMode: \(diagnosticsPaymentMode(offer.paymentMode))")
                    if let days = WeekFitPaywallCopy.introductoryDayCount(from: offer) {
                        lines.append("Intro period days: \(days)")
                    }
                    lines.append("Intro eligibility: \(diagnosticsEligibility(product.introductoryOfferEligibility))")
                    if let verified = WeekFitPaywallCopy.verifiedFreeTrialDayCount(for: product) {
                        lines.append("Verified free trial days: \(verified)")
                    } else {
                        lines.append("Verified free trial days: none")
                    }
                } else {
                    lines.append("Intro offer: none")
                    lines.append("Intro eligibility: \(diagnosticsEligibility(product.introductoryOfferEligibility))")
                }
            }
        }

        lines.append("")
        lines.append(WeekFitStoreKitTimelineDiagnostics.timelineText(events: timelineEvents))

        return lines.joined(separator: "\n")
    }

    static func accessStateLabel(_ state: WeekFitAccessState) -> String {
        switch state {
        case .loading: return "loading"
        case .legacy: return "legacy"
        case .trial: return "trial"
        case .subscribed: return "subscribed"
        case .expired: return "expired"
        case .unsubscribed: return "unsubscribed"
        }
    }

    private static func orderedDiagnosticsProducts(
        _ products: [WeekFitProductSnapshot]
    ) -> [WeekFitProductSnapshot] {
        let annual = products.first { $0.id == WeekFitSubscriptionProductID.annual.rawValue }
        let monthly = products.first { $0.id == WeekFitSubscriptionProductID.monthly.rawValue }
        var result: [WeekFitProductSnapshot] = []
        if let annual { result.append(annual) }
        if let monthly { result.append(monthly) }
        let known = Set(result.map(\.id))
        result.append(contentsOf: products.filter { !known.contains($0.id) })
        return result
    }

    private static func sectionTitle(for productID: String) -> String {
        switch WeekFitSubscriptionProductID(rawValue: productID) {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        case .none: return productID
        }
    }

    private static func diagnosticsEligibility(_ eligibility: WeekFitIntroEligibility) -> String {
        switch eligibility {
        case .unknown: return "not evaluated"
        case .eligible: return "eligible"
        case .ineligible: return "ineligible"
        }
    }

    private static func diagnosticsPaymentMode(_ mode: WeekFitIntroductoryPaymentMode) -> String {
        switch mode {
        case .free: return "free"
        case .payAsYouGo: return "payAsYouGo"
        case .payUpFront: return "payUpFront"
        }
    }
}
