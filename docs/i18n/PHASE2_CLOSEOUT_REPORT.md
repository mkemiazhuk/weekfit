# WeekFit localization — phase 2 closeout

Date: 2026-10-26. No commit / push / deploy.

Permanent materials: this folder (`docs/i18n/`). Temporary screenshots: `.tmp/i18n-audit/screenshots/`.

## Исправлено (closeout)

- UITest isolation flags: `-weekfit-force-onboarding`, `-weekfit-force-paywall`, `-weekfit-skip-health-access`, `-weekfit-complete-onboarding` (DEBUG + `-ui-testing` only; production-inert).
- Onboarding was previously **suppressed** under `-ui-testing`; force flag now presents `screen.onboarding`.
- Paywall reachable via force-paywall diagnostics path (asserts `paywall.cta`).
- Quick-action a11y ids: `today.quickAction.food` / `.drinks`.
- Splash concatenation spacing (`zähltwenn` etc.) — catalog suffixes + `spacedSplashSuffix()`.
- FAQ/Guides bodies: glossary product terms; DE calques (`Umzugstätigkeit`, `Verwertungstätigkeiten`, `Tätigkeit`→`Aktivität`).
- `meals.builder.title.edit` DE/KO/IT/… (`Edit Meal` / `아침 식사` → proper edit titles).
- JA `paywall.value.plan.body` imperative calque → descriptive.
- Weather pill shortened; `WeekFitLocalizedQuantityFormat` language mapping + EN catalog fallback; plural edge matrix 11–14, 101, 111–114; fractional via `portionsPhrase`.

## Проверено фактически (экраны)

| Экран | Языки | Доказательство |
|------|--------|----------------|
| Today | 10/10 | `*-01-today.png` |
| Coach | 10/10 | `*-02-coach.png` |
| Meals | 10/10 | `*-03-meals.png` (EN first pass had Health sheet; later tabs OK) |
| Plan | 10/10 | `*-04-plan.png` |
| **Paywall** | 10/10 | `*-06-paywall.png` with `paywall.cta` (gate shots **not** counted) |
| Onboarding splash | 10/10 | `*-07-onboarding.png` / `screen.onboarding` |
| Settings/profile path | 10 files | `*-10-settings.png` — **some mis-captures** (e.g. DE Edit Meal) |
| Quick log food | partial | some real meal sheets (RU Plan-add); many Health-blocked / false positives |
| Quick log drinks | 0 reliable | system Health Access / miss |

Catalog audit: `Scripts/audit_localization.py` → **failures=0**.  
Plural unit tests expanded (RU/PL teens + 101/111–114; DE/FR not English nouns; RU fractional portions).

FAQ/Guides: titles + bodies glossary pass; remaining FR `Nutrition` intentional (glossary keep).

## Screenshot review notes (selected)

See `docs/i18n/SCREENSHOT_INVENTORY.md` for reviewed rows. Highlights:

- All `*-05-paywall-or-gate.png` were **Today**, not paywall — discarded as paywall evidence.
- DE onboarding: glued `zähltwenn` — fixed.
- DE settings capture was **Edit Meal** with English title — title fixed in catalog.
- JA paywall feature blurb sounded like an order to the user — fixed.
- Weather pill truncation DE/RU — shortened copy.

## WeekFitLocalizedQuantityFormat

- Language: `AppLanguage.matchLanguageTag` / `zh`→`zh-Hans`.
- Plural: Slavic one/few/many for RU+PL; else one vs many.
- Fallback: preferred locale keys → English catalog forms → raw key (no crash).
- Args: `Int` into `%d`/`%lld`.
- Fractions: **not** in this API; use `WeekFitCountPluralization.portionsPhrase` (rounds to Int for noun form).

## Ограничения (осталось)

1. **Live LLM** Coach summary / food recognition prose — **not** verified (fixtures/mocks only).
2. **Quick log drinks** — not reliably opened (HealthKit system sheet).
3. **Settings sheets** — automation sometimes lands on meal editor / other chrome; not every language’s Settings root visually confirmed as Settings.
4. **Native-speaker quality** — not claimed.
5. StoreKit config must be selected in the Xcode scheme (no CLI flag on this Xcode).
6. User meal **titles** (concatenated ingredient names) are data, not catalog strings.

## Re-run

`docs/i18n/VISUAL_PASS_RERUN.md`
