import { describe, expect, it } from 'vitest';
import {
  TASK_SCHEDULE_SYNC_ERROR_AGRR_UNAVAILABLE,
  TASK_SCHEDULE_SYNC_ERROR_EMPTY_GDD_PROGRESS,
  TASK_SCHEDULE_SYNC_ERROR_GDD_DATE_NOT_FOUND,
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GDD_TRIGGER,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_START_DATE,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_WEATHER
} from './task-schedule-sync-error-keys';

/**
 * Mirror of `crates/agrr-domain/src/agricultural_task/task_schedule_sync_error_keys.rs`.
 * Update both when adding sync error keys.
 */
const RUST_TASK_SCHEDULE_SYNC_ERROR_KEYS = {
  MISSING_WEATHER: 'plans.task_schedules.sync_errors.missing_weather',
  MISSING_CROP_TEMPLATES: 'plans.task_schedules.sync_errors.missing_crop_templates',
  MISSING_CROP_BLUEPRINTS: 'plans.task_schedules.sync_errors.missing_crop_blueprints',
  MISSING_GENERAL_BLUEPRINTS: 'plans.task_schedules.sync_errors.missing_general_blueprints',
  MISSING_GENERAL_TEMPLATES: 'plans.task_schedules.sync_errors.missing_general_templates',
  EMPTY_GDD_PROGRESS: 'plans.task_schedules.sync_errors.empty_gdd_progress',
  MISSING_GDD_TRIGGER: 'plans.task_schedules.sync_errors.missing_gdd_trigger',
  GDD_DATE_NOT_FOUND: 'plans.task_schedules.sync_errors.gdd_date_not_found',
  MISSING_START_DATE: 'plans.task_schedules.sync_errors.missing_start_date',
  AGRR_UNAVAILABLE: 'plans.task_schedules.sync_errors.agrr_unavailable',
  GENERIC: 'plans.task_schedules.sync_errors.generic'
} as const;

const FRONTEND_KEY_BY_RUST_CONST = {
  MISSING_WEATHER: TASK_SCHEDULE_SYNC_ERROR_MISSING_WEATHER,
  MISSING_CROP_TEMPLATES: TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  MISSING_CROP_BLUEPRINTS: TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  MISSING_GENERAL_BLUEPRINTS: TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS,
  MISSING_GENERAL_TEMPLATES: TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
  EMPTY_GDD_PROGRESS: TASK_SCHEDULE_SYNC_ERROR_EMPTY_GDD_PROGRESS,
  MISSING_GDD_TRIGGER: TASK_SCHEDULE_SYNC_ERROR_MISSING_GDD_TRIGGER,
  GDD_DATE_NOT_FOUND: TASK_SCHEDULE_SYNC_ERROR_GDD_DATE_NOT_FOUND,
  MISSING_START_DATE: TASK_SCHEDULE_SYNC_ERROR_MISSING_START_DATE,
  AGRR_UNAVAILABLE: TASK_SCHEDULE_SYNC_ERROR_AGRR_UNAVAILABLE,
  GENERIC: TASK_SCHEDULE_SYNC_ERROR_GENERIC
} as const;

describe('task-schedule-sync-error-keys Rust contract', () => {
  it('matches task_schedule_sync_error_keys.rs constants', () => {
    for (const rustConst of Object.keys(RUST_TASK_SCHEDULE_SYNC_ERROR_KEYS) as Array<
      keyof typeof RUST_TASK_SCHEDULE_SYNC_ERROR_KEYS
    >) {
      expect(FRONTEND_KEY_BY_RUST_CONST[rustConst]).toBe(RUST_TASK_SCHEDULE_SYNC_ERROR_KEYS[rustConst]);
    }
  });
});
