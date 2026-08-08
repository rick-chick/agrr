import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  expectedPathname,
  expectedPathnameFromResolvedGoto,
  normalizePathname,
  resolveCaptureValidity,
} from './route-validity-lib.mjs';

test('expectedPathname strips query and trailing slash', () => {
  assert.equal(
    expectedPathname({ pattern: 'x', url: '/plans/1/work?tab=today', requiresAuth: true, source: 't' }),
    '/plans/1/work',
  );
  assert.equal(
    expectedPathname({ pattern: 'x', url: 'about/', requiresAuth: false, source: 't' }),
    '/about',
  );
});

test('normalizePathname treats root slash as /', () => {
  assert.equal(normalizePathname('/'), '/');
  assert.equal(normalizePathname('/plans/1/'), '/plans/1');
});

test('expectedPathnameFromResolvedGoto normalizes relative href', () => {
  assert.equal(expectedPathnameFromResolvedGoto('plans/77/work'), '/plans/77/work');
  assert.equal(expectedPathnameFromResolvedGoto('/plans/77/work/'), '/plans/77/work');
});

test('resolveCaptureValidity accepts work hub redirect to plan work', () => {
  const hosts = { work: 'app-work-hub', 'plans/:id/work': 'app-plan-work' };
  const redirected = resolveCaptureValidity('work', '/plans/1/work', '/work', hosts);
  assert.equal(redirected.pathname, '/plans/1/work');
  assert.equal(redirected.host, 'app-plan-work');

  const hub = resolveCaptureValidity('work', '/work', '/work', hosts);
  assert.equal(hub.pathname, '/work');
  assert.equal(hub.host, 'app-work-hub');
});
