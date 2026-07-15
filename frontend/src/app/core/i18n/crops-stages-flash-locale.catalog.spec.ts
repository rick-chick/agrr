import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in UI strings for crop stage flash toasts. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Success flash keys referenced by crop-stages.presenter.ts */
const CROPS_STAGES_FLASH_KEYS = [
  'crops.flash.stage_created',
  'crops.flash.stage_updated',
  'crops.flash.stage_deleted',
  'crops.flash.temperature_requirement_updated',
  'crops.flash.thermal_requirement_updated',
  'crops.flash.sunshine_requirement_updated',
  'crops.flash.nutrient_requirement_updated'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('crops stages flash i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of CROPS_STAGES_FLASH_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(value, `${name}: missing ${key}`).toBeTruthy();
          expect(typeof value, `${name}: ${key} must be a string`).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses English (not Japanese) for en crops.flash stage strings', () => {
    for (const key of CROPS_STAGES_FLASH_KEYS) {
      const value = getNested(en as JsonRecord, key);
      expect(value, `unexpected Japanese in en.json: ${key}=${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in crops.flash stage strings', () => {
    for (const key of CROPS_STAGES_FLASH_KEYS) {
      const value = getNested(inLocale as JsonRecord, key);
      expect(value, `unexpected Japanese in in.json: ${key}=${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
