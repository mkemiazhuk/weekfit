# Weekly context for evening Coach (prompt v8)

The recap should explain one useful connection in the user's recent history, with one proportionate next step. It should not simply narrate the visible daily dashboard.

## Data and compatibility

The iOS generation service enriches the request inside the existing single flight, before HTTP. It queries seven recent local wake-days and a **disjoint preceding 28-day baseline**, using existing read access without requesting authorization. A day-by-day query preserves calendar boundaries across DST. Sleep parsing reuses the Recovery screen's primary-session/source handling. No raw HealthKit samples, workout UUIDs, food text changes or credentials are added. Review Demo skips enrichment so synthetic and real health data cannot mix.

Additional optional fact groups: `recentSleep`, `recentVitals`, `recentActivity`, `baseline`, `recentFeeling`, `recentRecaps`. `schemaVersion` stays 1; response structure stays unchanged. Each group is bounded to 20 facts, each text to 500 characters; HTTP body is bounded to 64 KiB. Existing clients remain accepted by v8 but cannot provide a weekly pattern until updated. Deploy server first: the old server rejects unknown groups from the new client.

Sleep facts use wake-day, actual sleep start/wake instants, duration/awake minutes and available estimated stages. HRV is SDNN; vitals include overnight-window medians, sample counts and latest measurement timestamps. RHR is explicitly distinct from sleeping pulse. Calendar-day active energy and Apple Exercise totals are nullable; today's total is marked incomplete. Full calendar intervals do not establish full watch wear. Sessions include available recorded type, start/end and duration, without inventing intensity. Only the 12 most recent sessions are transmitted; no workout-frequency claims should be made if this bounded list is incomplete.

Baselines contain medians, ranges and observed-day counts, without recovery scores or invented thresholds. At least seven observed reference days are required for a median. Bedtime uses local minutes after noon, avoiding midnight averaging errors. Missing history remains unknown. Feeling check-ins are subjective, and the last cached recap is supplied only to reduce repetition, not as evidence.

## Reasoning requirements

- Pair prior-day activity with the following sleep/physiology, never today's exercise with earlier morning recovery.
- Distinguish observations from repeated associations. Repeated-pattern language requires at least three comparable exposure/outcome pairs, two comparison pairs and consideration of exceptions. These are conservative product rules, not clinical validation thresholds.
- Cite dated supporting facts on both sides of a connection. No causal or diagnostic assertions.
- Do not infer poor recovery from one estimated sleep stage, or good recovery from duration alone.
- Partial food logging does not imply inadequate whole-day intake. Missing records do not mean inactivity.
- If there is no defensible insight, give a brief calm conclusion rather than inventing a problem or a food logging task.

The LLM is responsible for interpreting these facts. Deterministic tests verify transport, bounds and evidence IDs, **not clinical validity or model adherence**. No real OpenAI requests were made for implementation testing.

## Illustrative review cases (not measured model outputs)

| Input | Expected behavior |
|---|---|
| One late workout followed by shorter sleep | Describe a single observation; do not claim a pattern |
| Repeated late workouts and later sleep, with comparable earlier-training days | Tentative association; suggest trying an earlier finish, without claiming causation |
| Two active days, quieter partial current day | Explain accumulated context; no instruction to catch up |
| Long sleep, higher RHR and lower HRV versus adequate personal reference | Explain mixed signals, with uncertainty; do not promise readiness |
| Bedtime drift across midnight | Interpret local dates/times correctly |
| Sparse or denied history | No fabricated baseline, zero values or hidden pattern |
| No meaningful deviations | Brief neutral conclusion, no forced intervention |

## Validation and release

All backend tests run against local mocks. XCTest coverage is added for disjoint windows across Warsaw DST, missing values and evidence bounds. This environment has no Xcode/Swift; the iOS build and XCTest execution must be completed on macOS before merge/release. Also measure HealthKit enrichment latency on a physical device: 35 daily query sets are performed once per generation flight; the UI timeout may expire while work continues, per existing coordinator policy.

Manual checks: seven historical days arrive with correct local dates; permission-denied queries stay unknown; evidence IDs accepted after enrichment; Root/Coach still join one flight; existing same-day cache is reused without extra provider calls; workspace changes never apply a former user's result.

No automatic cache invalidation or new paid request is introduced. A successful same-day recap remains cached until the next eligible day. Server deployment alone improves writing for old clients; weekly analysis requires the new iOS build. Do not deploy the iOS change before prompt v8 is live.
