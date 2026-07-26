import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {
  patchResearchFooterBrand,
  RESEARCH_FOOTER_NEW_HTML,
  RESEARCH_FOOTER_OLD_HTML
} from './patch-research-footer-brand-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const PATCH_SCRIPT = join(__dirname, 'patch-research-footer-brand.mjs');

test('patchResearchFooterBrand prioritizes AGRR in prerendered footer HTML', () => {
  const content = `<footer><p class="message">${RESEARCH_FOOTER_OLD_HTML}</p></footer>`;
  const patched = patchResearchFooterBrand(content);
  assert.match(patched, />AGRR<\/a>/);
  assert.ok(patched.includes(RESEARCH_FOOTER_NEW_HTML));
  assert.doesNotMatch(patched, />agrr\.net<\/a>/);
});

test('patch-research-footer-brand updates escaped VitePress footer message', () => {
  const dir = mkdtempSync(join(tmpdir(), 'research-footer-patch-'));
  const researchDir = join(dir, 'public', 'research');
  const htmlPath = join(researchDir, 'index.html');
  const content =
    '<html><body><script>window.__VP_SITE_DATA__=JSON.parse("{\\"themeConfig\\":{\\"footer\\":{\\"message\\":\\"<a href=\\\\\\"https://github.com/langchain-ai/open_deep_research\\\\\\" target=\\\\\\"_blank\\\\\\" rel=\\\\\\"noopener\\\\\\">OpenDeepResearch</a> ｜ <a href=\\\\\\"https://agrr.net\\\\\\" target=\\\\\\"_blank\\\\\\" rel=\\\\\\"noopener\\\\\\">agrr.net</a>\\"}}}");</script></body></html>';

  try {
    mkdirSync(researchDir, { recursive: true });
    writeFileSync(htmlPath, content, 'utf8');

    execFileSync('node', [PATCH_SCRIPT], {
      env: { ...process.env, RESEARCH_PATCH_ROOT: dir },
      stdio: 'pipe'
    });

    const patched = readFileSync(htmlPath, 'utf8');
    assert.match(patched, />AGRR<\/a>/);
    assert.doesNotMatch(patched, />agrr\.net<\/a>/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
