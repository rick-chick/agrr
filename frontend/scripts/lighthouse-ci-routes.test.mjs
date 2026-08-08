import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  LIGHTHOUSE_CI_AUTH_ROUTE_TEMPLATES,
  LIGHTHOUSE_CI_MOBILE_PUBLIC_ROUTE,
  LIGHTHOUSE_CI_PUBLIC_ROUTES,
  LIGHTHOUSE_CI_THRESHOLDS,
} from './lighthouse-ci-routes.mjs';
import { buildAuthLighthouseUrls } from './lighthouse-ci-auth-urls-lib.mjs';

test('LIGHTHOUSE_CI_PUBLIC_ROUTES covers 3–5 public prerender routes', () => {
  assert.ok(
    LIGHTHOUSE_CI_PUBLIC_ROUTES.length >= 3 && LIGHTHOUSE_CI_PUBLIC_ROUTES.length <= 5,
    `expected 3–5 routes, got ${LIGHTHOUSE_CI_PUBLIC_ROUTES.length}`,
  );
});

test('LIGHTHOUSE_CI_PUBLIC_ROUTES includes home, about, contact, public-plans/new', () => {
  const paths = LIGHTHOUSE_CI_PUBLIC_ROUTES.map((route) => route.path);
  for (const expected of ['/', '/about', '/contact', '/public-plans/new']) {
    assert.ok(paths.includes(expected), `missing route ${expected}`);
  }
});

test('LIGHTHOUSE_CI_AUTH_ROUTE_TEMPLATES includes 2–3 authenticated representative routes', () => {
  assert.ok(
    LIGHTHOUSE_CI_AUTH_ROUTE_TEMPLATES.length >= 2 &&
      LIGHTHOUSE_CI_AUTH_ROUTE_TEMPLATES.length <= 3,
    `expected 2–3 auth routes, got ${LIGHTHOUSE_CI_AUTH_ROUTE_TEMPLATES.length}`,
  );
  const paths = LIGHTHOUSE_CI_AUTH_ROUTE_TEMPLATES.map((route) => route.path);
  for (const expected of ['/plans', '/plans/:id', '/work']) {
    assert.ok(paths.includes(expected), `missing auth route ${expected}`);
  }
});

test('LIGHTHOUSE_CI_MOBILE_PUBLIC_ROUTE is a public route with mobile preset', () => {
  assert.equal(LIGHTHOUSE_CI_MOBILE_PUBLIC_ROUTE.preset, 'mobile');
  assert.equal(LIGHTHOUSE_CI_MOBILE_PUBLIC_ROUTE.path, '/contact');
});

test('LIGHTHOUSE_CI_THRESHOLDS keeps performance and LCP warn gates', () => {
  assert.equal(LIGHTHOUSE_CI_THRESHOLDS.performanceMinScore, 0.85);
  assert.equal(LIGHTHOUSE_CI_THRESHOLDS.lcpMaxMs, 2500);
});

test('buildAuthLighthouseUrls resolves plan id template', () => {
  const urls = buildAuthLighthouseUrls(
    [
      { path: '/plans', url: '/plans' },
      { path: '/plans/:id', urlTemplate: '/plans/{planId}' },
      { path: '/work', url: '/work' },
    ],
    42,
  );
  assert.deepEqual(urls, [
    { path: '/plans', url: '/plans' },
    { path: '/plans/:id', url: '/plans/42' },
    { path: '/work', url: '/work' },
  ]);
});
