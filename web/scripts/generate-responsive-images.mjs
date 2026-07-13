#!/usr/bin/env node
/**
 * Generate display-sized responsive assets from full-resolution sources.
 * Requires ImageMagick (`magick`). Sources live in assets-src/; outputs go to public/.
 */
import { execSync } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const ROOT = process.cwd();
const SRC = join(ROOT, "assets-src");
const PUBLIC = join(ROOT, "public");

const FRAME_W = 760;
const SCREEN_WIDTHS = [560, 760];
const WATCH_WIDTHS = [272, 368];
const SCREENS = ["today", "meals", "activity", "recovery", "coach", "nutrition"];

function runMagick(args) {
  execSync(`magick ${args.map((a) => `"${a.replace(/"/g, '\\"')}"`).join(" ")}`, {
    stdio: "inherit",
    shell: true,
  });
}

function ensureMagick() {
  try {
    execSync("magick -version", { stdio: "ignore" });
  } catch {
    console.error("generate-responsive-images: install ImageMagick (magick CLI)");
    process.exit(1);
  }
}

function resizeFrame(name) {
  const src = join(SRC, "mockify/devices", name);
  const out = join(PUBLIC, "mockify/devices", name);
  if (!existsSync(src)) {
    console.warn(`skip frame (missing source): ${name}`);
    return;
  }
  runMagick([src, "-filter", "Lanczos", "-resize", `${FRAME_W}x`, "-strip", out]);
  console.log(`frame ${FRAME_W}w → ${name}`);
}

function resizeScreens() {
  for (const name of SCREENS) {
    const jpg = join(PUBLIC, "img", `${name}.jpg`);
    if (!existsSync(jpg)) {
      console.warn(`skip screen (missing jpg): ${name}`);
      continue;
    }
    for (const w of SCREEN_WIDTHS) {
      const out = join(PUBLIC, "img", `${name}-${w}.webp`);
      runMagick([jpg, "-filter", "Lanczos", "-resize", `${w}x`, "-quality", "85", out]);
      console.log(`screen ${w}w → ${name}-${w}.webp`);
    }
  }
}

function resizeWatchOverlay() {
  const src = join(SRC, "img/hero-watch-ultra-overlay.png");
  if (!existsSync(src)) {
    const fallback = join(PUBLIC, "img", "hero-watch-ultra-overlay.png");
    if (!existsSync(fallback)) {
      console.warn("skip watch overlay (missing source png)");
      return;
    }
  }
  const overlaySrc = existsSync(join(SRC, "img/hero-watch-ultra-overlay.png"))
    ? join(SRC, "img/hero-watch-ultra-overlay.png")
    : join(PUBLIC, "img", "hero-watch-ultra-overlay.png");
  for (const w of WATCH_WIDTHS) {
    const out = join(PUBLIC, "img", `hero-watch-ultra-overlay-${w}.webp`);
    runMagick([overlaySrc, "-filter", "Lanczos", "-resize", `${w}x`, "-quality", "82", out]);
    console.log(`watch ${w}w → hero-watch-ultra-overlay-${w}.webp`);
  }
}

function resizeWordmark() {
  const src = join(SRC, "brand/logo-wf-mark.png");
  if (!existsSync(src)) {
    console.warn("skip wordmark (missing source)");
    return;
  }
  for (const h of [36, 72]) {
    const out = join(PUBLIC, "brand", `logo-wf-mark-${h}.webp`);
    runMagick([src, "-filter", "Lanczos", "-resize", `x${h}`, "-quality", "88", out]);
    console.log(`wordmark ${h}h → logo-wf-mark-${h}.webp`);
  }
}

ensureMagick();
mkdirSync(join(PUBLIC, "mockify/devices"), { recursive: true });
mkdirSync(join(PUBLIC, "brand"), { recursive: true });

resizeFrame("iPhone 16 Pro - Natural Titanium.png");
resizeFrame("iPhone 16 Pro - Black Titanium.png");
resizeScreens();
resizeWatchOverlay();
resizeWordmark();

console.log("generate-responsive-images: done");
