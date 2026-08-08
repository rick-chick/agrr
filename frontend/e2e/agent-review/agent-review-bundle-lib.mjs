import { createHash } from 'node:crypto';
import { readFile, stat, writeFile, mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

import { CAPTURE_LOCALES, agentPngFilename } from '../capture-locales.mjs';
import { bundlePath, agentReviewTmpDir } from './agent-review-paths.mjs';
import { captureRunIdFromReview } from './visual-review-lib.mjs';
import { displayPattern } from './verify-visual-review-fresh-lib.mjs';

const execFileAsync = promisify(execFile);

export { BUNDLE_FILENAME } from './agent-review-paths.mjs';
export { bundlePath } from './agent-review-paths.mjs';

/**
 * @param {string} frontendRoot
 */
export function agentOutDir(frontendRoot) {
  return join(frontendRoot, 'e2e/agent-review/out');
}

/**
 * @param {string} filePath
 */
export async function sha256File(filePath) {
  const data = await readFile(filePath);
  return createHash('sha256').update(data).digest('hex');
}

/**
 * @param {string} repoRoot
 */
export async function resolveGitCommit(repoRoot) {
  try {
    const { stdout } = await execFileAsync('git', ['rev-parse', 'HEAD'], {
      cwd: repoRoot,
      maxBuffer: 1024,
    });
    return stdout.trim() || null;
  } catch {
    return null;
  }
}

/**
 * @param {string | null} gitCommit
 * @param {string} completedAt
 */
export function buildRunId(gitCommit, completedAt) {
  const short = gitCommit ? gitCommit.slice(0, 7) : 'nogit';
  return `${completedAt}-${short}`;
}

/**
 * @param {string} value
 * @returns {boolean}
 */
export function isUnreviewedResultToken(value) {
  const v = String(value || '').trim();
  return v === '未レビュー' || v === '未キャプチャ';
}

/**
 * @param {Record<string, string>} row
 */
export function isActionableReviewRow(row) {
  if (
    isUnreviewedResultToken(row.layout) ||
    isUnreviewedResultToken(row.i18n) ||
    isUnreviewedResultToken(row.note)
  ) {
    return false;
  }
  return (
    row.layout === '注意' ||
    row.layout === '要確認' ||
    row.i18n === '注意' ||
    row.i18n === '要確認'
  );
}

/**
 * @param {{
 *   frontendRoot: string,
 *   repoRoot?: string,
 *   mergeExisting?: boolean,
 *   patternsFilter?: string[] | null,
 * }} options
 */
export async function generateCaptureBundle(options) {
  const { frontendRoot, repoRoot = join(frontendRoot, '..'), mergeExisting = false } = options;
  const manifestPath = join(frontendRoot, 'e2e/route-manifest.json');
  const outDir = agentOutDir(frontendRoot);
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  const routes = manifest.routes ?? [];

  /** @type {Record<string, unknown> | null} */
  let previous = null;
  const bundleFile = bundlePath(frontendRoot);
  if (mergeExisting) {
    try {
      previous = JSON.parse(await readFile(bundleFile, 'utf8'));
    } catch {
      previous = null;
    }
  }

  const completedAt = new Date().toISOString();
  const gitCommit = await resolveGitCommit(repoRoot);
  const runId = buildRunId(gitCommit, completedAt);

  /** @type {Map<string, object>} */
  const artifactMap = new Map();
  if (previous?.artifacts && mergeExisting) {
    for (const a of previous.artifacts) {
      const key = `${a.pattern}:${a.locale}`;
      artifactMap.set(key, a);
    }
  }

  const patternsFilter = options.patternsFilter;
  const filteredRoutes =
    patternsFilter && patternsFilter.length > 0
      ? routes.filter((r) => patternsFilter.includes(r.pattern))
      : routes;

  for (const route of filteredRoutes) {
    for (const locale of CAPTURE_LOCALES) {
      const png = agentPngFilename(route.pattern, locale);
      const filePath = join(outDir, png);
      try {
        const fileStat = await stat(filePath);
        const sha256 = await sha256File(filePath);
        const key = `${route.pattern}:${locale}`;
        artifactMap.set(key, {
          pattern: route.pattern,
          displayPattern: displayPattern(route.pattern),
          locale,
          png,
          sha256,
          capturedAt: fileStat.mtime.toISOString(),
          sizeBytes: fileStat.size,
        });
      } catch {
        if (!mergeExisting) {
          const key = `${route.pattern}:${locale}`;
          artifactMap.delete(key);
        }
      }
    }
  }

  const artifacts = [...artifactMap.values()].sort((a, b) => {
    const pa = `${a.displayPattern}:${a.locale}`;
    const pb = `${b.displayPattern}:${b.locale}`;
    return pa.localeCompare(pb);
  });

  const bundle = {
    bundleVersion: 1,
    runId,
    gitCommit,
    routeManifestGeneratedAt: manifest.generatedAt ?? null,
    routeManifestRouteCount: routes.length,
    completedAt,
    captureCommand: 'npm run e2e:capture-for-agent',
    artifacts,
  };

  await mkdir(agentReviewTmpDir(frontendRoot), { recursive: true });
  await writeFile(bundleFile, `${JSON.stringify(bundle, null, 2)}\n`);
  return bundle;
}

/**
 * @param {object} bundle
 * @param {string} frontendRoot
 */
export async function verifyBundleArtifactsOnDisk(bundle, frontendRoot) {
  const outDir = agentOutDir(frontendRoot);
  const missing = [];
  const hashMismatch = [];

  for (const artifact of bundle.artifacts ?? []) {
    const filePath = join(outDir, artifact.png);
    try {
      const sha256 = await sha256File(filePath);
      if (sha256 !== artifact.sha256) {
        hashMismatch.push({ png: artifact.png, expected: artifact.sha256, actual: sha256 });
      }
    } catch {
      missing.push(artifact.png);
    }
  }

  return {
    ok: missing.length === 0 && hashMismatch.length === 0,
    missing,
    hashMismatch,
  };
}

/**
 * @param {object} bundle
 * @param {string[]} pngNames
 */
export function bundleCoversPngs(bundle, pngNames) {
  const byName = new Map((bundle.artifacts ?? []).map((a) => [a.png, a]));
  const missing = [];

  for (const png of pngNames) {
    const artifact = byName.get(png);
    if (!artifact) {
      missing.push(png);
    }
  }

  return { ok: missing.length === 0, missing, stale: [] };
}

/**
 * @param {{
 *   bundle: object | null,
 *   review: object | null,
 *   manifestRouteCount: number,
 * }} input
 */
export function validateAgentReviewEvidenceChain(input) {
  const errors = [];
  const { bundle, review, manifestRouteCount } = input;

  if (!bundle) {
    errors.push('agent-review-bundle.json が存在しない。npm run e2e:capture-for-agent を実行すること');
    return { ok: false, errors, captureRunId: null };
  }

  const reviewRunId = review ? captureRunIdFromReview(review) : null;
  if (!reviewRunId) {
    errors.push(
      'visual-review.json に captureRunId がない。frontend-agent-visual-review で bundle.runId を含めて生成すること',
    );
  } else if (reviewRunId !== bundle.runId) {
    errors.push(
      `captureRunId 不一致: review=${reviewRunId} bundle=${bundle.runId}（キャプチャ後にレビューを更新すること）`,
    );
  }

  if (bundle.routeManifestRouteCount !== manifestRouteCount) {
    errors.push(
      `bundle.routeManifestRouteCount (${bundle.routeManifestRouteCount}) !== route-manifest (${manifestRouteCount})`,
    );
  }

  const expectedArtifactCount = manifestRouteCount * CAPTURE_LOCALES.length;
  const actualCount = (bundle.artifacts ?? []).length;
  if (actualCount < expectedArtifactCount) {
    errors.push(
      `bundle artifacts ${actualCount} < 期待 ${expectedArtifactCount}（全ルート × ${CAPTURE_LOCALES.join(', ')}）`,
    );
  }

  return {
    ok: errors.length === 0,
    errors,
    captureRunId: reviewRunId,
  };
}
