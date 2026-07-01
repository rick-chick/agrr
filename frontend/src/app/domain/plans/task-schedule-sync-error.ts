const TASK_SCHEDULE_SYNC_ERROR_PREFIX = 'plans.task_schedules.sync_errors.';
export const TASK_SCHEDULE_SYNC_ERROR_GENERIC = `${TASK_SCHEDULE_SYNC_ERROR_PREFIX}generic`;

export function normalizeTaskScheduleSyncError(syncError: string | null): string | null {
  if (syncError == null || syncError === '') {
    return null;
  }
  if (syncError.startsWith(TASK_SCHEDULE_SYNC_ERROR_PREFIX)) {
    return syncError;
  }
  return TASK_SCHEDULE_SYNC_ERROR_GENERIC;
}
