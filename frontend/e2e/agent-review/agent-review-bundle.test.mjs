import assert from 'node:assert/strict';
import { mkdtemp, writeFile, readFile, mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';

import {
  buildRunId,
  bundleCoversPngs,
  isActionableReviewRow,
  isGitLfsPointer,
  isUnreviewedResultToken,
  parseAgentReviewBundleContent,
  validateAgentReviewEvidenceChain,
} from './agent-review-bundle-lib.mjs';
import { bundlePath } from './agent-review-paths.mjs';

test('parseAgentReviewBundleContent rejects LFS pointer', () => {
  const { bundle, errors } = parseAgentReviewBundleContent(
    'version https://git-lfs.github.com/spec/v1\noid sha256:abc\nsize 1\n',
  );
  assert.equal(bundle, null);
  assert.match(errors[0], /LFS ポインタ/);
});

test('isGitLfsPointer detects LFS pointer text', () => {
  assert.equal(
    isGitLfsPointer('version https://git-lfs.github.com/spec/v1\noid sha256:abc\nsize 1\n'),
    true,
  );
  assert.equal(isGitLfsPointer('{"bundleVersion":1}\n'), false);
});

test('validateAgentReviewEvidenceChain fails when runId mismatches', () => {
  const bundle = {
    runId: 'run-a',
    routeManifestRouteCount: 2,
    artifacts: [{ png: 'home.ja.png' }, { png: 'home.en.png' }, { png: 'home.in.png' }],
  };
  const review = { captureRunId: 'run-b' };
  const result = validateAgentReviewEvidenceChain({
    bundle,
    review,
    manifestRouteCount: 2,
  });
  assert.equal(result.ok, false);
  assert.match(result.errors[0], /不一致/);
});

test('validateAgentReviewEvidenceChain fails when captureRunId is blank', () => {
  const bundle = {
    runId: 'run-a',
    routeManifestRouteCount: 1,
    artifacts: [{ png: 'home.ja.png' }, { png: 'home.en.png' }, { png: 'home.in.png' }],
  };
  const review = { captureRunId: '   ' };
  const result = validateAgentReviewEvidenceChain({
    bundle,
    review,
    manifestRouteCount: 1,
  });
  assert.equal(result.ok, false);
  assert.match(result.errors[0], /captureRunId/);
});

test('validateAgentReviewEvidenceChain passes when captureRunId matches bundle', () => {
  const bundle = {
    runId: 'run-a',
    routeManifestRouteCount: 1,
    artifacts: [{ png: 'home.ja.png' }, { png: 'home.en.png' }, { png: 'home.in.png' }],
  };
  const review = { captureRunId: 'run-a' };
  const result = validateAgentReviewEvidenceChain({
    bundle,
    review,
    manifestRouteCount: 1,
  });
  assert.equal(result.ok, true);
});

test('isActionableReviewRow rejects 未レビュー', () => {
  assert.equal(
    isActionableReviewRow({
      layout: '未レビュー',
      i18n: 'OK',
      note: 'なし',
    }),
    false,
  );
  assert.equal(
    isActionableReviewRow({
      layout: '注意',
      i18n: 'OK',
      note: 'なし',
    }),
    true,
  );
});

test('bundleCoversPngs checks artifact list', () => {
  const bundle = {
    artifacts: [
      { png: 'about.ja.png' },
      { png: 'about.en.png' },
      { png: 'about.in.png' },
    ],
  };
  const ok = bundleCoversPngs(bundle, ['about.ja.png', 'about.en.png', 'about.in.png']);
  assert.equal(ok.ok, true);
  const bad = bundleCoversPngs(bundle, ['missing.ja.png']);
  assert.equal(bad.ok, false);
  assert.deepEqual(bad.missing, ['missing.ja.png']);
});

test('generateCaptureBundle writes bundle under tmp/agent-review', async () => {
  const frontend = await mkdtemp(join(tmpdir(), 'agrr-bundle-'));
  const outDir = join(frontend, 'e2e/agent-review/out');
  await mkdir(outDir, { recursive: true });

  const manifest = {
    generatedAt: '2026-01-01T00:00:00.000Z',
    routes: [{ pattern: '', url: '/' }],
  };
  await writeFile(
    join(frontend, 'e2e/route-manifest.json'),
    JSON.stringify(manifest),
  );
  await writeFile(join(outDir, 'home.ja.png'), 'fake-png-bytes');

  const { generateCaptureBundle } = await import('./agent-review-bundle-lib.mjs');
  const bundle = await generateCaptureBundle({
    frontendRoot: frontend,
    repoRoot: frontend,
  });

  assert.equal(bundle.artifacts.length, 1);
  assert.equal(bundle.artifacts[0].png, 'home.ja.png');
  const saved = JSON.parse(await readFile(bundlePath(frontend), 'utf8'));
  assert.equal(saved.runId, bundle.runId);
});

test('buildRunId uses git short hash', () => {
  assert.equal(buildRunId('abcdef1234567890', '2026-01-01T00:00:00.000Z'), '2026-01-01T00:00:00.000Z-abcdef1');
});

test('isUnreviewedResultToken', () => {
  assert.equal(isUnreviewedResultToken('未レビュー'), true);
  assert.equal(isUnreviewedResultToken('OK'), false);
});
