#!/usr/bin/env node
/**
 * Live evaluation of coach-summary prompt against the unconfirmed-conclusions fixture.
 * Usage:
 *   OPENAI_API_KEY=... COACH_SUMMARY_MODEL=gpt-4.1-mini node --env-file-if-exists=.env scripts/eval-coach-summary-fixture.mjs
 */
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  validateDay,
  validateSummary,
  generateSummary,
  unconfirmedConclusionIssues,
  SUMMARY_PROMPT_VERSION,
  buildInstructions
} from '../coach-summary.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const fixturePath = path.join(root, '../fixtures/coach-summary/unconfirmed-conclusions-v11.json');
const fixture = JSON.parse(await readFile(fixturePath, 'utf8'));
const apiKey = process.env.OPENAI_API_KEY || '';
const model = process.env.COACH_SUMMARY_MODEL || 'gpt-4.1-mini';
const locales = (process.env.EVAL_LOCALES || 'ru,pl').split(',').map((s) => s.trim()).filter(Boolean);

if (!apiKey || apiKey.includes('...') || apiKey.length < 20) {
  console.error(JSON.stringify({ error: 'missing_openai_api_key', promptVersion: SUMMARY_PROMPT_VERSION }));
  process.exit(2);
}

const reports = [];
for (const locale of locales) {
  const body = structuredClone(fixture.input);
  body.locale = locale;
  const input = validateDay(body);
  const instructions = buildInstructions(input);
  const started = Date.now();
  const { result, usage } = await generateSummary(input, {
    apiKey,
    summaryModel: model,
    summaryTimeoutMs: 45000
  });
  validateSummary(result, input);
  const issues = unconfirmedConclusionIssues(result);
  const checks = {
    schemaValid: true,
    languageLooksLocale: locale === 'pl'
      ? /[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]/.test(`${result.today.text}${result.now.text}${result.tomorrow.text}`)
        || !/\b(the|you|your|today|tomorrow)\b/i.test(result.today.text)
      : /[А-Яа-яЁё]/.test(`${result.today.text}${result.now.text}${result.tomorrow.text}`),
    noUnconfirmedIssues: issues.length === 0,
    instructionAsksForEveningAdvice: /one recommendation for this evening/.test(instructions),
    instructionHasSilentVerify: /silently verify/.test(instructions)
  };
  reports.push({
    locale,
    promptVersion: SUMMARY_PROMPT_VERSION,
    model,
    latencyMs: Date.now() - started,
    usage: usage ?? null,
    checks,
    issues,
    result
  });
}

const failed = reports.some((r) => !r.checks.noUnconfirmedIssues || !r.checks.languageLooksLocale || !r.checks.schemaValid);
console.log(JSON.stringify({ promptVersion: SUMMARY_PROMPT_VERSION, failed, reports }, null, 2));
process.exit(failed ? 1 : 0);
