import type { PlanWizardReturnTab } from '../../domain/crops/plan-wizard-context';
import {
  BLUEPRINT_WIZARD_SYNC_ERRORS,
  PLAN_CONTEXT_SYNC_ERRORS
} from '../../domain/plans/task-schedule-sync-error';
import {
  TASK_SCHEDULE_SYNC_CROP_STAGES_LINK_KEY,
  TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY,
  TASK_SCHEDULE_SYNC_ERROR_EMPTY_GDD_PROGRESS,
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_ERROR_GDD_DATE_NOT_FOUND,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GDD_TRIGGER,
  TASK_SCHEDULE_SYNC_GDD_DATE_NOT_FOUND_WIZARD_LINK_KEY,
  TASK_SCHEDULE_SYNC_GENERIC_PLAN_LINK_KEY,
  TASK_SCHEDULE_SYNC_MISSING_GDD_TRIGGER_WIZARD_LINK_KEY,
  TASK_SCHEDULE_SYNC_PLAN_CONTEXT_LINK_KEY
} from '../../domain/plans/task-schedule-sync-error-keys';

export function syncErrorWizardLinkKey(syncError: string): string {
  if (syncError === TASK_SCHEDULE_SYNC_ERROR_MISSING_GDD_TRIGGER) {
    return TASK_SCHEDULE_SYNC_MISSING_GDD_TRIGGER_WIZARD_LINK_KEY;
  }
  if (syncError === TASK_SCHEDULE_SYNC_ERROR_GDD_DATE_NOT_FOUND) {
    return TASK_SCHEDULE_SYNC_GDD_DATE_NOT_FOUND_WIZARD_LINK_KEY;
  }
  return TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY;
}

export interface SyncErrorRemediationRoute {
  linkKey: string;
  routerLink: string | (string | number)[];
  queryParams: Record<string, string | number> | null;
}

export function syncErrorRemediationRoute(
  syncError: string | null,
  planId: number,
  returnTab: PlanWizardReturnTab,
  targetCropId: number | null,
  targetCropName: string | null,
  hasTargetCropId: boolean
): SyncErrorRemediationRoute | null {
  if (syncError == null) {
    return null;
  }

  const wizardQuery =
    planId > 0
      ? ({ fromPlan: planId, returnTo: returnTab } as Record<string, string | number>)
      : null;

  if (BLUEPRINT_WIZARD_SYNC_ERRORS.has(syncError)) {
    if (targetCropName || hasTargetCropId) {
      return {
        linkKey: syncErrorWizardLinkKey(syncError),
        routerLink:
          targetCropId != null
            ? ['/crops', targetCropId, 'task_schedule_blueprints']
            : '/crops',
        queryParams: wizardQuery
      };
    }
    return {
      linkKey: `${syncError}_link`,
      routerLink: '/crops',
      queryParams: null
    };
  }

  if (syncError === TASK_SCHEDULE_SYNC_ERROR_EMPTY_GDD_PROGRESS && targetCropId != null) {
    return {
      linkKey: TASK_SCHEDULE_SYNC_CROP_STAGES_LINK_KEY,
      routerLink: ['/crops', targetCropId, 'stages'],
      queryParams: wizardQuery
    };
  }

  if (
    syncError === TASK_SCHEDULE_SYNC_ERROR_EMPTY_GDD_PROGRESS ||
    PLAN_CONTEXT_SYNC_ERRORS.has(syncError)
  ) {
    if (syncError === TASK_SCHEDULE_SYNC_ERROR_GENERIC && planId <= 0) {
      return null;
    }
    return {
      linkKey:
        syncError === TASK_SCHEDULE_SYNC_ERROR_GENERIC
          ? TASK_SCHEDULE_SYNC_GENERIC_PLAN_LINK_KEY
          : TASK_SCHEDULE_SYNC_PLAN_CONTEXT_LINK_KEY,
      routerLink: planId > 0 ? ['/plans', planId] : '/plans',
      queryParams: null
    };
  }

  return null;
}
