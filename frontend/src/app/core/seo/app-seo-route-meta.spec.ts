import { describe, it, expect } from 'vitest';
import { resolveRouteMetaKeys } from './app-seo-route-meta';

describe('resolveRouteMetaKeys', () => {
  it('maps sitemap SPA paths to page meta i18n keys', () => {
    expect(resolveRouteMetaKeys('/about')).toEqual({
      titleKey: 'pages.about.title',
      descriptionKey: 'pages.about.description'
    });
    expect(resolveRouteMetaKeys('/public-plans/new')).toEqual({
      titleKey: 'pages.public_plans.title',
      descriptionKey: 'pages.public_plans.description'
    });
  });

  it('normalizes trailing slashes and query strings', () => {
    expect(resolveRouteMetaKeys('/contact/?utm=1')).toEqual({
      titleKey: 'pages.contact.title',
      descriptionKey: 'pages.contact.description'
    });
    expect(resolveRouteMetaKeys('/terms/')).toEqual({
      titleKey: 'pages.terms.title',
      descriptionKey: 'pages.terms.description'
    });
  });

  it('returns null for routes outside the sitemap SPA set', () => {
    expect(resolveRouteMetaKeys('/farms')).toBeNull();
    expect(resolveRouteMetaKeys('/login')).toBeNull();
  });

  it('treats undefined pathname as home', () => {
    expect(resolveRouteMetaKeys(undefined)).toEqual({
      titleKey: 'meta.default.title',
      descriptionKey: 'meta.default.description'
    });
  });
});
