import { describe, expect, it } from 'vitest';
import {
  APP_LANG_STORAGE_KEY,
  buildCaptureLocaleInitPayload,
} from '../../../e2e/capture-locales.mjs';

describe('buildCaptureLocaleInitPayload', () => {
  it('presets agrr.app.lang for capture locale switching', () => {
    expect(buildCaptureLocaleInitPayload('en')).toEqual({
      navLang: 'en-US',
      railsLocale: 'us',
      appLang: 'en',
      storageKey: APP_LANG_STORAGE_KEY,
    });
    expect(buildCaptureLocaleInitPayload('in').appLang).toBe('in');
    expect(buildCaptureLocaleInitPayload('ja').appLang).toBe('ja');
  });
});
