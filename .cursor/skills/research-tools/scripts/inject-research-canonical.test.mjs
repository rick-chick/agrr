import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { extractCanonicalHref } from '../../../../scripts/research-canonical-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const INJECT_SCRIPT = join(__dirname, 'inject-research-canonical.mjs');

test('inject-research-canonical adds canonical link to research HTML', () => {
  const dir = mkdtempSync(join(tmpdir(), 'research-canonical-'));
  const researchDir = join(dir, 'public', 'research', 'research_reports', 'radish', '03_pest_disease');
  const htmlPath = join(researchDir, 'major_pests.html');
  const content = '<html><head><title>test</title></head><body></body></html>';

  try {
    mkdirSync(researchDir, { recursive: true });
    writeFileSync(htmlPath, content, 'utf8');

    execFileSync('node', [INJECT_SCRIPT], {
      env: { ...process.env, RESEARCH_PATCH_ROOT: dir },
      stdio: 'pipe'
    });

    const patched = readFileSync(htmlPath, 'utf8');
    assert.equal(
      extractCanonicalHref(patched),
      'https://agrr.net/research/research_reports/radish/03_pest_disease/major_pests.html'
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
