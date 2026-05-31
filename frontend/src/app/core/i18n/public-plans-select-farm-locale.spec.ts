import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in public plan select-farm strings. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by public-plan-create farm selection heading. */
const SELECT_FARM_KEYS = ['public_plans.select_farm.available_farms'] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('public_plans select_farm i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of SELECT_FARM_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses English (not Japanese) for en locale select_farm strings', () => {
    for (const key of SELECT_FARM_KEYS) {
      const value = getNested(en as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in en.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in locale select_farm strings', () => {
    for (const key of SELECT_FARM_KEYS) {
      const value = getNested(inLocale as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in in.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
