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

/** Canonical per-area daily nutrient uptake unit (matches DB/agrr stored values and placeholders). */
const CANONICAL_UNIT = /g\/m[²2]\/day/i;
const WRONG_UNIT = /kg\/ha\/day/i;

const EDIT_KEYS = [
  'crops.edit.daily_uptake_n',
  'crops.edit.daily_uptake_p',
  'crops.edit.daily_uptake_k'
] as const;

const STAGE_NUTRIENT_LABEL_KEYS = [
  'crops.stage.nutrient.daily_uptake_n_label',
  'crops.stage.nutrient.daily_uptake_p_label',
  'crops.stage.nutrient.daily_uptake_k_label'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('crops nutrient uptake unit consistency', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of STAGE_NUTRIENT_LABEL_KEYS) {
        it(`defines ${key} with canonical unit`, () => {
          const value = getNested(catalog, key);
          expect(value, `${name}: missing ${key}`).toBeTruthy();
          expect(String(value)).toMatch(CANONICAL_UNIT);
          expect(String(value)).not.toMatch(WRONG_UNIT);
        });
      }

      for (const key of EDIT_KEYS) {
        it(`${key} uses same canonical unit as stage nutrient labels`, () => {
          const value = getNested(catalog, key);
          expect(value, `${name}: missing ${key}`).toBeTruthy();
          expect(String(value)).toMatch(CANONICAL_UNIT);
          expect(String(value)).not.toMatch(WRONG_UNIT);
        });
      }
    });
  }
});
