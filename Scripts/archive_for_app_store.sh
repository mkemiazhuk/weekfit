#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="WeekFit"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/WeekFit.xcarchive}"
DESTINATION="generic/platform=iOS"

echo "→ Archiving WeekFit for App Store"
cd "$ROOT"
python3 - "$ROOT/WeekFit/Info.plist" <<'PYTHON'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    p = plistlib.load(f)
if p.get('WeekFitAISandboxEnabled') or p.get('WeekFitAISandboxBaseURL'):
    sys.exit('Remove AI Sandbox flags before creating an App Store archive.')
PYTHON
bash "$ROOT/Scripts/verify_firebase_plist.sh"
mkdir -p "$(dirname "$ARCHIVE_PATH")"

xcodebuild archive \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Automatic

echo "✓ Archive created: $ARCHIVE_PATH"
echo "Next: open Xcode → Organizer → Distribute App → App Store Connect"
