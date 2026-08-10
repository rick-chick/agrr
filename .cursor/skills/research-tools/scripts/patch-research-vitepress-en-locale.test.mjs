import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const PATCH_SCRIPT = join(__dirname, 'patch-research-vitepress-en-locale.mjs');

test('patch-research-vitepress-en-locale fixes EN base and sidebar paths', () => {
  const dir = mkdtempSync(join(tmpdir(), 'research-en-locale-'));
  const htmlPath = join(
    dir,
    'public',
    'research',
    'en',
    'research_reports',
    'potato',
    'page.html'
  );
  const content =
    '<html><body><script>window.__VP_SITE_DATA__=JSON.parse("{\\"base\\":\\"/research/\\",\\"themeConfig\\":{\\"sidebar\\":{\\"/research_reports/potato/\\":[{\\"link\\":\\"/research_reports/potato/01_environmental_requirements/gdd_requirements\\"}]}}}");</script><a href="/research/research_reports/potato/01_environmental_requirements/gdd_requirements.html">x</a></body></html>';

  try {
    mkdirSync(join(dir, 'public', 'research', 'en', 'research_reports', 'potato'), {
      recursive: true,
    });
    writeFileSync(htmlPath, content, 'utf8');

    execFileSync('node', [PATCH_SCRIPT], {
      env: { ...process.env, RESEARCH_PATCH_ROOT: dir },
      stdio: 'pipe',
    });

    const patched = readFileSync(htmlPath, 'utf8');
    assert.match(patched, /\\"base\\":\\"\/research\/en\/\\"/);
    assert.match(patched, /\\"\/en\/research_reports\/potato\/\\"/);
    assert.match(patched, /\/research\/en\/research_reports\/potato/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
