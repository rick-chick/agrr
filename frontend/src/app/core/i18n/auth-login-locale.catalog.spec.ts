import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by login.component template. */
const AUTH_LOGIN_KEYS = [
  'auth.login.title',
  'auth.login.subtitle',
  'auth.login.google_button',
  'auth.login.dev_login_title',
  'auth.login.dev_login_as_developer',
  'auth.login.dev_login_as_farmer',
  'auth.login.dev_login_as_researcher',
  'auth.login.dev_login_note'
] as const;

/** in locale must not reuse English copy for these keys (visual-review #7). */
const IN_LOCALE_MUST_DIFFER_FROM_EN = ['auth.login.subtitle', 'auth.login.dev_login_note'] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('auth.login i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of AUTH_LOGIN_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses Hindi (not English copy) for in locale subtitle and dev note', () => {
    for (const key of IN_LOCALE_MUST_DIFFER_FROM_EN) {
      const inValue = getNested(inLocale as JsonRecord, key) as string;
      const enValue = getNested(en as JsonRecord, key) as string;
      expect(inValue, `${key} must not match en.json`).not.toBe(enValue);
    }
  });
});
