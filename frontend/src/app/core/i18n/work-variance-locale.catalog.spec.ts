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

const WORK_VARIANCE_I18N_KEYS = [
  'work.variance.title',
  'work.variance.subtitle',
  'work.variance.error_subtitle',
  'work.variance.retry',
  'work.variance.no_plans',
  'work.variance.no_plans_hint',
  'work.variance.create_plan_link',
  'work.variance.no_filter_results',
  'work.variance.portfolio_summary.title',
  'work.variance.portfolio_summary.unrecorded',
  'work.variance.portfolio_summary.action_required',
  'work.variance.portfolio_summary.gdd_delay',
  'work.variance.portfolio_summary.threshold_exceeded',
  'work.variance.filters.title',
  'work.variance.filters.farm',
  'work.variance.filters.status',
  'work.variance.filters.year',
  'work.variance.filters.all',
  'work.variance.attention_list.title',
  'work.variance.attention_list.item',
  'work.variance.table.year',
  'work.variance.table.status',
  'work.variance.table.unrecorded',
  'work.variance.table.gdd_delay',
  'work.variance.table.threshold_exceeded',
  'work.variance.table.actions',
  'work.variance.table.work_link',
  'work.variance.table.learn_link',
  'work.variance.table.plan_link',
  'work.variance.status.completed',
  'work.variance.status.pending',
  'work.variance.status.optimizing',
  'work.variance.status.failed'
] as const;

describe('work variance i18n catalog', () => {
  it.each([
    ['ja', ja],
    ['en', en],
    ['in', inLocale]
  ] as const)('defines work variance keys in %s', (_label, locale) => {
    for (const key of WORK_VARIANCE_I18N_KEYS) {
      const value = getNested(locale as JsonRecord, key);
      expect(typeof value).toBe('string');
      expect((value as string).length).toBeGreaterThan(0);
    }
  });
});
