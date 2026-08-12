import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  formatViolations,
  runArchitectureGuard,
} from './run-architecture-guard-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');
const GUARD_SCRIPT = join(REPO_ROOT, 'scripts/run-architecture-guard.sh');

function writeMinimalArchGuardTree(root) {
  mkdirSync(join(root, 'crates/agrr-domain/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-domain/Cargo.toml'), '[dependencies]\nserde = "1"\n');
  mkdirSync(join(root, 'crates/agrr-server/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-server/src/lib.rs'), '');
  mkdirSync(join(root, 'frontend/src/app/components'), { recursive: true });
  mkdirSync(join(root, 'frontend/src/app/domain'), { recursive: true });
}

test('runArchitectureGuard passes on production repo tree', () => {
  const result = runArchitectureGuard(REPO_ROOT);
  assert.equal(result.ok, true, result.violations.join('\n'));
});

test('R1 fails when domain imports axum', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-r1-'));
  mkdirSync(join(root, 'crates/agrr-domain/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-domain/Cargo.toml'), '[dependencies]\nserde = "1"\n');
  writeFileSync(
    join(root, 'crates/agrr-domain/src/bad.rs'),
    'use axum::Json;\n',
  );
  mkdirSync(join(root, 'crates/agrr-server/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-server/src/lib.rs'), '');
  mkdirSync(join(root, 'frontend/src/app/components'), { recursive: true });
  mkdirSync(join(root, 'frontend/src/app/domain'), { recursive: true });
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'R1' && v.file.includes('bad.rs')));
});

test('R1 fails when domain Cargo.toml lists sqlx', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-cargo-'));
  mkdirSync(join(root, 'crates/agrr-domain/src'), { recursive: true });
  writeFileSync(
    join(root, 'crates/agrr-domain/Cargo.toml'),
    '[dependencies]\nserde = "1"\nsqlx = "0.7"\n',
  );
  mkdirSync(join(root, 'crates/agrr-server/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-server/src/lib.rs'), '');
  mkdirSync(join(root, 'frontend/src/app/components'), { recursive: true });
  mkdirSync(join(root, 'frontend/src/app/domain'), { recursive: true });
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'R1' && v.file.includes('Cargo.toml')));
});

test('R2 fails on gateway default() in domain', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-r2-'));
  mkdirSync(join(root, 'crates/agrr-domain/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-domain/Cargo.toml'), '[dependencies]\nserde = "1"\n');
  writeFileSync(
    join(root, 'crates/agrr-domain/src/bad.rs'),
    'let g = FarmGateway::default();\n',
  );
  mkdirSync(join(root, 'crates/agrr-server/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-server/src/lib.rs'), '');
  mkdirSync(join(root, 'frontend/src/app/components'), { recursive: true });
  mkdirSync(join(root, 'frontend/src/app/domain'), { recursive: true });
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'R2'));
});

test('formatViolations renders rule id, file, and message', () => {
  const lines = formatViolations([
    { ruleId: 'R1', file: 'crates/agrr-domain/src/bad.rs', message: 'forbidden axum' },
  ]);
  assert.deepEqual(lines, ['[R1] crates/agrr-domain/src/bad.rs: forbidden axum']);
});

test('R6 fails when presenter uses Sqlite', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-r6-sqlite-'));
  writeMinimalArchGuardTree(root);
  writeFileSync(
    join(root, 'crates/agrr-server/src/foo_presenter.rs'),
    'let db = Sqlite::new();\n',
  );
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'R6' && /Sqlite/.test(v.message)));
});

test('R6 fails when presenter imports agrr-adapters', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-r6-'));
  writeMinimalArchGuardTree(root);
  writeFileSync(
    join(root, 'crates/agrr-server/src/foo_presenter.rs'),
    'use agrr_adapters_sqlite::Foo;\n',
  );
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'R6'));
});

test('run-architecture-guard.sh exits 1 on intentional R6 violation fixture', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-r6-shell-'));
  writeMinimalArchGuardTree(root);
  writeFileSync(
    join(root, 'crates/agrr-server/src/foo_presenter.rs'),
    'use agrr_adapters_sqlite::Foo;\n',
  );
  const result = spawnSync('bash', [GUARD_SCRIPT, root], { encoding: 'utf8' });
  assert.equal(result.status, 1, `expected exit 1, got ${result.status}\nstdout: ${result.stdout}\nstderr: ${result.stderr}`);
  assert.match(result.stderr ?? '', /R6/);
});

test('R7 passes when route handler delegates to interactor', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-r7-ok-'));
  mkdirSync(join(root, 'crates/agrr-domain/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-domain/Cargo.toml'), '[dependencies]\nserde = "1"\n');
  mkdirSync(join(root, 'crates/agrr-server/src'), { recursive: true });
  writeFileSync(
    join(root, 'crates/agrr-server/src/good_routes.rs'),
    `use axum::{extract::State, routing::get, Json, Router};
pub fn routes() -> Router<()> {
    Router::new().route("/test", get(handler))
}
async fn handler(State(_): State<()>) -> Json<()> {
    let interactor = CropListInteractor::new();
    interactor.run(())
}
`,
  );
  mkdirSync(join(root, 'frontend/src/app/components'), { recursive: true });
  mkdirSync(join(root, 'frontend/src/app/domain'), { recursive: true });
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, true, result.violations.join('\n'));
});

test('R7 fails when route handler lacks interactor delegation', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-r7-'));
  mkdirSync(join(root, 'crates/agrr-domain/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-domain/Cargo.toml'), '[dependencies]\nserde = "1"\n');
  mkdirSync(join(root, 'crates/agrr-server/src'), { recursive: true });
  writeFileSync(
    join(root, 'crates/agrr-server/src/bad_routes.rs'),
  `use axum::{extract::State, routing::get, Json, Router};
pub fn routes() -> Router<()> {
    Router::new().route("/test", get(handler))
}
async fn handler(State(_): State<()>) -> Json<()> {
    Json(())
}
`,
  );
  mkdirSync(join(root, 'frontend/src/app/components'), { recursive: true });
  mkdirSync(join(root, 'frontend/src/app/domain'), { recursive: true });
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'R7'));
});

test('frontend rule fails when component imports ../adapters/', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-fe-'));
  mkdirSync(join(root, 'crates/agrr-domain/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-domain/Cargo.toml'), '[dependencies]\nserde = "1"\n');
  mkdirSync(join(root, 'crates/agrr-server/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-server/src/lib.rs'), '');
  mkdirSync(join(root, 'frontend/src/app/components/foo'), { recursive: true });
  writeFileSync(
    join(root, 'frontend/src/app/components/foo/foo.component.ts'),
    "import { X } from '../adapters/x';\n",
  );
  mkdirSync(join(root, 'frontend/src/app/domain'), { recursive: true });
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'FE-COMPONENTS'));
});

test('frontend rule fails when domain imports ../components/', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-fe-domain-'));
  mkdirSync(join(root, 'crates/agrr-domain/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-domain/Cargo.toml'), '[dependencies]\nserde = "1"\n');
  mkdirSync(join(root, 'crates/agrr-server/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-server/src/lib.rs'), '');
  mkdirSync(join(root, 'frontend/src/app/components'), { recursive: true });
  mkdirSync(join(root, 'frontend/src/app/domain/foo'), { recursive: true });
  writeFileSync(
    join(root, 'frontend/src/app/domain/foo/bad.ts'),
    "import { X } from '../components/x';\n",
  );
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'FE-DOMAIN'));
});

test('frontend rule fails when domain imports ../../components/', () => {
  const root = mkdtempSync(join(tmpdir(), 'arch-guard-fe-domain-nested-'));
  mkdirSync(join(root, 'crates/agrr-domain/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-domain/Cargo.toml'), '[dependencies]\nserde = "1"\n');
  mkdirSync(join(root, 'crates/agrr-server/src'), { recursive: true });
  writeFileSync(join(root, 'crates/agrr-server/src/lib.rs'), '');
  mkdirSync(join(root, 'frontend/src/app/components'), { recursive: true });
  mkdirSync(join(root, 'frontend/src/app/domain/foo'), { recursive: true });
  writeFileSync(
    join(root, 'frontend/src/app/domain/foo/bad.ts'),
    "import { X } from '../../components/x';\n",
  );
  const result = runArchitectureGuard(root);
  assert.equal(result.ok, false);
  assert.ok(result.violations.some((v) => v.ruleId === 'FE-DOMAIN'));
});
