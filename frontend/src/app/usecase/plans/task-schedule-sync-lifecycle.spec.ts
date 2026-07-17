import { describe, expect, it } from 'vitest';
import {
  applyTaskScheduleSyncMessage,
  beginScheduleLoad,
  finishTaskScheduleLoad,
  initialTaskScheduleSyncLifecycleState,
  isStaleScheduleLoad,
  markRegeneratePostInFlight,
  receiveTaskScheduleSyncMessage,
  resolveRegenerating,
  taskScheduleSyncMessageFromRegenerateResponse
} from './task-schedule-sync-lifecycle';

describe('task-schedule-sync-lifecycle', () => {
  it('resolveRegenerating is true when sync state is generating', () => {
    expect(resolveRegenerating('generating', initialTaskScheduleSyncLifecycleState())).toBe(true);
  });

  it('resolveRegenerating is true while regenerate POST is in flight', () => {
    const lifecycle = markRegeneratePostInFlight(initialTaskScheduleSyncLifecycleState());
    expect(resolveRegenerating('ready', lifecycle)).toBe(true);
  });

  it('receiveTaskScheduleSyncMessage defers when entity is not loaded', () => {
    const result = receiveTaskScheduleSyncMessage(
      initialTaskScheduleSyncLifecycleState(),
      { syncState: 'ready', syncError: null, syncErrorCropId: null },
      false
    );

    expect(result.deferred).toBe(true);
    expect(result.lifecycle.pendingSyncMessage?.syncState).toBe('ready');
  });

  it('finishTaskScheduleLoad merges deferred sync on present', () => {
    const lifecycle = {
      pendingSyncMessage: {
        syncState: 'ready',
        syncError: null,
        syncErrorCropId: null
      },
      regeneratePostInFlight: false,
      scheduleLoadGeneration: 0
    };

    const result = finishTaskScheduleLoad(lifecycle, 'generating');

    expect(result.pendingMerge?.syncState).toBe('ready');
    expect(result.regenerating).toBe(false);
    expect(result.toastI18nKey).toBe('plans.task_schedules.sync_updated');
    expect(result.requestReload).toBe(true);
    expect(result.lifecycle.pendingSyncMessage).toBeNull();
  });

  it('finishTaskScheduleLoad keeps regenerating when loaded state is generating', () => {
    const result = finishTaskScheduleLoad(initialTaskScheduleSyncLifecycleState(), 'generating');

    expect(result.pendingMerge).toBeNull();
    expect(result.regenerating).toBe(true);
  });

  it('applyTaskScheduleSyncMessage keeps regenerating when deferred message is generating', () => {
    const result = applyTaskScheduleSyncMessage({
      lifecycle: initialTaskScheduleSyncLifecycleState(),
      message: { syncState: 'generating', syncError: null, syncErrorCropId: null },
      entityLoaded: false,
      currentSyncReloadNonce: 0
    });

    expect(result.appliedToEntity).toBe(false);
    expect(result.regenerating).toBe(true);
  });

  it('applyTaskScheduleSyncMessage applies patch when entity is loaded', () => {
    const result = applyTaskScheduleSyncMessage({
      lifecycle: initialTaskScheduleSyncLifecycleState(),
      message: { syncState: 'ready', syncError: null, syncErrorCropId: null },
      entityLoaded: true,
      currentSyncReloadNonce: 2
    });

    expect(result.appliedToEntity).toBe(true);
    expect(result.regenerating).toBe(false);
    expect(result.pendingSyncToastKey).toBe('plans.task_schedules.sync_updated');
    expect(result.syncReloadNonce).toBe(3);
  });

  it('taskScheduleSyncMessageFromRegenerateResponse maps POST body', () => {
    expect(
      taskScheduleSyncMessageFromRegenerateResponse({
        success: true,
        task_schedule_sync_state: 'generating'
      })
    ).toEqual({
      syncState: 'generating',
      syncError: null,
      syncErrorCropId: null
    });
  });

  it('beginScheduleLoad increments generation and isStaleScheduleLoad rejects older loads', () => {
    const first = beginScheduleLoad(initialTaskScheduleSyncLifecycleState());
    const second = beginScheduleLoad(first.lifecycle);

    expect(first.generation).toBe(1);
    expect(second.generation).toBe(2);
    expect(isStaleScheduleLoad(second.lifecycle, first.generation)).toBe(true);
    expect(isStaleScheduleLoad(second.lifecycle, second.generation)).toBe(false);
  });

  it('applyTaskScheduleSyncMessage requests reload when poll exhausts while generating', () => {
    const result = applyTaskScheduleSyncMessage({
      lifecycle: initialTaskScheduleSyncLifecycleState(),
      message: {
        syncState: 'generating',
        syncError: null,
        syncErrorCropId: null,
        pollExhausted: true
      },
      entityLoaded: true,
      currentSyncReloadNonce: 4
    });

    expect(result.regenerating).toBe(true);
    expect(result.syncReloadNonce).toBe(5);
    expect(result.appliedToEntity).toBe(true);
  });
});
