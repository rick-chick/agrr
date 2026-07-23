#!/usr/bin/env node
/**
 * Idempotently inject research simulate CTA runtime script into built VitePress HTML
 * under public/research/. Mirrors inject-research-google-analytics.rb marker pattern.
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  RESEARCH_CTA_SCRIPT_MARKER_END,
  RESEARCH_CTA_SCRIPT_MARKER_START,
  buildResearchCtaScriptSnippet,
  verifyAllResearchRequirementsCtaScripts
} from '../../../../scripts/research-simulate-cta-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = join(ROOT, 'public', 'research');
const SNIPPET = buildResearchCtaScriptSnippet();

function walkHtmlFiles(dir) {
  const results = [];
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      results.push(...walkHtmlFiles(fullPath));
      continue;
    }
    if (entry.endsWith('.html')) {
      results.push(fullPath);
    }
  }
  return results;
}

function injectSnippet(content) {
  if (content.includes(RESEARCH_CTA_SCRIPT_MARKER_START)) {
    if (!content.includes(RESEARCH_CTA_SCRIPT_MARKER_END)) {
      throw new Error('broken research CTA script markers');
    }
    return content.replace(
      new RegExp(
        `${RESEARCH_CTA_SCRIPT_MARKER_START}[\\s\\S]*?${RESEARCH_CTA_SCRIPT_MARKER_END}`,
        'm'
      ),
      SNIPPET
    );
  }
  if (!content.match(/<\/head>/i)) {
    throw new Error('missing </head>');
  }
  return content.replace(/<\/head>/i, `${SNIPPET}\n</head>`);
}

let updated = 0;
const failures = [];

for (const path of walkHtmlFiles(RESEARCH_DIR)) {
  const content = readFileSync(path, 'utf8');
  try {
    const next = injectSnippet(content);
    if (next === content) {
      continue;
    }
    writeFileSync(path, next, 'utf8');
    updated += 1;
  } catch (error) {
    failures.push(`${path}: ${error.message}`);
  }
}

if (failures.length > 0) {
  console.error('[inject-research-simulate-cta-script] failures:');
  for (const line of failures) {
    console.error(`  - ${line}`);
  }
  process.exit(1);
}

console.log(`[inject-research-simulate-cta-script] updated=${updated}`);

const verifyFailures = verifyAllResearchRequirementsCtaScripts(RESEARCH_DIR);
if (verifyFailures.length > 0) {
  console.error(JSON.stringify(verifyFailures, null, 2));
  process.exit(1);
}
