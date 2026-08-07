import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';

import { PUBLIC_PRERENDER_ROUTES } from '../../scripts/public-prerender-routes.mjs';
import {
  A11Y_AUTH_SAMPLE_ROUTES,
  A11Y_SMOKE_EXCLUDED_PATTERNS,
  buildA11ySmokeRoutes,
  loadA11yPrerenderPaths,
} from './a11y-smoke-lib.ts';

const manifest = JSON.parse(
  readFileSync(join(process.cwd(), 'e2e/route-manifest.json'), 'utf8'),
);

const prerenderPaths = loadA11yPrerenderPaths();

test('loadA11yPrerenderPaths matches scripts/public-prerender-routes.mjs paths', () => {
  const fromScript = PUBLIC_PRERENDER_ROUTES.map((route) => route.path).sort();
  const fromLib = [...loadA11yPrerenderPaths()].sort();
  assert.deepEqual(fromLib, fromScript);
});

test('buildA11ySmokeRoutes includes every manifest public route except excluded patterns', () => {
  const routes = buildA11ySmokeRoutes(manifest, prerenderPaths);
  const patterns = new Set(routes.map((r) => r.pattern));

  for (const row of manifest.routes) {
    if (row.requiresAuth || A11Y_SMOKE_EXCLUDED_PATTERNS.has(row.pattern)) {
      continue;
    }
    assert.ok(patterns.has(row.pattern), `missing public manifest route: ${row.pattern}`);
  }
});

test('buildA11ySmokeRoutes includes English prerender subpaths missing from manifest', () => {
  const routes = buildA11ySmokeRoutes(manifest, prerenderPaths);
  const patterns = new Set(routes.map((r) => r.pattern));

  for (const path of prerenderPaths) {
    if (path === '' || path.startsWith('entry-schedule/crop/')) {
      continue;
    }
    const manifestHas = manifest.routes.some((row) => row.pattern === path);
    if (!manifestHas) {
      assert.ok(patterns.has(path), `missing prerender-only route: ${path}`);
    }
  }
});

test('buildA11ySmokeRoutes includes entry-schedule crop prerender paths', () => {
  const routes = buildA11ySmokeRoutes(manifest, prerenderPaths);
  const patterns = new Set(routes.map((r) => r.pattern));

  const cropPaths = prerenderPaths.filter((path) => path.startsWith('entry-schedule/crop/'));
  assert.ok(cropPaths.length > 1, 'fixture: expected multiple entry-schedule crop prerender paths');
  for (const path of cropPaths) {
    assert.ok(patterns.has(path), `missing entry-schedule crop route: ${path}`);
  }
});

test('buildA11ySmokeRoutes keeps authenticated sample routes for shell regression', () => {
  const routes = buildA11ySmokeRoutes(manifest, prerenderPaths);
  const patterns = new Set(routes.map((r) => r.pattern));

  for (const sample of A11Y_AUTH_SAMPLE_ROUTES) {
    assert.ok(patterns.has(sample.pattern), `missing auth sample route: ${sample.pattern}`);
  }
});

test('buildA11ySmokeRoutes excludes login and wildcard 404 fixture routes', () => {
  const routes = buildA11ySmokeRoutes(manifest, prerenderPaths);
  const patterns = new Set(routes.map((r) => r.pattern));

  for (const excluded of A11Y_SMOKE_EXCLUDED_PATTERNS) {
    assert.equal(patterns.has(excluded), false, `excluded route leaked: ${excluded}`);
  }
});
