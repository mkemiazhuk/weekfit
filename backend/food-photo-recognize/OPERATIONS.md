# Single-node WeekFit operations

This deployment is one Render instance with a persistent `/var/data` mount.
Do not add a second instance, delete safety ledgers, or raise AI limits in response
to an alert. Multi-instance support requires a separate shared-ledger design.

## Signals

The API logs `runtime_metrics` once a minute, non-overlapping, and `/healthz`
exposes its last sample under `monitoring`. A null sample or a timestamp older
than five minutes means missing telemetry, not zero resource use. Sampling never
calls AI or changes quotas. Shutdown stops the timer and event-loop histogram.

- `diskUsedRatio`: filesystem utilization at DATA_DIR from statfs, including
  filesystem overhead; not a claim that fsync proves a persistent mount.
- `containerMemoryBytes` and `containerMemoryLimitBytes`: cgroup readings for API
  and worker together. Unsupported cgroup files produce null. `processRssBytes`
  is only the API process, not total service memory.
- CPU is taken from Render service metrics divided by the matching instance's
  `cpu_limit`. Do not add metrics from old and replacement instances.
- `asyncQueueDepth`, upload/processing gates, event-loop p95, uptime, API ready
  waiters. The separate worker logs `worker_metrics` with its own waiter count
  and in-flight work; these are distinct processes.
- Coach and photo UTC-day **reservation** counts and used ratios. These can
  exceed provider starts (e.g. a reserved attempt failed before sending). They
  are not bills. Missing/corrupt/inaccessible storage is reported as unavailable.

`runtime_alert` thresholds: disk warning 70%, critical 85%; memory 80%; more than
16 waiting queue listeners; quota reservations 80%; event-loop p95 above 200ms.
CPU >80% of instance limit for 10 minutes is an external monitoring condition.
Use trends for RAM/queue growth and distinguish deliberate deploys from crashes.

No high-cardinality UID labels, images, notes, health facts, prompts, responses,
authorization headers, or keys are included in these new events.

## AI calls, results, tokens and cost

`ai_transport` has a generated `callId`, endpoint, model and mock flag. Count only
`phase=started` by distinct callId with `mock=false` as real provider attempts.
Do not sum started + finished. `finished` means HTTP/JSON transport succeeded,
not that the answer passed validation or was saved. Coach `provider_call_finished`
and photo completion/failure events describe application outcomes.

Token fields are allowlisted numeric input/cached-input/output values. Sum once
per finished callId. Null means unknown (including network failures which may
still be billed). A restart does not regenerate a result or make an unknown
attempt free to retry. Existing ledgers remain authoritative for prevention.

The daily report must not call reservation counts or fixed per-call estimates
actual cost. Reconcile token totals per model against current OpenAI prices,
cached-input pricing and the OpenAI billing dashboard. Unavailable usage is
reported explicitly. Provider/photo and Coach budgets remain separate. Existing
photo `MAX_ESTIMATED_USD_PER_DAY` is a soft fixed-per-call estimate, not verified
account billing or a unified Coach+food dollar cap.

Current declared limits: 100 Coach starts/UTC day, 10/minute, 2 concurrent;
200 photo daily reservations, 200 photo provider calls/day, 20 scans/user/day,
16 global photo AI slots. 100 daily users can consume all Coach capacity and two
photos each exhaust the global photo quota. Do not change these limits without
explicit capacity/spending approval. A rejected Coach burst is expected with
these limits; it is not a promise to serve 100 simultaneous generations.

## Storage lifecycle

Successful photos are deleted immediately when DELETE_PHOTO_ON_COMPLETE=1.
Once a minute the worker removes expired photo .jpg and abandoned .tmp files
(PHOTO_TTL_MS, default 24h); photos referenced by queued/processing file jobs
are protected. A corrupt job aborts photo cleanup. No symlinks are followed.
Terminal expired job/result files are removed from both legacy flat and owner
subdirectories (JOB_TTL_MS, default 24h). Cleanup does not overlap itself, and
errors log `storage_cleanup_failed` rather than silently disappearing.

Never automatically delete `coach-summary/coach-guard`, `photo-calls`, `quota`,
or `idempotency`: these prevent duplicate provider calls, and quotas reconstruct
markers from reservations. They grow over time. Track disk growth, enlarge the
disk before 85%, and design safe archival/tombstones before pruning them. Do not
restore an old safety journal just to make a failed attempt eligible again.

Render daily disk snapshots are disaster recovery, not a tested application
backup. Document and test a consistent SQLite/file backup and recovery procedure
separately before using restore on production. No automatic restores are added.

## Checks and notifications

`npm test` includes 240 idle queue timeouts (listeners return to zero), cleanup
isolation, protected active photos and symlinks, telemetry redaction and quotas.

`node scripts/capacity-mock-check.mjs` uses only synthetic data and mock adapters:
100 daily photo users in waves, 100 simultaneous food submissions, 100 simultaneous
Coach submissions, replay of successful Coach attempts. It keeps the declared
production admission limits, reports shedding, bounds provider concurrency and
asserts accepted jobs complete. All external fetches are blocked. CI runs it in
the built Docker image with `--network none`. It is not a production load test or
proof of real OpenAI RPM/TPM, latency, billing or capacity on a 0.5 CPU/512MiB host.

A ChatGPT hourly read-only check reports new problems/recovery and gives an
08:15 Europe/Warsaw daily summary. This is hourly polling, not an immediate
pager or guaranteed SLA. It never calls a generation endpoint or changes Render.
Use an independent uptime/error alerting service if minute-level paging is needed.

Render references: https://render.com/docs/disks and
https://render.com/docs/service-metrics . Disk utilization is also in Dashboard
> service > Disk. Review CPU/RAM graphs and unexpected restart/deploy events.
