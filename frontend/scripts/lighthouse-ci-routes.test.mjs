import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  LIGHTHOUSE_CI_AUTH_ROUTES,
  LIGHTHOUSE_CI_ROUTES,
  LIGHTHOUSE_CI_THRESHOLDS,
  hasMobilePresetRoute,
} from './lighthouse-ci-routes.mjs';

test('LIGHTHOUSE_CI_ROUTES covers 3–5 public prerender routes', () => {
  assert.ok(
    LIGHTHOUSE_CI_ROUTES.length >= 3 && LIGHTHOUSE_CI_ROUTES.length <= 5,
    `expected 3–5 routes, got ${LIGHTHOUSE_CI_ROUTES.length}`
  );
});

test('LIGHTHOUSE_CI_ROUTES includes home, about, contact, public-plans/new', () => {
  const paths = LIGHTHOUSE_CI_ROUTES.map((route) => route.path);
  for (const expected of ['/', '/about', '/contact', '/public-plans/new']) {
    assert.ok(paths.includes(expected), `missing route ${expected}`);
  }
});

test('LIGHTHOUSE_CI_AUTH_ROUTES covers 2–3 authenticated SPA routes', () => {
  assert.ok(
    LIGHTHOUSE_CI_AUTH_ROUTES.length >= 2 && LIGHTHOUSE_CI_AUTH_ROUTES.length <= 3,
    `expected 2–3 auth routes, got ${LIGHTHOUSE_CI_AUTH_ROUTES.length}`
  );
});

test('LIGHTHOUSE_CI_AUTH_ROUTES includes plans list, plan detail, and work', () => {
  const paths = LIGHTHOUSE_CI_AUTH_ROUTES.map((route) => route.path);
  assert.ok(paths.includes('/plans'), 'missing /plans');
  assert.ok(paths.some((p) => p === '/plans/:id' || p.startsWith('/plans/')), 'missing plan detail route');
  assert.ok(paths.includes('/work'), 'missing /work');
});

test('at least one Lighthouse CI route uses mobile preset', () => {
  assert.equal(hasMobilePresetRoute(), true, 'expected mobile preset on at least one route');
});

test('LIGHTHOUSE_CI_THRESHOLDS match issue defaults', () => {
  assert.equal(LIGHTHOUSE_CI_THRESHOLDS.performanceMinScore, 0.85);
  assert.equal(LIGHTHOUSE_CI_THRESHOLDS.lcpMaxMs, 2500);
});
