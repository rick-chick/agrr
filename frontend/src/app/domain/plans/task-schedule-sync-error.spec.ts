import { describe, expect, it } from 'vitest';
import {
  isActionableDataDeficiencySyncError,
  normalizeTaskScheduleSyncError,
  resolveCropName,
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES
} from './task-schedule-sync-error';

describe('normalizeTaskScheduleSyncError', () => {
  it('keeps known i18n keys', () => {
    const key = 'plans.task_schedules.sync_errors.agrr_unavailable';
    expect(normalizeTaskScheduleSyncError(key)).toBe(key);
  });

  it('maps legacy raw messages to generic key', () => {
    expect(normalizeTaskScheduleSyncError('worker timeout')).toBe(TASK_SCHEDULE_SYNC_ERROR_GENERIC);
  });

  it('returns null for empty values', () => {
    expect(normalizeTaskScheduleSyncError(null)).toBeNull();
    expect(normalizeTaskScheduleSyncError('')).toBeNull();
  });
});

describe('isActionableDataDeficiencySyncError', () => {
  it('returns true for template, blueprint, and general deficiency keys', () => {
    expect(isActionableDataDeficiencySyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES)).toBe(
      true
    );
    expect(isActionableDataDeficiencySyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS)).toBe(
      true
    );
    expect(
      isActionableDataDeficiencySyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES)
    ).toBe(true);
  });

  it('returns false for transient errors', () => {
    expect(isActionableDataDeficiencySyncError(TASK_SCHEDULE_SYNC_ERROR_GENERIC)).toBe(false);
    expect(isActionableDataDeficiencySyncError(null)).toBe(false);
  });
});

describe('resolveCropName', () => {
  it('returns trimmed crop name for known id', () => {
    expect(resolveCropName(3, { 3: ' トマト ' })).toBe('トマト');
  });

  it('returns null when name is missing', () => {
    expect(resolveCropName(3, {})).toBeNull();
  });
});
