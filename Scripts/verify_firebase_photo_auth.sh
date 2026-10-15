#!/usr/bin/env bash
# Checks whether Firebase Anonymous Auth works for the WeekFit iOS plist.
# Does not print API keys or tokens.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT/WeekFit/GoogleService-Info.plist"

if [[ ! -f "$PLIST" ]]; then
  echo "FAIL: missing $PLIST (gitignored). Copy from Firebase Console."
  exit 1
fi

python3 - <<'PY' "$PLIST"
import json, plistlib, sys, urllib.error, urllib.request
from pathlib import Path

plist = plistlib.loads(Path(sys.argv[1]).read_bytes())
key = plist.get("API_KEY") or ""
project = plist.get("PROJECT_ID") or ""
bundle = plist.get("BUNDLE_ID") or ""
print(f"plist project={project} bundle={bundle}")

req = urllib.request.Request(
    f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={key}",
    data=b'{"returnSecureToken":true}',
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=30) as response:
        body = json.loads(response.read().decode())
except urllib.error.HTTPError as error:
    payload = json.loads(error.read().decode())
    message = payload.get("error", {}).get("message", str(error))
    print(f"FAIL: anonymous sign-up → {message}")
    print("Fix: Firebase Console → project", project, "→ Authentication → Get started → enable Anonymous.")
    print("URL: https://console.firebase.google.com/project/{}/authentication/providers".format(project))
    raise SystemExit(1)

if not body.get("idToken"):
    print("FAIL: sign-up succeeded but idToken missing")
    raise SystemExit(1)

print("OK: Firebase Anonymous Auth works for this project.")
print("Also confirm Render secret FIREBASE_PROJECT_ID matches:", project)
PY
