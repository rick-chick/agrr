import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  checkAgentsMd,
  checkAgentsMdContract,
  checkClaudeMdNormPriority,
} from './check-agents-md-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

const THIN_AGENTS = `# Agent commands

## Test commands

| Task | Command |
| ---- | ------- |
| R4 contracts | \`scripts/run-rust-contract-tests.sh\` |
| Domain tests | \`.cursor/skills/test-common/scripts/run-test-rust-domain.sh\` |
| Frontend tests | \`.cursor/skills/test-common/scripts/run-test-frontend.sh\` |
| API rebuild | \`.cursor/skills/dev-docker/scripts/rebuild-restart.sh\` |

## Skills

| Task | Skill |
| ---- | ----- |
| Tests | [test-common](.cursor/skills/test-common/SKILL.md) |
| TDD | [tdd-on-edit](.cursor/skills/tdd-on-edit/SKILL.md) |
| Docker dev | [dev-docker](.cursor/skills/dev-docker/SKILL.md) |
| Bugs | [error-investigation](.cursor/skills/error-investigation/SKILL.md) |
`;

const CLAUDE_TESTS_FIRST = `# CLAUDE.md

## Norm priority

1. Observable tests (\`run-rust-contract-tests.sh\`, frontend/cargo runners)
2. [\`docs/architecture/LAYER-RULES.md\`](docs/architecture/LAYER-RULES.md)
3. [\`.cursor/rules/*.mdc\`](.cursor/rules/)

## Project
`;

test('checkAgentsMdContract passes on production repo tree', () => {
  const result = checkAgentsMdContract(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkAgentsMd fails when ARCHITECTURE.md is referenced', () => {
  const root = mkdtempSync(join(tmpdir(), 'agents-md-'));
  writeFileSync(join(root, 'AGENTS.md'), 'read ARCHITECTURE.md\n');
  const result = checkAgentsMd(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /ARCHITECTURE\.md/);
});

test('checkAgentsMd fails on host-specific absolute paths', () => {
  const root = mkdtempSync(join(tmpdir(), 'agents-md-'));
  writeFileSync(join(root, 'AGENTS.md'), 'cd /home/user/projects/agrr\n');
  const result = checkAgentsMd(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /host-specific absolute paths/);
});

test('checkClaudeMdNormPriority requires Observable tests as item 1', () => {
  const root = mkdtempSync(join(tmpdir(), 'claude-md-'));
  writeFileSync(
    join(root, 'CLAUDE.md'),
  `# CLAUDE.md

## Norm priority

1. [\`ARCHITECTURE.md\`](ARCHITECTURE.md)
2. Observable tests

## Project
`,
  );
  const result = checkClaudeMdNormPriority(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /ARCHITECTURE\.md/);
  assert.match(result.errors.join('\n'), /item 1 must be Observable tests/);
});

test('checkAgentsMd accepts thin command table and skill index', () => {
  const root = mkdtempSync(join(tmpdir(), 'agents-md-ok-'));
  writeFileSync(join(root, 'AGENTS.md'), THIN_AGENTS);
  const result = checkAgentsMd(root);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkClaudeMdNormPriority accepts tests-first norm priority', () => {
  const root = mkdtempSync(join(tmpdir(), 'claude-md-ok-'));
  writeFileSync(join(root, 'CLAUDE.md'), CLAUDE_TESTS_FIRST);
  const result = checkClaudeMdNormPriority(root);
  assert.equal(result.ok, true, result.errors.join('\n'));
});
