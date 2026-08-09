import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

import {
  ALLOWED_READ_PREFIXES,
  createSafeFs,
  resolveAllowedPath,
} from './safe-fs.mjs';
import {
  AGRR_REPO_MCP_TOOL_NAMES,
  createAgrrRepoMcpToolHandlers,
} from './tools.mjs';
import { createRepoScanner } from './repo-scanner.mjs';

const REPO_ROOT = path.resolve(
  fileURLToPath(new URL('.', import.meta.url)),
  '../../..',
);

test('ALLOWED_READ_PREFIXES covers crates, frontend, scripts only', () => {
  assert.deepEqual(ALLOWED_READ_PREFIXES, ['crates/', 'frontend/', 'scripts/']);
});

test('resolveAllowedPath rejects markdown and docs paths', () => {
  assert.throws(() => resolveAllowedPath(REPO_ROOT, 'ARCHITECTURE.md'));
  assert.throws(() => resolveAllowedPath(REPO_ROOT, 'docs/architecture/LAYER-RULES.md'));
  assert.throws(() => resolveAllowedPath(REPO_ROOT, '.cursor/skills/test-common/scripts/run-test-rust-domain.sh'));
});

test('resolveAllowedPath accepts crates, frontend, scripts', () => {
  assert.equal(
    resolveAllowedPath(REPO_ROOT, 'crates/agrr-domain/src'),
    path.resolve(REPO_ROOT, 'crates/agrr-domain/src'),
  );
  assert.equal(
    resolveAllowedPath(REPO_ROOT, 'frontend/src/app/domain'),
    path.resolve(REPO_ROOT, 'frontend/src/app/domain'),
  );
  assert.equal(
    resolveAllowedPath(REPO_ROOT, 'scripts/run-rust-contract-tests.sh'),
    path.resolve(REPO_ROOT, 'scripts/run-rust-contract-tests.sh'),
  );
});

test('createSafeFs readdir/readFile only succeed under allowed prefixes', async () => {
  const safeFs = createSafeFs(REPO_ROOT);
  await assert.rejects(() => safeFs.readFile('README.md', 'utf8'));
  const entries = await safeFs.readdir('crates/agrr-domain/src', { withFileTypes: true });
  assert.ok(entries.length > 0);
});

test('MCP tool handlers expose four repo structure tools', () => {
  const scanner = createRepoScanner({ repoRoot: REPO_ROOT });
  const tools = createAgrrRepoMcpToolHandlers(scanner);
  assert.deepEqual(Object.keys(tools).sort(), [...AGRR_REPO_MCP_TOOL_NAMES].sort());
});

test('list_bounded_contexts returns domain directories with generated_at', async () => {
  const scanner = createRepoScanner({ repoRoot: REPO_ROOT });
  const tools = createAgrrRepoMcpToolHandlers(scanner);
  const result = await tools.list_bounded_contexts.handler({});
  const payload = JSON.parse(result.content[0].text);
  assert.ok(payload.generated_at);
  assert.match(payload.generated_at, /^\d{4}-\d{2}-\d{2}T/);
  assert.ok(Array.isArray(payload.contexts));
  assert.ok(payload.contexts.includes('crop'));
  assert.ok(payload.contexts.includes('farm'));
});

test('list_crates returns workspace crate names and descriptions', async () => {
  const scanner = createRepoScanner({ repoRoot: REPO_ROOT });
  const tools = createAgrrRepoMcpToolHandlers(scanner);
  const result = await tools.list_crates.handler({});
  const payload = JSON.parse(result.content[0].text);
  assert.ok(payload.generated_at);
  assert.ok(Array.isArray(payload.crates));
  const domain = payload.crates.find((c) => c.name === 'agrr-domain');
  assert.ok(domain);
  assert.ok(typeof domain.description === 'string');
});

test('list_test_commands returns script paths and existence', async () => {
  const scanner = createRepoScanner({ repoRoot: REPO_ROOT });
  const tools = createAgrrRepoMcpToolHandlers(scanner);
  const result = await tools.list_test_commands.handler({});
  const payload = JSON.parse(result.content[0].text);
  assert.ok(payload.generated_at);
  assert.ok(Array.isArray(payload.commands));
  const contract = payload.commands.find((c) => c.path === 'scripts/run-rust-contract-tests.sh');
  assert.ok(contract);
  assert.equal(contract.exists, true);
  const domain = payload.commands.find(
    (c) => c.path === '.cursor/skills/test-common/scripts/run-test-rust-domain.sh',
  );
  assert.ok(domain);
  assert.equal(domain.exists, true);
  const frontend = payload.commands.find(
    (c) => c.path === '.cursor/skills/test-common/scripts/run-test-frontend.sh',
  );
  assert.ok(frontend);
  assert.equal(frontend.exists, true);
});

test('get_frontend_layers returns layer dirs with file counts', async () => {
  const scanner = createRepoScanner({ repoRoot: REPO_ROOT });
  const tools = createAgrrRepoMcpToolHandlers(scanner);
  const result = await tools.get_frontend_layers.handler({});
  const payload = JSON.parse(result.content[0].text);
  assert.ok(payload.generated_at);
  assert.ok(Array.isArray(payload.layers));
  const domain = payload.layers.find((l) => l.name === 'domain');
  assert.ok(domain);
  assert.equal(domain.exists, true);
  assert.ok(domain.file_count > 0);
  const components = payload.layers.find((l) => l.name === 'components');
  assert.ok(components);
  assert.equal(components.exists, true);
});
