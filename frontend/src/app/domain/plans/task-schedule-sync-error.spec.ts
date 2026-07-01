import { describe, expect, it } from 'vitest';
import {
  normalizeTaskScheduleSyncError,
  TASK_SCHEDULE_SYNC_ERROR_GENERIC
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
