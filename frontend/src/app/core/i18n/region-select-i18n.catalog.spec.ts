import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in UI strings for region select. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by RegionSelectComponent. */
const REGION_SELECT_KEYS = [
  'shared.region_select.label',
  'shared.region_select.blank',
  'shared.region_select.jp',
  'shared.region_select.us',
  'shared.region_select.in'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('region-select i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of REGION_SELECT_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses non-Japanese strings for shared.region_select in en locale', () => {
    for (const key of REGION_SELECT_KEYS) {
      const value = getNested(en as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in en.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses non-Japanese strings for shared.region_select in in locale', () => {
    for (const key of REGION_SELECT_KEYS) {
      const value = getNested(inLocale as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in in.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
