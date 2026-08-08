import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

const FRONTEND_ROOT = join(__dirname, '..');

test('each Lighthouse rc file exports a single ci object (not an array)', () => {
  for (const file of [
    'lighthouserc.js',
    'lighthouserc.public-desktop.js',
    'lighthouserc.public-mobile.js',
  ]) {
    const config = require(join(FRONTEND_ROOT, file));
    assert.ok(config?.ci, `${file} must export { ci: ... }`);
    assert.equal(Array.isArray(config), false, `${file} must not export an array`);
  }
});

test('public-desktop config targets prerender dist with desktop preset routes', () => {
  const config = require(join(FRONTEND_ROOT, 'lighthouserc.public-desktop.js'));
  assert.equal(config.ci.collect.staticDistDir, './dist/frontend/browser');
  assert.equal(config.ci.collect.settings.preset, 'desktop');
  assert.ok(config.ci.collect.url.includes('/'));
  assert.ok(config.ci.collect.url.includes('/contact/'));
});

test('public-mobile config uses mobile preset for /about', () => {
  const config = require(join(FRONTEND_ROOT, 'lighthouserc.public-mobile.js'));
  assert.equal(config.ci.collect.settings.preset, 'mobile');
  assert.deepEqual(config.ci.collect.url, ['/about/']);
});
