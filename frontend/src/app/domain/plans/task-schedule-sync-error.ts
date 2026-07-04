import {
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_PREFIX
} from '../../core/task-schedule-sync-error-i18n';

export {
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES
} from '../../core/task-schedule-sync-error-i18n';

const ACTIONABLE_DATA_DEFICIENCY_SYNC_ERRORS = new Set([
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES
]);

export type TaskScheduleSyncCropNames = Record<number, string>;

export function isActionableDataDeficiencySyncError(syncError: string | null): boolean {
  return syncError != null && ACTIONABLE_DATA_DEFICIENCY_SYNC_ERRORS.has(syncError);
}

export function resolveCropName(
  cropId: number | null,
  cropNames: TaskScheduleSyncCropNames
): string | null {
  if (cropId == null) {
    return null;
  }
  const name = cropNames[cropId]?.trim();
  return name ? name : null;
}

export function normalizeTaskScheduleSyncError(syncError: string | null): string | null {
  if (syncError == null || syncError === '') {
    return null;
  }
  if (syncError.startsWith(TASK_SCHEDULE_SYNC_ERROR_PREFIX)) {
    return syncError;
  }
  return TASK_SCHEDULE_SYNC_ERROR_GENERIC;
}
