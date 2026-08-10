#!/usr/bin/env node
/**
 * CLI: verify EN research reports are translated. Fails when allowlisted crops have JA stubs.
 */
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { EN_TRANSLATED_CROPS } from './research-en-translated-crops-lib.mjs';
import {
  collectEnTranslationIssues,
  findAllowlistCoverageGaps,
} from './verify-research-en-translation-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '..');
const RESEARCH_DIR = join(ROOT, 'public', 'research');

const failures = collectEnTranslationIssues(RESEARCH_DIR);
const requiredFailures = failures.filter((f) => f.required);
const warnings = failures.filter((f) => !f.required);

const coverageGaps = findAllowlistCoverageGaps(RESEARCH_DIR, EN_TRANSLATED_CROPS);

if (warnings.length > 0) {
  console.warn(
    `[verify-research-en-translation] ${warnings.length} untranslated EN report(s) (not in EN_TRANSLATED_CROPS):`
  );
  for (const w of warnings) {
    console.warn(`  WARN ${w.relativePath}: ${w.issues.join('; ')}`);
  }
}

if (coverageGaps.length > 0) {
  console.error('[verify-research-en-translation] allowlist coverage gaps:');
  for (const gap of coverageGaps) {
    console.error(`  FAIL ${gap}`);
  }
  process.exit(1);
}

if (requiredFailures.length > 0) {
  console.error(
    `[verify-research-en-translation] ${requiredFailures.length} translated crop report(s) failed QA:`
  );
  for (const f of requiredFailures) {
    console.error(`  FAIL ${f.relativePath} (${f.crop}): ${f.issues.join('; ')}`);
  }
  process.exit(1);
}

console.log(
  `[verify-research-en-translation] OK — ${EN_TRANSLATED_CROPS.size} crop(s) in allowlist, no required failures`
);
