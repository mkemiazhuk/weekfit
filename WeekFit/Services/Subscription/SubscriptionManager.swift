import Foundation
internal import Combine

/// Central StoreKit 2 entitlement layer. Views should read `hasFullAccess`
/// instead of checking products or identity themselves.
@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var accessState: WeekFitAccessState = .loading
    @Published private(set) var products: [WeekFitProductSnapshot] = []
    @Published private(set) var selectedProductID: String = WeekFitSubscriptionProductID.annual.rawValue
    @Published private(set) var isPurchaseInFlight = false
    @Published private(set) var isRestoreInFlight = false
    @Published private(set) var lastOutcome: WeekFitPurchaseOutcome?
    /// Which action last set `lastOutcome` — keeps purchase vs restore footer copy separate.
    @Published private(set) var lastOutcomeSource: WeekFitPaywallOutcomeSource?
    @Published private(set) var productsFailedToLoad = false
    @Published private(set) var activeSubscription: WeekFitSubscriptionSnapshot?
    /// Temporary StoreKit diagnostics — same load as paywall prices.
    @Published private(set) var storefrontCountryCode: String?
    @Published private(set) var storefrontID: String?
    @Published private(set) var lastStoreProductsReturnedCount: Int = 0
    /// Bumps when the one-time AI photo free trial is consumed so SwiftUI re-reads the gate.
    @Published private(set) var photoAIFreeTrialRevision: Int = 0
    /// True when StoreKit has a **standard paid** JWS (no intro/promo/offer code/win-back).
    @Published private(set) var hasVerifiedPaidSubscriptionProof = false

    private let store: WeekFitStoreKitServicing
    private let bypassProvider: (() -> WeekFitEntitlementBypass)?
    private var fallbackStore: WeekFitEntitlementFallbackStore
    private var updatesTask: Task<Void, Never>?
    private var storefrontUpdatesTask: Task<Void, Never>?
    /// Long-lived observer; manager outlives the process UI session.
    private nonisolated(unsafe) var freeTrialObserver: NSObjectProtocol?
    private var hasStarted = false
    /// Prevent indefinite fail-open when StoreKit never becomes available.
    private var failOpenTimeoutTask: Task<Void, Never>?
    private var didApplyLoadingFailOpenGate = false
    /// Bounded fail-open window before gating a never-verified install.
    private let failOpenTimeout: Duration
    /// Cap for `AppStore.sync()` — it can hang indefinitely on Apple ID / Sandbox auth.
    private let restoreTimeout: Duration
    /// Cap for `Product.purchase()` — stale Products after sleep can hang until process kill.
    private let purchaseTimeout: Duration
    /// Bumped on every Continue tap so a hung Sandbox `purchase()` can be abandoned by retry.
    private var purchaseGeneration: UInt64 = 0
    /// One entitlement refresh at a time. Overlapping start/foreground calls share it.
    private var refreshTask: Task<Void, Never>?
    /// A purchase, restore, transaction, or storefront change that arrived mid-refresh.
    private var pendingRefreshSource: String?
    /// When the last start/foreground refresh finished. Immediate foreground repeats are skipped.
    private var lastAutomaticRefreshAt: Date?
    private let redundantForegroundWindow: TimeInterval = 3

    var hasResolved: Bool { accessState != .loading }

    var hasFullAccess: Bool {
        WeekFitEntitlementPolicy.hasFullAccess(for: accessState)
    }

    /// Cloud AI photo nutrition: **standard paid** StoreKit proof, or one complimentary free try.
    /// Promo / intro / offer code / win-back do **not** unlock AI (server enforces the same).
    var canUseCloudPhotoNutritionAnalysis: Bool {
        _ = photoAIFreeTrialRevision
        return hasVerifiedPaidSubscriptionProof || hasPhotoAIFreeTrialRemaining
    }

    /// True when the user still has the one-time free AI photo scan (and is not already paid).
    var hasPhotoAIFreeTrialRemaining: Bool {
        _ = photoAIFreeTrialRevision
        return !hasVerifiedPaidSubscriptionProof && PhotoFoodFreeTrialStore.hasRemaining
    }

    /// Mark the complimentary AI photo scan used (client UX). Server also claims once per UID.
    func consumePhotoAIFreeTrialIfNeeded() {
        guard !hasVerifiedPaidSubscriptionProof else { return }
        PhotoFoodFreeTrialStore.markConsumed()
    }

    /// True when Premium features (Coach / Meals / Plan) are gated.
    /// Does **not** block Today or app launch — see `WeekFitRootView` tab gating.
    var shouldBlockAccess: Bool {
        hasResolved && !hasFullAccess
    }

    /// Whether the given root tab may be opened without presenting the paywall.
    /// Premium tabs stay closed until entitlement is resolved (no flash of premium UI).
    func canAccess(_ tab: WeekFitTab) -> Bool {
        WeekFitPremiumTabGate.decision(
            for: tab,
            hasResolved: hasResolved,
            hasFullAccess: hasFullAccess
        ) == .allow
    }

    /// Last premium tab that presented the feature paywall — for purchase attribution.
    /// Cleared on dismiss without entitlement or after a successful unlock.
    @Published private(set) var paywallRequestedTabID: String?

    func noteFeaturePaywall(for tab: WeekFitTab) {
        paywallRequestedTabID = tab.paywallRequestedTabID
    }

    func clearFeaturePaywallRequest() {
        paywallRequestedTabID = nil
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
        failOpenTimeout: Duration = .seconds(12),
        restoreTimeout: Duration = .seconds(45),
        // Sandbox often shows a system error then never returns from purchase();
        // fail visibly so Connecting… cannot stick for minutes.
        purchaseTimeout: Duration = .seconds(20)
    ) {
        self.store = store ?? LiveWeekFitStoreKitService()
        self.bypassProvider = bypassProvider
        self.fallbackStore = fallbackStore
        self.failOpenTimeout = failOpenTimeout
        self.restoreTimeout = restoreTimeout
        self.purchaseTimeout = purchaseTimeout
        freeTrialObserver = NotificationCenter.default.addObserver(
            forName: .weekFitPhotoAIFreeTrialConsumed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.photoAIFreeTrialRevision += 1
            }
        }
    }

    nonisolated deinit {
        if let freeTrialObserver {
            NotificationCenter.default.removeObserver(freeTrialObserver)
        }
    }

    private func currentBypass() -> WeekFitEntitlementBypass {
        bypassProvider?() ?? .none
    }

    func start() async {
        guard !hasStarted else {
            await refresh(source: "start.reentry")
            return
        }
        hasStarted = true
        updatesTask = store.startTransactionUpdates { [weak self] notice in
            await self?.handleVerifiedTransactionUpdate(notice)
        }
        storefrontUpdatesTask = store.startStorefrontUpdates { [weak self] in
            await self?.handleStorefrontChange()
        }
        await refresh(source: "start")
    }

    /// Storefront changed: drop prior catalog immediately, then reload.
    /// Never leave previous-storefront prices on screen while / after a failed reload.
    private func handleStorefrontChange() async {
        markProductsUnavailableForReload(failed: false)
        await refresh(source: "storefront.updates")
    }

    private func markProductsUnavailableForReload(failed: Bool) {
        store.invalidateCachedProducts()
        products = []
        lastStoreProductsReturnedCount = 0
        productsFailedToLoad = failed
        // Keep selectedProductID so a successful reload can restore the same plan.
    }

    /// - Parameter invalidateProducts: drop cached StoreKit `Product`s. Use after a
    ///   meaningful background interval (sleep) so `Product.purchase()` does not hang.
    ///   Purchase already force-reloads; do not invalidate on every brief foreground.
    func refreshOnForeground(invalidateProducts: Bool = false) async {
        guard hasStarted else { return }
        if invalidateProducts {
            store.invalidateCachedProducts()
            await refresh(source: "foreground.invalidateProducts")
            return
        }
        await refresh(source: "foreground")
    }

    func refreshAfterExternalSubscriptionChange() async {
        await refresh(source: "externalSubscriptionChange.0")
        for attempt in 0..<3 {
            try? await Task.sleep(for: .milliseconds(350 * (attempt + 1)))
            await refresh(source: "externalSubscriptionChange.\(attempt + 1)")
        }
    }

    func selectProduct(_ id: String) {
        selectedProductID = id
        SubscriptionAnalytics.optionSelected(
            productID: id,
            requestedTab: paywallRequestedTabID
        )
    }

    func purchaseSelected() async {
        // New Continue always wins: Sandbox may show a system error while
        // `Product.purchase()` never returns — a second tap must not be a silent no-op.
        let attempt = beginPurchaseAttempt()
        defer { endPurchaseAttemptIfCurrent(attempt) }

        // Empty catalog: reload once so Continue isn’t a silent no-op.
        if selectedProduct == nil {
            await refresh(source: "paywall.cta.reloadProducts")
            guard isCurrentPurchaseAttempt(attempt) else { return }
            guard selectedProduct != nil else {
                lastOutcome = .productsUnavailable
                SubscriptionAnalytics.purchaseFailed(
                    productID: selectedProductID,
                    requestedTab: paywallRequestedTabID,
                    failureReason: .productsUnavailable
                )
                return
            }
        }

        guard let productID = selectedProduct?.id else {
            lastOutcome = .productsUnavailable
            SubscriptionAnalytics.purchaseFailed(
                productID: selectedProductID,
                requestedTab: paywallRequestedTabID,
                failureReason: .productsUnavailable
            )
            return
        }

        let requestedTab = paywallRequestedTabID
        SubscriptionAnalytics.purchaseStarted(
            productID: productID,
            requestedTab: requestedTab
        )
        let outcome: WeekFitPurchaseOutcome
        do {
            outcome = try await performPurchaseWithTimeout(productID: productID)
        } catch is WeekFitStoreKitPurchaseTimeoutError {
            guard isCurrentPurchaseAttempt(attempt) else { return }
            // Drop stale Product cache so the next Continue fetches a fresh instance.
            store.invalidateCachedProducts()
            await refresh(source: "purchase.timeout")
            lastOutcome = .timedOut
            // The sheet may still complete. Waiting is not a failed purchase.
            UnresolvedPurchaseAttemptAnalytics.mark(
                productID: productID,
                requestedTab: requestedTab
            )
            SubscriptionAnalytics.purchasePending(
                productID: productID,
                requestedTab: requestedTab,
                reason: .interfaceTimeout
            )
            return
        } catch {
            guard isCurrentPurchaseAttempt(attempt) else { return }
            await refresh(source: "purchase.failed")
            lastOutcome = .failed
            SubscriptionAnalytics.purchaseFailed(
                productID: productID,
                requestedTab: requestedTab,
                failureReason: .storekitError
            )
            return
        }
        guard isCurrentPurchaseAttempt(attempt) else { return }
        switch outcome {
        case .success:
            // StoreKit verified the transaction. Deliver entitlements before finish().
            await refresh(source: "purchase.success")
            if !hasFullAccess {
                await retryRefreshUntilFullAccess(maxAttempts: 4, source: "purchase.successRetry")
            }
            guard isCurrentPurchaseAttempt(attempt) else { return }
            await store.finishVerifiedPurchaseIfNeeded()
            // Confirm after finish — auto-renewables remain in currentEntitlements.
            if !hasFullAccess {
                await refresh(source: "purchase.afterFinish")
                if !hasFullAccess {
                    await retryRefreshUntilFullAccess(maxAttempts: 2, source: "purchase.afterFinishRetry")
                }
            }
            guard isCurrentPurchaseAttempt(attempt) else { return }
            if hasFullAccess {
                lastOutcome = .success
                WeekFitDeferredPurchaseStore.clear()
                UnresolvedPurchaseAttemptAnalytics.clear()
                SubscriptionAnalytics.purchaseSuccess(
                    productID: productID,
                    requestedTab: requestedTab,
                    storeEnvironment: StoreKitTransactionAnalytics.latestPurchaseEnvironmentToken()
                )
            } else {
                lastOutcome = .entitlementNotPropagated
                SubscriptionAnalytics.purchaseFailed(
                    productID: productID,
                    requestedTab: requestedTab,
                    failureReason: .entitlementNotPropagated
                )
            }
        case .cancelled:
            await refresh(source: "purchase.cancelled")
            lastOutcome = .cancelled
            WeekFitDeferredPurchaseStore.clear()
            SubscriptionAnalytics.purchaseCancelled(
                productID: productID,
                requestedTab: requestedTab
            )
        case .pending:
            await refresh(source: "purchase.pending")
            lastOutcome = .pending
            // Terminal for *this* attempt sheet; success may follow via Transaction.updates
            // (persisted so app relaunch before approval still completes the funnel once).
            WeekFitDeferredPurchaseStore.markPending(
                productID: productID,
                requestedTab: requestedTab
            )
            SubscriptionAnalytics.purchasePending(
                productID: productID,
                requestedTab: requestedTab,
                reason: .askToBuy
            )
        case .failedVerification:
            await refresh(source: "purchase.failedVerification")
            lastOutcome = .failedVerification
            SubscriptionAnalytics.purchaseFailed(
                productID: productID,
                requestedTab: requestedTab,
                failureReason: .verificationFailed
            )
        case .productsUnavailable:
            await refresh(source: "purchase.productsUnavailable")
            lastOutcome = .productsUnavailable
            SubscriptionAnalytics.purchaseFailed(
                productID: productID,
                requestedTab: requestedTab,
                failureReason: .productsUnavailable
            )
        case .timedOut:
            // Defensive: the wait is normally thrown above. Still not a failed purchase.
            await refresh(source: "purchase.timeout")
            lastOutcome = .timedOut
            UnresolvedPurchaseAttemptAnalytics.mark(
                productID: productID,
                requestedTab: requestedTab
            )
            SubscriptionAnalytics.purchasePending(
                productID: productID,
                requestedTab: requestedTab,
                reason: .interfaceTimeout
            )
        case .failed, .nothingToRestore, .entitlementNotPropagated:
            // These are not store.purchase() results.
            await refresh(source: "purchase.failed")
            lastOutcome = .failed
            SubscriptionAnalytics.purchaseFailed(
                productID: productID,
                requestedTab: requestedTab,
                failureReason: .storekitError
            )
        }
    }

    private func beginPurchaseAttempt() -> UInt64 {
        purchaseGeneration &+= 1
        isPurchaseInFlight = true
        lastOutcome = nil
        lastOutcomeSource = .purchase
        return purchaseGeneration
    }

    private func isCurrentPurchaseAttempt(_ attempt: UInt64) -> Bool {
        attempt == purchaseGeneration
    }

    private func endPurchaseAttemptIfCurrent(_ attempt: UInt64) {
        guard isCurrentPurchaseAttempt(attempt) else { return }
        isPurchaseInFlight = false
    }

    /// User-initiated Restore Purchases only (paywall / Settings).
    ///
    /// Apple StoreKit 2 model (WWDC22 / `AppStore.sync` docs):
    /// 1. Entitlements are available automatically via `Transaction.currentEntitlements`
    ///    on launch / reinstall — no `sync()` needed for the common path.
    /// 2. `AppStore.sync()` is only for the rare case when the user still sees missing
    ///    purchases after a local entitlement refresh. It always shows Apple ID auth.
    /// 3. Call `sync()` only from an explicit Restore tap (never from `start()` / `refresh()`).
    func restorePurchases(
        source: SubscriptionAnalyticsSource = .other,
        paywallInstanceID: String? = nil
    ) async {
        #if DEBUG
        WeekFitRestoreDiagnostics.log("RESTORE_TAPPED source=\(source.rawValue)")
        #endif
        guard !isRestoreInFlight else { return }
        isRestoreInFlight = true
        defer { isRestoreInFlight = false }
        lastOutcome = nil
        lastOutcomeSource = .restore
        let requestedTab = paywallRequestedTabID
        let hadEntitlementBefore = hasFullAccess
        SubscriptionAnalytics.restoreStarted(
            source: source,
            requestedTab: requestedTab,
            paywallInstanceID: paywallInstanceID
        )
        #if DEBUG
        WeekFitRestoreDiagnostics.log(
            "RESTORE_STARTED hasFullAccess=\(hadEntitlementBefore)"
        )
        #endif

        // Proactive path: re-read current entitlements without prompting for Apple ID.
        await refresh(source: "restore.localEntitlements")
        if !hasFullAccess {
            await retryRefreshUntilFullAccess(maxAttempts: 2, source: "restore.localRetry")
        }
        #if DEBUG
        WeekFitRestoreDiagnostics.log(
            "RESTORE_ENTITLEMENTS_CHECKED hasFullAccess=\(hasFullAccess)"
        )
        #endif

        if hasFullAccess {
            lastOutcome = .success
            SubscriptionAnalytics.restoreFinished(
                source: source,
                requestedTab: requestedTab,
                result: hadEntitlementBefore ? .alreadyEntitled : .restored,
                hasEntitlementBefore: hadEntitlementBefore,
                hasEntitlementAfter: true,
                restoredProductID: activeSubscription?.productID,
                paywallInstanceID: paywallInstanceID
            )
            #if DEBUG
            WeekFitRestoreDiagnostics.log(
                "RESTORE_RESULT=\(hadEntitlementBefore ? "already_entitled" : "restored")"
            )
            #endif
            return
        }

        // Rare path: force App Store sync only when local entitlements are empty.
        do {
            #if DEBUG
            WeekFitRestoreDiagnostics.log("RESTORE_SYNC_STARTED")
            #endif
            try await performRestoreWithTimeout()
            #if DEBUG
            WeekFitRestoreDiagnostics.log("RESTORE_SYNC_COMPLETED")
            #endif
            await refresh(source: "restore.afterAppStoreSync")
            if !hasFullAccess {
                await retryRefreshUntilFullAccess(maxAttempts: 4, source: "restore.afterSyncRetry")
            }
            if hasFullAccess {
                lastOutcome = .success
                SubscriptionAnalytics.restoreFinished(
                    source: source,
                    requestedTab: requestedTab,
                    result: .restored,
                    hasEntitlementBefore: hadEntitlementBefore,
                    hasEntitlementAfter: true,
                    restoredProductID: activeSubscription?.productID,
                    paywallInstanceID: paywallInstanceID
                )
                #if DEBUG
                WeekFitRestoreDiagnostics.log("RESTORE_RESULT=restored")
                #endif
            } else {
                lastOutcome = .nothingToRestore
                SubscriptionAnalytics.restoreFinished(
                    source: source,
                    requestedTab: requestedTab,
                    result: .noPurchases,
                    hasEntitlementBefore: hadEntitlementBefore,
                    hasEntitlementAfter: false,
                    paywallInstanceID: paywallInstanceID
                )
                #if DEBUG
                WeekFitRestoreDiagnostics.log("RESTORE_RESULT=no_purchases")
                #endif
            }
        } catch is CancellationError {
            await refresh(source: "restore.cancelled")
            lastOutcome = .cancelled
            SubscriptionAnalytics.restoreFinished(
                source: source,
                requestedTab: requestedTab,
                result: .cancelled,
                hasEntitlementBefore: hadEntitlementBefore,
                hasEntitlementAfter: hasFullAccess,
                paywallInstanceID: paywallInstanceID,
                error: CancellationError()
            )
            #if DEBUG
            WeekFitRestoreDiagnostics.log("RESTORE_SYNC_COMPLETED cancelled=true")
            WeekFitRestoreDiagnostics.log("RESTORE_RESULT=cancelled")
            #endif
        } catch let timeout as WeekFitStoreKitRestoreTimeoutError {
            await refresh(source: "restore.timeout")
            lastOutcome = .failed
            SubscriptionAnalytics.restoreFinished(
                source: source,
                requestedTab: requestedTab,
                result: .timeout,
                hasEntitlementBefore: hadEntitlementBefore,
                hasEntitlementAfter: hasFullAccess,
                paywallInstanceID: paywallInstanceID,
                error: timeout
            )
            #if DEBUG
            WeekFitRestoreDiagnostics.log("RESTORE_SYNC_COMPLETED timedOut=true")
            WeekFitRestoreDiagnostics.log("RESTORE_RESULT=failed_timeout")
            #endif
        } catch {
            await refresh(source: "restore.storekitError")
            lastOutcome = .failed
            SubscriptionAnalytics.restoreFinished(
                source: source,
                requestedTab: requestedTab,
                result: .storekitError,
                hasEntitlementBefore: hadEntitlementBefore,
                hasEntitlementAfter: hasFullAccess,
                paywallInstanceID: paywallInstanceID,
                error: error
            )
            #if DEBUG
            WeekFitRestoreDiagnostics.log("RESTORE_SYNC_COMPLETED threw=true")
            WeekFitRestoreDiagnostics.log("RESTORE_RESULT=failed_storekit")
            #endif
        }
    }

    /// Cap `AppStore.sync()` — the system Apple ID sheet can hang indefinitely in Sandbox.
    private func performRestoreWithTimeout() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                try await self.store.restorePurchases()
            }
            group.addTask {
                try await Task.sleep(for: self.restoreTimeout)
                throw WeekFitStoreKitRestoreTimeoutError()
            }
            do {
                _ = try await group.next()
                group.cancelAll()
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    /// Cap `Product.purchase()` — after sleep the system sheet may never appear.
    private func performPurchaseWithTimeout(productID: String) async throws -> WeekFitPurchaseOutcome {
        try await withThrowingTaskGroup(of: WeekFitPurchaseOutcome.self) { group in
            group.addTask { @MainActor in
                await self.store.purchase(productID: productID)
            }
            group.addTask {
                try await Task.sleep(for: self.purchaseTimeout)
                throw WeekFitStoreKitPurchaseTimeoutError()
            }
            do {
                guard let outcome = try await group.next() else {
                    throw WeekFitStoreKitPurchaseTimeoutError()
                }
                group.cancelAll()
                return outcome
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private func retryRefreshUntilFullAccess(
        maxAttempts: Int,
        source: String = "retry"
    ) async {
        guard maxAttempts > 0 else { return }
        // Small increasing delays; total wait ~3-4 seconds.
        for attempt in 0..<maxAttempts {
            if hasFullAccess { return }
            let delayMs = 450 * (attempt + 1)
            try? await Task.sleep(for: .milliseconds(delayMs))
            await refresh(source: "\(source).\(attempt)")
        }
    }

    /// `Transaction.updates` after Ask to Buy, SCA, or a UI wait that ended first.
    /// One success per verified transaction id. Entitlement alone does not count.
    /// There is no 24-hour cutoff: Ask to Buy can be approved later.
    private func handleVerifiedTransactionUpdate(_ notice: WeekFitVerifiedTransactionNotice) async {
        await refresh(source: "transaction.updates")
        guard notice.transactionID != 0, hasFullAccess else { return }
        if emitDeferredPurchaseSuccessIfConfirmed(notice) { return }
        emitUnresolvedPurchaseSuccessIfConfirmed(notice)
    }

    private func emitDeferredPurchaseSuccessIfConfirmed(_ notice: WeekFitVerifiedTransactionNotice) -> Bool {
        guard let pending = WeekFitDeferredPurchaseStore.pendingProductID(),
              pending == notice.productID,
              WeekFitPurchaseAttemptMatch.isConfirmedPurchase(
                purchaseDate: notice.purchaseDate,
                attemptMarkedAt: WeekFitDeferredPurchaseStore.pendingMarkedAt()
              ),
              PurchaseSuccessTransactionDedup.claim(notice.transactionID),
              let consumed = WeekFitDeferredPurchaseStore.consumeIfMatching(productID: pending)
        else { return false }
        UnresolvedPurchaseAttemptAnalytics.clear()
        recordPurchaseSuccess(productID: consumed.productID, requestedTab: consumed.requestedTab)
        return true
    }

    private func emitUnresolvedPurchaseSuccessIfConfirmed(_ notice: WeekFitVerifiedTransactionNotice) {
        guard let pending = UnresolvedPurchaseAttemptAnalytics.pendingProductID(),
              pending == notice.productID,
              WeekFitPurchaseAttemptMatch.isConfirmedPurchase(
                purchaseDate: notice.purchaseDate,
                attemptMarkedAt: UnresolvedPurchaseAttemptAnalytics.markedAt()
              ),
              PurchaseSuccessTransactionDedup.claim(notice.transactionID),
              let consumed = UnresolvedPurchaseAttemptAnalytics.consumeIfMatching(productID: pending)
        else { return }
        recordPurchaseSuccess(productID: consumed.productID, requestedTab: consumed.requestedTab)
    }

    private func recordPurchaseSuccess(productID: String, requestedTab: String?) {
        lastOutcome = .success
        lastOutcomeSource = .purchase
        SubscriptionAnalytics.purchaseSuccess(
            productID: productID,
            requestedTab: requestedTab,
            storeEnvironment: StoreKitTransactionAnalytics.latestPurchaseEnvironmentToken()
        )
    }

    func refresh() async {
        await refresh(source: "refresh")
    }

    func refresh(source: String) async {
        if shouldSkipRedundantForeground(source) { return }
        if let current = refreshTask {
            if Self.isMeaningfulRefresh(source) {
                pendingRefreshSource = source
            }
            await current.value
            return
        }

        let task = Task { @MainActor in
            var active: String? = source
            while let source = active {
                await self.performRefreshBody(source: source)
                if source == "start" || source == "foreground" {
                    self.lastAutomaticRefreshAt = Date()
                }
                active = self.pendingRefreshSource
                self.pendingRefreshSource = nil
            }
        }
        refreshTask = task
        await task.value
        if refreshTask == task {
            refreshTask = nil
        }
    }

    private func shouldSkipRedundantForeground(_ source: String) -> Bool {
        guard source == "foreground" else { return false }
        guard let lastAutomaticRefreshAt else { return false }
        return Date().timeIntervalSince(lastAutomaticRefreshAt) < redundantForegroundWindow
    }

    /// Events that must not be dropped when they arrive during another refresh.
    private static func isMeaningfulRefresh(_ source: String) -> Bool {
        switch source {
        case "start", "start.reentry", "foreground", "refresh":
            return false
        default:
            return true
        }
    }

    private func performRefreshBody(source: String) async {
        let bypass = currentBypass()
        #if DEBUG
        // UI-test force new/legacy still require `-ui-testing`.
        // Force-non-legacy is intentionally available for manual Sandbox runs
        // without `-ui-testing` so paywall + purchase can be exercised.
        let uiTesting = WeekFitUITestSupport.isActive
        let forceLegacy = uiTesting && ProcessInfo.processInfo.arguments.contains(WeekFitUITestSupport.forceLegacyUserLaunchArgument)
        let forceNew = uiTesting && ProcessInfo.processInfo.arguments.contains(WeekFitUITestSupport.forceNewUserLaunchArgument)
        let forceNonLegacy = WeekFitUITestSupport.shouldForceNonLegacyAppTransaction
        #else
        let forceLegacy = false
        let forceNew = false
        let forceNonLegacy = false
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
            products = Self.sortedProducts(loaded.products)
            lastStoreProductsReturnedCount = loaded.rawReturnedCount
            storefrontCountryCode = loaded.storefront.countryCode
            storefrontID = loaded.storefront.id
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
            markProductsUnavailableForReload(failed: true)
        }

        let transactionStatus = await store.loadAppTransaction()
        let currentSubscription = await store.loadCurrentSubscription()
        activeSubscription = currentSubscription.flatMap {
            WeekFitEntitlementPolicy.isActiveSubscription($0) ? $0 : nil
        }
        // Lifecycle analytics from verified StoreKit snapshots (auto-renew / ordinary expiry).
        // Does not emit revenue; purchase-sheet cancel remains `subscription_purchase_cancelled`.
        SubscriptionLifecycleAnalytics.observe(
            subscription: currentSubscription,
            refreshSource: source
        )

        if didApplyEntitlementOverride, let overrideState {
            cancelFailOpenTimeout()
            didApplyLoadingFailOpenGate = false
            accessState = overrideState
            // UI tests: `.subscribed` override counts as paid proof so AI photo flows can run.
            hasVerifiedPaidSubscriptionProof = (overrideState == .subscribed)
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
            forceLegacyUser: forceLegacy,
            forceNonLegacyAppTransaction: forceNonLegacy
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

        // AI photo: only a StoreKit JWS with no offer (not intro/promo/code/win-back).
        hasVerifiedPaidSubscriptionProof =
            await WeekFitPaidSubscriptionProof.currentPaidSubscriptionJWS() != nil

        cancelFailOpenTimeoutIfNotLoading()
        scheduleFailOpenTimeoutIfNeeded()

        #if DEBUG
        let entitlementReason = makeEntitlementReason(
            bypass: bypass,
            forceNewUser: forceNew,
            forceLegacyUser: forceLegacy,
            forceNonLegacyAppTransaction: forceNonLegacy,
            transactionStatus: transactionStatus,
            subscription: currentSubscription,
            legacyResult: legacyResult(
                from: transactionStatus,
                forceNonLegacyAppTransaction: forceNonLegacy
            )
        )
        let trace = makeEntitlementTrace(
            bypass: bypass,
            forceNewUser: forceNew,
            forceLegacyUser: forceLegacy,
            forceNonLegacyAppTransaction: forceNonLegacy,
            transactionStatus: transactionStatus,
            subscription: currentSubscription,
            legacyResult: legacyResult(
                from: transactionStatus,
                forceNonLegacyAppTransaction: forceNonLegacy
            ),
            resolvedAccessState: accessState,
            hasFullAccess: hasFullAccess,
            reason: entitlementReason
        )
        print(trace)
        WeekFitSubscriptionAccessDiagnostics.logRefreshResult(
            source: source,
            resolvedAccessState: accessState,
            hasFullAccess: hasFullAccess,
            reason: entitlementReason,
            subscription: currentSubscription,
            paywallWouldBlockPremiumTabs: shouldBlockAccess
        )
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
    private func legacyResult(
        from status: WeekFitAppTransactionStatus,
        forceNonLegacyAppTransaction: Bool
    ) -> String? {
        switch status {
        case .verified(let date, let environment):
            if environment == "Xcode" {
                return "ignoredXcodeEnvironment"
            }
            if forceNonLegacyAppTransaction {
                return "forcedNonLegacy"
            }
            return WeekFitEntitlementPolicy.isLegacy(originalPurchaseDate: date) ? "legacy" : "nonLegacy"
        case .unverified(_):
            return nil
        case .unavailable, .loading:
            return nil
        }
    }

    private func makeEntitlementReason(
        bypass: WeekFitEntitlementBypass,
        forceNewUser: Bool,
        forceLegacyUser: Bool,
        forceNonLegacyAppTransaction: Bool,
        transactionStatus: WeekFitAppTransactionStatus,
        subscription: WeekFitSubscriptionSnapshot?,
        legacyResult: String?
    ) -> String {
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
            if forceNonLegacyAppTransaction {
                return "forceNonLegacyAppTransaction"
            }
            if legacyResult == "legacy" { return "legacyOriginalPurchaseDate" }
            if let subscription, subscription.isExpired || subscription.isRevoked {
                return "subscriptionExpiredOrRevoked"
            }
            if let subscription, subscription.billingState == .inBillingRetry {
                return "subscriptionBillingRetryNoAccess"
            }
            return "verifiedAppTransactionNoActiveSubscription"
        case .unverified(_), .unavailable:
            if fallbackStore.lastVerified == nil { return "failOpenNoLastVerified" }
            if subscription != nil { return "unverifiedButSubscriptionSnapshotGates" }
            return "unverifiedButUsingLastVerified"
        }
    }

    private func makeEntitlementTrace(
        bypass: WeekFitEntitlementBypass,
        forceNewUser: Bool,
        forceLegacyUser: Bool,
        forceNonLegacyAppTransaction: Bool,
        transactionStatus: WeekFitAppTransactionStatus,
        subscription: WeekFitSubscriptionSnapshot?,
        legacyResult: String?,
        resolvedAccessState: WeekFitAccessState,
        hasFullAccess: Bool,
        reason: String
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
        let expirationUTC: String
        if let subscription {
            if subscription.isRevoked { subscriptionState = "revoked" }
            else if subscription.billingState == .inGracePeriod { subscriptionState = "grace" }
            else if subscription.billingState == .inBillingRetry { subscriptionState = "billingRetry" }
            else if subscription.isExpired { subscriptionState = "expired" }
            else if !subscription.willAutoRenew { subscriptionState = "cancelledButActive" }
            else if subscription.isIntroductoryTrial { subscriptionState = "trial" }
            else { subscriptionState = "active" }
            if let expiration = subscription.expirationDate {
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                expirationUTC = formatter.string(from: expiration)
            } else {
                expirationUTC = "nil"
            }
        } else {
            subscriptionState = "none"
            expirationUTC = "nil"
        }

        _ = forceNewUser
        _ = forceLegacyUser
        _ = forceNonLegacyAppTransaction
        _ = bypass

        return
            """
            [WeekFit.Entitlements] { env="\(env)", originalPurchaseDate=\(originalPurchaseDate.map { "\"\($0)\"" } ?? "null"), legacyResult=\(legacyResult.map { "\"\($0)\"" } ?? "null"), subscriptionProductID="\(subscriptionProductID)", subscriptionState="\(subscriptionState)", expirationUTC="\(expirationUTC)", willAutoRenew=\(subscription.map { String($0.willAutoRenew) } ?? "null"), appTransactionVerification="\(appTransactionVerification)", resolvedAccessState="\(resolvedAccessState)", hasFullAccess=\(hasFullAccess), reason="\(reason)" }
            """
    }
    #endif
}

#if DEBUG
private enum WeekFitRestoreDiagnostics {
    static func log(_ message: String) {
        print("[WeekFit.Restore] \(message)")
    }
}
#endif
