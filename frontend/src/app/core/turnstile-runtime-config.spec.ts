import { afterEach, describe, expect, it, vi } from 'vitest';
import { getTurnstileSiteKey } from './turnstile-runtime-config';

describe('getTurnstileSiteKey', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    delete (window as Window & { TURNSTILE_SITE_KEY?: string }).TURNSTILE_SITE_KEY;
  });

  it('prefers window.TURNSTILE_SITE_KEY over environment', () => {
    vi.stubGlobal('window', { TURNSTILE_SITE_KEY: '  window-key  ' });
    expect(getTurnstileSiteKey()).toBe('window-key');
  });

  it('falls back to environment when window is unset', () => {
    vi.stubGlobal('window', {});
    expect(getTurnstileSiteKey()).toBe('1x00000000000000000000AA');
  });
});
