import { describe, it, expect } from 'vitest';
import { normalizeSeoPath, resolveSeoKeyPrefix, ROUTE_SEO_KEY_MAP } from './route-seo-meta.config';
import { PUBLIC_PRERENDER_PATHS } from './public-prerender-routes';

describe('route-seo-meta.config', () => {
  it('normalizes trailing slashes and query strings', () => {
    expect(normalizeSeoPath('/about/')).toBe('/about');
    expect(normalizeSeoPath('/about?lang=ja')).toBe('/about');
    expect(normalizeSeoPath('/')).toBe('/');
    expect(normalizeSeoPath('')).toBe('/');
  });

  it('resolves sitemap SPA paths to page-specific i18n prefixes', () => {
    expect(resolveSeoKeyPrefix('/')).toBe('meta.default');
    expect(resolveSeoKeyPrefix('/about')).toBe('pages.about');
    expect(resolveSeoKeyPrefix('/contact')).toBe('pages.contact');
    expect(resolveSeoKeyPrefix('/privacy')).toBe('pages.privacy');
    expect(resolveSeoKeyPrefix('/terms')).toBe('pages.terms');
    expect(resolveSeoKeyPrefix('/public-plans/new')).toBe('pages.public_plans_new');
    expect(resolveSeoKeyPrefix('/entry-schedule')).toBe('pages.entry_schedule');
    expect(resolveSeoKeyPrefix('/entry-schedule/crop/42')).toBe('pages.entry_schedule_detail');
  });

  it('falls back to meta.default for undefined routes', () => {
    expect(resolveSeoKeyPrefix('/plans')).toBe('meta.default');
    expect(resolveSeoKeyPrefix('/unknown-page')).toBe('meta.default');
  });

  it('keeps /entry-schedule registered in SEO map and prerender paths', () => {
    expect(ROUTE_SEO_KEY_MAP['/entry-schedule']).toBe('pages.entry_schedule');
    expect(PUBLIC_PRERENDER_PATHS).toContain('entry-schedule');
  });
});
