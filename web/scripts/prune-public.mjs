/**
 * Remove non-production assets from `public/` before static export.
 * Keeps only Mockify frames referenced by the live site.
 */
import { existsSync, readdirSync, rmSync, statSync } from "node:fs";
import { join } from "node:path";

const PUBLIC = join(process.cwd(), "public");
const MOCKIFY_DEVICES = join(PUBLIC, "mockify", "devices");
const KEEP_DEVICES = new Set([
  "iPhone 16 Pro - Natural Titanium.png",
  "iPhone 16 Pro - Black Titanium.png",
]);

/** Paths relative to `public/` — removed from the deploy bundle only (keep in git). */
const PRUNE_PATHS = [
  "reels",
  "img/watch-cycling-workout.png",
  "img/hero-watch-ultra.png",
  "img/meal-details.jpg",
  "img/plan.jpg",
  // WebP is served on the site; JPGs remain in git for local scripts / schema fallbacks.
  "img/today.jpg",
  "img/meals.jpg",
  "img/activity.jpg",
  "img/recovery.jpg",
  "img/coach.jpg",
  "img/nutrition.jpg",
  // PNG kept for the export pipeline; WebP is ~78% smaller on the wire.
  "img/hero-watch-ultra-overlay.png",
];

let removed = 0;

function removePath(path) {
  if (!existsSync(path)) return;
  rmSync(path, { recursive: true, force: true });
  removed++;
}

for (const rel of PRUNE_PATHS) {
  removePath(join(PUBLIC, rel));
}

// Mockify: only hero + journey/download phone frames
const statusBarDir = join(PUBLIC, "mockify", "status-bar");
if (statSync(join(PUBLIC, "mockify"), { throwIfNoEntry: false })) {
  if (statSync(statusBarDir, { throwIfNoEntry: false })) {
    removePath(statusBarDir);
  }
  if (statSync(MOCKIFY_DEVICES, { throwIfNoEntry: false })) {
    for (const file of readdirSync(MOCKIFY_DEVICES)) {
      if (!KEEP_DEVICES.has(file)) {
        removePath(join(MOCKIFY_DEVICES, file));
      }
    }
  }
}

console.log(`prune-public: removed ${removed} paths`);
