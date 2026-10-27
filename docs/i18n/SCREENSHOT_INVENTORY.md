# Screenshot inventory (phase-2 closeout)

Temporary files live in `.tmp/i18n-audit/screenshots/` (not committed).

| File | Lang | Claimed | Actual (reviewed) | Issues |
|---|---|---|---|---|
| `de-01-today.png` | DE | de-01-today | Today | Weather truncated (fixed); Tätigkeit→Aktivität fixed after shot |
| `de-02-coach.png` | DE | de-02-coach | Coach | OK; Beliefs=Überzeugungen (debug) |
| `de-06-paywall.png` | DE | de-06-paywall | Paywall | OK |
| `de-07-onboarding.png` | DE | de-07-onboarding | Onboarding splash | Missing space zähltwenn — fixed in suffix + chrome |
| `de-10-settings.png` | DE | de-10-settings | Edit Meal sheet (NOT settings) | Wrong screen; Edit Meal EN title — fixed |
| `en-01-today.png` | EN | en-01-today | Today | OK; weather pill long |
| `en-02-coach.png` | EN | en-02-coach | Coach | OK empty-state |
| `en-03-meals.png` | EN | en-03-meals | Meals or Health Access | First pass was Health Access sheet (small file); re-pass may differ |
| `en-04-plan.png` | EN | en-04-plan | Plan or Health Access | First pass was Health Access |
| `en-06-paywall.png` | EN | en-06-paywall | Paywall | OK; StoreKit diagnostics debug chrome visible |
| `en-07-onboarding.png` | EN | en-07-onboarding | Onboarding splash | OK |
| `en-10-settings.png` | EN | en-10-settings | Settings/profile sheet (verify) | confirm not meal editor |
| `fr-03-meals.png` | FR | fr-03-meals | Meals | OK; meal titles concatenated |
| `ja-06-paywall.png` | JA | ja-06-paywall | Paywall | plan.value imperative calque — fixed |
| `ko-01-today.png` | KO | ko-01-today | Today | OK |
| `pl-04-plan.png` | PL | pl-04-plan | Plan | OK |
| `ru-01-today.png` | RU | ru-01-today | Today | Weather truncated — fixed |
| `ru-06-paywall.png` | RU | ru-06-paywall | Paywall | OK |
| `ru-08-quicklog-food-miss.png` | RU | ru-08-quicklog-food-miss | Plan Add Meal sheet | Useful meal/plan chrome; not QuickFoodLog id |
| `zh-Hans-01-today.png` | zh-Hans | zh-Hans-01-today | Today | OK |

## Coverage matrix

- `('01-today', 'captured')`: 10
- `('02-coach', 'captured')`: 10
- `('03-meals', 'captured')`: 10
- `('04-plan', 'captured')`: 10
- `('06-paywall', 'captured')`: 10
- `('07-onboarding', 'captured')`: 10
- `('08-quicklog-food', 'captured')`: 6
- `('08-quicklog-food', 'miss_or_wrong')`: 4
- `('09-quicklog-drinks', 'miss_or_wrong')`: 10
- `('10-settings', 'captured')`: 10
