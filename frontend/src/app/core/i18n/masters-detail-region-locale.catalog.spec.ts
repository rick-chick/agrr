import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in UI strings for master detail region. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Region label + value keys for agricultural-task-detail (matches crop-detail pattern). */
const AGRICULTURAL_TASK_DETAIL_REGION_KEYS = [
  'agricultural_tasks.show.region',
  'agricultural_tasks.form.region_jp',
  'agricultural_tasks.form.region_us',
  'agricultural_tasks.form.region_in'
] as const;

/** Region label + value keys for fertilize-detail. */
const FERTILIZE_DETAIL_REGION_KEYS = [
  'fertilizes.form.region_label',
  'fertilizes.form.region_jp',
  'fertilizes.form.region_us',
  'fertilizes.form.region_in'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('masters detail region i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of [...AGRICULTURAL_TASK_DETAIL_REGION_KEYS, ...FERTILIZE_DETAIL_REGION_KEYS]) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(value, `${name}: missing ${key}`).toBeTruthy();
          expect(typeof value, `${name}: ${key} must be a string`).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses English region labels and values in en locale', () => {
    for (const key of [...AGRICULTURAL_TASK_DETAIL_REGION_KEYS, ...FERTILIZE_DETAIL_REGION_KEYS]) {
      const value = getNested(en as JsonRecord, key);
      expect(value, `unexpected Japanese in en.json: ${key}=${value}`).not.toMatch(JAPANESE_UI);
    }
    expect(getNested(en as JsonRecord, 'agricultural_tasks.show.region')).toBe('Region');
    expect(getNested(en as JsonRecord, 'agricultural_tasks.form.region_jp')).toBe('Japan');
  });

  it('uses Hindi (not Japanese) for in master detail region strings', () => {
    for (const key of [...AGRICULTURAL_TASK_DETAIL_REGION_KEYS, ...FERTILIZE_DETAIL_REGION_KEYS]) {
      const value = getNested(inLocale as JsonRecord, key);
      expect(value, `unexpected Japanese in in.json: ${key}=${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
