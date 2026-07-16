#!/usr/bin/env node
/**
 * Idempotently inject temperature-requirements public-plan CTAs into built VitePress
 * assets under public/research/. Mirrors inline GDD CTA style (agrr-gdd-simulate-cta).
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  buildTemperatureCtaHtml,
  listTemperatureRequirementHtmlPaths,
  listTemperatureRequirementJsPaths,
  parseCropAndLangFromHtmlPath,
  parseCropFromJsPath,
  temperatureCtaBodySnippet,
  verifyAllTemperatureRequirementCtas
} from '../../../../scripts/verify-research-temperature-cta-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = join(ROOT, 'public', 'research');

function extractH2Ids(content) {
  return [...content.matchAll(/<h2 id="([^"]+)"/g)].map((match) => match[1]);
}

function summaryAnchor(h2Ids) {
  for (const id of [...h2Ids].reverse()) {
    if (id.includes('参考') || id.includes('まとめ表')) {
      continue;
    }
    if (id === 'まとめ' || id.endsWith('-まとめ') || /_\d+-まとめ$/.test(id)) {
      return id;
    }
  }
  return [...h2Ids]
    .reverse()
    .find((id) => id.toLowerCase() === 'sources' || id.includes('参考文献'));
}

function temperatureCtaPresent(content, lang) {
  return (
    content.includes(temperatureCtaBodySnippet(lang)) &&
    content.includes('agrr-gdd-simulate-cta')
  );
}

function injectBeforeAnchor(content, anchor, ctaHtml) {
  const needle = `<h2 id="${anchor}"`;
  if (!content.includes(needle)) {
    throw new Error(`anchor not found: ${anchor}`);
  }
  return content.replace(needle, `${ctaHtml}${needle}`);
}

function injectFile(path, lang, crop) {
  const content = readFileSync(path, 'utf8');
  if (temperatureCtaPresent(content, lang)) {
    return 'skipped';
  }

  const anchor = summaryAnchor(extractH2Ids(content));
  if (!anchor) {
    throw new Error(`no insertion anchor in ${path}`);
  }

  const updated = injectBeforeAnchor(content, anchor, buildTemperatureCtaHtml(lang, crop));
  writeFileSync(path, updated, 'utf8');
  return 'updated';
}

if (!RESEARCH_DIR) {
  console.warn('[inject-research-temperature-simulate-cta] skip: research dir missing');
  process.exit(0);
}

let updated = 0;
let skipped = 0;
const failures = [];

for (const relativePath of listTemperatureRequirementHtmlPaths(RESEARCH_DIR)) {
  const { lang, crop } = parseCropAndLangFromHtmlPath(relativePath);
  const path = join(RESEARCH_DIR, relativePath);
  try {
    const result = injectFile(path, lang, crop);
    if (result === 'updated') updated += 1;
    if (result === 'skipped') skipped += 1;
  } catch (error) {
    failures.push(`${relativePath}: ${error.message}`);
  }
}

for (const relativePath of listTemperatureRequirementJsPaths(RESEARCH_DIR)) {
  const crop = parseCropFromJsPath(relativePath);
  const path = join(RESEARCH_DIR, relativePath);
  try {
    const result = injectFile(path, 'ja', crop);
    if (result === 'updated') updated += 1;
    if (result === 'skipped') skipped += 1;
  } catch (error) {
    failures.push(`${relativePath}: ${error.message}`);
  }
}

if (failures.length > 0) {
  console.error('[inject-research-temperature-simulate-cta] failures:');
  for (const line of failures) {
    console.error(`  - ${line}`);
  }
  process.exit(1);
}

console.log(`[inject-research-temperature-simulate-cta] updated=${updated} skipped=${skipped}`);

if (updated > 0) {
  const verifyFailures = verifyAllTemperatureRequirementCtas(RESEARCH_DIR);
  if (verifyFailures.length > 0) {
    console.error(JSON.stringify(verifyFailures, null, 2));
    process.exit(1);
  }
}
