import { describe, expect, it } from 'vitest';

import en from '../../../../assets/i18n/en.json';
import inLocale from '../../../../assets/i18n/in.json';
import ja from '../../../../assets/i18n/ja.json';

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

const CROP_EDIT_CATALOG_KEYS = [
  'crops.edit.title',
  'crops.edit.stages_title',
  'crops.edit.add_stage',
  'crops.edit.stage_title',
  'crops.edit.stage_name',
  'crops.edit.stage_order',
  'crops.edit.requirements_title',
  'crops.edit.temperature_requirement',
  'crops.edit.thermal_requirement',
  'crops.edit.sunshine_requirement',
  'crops.edit.nutrient_requirement',
  'crops.edit.base_temperature',
  'crops.edit.optimal_min',
  'crops.edit.optimal_max',
  'crops.edit.low_stress_threshold',
  'crops.edit.high_stress_threshold',
  'crops.edit.frost_threshold',
  'crops.edit.sterility_risk_threshold',
  'crops.edit.max_temperature',
  'crops.edit.required_gdd',
  'crops.edit.minimum_sunshine_hours',
  'crops.edit.target_sunshine_hours',
  'crops.edit.daily_uptake_n',
  'crops.edit.daily_uptake_p',
  'crops.edit.daily_uptake_k',
  'crops.edit.region',
  'crops.errors.invalid_id',
  'crops.stage.default_name',
  'crops.stage.confirm_delete',
  'crops.stage.delete_confirm_message',
  'crops.stage.delete_confirm_blueprint_warning'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('CropEditComponent i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of CROP_EDIT_CATALOG_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).length).toBeGreaterThan(0);
        });
      }
    });
  }
});
