import Foundation
import StoreKit
internal import Combine

/// Temporary DEBUG-only timeline for StoreKit storefront / product / purchase ordering.
///
/// Diagnostics only — does not alter StoreKit calls, purchase handling, or entitlements.
/// Remove after the Poland/USD storefront investigation.
@MainActor
final class WeekFitStoreKitTimelineDiagnostics: ObservableObject {
    static let shared = WeekFitStoreKitTimelineDiagnostics()

    enum Kind: String, Sendable {
        case productLoadBefore = "LOAD BEFORE"
        case productLoadAfter = "LOAD AFTER"
        case productsReturned = "PRODUCT"
        case purchaseBefore = "PURCHASE BEFORE"
        case purchaseAfter = "PURCHASE AFTER"
        case storefrontUpdate = "STOREFRONT UPDATE"
    }

    struct Event: Identifiable, Sendable {
        let id: UUID
        let sequence: Int
        let recordedAt: Date
        let kind: Kind
        let detail: String
    }

    @Published private(set) var events: [Event] = []

    private var nextSequence = 1
    private let maxEvents = 64

    private init() {}

    func resetForTests() {
        events = []
        nextSequence = 1
    }

    func recordProductLoadBefore() async {
        guard isEnabled else { return }
        let snapshot = await Self.readCurrentStorefront()
        append(
            kind: .productLoadBefore,
            detail: Self.storefrontLine(snapshot)
        )
    }

    func recordProductLoadAfter(returnedCount: Int) async {
        guard isEnabled else { return }
        let snapshot = await Self.readCurrentStorefront()
        append(
            kind: .productLoadAfter,
            detail: "\(Self.storefrontLine(snapshot)) (count=\(returnedCount))"
        )
    }

    func recordProductsReturned(_ products: [Product]) {
        guard isEnabled else { return }
        for product in products {
            append(
                kind: .productsReturned,
                detail: Self.productLine(product)
            )
        }
    }

    func recordPurchaseBefore(product: Product) async {
        guard isEnabled else { return }
        let snapshot = await Self.readCurrentStorefront()
        append(
            kind: .purchaseBefore,
            detail: "\(Self.storefrontLine(snapshot)) / \(Self.cachedProductLine(product))"
        )
    }

    func recordPurchaseAfter(result: String) async {
        guard isEnabled else { return }
        let snapshot = await Self.readCurrentStorefront()
        append(
            kind: .purchaseAfter,
            detail: "\(Self.storefrontLine(snapshot)) / \(result)"
        )
    }

    func recordStorefrontUpdate(_ storefront: Storefront) {
        guard isEnabled else { return }
        append(
            kind: .storefrontUpdate,
            detail: Self.storefrontLine(Self.storefrontSnapshot(from: storefront))
        )
    }

    static func timelineText(events: [Event]) -> String {
        guard !events.isEmpty else {
            return "Timeline\n(no events yet)"
        }
        var lines = ["Timeline"]
        for event in events {
            lines.append("#\(event.sequence) \(event.kind.rawValue)  \(event.detail)")
        }
        return lines.joined(separator: "\n")
    }

    private var isEnabled: Bool {
        AppDistribution.current.showsTemporaryStoreKitPaywallDiagnostics
    }

    private func append(kind: Kind, detail: String) {
        let event = Event(
            id: UUID(),
            sequence: nextSequence,
            recordedAt: Date(),
            kind: kind,
            detail: detail
        )
        nextSequence += 1
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    private static func readCurrentStorefront() async -> WeekFitStorefrontSnapshot {
        guard let storefront = await Storefront.current else {
            return .unknown
        }
        return storefrontSnapshot(from: storefront)
    }

    private static func storefrontSnapshot(from storefront: Storefront) -> WeekFitStorefrontSnapshot {
        WeekFitStorefrontSnapshot(
            countryCode: storefront.countryCode,
            id: storefront.id
        )
    }

    private static func storefrontLine(_ snapshot: WeekFitStorefrontSnapshot) -> String {
        "\(snapshot.countryCode ?? "—") / \(snapshot.id ?? "—")"
    }

    private static func cachedProductLine(_ product: Product) -> String {
        let currency = product.priceFormatStyle.currencyCode ?? "—"
        let period = subscriptionPeriodDescription(product)
        return "\(product.id) / \(product.displayPrice) / \(currency) / \(NSDecimalNumber(decimal: product.price).stringValue) / \(period)"
    }

    private static func productLine(_ product: Product) -> String {
        let label = productLabel(product.id)
        let currency = product.priceFormatStyle.currencyCode ?? "—"
        let period = subscriptionPeriodDescription(product)
        return "\(label) \(product.id) / \(product.displayPrice) / \(currency) / \(NSDecimalNumber(decimal: product.price).stringValue) / \(period)"
    }

    private static func productLabel(_ productID: String) -> String {
        switch WeekFitSubscriptionProductID(rawValue: productID) {
        case .annual: return "annual"
        case .monthly: return "monthly"
        case .none: return productID
        }
    }

    private static func subscriptionPeriodDescription(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "—" }
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = "period"
        }
        return "\(period.value) \(unit)"
    }
}
