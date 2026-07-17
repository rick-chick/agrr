import { TaskScheduleSyncMessageDto } from './subscribe-task-schedule-sync.dtos';
import { RegenerateTaskScheduleResponseDto } from './regenerate-task-schedule-response.dtos';
import {
  applySyncFieldsToPlan,
  taskScheduleSyncViewPatch
} from './task-schedule-sync-view-patch';

export const TASK_SCHEDULE_SYNC_POLL_INTERVAL_MS = 250;
export const TASK_SCHEDULE_SYNC_POLL_MAX_ATTEMPTS = 120;

export interface TaskScheduleSyncLifecycleState {
  pendingSyncMessage: TaskScheduleSyncMessageDto | null;
  regeneratePostInFlight: boolean;
  scheduleLoadGeneration: number;
}

export function initialTaskScheduleSyncLifecycleState(): TaskScheduleSyncLifecycleState {
  return {
    pendingSyncMessage: null,
    regeneratePostInFlight: false,
    scheduleLoadGeneration: 0
  };
}

export function beginScheduleLoad(
  lifecycle: TaskScheduleSyncLifecycleState
): { lifecycle: TaskScheduleSyncLifecycleState; generation: number } {
  const generation = lifecycle.scheduleLoadGeneration + 1;
  return {
    lifecycle: { ...lifecycle, scheduleLoadGeneration: generation },
    generation
  };
}

export function isStaleScheduleLoad(
  lifecycle: TaskScheduleSyncLifecycleState,
  loadGeneration: number
): boolean {
  return loadGeneration < lifecycle.scheduleLoadGeneration;
}

export function resolveRegenerating(
  syncState: string | null | undefined,
  lifecycle: Pick<TaskScheduleSyncLifecycleState, 'regeneratePostInFlight'>
): boolean {
  return lifecycle.regeneratePostInFlight || syncState === 'generating';
}

export function markRegeneratePostInFlight(
  lifecycle: TaskScheduleSyncLifecycleState
): TaskScheduleSyncLifecycleState {
  return { ...lifecycle, regeneratePostInFlight: true };
}

export function clearRegeneratePostInFlight(
  lifecycle: TaskScheduleSyncLifecycleState
): TaskScheduleSyncLifecycleState {
  return { ...lifecycle, regeneratePostInFlight: false };
}

export function taskScheduleSyncMessageFromRegenerateResponse(
  response: RegenerateTaskScheduleResponseDto
): TaskScheduleSyncMessageDto {
  return {
    syncState: response.task_schedule_sync_state,
    syncError: null,
    syncErrorCropId: null
  };
}

export function receiveTaskScheduleSyncMessage(
  lifecycle: TaskScheduleSyncLifecycleState,
  message: TaskScheduleSyncMessageDto,
  entityLoaded: boolean
): {
  lifecycle: TaskScheduleSyncLifecycleState;
  deferred: boolean;
  viewPatch: ReturnType<typeof taskScheduleSyncViewPatch> | null;
} {
  if (!entityLoaded) {
    return {
      lifecycle: { ...lifecycle, pendingSyncMessage: message },
      deferred: true,
      viewPatch: null
    };
  }

  return {
    lifecycle: {
      pendingSyncMessage: null,
      regeneratePostInFlight: false,
      scheduleLoadGeneration: lifecycle.scheduleLoadGeneration
    },
    deferred: false,
    viewPatch: taskScheduleSyncViewPatch(message.syncState)
  };
}

export function finishTaskScheduleLoad(
  lifecycle: TaskScheduleSyncLifecycleState,
  loadedSyncState: string
): {
  lifecycle: TaskScheduleSyncLifecycleState;
  pendingMerge: TaskScheduleSyncMessageDto | null;
  regenerating: boolean;
  toastI18nKey: string | null;
  requestReload: boolean;
} {
  const pending = lifecycle.pendingSyncMessage;
  const nextLifecycle: TaskScheduleSyncLifecycleState = {
    pendingSyncMessage: null,
    regeneratePostInFlight: false,
    scheduleLoadGeneration: lifecycle.scheduleLoadGeneration
  };

  if (pending) {
    const patch = taskScheduleSyncViewPatch(pending.syncState);
    return {
      lifecycle: nextLifecycle,
      pendingMerge: pending,
      regenerating: resolveRegenerating(pending.syncState, nextLifecycle),
      toastI18nKey: patch.toastI18nKey,
      requestReload: patch.requestReload
    };
  }

  return {
    lifecycle: nextLifecycle,
    pendingMerge: null,
    regenerating: resolveRegenerating(loadedSyncState, nextLifecycle),
    toastI18nKey: null,
    requestReload: false
  };
}

export interface ApplyTaskScheduleSyncMessageInput {
  lifecycle: TaskScheduleSyncLifecycleState;
  message: TaskScheduleSyncMessageDto;
  entityLoaded: boolean;
  currentSyncReloadNonce: number;
}

export interface ApplyTaskScheduleSyncMessageResult {
  lifecycle: TaskScheduleSyncLifecycleState;
  regenerating: boolean;
  pendingSyncToastKey: string | null;
  syncReloadNonce: number;
  appliedToEntity: boolean;
  message: TaskScheduleSyncMessageDto;
}

export function applyTaskScheduleSyncMessage(
  input: ApplyTaskScheduleSyncMessageInput
): ApplyTaskScheduleSyncMessageResult {
  const received = receiveTaskScheduleSyncMessage(
    input.lifecycle,
    input.message,
    input.entityLoaded
  );

  if (received.deferred) {
    return {
      lifecycle: received.lifecycle,
      regenerating: resolveRegenerating(input.message.syncState, received.lifecycle),
      pendingSyncToastKey: null,
      syncReloadNonce: input.currentSyncReloadNonce,
      appliedToEntity: false,
      message: input.message
    };
  }

  const patch = received.viewPatch!;
  const pollExhaustedWhileGenerating =
    input.message.pollExhausted === true && input.message.syncState === 'generating';
  return {
    lifecycle: received.lifecycle,
    regenerating: pollExhaustedWhileGenerating ? true : patch.regenerating,
    pendingSyncToastKey: patch.toastI18nKey,
    syncReloadNonce:
      patch.requestReload || pollExhaustedWhileGenerating
        ? input.currentSyncReloadNonce + 1
        : input.currentSyncReloadNonce,
    appliedToEntity: true,
    message: input.message
  };
}

export function mergePlanWithSyncMessage<T extends Parameters<typeof applySyncFieldsToPlan>[0]>(
  plan: T,
  message: TaskScheduleSyncMessageDto
): T {
  return applySyncFieldsToPlan(plan, message);
}

export function isTaskScheduleSyncPollable(syncState: string): boolean {
  return syncState === 'generating';
}
