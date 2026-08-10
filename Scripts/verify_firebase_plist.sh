#!/usr/bin/env bash
# Release/archive preflight: GoogleService-Info.plist must exist for production Firebase.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT/WeekFit/GoogleService-Info.plist"

if [ ! -f "$PLIST" ]; then
  echo "error: GoogleService-Info.plist missing at:"
  echo "  $PLIST"
  echo "Copy docs/GoogleService-Info.plist.example → WeekFit/GoogleService-Info.plist with Console values."
  exit 1
fi

# Basic sanity — production bundle id must match.
if ! grep -q "com.weekfit.app" "$PLIST"; then
  echo "error: GoogleService-Info.plist does not reference com.weekfit.app"
  exit 1
fi

echo "✓ Firebase plist present: $PLIST"
