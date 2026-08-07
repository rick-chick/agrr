import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  findPrimaryColorDefinitions,
  scanPrimaryColorDefinitions,
  validateSinglePrimaryDefinition,
} from './check-primary-color-token-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND_ROOT = join(__dirname, '..');

test('findPrimaryColorDefinitions ignores non-primary tokens', () => {
  const text = `
    --color-primary-hover: #1d4ed8;
    --color-primary: #2d5016;
    --color-primary-light: #4a7c23;
  `;
  const defs = findPrimaryColorDefinitions(text);
  assert.equal(defs.length, 1);
  assert.equal(defs[0].value, '#2d5016');
});

test('validateSinglePrimaryDefinition rejects duplicate definitions outside styles.css', () => {
  const scan = [
    {
      file: '/workspace/frontend/src/styles.css',
      definitions: [{ line: 37, value: '#2d5016' }],
    },
    {
      file: '/workspace/frontend/src/app/app.css',
      definitions: [{ line: 10, value: '#2d5016' }],
    },
  ];
  const result = validateSinglePrimaryDefinition(scan);
  assert.equal(result.ok, false);
  assert.match(result.violations.join('\n'), /app\.css:10/);
});

test('frontend defines --color-primary only in styles.css', async () => {
  const scan = await scanPrimaryColorDefinitions(FRONTEND_ROOT);
  const result = validateSinglePrimaryDefinition(scan);
  assert.equal(
    result.ok,
    true,
    result.violations.length > 0
      ? result.violations.join('\n')
      : `expected 1 definition, found ${result.totalDefinitions}`,
  );
  const styles = await readFile(join(FRONTEND_ROOT, 'src/styles.css'), 'utf8');
  const defs = findPrimaryColorDefinitions(styles);
  assert.equal(defs[0].value, '#2d5016', 'brand green must be the canonical primary');
});
