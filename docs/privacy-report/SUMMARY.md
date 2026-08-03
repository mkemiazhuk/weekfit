# WeekFit Privacy Manifest Inspection (Firebase 12.16.0)

## Verdict: GoogleAppMeasurement / FirebaseAnalytics

**GoogleAppMeasurement 12.16.0 does NOT ship a `PrivacyInfo.xcprivacy`.** FirebaseAnalytics binary/Core wrappers also do not. `ProductInteraction` is declared only by the app manifest.

## Crashlytics (`Crashlytics/Resources/PrivacyInfo.xcprivacy`)

- type: `NSPrivacyCollectedDataTypeCrashData`
  - linked: `False`
  - tracking: `False`
  - purposes: `['NSPrivacyCollectedDataTypePurposeAppFunctionality']`
- type: `NSPrivacyCollectedDataTypeOtherDiagnosticData`
  - linked: `False`
  - tracking: `False`
  - purposes: `['NSPrivacyCollectedDataTypePurposeAppFunctionality']`
- NSPrivacyTracking: `False`
- NSPrivacyTrackingDomains: `[]`
- NSPrivacyAccessedAPITypes: UserDefaults reason CA92.1

## Archive-embedded PrivacyInfo with collected data types

### `Firebase_FirebaseCrashlytics.bundle/PrivacyInfo.xcprivacy`

- type: `NSPrivacyCollectedDataTypeCrashData`
  - linked: `False`
  - tracking: `False`
  - purposes: `['NSPrivacyCollectedDataTypePurposeAppFunctionality']`
- type: `NSPrivacyCollectedDataTypeOtherDiagnosticData`
  - linked: `False`
  - tracking: `False`
  - purposes: `['NSPrivacyCollectedDataTypePurposeAppFunctionality']`

### `Firebase_FirebaseInstallations.bundle/PrivacyInfo.xcprivacy`

- type: `NSPrivacyCollectedDataTypeOtherDiagnosticData`
  - linked: `False`
  - tracking: `False`
  - purposes: `['NSPrivacyCollectedDataTypePurposeAnalytics']`

### `GoogleDataTransport_GoogleDataTransport.bundle/PrivacyInfo.xcprivacy`

- type: `NSPrivacyCollectedDataTypeOtherDiagnosticData`
  - linked: `False`
  - tracking: `False`
  - purposes: `['NSPrivacyCollectedDataTypePurposeAnalytics']`

### `PrivacyInfo.xcprivacy` (app — after privacy verification)

- type: `NSPrivacyCollectedDataTypeProductInteraction`
  - linked: `False`
  - tracking: `False`
  - purposes: `['NSPrivacyCollectedDataTypePurposeAnalytics']`
- CrashData is **not** repeated at app level (Crashlytics SDK already declares it).

## Xcode Privacy Report PDF

Not automatable via `xcodebuild`. Archive at `docs/privacy-report/WeekFit.xcarchive`. Use Organizer → Generate Privacy Report.

## Verification notes (2026-07-27)

- No `Analytics.setUserID` / Crashlytics user ID APIs in WeekFit sources.
- Firebase Analytics / GoogleAppMeasurement 12.16.0: **no** shipped `PrivacyInfo.xcprivacy` → app must declare ProductInteraction.
- Purposes corrected: ProductInteraction → Analytics only; CrashData → AppFunctionality (via Crashlytics).
