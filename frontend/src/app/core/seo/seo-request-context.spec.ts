import { describe, expect, it } from 'vitest';
import { resolveSeoRequestContext } from './seo-request-context';
import { PRODUCTION_SITE_ORIGIN } from './seo-site-origin';

describe('resolveSeoRequestContext', () => {
  it('uses window location on the browser', () => {
    const location = {
      pathname: '/about',
      origin: 'http://localhost:4200'
    } as Location;

    expect(resolveSeoRequestContext(location, '/contact')).toEqual({
      path: '/about',
      origin: 'http://localhost:4200'
    });
  });

  it('falls back to router URL and production origin when window is unavailable', () => {
    expect(resolveSeoRequestContext(undefined, '/about')).toEqual({
      path: '/about',
      origin: PRODUCTION_SITE_ORIGIN
    });
  });

  it('uses router URL path on the server', () => {
    expect(resolveSeoRequestContext(null, '/public-plans/new')).toEqual({
      path: '/public-plans/new',
      origin: PRODUCTION_SITE_ORIGIN
    });
  });
});
