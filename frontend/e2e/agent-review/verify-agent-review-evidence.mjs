#!/usr/bin/env node
/**
 * Capture Run ボンドル・visual-review.json・PNG の証拠鎖を検証する。
 *
 *   node e2e/agent-review/verify-agent-review-evidence.mjs
 *   node e2e/agent-review/verify-agent-review-evidence.mjs --enforce
 */
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  bundlePath,
  visualReviewPath,
} from './agent-review-paths.mjs';
import {
  parseAgentReviewBundleContent,
  validateAgentReviewEvidenceChain,
  verifyBundleArtifactsOnDisk,
} from './agent-review-bundle-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND = join(__dirname, '..', '..');
const ENFORCE = process.argv.includes('--enforce');

const manifestPath = join(FRONTEND, 'e2e/route-manifest.json');

const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));

/** @type {object | null} */
let bundle = null;
let bundleParseErrors = [];
try {
  const raw = await readFile(bundlePath(FRONTEND), 'utf8');
  const parsed = parseAgentReviewBundleContent(raw);
  bundle = parsed.bundle;
  bundleParseErrors = parsed.errors;
} catch {
  bundle = null;
}

/** @type {object | null} */
let review = null;
try {
  review = JSON.parse(await readFile(visualReviewPath(FRONTEND), 'utf8'));
} catch {
  review = null;
}

const chain = validateAgentReviewEvidenceChain({
  bundle,
  review,
  manifestRouteCount: manifest.routes.length,
});
if (bundleParseErrors.length > 0) {
  chain.errors.unshift(...bundleParseErrors);
  chain.ok = false;
}

let diskOk = true;
let diskDetail = { missing: [], hashMismatch: [] };
if (bundle) {
  diskDetail = await verifyBundleArtifactsOnDisk(bundle, FRONTEND);
  diskOk = diskDetail.ok;
  if (!diskOk) {
    for (const png of diskDetail.missing) {
      chain.errors.push(`PNG 欠落: ${png}`);
    }
    for (const m of diskDetail.hashMismatch) {
      chain.errors.push(`PNG ハッシュ不一致: ${m.png}`);
    }
  }
}

const ok = chain.ok && diskOk;

if (ok) {
  console.log(
    `verify-agent-review-evidence: OK captureRunId=${bundle?.runId} artifacts=${bundle?.artifacts?.length ?? 0}`,
  );
  process.exit(0);
}

console.error('verify-agent-review-evidence: FAILED');
for (const err of chain.errors) {
  console.error(`  - ${err}`);
}
process.exit(ENFORCE ? 1 : 0);
