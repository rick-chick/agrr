import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in UI strings for farm show. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by farm-detail (farms show screen). */
const FARMS_SHOW_KEYS = [
  'farms.show.location',
  'farms.show.back_to_list',
  'farms.show.weather_status',
  'farms.show.weather_progress',
  'farms.show.map.title',
  'farms.show.fields',
  'farms.show.add_field',
  'farms.show.no_fields',
  'farms.show.add_first_field',
  'farms.show.field_form.edit_title',
  'farms.show.field_form.add_title',
  'farms.show.field_form.name_label',
  'farms.show.field_form.name_placeholder',
  'farms.show.field_form.area_label',
  'farms.show.field_form.area_placeholder',
  'farms.show.field_form.daily_fixed_cost_label',
  'farms.show.field_form.daily_fixed_cost_placeholder',
  'farms.show.field_form.region_label',
  'farms.show.field_form.region_placeholder',
  'farms.show.field_form.submit_update',
  'farms.show.field_form.submit_create'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('farms show i18n catalog (farm-detail)', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of FARMS_SHOW_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(value, `${name}: missing ${key}`).toBeTruthy();
          expect(typeof value, `${name}: ${key} must be a string`).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses natural Japanese for farms.show.location in ja (matches farms.form.region_label)', () => {
    expect(getNested(ja as JsonRecord, 'farms.show.location')).toBe('地域');
    expect(getNested(ja as JsonRecord, 'farms.form.region_label')).toBe('地域');
  });

  it('uses English (not Japanese) for en farms.show strings', () => {
    for (const key of FARMS_SHOW_KEYS) {
      const value = getNested(en as JsonRecord, key);
      expect(value, `unexpected Japanese in en.json: ${key}=${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in farms.show strings', () => {
    for (const key of FARMS_SHOW_KEYS) {
      const value = getNested(inLocale as JsonRecord, key);
      expect(value, `unexpected Japanese in in.json: ${key}=${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
