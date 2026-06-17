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

/** Keys referenced by plan-work-records and plan-work-nav on the history screen. */
const PLANS_WORK_RECORDS_KEYS = [
  'plans.work.back_to_plan',
  'plans.work_records.title',
  'plans.work_records.empty',
  'plans.work_records.badge.from_schedule',
  'plans.work_records.badge.adhoc',
  'plans.work_records.sheet.edit_title',
  'plans.work_records.sheet.save',
  'plans.work_records.sheet.delete',
  'plans.work_records.sheet.delete_confirm'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('plans.work_records i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of PLANS_WORK_RECORDS_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }
});
