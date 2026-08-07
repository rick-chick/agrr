import assert from 'node:assert/strict';
import { mkdtemp, writeFile, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';

import {
  buildRunId,
  bundleCoversPngs,
  isActionableReviewRow,
  isUnreviewedResultToken,
  parseVisualReviewCaptureRunId,
  stampVisualReviewCaptureRunId,
  validateAgentReviewEvidenceChain,
} from './agent-review-bundle-lib.mjs';

test('parseVisualReviewCaptureRunId reads meta stamp', () => {
  const md = `
## メタ

- **captureRunId**: \`2026-08-07T09:00:00.000Z-abc1234\`

## サマリ表
`;
  assert.equal(
    parseVisualReviewCaptureRunId(md),
    '2026-08-07T09:00:00.000Z-abc1234',
  );
});

test('stampVisualReviewCaptureRunId replaces existing line', () => {
  const md = '## メタ\n\n- **captureRunId**: `old`\n\n## サマリ表\n';
  const out = stampVisualReviewCaptureRunId(md, 'new-run');
  assert.match(out, /captureRunId.*new-run/);
  assert.doesNotMatch(out, /`old`/);
});

test('validateAgentReviewEvidenceChain fails when runId mismatches', () => {
  const bundle = {
    runId: 'run-a',
    routeManifestRouteCount: 2,
    artifacts: [{ png: 'home.ja.png' }, { png: 'home.en.png' }, { png: 'home.in.png' }],
  };
  const md = '## メタ\n\n- **captureRunId**: `run-b`\n';
  const result = validateAgentReviewEvidenceChain({
    bundle,
    reviewMarkdown: md,
    manifestRouteCount: 2,
  });
  assert.equal(result.ok, false);
  assert.match(result.errors[0], /不一致/);
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

test('generateCaptureBundle writes bundle with artifacts', async () => {
  const frontend = await mkdtemp(join(tmpdir(), 'agrr-bundle-'));
  const outDir = join(frontend, 'e2e/agent-review/out');
  await import('node:fs/promises').then((fs) => fs.mkdir(outDir, { recursive: true }));

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
  const saved = JSON.parse(
    await readFile(join(frontend, 'e2e/agent-review/agent-review-bundle.json'), 'utf8'),
  );
  assert.equal(saved.runId, bundle.runId);
});
