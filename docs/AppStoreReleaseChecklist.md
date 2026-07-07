# WeekFit — App Store Release Checklist

> **Purpose:** Gate for promoting a TestFlight build to App Store production.  
> **App:** WeekFit · `com.weekfit.app` · Team `7R6347XPK2`  
> **Target:** iOS 17+ · v1.0  
> **Owner:** Engineering + QA + Product

**Release:** 1.0 (build 8)  
**Build:** `build/WeekFit.xcarchive` — archived locally  
**Sign-off:** Engineering [x] · QA [ ] · Product [ ]

---

## 1. Pre-archive (engineering)

| # | Check | How | Pass |
|---|-------|-----|------|
| 1.1 | Versioning | `MARKETING_VERSION` = `1.0`; `CURRENT_PROJECT_VERSION` is an **integer** (increment per submit) | [x] build **8** |
| 1.2 | Privacy manifest | `WeekFit/PrivacyInfo.xcprivacy` is in the WeekFit target (auto-synced via folder) | [x] |
| 1.3 | Export compliance | `ITSAppUsesNonExemptEncryption = NO` in Release build settings | [x] |
| 1.4 | Entitlements | HealthKit, HealthKit background delivery, Sign in with Apple | [ ] |
| 1.5 | Debug paths | No test-only UI in Release (`-ui-testing` bypass is DEBUG/launch-arg only) | [ ] |
| 1.6 | Unshipped modules | Insights / Highlights tabs remain disabled — see `docs/UnshippedFeatures.md` | [ ] |
| 1.7 | Watch | No Watch companion promised in listing — see `docs/AppleWatchStrategy.md` | [ ] |

---

## 2. App Store Connect (metadata)

| # | Check | Notes | Pass |
|---|-------|-------|------|
| 2.1 | Privacy Policy URL | **Required** — external URL (in-app `TermsPrivacyView` is not enough) | [x] ready — deploy Pages |
| 2.2 | Support URL | Public page or mailto landing | [x] ready — deploy Pages |
| 2.3 | App description | EN + RU — see `docs/AppStoreListing.md` | [ ] |
| 2.4 | Subtitle & keywords | EN (+ RU if localized listing) | [ ] |
| 2.5 | Screenshots | iPhone 6.7" + 6.1" (iPad optional) — 5–8 scenes per size | [ ] |
| 2.6 | App Privacy questionnaire | Health, Camera, Location declared honestly | [ ] |
| 2.7 | Age rating | Health & Fitness, no medical diagnosis | [ ] |
| 2.8 | Pricing | Free (no IAP in 1.0) | [ ] |
| 2.9 | Review notes + demo video | Health app test path — see `docs/AppStoreListing.md` | [ ] |
| 2.10 | Phased release | Enable 10% → 50% → 100% | [ ] |

---

## 3. Coach gate (P0 — blocks release)

Full checklist: `COACH_RELEASE_CHECKLIST.md`

```bash
xcodebuild test -scheme WeekFit \
  -only-testing:WeekFitTests/CoachDayPriorityResolverXCTests \
  -only-testing:WeekFitTests/CoachStateNarrativeContractTests \
  -only-testing:WeekFitTests/HumanCoachDecisionEngineXCTests \
  -only-testing:WeekFitTests/TodayCoachContradictionRegressionTests
```

| Gate | Pass |
|------|------|
| P0 guardrails (all rows) | [ ] |
| P1 guardrails (all or documented exceptions) | [ ] |
| Screenshot batch (8 scenarios) | [ ] |
| Matrix audit (if Coach copy PRs in release) | [ ] |

---

## 4. QA gate

### 4.1 Automated smoke

```bash
xcodebuild test -scheme WeekFit \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

| Suite | Pass |
|-------|------|
| WeekFitUITests (tab navigation) | [ ] |
| ActivityReconcilerXCTests | [x] |
| HealthManagerIntegrationTests | [x] HealthDataConnectionStateTests |
| Coach suites (above) | [x] |

### 4.2 Localization

```bash
python3 Scripts/check_localization_parity.py
python3 Scripts/check_localization_language_mix.py
```

| Check | Pass |
|-------|------|
| EN/RU parity | [x] |
| No language mix in production surfaces | [x] |

### 4.3 Accessibility (`docs/AccessibilityPass.md`)

Test on iPhone SE + iPhone 15 Pro Max, EN + RU, Dynamic Type AX3–AX5.

| Area | Pass |
|------|------|
| Today | [ ] |
| Coach | [ ] |
| Plan | [ ] |
| Meals | [ ] |
| Global (tabs, sheets) | [ ] |

### 4.4 Device matrix (manual, clean install)

| Scenario | Pass |
|----------|------|
| Fresh install → Login → Open WeekFit → Health prompt | [ ] |
| Health granted, no sleep yet → Coach shows calm readiness copy | [ ] |
| Health denied → Profile shows setup needed, not "connected" | [ ] |
| Planned workout + completion via HealthKit | [ ] |
| App kill → reopen → no duplicate imported workouts | [ ] |
| RU locale full pass on 4 tabs | [ ] |
| Background 5+ min → foreground refresh | [ ] |

---

## 5. Archive & submit

| Step | Pass |
|------|------|
| Scheme: WeekFit → Any iOS Device | [ ] |
| Configuration: Release | [ ] |
| Product → Archive | [x] `build/WeekFit.xcarchive` |
| Validate App (no errors) | [ ] in Xcode Organizer |
| Distribute → App Store Connect | [ ] |
| Select build in App Store version | [ ] |
| What's New filled (EN + RU) — `docs/AppStoreListing.md` | [ ] |
| Submit for Review | [ ] |

---

## 6. Post-launch (first 7 days)

| Day | Action | Done |
|-----|--------|------|
| D0 | Phased release at 10% | [ ] |
| D0–D1 | Monitor crashes & reviews in App Store Connect | [ ] |
| D3 | Expand to 50% if stable | [ ] |
| D7 | 100% rollout or hotfix 1.0.1 | [ ] |
| D7 | Retro: Health state, reconciler, RU gaps → backlog | [ ] |

---

## 7. Known 1.0 limitations (document, do not hide from review)

| Item | Status |
|------|--------|
| No cloud account / sync | By design — local-first |
| No subscriptions | Free app |
| No Apple Watch app | Phone + HealthKit sync only |
| Insights / Highlights | Not in navigation |
| Sign in with Apple | Wired but not required (`accountAuthEnabled = false`) |

---

## 8. Release decision

| | |
|---|---|
| Engineering | [ ] **GO** · [ ] **NO-GO** |
| QA | [ ] **GO** · [ ] **NO-GO** |
| Product | [ ] **GO** · [ ] **NO-GO** |

**Exceptions / notes:**

---

*Listing copy: `docs/AppStoreListing.md` · Coach gate: `COACH_RELEASE_CHECKLIST.md` · Product risks: `ProductAudit.md`*
