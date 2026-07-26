import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import assert from 'node:assert/strict';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const PATCH_SCRIPT = join(__dirname, 'patch-research-footer-brand.mjs');

test('patch-research-footer-brand puts AGRR before OpenDeepResearch in footer message', () => {
  const root = mkdtempSync(join(tmpdir(), 'research-footer-'));
  const researchDir = join(root, 'public', 'research');
  mkdirSync(researchDir, { recursive: true });

  const html =
    '<html><body><script>window.__VP_SITE_DATA__=JSON.parse("{\\"themeConfig\\":{\\"footer\\":{\\"message\\":\\"<a href=\\\\\\"https://github.com/langchain-ai/open_deep_research\\\\\\">OpenDeepResearch</a> ｜ <a href=\\\\\\"https://agrr.net\\\\\\">agrr.net</a>\\"}}}");</script></body></html>';
  const path = join(researchDir, 'index.html');
  writeFileSync(path, html, 'utf8');

  const result = spawnSync('node', [PATCH_SCRIPT], {
    env: { ...process.env, RESEARCH_PATCH_ROOT: root },
    encoding: 'utf8'
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);

  const next = readFileSync(path, 'utf8');
  assert.match(next, /AGRR/);
  assert.doesNotMatch(next, /OpenDeepResearch.*?｜.*?agrr\.net/);
  assert.match(next, /agrr\.net.*?OpenDeepResearch|AGRR.*?OpenDeepResearch/s);
});
