#!/bin/sh
# Exercises the built image. Does not push it and does not call a deploy hook.
# OPENAI_MOCK stays forbidden when NODE_ENV=production. The mock server below
# overrides NODE_ENV to development only for the functional checks.
set -eu

IMAGE=${1:?image tag}
TOKEN=weekfit-ci-container-token
ONE=11111111-1111-4111-8111-111111111111
SHARED=22222222-2222-4222-8222-222222222222
PORT=18080
NAME=weekfit-photo-ci
VOL=weekfit-photo-ci-data
BASE="http://127.0.0.1:${PORT}"

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker volume rm "$VOL" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

echo "== production boot with OPENAI_MOCK is refused =="
set +e
timeout 30 docker run --rm --network none \
  -e NODE_ENV=production \
  -e OPENAI_MOCK=1 \
  -e ALLOW_DEV_AUTH=0 \
  "$IMAGE" >/tmp/weekfit-mock-ban.log 2>&1
ban_code=$?
set -e
if [ "$ban_code" -eq 0 ]; then
  echo "production process started with OPENAI_MOCK=1" >&2
  cat /tmp/weekfit-mock-ban.log >&2
  exit 1
fi
grep -q "OPENAI_MOCK is forbidden in production" /tmp/weekfit-mock-ban.log
echo "boot refusal exit ${ban_code}"

echo "== production without a persistent directory does not call a provider =="
timeout 60 docker run --rm --network none --entrypoint node "$IMAGE" image-runtime-check.mjs production-no-dir

echo "== mock server with an explicit data volume =="
docker volume create "$VOL" >/dev/null
docker run --rm --user root --entrypoint sh -v "$VOL:/var/data" "$IMAGE" \
  -c 'mkdir -p /var/data && chown -R node:node /var/data'

start_mock() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run -d --name "$NAME" \
    -p "${PORT}:8080" \
    -v "$VOL:/var/data" \
    -e NODE_ENV=development \
    -e OPENAI_MOCK=1 \
    -e ALLOW_DEV_AUTH=1 \
    -e WEEKFIT_DEV_TOKEN="$TOKEN" \
    -e DATA_DIR=/var/data \
    -e ALLOW_SINGLE_NODE_ASYNC=1 \
    -e STATE_BACKEND=file \
    -e OBJECT_STORE=local \
    -e FOOD_PHOTO_MOCK_DELAY_MS=400 \
    -e COACH_AI_ENABLED=0 \
    "$IMAGE" >/dev/null
}

wait_health() {
  i=0
  while [ "$i" -lt 40 ]; do
    if curl -fsS "${BASE}/healthz" >/tmp/weekfit-health.json; then
      return 0
    fi
    i=$((i + 1))
    sleep 0.5
  done
  docker logs "$NAME" >&2 || true
  echo "healthz did not become ready" >&2
  exit 1
}

python3 - <<'PY'
import json, base64
jpeg = bytes([255, 216, 255, 192, 0, 17, 8, 0, 100, 0, 100, 3, 1, 17, 0, 2, 17, 0, 3, 17, 0, 255, 217])
with open("/tmp/weekfit-body.json", "w") as handle:
    json.dump({
        "imageBase64": base64.b64encode(jpeg).decode("ascii"),
        "mimeType": "image/jpeg",
        "locale": "en_US",
    }, handle)
PY

post() {
  user_token=$1
  analysis=$2
  out=$3
  curl -sS -o "${out}.json" -D "${out}.headers" -w "%{http_code}" \
    -H "Authorization: Bearer ${user_token}" \
    -H "X-WeekFit-Subscription-JWS: weekfit-dev-local-subscription" \
    -H "Content-Type: application/json" \
    -H "Idempotency-Key: ${analysis}" \
    --data @/tmp/weekfit-body.json \
    "${BASE}/v1/food/photo-recognize" > "${out}.status"
}

expect_calls() {
  python3 - "$1" <<'PY'
import json, sys
want = int(sys.argv[1])
health = json.load(open("/tmp/weekfit-health.json"))
metrics = health.get("mockMetrics") or {}
assert health.get("ok") is True, health
assert health.get("openAIMock") is True, health
assert health.get("persistentDataDir") is True, health
assert metrics.get("realFetchAttempts") == 0, metrics
assert metrics.get("calls") == want, metrics
print(f"mock calls={metrics['calls']} realFetchAttempts=0")
PY
}

start_mock
wait_health
expect_calls 0

echo "== one user, parallel and repeated =="
for n in 1 2 3 4; do
  post "$TOKEN" "$ONE" "/tmp/weekfit-par-${n}" &
done
wait
post "$TOKEN" "$ONE" /tmp/weekfit-repeat
for n in 1 2 3 4; do
  test "$(cat /tmp/weekfit-par-${n}.status)" = "200"
done
test "$(cat /tmp/weekfit-repeat.status)" = "200"
python3 - <<'PY'
import json
names = [json.load(open(f"/tmp/weekfit-par-{n}.json"))["name"] for n in (1, 2, 3, 4)]
repeat = json.load(open("/tmp/weekfit-repeat.json"))["name"]
assert len(set(names + [repeat])) == 1, names + [repeat]
open("/tmp/weekfit-saved-name.txt", "w").write(repeat)
print("shared result", repeat)
PY
curl -fsS "${BASE}/healthz" >/tmp/weekfit-health.json
expect_calls 1

echo "== restart with the same volume =="
docker rm -f "$NAME" >/dev/null
start_mock
wait_health
expect_calls 0
post "$TOKEN" "$ONE" /tmp/weekfit-replay
test "$(cat /tmp/weekfit-replay.status)" = "200"
grep -qi "^X-WeekFit-Idempotent-Hit: 1" /tmp/weekfit-replay.headers
python3 - <<'PY'
import json
saved = open("/tmp/weekfit-saved-name.txt").read()
body = json.load(open("/tmp/weekfit-replay.json"))
assert body["name"] == saved, (body["name"], saved)
print("replay", body["name"])
PY
curl -fsS "${BASE}/healthz" >/tmp/weekfit-health.json
expect_calls 0

echo "== two UIDs, one analysis id =="
post "${TOKEN}.uid-a" "$SHARED" /tmp/weekfit-uid-a
test "$(cat /tmp/weekfit-uid-a.status)" = "200"
docker exec -e ANALYSIS="$SHARED" "$NAME" \
  node --input-type=module -e '
import { readFile, writeFile } from "node:fs/promises";
import { ownerKey } from "./async/quota.mjs";
const id = process.env.ANALYSIS;
const file = `/var/data/photo-calls/owners/${ownerKey("devuid:uid-a")}/${id}.json`;
const stored = JSON.parse(await readFile(file, "utf8"));
stored.result = { ...stored.result, name: "secret-for-a" };
await writeFile(file, JSON.stringify(stored) + "\n");
console.log(file);
'
post "${TOKEN}.uid-b" "$SHARED" /tmp/weekfit-uid-b
test "$(cat /tmp/weekfit-uid-b.status)" = "200"
post "${TOKEN}.uid-a" "$SHARED" /tmp/weekfit-uid-a-replay
test "$(cat /tmp/weekfit-uid-a-replay.status)" = "200"
python3 - <<'PY'
import json
other = json.load(open("/tmp/weekfit-uid-b.json"))
replay = json.load(open("/tmp/weekfit-uid-a-replay.json"))
assert other["name"] != "secret-for-a", other
assert replay["name"] == "secret-for-a", replay
assert "secret-for-a" not in json.dumps(other)
print("uid-b", other["name"], "uid-a", replay["name"])
PY
curl -fsS "${BASE}/healthz" >/tmp/weekfit-health.json
expect_calls 2

echo "container checks passed"
