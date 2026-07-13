import { readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const OUT = join(process.cwd(), "out");
const MAX_MB = Number(process.env.DEPLOY_SIZE_MAX_MB ?? 0);

function dirSize(dir) {
  let total = 0;
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    const s = statSync(p);
    total += s.isDirectory() ? dirSize(p) : s.size;
  }
  return total;
}

function formatMb(bytes) {
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

const bytes = dirSize(OUT);
console.log(`deploy-size: ${formatMb(bytes)} (${OUT})`);

const forbidden = [
  "reels/.tmp",
  "mockify/status-bar",
  "reels/weekfit-launch-reel.mp4",
  "img/watch-cycling-workout.png",
  "img/hero-watch-ultra.png",
  "img/today.jpg",
];
function walk(dir, rel = "") {
  const hits = [];
  for (const entry of readdirSync(dir)) {
    const nextRel = rel ? `${rel}/${entry}` : entry;
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) hits.push(...walk(p, nextRel));
    else if (forbidden.some((f) => nextRel.includes(f))) hits.push(nextRel);
  }
  return hits;
}

const leaks = walk(OUT);
if (leaks.length) {
  console.error("deploy-size: forbidden paths in export:", leaks.join(", "));
  process.exit(1);
}

if (MAX_MB > 0 && bytes > MAX_MB * 1024 * 1024) {
  console.error(`deploy-size: exceeds budget ${MAX_MB} MB`);
  process.exit(1);
}
