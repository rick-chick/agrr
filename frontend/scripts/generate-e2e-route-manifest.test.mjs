import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  buildManifestData,
  checkManifestFreshness,
  normalizeManifestJson,
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
