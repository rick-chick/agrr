import { describe, expect, it } from 'vitest';
import {
  applySyncFieldsToPlan,
  taskScheduleSyncViewPatch
} from './task-schedule-sync-presenter.helpers';

describe('taskScheduleSyncViewPatch', () => {
  it('marks generating state as in-flight regeneration', () => {
    expect(taskScheduleSyncViewPatch('generating')).toEqual({
      regenerating: true,
      toastI18nKey: null,
      requestReload: false
    });
  });

  it('marks ready state for toast and reload', () => {
    expect(taskScheduleSyncViewPatch('ready')).toEqual({
      regenerating: false,
      toastI18nKey: 'plans.task_schedules.sync_updated',
      requestReload: true
    });
  });

  it('marks stale state as banner-only update', () => {
    expect(taskScheduleSyncViewPatch('stale')).toEqual({
      regenerating: false,
      toastI18nKey: null,
      requestReload: false
    });
  });

  it('marks failed state for reload without toast', () => {
    expect(taskScheduleSyncViewPatch('failed')).toEqual({
      regenerating: false,
      toastI18nKey: null,
      requestReload: true
    });
  });
});

describe('applySyncFieldsToPlan', () => {
  it('copies sync fields onto the plan snapshot', () => {
    const plan = {
      id: 7,
      task_schedule_sync_state: 'ready',
      task_schedule_sync_error: null
    };

    expect(
      applySyncFieldsToPlan(plan, {
        syncState: 'failed',
        syncError: 'plans.task_schedules.sync_errors.agrr_unavailable'
      })
    ).toEqual({
      id: 7,
      task_schedule_sync_state: 'failed',
      task_schedule_sync_error: 'plans.task_schedules.sync_errors.agrr_unavailable'
    });
  });
});
