# WeekFit — App Store Release Checklist

> **Purpose:** Gate for promoting a TestFlight build to App Store production.  
> **App:** WeekFit · `com.weekfit.app` · Team `7R6347XPK2`  
> **Target:** iOS 18+ (deployment) · v1.1  
> **Owner:** Engineering + QA + Product

**Release:** 1.2 (build 17)  
**Build:** archive with `Scripts/archive_for_app_store.sh`  
**Sign-off:** Engineering [ ] · QA [ ] · Product [ ]

---

## 0. Scope of this release (WIP on main)

| Area | Status |
|------|--------|
| Firebase Analytics Core + Crashlytics | In tree — **ship** |
| Review prompts + Help WeekFit / feedback (mailto) | In tree — **ship** |
| Privacy policy updated for analytics/crash/feedback | Prepared — **deploy before submit** |
| Meals empty states + library sync + barcode polish | In tree — **ship** |
| Swimming / Hiking workouts + coach coverage | In tree — **ship** |
| Profile avatar discoverability | In tree — **ship** |
| App size / asset compression | Deferred — not in this release |
| Insights / Highlights tabs | Still unshipped |

---

## 1. Pre-archive (engineering)

| # | Check | How | Pass |
|---|-------|-----|------|
| 1.1 | Versioning | `MARKETING_VERSION` = `1.2`; `CURRENT_PROJECT_VERSION` = **17** | [x] 2026-07-28 |
| 1.2 | Privacy manifest | `WeekFit/PrivacyInfo.xcprivacy` declares Product Interaction; Crashlytics via SDK | [x] |
| 1.3 | Export compliance | `ITSAppUsesNonExemptEncryption = NO` in Release build settings | [x] |
| 1.4 | Entitlements | HealthKit, HealthKit background delivery, Sign in with Apple | [x] |
| 1.5 | Debug paths | UI-testing / debug diagnostics are `#if DEBUG` | [ ] spot-check |
| 1.6 | Unshipped modules | Insights / Highlights remain disabled — `docs/UnshippedFeatures.md` | [x] |
| 1.7 | Watch | No Watch companion promised in listing | [x] |
| 1.8 | `GoogleService-Info.plist` | Present locally for archive (gitignored); bundle id `com.weekfit.app` | [ ] verify before archive |
| 1.9 | Localization | `Scripts/check_localization_parity.py` + language-mix | [x] 2026-07-28 |
| 1.10 | Focused unit tests | Analytics + Review + Settings IA | [x] 2026-07-28 · iPhone 16 / iOS 18.5 |
| 1.11 | Full `WeekFitTests` | Unit suite only (UITests flaky / separate) | [x] 2026-07-28 · **TEST SUCCEEDED** |

---

## 2. App Store Connect (metadata)

| # | Check | Notes | Pass |
|---|-------|-------|------|
| 2.1 | Privacy Policy URL | https://weekfit.app/privacy.html — **must show updated 28 Jul 2026 copy** | [x] live 2026-07-28 |
| 2.2 | Support URL | https://weekfit.app/support.html | [ ] |
| 2.3 | App description | EN + RU — `docs/AppStoreListing.md` | [ ] |
| 2.4 | Subtitle & keywords | EN (+ RU if localized listing) | [ ] |
| 2.5 | Screenshots | iPhone 6.7" + 6.1" | [ ] |
| 2.6 | App Privacy questionnaire | See `docs/AppStorePrivacyDisclosures.md` — Product Interaction + Crash Data; **Tracking = No** | [ ] update ASC |
| 2.7 | Age rating | Health & Fitness, no medical diagnosis | [ ] |
| 2.8 | Pricing | Free (no IAP) | [ ] |
| 2.9 | Review notes + demo | Health path — `docs/AppStoreListing.md` | [ ] |
| 2.10 | What's New | 1.1 EN + RU from `docs/AppStoreListing.md` | [ ] |
| 2.11 | Phased release | Enable 10% → 50% → 100% | [ ] |

---

## 3. Coach gate (P0 — blocks release)

Full checklist: `COACH_RELEASE_CHECKLIST.md`

If this release does **not** change Coach narrative/copy engines, run the automated suites; screenshot batch optional.

```bash
xcodebuild test -scheme WeekFit \
  -destination 'platform=iOS Simulator,id=9AA9CED9-B49D-4CEA-83CD-289DEDD802E3' \
  -only-testing:WeekFitTests/CoachDayPriorityResolverXCTests \
  -only-testing:WeekFitTests/CoachStateNarrativeContractTests \
  -only-testing:WeekFitTests/HumanCoachDecisionEngineXCTests \
  -only-testing:WeekFitTests/TodayCoachContradictionRegressionTests
```

| Gate | Pass |
|------|------|
| P0 automated suites | [x] 2026-07-28 · iPhone 16 · **TEST SUCCEEDED** (+ classifier parity) |
| P1 / screenshots | [ ] if Coach copy changed |

---

## 4. QA gate

### 4.1 Automated

```bash
# Full suite (release gate)
xcodebuild test -scheme WeekFit \
  -destination 'platform=iOS Simulator,id=9AA9CED9-B49D-4CEA-83CD-289DEDD802E3'
```

| Suite | Pass |
|-------|------|
| Analytics + Review focused | [x] 2026-07-28 |
| Full `WeekFitTests` | [x] 2026-07-28 · re-run after 1.2 delta · **TEST SUCCEEDED** |
| Localization parity + language-mix | [x] 2026-07-28 |
| Release configuration archive | [x] `build/WeekFit.xcarchive` · **1.2 (17)** · 2026-07-28 |

### 4.2 Manual smoke (1.1-specific)

| Scenario | Pass |
|----------|------|
| Fresh install → Open WeekFit → Health prompt | [ ] |
| Settings → Help WeekFit → feedback mailto opens | [ ] |
| Meaningful actions → review prompt eligibility (DEBUG tooling OK) | [ ] |
| Firebase: events visible in DebugView / Crashlytics console after TestFlight | [ ] |
| Health granted / denied paths | [ ] |
| RU locale on 4 tabs | [ ] |
| In-app Terms/Privacy mentions analytics accurately | [ ] |

---

## 5. Archive & submit

| Step | Pass |
|------|------|
| `Scripts/archive_for_app_store.sh` | [x] 2026-07-28 · **1.2 (17)** |
| Validate App (Organizer) | [ ] |
| Distribute → App Store Connect | [ ] |
| Select build on version **1.2** | [ ] |
| Privacy policy live + ASC Nutrition Label updated | [x] policy live · [ ] ASC label |
| Submit for Review | [ ] |

---

## 6. Post-launch (first 7 days)

| Day | Action | Done |
|-----|--------|------|
| D0 | Phased release at 10% | [ ] |
| D0–D1 | Monitor Crashlytics + reviews | [ ] |
| D3 | Expand to 50% if stable | [ ] |
| D7 | 100% or hotfix | [ ] |

---

## 7. Known limitations (document, do not hide)

| Item | Status |
|------|--------|
| No cloud account / sync | By design — local-first |
| No subscriptions | Free app |
| No Apple Watch app | Phone + HealthKit sync only |
| Insights / Highlights | Not in navigation |
| Sign in with Apple | Wired but not required |
| App download size ~170 MB | Assets deferred; not a Review blocker |

---

## 8. Release decision

| | |
|---|---|
| Engineering | [ ] **GO** · [ ] **NO-GO** |
| QA | [ ] **GO** · [ ] **NO-GO** |
| Product | [ ] **GO** · [ ] **NO-GO** |

**Exceptions / notes:**

- Commit Analytics/Review WIP + privacy docs before archive.
- Deploy privacy.html **before** App Review sees the build.

---

*Listing: `docs/AppStoreListing.md` · Privacy ASC: `docs/AppStorePrivacyDisclosures.md` · Coach: `COACH_RELEASE_CHECKLIST.md`*
