import StoreKit
import SwiftUI

struct WeekFitAIUsageView: View {
    @StateObject private var store = WeekFitAIUsageStore()
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.weekFitPalette) private var palette
    @State private var showPaywall = false
    @State private var showManage = false
    @State private var paywallID = UUID().uuidString
    @State private var pack: WeekFitAIBalancePack?

    var body: some View {
        WeekFitAIBalanceScreen(
            content: store.usage.map { WeekFitAIBalanceContent.make($0) },
            isLoading: store.usage == nil && (store.isRefreshing || store.message == nil),
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
        .blur(radius: coversBackground ? 16 : 0)
        .animation(.easeInOut(duration: 0.25), value: coversBackground)
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
        .sheet(isPresented: $showPaywall, onDismiss: { Task { await store.refresh() } }) {
            WeekFitPaywallView(source: .settings, currentTab: "settings", paywallInstanceID: paywallID, allowsDismiss: true)
                .environmentObject(subscriptionManager)
                .environment(\.weekFitPalette, palette)
        }
        .sheet(item: $pack, onDismiss: { Task { await store.refresh() } }) { selected in
            WeekFitAIBalancePurchaseSheet(store: store, pack: selected)
                .environment(\.weekFitPalette, palette)
        }
        .onChange(of: store.didCreditPurchase) { _, credited in
            guard credited else { return }
            pack = nil
            store.acknowledgePurchaseCredit()
        }
    }

    private var coversBackground: Bool { pack != nil || showPaywall }
}

struct WeekFitAIBalanceScreen: View {
    var content: WeekFitAIBalanceContent?
    var isLoading: Bool
    var message: String?
    var showsSubscribe: Bool
    var showsManage: Bool
    var isBusy: Bool
    var locale: Locale? = nil
    var scrolls: Bool = true
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
        .background(WeekFitTheme.backgroundColor)
        .navigationTitle(text("ai.usage.title"))
        .navigationBarTitleDisplayMode(.inline)
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
                actionRow(text("ai.usage.refresh"), systemImage: "arrow.clockwise", action: onRetry)
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

    private func actionRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(iconTile)
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(WeekFitTheme.iconPrimary)
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WeekFitTheme.tertiaryText)
                    .accessibilityHidden(true)
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
}

struct WeekFitAIBalancePurchaseSheet: View {
    @ObservedObject var store: WeekFitAIUsageStore
    var pack: WeekFitAIBalancePack
    var locale: Locale? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String?

    var body: some View {
        WeekFitAIBalancePurchaseLayout(
            title: text(pack.titleKey),
            intro: text(pack.introKey),
            options: options,
            selectedID: selectedID,
            terms: [text(pack.noteKey), text("ai.usage.subscriptionRequired")],
            buyTitle: buyTitle,
            isBusy: store.isBusy,
            status: statusText,
            emptyMessage: options.isEmpty ? text("ai.usage.unavailable") : nil,
            onSelect: { id in
                guard !store.isBusy else { return }
                selectedID = id
            },
            onBuy: {
                guard let product = selectedProduct else { return }
                Task { await store.buy(product) }
            },
            onClose: { dismiss() }
        )
        .presentationDetents([.height(preferredDetent), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(WeekFitTheme.backgroundColor)
        .onAppear(perform: selectSmallestIfNeeded)
        .onChange(of: optionIDs) { _, _ in selectSmallestIfNeeded() }
    }

    private var optionIDs: [String] { options.map(\.id) }

    private var options: [WeekFitAIBalancePackOption] {
        sortedProducts.map { product in
            WeekFitAIBalancePackOption(
                id: product.id,
                title: WeekFitAIBalanceContent.packTitle(product.id, locale: locale) ?? product.displayName,
                price: product.displayPrice
            )
        }
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
        guard let product = selectedProduct else { return text(pack.titleKey) }
        let quantity = WeekFitAIBalanceContent.packTitle(product.id, locale: locale) ?? product.displayName
        return String(format: text("ai.balance.buy"), locale: locale ?? WeekFitCurrentLocale(), quantity, product.displayPrice)
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

    private var preferredDetent: CGFloat {
        let count = CGFloat(max(options.count, 1))
        return min(680, 320 + count * 80)
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
    var intro: String
    var options: [WeekFitAIBalancePackOption]
    var selectedID: String?
    var terms: [String]
    var buyTitle: String
    var isBusy: Bool
    var status: String?
    var emptyMessage: String?
    var scrolls: Bool = true
    var onSelect: (String) -> Void
    var onBuy: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if scrolls {
                    ScrollView { choices }
                } else {
                    choices
                }
            }
            footer
        }
        .background(WeekFitTheme.backgroundColor)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            WeekFitCloseButton(size: .regular, playsHaptic: false, action: onClose)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(intro)
                .font(.subheadline)
                .foregroundStyle(WeekFitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let emptyMessage {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(options) { option in
                        packCard(option)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private func packCard(_ option: WeekFitAIBalancePackOption) -> some View {
        let selected = option.id == selectedID
        return Button {
            onSelect(option.id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                WeekFitAIBalanceRadio(isSelected: selected)
                Text(option.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(option.price)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .multilineTextAlignment(.trailing)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(WeekFitTheme.cardSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                selected ? WeekFitTheme.primaryText : WeekFitTheme.borderSoft,
                                lineWidth: selected ? 2 : 1
                            )
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel("\(option.title), \(option.price)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(terms, id: \.self) { term in
                    Text(term)
                }
            }
            .font(.footnote)
            .foregroundStyle(WeekFitTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            if let status {
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

private struct WeekFitAIBalanceRadio: View {
    var isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(WeekFitTheme.primaryText.opacity(isSelected ? 1 : 0.38), lineWidth: 1.5)
            if isSelected {
                Circle()
                    .fill(WeekFitTheme.primaryText)
                    .padding(5)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
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
            .frame(minHeight: 52)
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
