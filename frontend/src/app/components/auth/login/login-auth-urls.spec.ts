import { describe, it, expect } from 'vitest';
import {
  buildGoogleOAuthStartUrl,
  buildMockLoginUrl,
  oauthLocationForLogin,
  oauthReturnToUrl
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

  it('sets return_to to full href when not on login path', () => {
    const href = `${origin}/plans?tab=1`;
    expect(
      oauthReturnToUrl({
        href,
        pathname: '/plans',
        origin
      })
    ).toBe(href);
  });

  it('uses return_to query for OAuth when provided', () => {
    const loc = { href: `${origin}/login`, pathname: '/login', origin };
    const plans = `${origin}/plans?x=1`;
    const effective = oauthLocationForLogin(loc, plans);
    const url = buildGoogleOAuthStartUrl('', effective);
    expect(url).toContain(`return_to=${encodeURIComponent(plans)}`);
  });

  it('builds same-origin Google OAuth start URL when apiBase is empty', () => {
    const loc = { href: `${origin}/login`, pathname: '/login', origin };
    const url = buildGoogleOAuthStartUrl('', loc);
    expect(url).toBe(
      `/auth/google_oauth2?return_to=${encodeURIComponent(`${origin}/`)}`
    );
  });

  it('oauthReturnToUrl tolerates missing location', () => {
    const origin = window.location?.origin;
    expect(oauthReturnToUrl(undefined)).toBe(origin ? `${origin}/` : '/');
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
