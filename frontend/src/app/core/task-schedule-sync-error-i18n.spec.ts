import { describe, expect, it } from 'vitest';
import {
  syncErrorDetailTranslateKey,
  syncErrorDetailTranslateParams,
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_EMPTY_GDD_PROGRESS
} from './task-schedule-sync-error-i18n';

describe('syncErrorDetailTranslateKey', () => {
  it('uses single-crop detail key for generic errors with one plan crop', () => {
    expect(syncErrorDetailTranslateKey(TASK_SCHEDULE_SYNC_ERROR_GENERIC, 'トマト', 1)).toBe(
      `${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_single`
    );
  });

  it('uses no-crop detail key when plan crops are unknown', () => {
    expect(syncErrorDetailTranslateKey(TASK_SCHEDULE_SYNC_ERROR_GENERIC, null, 0)).toBe(
      `${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_no_plan_crops`
    );
  });

  it('uses multi-crop detail key for generic errors with multiple plan crops', () => {
    expect(syncErrorDetailTranslateKey(TASK_SCHEDULE_SYNC_ERROR_GENERIC, null, 2)).toBe(
      `${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_multi`
    );
  });

  it('uses named detail keys when crop name is known', () => {
    expect(
      syncErrorDetailTranslateKey(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS, 'トマト')
    ).toBe(`${TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS}_named`);
  });

  it('uses named detail key for empty gdd progress when crop name is known', () => {
    expect(
      syncErrorDetailTranslateKey(TASK_SCHEDULE_SYNC_ERROR_EMPTY_GDD_PROGRESS, 'Tomato')
    ).toBe(`${TASK_SCHEDULE_SYNC_ERROR_EMPTY_GDD_PROGRESS}_named`);
  });

  it('falls back to base key without crop name', () => {
    expect(syncErrorDetailTranslateKey(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS, null)).toBe(
      TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS
    );
  });
});

describe('syncErrorDetailTranslateParams', () => {
  it('passes cropName only when present', () => {
    expect(syncErrorDetailTranslateParams('トマト')).toEqual({ cropName: 'トマト' });
    expect(syncErrorDetailTranslateParams(null)).toEqual({});
  });
});
