const TASK_SCHEDULE_SYNC_ERROR_PREFIX = 'plans.task_schedules.sync_errors.';

export const TASK_SCHEDULE_SYNC_ERROR_GENERIC = `${TASK_SCHEDULE_SYNC_ERROR_PREFIX}generic`;
export const TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES = `${TASK_SCHEDULE_SYNC_ERROR_PREFIX}missing_crop_templates`;
export const TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS = `${TASK_SCHEDULE_SYNC_ERROR_PREFIX}missing_crop_blueprints`;
export const TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES = `${TASK_SCHEDULE_SYNC_ERROR_PREFIX}missing_general_templates`;
export const TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS = `${TASK_SCHEDULE_SYNC_ERROR_PREFIX}missing_general_blueprints`;

export { TASK_SCHEDULE_SYNC_ERROR_PREFIX };

const NAMED_DETAIL_SYNC_ERRORS = new Set([
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_GENERIC
]);

export function syncErrorDetailTranslateKey(
  syncError: string | null,
  cropName: string | null,
  planCropCount = 0
): string | null {
  if (syncError == null) {
    return null;
  }
  if (syncError === TASK_SCHEDULE_SYNC_ERROR_GENERIC) {
    if (planCropCount === 0) {
      return `${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_no_plan_crops`;
    }
    if (planCropCount === 1 && cropName) {
      return `${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_single`;
    }
    if (planCropCount > 1) {
      return `${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_multi`;
    }
  }
  if (cropName && NAMED_DETAIL_SYNC_ERRORS.has(syncError)) {
    return `${syncError}_named`;
  }
  return syncError;
}

export function syncErrorDetailTranslateParams(
  cropName: string | null
): { cropName?: string } {
  return cropName ? { cropName } : {};
}

export const TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY = `${TASK_SCHEDULE_SYNC_ERROR_PREFIX}crop_wizard_link`;

export function cropMasterRemediationLinkKey(
  syncError: string | null,
  _syncState: string,
  cropName: string | null,
  hasTargetCropId: boolean
): string | null {
  const actionableErrors = new Set([
    TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
    TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
    TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
    TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS
  ]);

  if (syncError != null && actionableErrors.has(syncError)) {
    if (cropName || hasTargetCropId) {
      return TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY;
    }
    return `${syncError}_link`;
  }
  return null;
}
