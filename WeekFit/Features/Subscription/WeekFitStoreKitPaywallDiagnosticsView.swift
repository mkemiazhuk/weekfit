import SwiftUI

/// Temporary TestFlight (and DEBUG) StoreKit price diagnostics for the paywall.
///
/// Uses the same `WeekFitProductSnapshot` instances as plan cards — no separate
/// product fetch. Remove after the Poland/USD storefront investigation.
struct WeekFitStoreKitPaywallDiagnosticsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var timelineDiagnostics = WeekFitStoreKitTimelineDiagnostics.shared
    @Environment(\.weekFitPalette) private var palette
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(diagnosticsText)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
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
        timelineEvents: [WeekFitStoreKitTimelineDiagnostics.Event] = []
    ) -> String {
        var lines: [String] = []
        lines.append("Build")
        lines.append("Distribution: \(distribution.analyticsValue)")
        lines.append("Version: \(appVersion ?? "—") (\(appBuild ?? "—"))")
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
            }
        }

        lines.append("")
        lines.append(WeekFitStoreKitTimelineDiagnostics.timelineText(events: timelineEvents))

        return lines.joined(separator: "\n")
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
}
