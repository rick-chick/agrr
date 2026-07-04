import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in UI strings for crop show. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by crop-detail.component.ts on the crops show screen. */
const CROPS_SHOW_KEYS = [
  'crops.show.name',
  'crops.show.variety',
  'crops.show.area_per_unit',
  'crops.show.area_unit',
  'crops.show.revenue_per_area',
  'crops.show.revenue_unit',
  'crops.show.groups',
  'crops.show.region',
  'crops.show.created_at',
  'crops.show.updated_at',
  'crops.show.stages_title',
  'crops.show.required_gdd',
  'crops.show.gdd_unit',
  'crops.show.optimal_temperature',
  'crops.show.celsius_unit',
  'crops.show.agricultural_tasks_title',
  'crops.show.from_plan_wizard_title',
  'crops.show.from_plan_wizard_lead',
  'crops.show.agricultural_tasks_step_label',
  'crops.show.agricultural_tasks_description',
  'crops.show.no_agricultural_tasks_description',
  'crops.show.reference_task',
  'crops.show.task_schedule_blueprints_title',
  'crops.show.task_schedule_blueprints_step_label',
  'crops.show.task_schedule_blueprints_description_html',
  'crops.show.task_schedule_blueprints_description_empty_html',
  'crops.show.no_task_schedule_blueprints',
  'crops.show.gdd_trigger',
  'crops.show.stage_name',
  'crops.show.manual_blueprint_add.title',
  'crops.show.manual_blueprint_add.description',
  'crops.show.manual_blueprint_add.prerequisites',
  'crops.show.manual_blueprint_add.stage_label',
  'crops.show.manual_blueprint_add.stage_placeholder',
  'crops.show.manual_blueprint_add.task_label',
  'crops.show.manual_blueprint_add.task_placeholder',
  'crops.show.manual_blueprint_add.gdd_label',
  'crops.show.manual_blueprint_add.submit',
  'crops.show.manual_blueprint_add.ai_hint',
  'crops.show.generate_task_schedule_blueprints_button',
  'crops.show.generate_task_schedule_blueprints_confirm',
  'crops.show.blueprint_readiness.title',
  'crops.show.blueprint_readiness.templates_ready',
  'crops.show.blueprint_readiness.templates_missing',
  'crops.show.blueprint_readiness.templates_action',
  'crops.show.blueprint_readiness.stages_ready',
  'crops.show.blueprint_readiness.stages_missing',
  'crops.show.blueprint_readiness.stages_action',
  'crops.show.blueprint_errors.missing_task_templates',
  'crops.show.blueprint_errors.missing_agrr_requirement',
  'crops.show.blueprint_errors.blueprint_generation_failed',
  'crops.show.blueprint_errors.ai_unavailable',
  'crops.show.blueprint_errors.ai_execution_failed',
  'crops.show.blueprint_errors.generic',
  'crops.show.blueprint_errors.retry_action',
  'crops.show.delete_blueprint',
  'crops.show.delete_blueprint_confirm',
  'crops.agricultural_tasks.new.associate_existing_task',
  'crops.agricultural_tasks.new.associate_existing_task_description',
  'crops.agricultural_tasks.new.select_existing_task',
  'crops.agricultural_tasks.new.select_task_placeholder',
  'crops.agricultural_tasks.new.associate_button',
  'crops.agricultural_tasks.new.no_unassociated_tasks',
  'crops.agricultural_tasks.new.no_unassociated_tasks_all_templated',
  'crops.agricultural_tasks.new.go_to_create',
  'crops.agricultural_tasks.index.actions.delete_confirm',
  'crops.form.region_jp',
  'crops.form.region_us',
  'crops.form.region_in'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('crops show i18n catalog (crop-detail)', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of CROPS_SHOW_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(value, `${name}: missing ${key}`).toBeTruthy();
          expect(typeof value, `${name}: ${key} must be a string`).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses Japanese region label in ja locale', () => {
    expect(getNested(ja as JsonRecord, 'crops.show.region')).toBe('地域');
  });

  it('uses English (not Japanese) for en crops.show strings', () => {
    for (const key of CROPS_SHOW_KEYS) {
      const value = getNested(en as JsonRecord, key);
      expect(value, `unexpected Japanese in en.json: ${key}=${value}`).not.toMatch(JAPANESE_UI);
    }
    expect(getNested(en as JsonRecord, 'crops.show.region')).toBe('Region');
  });

  it('uses Hindi (not Japanese) for in crops.show strings', () => {
    for (const key of CROPS_SHOW_KEYS) {
      const value = getNested(inLocale as JsonRecord, key);
      expect(value, `unexpected Japanese in in.json: ${key}=${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
