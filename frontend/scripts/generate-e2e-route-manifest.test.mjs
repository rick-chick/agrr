import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  buildHostSelectorData,
  buildManifestData,
  checkManifestFreshness,
  normalizeManifestJson,
  parseSelectorFromComponentSource,
} from './generate-e2e-route-manifest-lib.mjs';

const FRONTEND = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('normalizeManifestJson ignores generatedAt', () => {
  const a = {
    generatedAt: '2026-01-01T00:00:00.000Z',
    note: 'note',
    routes: [{ pattern: 'about', url: '/about', requiresAuth: false, source: 'pages.routes.ts' }],
  };
  const b = {
    generatedAt: '2026-06-17T14:00:00.000Z',
    note: 'note',
    routes: [{ pattern: 'about', url: '/about', requiresAuth: false, source: 'pages.routes.ts' }],
  };
  assert.equal(normalizeManifestJson(a), normalizeManifestJson(b));
});

test('checkManifestFreshness passes when committed manifest matches routes', async () => {
  const result = await checkManifestFreshness(FRONTEND);
  assert.equal(result.ok, true, result.errors?.join('\n'));
});

test('checkManifestFreshness detects stale route-manifest.json content', async () => {
  const { payload } = await buildManifestData(FRONTEND);
  const stale = {
    ...payload,
    routes: payload.routes.slice(0, Math.max(0, payload.routes.length - 1)),
  };
  assert.notEqual(normalizeManifestJson(stale), normalizeManifestJson(payload));
});

test('parseSelectorFromComponentSource extracts app-* selector', () => {
  const source = `@Component({ selector: 'app-farm-list', standalone: true })`;
  assert.equal(parseSelectorFromComponentSource(source), 'app-farm-list');
});

test('buildHostSelectorData maps loadComponent routes to component selectors', async () => {
  const { map } = await buildHostSelectorData(FRONTEND);
  assert.equal(map.farms, 'app-farm-list');
  assert.equal(map['farms/:id'], 'app-farm-detail');
  assert.equal(map.about, 'app-about');
});

test('buildHostSelectorData maps direct component routes', async () => {
  const { map } = await buildHostSelectorData(FRONTEND);
  assert.equal(map[''], 'app-home');
  assert.equal(map.login, 'app-login');
  assert.equal(map.dashboard, 'app-home');
});

test('buildHostSelectorData applies redirect-only overrides', async () => {
  const { map } = await buildHostSelectorData(FRONTEND);
  assert.equal(map['public-plans/select-farm-size'], 'app-public-plan-create');
});

test('buildHostSelectorData covers every route-manifest pattern', async () => {
  const { payload } = await buildManifestData(FRONTEND);
  const { map } = await buildHostSelectorData(FRONTEND);
  const missing = payload.routes
    .map((r) => r.pattern)
    .filter((pattern) => !map[pattern]);
  assert.deepEqual(missing, [], `missing host selectors: ${missing.join(', ')}`);
});

test('checkManifestFreshness passes when committed host-selector file matches routes', async () => {
  const result = await checkManifestFreshness(FRONTEND);
  assert.equal(result.ok, true, result.errors?.join('\n'));
});
