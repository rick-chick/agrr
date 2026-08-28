import { describe, expect, it } from 'vitest';
import {
  applySyncFieldsToPlan,
  taskScheduleSyncViewPatch
} from './task-schedule-sync-view-patch';

describe('taskScheduleSyncViewPatch', () => {
  it('keeps regenerating true while sync state is generating', () => {
    expect(taskScheduleSyncViewPatch('generating')).toEqual({
      regenerating: true,
      toastI18nKey: null,
      requestReload: false
    });
  });

  it('keeps regenerating true while sync state is stale (superseded regen pending)', () => {
    expect(taskScheduleSyncViewPatch('stale')).toEqual({
      regenerating: true,
      toastI18nKey: null,
      requestReload: false
    });
  });

  it('clears regenerating and requests reload with toast when ready', () => {
    expect(taskScheduleSyncViewPatch('ready')).toEqual({
      regenerating: false,
      toastI18nKey: 'plans.task_schedules.sync_updated',
      requestReload: true
    });
  });

  it('stops regenerating and requests reload without toast when failed', () => {
    expect(taskScheduleSyncViewPatch('failed')).toEqual({
      regenerating: false,
      toastI18nKey: null,
      requestReload: true
    });
  });

  it('returns idle patch for unknown sync states', () => {
    expect(taskScheduleSyncViewPatch('unknown')).toEqual({
      regenerating: false,
      toastI18nKey: null,
      requestReload: false
    });
  });
});

describe('applySyncFieldsToPlan', () => {
  it('merges sync message fields onto plan without mutating the original', () => {
    const plan = {
      id: 7,
      name: 'Plan A',
      task_schedule_sync_state: 'ready',
      task_schedule_sync_error: null,
      task_schedule_sync_error_crop_id: null
    };

    const patched = applySyncFieldsToPlan(plan, {
      syncState: 'generating',
      syncError: 'crop_missing',
      syncErrorCropId: 3
    });

    expect(patched).toEqual({
      id: 7,
      name: 'Plan A',
      task_schedule_sync_state: 'generating',
      task_schedule_sync_error: 'crop_missing',
      task_schedule_sync_error_crop_id: 3
    });
    expect(plan.task_schedule_sync_state).toBe('ready');
  });
});
