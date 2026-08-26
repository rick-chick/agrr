import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  LAYOUT_ALLOW_DOCUMENT_HORIZONTAL_OVERFLOW,
  LAYOUT_SMOKE_SKIP_PATTERNS,
  LAYOUT_SMOKE_VIEWPORTS,
  shouldRunLayoutSmoke,
} from './layout-smoke-lib.mjs';

test('LAYOUT_SMOKE_VIEWPORTS includes mobile, tablet, desktop', () => {
  assert.equal(LAYOUT_SMOKE_VIEWPORTS.length, 3);
  assert.ok(LAYOUT_SMOKE_VIEWPORTS.some((v) => v.name === 'desktop' && v.width === 1280));
});

test('shouldRunLayoutSmoke skips login under dev session', () => {
  const result = shouldRunLayoutSmoke('login', 1280);
  assert.equal(result.run, false);
  assert.ok(result.reason);
});

test('shouldRunLayoutSmoke runs for plans at desktop', () => {
  const result = shouldRunLayoutSmoke('plans', 1280);
  assert.equal(result.run, true);
  assert.equal(result.reason, null);
});

test('gantt routes may allow document horizontal overflow', () => {
  assert.ok(LAYOUT_ALLOW_DOCUMENT_HORIZONTAL_OVERFLOW.has('plans/:id/work'));
});

test('login is in skip patterns', () => {
  assert.ok(LAYOUT_SMOKE_SKIP_PATTERNS.has('login'));
});
