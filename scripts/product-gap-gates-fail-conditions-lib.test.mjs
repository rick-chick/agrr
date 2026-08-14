import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { checkProductGapGatesFailConditions } from './product-gap-gates-fail-conditions-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('checkProductGapGatesFailConditions passes on production repo tree', () => {
  const result = checkProductGapGatesFailConditions(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkProductGapGatesFailConditions fails when gates.md lacks deep-dive stop fail rows', () => {
  const root = mkdtempSync(join(tmpdir(), 'pg-gates-'));
  const skillDir = join(root, '.cursor/skills/product-gap-to-issues/references');
  mkdirSync(skillDir, { recursive: true });
  writeFileSync(
    join(skillDir, 'gates.md'),
    '# gates\n## G2\n### fail\n| G2-1 | foo |\n',
  );
  writeFileSync(join(skillDir, 'subagent-prompts.md'), '## §4\ntheme-selection.md theme-deep-dive.md\n## §5\ntheme-selection.md\n');
  writeFileSync(join(root, '.cursor/skills/product-gap-to-issues/SKILL.md'), '## フェーズ 3\ngates.md G2-5\n## フェーズ 4\ngates.md G2-6\n');
  const result = checkProductGapGatesFailConditions(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /G2-5|deep-dive stop/);
});
