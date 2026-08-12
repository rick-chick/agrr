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

/** Keys referenced by plan-task-schedule and task-schedule-month-list components. */
const PLANS_TASK_SCHEDULE_KEYS = [
  'plans.task_schedules.page_title',
  'plans.show.nav.aria_label',
  'plans.show.nav.workbench',
  'plans.show.nav.task_schedule',
  'plans.show.nav.learn',
  'plans.work.nav.work',
  'plans.work.nav.history',
  'plans.work.retry',
  'plans.task_schedules.empty_hint',
  'plans.task_schedules.empty_ready_no_fields',
  'plans.task_schedules.empty_fields_summary',
  'plans.task_schedules.empty_fields_no_tasks_hint',
  'plans.task_schedules.empty_cta',
  'plans.task_schedules.no_schedules',
  'plans.task_schedules.status.planned',
  'plans.task_schedules.status.skipped',
  'plans.task_schedules.status.completed',
  'plans.task_schedules.summary',
  'plans.task_schedules.filter_field',
  'plans.task_schedules.filter_all_fields',
  'plans.task_schedules.filter_from_date',
  'plans.task_schedules.list_empty',
  'plans.task_schedules.list_row_meta',
  'plans.task_schedules.unscheduled_title',
  'plans.task_schedules.timeline_generated_at',
  'plans.task_schedules.timeline_generated_unknown',
  'plans.task_schedules.sync_never',
  'plans.task_schedules.sync_failed',
  'plans.task_schedules.sync_generating',
  'plans.task_schedules.sync_stale',
  'plans.task_schedules.sync_plan_link',
  'plans.task_schedules.sync_updated',
  'plans.task_schedules.sync_retry',
  'plans.task_schedules.regenerate_confirm',
  'plans.task_schedules.sync_wizard_cta_hint',
  'plans.task_schedules.sync_errors.missing_weather',
  'plans.task_schedules.sync_errors.missing_crop_templates',
  'plans.task_schedules.sync_errors.missing_crop_templates_named',
  'plans.task_schedules.sync_errors.missing_crop_templates_link',
  'plans.task_schedules.sync_errors.missing_crop_blueprints',
  'plans.task_schedules.sync_errors.missing_crop_blueprints_named',
  'plans.task_schedules.sync_errors.missing_crop_blueprints_link',
  'plans.task_schedules.sync_errors.missing_general_templates',
  'plans.task_schedules.sync_errors.missing_general_templates_named',
  'plans.task_schedules.sync_errors.missing_general_templates_link',
  'plans.task_schedules.sync_errors.missing_general_blueprints',
  'plans.task_schedules.sync_errors.missing_general_blueprints_named',
  'plans.task_schedules.sync_errors.missing_general_blueprints_link',
  'plans.task_schedules.sync_errors.empty_gdd_progress',
  'plans.task_schedules.sync_errors.empty_gdd_progress_named',
  'plans.task_schedules.sync_errors.missing_gdd_trigger',
  'plans.task_schedules.sync_errors.missing_gdd_trigger_named',
  'plans.task_schedules.sync_errors.missing_gdd_trigger_link',
  'plans.task_schedules.sync_errors.missing_gdd_trigger_wizard_link',
  'plans.task_schedules.sync_errors.gdd_date_not_found',
  'plans.task_schedules.sync_errors.gdd_date_not_found_named',
  'plans.task_schedules.sync_errors.gdd_date_not_found_link',
  'plans.task_schedules.sync_errors.gdd_date_not_found_wizard_link',
  'plans.task_schedules.sync_errors.missing_start_date',
  'plans.task_schedules.sync_errors.agrr_unavailable',
  'plans.task_schedules.sync_errors.generic',
  'plans.task_schedules.sync_errors.generic_single',
  'plans.task_schedules.sync_errors.generic_multi',
  'plans.task_schedules.sync_errors.generic_no_plan_crops',
  'plans.task_schedules.sync_errors.crop_wizard_link',
  'plans.task_schedules.sync_errors.plan_context_link',
  'plans.task_schedules.sync_errors.crop_stages_link',
  'plans.task_schedules.sync_errors.generic_plan_link',
  'plans.task_schedules.detail.dialog_title',
  'plans.task_schedules.detail.empty',
  'plans.task_schedules.detail.stage',
  'plans.task_schedules.detail.amount',
  'plans.task_schedules.detail.master_description',
  'plans.task_schedules.detail.not_applicable',
  'plans.task_schedules.detail.variance_heading',
  'plans.task_schedules.detail.scheduled_date',
  'plans.task_schedules.detail.actual_date',
  'plans.task_schedules.detail.delta_days',
  'plans.task_schedules.detail.planned_gdd',
  'plans.task_schedules.detail.actual_gdd',
  'plans.task_schedules.detail.gdd_delta',
  'plans.task_schedules.variance.month_average',
  'plans.task_schedules.variance.badge.unrecorded',
  'plans.task_schedules.variance.badge.on_time',
  'plans.task_schedules.variance.badge.late',
  'plans.task_schedules.variance.badge.early',
  'plans.task_schedules.variance_summary_line',
  'plans.task_schedules.open_learn',
  'plans.learn.page_title',
  'plans.task_schedules.variance_subview.toggle_aria',
  'plans.task_schedules.variance_subview.view_list',
  'plans.task_schedules.variance_subview.view_variance',
  'plans.task_schedules.variance_subview.summary_title',
  'plans.task_schedules.variance_subview.summary_completed',
  'plans.task_schedules.variance_subview.summary_average_delta',
  'plans.task_schedules.variance_subview.summary_unrecorded',
  'plans.task_schedules.variance_subview.categories_title',
  'plans.task_schedules.variance_subview.category_column',
  'plans.task_schedules.variance_subview.category_average',
  'plans.task_schedules.variance_subview.category_recorded',
  'plans.task_schedules.variance_subview.top_variance_title',
  'plans.task_schedules.variance_subview.top_item_dates',
  'plans.task_schedules.variance_subview.unrecorded_title',
  'plans.task_schedules.variance_subview.open_in_schedule',
  'plans.task_schedules.variance_subview.no_data',
  'plans.task_schedules.variance_subview.delta_value',
  'plans.task_schedules.variance_subview.average_value',
  'plans.task_schedules.variance_subview.not_available',
  'plans.task_schedules.variance_subview.category.general',
  'plans.task_schedules.variance_subview.category.fertilizer',
  'plans.task_schedules.variance_subview.category.unscheduled'
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
