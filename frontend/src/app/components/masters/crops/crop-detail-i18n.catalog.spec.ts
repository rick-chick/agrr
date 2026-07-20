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

/** Keys referenced by crop-detail.component.ts on the crop show screen. */
const CROP_DETAIL_CATALOG_KEYS = [
  'crops.show.stages_title',
  'crops.show.task_schedule_blueprints_title',
  'crops.show.task_schedule_blueprints_lead',
  'crops.show.task_schedule_blueprints_gdd_axis_caption',
  'crops.show.stage_required_gdd_label',
  'crops.show.gdd_unit',
  'crops.show.optimal_temperature',
  'crops.show.celsius_unit',
  'crops.show.blueprint_readiness.detail_title',
  'crops.show.blueprint_readiness.stages_edit_action',
  'crops.show.blueprint_readiness.stages_action',
  'crops.show.blueprint_summary.edit_action',
  'crops.show.blueprint_stage_lane.gdd_range'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('CropDetailComponent i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of CROP_DETAIL_CATALOG_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).length).toBeGreaterThan(0);
        });
      }
    });
  }
});
