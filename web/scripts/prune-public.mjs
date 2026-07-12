/**
 * Remove non-production assets from `public/` before static export.
 * Keeps only Mockify frames referenced by the live site.
 */
import { readdirSync, rmSync, statSync } from "node:fs";
import { join } from "node:path";

const PUBLIC = join(process.cwd(), "public");
const MOCKIFY_DEVICES = join(PUBLIC, "mockify", "devices");
const KEEP_DEVICES = new Set([
  "iPhone 16 Pro - Natural Titanium.png",
  "iPhone 16 Pro - Black Titanium.png",
]);

let removed = 0;

function removePath(path) {
  rmSync(path, { recursive: true, force: true });
  removed++;
}

// reels/.tmp — local export scratch, never ship
removePath(join(PUBLIC, "reels", ".tmp"));

// Mockify: only hero + journey/download phone frames
const statusBarDir = join(PUBLIC, "mockify", "status-bar");
if (statSync(join(PUBLIC, "mockify"), { throwIfNoEntry: false })) {
  if (statSync(statusBarDir, { throwIfNoEntry: false })) {
    removePath(statusBarDir);
  }
  for (const file of readdirSync(MOCKIFY_DEVICES)) {
    if (!KEEP_DEVICES.has(file)) {
      removePath(join(MOCKIFY_DEVICES, file));
    }
  }
}

console.log(`prune-public: removed ${removed} paths`);
