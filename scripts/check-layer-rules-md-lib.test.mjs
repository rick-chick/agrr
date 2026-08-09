import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { checkLayerRulesMd } from './check-layer-rules-md-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('checkLayerRulesMd passes on production repo tree', () => {
  const result = checkLayerRulesMd(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkLayerRulesMd fails when file exceeds line limit', () => {
  const root = mkdtempSync(join(tmpdir(), 'layer-rules-'));
  mkdirSync(join(root, 'docs/architecture'), { recursive: true });
  const body = '# Layer rules\n\n' + 'x\n'.repeat(120);
  writeFileSync(join(root, 'docs/architecture/LAYER-RULES.md'), body);
  const result = checkLayerRulesMd(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /max 100/);
});

test('checkLayerRulesMd fails on forbidden Ruby-era strings', () => {
  const root = mkdtempSync(join(tmpdir(), 'layer-rules-'));
  mkdirSync(join(root, 'docs/architecture'), { recursive: true });
  writeFileSync(
    join(root, 'docs/architecture/LAYER-RULES.md'),
  `# Layer rules

| Rule | Summary |
| ---- | ------- |
| **R0** | ok |
| **R1** | ok |
| **R2** | ok |
| **R3** | ok |
| **R4** | ok |
| **R5** | ok |
| **R6** | ok |
| **R7** | ok |
| **R8** | ok |
| **R9** | ok |

see lib/domain and scripts/run-architecture-guard.sh
`,
  );
  const result = checkLayerRulesMd(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /lib\/domain/);
});
