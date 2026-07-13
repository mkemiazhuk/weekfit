/**
 * Lightweight RU copy lint to reduce “AI-written” tells.
 *
 * This is intentionally heuristic. It does NOT prove a text is human-written.
 * It only blocks the most common giveaways: anglicisms, calques, wrong quotes,
 * ASCII hyphens where em-dash is expected, and filler phrases.
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const ROOT = join(process.cwd(), "lib");

function walk(dir, out = []) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    const s = statSync(p);
    if (s.isDirectory()) walk(p, out);
    else if (p.endsWith(".ts") || p.endsWith(".tsx")) out.push(p);
  }
  return out;
}

/** Extract likely RU copy payloads from blog content modules. */
function extractRuStrings(source) {
  const results = [];

  // Matches: ru: [ ... v: "..." ... ] and similar.
  // We purposely keep it simple and only grab string literals assigned to `v`.
  const ruBlock = /ru\s*:\s*\[[\s\S]*?\]\s*,/g;
  const vString = /\bv\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/g;

  const ruMatches = source.match(ruBlock) ?? [];
  for (const block of ruMatches) {
    let m;
    while ((m = vString.exec(block))) {
      results.push(m[1]);
    }
  }
  return results;
}

function unescapeJs(s) {
  return s
    .replaceAll('\\"', '"')
    .replaceAll("\\n", "\n")
    .replaceAll("\\t", "\t")
    .replaceAll("\\u2014", "—")
    .replaceAll("\\u00A0", "\u00A0");
}

const RULES = [
  {
    id: "ru-quotes",
    hint: "Use «ёлочки» for Russian quotes, avoid “English quotes”.",
    test: (s) => /[“”„]/.test(s),
  },
  {
    id: "ascii-dash",
    hint: "Use em dash (—) in RU prose instead of hyphen-minus (-) with spaces.",
    test: (s) => /\s-\s/.test(s),
  },
  {
    id: "anglicisms",
    hint: "Avoid англицизмы (тайминг, катоф/катофф, чеклист, оффер, etc.) unless brand-required.",
    test: (s) =>
      /\b(тайминг|cutoff|катофф|катоф|чеклист|оффер|фич(а|и)|инсайт(ы)?|скролл(ить|ю|ишь|ит))\b/i.test(
        s
      ),
  },
  {
    id: "generic-ai-fillers",
    hint: "Avoid generic AI filler phrasing; make it concrete and specific.",
    test: (s) =>
      /\b(в целом|на самом деле|в общем|очень важно|как правило|стоит отметить|не стоит забывать)\b/i.test(s),
  },
  {
    id: "latin-in-ru",
    hint: "Avoid unnecessary Latin words in RU copy (brand terms like WeekFit / Apple Health are ok).",
    test: (s) => {
      const allowed = [
        "WeekFit",
        "Apple",
        "Health",
        "Watch",
        "HealthKit",
        "VO2",
        "VO₂",
        "max",
      ];
      let t = s;
      for (const token of allowed) t = t.replaceAll(token, "");
      return /[A-Za-z]{3,}/.test(t);
    },
  },
];

let failed = false;
const findings = [];

for (const file of walk(ROOT)) {
  const src = readFileSync(file, "utf8");
  const ruStrings = extractRuStrings(src);
  if (ruStrings.length === 0) continue;

  ruStrings.forEach((raw, idx) => {
    const s = unescapeJs(raw);
    for (const rule of RULES) {
      if (!rule.test(s)) continue;
      failed = true;
      const preview = s.replaceAll("\n", " ").slice(0, 140);
      findings.push(`✗ ${rule.id} in ${file} [ru#${idx + 1}]: ${preview}`);
      findings.push(`  ↳ ${rule.hint}`);
    }
  });
}

if (!failed) {
  console.log("✓ copy-lint: RU copy looks editorial (heuristic)");
  process.exit(0);
}

console.error(["copy-lint: issues found", ...findings].join("\n"));
process.exit(1);

