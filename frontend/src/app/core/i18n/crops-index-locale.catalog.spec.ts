import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in UI strings for crop list. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

type CropsIndexBundle = {
  title?: string;
  description?: string;
  new_crop?: string;
  reference_badge?: string;
};

function cropsIndex(bundle: JsonRecord): CropsIndexBundle {
  const crops = (bundle['crops'] as JsonRecord) ?? {};
  return (crops['index'] as CropsIndexBundle) ?? {};
}

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by crop-list.component.ts on the crops index screen. */
const CATALOG_KEYS = [
  'crops.index.title',
  'crops.index.description',
  'crops.index.new_crop',
  'crops.index.reference_badge'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('crops index i18n catalog (crop-list)', () => {
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

  it('ja reference_badge matches reference crop wording', () => {
    expect(cropsIndex(ja as JsonRecord).reference_badge).toBe('参照作物');
  });

  it('en reference_badge is short label for inline badge', () => {
    expect(cropsIndex(en as JsonRecord).reference_badge).toBe('Reference');
  });

  it('in reference_badge uses Hindi reference crop label', () => {
    expect(cropsIndex(inLocale as JsonRecord).reference_badge).toBe('संदर्भ फसल');
  });

  it('uses English (not Japanese) for en locale index strings', () => {
    const index = cropsIndex(en as JsonRecord);
    const enStrings = [index.title, index.description, index.new_crop, index.reference_badge];
    for (const value of enStrings) {
      expect(value, `unexpected Japanese in en.json: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in locale index strings', () => {
    const index = cropsIndex(inLocale as JsonRecord);
    const inStrings = [index.title, index.description, index.new_crop, index.reference_badge];
    for (const value of inStrings) {
      expect(value, `unexpected Japanese in in.json: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
