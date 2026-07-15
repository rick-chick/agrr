import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in UI strings for crop edit. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by crop-stages.component.ts (cumulative GDD + requirement field hints). */
const CROPS_EDIT_KEYS = [
  'crops.edit.stage_cumulative_gdd_range',
  'crops.edit.stage_cumulative_gdd_missing',
  'crops.edit.base_temperature_placeholder',
  'crops.edit.base_temperature_help',
  'crops.edit.required_gdd_placeholder',
  'crops.edit.required_gdd_help',
  'crops.edit.stage_order_duplicate',
  'crops.edit.save_stage',
  'crops.edit.edit_temperature_details',
  'crops.edit.edit_sunshine_nutrient',
  'crops.edit.temperature_details_title',
  'crops.edit.advanced_details_title',
  'crops.edit.unsaved_confirm_message',
  'crops.edit.table_order',
  'crops.edit.table_stage_name',
  'crops.edit.table_base_temperature',
  'crops.edit.table_required_gdd',
  'crops.edit.table_cumulative_gdd',
  'crops.edit.value_missing'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('crops edit i18n catalog (crop-stages)', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of CROPS_EDIT_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(value, `${name}: missing ${key}`).toBeTruthy();
          expect(typeof value, `${name}: ${key} must be a string`).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses English (not Japanese) for en crops.edit cumulative GDD strings', () => {
    for (const key of CROPS_EDIT_KEYS) {
      const value = getNested(en as JsonRecord, key);
      expect(value, `unexpected Japanese in en.json: ${key}=${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in crops.edit cumulative GDD strings', () => {
    for (const key of CROPS_EDIT_KEYS) {
      const value = getNested(inLocale as JsonRecord, key);
      expect(value, `unexpected Japanese in in.json: ${key}=${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
