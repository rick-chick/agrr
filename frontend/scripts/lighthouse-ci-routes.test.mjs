import assert from 'node:assert/strict';
import { test } from 'node:test';

import { LIGHTHOUSE_CI_ROUTES } from './lighthouse-ci-routes.mjs';

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
