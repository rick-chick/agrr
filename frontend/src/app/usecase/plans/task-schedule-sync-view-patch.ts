import { TaskScheduleSyncMessageDto } from './subscribe-task-schedule-sync.dtos';

interface TaskScheduleSyncPlanFields {
  task_schedule_sync_state: string;
  task_schedule_sync_error: string | null;
  task_schedule_sync_error_crop_id: number | null;
}

export interface TaskScheduleSyncViewPatch {
  regenerating: boolean;
  toastI18nKey: string | null;
  requestReload: boolean;
}

export function applySyncFieldsToPlan<T extends TaskScheduleSyncPlanFields>(
  plan: T,
  message: TaskScheduleSyncMessageDto
): T {
  return {
    ...plan,
    task_schedule_sync_state: message.syncState,
    task_schedule_sync_error: message.syncError,
    task_schedule_sync_error_crop_id: message.syncErrorCropId
  };
}

export function taskScheduleSyncViewPatch(syncState: string): TaskScheduleSyncViewPatch {
  if (syncState === 'generating') {
    return {
      regenerating: true,
      toastI18nKey: null,
      requestReload: false
    };
  }
  if (syncState === 'ready') {
    return {
      regenerating: false,
      toastI18nKey: 'plans.task_schedules.sync_updated',
      requestReload: true
    };
  }
  if (syncState === 'failed') {
    return {
      regenerating: false,
      toastI18nKey: null,
      requestReload: true
    };
  }
  return {
    regenerating: false,
    toastI18nKey: null,
    requestReload: false
  };
}
