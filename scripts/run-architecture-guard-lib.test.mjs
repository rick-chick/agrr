import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { runArchitectureGuard } from './run-architecture-guard-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('runArchitectureGuard passes on production repo tree', () => {
  const result = runArchitectureGuard(REPO_ROOT);
  assert.equal(result.ok, true, result.violations.map((v) => `${v.ruleId} ${v.file}: ${v.message}`).join('\n'));
});

test('runArchitectureGuard detects R1 forbidden use in agrr-domain source', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-r1-'));
  const domainSrc = join(root, 'crates/agrr-domain/src');
  mkdirSync(domainSrc, { recursive: true });
  writeFileSync(join(root, 'crates/agrr-domain/Cargo.toml'), '[dependencies]\nserde = "1"\n');
  writeFileSync(join(domainSrc, 'bad.rs'), 'use axum::Router;\n');
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'R1' && v.file.includes('bad.rs')));
});

test('runArchitectureGuard detects R1 forbidden dependency in agrr-domain Cargo.toml', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-cargo-'));
  mkdirSync(join(root, 'crates/agrr-domain/src'), { recursive: true });
  writeFileSync(
    join(root, 'crates/agrr-domain/Cargo.toml'),
    '[dependencies]\nserde = "1"\naxum = "0.7"\n',
  );
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'R1' && v.file.endsWith('Cargo.toml')));
});

test('runArchitectureGuard detects R2 gateway default() in agrr-domain source', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-r2-'));
  const domainSrc = join(root, 'crates/agrr-domain/src');
  mkdirSync(domainSrc, { recursive: true });
  writeFileSync(join(root, 'crates/agrr-domain/Cargo.toml'), '[dependencies]\n');
  writeFileSync(join(domainSrc, 'bad.rs'), 'let gw = FarmGateway.default();\n');
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'R2'));
});

test('runArchitectureGuard detects frontend component importing ../adapters/', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-fe-'));
  const componentDir = join(root, 'frontend/src/app/components/foo');
  mkdirSync(componentDir, { recursive: true });
  writeFileSync(
    join(componentDir, 'foo.component.ts'),
    "import { X } from '../adapters/foo.presenter';\n",
  );
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'FRONTEND' && v.file.includes('foo.component.ts')));
});

test('runArchitectureGuard detects R6 presenter importing agrr-adapters-', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-r6-'));
  const presenterDir = join(root, 'crates/agrr-server/src/foo');
  mkdirSync(presenterDir, { recursive: true });
  writeFileSync(
    join(presenterDir, 'foo_presenter.rs'),
    'use agrr_adapters_sqlite::FarmSqliteGateway;\n',
  );
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'R6' && v.file.includes('foo_presenter.rs')));
});

test('runArchitectureGuard detects R7 route handler without interactor delegation', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-r7-'));
  const serverSrc = join(root, 'crates/agrr-server/src');
  mkdirSync(serverSrc, { recursive: true });
  writeFileSync(
    join(serverSrc, 'bad_routes.rs'),
    `pub fn routes() -> Router<AppState> {
    Router::new().route("/api/v1/widgets", get(list_widgets))
}
async fn list_widgets() -> Json<Value> {
    Json(json!({"ok": true}))
}
`,
  );
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'R7'));
});
