import { TaskScheduleSyncMessageDto } from '../../usecase/plans/subscribe-task-schedule-sync.dtos';
import {
  cropMasterRemediationLinkKey,
  cropWizardFragmentForSyncError,
  syncErrorDetailTranslateKey,
  syncErrorDetailTranslateParams,
  TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY,
  TASK_SCHEDULE_SYNC_ERROR_GENERIC
} from '../../core/task-schedule-sync-error-i18n';
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

interface TaskScheduleSyncPlanFields {
  task_schedule_sync_state: string;
  task_schedule_sync_error: string | null;
  task_schedule_sync_error_crop_id: number | null;
}

interface TaskScheduleSyncViewPatch {
  regenerating: boolean;
  toastI18nKey: string | null;
  requestReload: boolean;
}

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
  cropWizardFragment: string;
  cropWizardLinkKey: string;
  cropsRouterLink: string | (string | number)[];
  cropMasterQueryParams: { fromPlan: number } | null;
  showGenericPlanLink: boolean;
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
}

function uniqueCropIds(cropIds: number[]): number[] {
  return [...new Set(cropIds.filter((id) => id > 0))];
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
  const remediationLinkKey = showCropWizardLinks
    ? null
    : cropMasterRemediationLinkKey(
        input.syncError,
        input.syncState,
        targetCropName,
        targetCropId != null
      );
  const showGenericPlanLink =
    input.syncError === TASK_SCHEDULE_SYNC_ERROR_GENERIC &&
    cropBannerEntries.length === 0 &&
    input.planId > 0;
  const showRetry =
    input.syncState !== 'generating' &&
    input.syncState !== 'stale' &&
    !isActionableDataDeficiencySyncError(input.syncError) &&
    !showCropWizardLinks &&
    !showGenericPlanLink &&
    !(
      input.syncError === TASK_SCHEDULE_SYNC_ERROR_GENERIC && targetCropName != null
    );

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
    cropWizardFragment: cropWizardFragmentForSyncError(input.syncError),
    cropWizardLinkKey: TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY,
    cropsRouterLink: targetCropId != null ? ['/crops', targetCropId] : '/crops',
    cropMasterQueryParams: input.planId > 0 ? { fromPlan: input.planId } : null,
    showGenericPlanLink,
    showRetry
  };
}
