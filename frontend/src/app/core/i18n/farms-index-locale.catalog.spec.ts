import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in UI strings for farm list. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

type FarmsIndexBundle = {
  title?: string;
  description?: string;
  new_farm?: string;
  reference_badge?: string;
};

function farmsIndex(bundle: JsonRecord): FarmsIndexBundle {
  const farms = (bundle['farms'] as JsonRecord) ?? {};
  return (farms['index'] as FarmsIndexBundle) ?? {};
}

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by farm-list.component.ts on the farms index screen. */
const CATALOG_KEYS = [
  'farms.index.title',
  'farms.index.description',
  'farms.index.new_farm',
  'farms.index.reference_badge'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('farms index i18n catalog (farm-list)', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of CATALOG_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('ja reference_badge matches reference farm wording', () => {
    expect(farmsIndex(ja as JsonRecord).reference_badge).toBe('参照農場');
  });

  it('en reference_badge is short label for inline badge', () => {
    expect(farmsIndex(en as JsonRecord).reference_badge).toBe('Reference');
  });

  it('in reference_badge uses Hindi reference farm label', () => {
    expect(farmsIndex(inLocale as JsonRecord).reference_badge).toBe('संदर्भ खेत');
  });

  it('uses English (not Japanese) for en locale index strings', () => {
    const index = farmsIndex(en as JsonRecord);
    const enStrings = [index.title, index.description, index.new_farm, index.reference_badge];
    for (const value of enStrings) {
      expect(value, `unexpected Japanese in en.json: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in locale index strings', () => {
    const index = farmsIndex(inLocale as JsonRecord);
    const inStrings = [index.title, index.description, index.new_farm, index.reference_badge];
    for (const value of inStrings) {
      expect(value, `unexpected Japanese in in.json: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
