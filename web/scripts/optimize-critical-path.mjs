/**
 * Shorten the render-blocking critical path:
 * - Inline minimal hero/nav CSS in <head>
 * - Hoist the main stylesheet immediately after <meta viewport>
 * - Drop duplicate preload hints that delayed CSS discovery
 */
import { readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const OUT = join(process.cwd(), "out");
const CRITICAL = readFileSync(join(process.cwd(), "styles", "critical.css"), "utf8")
  .replace(/\/\*[\s\S]*?\*\//g, "")
  .replace(/\s+/g, " ")
  .trim();

const CRITICAL_TAG = `<style id="critical-css">${CRITICAL}</style>`;

function walk(dir, files = []) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) walk(p, files);
    else files.push(p);
  }
  return files;
}

function preloadKey(tag) {
  const href = tag.match(/\shref="([^"]+)"/)?.[1];
  const src = tag.match(/\ssrc="([^"]+)"/)?.[1];
  const media = tag.match(/\smedia="([^"]+)"/)?.[1] ?? "";
  const as = tag.match(/\sas="([^"]+)"/)?.[1] ?? "";
  return `${as}|${href ?? src ?? ""}|${media}`;
}

function optimizeHtml(html) {
  if (html.includes('id="critical-css"')) {
    html = html.replace(/<style id="critical-css">[\s\S]*?<\/style>/g, "");
  }

  const sheet = html.match(/<link rel="stylesheet" href="([^"]+)"[^>]*>/);
  if (!sheet) return { html, changed: false };

  const sheetTag = sheet[0];
  const sheetHref = sheet[1];
  let next = html.replace(sheetTag, "");

  const preloads = [];
  next = next.replace(/<link rel="preload"[^>]*>/g, (tag) => {
    preloads.push(tag);
    return "";
  });

  const seen = new Set();
  const uniquePreloads = preloads.filter((tag) => {
    const key = preloadKey(tag);
    if (seen.has(key)) return false;
    seen.add(key);
    if (tag.includes('as="image"')) {
      return (
        tag.includes("/img/today-560.webp") ||
        tag.includes("/img/today-760.webp")
      );
    }
    return true;
  });

  // Stylesheet first, then other preloads (LCP images, fonts, scripts).
  const block = [
    CRITICAL_TAG,
    `<link rel="preload" href="${sheetHref}" as="style">`,
    sheetTag,
    ...uniquePreloads,
  ].join("");

  const anchor = /<meta name="viewport"[^>]*>/;
  if (!anchor.test(next)) return { html, changed: false };

  next = next.replace(anchor, (m) => `${m}${block}`);
  return { html: next, changed: next !== html };
}

let pages = 0;
for (const file of walk(OUT)) {
  if (!/\.html$/.test(file)) continue;
  const src = readFileSync(file, "utf8");
  const { html, changed } = optimizeHtml(src);
  if (changed) {
    writeFileSync(file, html);
    pages++;
  }
}

console.log(`optimize-critical-path: updated ${pages} html files`);
