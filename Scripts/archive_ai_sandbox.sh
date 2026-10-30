#!/usr/bin/env bash
# Explicit, isolated TestFlight archive. Never modifies the release checkout.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX_URL="${1:?Usage: bash Scripts/archive_ai_sandbox.sh https://sandbox-host [build-number]}"
BUILD_NUMBER="${2:-}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/WeekFit-AI-Sandbox.xcarchive}"
[[ "$ARCHIVE_PATH" = /* ]] || { echo 'ARCHIVE_PATH must be absolute' >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo 'Run on a Mac with Xcode and signing configured.' >&2; exit 1; }
python3 - "$SANDBOX_URL" "$BUILD_NUMBER" <<'PY'
import sys
from urllib.parse import urlsplit
u = urlsplit(sys.argv[1])
if (u.scheme != 'https' or not u.hostname or u.hostname == 'weekfit-food-photo.onrender.com'
    or u.username or u.password or u.query or u.fragment or u.path not in ('', '/')):
    sys.exit('Supply a separate HTTPS Sandbox origin without credentials or path.')
if sys.argv[2] and not sys.argv[2].isdigit():
    sys.exit('Build number must contain only digits.')
PY
bash "$ROOT/Scripts/verify_firebase_plist.sh"
if [[ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]]; then
    echo 'Commit tracked changes first: this archive uses exactly HEAD.' >&2
    exit 1
fi
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/weekfit-ai-sandbox.XXXXXX")"
cleanup() {
    git -C "$ROOT" worktree remove --force "$STAGING_DIR/source" >/dev/null 2>&1 || true
    rmdir "$STAGING_DIR" 2>/dev/null || true
}
trap cleanup EXIT
git -C "$ROOT" worktree add --detach "$STAGING_DIR/source" HEAD
cp "$ROOT/WeekFit/GoogleService-Info.plist" "$STAGING_DIR/source/WeekFit/GoogleService-Info.plist"
python3 - "$STAGING_DIR/source/WeekFit/Info.plist" "$SANDBOX_URL" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    p = plistlib.load(f)
p.update(WeekFitAIUsageEnabled=True, WeekFitAISandboxEnabled=True, WeekFitAISandboxBaseURL=sys.argv[2])
with open(sys.argv[1], 'wb') as f:
    plistlib.dump(p, f)
PY
mkdir -p "$(dirname "$ARCHIVE_PATH")"
cd "$STAGING_DIR/source"
BUILD_ARGS=()
if [[ -n "$BUILD_NUMBER" ]]; then BUILD_ARGS+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER"); fi
xcodebuild archive -project WeekFit.xcodeproj -scheme WeekFit -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Automatic "${BUILD_ARGS[@]}"
python3 - "$ARCHIVE_PATH/Products/Applications/WeekFit.app/Info.plist" "$SANDBOX_URL" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    p = plistlib.load(f)
assert p.get('WeekFitAIUsageEnabled') is True
assert p.get('WeekFitAISandboxEnabled') is True
assert p.get('WeekFitAISandboxBaseURL') == sys.argv[2]
print('Verified Sandbox archive. Upload for internal TestFlight testing only.')
PY
printf 'Archive: %s\n' "$ARCHIVE_PATH"
