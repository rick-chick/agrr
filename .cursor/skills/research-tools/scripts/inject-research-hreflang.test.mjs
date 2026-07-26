import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {
  researchHreflangCluster,
  renderResearchHreflangHeadTags,
} from './inject-research-hreflang-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const INJECT_SCRIPT = join(__dirname, 'inject-research-hreflang.mjs');

test('researchHreflangCluster maps JA crop report to EN counterpart', () => {
  const cluster = researchHreflangCluster(
    'research_reports/tomato/01_environmental_requirements/temperature_requirements.html'
  );
  assert.deepEqual(cluster, {
    canonicalPath:
      '/research/research_reports/tomato/01_environmental_requirements/temperature_requirements.html',
    jaPath:
      '/research/research_reports/tomato/01_environmental_requirements/temperature_requirements.html',
    enPath:
      '/research/en/research_reports/tomato/01_environmental_requirements/temperature_requirements.html',
  });
});

test('researchHreflangCluster maps EN crop report to JA counterpart', () => {
  const cluster = researchHreflangCluster(
    'en/research_reports/tomato/01_environmental_requirements/temperature_requirements.html'
  );
  assert.deepEqual(cluster, {
    canonicalPath:
      '/research/en/research_reports/tomato/01_environmental_requirements/temperature_requirements.html',
    jaPath:
      '/research/research_reports/tomato/01_environmental_requirements/temperature_requirements.html',
    enPath:
      '/research/en/research_reports/tomato/01_environmental_requirements/temperature_requirements.html',
  });
});

test('researchHreflangCluster maps locale index pages', () => {
  assert.deepEqual(researchHreflangCluster('index.html'), {
    canonicalPath: '/research/',
    jaPath: '/research/',
    enPath: '/research/en/',
  });
  assert.deepEqual(researchHreflangCluster('en/index.html'), {
    canonicalPath: '/research/en/',
    jaPath: '/research/',
    enPath: '/research/en/',
  });
});

test('renderResearchHreflangHeadTags emits canonical and bidirectional hreflang', () => {
  const tags = renderResearchHreflangHeadTags({
    canonicalPath: '/research/',
    jaPath: '/research/',
    enPath: '/research/en/',
  });
  assert.match(tags, /<link rel="canonical" href="https:\/\/agrr\.net\/research\/">/);
  assert.match(tags, /<link rel="alternate" hreflang="ja" href="https:\/\/agrr\.net\/research\/">/);
  assert.match(tags, /<link rel="alternate" hreflang="en" href="https:\/\/agrr\.net\/research\/en\/">/);
  assert.match(
    tags,
    /<link rel="alternate" hreflang="x-default" href="https:\/\/agrr\.net\/research\/">/
  );
});

test('inject-research-hreflang injects head tags into indexable HTML', () => {
  const dir = mkdtempSync(join(tmpdir(), 'research-hreflang-'));
  const researchDir = join(dir, 'public', 'research');
  const htmlPath = join(researchDir, 'index.html');
  const content = '<!DOCTYPE html><html><head><title>AGRR</title></head><body></body></html>';

  try {
    mkdirSync(researchDir, { recursive: true });
    writeFileSync(htmlPath, content, 'utf8');

    execFileSync('node', [INJECT_SCRIPT], {
      env: { ...process.env, RESEARCH_PATCH_ROOT: dir },
      stdio: 'pipe',
    });

    const patched = readFileSync(htmlPath, 'utf8');
    assert.match(patched, /agrr-research-hreflang:start/);
    assert.match(patched, /rel="canonical"/);
    assert.match(patched, /hreflang="ja"/);
    assert.match(patched, /hreflang="en"/);
    assert.match(patched, /hreflang="x-default"/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
