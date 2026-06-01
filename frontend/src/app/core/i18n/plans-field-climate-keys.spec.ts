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

/** Keys referenced by PlanFieldClimateComponent (template + chart labels). */
const FIELD_CLIMATE_KEYS = [
  'plans.field_climate.header_title_fallback',
  'plans.field_climate.header_subtitle_fallback',
  'plans.field_climate.period_unknown',
  'plans.field_climate.close',
  'plans.field_climate.loading',
  'plans.field_climate.load_failed',
  'plans.field_climate.load_unknown',
  'plans.field_climate.retry',
  'plans.field_climate.base_temperature',
  'plans.field_climate.optimal_range',
  'plans.field_climate.current_stage',
  'plans.field_climate.stage_gdd_value',
  'plans.field_climate.daily_temperature',
  'plans.field_climate.gdd_progress',
  'plans.field_climate.chart.temperature',
  'plans.field_climate.chart.cumulative_gdd',
  'plans.field_climate.chart.min_temp',
  'plans.field_climate.chart.mean_temp',
  'plans.field_climate.chart.max_temp',
  'plans.field_climate.chart.daily_gdd',
  'plans.field_climate.chart.tooltip_format',
  'plans.field_climate.chart.required_cumulative_gdd',
  'plans.detail.select_cultivation_hint'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('plans.field_climate translation files', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of FIELD_CLIMATE_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }

      it('does not define js.field_climate (legacy namespace)', () => {
        expect(getNested(catalog, 'js.field_climate')).toBeUndefined();
      });
    });
  }
});
