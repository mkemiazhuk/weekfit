# WeekFit Analytics Event Dictionary

Product analytics go through `AppAnalytics` / `ProductAnalytics` / `OnboardingFunnelAnalytics` /
`ReviewAnalytics` (review funnel bridge). Feature code must not import Firebase.

**Ownership:** Every new event must answer a concrete product question, use a typed
`AnalyticsEvent` case + bounded parameters, and be documented here before shipping.
Prefer extending parameters over inventing near-duplicate event names.

**Privacy rules:** never send HealthKit values, free-form text, names, emails, barcodes,
food names, macros, notification copy, recommendation / coach message text,
`localizedDescription`, user IDs, or exact high-cardinality timestamps.

App Store Connect questionnaire notes: `docs/AppStorePrivacyDisclosures.md`.

---

## Event lifecycle guarantees

| Rule | Behavior |
|------|----------|
| Started once per flow | `*_started` opens a flow; callers must not spam on SwiftUI re-render |
| One terminal where reliable | Exactly one of `completed` / `failed` / `cancelled` for food & hydration; activity sheet uses `activity_started` / `activity_completed` / `activity_logging_failed` / `activity_cancelled` |
| Cancel semantics | Cancel only after start, only if no terminal yet, only on genuine dismiss-before-save |
| Screens | Visit semantics via `ProductScreenTracker` — same active destination is not re-emitted |
| SwiftUI | Re-renders / language resets / backgrounding must not invent duplicate terminals |

---

## Screens (`trackScreen`)

| Screen id | Trigger | Purpose |
|-----------|---------|---------|
| `today` | Root appear + tab change to Today | Primary destination |
| `coach` | Tab change to Coach | Primary destination |
| `meals` | Tab change to Meals | Primary destination |
| `plan` | Tab change to Plan (`WeekFitTab.calendar`) | Primary destination |
| `settings` | Settings sheet appear | Profile / settings host |
| `recovery_details` | Today recovery ring open | Detail destination |
| `activity_details` | Today activity ring / intelligence open | Detail destination |
| `nutrition_details` | Today nutrition ring open | Detail destination (includes hydration UI) |
| `meal_builder` | Meal Builder appear | Creation surface |
| `onboarding` | Reserved (first-run flow) | Activation |
| `help_weekfit` / `feedback_form` | Settings help destinations | Support |

**Automatic Firebase screen reporting is disabled** via `FirebaseAutomaticScreenReportingEnabled = NO` in `Info.plist`. Only manual `trackScreen` / `screen_view` events from `ProductScreenTracker` are used.

**Duplicate prevention:** `ProductScreenTracker` emits only when the active screen changes.
Same-tab re-taps are ignored by bottom bar / `selectTab`.

**Omitted screens:** Insights, Highlights (unshipped); dedicated sleep/hydration/barcode scanner screens (embedded in Recovery / Nutrition / photo capture).

---

## Onboarding / activation

| Event | Trigger | Parameters | Completion / cancel |
|-------|---------|------------|---------------------|
| `onboarding_started` | First genuine onboarding presentation | — | Once per lifecycle (`OnboardingFunnelAnalytics`) |
| `onboarding_step_viewed` | Step becomes active | `step` | Once per step id per lifecycle |
| `onboarding_completed` | After `OnboardingStore.markCompleted()` persists | — | Once after successful persistence |
| `health_connection_*` | Onboarding Health connect / skip / fail | `reason` on fail | See onboarding docs in code comments |
| `notification_permission_responded` | System notification dialog result | `status` | Only when dialog was shown |

---

## Today

| Event | Trigger | Parameters |
|-------|---------|------------|
| `today_primary_action_tapped` | Quick action or coach insight tap | `action_category`, `source=today` |
| `today_section_opened` | Recovery / activity / nutrition ring | `section`, `source=today` |
| `quick_log_opened` | Food or drink quick-log sheet open | `action_category`, `source=today` |

---


## Morning Proposal (Phase 1)

Privacy: coarse `change_kind`, `reason_category`, count buckets, `result_type`, `surface` only.
Never log Recovery/HRV/sleep values, titles, HealthKit samples, or localized Coach copy.

| Event | When | Params |
|-------|------|--------|
| `morning_proposal_generated` | Engine produces ready proposal | `selected_count_bucket`, `source` |
| `morning_proposal_unavailable` | Gate/engine unavailable | `reason`, `source` |
| `morning_proposal_no_changes` | No mutating/guidance changes | `source` |
| `morning_proposal_viewed` | Today ready card shown (once/proposal id) | `selected_count_bucket`, `surface` |
| `morning_proposal_review_opened` | Review sheet appear | `selected_count_bucket`, `surface` |
| `morning_proposal_recommendation_selected` | Toggle on | `change_kind`, `reason_category` |
| `morning_proposal_recommendation_deselected` | Toggle off | `change_kind`, `reason_category` |
| `morning_proposal_reason_expanded` | Why expanded | `change_kind`, `reason_category` |
| `morning_proposal_apply_started` | Apply tapped | `selected_count_bucket` |
| `morning_proposal_apply_succeeded` | All selected applied | `applied_count_bucket`, `result_type` |
| `morning_proposal_apply_partial` | Some applied, some failed | `applied_count_bucket`, `selected_count_bucket`, `result_type` |
| `morning_proposal_apply_failed` | Apply failed / stale / none valid | `result_type` |
| `morning_proposal_dismissed` | Keep original plan | `surface` |
| `morning_proposal_stale` | Fingerprint drift | `source` |
| `morning_proposal_adjusted_item_viewed` | Provenance detail opened | `change_kind?`, `surface` |
| `morning_proposal_adjusted_item_manually_edited` | User edits after Apply | `change_kind?`, `surface` |
| `morning_proposal_adjusted_item_completed` | Adjusted activity completed | `change_kind?` |
| `morning_proposal_coach_acknowledgment_viewed` | Coach/Today ack shown (once/day) | `surface` |
| `morning_proposal_notification_scheduled` | Local proposal-ready notification scheduled | `surface`, `source=notification` |
| `morning_proposal_notification_opened` | User opened proposal-ready notification | `surface`, `source=notification` |

Helper: `MorningProposalAnalytics` / `ProductAnalytics` wrappers.

## Coach

| Event | Trigger | Parameters |
|-------|---------|------------|
| `coach_recommendation_viewed` | Recommendation text actually appears | `category`, `source=coach` |

### Category mapping (`CoachRecommendationCategory`)

Mapped from `CoachScenarioKey` (+ optional `CoachSafetyAlert`), never from copy or HealthKit:

| Category | When |
|----------|------|
| `hydration` | `warningAlert == .hydrationCritical` |
| `nutrition` | `warningAlert == .fuelCritical` |
| `sleep` | `morningReadiness` |
| `activity` | Endurance / racket / strength scenario families |
| `recovery` | Day-protection / heavy-yesterday / walk / recovery / sauna families |
| `general` | `stableDay` (fallback when no deterministic family) |

**Omitted:** `coach_action_tapped` / `completed` / `dismissed` — product UI has no reliable action handlers.

**View semantics:** Fired once per Coach view lifetime when recommendation content appears (`didRecordCoachRecommendationOpen` guard). Not fired on in-memory recompute alone.

---

## Food logging

| Event | Trigger | Parameters |
|-------|---------|------------|
| `food_logging_started` | Quick log open / manual create path | `method`, `source` |
| `food_logging_completed` | After successful `modelContext.save()` | `method`, `source` |
| `food_logging_cancelled` | User exits started flow before save | `method`, `source` |
| `food_logging_failed` | Invalid input / save failure | `method`, `source`, `reason` |

Methods: `manual`, `recent`, `barcode`, `meal_builder`, `quick_log`, `other`.  
Sources: `today`, `meals`, `coach`, `quick_log`, `plan`, `other`.

**Completion:** only after persistence succeeds.  
**Cancel (wired):**
- Today food quick-log sheet dismiss (`ProductAnalytics.foodLoggingCancelIfNeeded`)
- Meals creation sheet dismiss after `manual` start without save

Tracked via `ProductAnalyticsFlowTracker` — cancel is skipped after completed/failed and never duplicated.

---

## Meal Builder

| Event | Trigger | Parameters |
|-------|---------|------------|
| `meal_builder_started` | Chooser selects builder | `mode`, `source` |
| `meal_builder_completed` | `onSave` after build | `mode`, `source` |
| `meal_builder_cancelled` | Back without save | `mode`, `source` |
| `meal_builder_failed` | Persist failure when surfaced | `mode`, `source`, `reason` |

`mode`: `new` \| `edit`.

**Note:** Cancel is wired on the explicit back button. Swipe-dismiss of the creation sheet without pressing back does **not** reliably emit `meal_builder_cancelled` today (intentionally not manufactured).

---

## Barcode (photo → Vision → lookup)

| Event | Trigger | Parameters |
|-------|---------|------------|
| `barcode_scan_started` | Camera opens for capture | `source` |
| `barcode_scan_succeeded` | Product lookup usable | `source` |
| `barcode_scan_failed` | Not recognized / not found / network / camera | `source`, `reason` |
| `barcode_scan_cancelled` | Camera cancel | `source` |

**Success:** product result found so the form can proceed — not mere camera shutter.  
Never send barcode digits or product names.

---

## Hydration

| Event | Trigger | Parameters |
|-------|---------|------------|
| `hydration_logging_started` | Drink quick-log open | `method`, `source` |
| `hydration_logging_completed` | After successful save | `method`, `source` |
| `hydration_logging_cancelled` | Exit before save | `method`, `source` |
| `hydration_logging_failed` | Save failure | `method`, `source`, `reason` |

**Cancel (wired):** Today drink quick-log sheet dismiss via `hydrationLoggingCancelIfNeeded`.

---

## Activity (user-initiated only)

| Event | Trigger | Meaning |
|-------|---------|---------|
| `activity_logging_started` | Today Start Activity **sheet** opens | Sheet / chooser funnel start — not a live session |
| `activity_started` | Live session **persisted** | User actually began a trackable session |
| `activity_completed` | Live stop or plan/notification complete | Session finished |
| `activity_cancelled` | Start Activity sheet dismissed before start/complete/fail | Sheet abandon |
| `activity_logging_failed` | Save failure on start | Persistence error |

**Cancel (wired):** Today workout sheet dismiss before `activity_started` / `activity_completed` / `activity_logging_failed`.

**Omitted:** HealthKit import / reconcile paths.

---

## Plan

| Event | Trigger | Parameters |
|-------|---------|------------|
| `plan_item_creation_started` | Add sheet opens | `item_type` |
| `plan_item_created` | Create save succeeds | `item_type` |
| `plan_item_edit_started` | Edit sheet opens | `item_type` |
| `plan_item_updated` | Edit save succeeds | `item_type` |
| `plan_item_completed` | User marks complete | `item_type` |
| `plan_item_deleted` | Delete succeeds | `item_type` |

`item_type`: `activity` \| `meal` \| `hydration` \| `recovery` \| `habit` \| `other`.  
No titles, notes, dates, or times.

---

## Settings

| Event | Trigger | Parameters |
|-------|---------|------------|
| `health_settings_opened` | Health row / open Apple Health | — |
| `notification_settings_opened` | Notifications row | — |
| `language_changed` | Language selected | `language` = `en` \| `ru` \| `other` |
| `data_reset_started` | Reset begins | — |
| `data_reset_completed` | Reset succeeds | — |

Data reset clears onboarding analytics keys (via `LocalDataResetService`) and resets screen dedupe. It does **not** emit a new `onboarding_started` until onboarding is presented again.

---

## Notifications

| Event | Trigger | Parameters |
|-------|---------|------------|
| `notification_opened` | User taps / acts on activity notification | `category` (currently `activity`) |

Delivery is not counted. Titles/bodies are never sent.

---

## Review funnel

Bridged: `ReviewAnalytics` → `AppAnalytics` (Firebase in production). Same event names as `AnalyticsEvent`.

| Event | Trigger | Parameters (bounded) |
|-------|---------|----------------------|
| `review_eligibility_reached` | First time soft-prompt eligibility is true | `app_version`, `trigger_source`, eligibility **buckets** |
| `review_feedback_sheet_shown` | Sentiment sheet presented | same |
| `review_feedback_selected` | User picks sentiment | `feedback_sentiment`, `trigger_source`, `app_version` |
| `native_review_request_attempted` | `SKStoreReviewController` requested | `surface` = `soft_prompt` \| `settings_in_app`, `trigger_source` |
| `feedback_form_opened` | Feedback form presented | `feedback_intent`, `feedback_sentiment`, … |
| `feedback_submitted` | Feedback handoff succeeds (e.g. mailto flow) | `feedback_category`, sentiment — **never message body** |
| `feedback_dismissed` | Sheet dismissed without submit | `trigger_source` |
| `rate_weekfit_selected_from_settings` | Settings Rate WeekFit | `trigger_source` |

**Limitation:** There is **no** `review_submitted` / App Store review completion event.
iOS does not confirm whether the user submitted a rating after `native_review_request_attempted`.

Eligibility counters are sent as coarse buckets (`0_2`, `3_4`, `5_plus`), never exact dates or raw high-cardinality integers.

DEBUG-only OSLog for review events; production does not spam.

---

## Intentionally unwired / reserved

| Item | Reason |
|------|--------|
| `app_opened` | Firebase auto sessions / `first_open` — do not double-count |
| Coach action tapped/completed/dismissed | No reliable product UI handlers |
| Insights / Highlights screens & events | Unshipped |
| `meal_builder_cancelled` on swipe-dismiss | Lifecycle unreliable vs explicit back |
| `food_logging_started` for every “recent” log | Recent path completes without a sheet start today |
| Fake `review_submitted` | Impossible to know on iOS |

---

## Suggested Firebase / GA4 reports

### Primary feature adoption
Unique users with screen views: `today`, `coach`, `meals`, `plan`, `settings`.

### Coach engagement
`coach_recommendation_viewed` segmented by `category`.

### Food funnel
`food_logging_started` → `food_logging_completed` \| `food_logging_cancelled` \| `food_logging_failed`.

### Barcode funnel
`barcode_scan_started` → `barcode_scan_succeeded` → `food_logging_completed` (`method=barcode`).

### Meal Builder funnel
`meal_builder_started` → `meal_builder_completed`.

### Hydration funnel
`hydration_logging_started` → `hydration_logging_completed` \| `cancelled` \| `failed`.

### Activity sheet → live session
`activity_logging_started` → `activity_started` → `activity_completed` (or `activity_cancelled` from sheet).

### Review funnel
`review_eligibility_reached` → `review_feedback_sheet_shown` → (`native_review_request_attempted` \| `feedback_form_opened`).

### Plan adoption
Users with ≥1 `plan_item_created` and later `plan_item_completed`.

### Retention cohorts (anonymous)
Compare retention for users who:
- Opened Coach (`coach` screen or `coach_recommendation_viewed`)
- Completed food log
- Completed hydration log
- Created a plan item

Do **not** cohort on health state, scores, or medical inferences.

---

## Architecture notes

- Mapping layer: `AnalyticsEvent`, `AnalyticsScreen`, `AnalyticsParameters`, `ProductAnalytics`,
  `ProductAnalyticsFlowTracker`, `OnboardingFunnelAnalytics`, `ReviewAnalytics`.
- Backend: `FirebaseAnalyticsService` (DEBUG logs + Firebase) or `LoggingAnalyticsService`.
- Tests: `RecordingAnalyticsService` — no network dependency.
- Firebase init order: `FirebaseBootstrap.configureIfNeeded()` before `AnalyticsBootstrap`; never probe `FirebaseApp.app()` before configure.
