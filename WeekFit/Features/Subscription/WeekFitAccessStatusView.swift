import StoreKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Shown from Profile when the user already has WeekFit access.
struct WeekFitAccessStatusView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        ZStack {
            palette.appScreenBackground
                .ignoresSafeArea()
            ProfilePremiumBackground(accent: WeekFitTheme.brandGold.opacity(0.55))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                VStack(alignment: .leading, spacing: 0) {
                    OnboardingTitle(text: statusTitle)
                    OnboardingSubtitle(text: statusBody)
                        .padding(.top, 10)

                    statusCard
                        .padding(.top, 22)
                }
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                .padding(.top, 2)

                Spacer(minLength: 16)

                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .id(palette.appearanceInvalidationToken)
        .task {
            await subscriptionManager.refreshAfterExternalSubscriptionChange()
        }
    }

    private var navBar: some View {
        HStack {
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

            Spacer()
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WeekFitTheme.brandGold)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(statusBadge)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.brandGold)
                Text(statusDetail)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .weekFitPremiumCard(emphasis: .compact, cornerRadius: OnboardingLayout.cardCornerRadius)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if showsManageSubscription {
                OnboardingPrimaryButton(
                    title: WeekFitLocalizedString("paywall.access.manage"),
                    isLoading: false,
                    isEnabled: true
                ) {
                    Task { await openManageSubscriptions() }
                }
                .accessibilityIdentifier("paywall.access.manage")
            }

            Button {
                dismiss()
            } label: {
                Text(WeekFitLocalizedString("paywall.access.done"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paywall.access.done")
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.bottom, 8)
        .safeAreaPadding(.bottom, 2)
    }

    private var showsManageSubscription: Bool {
        switch subscriptionManager.accessState {
        case .trial, .subscribed:
            return true
        case .legacy, .loading, .expired, .unsubscribed:
            return false
        }
    }

    private var statusIcon: String {
        switch subscriptionManager.accessState {
        case .legacy:
            return "heart.fill"
        case .trial:
            return "clock.fill"
        case .subscribed:
            return "checkmark.seal.fill"
        case .loading, .expired, .unsubscribed:
            return "creditcard.fill"
        }
    }

    private var isCancelledButActive: Bool {
        guard let activeSubscription = subscriptionManager.activeSubscription else { return false }
        return !activeSubscription.willAutoRenew
    }

    private var statusTitle: String {
        switch subscriptionManager.accessState {
        case .legacy:
            return WeekFitLocalizedString("paywall.legacy.title")
        case .trial:
            return isCancelledButActive
                ? WeekFitLocalizedString("paywall.access.trial.cancelled.title")
                : WeekFitLocalizedString("paywall.access.trial.title")
        case .subscribed:
            return isCancelledButActive
                ? WeekFitLocalizedString("paywall.access.subscribed.cancelled.title")
                : WeekFitLocalizedString("paywall.access.subscribed.title")
        case .loading, .expired, .unsubscribed:
            return WeekFitLocalizedString("settings.weekFitAccess.title")
        }
    }

    private var statusBody: String {
        switch subscriptionManager.accessState {
        case .legacy:
            return WeekFitLocalizedString("paywall.legacy.body")
        case .trial:
            if isCancelledButActive {
                return cancelledAccessBody
            }
            return WeekFitLocalizedString("paywall.access.trial.body")
        case .subscribed:
            if isCancelledButActive {
                return cancelledAccessBody
            }
            return WeekFitLocalizedString("paywall.access.subscribed.body")
        case .loading, .expired, .unsubscribed:
            return WeekFitLocalizedString("paywall.subtitle")
        }
    }

    private var cancelledAccessBody: String {
        if let expiration = subscriptionManager.activeSubscription?.expirationDate {
            let formatted = Self.accessDateFormatter.string(from: expiration)
            return String(
                format: WeekFitLocalizedString("paywall.access.cancelled.bodyFormat"),
                formatted
            )
        }
        return WeekFitLocalizedString("paywall.access.cancelled.bodyFallback")
    }

    private var statusBadge: String {
        if isCancelledButActive {
            return WeekFitLocalizedString("paywall.access.badge.cancelled")
        }
        switch subscriptionManager.accessState {
        case .legacy:
            return WeekFitLocalizedString("paywall.access.badge.included")
        case .trial:
            return WeekFitLocalizedString("paywall.access.badge.trial")
        case .subscribed:
            return WeekFitLocalizedString("paywall.access.badge.active")
        case .loading, .expired, .unsubscribed:
            return WeekFitLocalizedString("paywall.access.badge.active")
        }
    }

    private var statusDetail: String {
        if let product = subscriptionManager.selectedProduct {
            return product.displayName
        }
        switch subscriptionManager.accessState {
        case .legacy:
            return WeekFitLocalizedString("paywall.access.detail.legacy")
        case .trial:
            return WeekFitLocalizedString("paywall.access.detail.trial")
        case .subscribed:
            return WeekFitLocalizedString("paywall.access.detail.subscribed")
        case .loading, .expired, .unsubscribed:
            return WeekFitLocalizedString("settings.weekFitAccess.title")
        }
    }

    @MainActor
    private func openManageSubscriptions() async {
        #if canImport(UIKit)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        _ = try? await AppStore.showManageSubscriptions(in: scene)
        await subscriptionManager.refreshAfterExternalSubscriptionChange()
        #endif
    }

    private static let accessDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
