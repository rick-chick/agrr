import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { normalizeSeoPath, resolveSeoKeyPrefix } from './route-seo-meta-lib.mjs';

describe('route-seo-meta-lib.mjs', () => {
  it('normalizes trailing slashes and query strings', () => {
    assert.equal(normalizeSeoPath('/about/'), '/about');
    assert.equal(normalizeSeoPath('/about?foo=bar'), '/about');
    assert.equal(normalizeSeoPath(null), '/');
  });

  it('strips /en prefix for SEO key resolution', () => {
    assert.equal(normalizeSeoPath('/en'), '/');
    assert.equal(normalizeSeoPath('/en/about'), '/about');
    assert.equal(resolveSeoKeyPrefix('/en/about'), 'pages.about');
  });

  it('resolves known route prefixes', () => {
    assert.equal(resolveSeoKeyPrefix('/'), 'meta.default');
    assert.equal(resolveSeoKeyPrefix('/about'), 'pages.about');
    assert.equal(resolveSeoKeyPrefix('/contact'), 'pages.contact');
    assert.equal(resolveSeoKeyPrefix('/privacy'), 'pages.privacy');
    assert.equal(resolveSeoKeyPrefix('/terms'), 'pages.terms');
    assert.equal(resolveSeoKeyPrefix('/public-plans/new'), 'pages.public_plans_new');
    assert.equal(resolveSeoKeyPrefix('/public-plans/results'), 'pages.public_plans_new');
    assert.equal(resolveSeoKeyPrefix('/entry-schedule'), 'pages.entry_schedule');
    assert.equal(resolveSeoKeyPrefix('/entry-schedule/farm/42'), 'pages.entry_schedule');
    assert.equal(resolveSeoKeyPrefix('/entry-schedule/crop/42'), 'pages.entry_schedule_detail');
  });

  it('falls back to meta.default for undefined routes', () => {
    assert.equal(resolveSeoKeyPrefix('/plans'), 'meta.default');
    assert.equal(resolveSeoKeyPrefix('/unknown'), 'meta.default');
  });
});
