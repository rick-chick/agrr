import {
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_ERROR_GDD_DATE_NOT_FOUND,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GDD_TRIGGER,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_START_DATE,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_WEATHER,
  TASK_SCHEDULE_SYNC_ERROR_PREFIX
} from './task-schedule-sync-error-keys';

export {
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS
} from './task-schedule-sync-error-keys';

export const ACTIONABLE_DATA_DEFICIENCY_SYNC_ERRORS = new Set([
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GDD_TRIGGER,
  TASK_SCHEDULE_SYNC_ERROR_GDD_DATE_NOT_FOUND
]);

/** Blueprint wizard remediation uses the same actionable deficiency errors. */
export const BLUEPRINT_WIZARD_SYNC_ERRORS = ACTIONABLE_DATA_DEFICIENCY_SYNC_ERRORS;

export const PLAN_CONTEXT_SYNC_ERRORS = new Set([
  TASK_SCHEDULE_SYNC_ERROR_MISSING_WEATHER,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_START_DATE,
  TASK_SCHEDULE_SYNC_ERROR_GENERIC
]);

export type TaskScheduleSyncCropNames = Record<number, string>;

export function isActionableDataDeficiencySyncError(syncError: string | null): boolean {
  return syncError != null && ACTIONABLE_DATA_DEFICIENCY_SYNC_ERRORS.has(syncError);
}

export function isBlueprintWizardSyncError(syncError: string | null): boolean {
  return isActionableDataDeficiencySyncError(syncError);
}

export function isPlanContextSyncError(syncError: string | null): boolean {
  return syncError != null && PLAN_CONTEXT_SYNC_ERRORS.has(syncError);
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
