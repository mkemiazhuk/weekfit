import XCTest
import SwiftUI
@testable import WeekFit

final class WeekFitAIBalanceTests: XCTestCase {
    private let english = Locale(identifier: "en_US")

    func testSmallestPackSortsBeforeTheLargerOne() {
        XCTAssertLessThan(
            WeekFitAIBalancePack.quantityRank("com.weekfit.topup.voice15"),
            WeekFitAIBalancePack.quantityRank("com.weekfit.topup.voice30")
        )
        XCTAssertLessThan(
            WeekFitAIBalancePack.quantityRank("com.weekfit.topup.photos20"),
            WeekFitAIBalancePack.quantityRank("com.weekfit.topup.photos50")
        )
    }

    func testCompactClockUsesShortUnitsWithoutCommas() {
        XCTAssertEqual(WeekFitAIClock.compact(seconds: 0, locale: english), "0m")
        XCTAssertEqual(WeekFitAIClock.compact(seconds: 45, locale: english), "45s")
        XCTAssertEqual(WeekFitAIClock.compact(seconds: 300, locale: english), "5m")
        XCTAssertEqual(WeekFitAIClock.compact(seconds: 852, locale: english), "14m 12s")
        XCTAssertEqual(WeekFitAIClock.compact(seconds: 900, locale: english), "15m")
        XCTAssertFalse(WeekFitAIClock.compact(seconds: 852, locale: english).contains(","))
        XCTAssertEqual(WeekFitAIClock.spoken(seconds: 120, locale: Locale(identifier: "ru_RU")), "2 минуты")
    }

    func testFullAllowanceShowsRemainingOverIncluded() throws {
        let content = try content(photosIncluded: 30, voiceIncluded: 300)
        XCTAssertEqual(content.photos.hero, "30")
        XCTAssertEqual(content.photos.includedValue, "30 / 30")
        XCTAssertEqual(content.photos.purchasedValue, "0")
        XCTAssertEqual(content.voice.hero, "5m")
        XCTAssertEqual(content.voice.includedValue, "5m / 5m")
        XCTAssertEqual(content.voice.purchasedValue, "0m")
        XCTAssertEqual(content.voice.fractionCaption, "Remaining / included")
        XCTAssertTrue(content.voice.includedAccessibility.contains("5 minutes left of 5 minutes included"))
    }

    func testPartialSpend() throws {
        let content = try content(photosIncluded: 18, voiceIncluded: 120)
        XCTAssertEqual(content.photos.hero, "18")
        XCTAssertEqual(content.photos.includedValue, "18 / 30")
        XCTAssertEqual(content.voice.hero, "2m")
        XCTAssertEqual(content.voice.includedValue, "2m / 5m")
        XCTAssertTrue(content.voice.includedAccessibility.contains("2 minutes left of 5 minutes included"))
    }

    func testZeroIncludedWithPurchasedTime() throws {
        let content = try content(photosIncluded: 0, voiceIncluded: 0, voicePurchased: 852)
        XCTAssertEqual(content.voice.hero, "14m 12s")
        XCTAssertEqual(content.voice.caption, "available to use")
        XCTAssertEqual(content.voice.includedValue, "0m / 5m")
        XCTAssertEqual(content.voice.purchasedValue, "14m 12s")
        XCTAssertFalse(content.voice.purchasedValue?.contains("/") == true)
        XCTAssertEqual(content.photos.hero, "0")
        XCTAssertEqual(content.photos.includedValue, "0 / 30")
        XCTAssertEqual(content.photos.purchasedValue, "0")
    }

    func testPurchasedTimeShowsWhatWasBoughtWhenTheSpendIsKnown() throws {
        let spent = try content(voiceIncluded: 0, voicePurchased: 852, voiceUsed: 300 + 48)
        XCTAssertEqual(spent.voice.includedValue, "0m / 5m")
        XCTAssertEqual(spent.voice.purchasedValue, "14m 12s / 15m")
        XCTAssertTrue(spent.voice.purchasedAccessibility.contains("left of"))
        XCTAssertTrue(spent.voice.purchasedAccessibility.contains("purchased"))

        let untouched = try content(voiceIncluded: 300, voicePurchased: 900, voiceUsed: 0)
        XCTAssertEqual(untouched.voice.purchasedValue, "15m / 15m")
    }

    func testSeveralPurchasesShowRemainderWithoutADenominator() throws {
        let content = try content(photosPurchased: 20 + 50, voiceIncluded: 0, voicePurchased: 900 + 1800)
        XCTAssertEqual(content.voice.purchasedValue, "45m")
        XCTAssertFalse(content.voice.purchasedValue?.contains("/") == true)
        XCTAssertEqual(content.voice.hero, "45m")
        XCTAssertEqual(content.photos.purchasedValue, "70")
        XCTAssertFalse(content.photos.purchasedValue?.contains("/") == true)
        XCTAssertEqual(content.photos.hero, "100")
    }

    func testMissingLimitsDoNotInventADenominator() throws {
        let content = try content(photosIncluded: 18, voiceIncluded: 120, grandfathered: false, limits: false)
        XCTAssertEqual(content.photos.includedValue, "18")
        XCTAssertEqual(content.voice.includedValue, "2m")
        XCTAssertNil(content.photos.fractionCaption)
        XCTAssertNil(content.voice.fractionCaption)
        XCTAssertFalse(content.photos.includedValue?.contains("/") == true)
    }

    func testInactiveSubscriptionKeepsPurchasedBalance() throws {
        let content = try content(active: false, photosPurchased: 20, voiceIncluded: 0, voicePurchased: 900, periodEnd: future)
        XCTAssertEqual(content.voice.hero, "15m")
        XCTAssertEqual(content.voice.purchasedValue, "15m")
        XCTAssertEqual(content.photos.purchasedValue, "20")
        XCTAssertEqual(content.accessNote, "An active Premium subscription is required.")
        XCTAssertNil(content.renews)
        XCTAssertEqual(content.usedFirst, "Your Premium allowance is used first.")
    }

    func testPastRenewalDateIsNotShownAsUpcoming() throws {
        let expired = try content(periodEnd: past)
        XCTAssertNil(expired.renews)
        let upcoming = try content(periodEnd: future)
        XCTAssertTrue(upcoming.renews?.contains("2027") == true)
        XCTAssertTrue(upcoming.renews?.hasPrefix("Premium allowance renews on ") == true)
    }

    func testGrandfatheredPhotosAreNotShownAsAMillion() throws {
        let content = try content(photosIncluded: 1_000_000, photosPurchased: 20, grandfathered: true)
        XCTAssertFalse(content.photos.hero.contains("1000000") || content.photos.hero.contains("1,000,000"))
        XCTAssertEqual(content.photos.hero, "Existing access preserved")
        XCTAssertEqual(content.photos.includedValue, "Existing access preserved")
        XCTAssertNil(content.photos.fractionCaption)
        XCTAssertEqual(content.photos.purchasedValue, "20")
        XCTAssertNil(content.photos.action)
        XCTAssertEqual(content.voice.action, WeekFitAIBalancePack.time)
    }

    func testReservedOrFinalizingCallDoesNotShowAFinalRemainder() throws {
        let held = try content(voiceIncluded: 0, voicePurchased: 852, voiceReserved: 300)
        XCTAssertEqual(held.voice.hero, "This time is held for your current call.")
        XCTAssertFalse(held.voice.showsBreakdown)
        XCTAssertNil(held.voice.includedValue)
        XCTAssertEqual(held.voice.action, WeekFitAIBalancePack.time)
        XCTAssertEqual(held.photos.hero, "30")

        let finishing = try content(voiceIncluded: 0, voiceReserved: 300, finalizing: true)
        XCTAssertEqual(finishing.voice.hero, "Updating your time after the call")
        XCTAssertFalse(finishing.voice.showsBreakdown)
    }

    func testLargerPackShowsRealSavingsOnly() {
        XCTAssertEqual(WeekFitAIBalancePack.savingsPercent(price: 11.99, quantity: 30, basePrice: 6.99, baseQuantity: 15), 14)
        XCTAssertNil(WeekFitAIBalancePack.savingsPercent(price: 13.49, quantity: 30, basePrice: 6.99, baseQuantity: 15))
        XCTAssertNil(WeekFitAIBalancePack.savingsPercent(price: 6.99, quantity: 15, basePrice: 6.99, baseQuantity: 15))
        XCTAssertNil(WeekFitAIBalancePack.savingsPercent(price: 16.99, quantity: 30, basePrice: 6.99, baseQuantity: 15))
        XCTAssertEqual(WeekFitAIBalancePack.quantity("com.weekfit.topup.photos50"), 50)
        XCTAssertNil(WeekFitAIBalancePack.quantity("com.weekfit.topup.unknown"))
        XCTAssertEqual(String(format: WeekFitLocalizedString("ai.balance.save", locale: Locale(identifier: "ru")), 14), "Выгоднее на 14%")
    }

    func testPackEstimatesReadNaturally() {
        let ru = Locale(identifier: "ru")
        XCTAssertEqual(WeekFitAIBalancePack.time.estimate(quantity: 15), 5)
        XCTAssertEqual(WeekFitAIBalancePack.photos.estimate(quantity: 50), 16)
        XCTAssertNil(WeekFitAIBalancePack.time.estimate(quantity: 2))
        XCTAssertEqual(WeekFitLocalizedQuantityFormat("ai.balance.estimate.calls", count: 5, locale: ru), "≈ 5 звонков по 3 мин")
        XCTAssertEqual(WeekFitLocalizedQuantityFormat("ai.balance.estimate.calls", count: 2, locale: ru), "≈ 2 звонка по 3 мин")
        XCTAssertEqual(WeekFitLocalizedQuantityFormat("ai.balance.estimate.days", count: 6, locale: ru), "≈ 6 дней по 3 приёма пищи")
        XCTAssertEqual(WeekFitLocalizedQuantityFormat("ai.balance.estimate.days", count: 1, locale: english), "≈ 1 day at 3 meals a day")
    }

    func testPackTitleSplitsIntoAmountAndUnit() {
        XCTAssertEqual(WeekFitAIBalancePackOption.split(title: "15 минут", quantity: 15).amount, "15")
        XCTAssertEqual(WeekFitAIBalancePackOption.split(title: "15 минут", quantity: 15).unit, "минут")
        XCTAssertEqual(WeekFitAIBalancePackOption.split(title: "15分", quantity: 15).unit, "分")
        XCTAssertNil(WeekFitAIBalancePackOption.split(title: "Mystery pack", quantity: 15).unit)
        XCTAssertEqual(WeekFitAIBalancePackOption.split(title: "Mystery pack", quantity: nil).amount, "Mystery pack")
    }

    func testUsageWithoutLimitsStillDecodes() throws {
        let usage = try decode(limits: false)
        XCTAssertNil(usage.limits)
        let withLimits = try decode(limits: true)
        XCTAssertEqual(withLimits.limits, WeekFitAIUsage.Limits(photos: 30, voice: 300))
    }

    @MainActor
    func testRenderPaywallAIBenefits() throws {
        let directory = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.tmp/ai-balance-shots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for appearance in [WeekFitAppearance.light, WeekFitAppearance.dark] {
            WeekFitPaletteStore.update(appearance: appearance, blend: 0)
            let palette = WeekFitSemanticPalette.interpolated(blend: 0, appearance: appearance)
            for name in ["en", "ru", "de", "fr", "es", "it", "pl", "ja", "ko", "zh-Hans"] {
                let locale = Locale(identifier: name)
                func t(_ key: String) -> String { WeekFitLocalizedString(key, locale: locale) }
                let view = VStack(alignment: .leading, spacing: 10) {
                    Text(t("ai.usage.paywallTitle"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(t("ai.usage.paywallSubtitle"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.bottom, 8)
                    WeekFitPaywallValueRow(icon: "waveform", title: t("ai.usage.paywallMayaTitle"),
                                           subtitle: t("ai.usage.paywallMayaBody"),
                                           allowance: t("ai.usage.paywallMayaAllowance"))
                    WeekFitPaywallValueRow(icon: "camera", title: t("ai.usage.paywallPhotoTitle"),
                                           subtitle: t("ai.usage.paywallPhotoBody"),
                                           allowance: t("ai.usage.paywallPhotoAllowance"))
                    WeekFitPaywallValueRow(icon: "sparkles", title: t("ai.usage.paywallCoachTitle"),
                                           subtitle: t("ai.usage.paywallCoachBody"))
                    Text(t("ai.usage.paywallFootnote"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(24)
                .frame(width: 402)
                .background(palette.appScreenBackground)
                .environment(\.weekFitPalette, palette)
                .environment(\.colorScheme, appearance == .light ? .light : .dark)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let data = try XCTUnwrap(renderer.uiImage?.pngData())
                XCTAssertGreaterThan(data.count, 10_000)
                try data.write(to: directory.appendingPathComponent("paywall-\(name)-\(appearance).png"))
            }
        }
    }

    @MainActor
    func testRenderBalanceInLightAndDark() throws {
        let content = try content(photosIncluded: 30, voiceIncluded: 0, voicePurchased: 852, periodEnd: future)
        let directory = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.tmp/ai-balance-shots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for appearance in [WeekFitAppearance.light, WeekFitAppearance.dark] {
            WeekFitPaletteStore.update(appearance: appearance, blend: 0)
            let palette = WeekFitSemanticPalette.interpolated(blend: 0, appearance: appearance)
            let view = VStack(spacing: 0) {
                Text(WeekFitLocalizedString("ai.usage.title", locale: english))
                    .font(.headline)
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                WeekFitAIBalanceScreen(
                    content: content,
                    isLoading: false,
                    message: nil,
                    showsSubscribe: false,
                    showsManage: true,
                    isBusy: false,
                    locale: english,
                    scrolls: false,
                    onAdd: { _ in },
                    onRetry: {},
                    onSubscribe: {},
                    onManage: {}
                )
            }
            .frame(width: 402, height: 874, alignment: .top)
            .background(WeekFitTheme.backgroundColor)
            .environment(\.weekFitPalette, palette)
            .environment(\.colorScheme, appearance == .light ? .light : .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            renderer.proposedSize = ProposedViewSize(width: 402, height: 874)
            let image = renderer.uiImage
            let data = try XCTUnwrap(image?.pngData())
            XCTAssertGreaterThan(data.count, 10_000)
            try data.write(to: directory.appendingPathComponent("\(appearance).png"))

            for (name, locale) in [("en", english), ("ru", Locale(identifier: "ru"))] {
                func t(_ key: String) -> String { WeekFitLocalizedString(key, locale: locale) }
                let small = t("ai.balance.pack.voice15")
                let large = t("ai.balance.pack.voice30")
                let first = WeekFitAIBalancePackOption.split(title: small, quantity: 15)
                let second = WeekFitAIBalancePackOption.split(title: large, quantity: 30)
                let sheet = WeekFitAIBalancePurchaseLayout(
                    title: t("ai.balance.addTime"),
                    symbol: "waveform",
                    intro: t("ai.balance.timeIntro"),
                    options: [
                        WeekFitAIBalancePackOption(id: "voice15", title: small, price: "6,99 zł",
                            amount: first.amount, unit: first.unit,
                            unitPrice: String(format: t("ai.balance.perMinute"), "0,47 zł"),
                            estimate: WeekFitLocalizedQuantityFormat("ai.balance.estimate.calls", count: 5, locale: locale)),
                        WeekFitAIBalancePackOption(id: "voice30", title: large, price: "11,99 zł",
                            badge: String(format: t("ai.balance.save"), locale: locale, 14),
                            amount: second.amount, unit: second.unit,
                            unitPrice: String(format: t("ai.balance.perMinute"), "0,40 zł"),
                            estimate: WeekFitLocalizedQuantityFormat("ai.balance.estimate.calls", count: 10, locale: locale))
                    ],
                    selectedID: "voice30",
                    summary: WeekFitAIBalanceOrderSummary(
                        title: t("ai.balance.orderSummary"),
                        item: large,
                        price: "11,99 zł",
                        totalTitle: t("ai.balance.total"),
                        note: t("ai.balance.taxNote")
                    ),
                    terms: [t("ai.balance.purchasedTimeNeverExpires"), t("ai.usage.subscriptionRequired")],
                    buyTitle: String(format: t("ai.balance.buy"), locale: locale, large, "11,99 zł"),
                    isBusy: false,
                    status: nil,
                    emptyMessage: nil,
                    scrolls: false,
                    onSelect: { _ in },
                    onBuy: {},
                    onClose: {}
                )
                .frame(width: 402, height: 760, alignment: .top)
                .background(WeekFitTheme.backgroundColor)
                .environment(\.weekFitPalette, palette)
                .environment(\.colorScheme, appearance == .light ? .light : .dark)
                let sheetRenderer = ImageRenderer(content: sheet)
                sheetRenderer.scale = 2
                sheetRenderer.proposedSize = ProposedViewSize(width: 402, height: 760)
                let sheetImage = try XCTUnwrap(sheetRenderer.uiImage?.pngData())
                XCTAssertGreaterThan(sheetImage.count, 10_000)
                try sheetImage.write(to: directory.appendingPathComponent("sheet-\(name)-\(appearance).png"))

                let accent = Color(red: 0.84, green: 0.62, blue: 0.27)
                let rows = VStack(spacing: 14) {
                    ForEach([79, 4, 0], id: \.self) { count in
                        WeekFitAIPhotosLeftRow(count: count, accent: accent, locale: locale, action: {})
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 20).fill(WeekFitTheme.cardBackground))
                    }
                    WeekFitAIPhotosLeftRow(count: nil, accent: accent, locale: locale, action: {})
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 20).fill(WeekFitTheme.cardBackground))
                }
                .padding(20)
                .frame(width: 402)
                .background(WeekFitTheme.backgroundColor)
                .environment(\.weekFitPalette, palette)
                let rowsRenderer = ImageRenderer(content: rows)
                rowsRenderer.scale = 2
                try XCTUnwrap(rowsRenderer.uiImage?.pngData())
                    .write(to: directory.appendingPathComponent("photos-left-\(name)-\(appearance).png"))
            }
        }
    }

    private var future: Double { Date(timeIntervalSince1970: 1_800_000_000).timeIntervalSince1970 * 1000 }
    private var past: Double { Date(timeIntervalSince1970: 1_000_000_000).timeIntervalSince1970 * 1000 }

    private func content(
        active: Bool = true,
        photosIncluded: Int = 30,
        photosPurchased: Int = 0,
        voiceIncluded: Int = 300,
        voicePurchased: Int = 0,
        voiceUsed: Int = 0,
        voiceReserved: Int = 0,
        finalizing: Bool = false,
        grandfathered: Bool = false,
        limits: Bool = true,
        periodEnd: Double? = nil
    ) throws -> WeekFitAIBalanceContent {
        let usage = try decode(
            active: active,
            photosIncluded: photosIncluded,
            photosPurchased: photosPurchased,
            voiceIncluded: voiceIncluded,
            voicePurchased: voicePurchased,
            voiceUsed: voiceUsed,
            voiceReserved: voiceReserved,
            finalizing: finalizing,
            grandfathered: grandfathered,
            limits: limits,
            periodEnd: periodEnd ?? future
        )
        return WeekFitAIBalanceContent.make(usage, now: Date(timeIntervalSince1970: 1_761_000_000), locale: english)
    }

    func testMayaCardCountsHeldSecondsAndWholeMinutes() throws {
        let russian = Locale(identifier: "ru")
        XCTAssertEqual(MayaCallBalance(try decode(voiceIncluded: 300)), .seconds(300))
        XCTAssertEqual(MayaCallBalance(try decode(voiceIncluded: 200, voicePurchased: 900, voiceReserved: 40)), .seconds(1140))
        XCTAssertEqual(MayaCallBalance(try decode(active: false)), .needsPremium)
        XCTAssertEqual(MayaCallBalance.seconds(299).note(locale: english), "4 min left")
        XCTAssertEqual(MayaCallBalance.seconds(299).note(locale: russian), "Осталось 4 мин")
        XCTAssertEqual(MayaCallBalance.seconds(59).note(locale: russian), "Осталось меньше минуты")
        XCTAssertEqual(MayaCallBalance.seconds(0).note(locale: russian), "Минуты закончились")
        XCTAssertEqual(MayaCallBalance.needsPremium.note(locale: russian), "Входит в Premium")
        XCTAssertFalse(MayaCallBalance.seconds(120).isLow)
        XCTAssertTrue(MayaCallBalance.seconds(119).isLow)
        XCTAssertTrue(MayaCallBalance.seconds(0).isLow)
        XCTAssertFalse(MayaCallBalance.needsPremium.isLow)
    }

    @MainActor
    func testRenderMayaCardBalances() throws {
        let directory = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.tmp/ai-balance-shots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for appearance in [WeekFitAppearance.light, WeekFitAppearance.dark] {
            WeekFitPaletteStore.update(appearance: appearance, blend: 0)
            let palette = WeekFitSemanticPalette.interpolated(blend: 0, appearance: appearance)
            let balances: [MayaCallBalance?] = [.seconds(272), .seconds(95), .seconds(0), .needsPremium, nil]
            let view = VStack(spacing: 12) {
                ForEach(Array(balances.enumerated()), id: \.offset) { _, balance in
                    MayaPearlCallCard(isReturning: false, balance: balance) {}
                }
            }
            .padding(16)
            .frame(width: 402)
            .background(palette.appScreenBackground)
            .environment(\.weekFitPalette, palette)
            .environment(\.colorScheme, appearance == .light ? .light : .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let data = try XCTUnwrap(renderer.uiImage?.pngData())
            try data.write(to: directory.appendingPathComponent("maya-card-\(appearance).png"))
        }
    }

    private func decode(
        active: Bool = true,
        photosIncluded: Int = 30,
        photosPurchased: Int = 0,
        voiceIncluded: Int = 300,
        voicePurchased: Int = 0,
        voiceUsed: Int = 0,
        voiceReserved: Int = 0,
        finalizing: Bool = false,
        grandfathered: Bool = false,
        limits: Bool = true,
        periodEnd: Double = 1_800_000_000_000
    ) throws -> WeekFitAIUsage {
        let limitsJSON = limits ? #""limits":{"photos":30,"voice":300},"# : ""
        let json = """
        {"appAccountToken":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE","active":\(active),
         "productId":"com.weekfit.subscription.monthly","periodStart":1,"periodEnd":\(periodEnd),
         "grandfatheredPhotos":\(grandfathered),
         "photos":{"included":\(photosIncluded),"purchased":\(photosPurchased)},
         "voice":{"included":\(voiceIncluded),"purchased":\(voicePurchased),"reserved":\(voiceReserved),"used":\(voiceUsed)},
         \(limitsJSON)
         "voiceFinalizing":\(finalizing)}
        """
        return try JSONDecoder().decode(WeekFitAIUsage.self, from: Data(json.utf8))
    }
}
