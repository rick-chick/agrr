import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

const MASTER_COMMON_CATALOG_KEYS = [
  'agricultural_tasks.edit.title_default',
  'agricultural_tasks.errors.invalid_id',
  'agricultural_tasks.show.task_type',
  'common.creating',
  'common.breadcrumb_label',
  'common.sending',
  'common.updating',
  'shared.cookie_consent.title',
  'shared.cookie_consent.accept',
  'shared.cookie_consent.reject',
  'farms.map.default_name',
  'farms.new.form.coordinates_validation_error',
  'interaction_rules.errors.invalid_id',
  'pesticides.edit.title_default',
  'pesticides.fallback.crop',
  'pesticides.fallback.pest',
  'public_plans.create_failed',
  'public_plans.invalid_farm_id',
  'crops.show.reference_crop'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('i18n master/common catalog (#633)', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of MASTER_COMMON_CATALOG_KEYS) {
        it(`defines ${key} as human-readable text`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          const text = value as string;
          expect(text.length).toBeGreaterThan(0);
          expect(text).not.toBe(key);
          expect(text).not.toContain('cookie_consent.');
          expect(text).not.toContain('title_default');
        });
      }
    });
  }
});
