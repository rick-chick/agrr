import { describe, it, expect } from 'vitest';
import {
  buildMockLoginUrl,
  buildOAuthLoginUrl,
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

  it('builds OAuth login URL with encoded return_to', () => {
    const loc = { href: `${origin}/login`, pathname: '/login', origin };
    const url = buildOAuthLoginUrl('http://localhost:3000', 'ja', loc);
    expect(url).toContain(`return_to=${encodeURIComponent(`${origin}/`)}`);
    expect(url).toBe('http://localhost:3000/ja/auth/login?return_to=http%3A%2F%2Flocalhost%3A4200%2F');
  });

  it('builds dev mock login URLs on strangler :3000', () => {
    const loc = { href: `${origin}/login`, pathname: '/login', origin };
    const apiBase = 'http://localhost:3000';
    expect(buildMockLoginUrl(apiBase, 'developer', loc)).toBe(
      `${apiBase}/auth/test/mock_login_as/developer?return_to=${encodeURIComponent(`${origin}/`)}`
    );
    expect(buildMockLoginUrl(apiBase, 'farmer', loc)).toContain('/auth/test/mock_login_as/farmer?return_to=');
    expect(buildMockLoginUrl(apiBase, 'researcher', loc)).toContain(
      '/auth/test/mock_login_as/researcher?return_to='
    );
  });
});
