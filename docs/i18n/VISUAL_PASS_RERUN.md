# Localization visual pass — how to re-run

DEBUG + `-ui-testing` only. Launch flags are ignored in Release / App Store.

## Flags

| Flag | Effect |
|------|--------|
| `-weekfit-language=<code>` | Force in-app language (`en`,`ru`,`zh-Hans`,`fr`,`pl`,`es`,`de`,`ja`,`it`,`ko`) |
| `-weekfit-complete-onboarding` | Mark first-run completed |
| `-weekfit-force-onboarding` | Reset + present first-run onboarding (overrides UI-test suppress) |
| `-weekfit-skip-health-access` | Skip in-app HealthAccess gate |
| `-weekfit-force-paywall` | Open real paywall via DEBUG force-paywall store |
| `-weekfit-entitlement-test-state=` | `subscribed` / `unsubscribed` / `legacy` / … |
| `-weekfit-force-legacy-user` | Skip paywall entitlement path for tab chrome |

## StoreKit

Select `WeekFit/Configuration/WeekFit.storekit` in the Xcode scheme’s **Run/Test → Options → StoreKit Configuration** (Sandbox QA scheme documents this). There is no portable `xcodebuild -storekitconfigurationpath` on this Xcode.

## Command

```bash
xcodebuild test -scheme WeekFit \
  -destination 'platform=iOS Simulator,name=iPhone 17e,OS=26.5' \
  -only-testing:WeekFitUITests/LocalizationVisualPassUITests
```

Screenshots: `.tmp/i18n-audit/screenshots/` (temporary).

## Offline catalog audit

```bash
python3 Scripts/audit_localization.py
```

## Unit tests

```bash
xcodebuild test -scheme WeekFit \
  -destination 'platform=iOS Simulator,name=iPhone 17e,OS=26.5' \
  -only-testing:WeekFitTests/LocalizationCatalogIntegrityTests \
  -only-testing:WeekFitTests/LocalizationRegressionTests
```

Live LLM Coach / food recognition quality is **not** covered — only locale→prompt fixtures.
