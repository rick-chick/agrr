import { TaskScheduleSyncMessageDto } from '../../usecase/plans/subscribe-task-schedule-sync.dtos';
import {
  syncErrorDetailTranslateKey,
  syncErrorDetailTranslateParams
} from '../../core/task-schedule-sync-error-i18n';
import {
  syncErrorRemediationRoute,
  syncErrorWizardLinkKey
} from './task-schedule-sync-remediation.mapper';
import {
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_PLAN_REVIEW_LINK_KEY
} from '../../domain/plans/task-schedule-sync-error-keys';
import {
  cropPlanWizardQueryParams,
  type CropPlanWizardQueryParams,
  type PlanWizardReturnTab
} from '../../domain/crops/plan-wizard-context';
import {
  isActionableDataDeficiencySyncError,
  resolveCropName,
  type TaskScheduleSyncCropNames
} from '../../domain/plans/task-schedule-sync-error';
import type { PlanRemediationCrop } from '../../models/plans/task-schedule';
import type { TaskScheduleSyncState } from '../../domain/plans/task-schedule-sync-state';

export interface CropBannerEntry {
  cropId: number;
  label: string;
}

export { applySyncFieldsToPlan, taskScheduleSyncViewPatch } from '../../usecase/plans/task-schedule-sync-view-patch';

export function buildCropBannerContext(
  fields: Array<{ crop_id: number; crop_name?: string | null }>
): { cropIds: number[]; cropNames: Record<number, string> } {
  const cropIds = [...new Set(fields.map((field) => field.crop_id).filter((id) => id > 0))];
  const cropNames: Record<number, string> = {};
  for (const field of fields) {
    if (field.crop_id > 0 && field.crop_name?.trim()) {
      cropNames[field.crop_id] = field.crop_name.trim();
    }
  }
  return { cropIds, cropNames };
}

export function buildCropBannerEntries(
  cropIds: number[],
  cropNames: Record<number, string>
): CropBannerEntry[] {
  const uniqueIds = [...new Set(cropIds.filter((id) => id > 0))];
  return uniqueIds.map((cropId) => {
    const name = cropNames[cropId]?.trim();
    return {
      cropId,
      label: name && name.length > 0 ? name : `#${cropId}`
    };
  });
}

export function shouldOfferCropWizardLinks(
  syncError: string | null,
  cropEntries: CropBannerEntry[],
  hasSingleRemediationTarget: boolean
): boolean {
  if (cropEntries.length === 0) {
    return false;
  }
  if (syncError === TASK_SCHEDULE_SYNC_ERROR_GENERIC) {
    return true;
  }
  if (isActionableDataDeficiencySyncError(syncError)) {
    if (hasSingleRemediationTarget) {
      return false;
    }
    return true;
  }
  return false;
}

export function mergeCropBannerContext(
  fields: Array<{ crop_id: number; crop_name?: string | null }>,
  planCrops: PlanRemediationCrop[] | null | undefined
): { cropIds: number[]; cropNames: Record<number, string> } {
  const fromFields = buildCropBannerContext(fields);
  if (fromFields.cropIds.length > 0) {
    return fromFields;
  }
  return buildCropBannerContext(
    (planCrops ?? []).map((crop) => ({
      crop_id: crop.crop_id,
      crop_name: crop.crop_name
    }))
  );
}

export interface TaskScheduleSyncBannerViewModel {
  visible: boolean;
  showHeadline: boolean;
  messageKey: string;
  bannerClass: string;
  syncErrorDetailKey: string | null;
  syncErrorDetailParams: { cropName?: string };
  remediationLinkKey: string | null;
  remediationLinkParams: { cropName: string };
  showCropWizardLinks: boolean;
  cropBannerEntries: CropBannerEntry[];
  cropWizardLinkKey: string;
  cropsRouterLink: string | (string | number)[];
  cropMasterQueryParams: CropPlanWizardQueryParams | Record<string, string | number> | null;
  showRetry: boolean;
}

export interface TaskScheduleSyncBannerViewInput {
  syncState: TaskScheduleSyncState | string;
  syncError: string | null;
  cropIds: number[];
  cropNames: TaskScheduleSyncCropNames;
  planId: number;
  syncErrorCropId: number | null;
  regenerateError: string | null;
  returnTab?: PlanWizardReturnTab;
}

function uniqueCropIds(cropIds: number[]): number[] {
  return [...new Set(cropIds.filter((id) => id > 0))];
}

function syncStatePlanRemediationRoute(
  syncState: TaskScheduleSyncState | string,
  planId: number
): { linkKey: string; routerLink: (string | number)[]; queryParams: null } | null {
  if ((syncState !== 'never' && syncState !== 'stale') || planId <= 0) {
    return null;
  }
  return {
    linkKey: TASK_SCHEDULE_SYNC_PLAN_REVIEW_LINK_KEY,
    routerLink: ['/plans', planId],
    queryParams: null
  };
}

function resolveTargetCropId(
  syncErrorCropId: number | null,
  cropIds: number[]
): number | null {
  if (syncErrorCropId != null && syncErrorCropId > 0) {
    return syncErrorCropId;
  }
  const ids = uniqueCropIds(cropIds);
  return ids.length === 1 ? ids[0] : null;
}

function resolveCropBannerEntries(
  syncError: string | null,
  syncErrorCropId: number | null,
  cropIds: number[],
  cropNames: TaskScheduleSyncCropNames
): CropBannerEntry[] {
  const entries = buildCropBannerEntries(uniqueCropIds(cropIds), cropNames);
  if (
    syncError === TASK_SCHEDULE_SYNC_ERROR_GENERIC &&
    syncErrorCropId != null &&
    syncErrorCropId > 0 &&
    !entries.some((entry) => entry.cropId === syncErrorCropId)
  ) {
    const name = resolveCropName(syncErrorCropId, cropNames);
    return [...entries, { cropId: syncErrorCropId, label: name ?? `#${syncErrorCropId}` }];
  }
  return entries;
}

export function buildTaskScheduleSyncBannerViewModel(
  input: TaskScheduleSyncBannerViewInput
): TaskScheduleSyncBannerViewModel {
  const targetCropId = resolveTargetCropId(input.syncErrorCropId, input.cropIds);
  const targetCropName = resolveCropName(targetCropId, input.cropNames);
  const cropBannerEntries = resolveCropBannerEntries(
    input.syncError,
    input.syncErrorCropId,
    input.cropIds,
    input.cropNames
  );
  const showCropWizardLinks = shouldOfferCropWizardLinks(
    input.syncError,
    cropBannerEntries,
    targetCropId != null
  );
  const fallbackName =
    cropBannerEntries.length === 1 ? cropBannerEntries[0].label : null;
  const detailCropName =
    targetCropName ??
    (fallbackName && !fallbackName.startsWith('#') ? fallbackName : null);
  const returnTab = input.returnTab ?? 'task_schedule';
  const wizardQueryParams =
    input.planId > 0 ? cropPlanWizardQueryParams(input.planId, returnTab) : null;
  const remediation = showCropWizardLinks
    ? null
    : syncErrorRemediationRoute(
        input.syncError,
        input.planId,
        returnTab,
        targetCropId,
        targetCropName,
        targetCropId != null
      ) ??
      syncStatePlanRemediationRoute(input.syncState, input.planId);
  const remediationLinkKey = remediation?.linkKey ?? null;
  const showRetry =
    input.syncState !== 'generating' &&
    (input.syncState === 'never' ||
      input.syncState === 'stale' ||
      (input.syncState === 'failed' &&
        (input.syncError === TASK_SCHEDULE_SYNC_ERROR_GENERIC ||
          (!isActionableDataDeficiencySyncError(input.syncError) && !showCropWizardLinks))));

  return {
    visible:
      input.syncState === 'never' ||
      input.syncState === 'failed' ||
      input.syncState === 'generating' ||
      input.syncState === 'stale',
    showHeadline: input.syncState !== 'failed' || !input.syncError,
    messageKey: `plans.task_schedules.sync_${input.syncState}`,
    bannerClass:
      input.syncState === 'failed' || input.regenerateError
        ? 'page-alert-error task-schedule-sync-banner'
        : input.syncState === 'stale'
          ? 'page-alert-warning task-schedule-sync-banner'
          : 'page-alert-info task-schedule-sync-banner',
    syncErrorDetailKey: syncErrorDetailTranslateKey(
      input.syncError,
      targetCropName,
      cropBannerEntries.length
    ),
    syncErrorDetailParams: syncErrorDetailTranslateParams(detailCropName),
    remediationLinkKey,
    remediationLinkParams: {
      cropName: targetCropName ?? (targetCropId != null ? `#${targetCropId}` : '')
    },
    showCropWizardLinks,
    cropBannerEntries,
    cropWizardLinkKey: syncErrorWizardLinkKey(input.syncError!),
    cropsRouterLink:
      remediation?.routerLink ??
      (targetCropId != null
        ? ['/crops', targetCropId, 'task_schedule_blueprints']
        : '/crops'),
    cropMasterQueryParams:
      remediation?.queryParams ?? (showCropWizardLinks ? wizardQueryParams : null),
    showRetry
  };
}
