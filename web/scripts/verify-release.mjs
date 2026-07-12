/**
 * Post-build release verification for static export.
 */
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join } from "node:path";

const OUT = join(process.cwd(), "out");
const SITE = "https://weekfit.app";

const REQUIRED_ROUTES = [
  "index.html",
  "ru/index.html",
  "experience/index.html",
  "download/index.html",
  "blog/index.html",
  "privacy/index.html",
  "terms/index.html",
  "support/index.html",
  "faq/index.html",
  "404.html",
];

const REQUIRED_OG = [
  "opengraph-image.png",
  "experience/opengraph-image.png",
  "blog/opengraph-image.png",
  "download/opengraph-image.png",
];

const FORBIDDEN = ["reels/.tmp", "mockify/status-bar"];

function walk(dir, rel = "", files = []) {
  for (const entry of readdirSync(dir)) {
    const nextRel = rel ? `${rel}/${entry}` : entry;
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) walk(p, nextRel, files);
    else files.push(nextRel);
  }
  return files;
}

function dirSize(dir) {
  let total = 0;
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    const s = statSync(p);
    total += s.isDirectory() ? dirSize(p) : s.size;
  }
  return total;
}

let failed = false;
const report = [];

function pass(msg) {
  report.push(`✓ ${msg}`);
}

function fail(msg) {
  report.push(`✗ ${msg}`);
  failed = true;
}

if (!existsSync(OUT)) {
  console.error("verify-release: out/ missing — run npm run build first");
  process.exit(1);
}

for (const route of REQUIRED_ROUTES) {
  if (existsSync(join(OUT, route))) pass(`route ${route}`);
  else fail(`missing route ${route}`);
}

for (const og of REQUIRED_OG) {
  if (existsSync(join(OUT, og))) pass(`OG ${og}`);
  else fail(`missing OG ${og}`);
}

const home = readFileSync(join(OUT, "index.html"), "utf8");
const orgCount = (home.match(/"@type":\s*"SoftwareApplication"/g) ?? []).length;
if (orgCount === 1) pass("single SoftwareApplication schema on homepage");
else fail(`homepage SoftwareApplication count: ${orgCount} (expected 1)`);

const graphCount = (home.match(/"@graph"/g) ?? []).length;
if (graphCount === 1) pass("single @graph on homepage");
else fail(`homepage @graph count: ${graphCount} (expected 1)`);

const sitemap = readFileSync(join(OUT, "sitemap.xml"), "utf8");
const emptyCategories = ["sleep", "apple-health", "wellness", "coach"];
for (const cat of emptyCategories) {
  if (sitemap.includes(`/blog/${cat}/`)) fail(`empty category in sitemap: ${cat}`);
  else pass(`empty category excluded: ${cat}`);
}

const robots = readFileSync(join(OUT, "robots.txt"), "utf8");
if (robots.includes(`${SITE}/sitemap.xml`)) pass("robots references sitemap");
else fail("robots missing sitemap reference");

const googleHtmlFile = "googlebe868e9843b46f53.html";
if (existsSync(join(OUT, googleHtmlFile))) pass(`google verification file ${googleHtmlFile}`);
else fail(`missing google verification file ${googleHtmlFile}`);

if (home.includes('name="google-site-verification"')) pass("google verification meta on homepage");
else fail("homepage missing google-site-verification meta");

const allFiles = walk(OUT);
for (const f of allFiles) {
  if (FORBIDDEN.some((x) => f.includes(x))) fail(`forbidden export path: ${f}`);
}

const mb = (dirSize(OUT) / (1024 * 1024)).toFixed(1);
pass(`deploy size ${mb} MB`);

console.log(report.join("\n"));
if (failed) process.exit(1);
