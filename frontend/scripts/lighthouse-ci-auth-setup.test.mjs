import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildAuthUrls,
  parseSessionCookies,
  resolvePlanIdFromPlansResponse,
} from './lighthouse-ci-auth-setup.mjs';

test('parseSessionCookies extracts session_id from Set-Cookie headers', () => {
  const cookies = parseSessionCookies([
    'session_id=abc123; Path=/; HttpOnly; SameSite=Lax',
    'other=value; Path=/',
  ]);
  assert.equal(cookies.length, 1);
  assert.equal(cookies[0].name, 'session_id');
  assert.equal(cookies[0].value, 'abc123');
  assert.equal(cookies[0].path, '/');
});

test('resolvePlanIdFromPlansResponse prefers E2E Baseline plan', () => {
  const id = resolvePlanIdFromPlansResponse([
    { id: 99, plan_name: 'Other' },
    { id: 42, plan_name: 'E2E Baseline Plan' },
  ]);
  assert.equal(id, 42);
});

test('resolvePlanIdFromPlansResponse falls back to first plan id', () => {
  const id = resolvePlanIdFromPlansResponse([{ id: 7, plan_name: 'Farm plan' }]);
  assert.equal(id, 7);
});

test('buildAuthUrls substitutes planId into urlPattern routes', () => {
  const urls = buildAuthUrls(
    [
      { path: '/plans', url: '/plans', preset: 'desktop' },
      { path: '/plans/:id', urlPattern: '/plans/{planId}', preset: 'desktop', resolvePlanId: true },
      { path: '/work', url: '/work', preset: 'desktop' },
    ],
    42
  );
  assert.deepEqual(urls, ['/plans', '/plans/42', '/work']);
});
