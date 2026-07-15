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

/** Crop-stage base_temperature label keys that must use the same product term. */
const CROP_BASE_TEMPERATURE_LABEL_KEYS = [
  'crops.edit.base_temperature',
  'crops.show.base_temperature',
  'crops.stage.temperature.base_temperature_label',
  'plans.field_climate.base_temperature'
] as const;

/** Readiness / wizard copy that refers to crop-stage base_temperature (ja must not use 基準温度 or 最低限界温度). */
const CROP_BASE_TEMPERATURE_MESSAGE_KEYS = [
  'crops.show.blueprint_readiness.stages_ready',
  'crops.show.blueprint_readiness.stages_missing',
  'crops.show.blueprint_errors.missing_agrr_requirement',
  'crops.show.from_plan_stages_wizard_lead'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

function stripUnitSuffix(value: string): string {
  return value.replace(/\s*\([^)]*\)\s*$/, '').trim();
}

describe('crops base_temperature terminology catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of CROP_BASE_TEMPERATURE_LABEL_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(value, `${name}: missing ${key}`).toBeTruthy();
          expect(typeof value, `${name}: ${key} must be a string`).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses 基底温度 consistently for crop base_temperature labels in ja', () => {
    const cores = CROP_BASE_TEMPERATURE_LABEL_KEYS.map((key) =>
      stripUnitSuffix(getNested(ja as JsonRecord, key) as string)
    );
    expect(cores.every((core) => core === '基底温度'), cores.join(' | ')).toBe(true);
  });

  it('does not use 最低限界温度 or 基準温度 in crop base_temperature labels (ja)', () => {
    for (const key of CROP_BASE_TEMPERATURE_LABEL_KEYS) {
      const value = getNested(ja as JsonRecord, key) as string;
      expect(value, key).not.toContain('最低限界温度');
      expect(value, key).not.toContain('基準温度');
    }
  });

  it('uses base temperature wording consistently in crop readiness messages (ja)', () => {
    for (const key of CROP_BASE_TEMPERATURE_MESSAGE_KEYS) {
      const value = getNested(ja as JsonRecord, key) as string;
      expect(value, key).toContain('基底温度');
      expect(value, key).not.toContain('基準温度');
      expect(value, key).not.toContain('最低限界温度');
    }
  });

  it('uses Base Temperature consistently for crop base_temperature labels in en', () => {
    for (const key of CROP_BASE_TEMPERATURE_LABEL_KEYS) {
      const value = getNested(en as JsonRecord, key) as string;
      expect(value.toLowerCase(), key).toContain('base temperature');
    }
  });

  it('uses आधार तापमान consistently for crop base_temperature labels in in', () => {
    for (const key of CROP_BASE_TEMPERATURE_LABEL_KEYS) {
      const value = getNested(inLocale as JsonRecord, key) as string;
      expect(value, key).toContain('आधार तापमान');
    }
  });
});
