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

/** Keys referenced by plan-work, plan-work-nav, and work-record-sheet on plans/:id/work. */
const PLANS_WORK_KEYS = [
  'plans.work.back_to_plan',
  'plans.work.back_to_hub',
  'plans.work.page_title',
  'plans.work.show_skipped',
  'plans.work.section.overdue',
  'plans.work.section.today',
  'plans.work.section.upcoming',
  'plans.work.empty_today',
  'plans.work.empty_today_hint',
  'plans.work.add_record',
  'plans.work.recorded_today',
  'plans.work.skipped_badge',
  'plans.work.complete',
  'plans.work.record_with_details',
  'plans.work.menu',
  'plans.work.skip',
  'plans.work.unskip',
  'plans.work.retry',
  'plans.work.toast.record_saved',
  'plans.work.toast.record_saved_adhoc',
  'plans.work.recent_adhoc',
  'plans.work.recent_adhoc_history_link',
  'plans.work.nav.work',
  'plans.work.nav.schedule',
  'plans.work.nav.history',
  'plans.work.sheet.title',
  'plans.work.sheet.name',
  'plans.work.sheet.actual_date',
  'plans.work.sheet.amount',
  'plans.work.sheet.amount_unit',
  'plans.work.sheet.time_spent',
  'plans.work.sheet.notes',
  'plans.work.sheet.field',
  'plans.work.sheet.field_select',
  'plans.work.sheet.field_optional',
  'plans.work.sheet.submit',
  'plans.work.sheet.task_picker',
  'plans.work.sheet.task_other',
  'plans.work.sheet.show_details',
  'plans.work.sheet.hide_details',
  'plans.work.errors.name_required',
  'plans.errors.invalid_id'
] as const;

/** in locale must not reuse ja copy for primary work-screen labels (visual-review #48). */
const IN_LOCALE_MUST_DIFFER_FROM_JA = [
  'plans.work.nav.work',
  'plans.work.nav.schedule',
  'plans.work.nav.history',
  'plans.work.empty_today',
  'plans.work.show_skipped',
  'plans.work.section.today'
] as const;

const JAPANESE_CHAR = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('plans.work i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of PLANS_WORK_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses Hindi (not ja copy) for in locale work nav and body labels', () => {
    for (const key of IN_LOCALE_MUST_DIFFER_FROM_JA) {
      const inValue = getNested(inLocale as JsonRecord, key) as string;
      const jaValue = getNested(ja as JsonRecord, key) as string;
      expect(inValue, `${key} must not match ja.json`).not.toBe(jaValue);
      expect(inValue, `${key} must not contain Japanese characters`).not.toMatch(JAPANESE_CHAR);
    }
  });
});
