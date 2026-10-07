import { afterEach, describe, expect, it } from 'vitest';
import { getTurnstileSiteKey } from './turnstile-runtime-config';

describe('getTurnstileSiteKey', () => {
  afterEach(() => {
    delete (window as { TURNSTILE_SITE_KEY?: string }).TURNSTILE_SITE_KEY;
  });

  it('prefers window.TURNSTILE_SITE_KEY', () => {
    window.TURNSTILE_SITE_KEY = '  window-key  ';
    expect(getTurnstileSiteKey()).toBe('window-key');
  });

  it('falls back to environment when window is empty', () => {
    window.TURNSTILE_SITE_KEY = '   ';
    expect(getTurnstileSiteKey()).toBe('1x00000000000000000000AA');
  });
});
