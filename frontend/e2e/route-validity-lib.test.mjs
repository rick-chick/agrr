import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  expectedPathname,
  expectedPathnameFromResolvedGoto,
  normalizePathname,
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
