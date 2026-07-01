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

/** Keys referenced by plan-task-schedule and task-schedule-timeline components. */
const PLANS_TASK_SCHEDULE_KEYS = [
  'plans.task_schedules.title',
  'plans.task_schedules.back_to_plan',
  'plans.task_schedules.general_label',
  'plans.task_schedules.fertilizer_label',
  'plans.task_schedules.no_schedules',
  'plans.task_schedules.status.planned',
  'plans.task_schedules.status.skipped',
  'plans.task_schedules.status.completed',
  'plans.task_schedules.field_section',
  'plans.task_schedules.field_number',
  'plans.task_schedules.sync_never',
  'plans.task_schedules.sync_failed',
  'plans.task_schedules.sync_generating',
  'plans.task_schedules.sync_stale',
  'plans.task_schedules.sync_updated',
  'plans.task_schedules.sync_retry',
  'plans.task_schedules.sync_errors.missing_weather',
  'plans.task_schedules.sync_errors.missing_crop_templates',
  'plans.task_schedules.sync_errors.missing_general_templates',
  'plans.task_schedules.sync_errors.empty_gdd_progress',
  'plans.task_schedules.sync_errors.missing_gdd_trigger',
  'plans.task_schedules.sync_errors.gdd_date_not_found',
  'plans.task_schedules.sync_errors.missing_start_date',
  'plans.task_schedules.sync_errors.agrr_unavailable',
  'plans.task_schedules.sync_errors.generic'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('plans.task_schedules i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of PLANS_TASK_SCHEDULE_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }
});
