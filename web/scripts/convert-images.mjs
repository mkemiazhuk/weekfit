#!/usr/bin/env node
/** Regenerate WebP screenshots from source JPGs (requires `cwebp`). */
import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const IMG = join(process.cwd(), "public", "img");
const FILES = ["today", "meals", "activity", "recovery", "coach"];

for (const name of FILES) {
  const jpg = join(IMG, `${name}.jpg`);
  const webp = join(IMG, `${name}.webp`);
  if (!existsSync(jpg)) {
    console.warn(`convert-images: skip missing ${jpg}`);
    continue;
  }
  execSync(`cwebp -q 85 "${jpg}" -o "${webp}"`, { stdio: "inherit" });
}

console.log("convert-images: done");
