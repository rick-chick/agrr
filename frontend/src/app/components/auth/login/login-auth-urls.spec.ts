import { describe, it, expect } from 'vitest';
import {
  buildGoogleOAuthStartUrl,
  buildMockLoginUrl,
  oauthLocationForLogin,
  oauthReturnToUrl,
  requiresAuthForDirectLanding
} from './login-auth-urls';

const origin = 'http://localhost:4200';

describe('login-auth-urls', () => {
  it('sets return_to to origin root when pathname is /login', () => {
    expect(
      oauthReturnToUrl({
        href: `${origin}/login`,
        pathname: '/login',
        origin
      })
    ).toBe(`${origin}/`);
  });

  it('sets return_to to origin root when pathname is /login/', () => {
    expect(
      oauthReturnToUrl({
        href: `${origin}/login/`,
        pathname: '/login/',
        origin
      })
    ).toBe(`${origin}/`);
  });

  it('routes auth-required paths through / with _post_login (no SPA shell mirror)', () => {
    const href = `${origin}/plans?tab=1`;
    expect(
      oauthReturnToUrl({
        href,
        pathname: '/plans',
        origin
      })
    ).toBe(
      `${origin}/?_post_login=${encodeURIComponent('/plans?tab=1')}`
    );
  });

  it('keeps public full-page paths as direct return_to', () => {
    const href = `${origin}/public-plans/results?planId=756`;
    expect(
      oauthReturnToUrl({
        href,
        pathname: '/public-plans/results',
        origin
      })
    ).toBe(href);
  });

  it('requiresAuthForDirectLanding does not treat public-plans as /plans', () => {
    expect(requiresAuthForDirectLanding('/plans')).toBe(true);
    expect(requiresAuthForDirectLanding('/public-plans/results')).toBe(false);
  });

  it('uses return_to query for OAuth when provided', () => {
    const loc = { href: `${origin}/login`, pathname: '/login', origin };
    const plans = `${origin}/plans?x=1`;
    const effective = oauthLocationForLogin(loc, plans);
    const url = buildGoogleOAuthStartUrl('', effective);
    expect(url).toContain(
      `return_to=${encodeURIComponent(`${origin}/?_post_login=${encodeURIComponent('/plans?x=1')}`)}`
    );
  });

  it('builds same-origin Google OAuth start URL when apiBase is empty', () => {
    const loc = { href: `${origin}/login`, pathname: '/login', origin };
    const url = buildGoogleOAuthStartUrl('', loc);
    expect(url).toBe(
      `/auth/google_oauth2?return_to=${encodeURIComponent(`${origin}/`)}`
    );
  });

  it('oauthReturnToUrl tolerates missing location', () => {
    const result = oauthReturnToUrl(undefined);
    expect(result === '/' || result.endsWith('/')).toBe(true);
  });

  it('builds same-origin mock login URLs when apiBase is empty', () => {
    const loc = { href: `${origin}/login`, pathname: '/login', origin };
    expect(buildMockLoginUrl('', 'developer', loc)).toBe(
      `/auth/test/mock_login_as/developer?return_to=${encodeURIComponent(`${origin}/`)}`
    );
    expect(buildMockLoginUrl('', 'farmer', loc)).toContain('/auth/test/mock_login_as/farmer?return_to=');
    expect(buildMockLoginUrl('', 'researcher', loc)).toContain(
      '/auth/test/mock_login_as/researcher?return_to='
    );
  });
});
