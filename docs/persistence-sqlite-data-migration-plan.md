# WeekFit local-first + private iCloud recovery

**Status:** planning only — no implementation started from this document.  
**Goal:** Move persistence from SwiftData/`UserDefaults` to SQLiteData with private CloudKit recovery, without accidental data loss and with hard-delete semantics for Delete Account.

---

## 1. Current state (verified in repo)

### Persistence today

| Concern | Mechanism | Path |
|---|---|---|
| Plan + food/drink logs + workouts | Single SwiftData `@Model` `PlannedActivity` | `Packages/WeekFitPlanner/Sources/WeekFitPlanner/PlannedActivity.swift` |
| Store | Application Support `default.store` (**no CloudKit**) | `WeekFit/App/WeekFitModelContainer.swift` |
| Custom meals catalog | UserDefaults JSON `weekfit_custom_meals_v1` | `WeekFit/Features/Meals/CustomMealStore.swift` |
| Meal photos | Files under `Application Support/WeekFit/MealPhotos/` | `MealPhotoStore` in same file |
| Custom ingredients | Key reserved; almost unused in production | `weekfit_custom_ingredients_v1` |
| Profile / prefs / coach state | UserDefaults domain `com.weekfit.app` | `WeekFitUserSettings`, coach `*.v1` keys |
| Auth session | UserDefaults `weekfit.auth.appleUserID` | `AuthSessionStore` |
| Apple name/email durability | Keychain + disk (**survives domain wipe**) | `AppleIdentityStore` |

**Only one `@Model`.** Roughly **180 Swift files** reference `PlannedActivity`. Classification is string heuristics on `type` / `source` / `imageName` (`timelineEventKind`).

**CloudKit:** none. `WeekFit/WeekFit.entitlements` has Sign in with Apple, WeatherKit, HealthKit only. Privacy copy still says no cloud sync (`docs/privacy.html`, `web/public/privacy.html`).

### Catch-all problem

The same row is both “planned intention” and “consumed log”:

- Future planner meal → `source: planner`, `isCompleted: false`
- Quick log → `source: today`, `isCompleted: true` (`QuickLogActivitySync`)
- Meals library log → `source: nutritionLog`
- HK import → `type: workout`, `source: appleWorkout`, `healthKitWorkoutUUID`

### Delete / sign-out / workspace isolation (release)

**Principle:** Data belongs to the workspace where it was created. No implicit share/migration between Local and Apple.

| Action | Behavior |
|---|---|
| **Sign out** | Clears SIWA session → welcome. **Does not wipe** yet. Owner marker stays `apple:<id>` so the same Apple ID can return. |
| **Sign Out → Sign in same Apple A** | Owner matches → **keep** Apple A data on the shared store. |
| **Sign Out → Open WeekFit (Local)** | Destructive: wipe Apple A from the shared store → clean Local. **Confirmation required.** |
| **Local → Sign in Apple A** | Destructive: wipe Local → clean Apple A. **Confirmation required.** |
| **Apple A → Apple B** | Wipe A → clean B. |
| **Delete account** | Full wipe + identity clear → welcome. |
| **Reset local data** | Wipe **current** workspace only; auth/entry unchanged. |

#### Architecture evaluation (single SQLite)

WeekFit still has **one** on-disk production store (`Application Support/default.store`) plus one UserDefaults domain. There is no per-identity database.

| Requirement | Single-DB today | Long-term |
|---|---|---|
| Local ≠ Apple | Wipe on switch | Separate Local DB / owner partition |
| Apple A ≠ Apple B | Wipe on switch | Separate Apple-scoped DB or encrypted partition |
| Apple A → Sign Out → Apple A | Keep via owner marker (no Open WeekFit in between) | Keep without destroying sibling workspaces |
| Keep Local **and** Apple A on device | **Not possible** | Per-workspace storage |

**Release limitation (explicit):** Isolating workspaces currently means **destroying** the previous workspace when opening another. After Sign Out, choosing Open WeekFit permanently removes Apple A data from this device; signing back into Apple A then starts empty. The only way to keep Apple A data across Sign Out is to Sign in with the **same** Apple ID from welcome without opening Local first.

**Long-term:** per-workspace ownership/storage for Local / Apple A / Apple B without wipe-on-switch (see §2 target architecture).

### Major write sites (must all move)

- Planner: `PlanViewModel`, `WeekPlanerView`, confirmation/skip services
- Today / quick log: `PremiumActivityStartSheet`, `QuickLogActivitySync`
- Meals: `MealsView`, `MealDetailsView`, `NutritionViewModel`
- Coach: `CoachPlanApplyService`
- HealthKit: `WeekFitActivityCoordinator` / `ActivityReconciler`
- Review demo: `AppReviewDemoPlannedActivitySeeder`
- Wipe: `LocalDataResetService`, `AccountDeletionService`

---

## 2. Target architecture

```text
UI (Today / Plan / Meals / Coach)
        │
        ▼
WeekFitPersistence repositories
        │
        ├── SQLiteData local DB  ←── SyncEngine ──→  private CloudKit zone "WeekFit.private"
        └── MealPhoto file cache (hydrated from synced Data/CKAsset)
        
Sign in with Apple  →  app session only (does NOT own CloudKit ACL)
iCloud account      →  private CloudKit recovery identity
```

### Identity separation (committed)

- **SIWA** = WeekFit app session / profile display. Does **not** own CloudKit access.
- **iCloud account** = private CloudKit database / SyncEngine. Recovery is tied to this.
- **Do not** stamp `appleUserID` on every row. CloudKit already scopes the private DB to the iCloud user.
- Local `AppMeta` holds schema/migration/sync flags only.

| SIWA | iCloud | Expected behavior |
|---|---|---|
| Signed in | Available | Normal local-first + sync |
| Signed in | Unavailable / disabled | Local-only; banner; no false “restored” claims |
| Signed out | Available | Local DB kept; cloud untouched; next SIWA login sees same device data |
| Same SIWA, iCloud changed | Treat as new cloud identity; **do not** upload prior user’s history without explicit confirm |
| iCloud same, SIWA revoked | Local+cloud history remain; block app until SIWA restored or Delete Account |

### Tables (SQLiteData `@Table`)

#### `PlanItem` — intention / schedule

- `id` UUID text (preserve legacy `PlannedActivity.id` where possible)
- `scheduledAt`, `type` (workout / meal / drink / recovery / habit / …)
- `title`, `durationMinutes`, `actualDurationMinutes?`
- `icon`, `imageName`, color RGB
- `status`: planned | active | completed | skipped
- `source`: planner | today | coach | appleWorkout | reviewDemo | …
- `healthKitWorkoutUUID?` — opaque local reconcile link only; never raw HK samples
- macros optional (planned meal targets)
- `catalogMealId?`
- `updatedAt`

#### `FoodLog` — actual consumption

- `id` UUID
- `loggedAt`
- `kind`: meal | snack | drink
- title, imageName, icon, color
- quantity/portion encoding (migrate from quick-log `durationMinutes` encoding)
- calories / protein / carbs / fats / fiber
- `source`: today | nutritionLog | plannerCompletion | …
- `planItemId?` — set when completing a planned meal/drink
- `catalogMealId?`
- `updatedAt`

#### `CustomMeal` / `CustomIngredient`

Move catalog out of UserDefaults. Mirror fields from `Meals` / `MealBuilderIngredient` that production uses.

#### `MealPhoto`

Separate table (`mealId`, `kind` original|thumb, `bytes` as `Data?`) so list queries stay lean. SyncEngine maps blobs → **CKAsset**. Keep on-disk cache for UI; hydrate files after restore.

#### `AppMeta`

- `schemaVersion`, `legacyMigrationState`, `legacyMigrationAttemptId`
- `cloudDeletionState`: none | pending | verified
- `lastSuccessfulSyncAt?`
- `didSeedDefaultLibrary`
- **`syncUploadArmed`** — gate CloudKit upload until migration validated

#### Out of initial sync scope (local until later)

Coach observation/proposal/journal UserDefaults, review-prompt counters, analytics funnels, HK sync cursors / dismissed UUIDs, barcode cache, Firebase identity.

### Photo strategy (committed)

1. Local file cache remains for display.
2. Synced copy = compressed JPEG `Data` in `MealPhoto` → SyncEngine → CKAsset (library-supported).
3. Restore: download assets → rewrite local files.
4. Deleting CustomMeal deletes photo rows → cloud tombstones.
5. Never store multi‑MB originals on PlanItem/FoodLog rows.

### Sync topology

- SPM: [pointfreeco/sqlite-data](https://github.com/pointfreeco/sqlite-data)
- Entitlement: iCloud + CloudKit container (e.g. `iCloud.app.weekfit`)
- Private zone name: **`WeekFit.private`**
- Tables registered with `SyncEngine`
- **`syncUploadArmed = false` until migration validation passes**
- CKShare / sharing: out of scope

### HealthKit boundary

| Allowed in CloudKit | Forbidden |
|---|---|
| WeekFit `PlanItem` / `FoodLog` rows the app already stores | Raw HK samples (HR, sleep, steps series, workout binaries) |
| Opaque `healthKitWorkoutUUID` for reconcile | Shipping HK query payloads into SQLite “for sync” |

Update privacy policy **before** enabling SyncEngine.

---

## 3. Critical deletion semantics

| User action | Local SQLite | Photo files | Private CloudKit | SIWA session |
|---|---|---|---|---|
| Uninstall app | Gone | Gone | **Survives** | n/a |
| Reinstall + iCloud available | Empty → SyncEngine pull | Hydrate from assets | Source of truth | Sign in again for app |
| Sign out | **Keep** | Keep | **Keep** | Cleared |
| Reset this device (if offered) | Wipe | Wipe | **Keep** | Unchanged |
| **Delete Account & All Data** | Wipe **after** cloud success | Wipe **after** cloud success | **Permanently delete** | Cleared + clear AppleIdentity |

### Hard-delete algorithm (fail closed)

Avoid: local wiped → cloud failed → reinstall restores “deleted” data.

1. Persist `cloudDeletionState = pending` in **durable storage outside the DB** (Application Support tombstone file + Keychain flag).
2. Stop writes / UI editing.
3. Delete all synced rows (SyncEngine tombstones) **and/or** `deleteRecordZone(WeekFit.private)`.
4. `await syncEngine.sendChanges()` (and/or confirm zone gone).
5. **Only on success** → erase SQLite + metadatabase + photos + UserDefaults domain + SIWA + AppleIdentity.
6. Clear `pending` flag.
7. On launch, if `pending`: **do not restore from cloud**; retry wipe first.

Rename CTA to **Delete Account & All Data** with multi-step destructive confirmation. Distinguish from Reset this device.

Remote `DELETE /v1/account` remains optional until a real backend exists; CloudKit wipe is the real remote step.

### Restore UX

- Default: SyncEngine auto-reconstructs local store after reinstall when iCloud is available. Show non-blocking “Restoring from iCloud…”.
- Delay `DefaultMealLibrarySeeder` until cloud is confirmed empty (avoid uploading a fresh seed that fights restored catalog).
- **Do not** offer a “Start Fresh” that silently destroys cloud. “Use without iCloud” = local-only, sync off. Destroying cloud is only via Delete Account & All Data.

---

## 4. Migration requirements

Legacy sources:

- SwiftData `PlannedActivity`
- UserDefaults custom meals (+ reserved ingredients)
- Meal photo files

Classifier (committed starting point):

```text
if timeline kind in {food, drink} AND (isCompleted OR source in {today, nutritionLog, foodLog}):
  → FoodLog
  → also PlanItem if it originated as planner (status completed, FoodLog.planItemId = id)
else:
  → PlanItem (status from isCompleted / isSkipped)
```

Requirements:

1. Detect legacy data  
2. Create SQLiteData store  
3. Migrate records with preserved ids  
4. Validate counts / calorie invariants  
5. Retire legacy only after `verified`  
6. Idempotent resume  
7. No Cloud upload until `syncUploadArmed`  
8. AppMeta migration version/state  
9. Rollback = keep SwiftData until verified; do not delete legacy early  

---

## 5. Phases

### Phase 0 — Inventory, fixtures, privacy prep

- Golden fixtures / count classifiers for PlanItem-like vs FoodLog-like rows
- Write-site map locked in tests
- Draft privacy + App Store disclosures (ship before SyncEngine)
- In-memory migrator unit tests

### Phase 1 — SQLiteData local-only

- Add SPM dependency
- New module `WeekFitPersistence`: schema v1 + GRDB migrations
- Bootstrap `DatabaseQueue` **beside** SwiftData (SwiftData still source of truth)
- No SyncEngine, no entitlements yet

### Phase 2 — Dual-write + migrator

- Repositories for PlanItem / FoodLog / CustomMeal / MealPhoto
- Idempotent `LegacySwiftDataMigrator`
- Validation gates; **`syncUploadArmed = false`**

### Phase 3 — Switch reads

- Replace `@Query PlannedActivity` with `@FetchAll` / repository observation in Today, Plan, Meals, Root, Insights
- Fallback to SwiftData if migration not `verified`

### Phase 4 — Write cutover

- All writes SQLite-only
- SwiftData becomes archive until Phase 7
- Review-demo uses isolated SQLite store (never user CloudKit)

### Phase 5 — CloudKit SyncEngine

- Entitlements + container + zone `WeekFit.private`
- Start SyncEngine only when migration verified + armed + iCloud available
- Reinstall restore + iCloud edge cases + SyncEngineDelegate account change handling

### Phase 6 — Hard-delete CloudKit

- Pending-wipe state machine in `AccountDeletionService`
- Settings UX split: Sign out | Reset this device | Delete Account & All Data
- Clear AppleIdentity on hard delete (gap today)
- Launch retry if pending

### Phase 7 — Remove legacy

- Remove SwiftData `PlannedActivity` production usage / container
- Remove UserDefaults meal catalog keys
- Shrink `LocalDataResetService`

---

## 6. Risk matrix

| Risk | Mitigation |
|---|---|
| Migration loses meals/plans | Idempotent upsert by legacy id; count/macro invariants; keep SwiftData until verified; no upload until armed |
| Interrupted migration | AppMeta state machine; resume; never delete legacy early |
| Partial upload corrupts cloud | `syncUploadArmed` gate |
| Deleted data reappears | Cloud wipe **before** local wipe; durable pending flag; block restore while pending |
| Duplicates | Deterministic classification; UUID PKs; HK reconcile by workout UUID |
| Photo orphans | MealPhoto cascade; wipe clears files; restore rehydrates |
| SIWA ↔ iCloud mismatch | Separate identities; banners; no per-row SIWA ACL |
| SyncEngine local wipe on iCloud logout | Custom delegate; distinguish temporary unavailable vs full sign-out |
| Second-device conflicts | UUID PKs; delay default meal seed until cloud empty |
| Quota / asset failures | Soft-fail photos; don’t complete account deletion if zone/assets remain |
| HK over-sync | Field allowlist; review checklist |
| Privacy / App Review | Update policy + ASC before enabling CloudKit |

---

## 7. Test matrix (minimum)

| Case | Expect |
|---|---|
| Existing user upgrade | Legacy counts == new; SwiftData retained until verified |
| Clean install, no iCloud | Empty local; works |
| Clean install + empty iCloud | Empty; seed library once after cloud-empty confirm |
| Uninstall/reinstall + iCloud data | Auto restore plans/meals/photos |
| Offline reinstall | Empty until network; then restore |
| Second device | Convergence without dupes |
| iCloud disabled | Local works; clear messaging |
| Sign out / sign in | Local + cloud intact |
| Reset this device | Local empty; cloud intact; later restore works |
| Delete Account success | Local + cloud empty; reinstall stays empty |
| Delete Account fail mid-cloud | Local preserved **or** pending blocks restore; retry |
| Kill mid-migration | Resume; no upload |
| Kill mid-initial sync | Resume; no dupes |
| Meal photo restore | Files + relationships intact |
| Custom meals migration | Catalog + photos match |
| Planned meal completed | PlanItem completed + FoodLog.`planItemId` |
| Quick-log only | FoodLog (no orphan plan) |
| HK imported workout | PlanItem with UUID link; no raw samples |
| Review demo | Isolated; never sync into user CloudKit |

---

## 8. Recommended implementation sequence

**Start with Phase 0 + Phase 1 (local SQLiteData + migrator tests). Do not enable CloudKit first.**

Why:

1. CloudKit permanently amplifies migration mistakes across devices.
2. ~180 `PlannedActivity` call sites need a repository boundary before SyncEngine.
3. Entitlements / privacy / App Review are product commitments — land after local migration is proven.
4. Hard-delete correctness depends on a stable synced schema and tombstones.

**Order:** Phase 0 → 1 → 2 → 3 → 4 → **5 SyncEngine** → 6 hard-delete → 7 legacy removal.

### First engineering milestone

Create `WeekFitPersistence` with `PlanItem` / `FoodLog` / `CustomMeal` / `MealPhoto` / `AppMeta`, an idempotent `LegacySwiftDataMigrator` covered by tests, and keep the shipping app on SwiftData until migrator reports `verified` in QA builds.
