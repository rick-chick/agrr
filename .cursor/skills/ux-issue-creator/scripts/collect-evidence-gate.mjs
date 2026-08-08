/**
 * UX issue 起票前の証拠鎖ゲート（Capture Run ボンドル）
 */
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

import {
  bundleCoversPngs,
  bundlePath,
  validateAgentReviewEvidenceChain,
} from '../../../../frontend/e2e/agent-review/agent-review-bundle-lib.mjs';
import { visualReviewPath } from '../../../../frontend/e2e/agent-review/agent-review-paths.mjs';

/**
 * @param {string} repoRoot
 */
export async function loadAgentReviewEvidence(repoRoot) {
  const frontendRoot = join(repoRoot, 'frontend');
  const manifest = JSON.parse(
    await readFile(join(frontendRoot, 'e2e/route-manifest.json'), 'utf8'),
  );

  /** @type {object | null} */
  let review = null;
  try {
    review = JSON.parse(await readFile(visualReviewPath(frontendRoot), 'utf8'));
  } catch {
    review = null;
  }

  /** @type {object | null} */
  let bundle = null;
  try {
    bundle = JSON.parse(await readFile(bundlePath(frontendRoot), 'utf8'));
  } catch {
    bundle = null;
  }

  const chain = validateAgentReviewEvidenceChain({
    bundle,
    review,
    manifestRouteCount: manifest.routes.length,
  });

  return { bundle, chain, review, manifest };
}

/**
 * visual 指摘が bundle に紐づく PNG を持つか。
 * @param {Record<string, unknown>} finding
 * @param {object | null} bundle
 */
export function findingHasBundleEvidence(finding, bundle) {
  if (!bundle || finding.source !== 'visual-review') {
    return finding.source !== 'visual-review';
  }
  const pngs = finding.png ?? [];
  if (!Array.isArray(pngs) || pngs.length === 0) return false;
  const cover = bundleCoversPngs(bundle, pngs);
  return cover.ok;
}

/**
 * @param {Array<Record<string, unknown>>} findings
 * @param {object | null} bundle
 */
export function filterFindingsByEvidence(findings, bundle) {
  return findings.filter((f) => {
    if (f.source === 'css-audit') return true;
    return findingHasBundleEvidence(f, bundle);
  });
}
