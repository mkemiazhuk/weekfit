# WeekFit 1.3.6 — release verification

## Published 1.3.5 vs this tree

| Item | Value |
|------|--------|
| ASC uploaded | **1.3.5 (build 1)** — Organizer archive `2026-10-02/WeekFit 02-10-2026, 12.51.xcarchive` |
| Code base for that upload | `dd07e9c` (What’s New 1.3.4) + **local-only** `MARKETING_VERSION=1.3.5` / `CURRENT_PROJECT_VERSION=1` (never committed) |
| Git tags for 1.3.5 | **None** |
| This working tree | **1.3.6 (29)** = all of 1.3.4/`dd07e9c` + Firebase/morning/onboarding/grace/Ask-to-Buy fixes |

There is no separate 1.3.5 feature commit to cherry-pick. Shipping 1.3.6 includes everything that was in the 1.3.5 binary plus the audit fixes.

---

## Manual analytics / StoreKit checks

### Scheme: **WeekFit Sandbox QA**

Use this shared scheme on a **physical iPhone** with a Sandbox Apple ID:

| Launch arg | Default | Purpose |
|------------|---------|---------|
| `-weekfit-enable-debug-analytics` | ON | Firebase Analytics ON in Debug (`distribution=debug`) |
| `-FIRDebugEnabled` / `-FIRAnalyticsDebugEnabled` | ON | DebugView streaming |
| `-weekfit-force-non-legacy` | OFF | Optional; Sandbox sentinel is already non-legacy |
| StoreKit Configuration | **none** | Real ASC Sandbox prices (PL storefront → e.g. 4,99 / 39,99 zł) |

Local `WeekFit/Configuration/WeekFit.storekit` prices (`4.99` / `34.99` USD, storefront USA) apply only when that file is selected in a scheme for Xcode StoreKit Testing — not in Sandbox QA.

### Sandbox sentinel vs Production legacy

| Environment | `originalPurchaseDate` | Legacy? |
|-------------|------------------------|---------|
| **Sandbox** | Apple sentinel `2013-08-01` | **No** — paywall / expire / restore testable |
| **Production** | Real App Store download date | Yes if `< monetization cutoff` |

### Which build can hit DebugView?

| Build | Analytics | How to use |
|-------|-----------|------------|
| **DEBUG** default scheme | **OFF** | Cannot validate Firebase events |
| **DEBUG + WeekFit Sandbox QA** | ON (`distribution=debug`) | Preferred Sandbox + DebugView path |
| **Release → device** | ON if consent (`testflight`/`appstore`) | Archive / TF |
| **App Store** | ON (`distribution=appstore`) | Production |

`distribution` is set in `FirebaseEnvironment.configureTelemetry()`. Production reports must filter `distribution = appstore`.

### Sandbox checklist (device, WeekFit Sandbox QA)

1. Confirm console: `Firebase telemetry: debug — analytics ON` and entitlements `env=Sandbox` → **not** `legacy` when subscription expired.
2. **Purchase** → `subscription_purchase_started` → `subscription_purchase_success` + `in_app_purchase`/`_iapx` once. Premium unlocks. Prices from ASC (e.g. PL 4,99 / 39,99 zł), not local `.storekit` USD.
3. **Expire** (Sandbox accelerated renewal / Manage Subscriptions) → Premium **closes** (`expired` / `unsubscribed`), not stuck on legacy.
4. **Restore** with active sub → `restore_started` → `restore_success`; no second revenue event.
5. **Restore** with nothing → `restore_completed` (`no_purchases`).
6. **Cancel** purchase sheet → `subscription_purchase_cancelled` only.
7. **Pending / Ask to Buy** → `purchase_failed`(`pending`); after approve (incl. after kill) → one success + one `logTransaction`.
8. Foreground spam: `Product.products cache hit` after first load (no request storm).
9. **Grace** — grace keeps Premium; bare billing retry does not; recovery restores Premium.

---

## Money reconciliation (ASC ≠ Firebase Revenue)

Do **not** equate ASC **Proceeds** (after Apple commission) to Firebase / GA4 **Revenue**.

| Source | What it shows | Notes |
|--------|---------------|--------|
| ASC Sales / Proceeds | Net to developer after commission, in proceeds currency | Taxes/VAT handling differs by country; refunds reduce proceeds |
| ASC Units / Sales | Units sold / customer price | Better unit match than proceeds |
| Firebase `in_app_purchase` value | Customer-facing transaction value from StoreKit (pre-commission), GA4 currency | Trials/promos often **$0**; Sandbox may appear only in DebugView |
| Custom `subscription_purchase_success` | Funnel count only | **Not** revenue |

**Comparable approach:**
1. Same calendar window in UTC (or storefront local day — pick one and stick to it).
2. Compare **paid units** (ASC) vs **paid `in_app_purchase` events** with value > 0 (Firebase), filtered `distribution=appstore`.
3. Expect Firebase revenue ≈ sum of customer prices (tax-inclusive or exclusive depending on StoreKit locale), **not** ASC proceeds (~70% after commission, variable).
4. Exclude Sandbox / TestFlight (`distribution!=appstore`).
5. Allow 24–48h Firebase processing delay; refunds and FX create residual gaps.

---

## Entitlement states (post-fix)

| StoreKit status | Premium? |
|-----------------|----------|
| Active subscribed period | Yes |
| `inGracePeriod` (before `gracePeriodExpirationDate`) | Yes |
| `inBillingRetryPeriod` without grace | **No** |
| Expired / revoked | No |
| Payment recovered → subscribed again | Yes |
