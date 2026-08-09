import assert from 'node:assert/strict';
import test from 'node:test';

import { ALLOWED_READ_PREFIXES, createRepoFsAccess } from './fs-access.mjs';
import { DEFAULT_REPO_ROOT } from './repo-root.mjs';
import {
  AGRR_REPO_MCP_TOOL_NAMES,
  createAgrrRepoMcpToolHandlers,
  getFrontendLayers,
  listBoundedContexts,
  listCrates,
  listTestCommands,
} from './tools.mjs';

test('MCP tool handlers expose four repo structure tools', () => {
  const fsAccess = createRepoFsAccess(DEFAULT_REPO_ROOT);
  const tools = createAgrrRepoMcpToolHandlers({
    repoRoot: DEFAULT_REPO_ROOT,
    fsAccess,
  });
  assert.deepEqual(Object.keys(tools).sort(), [...AGRR_REPO_MCP_TOOL_NAMES].sort());
});

test('list_bounded_contexts returns domain directories with generated_at', async () => {
  const fsAccess = createRepoFsAccess(DEFAULT_REPO_ROOT);
  const result = await listBoundedContexts(DEFAULT_REPO_ROOT, fsAccess);
  assert.match(result.generated_at, /^\d{4}-\d{2}-\d{2}T/);
  assert.ok(result.bounded_contexts.includes('crop'));
  assert.ok(result.bounded_contexts.includes('farm'));
});

test('list_crates returns workspace crate metadata with generated_at', async () => {
  const fsAccess = createRepoFsAccess(DEFAULT_REPO_ROOT);
  const result = await listCrates(DEFAULT_REPO_ROOT, fsAccess);
  assert.match(result.generated_at, /^\d{4}-\d{2}-\d{2}T/);
  const domain = result.crates.find((c) => c.name === 'agrr-domain');
  assert.ok(domain);
  assert.match(domain.description, /domain/i);
});

test('list_test_commands returns script paths and existence with generated_at', async () => {
  const result = await listTestCommands(DEFAULT_REPO_ROOT);
  assert.match(result.generated_at, /^\d{4}-\d{2}-\d{2}T/);
  assert.equal(result.commands.length, 3);
  const contract = result.commands.find((c) => c.name === 'run-rust-contract-tests');
  assert.equal(contract.path, 'scripts/run-rust-contract-tests.sh');
  assert.equal(contract.exists, true);
  const frontend = result.commands.find((c) => c.name === 'run-test-frontend');
  assert.equal(frontend.exists, true);
});

test('get_frontend_layers reports layer file counts with generated_at', async () => {
  const fsAccess = createRepoFsAccess(DEFAULT_REPO_ROOT);
  const result = await getFrontendLayers(DEFAULT_REPO_ROOT, fsAccess);
  assert.match(result.generated_at, /^\d{4}-\d{2}-\d{2}T/);
  const domain = result.layers.find((l) => l.layer === 'domain');
  assert.equal(domain.exists, true);
  assert.ok(domain.file_count > 0);
});

test('fs readdir and readFile only touch crates/, frontend/, or scripts/', async () => {
  const accessed = [];
  const fsAccess = createRepoFsAccess(DEFAULT_REPO_ROOT, {
    onRead: (repoRelative, op) => {
      accessed.push({ repoRelative, op });
    },
  });

  await listBoundedContexts(DEFAULT_REPO_ROOT, fsAccess);
  await listCrates(DEFAULT_REPO_ROOT, fsAccess);
  await listTestCommands(DEFAULT_REPO_ROOT);
  await getFrontendLayers(DEFAULT_REPO_ROOT, fsAccess);

  assert.ok(accessed.length > 0, 'expected filesystem reads during tool execution');
  for (const { repoRelative } of accessed) {
    const normalized = repoRelative.replace(/\\/g, '/');
    const allowed = ALLOWED_READ_PREFIXES.some(
      (prefix) =>
        normalized === prefix.replace(/\/$/, '') || normalized.startsWith(prefix),
    );
    assert.ok(
      allowed,
      `unexpected fs read path: ${normalized} (allowed: ${ALLOWED_READ_PREFIXES.join(', ')})`,
    );
    assert.ok(!normalized.endsWith('.md'), `markdown read forbidden: ${normalized}`);
  }
});

test('tool handlers return JSON including generated_at', async () => {
  const fsAccess = createRepoFsAccess(DEFAULT_REPO_ROOT);
  const tools = createAgrrRepoMcpToolHandlers({
    repoRoot: DEFAULT_REPO_ROOT,
    fsAccess,
  });
  for (const name of AGRR_REPO_MCP_TOOL_NAMES) {
    const response = await tools[name].handler({});
    const payload = JSON.parse(response.content[0].text);
    assert.match(payload.generated_at, /^\d{4}-\d{2}-\d{2}T/, name);
  }
});
