import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in plans.new strings. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by plan-new page heading and description. */
const PLANS_NEW_DESCRIPTION_KEYS = ['plans.new.title', 'plans.new.subtitle'] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('plans.new i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of PLANS_NEW_DESCRIPTION_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('does not mention year in en title or subtitle (form has no year field)', () => {
    for (const key of PLANS_NEW_DESCRIPTION_KEYS) {
      const value = getNested(en as JsonRecord, key) as string;
      expect(value, `${key} must not mention year`).not.toMatch(/\byear\b/i);
    }
  });

  it('does not mention year in in title or subtitle (form has no year field)', () => {
    for (const key of PLANS_NEW_DESCRIPTION_KEYS) {
      const value = getNested(inLocale as JsonRecord, key) as string;
      expect(value, `${key} must not mention year (वर्ष)`).not.toMatch(/वर्ष/);
    }
  });

  it('does not mention year in ja title or subtitle', () => {
    for (const key of PLANS_NEW_DESCRIPTION_KEYS) {
      const value = getNested(ja as JsonRecord, key) as string;
      expect(value, `${key} must not mention year (年)`).not.toMatch(/年/);
    }
  });

  it('uses English (not Japanese) for en locale plans.new strings', () => {
    for (const key of PLANS_NEW_DESCRIPTION_KEYS) {
      const value = getNested(en as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in en.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in locale plans.new strings', () => {
    for (const key of PLANS_NEW_DESCRIPTION_KEYS) {
      const value = getNested(inLocale as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in in.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
