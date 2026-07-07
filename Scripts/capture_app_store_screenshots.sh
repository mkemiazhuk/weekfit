#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="WeekFit"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro Max}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/build/app-store-screenshots}"

echo "→ Capturing App Store screenshots"
echo "  Destination: $DESTINATION"
echo "  Output hint: check XCTest tmp WeekFitAppStoreScreenshots + test report attachments"

cd "$ROOT"
mkdir -p "$OUTPUT_DIR"

xcodebuild test \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:WeekFitUITests/WeekFitScreenshotTests \
  -resultBundlePath "$OUTPUT_DIR/ScreenshotTest.xcresult"

echo "✓ Done. Open $OUTPUT_DIR/ScreenshotTest.xcresult in Xcode for attachments."
