import { describe, it, expect } from 'vitest';
import { normalizeSeoPath, resolveSeoKeyPrefix } from './route-seo-meta.config';

describe('route-seo-meta.config', () => {
  it('normalizes trailing slashes and query strings', () => {
    expect(normalizeSeoPath('/about/')).toBe('/about');
    expect(normalizeSeoPath('/about?foo=bar')).toBe('/about');
    expect(normalizeSeoPath(null)).toBe('/');
  });

  it('strips /en prefix for SEO key resolution', () => {
    expect(normalizeSeoPath('/en')).toBe('/');
    expect(normalizeSeoPath('/en/about')).toBe('/about');
    expect(resolveSeoKeyPrefix('/en/about')).toBe('pages.about');
  });

  it('resolves known route prefixes', () => {
    expect(resolveSeoKeyPrefix('/')).toBe('meta.default');
    expect(resolveSeoKeyPrefix('/about')).toBe('pages.about');
    expect(resolveSeoKeyPrefix('/contact')).toBe('pages.contact');
    expect(resolveSeoKeyPrefix('/privacy')).toBe('pages.privacy');
    expect(resolveSeoKeyPrefix('/terms')).toBe('pages.terms');
    expect(resolveSeoKeyPrefix('/public-plans/new')).toBe('pages.public_plans_new');
    expect(resolveSeoKeyPrefix('/public-plans/results')).toBe('pages.public_plans_new');
    expect(resolveSeoKeyPrefix('/entry-schedule')).toBe('pages.entry_schedule');
    expect(resolveSeoKeyPrefix('/entry-schedule/farm/42')).toBe('pages.entry_schedule');
    expect(resolveSeoKeyPrefix('/entry-schedule/crop/42')).toBe('pages.entry_schedule_detail');
  });

  it('falls back to meta.default for undefined routes', () => {
    expect(resolveSeoKeyPrefix('/plans')).toBe('meta.default');
    expect(resolveSeoKeyPrefix('/unknown')).toBe('meta.default');
  });
});
