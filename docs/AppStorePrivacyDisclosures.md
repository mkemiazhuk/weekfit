# App Store Connect privacy disclosures (manual)

This document lists **manual** App Privacy questionnaire answers that must stay aligned
with WeekFit’s analytics implementation and privacy manifests. It is **not** legal advice —
verify against Apple’s current definitions before each App Store submission.

Related:
- `WeekFit/PrivacyInfo.xcprivacy` (app-level)
- FirebaseCrashlytics bundled `PrivacyInfo.xcprivacy`
- `docs/privacy-report/` (archive + inspection notes)
- `docs/AnalyticsEventDictionary.md`

---

## Tracking

| Question | Answer | Why |
|----------|--------|-----|
| Does this app use data for tracking? | **No** | Analytics uses Firebase Analytics Core **without** Ad Support / IDFA. Events are not used to track users across other companies’ apps or websites for advertising. `NSPrivacyTracking` is `false` in app + Crashlytics manifests. |

Do **not** declare tracking unless product behavior changes to meet Apple’s tracking definition.

---

## PrivacyInfo vs App Store Connect

Apple: the app’s `PrivacyInfo.xcprivacy` does **not** need to repeat data types already declared by linked third-party SDK manifests. Xcode’s Privacy Report aggregates app + SDK manifests for ASC.

| Data type | Declared where | ASC Nutrition Label |
|-----------|----------------|---------------------|
| Product Interaction | **App** `PrivacyInfo.xcprivacy` (required — Firebase Analytics / GoogleAppMeasurement **12.16.0 ships no PrivacyInfo** with this type) | Declare collected |
| Crash Data | **FirebaseCrashlytics** SDK manifest only (do not duplicate in app) | Declare collected |
| Other Diagnostic Data | Crashlytics + Installations + GoogleDataTransport SDK manifests | Declare if Privacy Report shows it |

---

## Data types to declare (Nutrition Label)

### Product Interaction
- **Collected:** Yes  
- **Linked to identity:** **No**  
- **Used for tracking:** No  
- **Purposes:** Analytics  
- **Evidence:** No `Analytics.setUserID`, no account IDs / email / names in event parameters, no intentional join of Analytics to an identified user profile. Firebase Installation ID alone is **not** treated as proof of linkage to identity.  
- **What it is:** Bounded product events (screens, funnel steps, settings actions, review prompt states) logged via Firebase Analytics.

### Crash Data
- **Collected:** Yes (via Firebase Crashlytics SDK)  
- **Linked to identity:** No (SDK + no `Crashlytics.setUserID` in app code)  
- **Used for tracking:** No  
- **Purposes:** App Functionality  
- **Note:** Declared by Crashlytics’ own `PrivacyInfo.xcprivacy`, not repeated in the app manifest.

Also review Firebase’s guidance:  
https://firebase.google.com/docs/ios/app-store-data-collection

---

## Explicitly not collected via WeekFit analytics events

WeekFit product analytics **does not** send:

- HealthKit samples  
- Calories, macros, HRV, sleep values, recovery scores  
- Food names, barcodes, meal titles  
- Coach / recommendation / feedback message text  
- Email addresses, account IDs, or other PII in event parameters  
- Exact eligibility timestamps or raw high-cardinality counters (review eligibility uses coarse buckets)

Do **not** declare Health & Fitness data, Sensitive Info, or Contact Info **for analytics**
unless another product feature (outside this event layer) actually collects and leaves the device.

---

## When to revisit

- Adding paywall / subscription / ads SDKs  
- Enabling Analytics advertising identifiers or Google Ads linking  
- Calling `Analytics.setUserID` or Crashlytics user ID APIs (would flip Linked → Yes)  
- Firebase Analytics shipping a PrivacyInfo that includes ProductInteraction (then re-evaluate whether the app-level entry is still needed)  
- Collecting feedback message bodies remotely
