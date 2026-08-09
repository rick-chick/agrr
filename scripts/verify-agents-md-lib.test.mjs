import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { verifyAgentsMd } from './verify-agents-md-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('verifyAgentsMd passes on production repo tree', () => {
  const result = verifyAgentsMd(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('verifyAgentsMd fails when AGENTS.md exceeds line limit', () => {
  const root = mkdtempSync(join(tmpdir(), 'agents-md-'));
  writeFileSync(join(root, 'AGENTS.md'), `${'# line\n'.repeat(41)}`);
  writeFileSync(
    join(root, 'CLAUDE.md'),
    '## Norm priority\n\n1. Observable tests (`run-rust-contract-tests.sh`)\n',
  );
  const result = verifyAgentsMd(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /max 40/);
});

test('verifyAgentsMd fails when CLAUDE Norm priority leads with ARCHITECTURE.md', () => {
  const root = mkdtempSync(join(tmpdir(), 'agents-md-'));
  writeFileSync(join(root, 'AGENTS.md'), minimalAgentsMd());
  writeFileSync(
    join(root, 'CLAUDE.md'),
    '## Norm priority\n\n1. [`ARCHITECTURE.md`](ARCHITECTURE.md)\n2. Observable tests\n',
  );
  const result = verifyAgentsMd(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /ARCHITECTURE\.md/);
});

function minimalAgentsMd() {
  return `# Agent quick reference

## Commands

| Task | Command |
| ---- | ------- |
| R4 | \`scripts/run-rust-contract-tests.sh\` |
| Domain | \`.cursor/skills/test-common/scripts/run-test-rust-domain.sh\` |
| Frontend | \`.cursor/skills/test-common/scripts/run-test-frontend.sh\` |
| Docker | \`.cursor/skills/dev-docker/scripts/rebuild-restart.sh\` |

## Skills

- [test-common](.cursor/skills/test-common/SKILL.md)
- [tdd-on-edit](.cursor/skills/tdd-on-edit/SKILL.md)
- [dev-docker](.cursor/skills/dev-docker/SKILL.md)
- [error-investigation](.cursor/skills/error-investigation/SKILL.md)
`;
}
