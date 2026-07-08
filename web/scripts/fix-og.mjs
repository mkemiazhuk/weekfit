// Post-build: Next emits metadata images (opengraph-image / twitter-image) as
// extension-less files. GitHub Pages serves those with the wrong Content-Type,
// which social scrapers reject. This gives them a real ".png" alongside and
// rewrites the HTML references so previews work everywhere.
import { readdirSync, statSync, copyFileSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const OUT = join(process.cwd(), "out");
const IMAGE_ROUTES = ["opengraph-image", "twitter-image"];

function walk(dir, files = []) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    const s = statSync(p);
    if (s.isDirectory()) walk(p, files);
    else files.push(p);
  }
  return files;
}

const all = walk(OUT);
let pngCount = 0;

for (const file of all) {
  const name = file.split("/").pop();
  if (IMAGE_ROUTES.includes(name)) {
    copyFileSync(file, `${file}.png`);
    pngCount++;
  }
}

let htmlCount = 0;
for (const file of all) {
  if (!/\.(html|txt)$/.test(file)) continue;
  const src = readFileSync(file, "utf8");
  let out = src;
  for (const route of IMAGE_ROUTES) {
    // "/route?hash"  and  "/route"  ->  "/route.png..."
    out = out
      .replaceAll(`${route}?`, `${route}.png?`)
      .replaceAll(`${route}"`, `${route}.png"`)
      .replaceAll(`${route}&`, `${route}.png&`);
  }
  if (out !== src) {
    writeFileSync(file, out);
    htmlCount++;
  }
}

console.log(`fix-og: wrote ${pngCount} .png images, rewrote ${htmlCount} files`);
