import { afterEach, describe, expect, it, vi } from 'vitest';

describe('getApiBaseUrl', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.resetModules();
  });

  it('returns empty string when proxySameOriginApi is enabled', async () => {
    vi.stubGlobal('window', { API_BASE_URL: undefined, location: { hostname: '127.0.0.1', port: '4200' } });
    const { getApiBaseUrl } = await import('./api-base-url');
    expect(getApiBaseUrl()).toBe('');
  });

  it('prefers window.API_BASE_URL when set', async () => {
    vi.stubGlobal('window', {
      API_BASE_URL: 'https://api.example.test',
      location: { hostname: '127.0.0.1', port: '4200' }
    });
    const { getApiBaseUrl } = await import('./api-base-url');
    expect(getApiBaseUrl()).toBe('https://api.example.test');
  });
});
