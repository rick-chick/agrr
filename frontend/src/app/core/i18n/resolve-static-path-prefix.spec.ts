import { afterEach, describe, expect, it, vi } from 'vitest';

describe('resolveStaticPathPrefix', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.resetModules();
  });

  it('prefers window.STATIC_PATH_PREFIX when set', async () => {
    vi.stubGlobal('window', { STATIC_PATH_PREFIX: 'static' });
    const { resolveStaticPathPrefix } = await import('./resolve-static-path-prefix');
    expect(resolveStaticPathPrefix()).toBe('static');
  });

  it('infers prefix from module main script src when window value is missing', async () => {
    vi.stubGlobal('window', { STATIC_PATH_PREFIX: undefined });
    vi.stubGlobal('document', {
      querySelector: vi.fn(() => ({ getAttribute: () => '/static/main-ABC123.js' })),
    });
    const { resolveStaticPathPrefix } = await import('./resolve-static-path-prefix');
    expect(resolveStaticPathPrefix()).toBe('static');
  });

  it('returns empty string for local dev without prefix', async () => {
    vi.stubGlobal('window', { STATIC_PATH_PREFIX: undefined });
    vi.stubGlobal('document', {
      querySelector: vi.fn(() => ({ getAttribute: () => '/main.js' })),
    });
    const { resolveStaticPathPrefix } = await import('./resolve-static-path-prefix');
    expect(resolveStaticPathPrefix()).toBe('');
  });
});
