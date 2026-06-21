import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = dirname(fileURLToPath(import.meta.url));

test('resolve-capture-urls imports MASTER_SEGMENTS into module scope', async () => {
  const text = await readFile(join(DIR, 'resolve-capture-urls.ts'), 'utf8');
  assert.match(
    text,
    /import\s*\{[^}]*\bMASTER_SEGMENTS\b[^}]*\}\s*from\s*['"]\.\/shared\/baseline-ids['"]/,
    'MASTER_SEGMENTS must be imported (not only re-exported) for use in buildResolvedCaptureIds',
  );
});
