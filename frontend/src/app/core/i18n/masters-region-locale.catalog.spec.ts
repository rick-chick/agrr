import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in master region labels. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Region labels referenced by master edit/show screens (crops, tasks, fertilizes). */
const MASTERS_REGION_LABEL_KEYS = [
  'crops.show.region',
  'crops.edit.region',
  'agricultural_tasks.show.region',
  'fertilizes.form.region_label'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('masters region label i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of MASTERS_REGION_LABEL_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses English region labels in en locale (no Japanese fallback)', () => {
    for (const key of MASTERS_REGION_LABEL_KEYS) {
      const value = getNested(en as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in en.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
      if (key.endsWith('.region') || key.endsWith('region_label')) {
        expect(value.toLowerCase()).toContain('region');
      }
    }
  });

  it('uses non-Japanese region labels in in locale', () => {
    for (const key of MASTERS_REGION_LABEL_KEYS) {
      const value = getNested(inLocale as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in in.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
