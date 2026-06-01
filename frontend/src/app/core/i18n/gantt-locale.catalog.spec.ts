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

/** Keys referenced by gantt-chart.component (UI-visible). */
const GANTT_KEYS = [
  'plans.gantt.optimizing',
  'plans.gantt.range.prev_month',
  'plans.gantt.range.next_month',
  'plans.gantt.no_plan_data',
  'plans.gantt.no_field_data',
  'plans.gantt.no_data',
  'plans.gantt.adjust_failed',
  'plans.gantt.trash_drop_label',
  'plans.gantt.labels.year',
  'plans.gantt.labels.month',
  'plans.gantt.labels.day',
  'plans.gantt.labels.week',
  'plans.gantt.labels.quarter',
  'js.gantt.add_crop_button',
  'js.gantt.crop_palette_cancel',
  'js.gantt.add_field_button',
  'js.gantt.crop_palette_title',
  'js.gantt.crop_palette_no_crops',
  'js.gantt.field_form_name_label',
  'js.gantt.field_form_name_placeholder',
  'js.gantt.field_form_area_label',
  'js.gantt.field_form_area_placeholder',
  'js.gantt.field_form_submit',
  'js.gantt.adding_field_loading',
  'plans.gantt.mobile.field_column_short',
  'plans.gantt.mobile.field_legend_button',
  'plans.gantt.mobile.field_legend_title',
  'plans.gantt.mobile.field_legend_item',
  'plans.gantt.mobile.field_legend_delete',
  'plans.gantt.mobile.drag_target_field',
  'js.gantt.logs.data_refetch_failed',
  'js.gantt.logs.data_refetch_api_error'
] as const;

/** English uses empty axis suffixes for year/month (e.g. "2026", "5"). */
const EN_ALLOW_EMPTY_KEYS = new Set<string>([
  'plans.gantt.labels.year',
  'plans.gantt.labels.month'
]);

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('gantt i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of GANTT_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          if (name === 'en' && EN_ALLOW_EMPTY_KEYS.has(key)) {
            return;
          }
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }
});
