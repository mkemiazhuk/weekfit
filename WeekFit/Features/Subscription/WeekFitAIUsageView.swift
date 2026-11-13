import StoreKit
import SwiftUI
import UIKit

/// Modal entry to AI balance. With a pack it opens that top-up directly.
/// One close button returns to where the user came from; a credited purchase closes it too.
struct WeekFitAIBalanceSheet: View {
    var pack: WeekFitAIBalancePack? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        NavigationStack {
            if let pack {
                WeekFitAIBalanceTopUpView(pack: pack, onClose: { dismiss() })
            } else {
                WeekFitAIUsageView(onClose: { dismiss() })
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(palette.appScreenBackground.ignoresSafeArea())
    }
}

extension View {
    func weekFitAIBalanceCloseButton(_ onClose: (() -> Void)?) -> some View {
        toolbar {
            if let onClose {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .tint(WeekFitTheme.primaryText)
                    .accessibilityLabel(AppText.Common.Action.close)
                }
            }
        }
    }
}

struct WeekFitAIBalanceTopUpView: View {
    var pack: WeekFitAIBalancePack
    var onClose: () -> Void
    @StateObject private var store = WeekFitAIUsageStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        WeekFitAIBalancePurchaseSheet(store: store, pack: pack, onClose: onClose)
            .task { await store.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.refresh() } }
            }
            .onChange(of: store.didCreditPurchase) { _, credited in
                guard credited else { return }
                store.acknowledgePurchaseCredit()
                onClose()
            }
            .sensoryFeedback(.success, trigger: store.didCreditPurchase) { _, credited in credited }
    }
}

struct WeekFitAIUsageView: View {
    var onClose: (() -> Void)? = nil
    @StateObject private var store = WeekFitAIUsageStore()
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isSettingsNavigationPush) private var isSettingsNavigationPush
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.weekFitPalette) private var palette
    @State private var showPaywall = false
    @State private var showManage = false
    @State private var paywallID = UUID().uuidString
    @State private var pack: WeekFitAIBalancePack?

    var body: some View {
        VStack(spacing: 0) {
            usageHeader
            WeekFitAIBalanceScreen(
                content: store.usage.map { WeekFitAIBalanceContent.make($0) },
                isLoading: store.usage == nil && store.message == nil,
                isRefreshing: store.isRefreshing,
                message: store.message,
                showsSubscribe: store.usage?.active == false || store.requiresSubscription,
                showsManage: store.usage != nil,
                isBusy: store.isBusy,
                onAdd: { selected in
                    store.preparePurchase()
                    pack = selected
                },
                onRetry: { Task { await store.refresh() } },
                onSubscribe: { showPaywall = true },
                onManage: { showManage = true }
            )
        }
        .background(palette.appScreenBackground.ignoresSafeArea())
        .background {
            if isSettingsNavigationPush {
                WeekFitNavigationPopEnabler()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .blur(radius: coversBackground ? 16 : 0)
        .animation(.easeInOut(duration: 0.25), value: coversBackground)
        .animation(nil, value: store.usage == nil)
        .task { await store.refresh() }
        .refreshable { await store.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weekfitVoiceStopFinished)) { _ in
            Task { await store.refresh() }
        }
        .task(id: store.usage?.voiceFinalizing) {
            guard store.usage?.voiceFinalizing == true else { return }
            for _ in 0..<15 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, store.usage?.voiceFinalizing == true else { return }
                await store.refresh()
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManage)
        .fullScreenCover(isPresented: $showPaywall, onDismiss: { Task { await store.refresh() } }) {
            WeekFitPaywallView(source: .settings, currentTab: "settings", paywallInstanceID: paywallID, allowsDismiss: true)
                .environmentObject(subscriptionManager)
                .environment(\.weekFitPalette, palette)
        }
        .navigationDestination(item: $pack) { selected in
            WeekFitAIBalancePurchaseSheet(store: store, pack: selected, isPushed: true, onClose: onClose)
                .environment(\.weekFitPalette, palette)
        }
        .sensoryFeedback(.success, trigger: store.didCreditPurchase) { _, credited in credited }
        .onChange(of: pack) { _, current in
            if current == nil { Task { await store.refresh() } }
        }
        .onChange(of: store.didCreditPurchase) { _, credited in
            guard credited else { return }
            store.acknowledgePurchaseCredit()
            if let onClose { onClose() } else { pack = nil }
        }
    }

    private var coversBackground: Bool { showPaywall }

    private var usageHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            if isSettingsNavigationPush {
                ProfilePremiumDismissButton(style: .back, action: { dismiss() })
            }
            Text(WeekFitLocalizedString("ai.usage.title"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(WeekFitTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            if let onClose, !isSettingsNavigationPush {
                WeekFitCloseButton(size: .regular, playsHaptic: false, action: onClose)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }
}

struct WeekFitAIBalanceScreen: View {
    var content: WeekFitAIBalanceContent?
    var isLoading: Bool
    var isRefreshing: Bool = false
    var message: String?
    var showsSubscribe: Bool
    var showsManage: Bool
    var isBusy: Bool
    var locale: Locale? = nil
    var scrolls: Bool = true
    @Environment(\.weekFitPalette) private var palette
    var onAdd: (WeekFitAIBalancePack) -> Void
    var onRetry: () -> Void
    var onSubscribe: () -> Void
    var onManage: () -> Void

    var body: some View {
        Group {
            if scrolls {
                ScrollView { stack }
            } else {
                stack
            }
        }
        .background(palette.appScreenBackground.ignoresSafeArea())
    }

    private var stack: some View {
        VStack(alignment: .leading, spacing: 14) {
                if let content {
                    WeekFitAIBalanceCardView(card: content.voice, isBusy: isBusy, onAdd: onAdd)
                    WeekFitAIBalanceCardView(card: content.photos, isBusy: isBusy, onAdd: onAdd)
                    footnotes(content)
                } else if isLoading {
                    WeekFitAIBalancePlaceholder()
                    WeekFitAIBalancePlaceholder()
                }
                if let banner {
                    Text(banner)
                        .font(.subheadline)
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                if showsActions {
                    actions
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
    }

    private var banner: String? {
        guard let message, !message.isEmpty else { return nil }
        if message == content?.accessNote { return nil }
        return message
    }

    private var showsActions: Bool {
        message != nil || showsSubscribe || showsManage
    }

    @ViewBuilder
    private func footnotes(_ content: WeekFitAIBalanceContent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let accessNote = content.accessNote {
                Text(accessNote)
            }
            if let renews = content.renews {
                Text(renews)
            }
            Text(content.usedFirst)
        }
        .font(.footnote)
        .foregroundStyle(WeekFitTheme.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var actions: some View {
        SettingsGroupedSection {
            if message != nil {
                actionRow(
                    text("ai.usage.refresh"),
                    systemImage: "arrow.clockwise",
                    showsProgress: isRefreshing,
                    action: onRetry
                )
                .disabled(isRefreshing)
            }
            if message != nil && (showsSubscribe || showsManage) {
                SettingsGroupDivider()
            }
            if showsSubscribe {
                actionRow(text("ai.usage.subscribe"), systemImage: "sparkles", action: onSubscribe)
            }
            if showsSubscribe && showsManage {
                SettingsGroupDivider()
            }
            if showsManage {
                actionRow(text("ai.usage.manage"), systemImage: "creditcard.fill", action: onManage)
            }
        }
    }

    private func actionRow(
        _ title: String,
        systemImage: String,
        showsProgress: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(iconTile)
                    if showsProgress {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: systemImage)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(WeekFitTheme.iconPrimary)
                    }
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !showsProgress {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WeekFitTheme.tertiaryText)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .settingsRowTouchTarget(minHeight: 52)
        }
        .buttonStyle(WeekFitAIBalancePressStyle())
        .disabled(isBusy && systemImage != "arrow.clockwise")
    }

    private var iconTile: Color {
        WeekFitTheme.internalTile
    }

    private func text(_ key: String) -> String {
        WeekFitLocalizedString(key, locale: locale)
    }
}

struct WeekFitAIBalanceCardView: View {
    var card: WeekFitAIBalanceContent.Card
    var isBusy: Bool
    var onAdd: (WeekFitAIBalancePack) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(WeekFitTheme.internalTile)
                        Image(systemName: card.symbolName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(WeekFitTheme.iconPrimary)
                    }
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
                    Text(card.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                heroLine
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(card.heroAccessibility)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            if card.showsBreakdown {
                SettingsGroupDivider(leadingInset: 16)
                VStack(alignment: .leading, spacing: 8) {
                    if let fractionCaption = card.fractionCaption {
                        Text(fractionCaption)
                            .font(.caption)
                            .foregroundStyle(WeekFitTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let includedValue = card.includedValue {
                        valueRow(
                            title: card.includedTitle,
                            value: includedValue,
                            accessibility: card.includedAccessibility
                        )
                    }
                    if let purchasedValue = card.purchasedValue {
                        valueRow(
                            title: card.purchasedTitle,
                            value: purchasedValue,
                            accessibility: card.purchasedAccessibility
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Text(card.note)
                .font(.footnote)
                .foregroundStyle(WeekFitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let action = card.action {
                WeekFitAIBalanceSecondaryButton(
                    title: WeekFitLocalizedString(action.buttonKey),
                    isEnabled: !isBusy
                ) {
                    onAdd(action)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
        }
        .weekFitPremiumCard(emphasis: .standard, cornerRadius: 20)
    }

    @ViewBuilder
    private var heroLine: some View {
        if card.heroIsStatus || card.caption == nil {
            Text(card.hero)
                .font(.title3.weight(.semibold))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ViewThatFits(in: .horizontal) {
                baselineHero(stacks: false)
                baselineHero(stacks: true)
            }
        }
    }

    private func baselineHero(stacks: Bool) -> some View {
        let amount = Text(card.hero)
            .font(.title.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(WeekFitTheme.primaryText)
        let caption = Text(card.caption ?? "")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(WeekFitTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        return Group {
            if stacks {
                VStack(alignment: .leading, spacing: 0) {
                    amount
                    caption
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    amount
                    caption
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func valueRow(title: String, value: String, accessibility: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(WeekFitTheme.primaryText)
                .multilineTextAlignment(.trailing)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }
}

private struct WeekFitAIBalancePlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 13) {
                Circle().frame(width: 34, height: 34)
                RoundedRectangle(cornerRadius: 6, style: .continuous).frame(width: 148, height: 16)
            }
            RoundedRectangle(cornerRadius: 6, style: .continuous).frame(width: 92, height: 28)
            RoundedRectangle(cornerRadius: 6, style: .continuous).frame(width: 120, height: 14)
            SettingsGroupDivider(leadingInset: 16)
            RoundedRectangle(cornerRadius: 6, style: .continuous).frame(maxWidth: .infinity).frame(height: 14)
            RoundedRectangle(cornerRadius: 6, style: .continuous).frame(maxWidth: .infinity).frame(height: 14)
            RoundedRectangle(cornerRadius: 6, style: .continuous).frame(width: 190, height: 12)
            SettingsGroupDivider(leadingInset: 16)
            RoundedRectangle(cornerRadius: 6, style: .continuous).frame(width: 96, height: 16)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.35))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .weekFitPremiumCard(emphasis: .standard, cornerRadius: 20)
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct WeekFitAIBalancePackOption: Identifiable, Equatable {
    var id: String
    var title: String
    var price: String
    var badge: String? = nil
    var amount: String? = nil
    var unit: String? = nil
    var unitPrice: String? = nil
    var estimate: String? = nil

    /// "15 minutes" → ("15", "minutes"); "15分" → ("15", "分"). Falls back to the whole title.
    static func split(title: String, quantity: Int?) -> (amount: String, unit: String?) {
        guard let quantity, let range = title.range(of: String(quantity)) else { return (title, nil) }
        var rest = title
        rest.removeSubrange(range)
        let unit = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        return (String(quantity), unit.isEmpty ? nil : unit)
    }
}

struct WeekFitAIBalanceOrderSummary: Equatable {
    var title: String
    var item: String
    var price: String
    var totalTitle: String
    var note: String
}

struct WeekFitAIBalancePurchaseSheet: View {
    @ObservedObject var store: WeekFitAIUsageStore
    var pack: WeekFitAIBalancePack
    var locale: Locale? = nil
    /// Pushed from the balance screen. The root top-up closes the sheet instead.
    var isPushed: Bool = false
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String?

    var body: some View {
        WeekFitAIBalancePurchaseLayout(
            title: text(pack.titleKey),
            symbol: nil,
            intro: text(pack.introKey),
            options: options,
            selectedID: selectedID,
            summary: nil,
            terms: pack == .time
                ? [text("ai.balance.purchasedMinutesNeverExpire"), text("ai.balance.premiumRequiredToUse")]
                : [text("ai.balance.purchasedPhotosNeverExpire"), text("ai.balance.premiumRequiredToUse")],
            buyTitle: buyTitle,
            isBusy: store.isBusy,
            canPurchase: canPurchase,
            status: statusText,
            emptyMessage: options.isEmpty && !store.isRefreshing ? text("ai.usage.unavailable") : nil,
            showsClose: false,
            usesMinuteRows: true,
            isLoadingProducts: options.isEmpty && store.isRefreshing,
            storeCaption: text("ai.balance.appStorePurchase"),
            onLeading: {
                if isPushed {
                    dismiss()
                } else if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            },
            leadingIsClose: !isPushed,
            onSelect: { id in
                guard !store.isBusy else { return }
                selectedID = id
            },
            onBuy: {
                guard let product = selectedProduct else { return }
                Task { await store.buy(product) }
            },
            onClose: { onClose?() }
        )
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .background {
            if isPushed {
                WeekFitNavigationPopEnabler()
            }
        }
        .onAppear(perform: selectSmallestWithoutAnimation)
        .onChange(of: optionIDs) { _, _ in selectSmallestWithoutAnimation() }
    }

    private var optionIDs: [String] { options.map(\.id) }

    private var options: [WeekFitAIBalancePackOption] {
        let products = sortedProducts
        let base = products.first.flatMap { product in
            WeekFitAIBalancePack.quantity(product.id).map { (price: product.price, quantity: $0) }
        }
        return products.map { product in
            let quantity = WeekFitAIBalancePack.quantity(product.id)
            let savings = base.flatMap { base in
                quantity.flatMap { count in
                    WeekFitAIBalancePack.unitSavingsPercent(
                        price: product.price,
                        quantity: count,
                        basePrice: base.price,
                        baseQuantity: base.quantity
                    )
                }
            }
            let title = WeekFitAIBalanceContent.packTitle(product.id, locale: locale) ?? product.displayName
            let parts = WeekFitAIBalancePackOption.split(title: title, quantity: quantity)
            let badgeKey = pack == .time ? "ai.balance.savePerMinute" : "ai.balance.savePerPhoto"
            return WeekFitAIBalancePackOption(
                id: product.id,
                title: title,
                price: product.displayPrice,
                badge: savings.map { String(format: text(badgeKey), locale: resolvedLocale, $0) },
                amount: parts.amount,
                unit: parts.unit,
                unitPrice: quantity.map { unitPrice(product, quantity: $0) },
                estimate: nil
            )
        }
    }

    private var resolvedLocale: Locale { locale ?? WeekFitCurrentLocale() }

    private func unitPrice(_ product: Product, quantity: Int) -> String {
        let each = (product.price / Decimal(quantity)).formatted(product.priceFormatStyle.presentation(.narrow))
        let key = pack == .time ? "ai.balance.perMinute" : "ai.balance.perPhoto"
        return String(format: text(key), locale: resolvedLocale, each)
    }

    private var sortedProducts: [Product] {
        store.products
            .filter { pack.matches($0.id) }
            .sorted { lhs, rhs in
                let rank = WeekFitAIBalancePack.quantityRank(lhs.id)
                let other = WeekFitAIBalancePack.quantityRank(rhs.id)
                if rank != other { return rank < other }
                return lhs.price < rhs.price
            }
    }

    private var selectedProduct: Product? {
        sortedProducts.first { $0.id == selectedID }
    }

    private var buyTitle: String {
        guard let product = selectedProduct, !product.displayPrice.isEmpty else {
            return text("ai.balance.buyPending")
        }
        let quantity = WeekFitAIBalanceContent.packTitle(product.id, locale: locale) ?? product.displayName
        return String(format: text("ai.balance.buy"), locale: locale ?? WeekFitCurrentLocale(), quantity, product.displayPrice)
    }

    private var canPurchase: Bool {
        guard let product = selectedProduct else { return false }
        return !product.displayPrice.isEmpty && !store.isBusy
    }

    private var statusText: String? {
        switch store.purchasePhase {
        case .pending:
            return text("ai.usage.pending") + " " + text("ai.balance.pendingDetail")
        case .failed(let message):
            return message
        case .crediting:
            return text("ai.balance.crediting")
        case .idle, .purchasing:
            return nil
        }
    }

    private func selectSmallestWithoutAnimation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectSmallestIfNeeded()
        }
    }

    private func selectSmallestIfNeeded() {
        guard !store.isBusy else { return }
        let ids = options.map(\.id)
        if let selectedID, ids.contains(selectedID) { return }
        selectedID = ids.first
    }

    private func text(_ key: String) -> String {
        WeekFitLocalizedString(key, locale: locale)
    }
}

struct WeekFitAIBalancePurchaseLayout: View {
    var title: String
    var symbol: String? = nil
    var intro: String
    var options: [WeekFitAIBalancePackOption]
    var selectedID: String?
    var summary: WeekFitAIBalanceOrderSummary? = nil
    var terms: [String]
    var buyTitle: String
    var isBusy: Bool
    var canPurchase: Bool = true
    var status: String?
    var emptyMessage: String?
    var scrolls: Bool = true
    var showsClose: Bool = true
    var usesMinuteRows: Bool = false
    var isLoadingProducts: Bool = false
    var storeCaption: String? = nil
    var onLeading: (() -> Void)? = nil
    var leadingIsClose: Bool = false
    var onSelect: (String) -> Void
    var onBuy: () -> Void
    var onClose: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        Group {
            if usesMinuteRows {
                minuteScreen
            } else {
                legacyScreen
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: selectedID)
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    /// Fixed header and a docked buy bar. Prices fill in without moving the screen.
    private var minuteScreen: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                choices
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(palette.appScreenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            minuteFooter
        }
    }

    private var legacyScreen: some View {
        VStack(spacing: 0) {
            header
            Group {
                if scrolls {
                    ScrollView {
                        choices
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    choices
                }
            }
            footer
        }
        .background(palette.appScreenBackground.ignoresSafeArea())
    }

    private var accent: Color { WeekFitTheme.primaryCTA }

    /// Muted sage from the activity metric. Dark stays this tone; light uses the same hue.
    private var sage: Color { WeekFitSemanticMetricTokens.activity }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let onLeading {
                if leadingIsClose {
                    WeekFitCloseButton(size: .regular, playsHaptic: false, action: onLeading)
                } else {
                    WeekFitDetailScreenBackButton(action: onLeading)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(accent.opacity(palette.isLight ? 0.14 : 0.2)))
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(.system(usesMinuteRows ? .title2 : .title3, design: .rounded).weight(.bold))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .lineLimit(usesMinuteRows ? 2 : 1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                }
                Text(intro)
                    .font(.subheadline)
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showsClose, onLeading == nil {
                WeekFitCloseButton(size: .regular, playsHaptic: false, action: onClose)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, usesMinuteRows ? 18 : 14)
        .padding(.bottom, usesMinuteRows ? 10 : 4)
    }

    // MARK: Choices

    private var choices: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let emptyMessage {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            } else if usesMinuteRows {
                if isLoadingProducts {
                    VStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(WeekFitTheme.cardSurface)
                                .frame(height: 100)
                                .redacted(reason: .placeholder)
                        }
                    }
                    .padding(.top, 8)
                    .accessibilityHidden(true)
                } else {
                    VStack(spacing: 12) {
                        ForEach(options) { option in
                            minuteRow(option)
                        }
                    }
                    .padding(.top, 8)
                    minuteTerms
                        .padding(.top, 18)
                }
            } else {
                packRow
                    .padding(.top, 16)
                if let summary {
                    orderSummary(summary)
                        .padding(.top, 18)
                }
                termsList
                    .padding(.top, 14)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var packRow: some View {
        if usesThreeAcross {
            HStack(alignment: .top, spacing: 8) {
                ForEach(options) { option in
                    packCard(option)
                }
            }
            .frame(minHeight: 196, maxHeight: 228, alignment: .top)
        } else {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(options) { option in
                    packCard(option)
                }
            }
        }
    }

    /// Three packs (15 / 30 / 60, or the photo packs) stay on one row.
    private var usesThreeAcross: Bool {
        !dynamicTypeSize.isAccessibilitySize && options.count == 3
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : (usesThreeAcross ? 3 : min(max(options.count, 1), 2))
        return Array(repeating: GridItem(.flexible(), spacing: usesThreeAcross ? 8 : 12), count: count)
    }

    private func packCard(_ option: WeekFitAIBalancePackOption) -> some View {
        let selected = option.id == selectedID
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Button {
            onSelect(option.id)
        } label: {
            VStack(spacing: 0) {
                Text(option.amount ?? option.title)
                    .font(.system(size: usesThreeAcross ? 28 : 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit = option.unit {
                    Text(unit)
                        .font(usesThreeAcross ? .caption.weight(.medium) : .subheadline.weight(.medium))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if let estimate = option.estimate {
                    Text(estimate)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected ? accent : WeekFitTheme.primaryText.opacity(0.72))
                        .lineLimit(usesThreeAcross ? 3 : nil)
                        .minimumScaleFactor(usesThreeAcross ? 0.8 : 1)
                        .fixedSize(horizontal: false, vertical: !usesThreeAcross)
                        .padding(.top, usesThreeAcross ? 6 : 8)
                }
                if usesThreeAcross {
                    Spacer(minLength: 8)
                }
                Rectangle()
                    .fill(WeekFitTheme.borderSoft)
                    .frame(width: usesThreeAcross ? 20 : 28, height: 1)
                    .padding(.vertical, usesThreeAcross ? 8 : 12)
                    .accessibilityHidden(true)
                Text(option.price)
                    .font(usesThreeAcross ? .system(.subheadline, design: .rounded).weight(.semibold) : .system(.headline, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unitPrice = option.unitPrice {
                    Text(unitPrice)
                        .font(usesThreeAcross ? .caption2 : .caption)
                        .monospacedDigit()
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 2)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, usesThreeAcross ? 6 : 12)
            .padding(.top, usesThreeAcross ? 16 : 22)
            .padding(.bottom, usesThreeAcross ? 12 : 18)
            .frame(maxWidth: .infinity, maxHeight: usesThreeAcross ? .infinity : nil, alignment: .top)
            .background {
                if !palette.isLight && !reduceTransparency {
                    WeekFitDarkGlassPlate(
                        cornerRadius: 22,
                        tint: selected ? accent : nil,
                        shadowOpacity: 0.28,
                        shadowRadius: 12,
                        shadowY: 6
                    )
                } else {
                    shape
                        .fill(selected ? accent.opacity(palette.isLight ? 0.09 : 0.16) : WeekFitTheme.cardSurface)
                        .overlay {
                            shape.strokeBorder(
                                selected ? accent : WeekFitTheme.borderSoft,
                                lineWidth: selected ? 2 : 1
                            )
                        }
                        .shadow(color: .black.opacity(palette.isLight && selected ? 0.08 : 0), radius: 14, y: 6)
                }
            }
            .overlay {
                if !palette.isLight && !reduceTransparency && selected {
                    shape.strokeBorder(accent, lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: usesThreeAcross ? 16 : 20, weight: .semibold))
                    .foregroundStyle(selected ? accent : WeekFitTheme.borderSoft)
                    .padding(usesThreeAcross ? 6 : 10)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .top) {
                if let badge = option.badge {
                    Text(badge)
                        .font((usesThreeAcross ? Font.caption2 : Font.caption).weight(.bold))
                        .foregroundStyle(WeekFitTheme.primaryCTAForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, usesThreeAcross ? 8 : 12)
                        .padding(.vertical, usesThreeAcross ? 4 : 5)
                        .background { Capsule().fill(accent) }
                        .padding(.horizontal, usesThreeAcross ? 4 : 0)
                        .frame(maxWidth: usesThreeAcross ? .infinity : nil)
                        .offset(y: -12)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(WeekFitAIBalanceCardPressStyle(reduceMotion: reduceMotion))
        .disabled(isBusy)
        .accessibilityLabel([option.title, option.estimate, option.price, option.unitPrice, option.badge].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func orderSummary(_ summary: WeekFitAIBalanceOrderSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(WeekFitTheme.secondaryText)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 12) {
                summaryRow(summary.item, summary.price, emphasized: false)
                Rectangle()
                    .fill(WeekFitTheme.borderSoft)
                    .frame(height: 0.5)
                    .accessibilityHidden(true)
                summaryRow(summary.totalTitle, summary.price, emphasized: true)
            }
            .padding(16)
            .background {
                if !palette.isLight && !reduceTransparency {
                    WeekFitDarkGlassPlate(
                        cornerRadius: 18,
                        shadowOpacity: 0.28,
                        shadowRadius: 10,
                        shadowY: 5
                    )
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(WeekFitTheme.cardSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(WeekFitTheme.borderSoft, lineWidth: 1)
                        }
                }
            }
            Text(summary.note)
                .font(.caption)
                .foregroundStyle(WeekFitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    private func summaryRow(_ title: String, _ value: String, emphasized: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .monospacedDigit()
                .layoutPriority(1)
                .contentTransition(.numericText())
        }
        .font(emphasized ? .system(.title3, design: .rounded).weight(.bold) : .subheadline)
        .foregroundStyle(emphasized ? WeekFitTheme.primaryText : WeekFitTheme.secondaryText)
        .accessibilityElement(children: .combine)
    }

    private var termsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(terms, id: \.self) { term in
                Label {
                    Text(term)
                } icon: {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(WeekFitTheme.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func minuteRow(_ option: WeekFitAIBalancePackOption) -> some View {
        let selected = option.id == selectedID
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return Button {
            onSelect(option.id)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                minuteRadio(selected: selected)
                VStack(alignment: .leading, spacing: 6) {
                    Text(option.title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let badge = option.badge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(sage)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background {
                                Capsule().fill(sage.opacity(palette.isLight ? 0.14 : 0.20))
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(option.price)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let unitPrice = option.unitPrice {
                        Text(unitPrice)
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(WeekFitTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 128 : 100, alignment: .center)
            .background {
                shape.fill(selected ? sage.opacity(palette.isLight ? 0.16 : 0.18) : WeekFitTheme.cardSurface)
            }
            .overlay {
                shape.strokeBorder(
                    selected ? sage.opacity(0.95) : minuteIdleBorder,
                    lineWidth: selected ? 1.5 : 1
                )
            }
            .contentShape(shape)
        }
        .buttonStyle(WeekFitAIBalanceCardPressStyle(reduceMotion: reduceMotion))
        .disabled(isBusy)
        .accessibilityLabel([option.title, option.price, option.unitPrice, option.badge].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func minuteRadio(selected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(selected ? sage : Color.clear)
            Circle()
                .strokeBorder(selected ? sage : minuteRadioIdle, lineWidth: 1.5)
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(minuteCheck)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }

    private var minuteIdleBorder: Color {
        palette.isLight ? WeekFitLightTokens.cardBorder : Color.white.opacity(0.16)
    }

    private var minuteRadioIdle: Color {
        palette.isLight ? WeekFitTheme.secondaryText : Color.white.opacity(0.62)
    }

    private var minuteCheck: Color {
        Color(red: 0.067, green: 0.086, blue: 0.133)
    }

    private var minuteButtonFill: Color {
        palette.isLight ? WeekFitTheme.primaryCTA : sage
    }

    private var minuteButtonInk: Color {
        palette.isLight ? WeekFitTheme.primaryCTAForeground : minuteCheck
    }

    private var minuteTerms: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(terms.enumerated()), id: \.offset) { index, term in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: index == 0 ? "infinity" : "crown")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(sage)
                        .frame(width: 18, alignment: .center)
                        .accessibilityHidden(true)
                    Text(term)
                        .font(.subheadline)
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var minuteFooter: some View {
        VStack(spacing: 8) {
            if let status {
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let storeCaption {
                Text(storeCaption)
                    .font(.footnote)
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            Button(action: onBuy) {
                HStack(spacing: 8) {
                    if isBusy {
                        ProgressView()
                            .tint(minuteButtonInk)
                    }
                    Text(buyTitle)
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(minuteButtonInk)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 56)
                .background { Capsule().fill(minuteButtonFill) }
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canPurchase || isBusy)
            .opacity(canPurchase || isBusy ? 1 : 0.45)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(palette.appScreenBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WeekFitTheme.borderSoft)
                .frame(height: 0.5)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let status {
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
            WeekFitAIBalancePrimaryButton(
                title: buyTitle,
                isLoading: isBusy,
                isEnabled: selectedID != nil && emptyMessage == nil
            ) {
                onBuy()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }
}

private struct WeekFitNavigationPopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigation = navigationController, navigation.viewControllers.count > 1 else { return }
            navigation.interactivePopGestureRecognizer?.isEnabled = true
            navigation.interactivePopGestureRecognizer?.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

private struct WeekFitAIBalanceCardPressStyle: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
    }
}

private struct WeekFitAIBalanceSecondaryButton: View {
    var title: String
    var isEnabled: Bool
    var action: () -> Void
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.isLight ? WeekFitLightTokens.softCTAForeground : WeekFitTheme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 50)
                .background {
                    Capsule()
                        .fill(palette.isLight ? WeekFitLightTokens.softCTA : WeekFitTheme.whiteOpacity(0.12))
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    palette.isLight ? WeekFitLightTokens.primaryCTA.opacity(0.55) : Color.white.opacity(0.34),
                                    lineWidth: 1.25
                                )
                        }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct WeekFitAIBalancePrimaryButton: View {
    var title: String
    var isLoading: Bool
    var isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(WeekFitTheme.primaryCTAForeground)
                }
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(WeekFitTheme.primaryCTAForeground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 56)
            .background { Capsule().fill(WeekFitTheme.primaryCTA) }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

private struct WeekFitAIBalancePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.55 : 1)
    }
}

/// Photo balance at the bottom of the AI photo card in Log food.
struct WeekFitAIPhotosLeftRow: View {
    /// nil while loading.
    var count: Int?
    var preserved: Bool = false
    var accent: Color
    var locale: Locale? = nil
    var action: () -> Void

    @Environment(\.weekFitPalette) private var palette

    private static let lowThreshold = 6

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .redacted(reason: count == nil && !preserved ? .placeholder : [])
                    if let detail {
                        Text(detail)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.78))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if preserved {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.55))
                } else {
                    addCapsule
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(WeekFitAIBalancePressStyle())
        .animation(.snappy(duration: 0.25), value: count)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([String(headline.characters), detail].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint(preserved ? "" : text("ai.balance.addPhotos"))
        .accessibilityIdentifier("quickFood.ai.photosLeft")
    }

    private var isLow: Bool { (count ?? Self.lowThreshold + 1) <= Self.lowThreshold }

    private var headline: AttributedString {
        if preserved { return AttributedString(text("ai.usage.existingAccess")) }
        guard let count else {
            return AttributedString(WeekFitLocalizedQuantityFormat("ai.usage.photosLeft", count: 20, locale: resolvedLocale))
        }
        if count == 0 { return AttributedString(text("ai.usage.noPhotosLeft")) }
        var line = AttributedString(WeekFitLocalizedQuantityFormat("ai.usage.photosLeft", count: count, locale: resolvedLocale))
        if let range = line.range(of: String(count)) {
            line[range].font = .system(size: 17, weight: .bold, design: .rounded)
            if isLow { line[range].foregroundColor = accent }
        }
        return line
    }

    private var detail: String? {
        guard !preserved, let count, let days = WeekFitAIBalancePack.photos.estimate(quantity: count) else { return nil }
        return WeekFitLocalizedQuantityFormat(WeekFitAIBalancePack.photos.estimateKey, count: days, locale: resolvedLocale)
    }

    private var addCapsule: some View {
        Label(text(isLow ? "ai.balance.addPhotos" : "ai.balance.addShort"), systemImage: "plus")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(isLow ? WeekFitTheme.primaryCTAForeground : accent)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(
                Capsule(style: .continuous)
                    .fill(isLow ? accent : accent.opacity(palette.isLight ? 0.12 : 0.18))
            )
            .fixedSize()
    }

    private var resolvedLocale: Locale { locale ?? WeekFitCurrentLocale() }

    private func text(_ key: String) -> String {
        WeekFitLocalizedString(key, locale: locale)
    }
}
