import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  BASE_PATH_GUARD_MARKER_END,
  BASE_PATH_GUARD_MARKER_START,
  injectResearchBasePathGuard,
  withResearchPrefix,
} from './research-base-path-guard-lib.mjs';

test('withResearchPrefix restores /research for JA report paths', () => {
  assert.equal(
    withResearchPrefix('/research_reports/tomato/page'),
    '/research/research_reports/tomato/page',
  );
});

test('withResearchPrefix restores /research for EN report paths', () => {
  assert.equal(
    withResearchPrefix('/en/research_reports/tomato/page'),
    '/research/en/research_reports/tomato/page',
  );
});

test('withResearchPrefix leaves already-prefixed paths unchanged', () => {
  assert.equal(
    withResearchPrefix('/research/research_reports/tomato/page'),
    '/research/research_reports/tomato/page',
  );
});

test('withResearchPrefix leaves unrelated paths unchanged', () => {
  assert.equal(withResearchPrefix('/research/'), '/research/');
  assert.equal(withResearchPrefix('/about'), '/about');
});

test('injectResearchBasePathGuard inserts snippet before </head>', () => {
  const html = '<html><head><title>x</title></head><body></body></html>';
  const next = injectResearchBasePathGuard(html);
  assert.match(next, new RegExp(`${BASE_PATH_GUARD_MARKER_START}[\\s\\S]*${BASE_PATH_GUARD_MARKER_END}`));
  assert.match(next, /withResearchPrefix/);
  assert.ok(next.indexOf(BASE_PATH_GUARD_MARKER_START) < next.indexOf('</head>'));
});

test('injectResearchBasePathGuard replaces existing marker block idempotently', () => {
  const first = injectResearchBasePathGuard('<html><head></head><body></body></html>');
  const second = injectResearchBasePathGuard(first);
  assert.equal(second, first);
  assert.equal(
    (second.match(new RegExp(BASE_PATH_GUARD_MARKER_START, 'g')) ?? []).length,
    1,
  );
});

test('injectResearchBasePathGuard throws when </head> is missing', () => {
  assert.throws(
    () => injectResearchBasePathGuard('<html><body></body></html>'),
    /missing <\/head>/i,
  );
});

test('inject-research-base-path-guard script patches HTML under RESEARCH_PATCH_ROOT', () => {
  const __dirname = fileURLToPath(new URL('.', import.meta.url));
  const INJECT_SCRIPT = join(__dirname, 'inject-research-base-path-guard.mjs');
  const root = mkdtempSync(join(tmpdir(), 'research-base-guard-'));
  const researchDir = join(root, 'public', 'research', 'research_reports', 'tomato');
  mkdirSync(researchDir, { recursive: true });

  const html = '<html><head><title>page</title></head><body></body></html>';
  const path = join(researchDir, 'page.html');
  writeFileSync(path, html, 'utf8');

  try {
    const result = spawnSync('node', [INJECT_SCRIPT], {
      env: { ...process.env, RESEARCH_PATCH_ROOT: root },
      encoding: 'utf8',
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);

    const next = readFileSync(path, 'utf8');
    assert.match(next, /agrr-research-base-path-guard:start/);
    assert.match(next, /withResearchPrefix/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
