import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  checkAgentsCommandSync,
  checkAlwaysApplyRules,
  checkBoundedContextSync,
  checkCommandTableSync,
  checkDocInternalLinks,
  checkDocStalePaths,
  checkDomainFallbackPolicy,
} from './check-doc-freshness-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('checkDocInternalLinks passes on production repo tree', () => {
  const result = checkDocInternalLinks(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkDocInternalLinks fails on broken relative link', () => {
  const root = mkdtempSync(join(tmpdir(), 'doc-link-'));
  mkdirSync(join(root, 'docs'), { recursive: true });
  writeFileSync(join(root, 'README.md'), '[bad](./docs/missing.md)\n');
  const result = checkDocInternalLinks(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /missing\.md/);
});

test('checkDocStalePaths passes on production repo tree', () => {
  const result = checkDocStalePaths(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkDocStalePaths fails on stale lib/domain outside allowlist', () => {
  const root = mkdtempSync(join(tmpdir(), 'doc-stale-'));
  mkdirSync(join(root, 'docs', 'design'), { recursive: true });
  writeFileSync(join(root, 'docs', 'design', 'bad.md'), 'see lib/domain/foo\n');
  const result = checkDocStalePaths(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /lib\/domain/);
});

test('checkAlwaysApplyRules passes on production repo tree', () => {
  const result = checkAlwaysApplyRules(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkAlwaysApplyRules fails when extra alwaysApply file exists', () => {
  const root = mkdtempSync(join(tmpdir(), 'alwaysapply-'));
  mkdirSync(join(root, '.cursor/rules'), { recursive: true });
  writeFileSync(
    join(root, 'CLAUDE.md'),
    '## Always-apply rules\n@.cursor/rules/git-operational-constraints.mdc\n\n## Contextual rules\n',
  );
  writeFileSync(
    join(root, '.cursor/rules/git-operational-constraints.mdc'),
    '---\nalwaysApply: true\n---\n# git\n',
  );
  writeFileSync(
    join(root, '.cursor/rules/extra.mdc'),
    '---\nalwaysApply: true\n---\n# extra\n',
  );
  const result = checkAlwaysApplyRules(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /alwaysApply: true count/);
});

test('checkDocStalePaths allows docs/migration/archive historical paths', () => {
  const root = mkdtempSync(join(tmpdir(), 'doc-stale-ok-'));
  mkdirSync(join(root, 'docs', 'migration', 'archive'), { recursive: true });
  writeFileSync(
    join(root, 'docs', 'migration', 'archive', 'note.md'),
    'Ruby lib/domain was removed.\n',
  );
  const result = checkDocStalePaths(root);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkBoundedContextSync passes on production repo tree', () => {
  const result = checkBoundedContextSync(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkBoundedContextSync fails when ARCHITECTURE.md omits a bounded context', () => {
  const root = mkdtempSync(join(tmpdir(), 'bc-sync-'));
  mkdirSync(join(root, 'crates/agrr-domain/src/crop'), { recursive: true });
  mkdirSync(join(root, 'crates/agrr-domain/src/farm'), { recursive: true });
  mkdirSync(join(root, 'crates/agrr-domain/src/shared'), { recursive: true });
  writeFileSync(
    join(root, 'ARCHITECTURE.md'),
    '**Bounded contexts** (`crates/agrr-domain/src/`): `crop`.\n',
  );
  const result = checkBoundedContextSync(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /farm/);
});

test('checkCommandTableSync passes on production repo tree', () => {
  const result = checkCommandTableSync(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkCommandTableSync fails when CLAUDE.md references missing script', () => {
  const root = mkdtempSync(join(tmpdir(), 'cmd-sync-'));
  writeFileSync(
    join(root, 'CLAUDE.md'),
    `# CLAUDE.md

## Commands

| Task | Command |
| ---- | ------- |
| Missing | \`scripts/does-not-exist.sh\` |

## Workflows
`,
  );
  const result = checkCommandTableSync(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /does-not-exist\.sh/);
});

test('checkAgentsCommandSync passes on production repo tree', () => {
  const result = checkAgentsCommandSync(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkAgentsCommandSync fails when AGENTS.md references missing script', () => {
  const root = mkdtempSync(join(tmpdir(), 'agents-cmd-'));
  writeFileSync(
    join(root, 'AGENTS.md'),
    `# Agent commands

## Test commands

| Task | Command |
| ---- | ------- |
| Bad | \`scripts/missing-agents-script.sh\` |
`,
  );
  const result = checkAgentsCommandSync(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /missing-agents-script\.sh/);
});

test('checkDomainFallbackPolicy passes on production repo tree', () => {
  const result = checkDomainFallbackPolicy(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkDomainFallbackPolicy fails when fallback.mdc is missing', () => {
  const root = mkdtempSync(join(tmpdir(), 'domain-fallback-'));
  writeFileSync(join(root, 'ARCHITECTURE.md'), '## Domain fallback policy\n\nsee fallback.mdc\n');
  mkdirSync(join(root, '.cursor/skills/error-investigation/references'), {
    recursive: true,
  });
  writeFileSync(
    join(root, '.cursor/skills/error-investigation/references/CHECKLIST.md'),
    '- 根本原因優先: [fallback.mdc](../../../rules/fallback.mdc)\n',
  );
  const result = checkDomainFallbackPolicy(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /fallback\.mdc: missing/);
});
