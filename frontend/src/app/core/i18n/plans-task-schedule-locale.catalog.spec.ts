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
  'plans.task_schedules.no_schedules'
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
