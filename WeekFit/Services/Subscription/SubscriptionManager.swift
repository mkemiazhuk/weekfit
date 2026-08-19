import Foundation
internal import Combine

/// Central StoreKit 2 entitlement layer. Views should read `hasFullAccess`
/// instead of checking products or identity themselves.
@MainActor
final class SubscriptionManager: ObservableObject {
    nonisolated deinit {}

    @Published private(set) var accessState: WeekFitAccessState = .loading
    @Published private(set) var products: [WeekFitProductSnapshot] = []
    @Published private(set) var selectedProductID: String = WeekFitSubscriptionProductID.annual.rawValue
    @Published private(set) var isPurchaseInFlight = false
    @Published private(set) var isRestoreInFlight = false
    @Published private(set) var lastOutcome: WeekFitPurchaseOutcome?
    @Published private(set) var productsFailedToLoad = false
    @Published private(set) var activeSubscription: WeekFitSubscriptionSnapshot?

    private let store: WeekFitStoreKitServicing
    private let bypassProvider: (() -> WeekFitEntitlementBypass)?
    private var fallbackStore: WeekFitEntitlementFallbackStore
    private var updatesTask: Task<Void, Never>?
    private var hasStarted = false
    /// Prevent indefinite fail-open when StoreKit never becomes available.
    private var failOpenTimeoutTask: Task<Void, Never>?
    private var didApplyLoadingFailOpenGate = false
    /// Bounded fail-open window before gating a never-verified install.
    private let failOpenTimeout: Duration

    var hasResolved: Bool { accessState != .loading }

    var hasFullAccess: Bool {
        WeekFitEntitlementPolicy.hasFullAccess(for: accessState)
    }

    /// Root paywall gate. Does not inspect workspaces, Apple sign-in, or guest mode.
    var shouldBlockAccess: Bool {
        hasResolved && !hasFullAccess
    }

    var selectedProduct: WeekFitProductSnapshot? {
        products.first { $0.id == selectedProductID } ?? products.first
    }

    var annualProduct: WeekFitProductSnapshot? {
        products.first { $0.id == WeekFitSubscriptionProductID.annual.rawValue }
    }

    var monthlyProduct: WeekFitProductSnapshot? {
        products.first { $0.id == WeekFitSubscriptionProductID.monthly.rawValue }
    }

    init(
        store: WeekFitStoreKitServicing? = nil,
        bypassProvider: (() -> WeekFitEntitlementBypass)? = nil,
        fallbackStore: WeekFitEntitlementFallbackStore = WeekFitEntitlementFallbackStore(),
        failOpenTimeout: Duration = .seconds(12)
    ) {
        self.store = store ?? LiveWeekFitStoreKitService()
        self.bypassProvider = bypassProvider
        self.fallbackStore = fallbackStore
        self.failOpenTimeout = failOpenTimeout
    }

    private func currentBypass() -> WeekFitEntitlementBypass {
        bypassProvider?() ?? .none
    }

    func start() async {
        guard !hasStarted else {
            await refresh()
            return
        }
        hasStarted = true
        updatesTask = store.startTransactionUpdates { [weak self] in
            await self?.refresh()
        }
        await refresh()
    }

    func refreshOnForeground() async {
        guard hasStarted else { return }
        await refresh()
    }

    func refreshAfterExternalSubscriptionChange() async {
        await refresh()
        for attempt in 0..<3 {
            try? await Task.sleep(for: .milliseconds(350 * (attempt + 1)))
            await refresh()
        }
    }

    func selectProduct(_ id: String) {
        selectedProductID = id
        SubscriptionAnalytics.optionSelected(productID: id)
    }

    func purchaseSelected() async {
        guard let productID = selectedProduct?.id else {
            lastOutcome = .productsUnavailable
            return
        }
        guard !isPurchaseInFlight else { return }

        isPurchaseInFlight = true
        lastOutcome = nil
        SubscriptionAnalytics.purchaseStarted(productID: productID)
        let outcome = await store.purchase(productID: productID)
        if outcome == .success {
            await refresh()
            // StoreKit (especially Xcode local environment) may update entitlement
            // state with a short delay; keep retrying until it becomes authoritative.
            if !hasFullAccess {
                await retryRefreshUntilFullAccess(maxAttempts: 4)
            }
        } else {
            await refresh()
        }

        switch outcome {
        case .success:
            lastOutcome = hasFullAccess ? .success : .failedVerification
            if hasFullAccess {
                SubscriptionAnalytics.purchaseSuccess(productID: productID)
            }
        case .cancelled:
            lastOutcome = .cancelled
            SubscriptionAnalytics.purchaseCancelled(productID: productID)
        case .pending:
            lastOutcome = .pending
        case .failedVerification, .productsUnavailable, .failed:
            lastOutcome = outcome
        }

        isPurchaseInFlight = false
    }

    func restorePurchases() async {
        guard !isRestoreInFlight else { return }
        isRestoreInFlight = true
        lastOutcome = nil
        SubscriptionAnalytics.restoreStarted()
        do {
            try await store.restorePurchases()
            await refresh()
            if !hasFullAccess {
                await retryRefreshUntilFullAccess(maxAttempts: 4)
            }
            if hasFullAccess {
                lastOutcome = .success
                SubscriptionAnalytics.restoreSuccess()
            } else {
                lastOutcome = .failed
            }
        } catch is CancellationError {
            await refresh()
            lastOutcome = .cancelled
        } catch {
            await refresh()
            lastOutcome = .failed
        }
        isRestoreInFlight = false
    }

    private func retryRefreshUntilFullAccess(maxAttempts: Int) async {
        guard maxAttempts > 0 else { return }
        // Small increasing delays; total wait ~3-4 seconds.
        for attempt in 0..<maxAttempts {
            if hasFullAccess { return }
            let delayMs = 450 * (attempt + 1)
            try? await Task.sleep(for: .milliseconds(delayMs))
            await refresh()
        }
    }

    func refresh() async {
        let bypass = currentBypass()
        #if DEBUG
        // Only UI tests should honor forced entitlement paths.
        // Manual/local StoreKit runs (Xcode environment) must not be accidentally gated.
        let uiTesting = WeekFitUITestSupport.isActive
        let forceLegacy = uiTesting && ProcessInfo.processInfo.arguments.contains(WeekFitUITestSupport.forceLegacyUserLaunchArgument)
        let forceNew = uiTesting && ProcessInfo.processInfo.arguments.contains(WeekFitUITestSupport.forceNewUserLaunchArgument)
        #else
        let forceLegacy = false
        let forceNew = false
        #endif

        // DEBUG/UI-test deterministic overrides (impossible in Release).
        #if DEBUG
        let overrideState = WeekFitUITestSupport.entitlementOverrideState()
        let didApplyEntitlementOverride = overrideState != nil
        #else
        let overrideState: WeekFitAccessState? = nil
        let didApplyEntitlementOverride = false
        #endif

        do {
            let loaded = try await store.loadProducts()
            products = Self.sortedProducts(loaded)
            productsFailedToLoad = products.isEmpty
            if products.contains(where: { $0.id == selectedProductID }) == false {
                selectedProductID = annualProduct?.id ?? monthlyProduct?.id ?? selectedProductID
            }
            #if DEBUG
            if productsFailedToLoad {
                print("[WeekFit.StoreKit] paywall will hide prices — Product.products returned no usable subscriptions")
            }
            #endif
        } catch {
            #if DEBUG
            print("[WeekFit.StoreKit] paywall will hide prices — loadProducts threw \(error)")
            #endif
            productsFailedToLoad = products.isEmpty
        }

        let transactionStatus = await store.loadAppTransaction()
        let currentSubscription = await store.loadCurrentSubscription()
        activeSubscription = currentSubscription.flatMap {
            WeekFitEntitlementPolicy.isActiveSubscription($0) ? $0 : nil
        }

        if didApplyEntitlementOverride, let overrideState {
            cancelFailOpenTimeout()
            didApplyLoadingFailOpenGate = false
            accessState = overrideState
            #if DEBUG
            print(
                """
                [WeekFit.Entitlements] { env="ui-test", originalPurchaseDate=null, legacyResult=null, subscriptionProductID=null, subscriptionState="override", appTransaction="override", resolvedAccessState="\(overrideState)", hasFullAccess=\(WeekFitEntitlementPolicy.hasFullAccess(for: overrideState)), reason="uiTestOverride" }
                """
            )
            #endif
            return
        }

        let decision = WeekFitEntitlementPolicy.resolve(
            appTransaction: transactionStatus,
            subscription: currentSubscription,
            lastVerified: fallbackStore.lastVerified,
            bypass: bypass,
            forceNewUser: forceNew,
            forceLegacyUser: forceLegacy
        )
        if decision.shouldPersistVerifiedEntitlement,
           let record = WeekFitVerifiedEntitlement(accessState: decision.state) {
            fallbackStore.lastVerified = record
            didApplyLoadingFailOpenGate = false
        }

        if decision.state == .loading, didApplyLoadingFailOpenGate, fallbackStore.lastVerified == nil {
            accessState = .unsubscribed
        } else {
            accessState = decision.state
        }

        cancelFailOpenTimeoutIfNotLoading()
        scheduleFailOpenTimeoutIfNeeded()

        #if DEBUG
        let trace = makeEntitlementTrace(
            bypass: bypass,
            forceNewUser: forceNew,
            forceLegacyUser: forceLegacy,
            transactionStatus: transactionStatus,
            subscription: currentSubscription,
            legacyResult: legacyResult(from: transactionStatus),
            resolvedAccessState: accessState,
            hasFullAccess: hasFullAccess
        )
        print(trace)
        #endif
    }

    private static func sortedProducts(_ products: [WeekFitProductSnapshot]) -> [WeekFitProductSnapshot] {
        products.sorted { lhs, rhs in
            if lhs.id == WeekFitSubscriptionProductID.annual.rawValue { return true }
            if rhs.id == WeekFitSubscriptionProductID.annual.rawValue { return false }
            return lhs.id < rhs.id
        }
    }

    private func cancelFailOpenTimeout() {
        failOpenTimeoutTask?.cancel()
        failOpenTimeoutTask = nil
    }

    private func cancelFailOpenTimeoutIfNotLoading() {
        if accessState != .loading {
            cancelFailOpenTimeout()
            didApplyLoadingFailOpenGate = false
        }
    }

    private func scheduleFailOpenTimeoutIfNeeded() {
        guard accessState == .loading else { return }
        guard fallbackStore.lastVerified == nil else { return }
        guard !didApplyLoadingFailOpenGate else { return }

        // Don’t fight deterministic UI-test expectations.
        #if DEBUG
        if WeekFitUITestSupport.isActive, overrideStateIsLoadingOverrideApplied() {
            return
        }
        #endif

        cancelFailOpenTimeout()
        failOpenTimeoutTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.failOpenTimeout)
            await self.applyLoadingFailOpenGateIfStillNeeded()
        }
    }

    #if DEBUG
    private func overrideStateIsLoadingOverrideApplied() -> Bool {
        WeekFitUITestSupport.entitlementOverrideState() == .loading
    }
    #endif

    private func applyLoadingFailOpenGateIfStillNeeded() async {
        guard accessState == .loading else { return }
        guard fallbackStore.lastVerified == nil else { return }
        guard !didApplyLoadingFailOpenGate else { return }

        didApplyLoadingFailOpenGate = true
        accessState = .unsubscribed
    }

    #if DEBUG
    private func legacyResult(from status: WeekFitAppTransactionStatus) -> String? {
        switch status {
        case .verified(let date, let environment):
            #if DEBUG
            if environment == "Xcode" {
                return "ignoredXcodeEnvironment"
            }
            #endif
            return WeekFitEntitlementPolicy.isLegacy(originalPurchaseDate: date) ? "legacy" : "nonLegacy"
        case .unverified(_):
            return nil
        case .unavailable, .loading:
            return nil
        }
    }

    private func makeEntitlementTrace(
        bypass: WeekFitEntitlementBypass,
        forceNewUser: Bool,
        forceLegacyUser: Bool,
        transactionStatus: WeekFitAppTransactionStatus,
        subscription: WeekFitSubscriptionSnapshot?,
        legacyResult: String?,
        resolvedAccessState: WeekFitAccessState,
        hasFullAccess: Bool
    ) -> String {
        let env: String
        let appTransactionVerification: String
        let originalPurchaseDate: String?

        switch transactionStatus {
        case .verified(let date, let environment):
            env = environment
            appTransactionVerification = "verified"
            originalPurchaseDate = ISO8601DateFormatter().string(from: date)
        case .unverified(let environment):
            env = environment
            appTransactionVerification = "unverified"
            originalPurchaseDate = nil
        case .unavailable:
            env = "unavailable"
            appTransactionVerification = "unavailable"
            originalPurchaseDate = nil
        case .loading:
            env = "loading"
            appTransactionVerification = "loading"
            originalPurchaseDate = nil
        }

        let subscriptionProductID = subscription?.productID ?? "none"
        let subscriptionState: String
        if let subscription {
            if subscription.isExpired { subscriptionState = "expired" }
            else if subscription.isRevoked { subscriptionState = "revoked" }
            else if subscription.inGraceOrRetry { subscriptionState = "graceOrRetry" }
            else if !subscription.willAutoRenew { subscriptionState = "cancelledButActive" }
            else if subscription.isIntroductoryTrial { subscriptionState = "trial" }
            else { subscriptionState = "active" }
        } else {
            subscriptionState = "none"
        }

        let reason: String = {
            if bypass.grantsAccess || forceLegacyUser {
                return "bypassOrForceLegacy"
            }
            if forceNewUser {
                return "forceNewUser"
            }
            if let sub = subscription, WeekFitEntitlementPolicy.isActiveSubscription(sub) {
                return "activeSubscription"
            }
            switch transactionStatus {
            case .loading:
                return "appTransactionLoading"
            case .verified:
                if legacyResult == "legacy" { return "legacyOriginalPurchaseDate" }
                return "verifiedAppTransaction"
            case .unverified(_), .unavailable:
                if fallbackStore.lastVerified == nil { return "failOpenNoLastVerified" }
                if subscription != nil { return "unverifiedButSubscriptionSnapshotGates" }
                return "unverifiedButUsingLastVerified"
            }
        }()

        return
            """
            [WeekFit.Entitlements] { env="\(env)", originalPurchaseDate=\(originalPurchaseDate.map { "\"\($0)\"" } ?? "null"), legacyResult=\(legacyResult.map { "\"\($0)\"" } ?? "null"), subscriptionProductID="\(subscriptionProductID)", subscriptionState="\(subscriptionState)", appTransactionVerification="\(appTransactionVerification)", resolvedAccessState="\(resolvedAccessState)", hasFullAccess=\(hasFullAccess), reason="\(reason)" }
            """
    }
    #endif
}
