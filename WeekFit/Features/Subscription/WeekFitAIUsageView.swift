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

    var body: some View {
        List {
            if store.isRefreshing && store.usage == nil {
                Section { ProgressView() }
            }
            if let usage = store.usage {
                Section(WeekFitLocalizedString("ai.usage.included")) {
                    LabeledContent(WeekFitLocalizedString("ai.usage.photos"), value: usage.grandfatheredPhotos
                        ? WeekFitLocalizedString("ai.usage.existingAccess") : usage.photos.included.formatted())
                    if usage.voiceFinalizing {
                        Text(WeekFitLocalizedString("ai.usage.finalizing"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        LabeledContent(WeekFitLocalizedString("ai.usage.voice"), value: clock(usage.voice.included))
                    }
                    if usage.voice.reserved > 0 {
                        LabeledContent(WeekFitLocalizedString("ai.usage.voiceReserved"), value: clock(usage.voice.reserved))
                    }
                    if usage.voice.used > 0 {
                        LabeledContent(WeekFitLocalizedString("ai.usage.voiceUsed"), value: clock(usage.voice.used))
                    }
                    if usage.active {
                        LabeledContent(WeekFitLocalizedString("ai.usage.renews")) {
                            Text(usage.resetDate, format: .dateTime.day().month().year())
                        }
                    }
                }
                Section(WeekFitLocalizedString("ai.usage.purchased")) {
                    LabeledContent(WeekFitLocalizedString("ai.usage.photos"), value: usage.photos.purchased.formatted())
                    LabeledContent(WeekFitLocalizedString("ai.usage.voice"), value: clock(usage.voice.purchased))
                    Text(WeekFitLocalizedString("ai.usage.terms"))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if usage.active {
                    Section(WeekFitLocalizedString("ai.usage.topUp")) {
                        ForEach(store.products, id: \.id) { product in
                            let voiceHeld = (usage.voiceFinalizing || usage.voice.reserved > 0) && product.id.contains("voice")
                            if !voiceHeld && !(usage.grandfatheredPhotos && product.id.contains("photos")) {
                                Button { Task { await store.buy(product) } } label: {
                                    HStack {
                                        Text(product.displayName)
                                        Spacer()
                                        Text(product.displayPrice).fontWeight(.semibold)
                                    }
                                }
                                .disabled(store.isBusy)
                            }
                        }
                        if store.products.isEmpty {
                            Text(WeekFitLocalizedString("ai.usage.unavailable")).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if store.usage?.active == false || store.requiresSubscription {
                Section {
                    Button(WeekFitLocalizedString("ai.usage.subscribe")) { showPaywall = true }
                }
            }
            if let message = store.message {
                Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
            Section {
                Button(WeekFitLocalizedString("ai.usage.refresh")) { Task { await store.refresh() } }
                    .disabled(store.isRefreshing)
                Button(WeekFitLocalizedString("ai.usage.manage")) { showManage = true }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WeekFitTheme.backgroundColor)
        .navigationTitle(WeekFitLocalizedString("ai.usage.title"))
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
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await store.refresh()
        }
        .manageSubscriptionsSheet(isPresented: $showManage)
        .sheet(isPresented: $showPaywall, onDismiss: { Task { await store.refresh() } }) {
            WeekFitPaywallView(source: .settings, currentTab: "settings", paywallInstanceID: paywallID, allowsDismiss: true)
                .environmentObject(subscriptionManager)
                .environment(\.weekFitPalette, palette)
        }
    }
    private func clock(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = WeekFitCurrentLocale()
        formatter.calendar = calendar
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(seconds)) ?? "0"
    }
}
