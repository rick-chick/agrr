import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const PATCH_SCRIPT = join(__dirname, 'patch-research-vitepress-links.mjs');

test('patch-research-vitepress-links adds .html to escaped VitePress sidebar links', () => {
  const dir = mkdtempSync(join(tmpdir(), 'research-patch-'));
  const researchDir = join(dir, 'public', 'research', 'research_reports', 'tomato');
  const htmlPath = join(researchDir, 'page.html');
  const content =
    '<html><head></head><body><script>window.__VP_SITE_DATA__=JSON.parse("{\\"themeConfig\\":{\\"nav\\":[{\\"link\\":\\"/research_reports/tomato/01_environmental_requirements/temperature_requirements\\"}]}}");</script></body></html>';

  try {
    mkdirSync(researchDir, { recursive: true });
    writeFileSync(htmlPath, content, 'utf8');

    execFileSync('node', [PATCH_SCRIPT], {
      env: { ...process.env, RESEARCH_PATCH_ROOT: dir },
      stdio: 'pipe'
    });

    const patched = readFileSync(htmlPath, 'utf8');
    assert.match(patched, /temperature_requirements\.html/);
    assert.doesNotMatch(patched, /temperature_requirements\\"/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
