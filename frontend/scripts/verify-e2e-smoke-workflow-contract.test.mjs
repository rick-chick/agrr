import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { describe, it } from 'node:test';

const ROOT = join(import.meta.dirname, '..', '..');
const WORKFLOW = join(ROOT, '.github', 'workflows', 'frontend-e2e-smoke.yml');
const README = join(ROOT, 'frontend', 'e2e', 'smoke', 'README.md');

describe('frontend-e2e-smoke CI contract', () => {
  it('defines a dedicated workflow file', () => {
    assert.ok(existsSync(WORKFLOW), `missing ${WORKFLOW}`);
  });

  it('runs route-smoke with dev session and strangler env', () => {
    const yaml = readFileSync(WORKFLOW, 'utf8');
    assert.match(yaml, /E2E_CAPTURE_DEV_SESSION[=:][\s"']*1/);
    assert.match(yaml, /E2E_STRANGLER[=:][\s"']*1/);
    assert.match(yaml, /route-smoke\.spec\.ts/);
  });

  it('starts agrr-server stack before Playwright', () => {
    const yaml = readFileSync(WORKFLOW, 'utf8');
    assert.match(yaml, /agrr-server/);
    assert.match(yaml, /strangler-proxy|127\.0\.0\.1:3000/);
    assert.match(yaml, /playwright install/i);
  });

  it('documents CI prerequisites in smoke README', () => {
    const readme = readFileSync(README, 'utf8');
    assert.match(readme, /CI|GitHub Actions/i);
    assert.match(readme, /route-smoke/);
    assert.match(readme, /E2E_CAPTURE_DEV_SESSION/);
  });
});
