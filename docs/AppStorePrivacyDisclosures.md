# App Store Connect privacy disclosures (manual)

This document lists **manual** App Privacy questionnaire answers that must stay aligned
with WeekFit’s analytics implementation and privacy manifests. It is **not** legal advice —
verify against Apple’s current definitions before each App Store submission.

Related:
- `WeekFit/PrivacyInfo.xcprivacy` (app-level)
- FirebaseCrashlytics bundled `PrivacyInfo.xcprivacy`
- `docs/privacy-report/` (archive + inspection notes)
- `docs/AnalyticsEventDictionary.md`
- `ProductAnalyticsConsent` / `FirebaseEnvironment` (opt-in Analytics; Crashlytics separate)

---

## Tracking

| Question | Answer | Why |
|----------|--------|-----|
| Does this app use data for tracking? | **No** | Analytics uses Firebase Analytics Core **without** Ad Support / IDFA. Events are not used to track users across other companies’ apps or websites for advertising. `NSPrivacyTracking` is `false` in app + Crashlytics manifests. |

Do **not** declare tracking unless product behavior changes to meet Apple’s tracking definition.

---

## Consent model (shipped)

| Channel | Firebase Analytics | Firebase Crashlytics |
|---------|--------------------|----------------------|
| DEBUG | OFF | OFF |
| TestFlight / App Store | OFF until user enables **Share Product Analytics** in Settings | ON (crash diagnostics; no health payloads) |
| Missing stored choice (fresh + existing upgrades) | Treated as OFF | — |

---

## PrivacyInfo vs App Store Connect

Apple: the app’s `PrivacyInfo.xcprivacy` does **not** need to repeat data types already declared by linked third-party SDK manifests. Xcode’s Privacy Report aggregates app + SDK manifests for ASC.

| Data type | Declared where | ASC Nutrition Label |
|-----------|----------------|---------------------|
| Product Interaction | **App** `PrivacyInfo.xcprivacy` (required — Firebase Analytics / GoogleAppMeasurement **12.16.0 ships no PrivacyInfo** with this type) | Declare collected (when user opts in; still declare as collected capability) |
| Crash Data | **FirebaseCrashlytics** SDK manifest only (do not duplicate in app) | Declare collected |
| Other Diagnostic Data | Crashlytics + Installations + GoogleDataTransport SDK manifests | Declare if Privacy Report shows it |

---

## Data types to declare (Nutrition Label)

### Product Interaction (Usage Data)
- **Collected:** Yes (opt-in product analytics)
- **Linked to identity:** **No**
- **Used for tracking:** No
- **Purposes:** Analytics
- **Evidence:** No `Analytics.setUserID`, no account IDs / email / names in event parameters. Firebase Installation ID alone is **not** treated as proof of linkage to identity.
- **What it is:** Bounded product events (screens, funnel steps, settings actions, review prompt states, subscription product ids) logged via Firebase Analytics when consent is ON.

### Crash Data (Diagnostics)
- **Collected:** Yes (via Firebase Crashlytics SDK; independent of Analytics consent)
- **Linked to identity:** No (SDK + no `Crashlytics.setUserID` in app code)
- **Used for tracking:** No
- **Purposes:** App Functionality
- **Note:** Declared by Crashlytics’ own `PrivacyInfo.xcprivacy`, not repeated in the app manifest. Custom logs use bounded diagnostic codes only (no paths, HealthKit values, or `localizedDescription`).

### Purchases
- **Collected:** Yes if subscription funnel events remain (`product_id` catalog tokens only)
- **Linked to identity:** No
- **Used for tracking:** No
- **Purposes:** Analytics / App Functionality

### Health & Fitness
- **Collected via Firebase:** **No**
- WeekFit product analytics must not send raw or derived health/recovery/sleep/readiness signals.
- Local HealthKit use for in-app features remains on-device.

### Location / Contact Info / User Content
- **Via Firebase:** **No**

Also review Firebase’s guidance:  
https://firebase.google.com/docs/ios/app-store-data-collection

---

## Explicitly not collected via WeekFit analytics events

WeekFit product analytics **does not** send:

- HealthKit samples or permission-state tokens (`health_access_denied`)
- Derived recovery bands, sleep presence, readiness, HRV, RHR, training load
- Recovery-driven proposal strategy / reason categories / context confidence
- Coach health topic categories (`sleep`, `recovery`, `nutrition`, `hydration`)
- Calories, macros, hydration amounts
- Food names, barcodes, meal titles
- Activity/workout type categories, durations, intensity
- Coach / recommendation / feedback message text
- Email addresses, account IDs, or other PII in event parameters
- Exact eligibility timestamps or raw high-cardinality counters (review eligibility uses coarse buckets)

Do **not** declare Health & Fitness for Firebase analytics unless a regression reintroduces health-derived parameters
(guarded by `AnalyticsPrivacyContract` + unit tests).

---

## When to revisit

- Adding paywall / subscription / ads SDKs  
- Enabling Analytics advertising identifiers or Google Ads linking  
- Calling `Analytics.setUserID` or Crashlytics user ID APIs (would flip Linked → Yes)  
- Changing Analytics or Crashlytics consent coupling  
- Firebase Analytics shipping a PrivacyInfo that includes ProductInteraction (then re-evaluate whether the app-level entry is still needed)  
- Collecting feedback message bodies remotely
