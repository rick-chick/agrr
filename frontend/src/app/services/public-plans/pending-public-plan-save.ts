import {
  PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY,
  readBrowserStorageItem,
  removeBrowserStorageItem,
  writeBrowserStorageItem
} from './public-plan-browser-storage';

export interface PendingPublicPlanSave {
  planId: number;
  at: string;
}

export function setPendingPublicPlanSave(planId: number): boolean {
  const payload: PendingPublicPlanSave = {
    planId,
    at: new Date().toISOString()
  };
  return writeBrowserStorageItem(
    PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY,
    JSON.stringify(payload)
  ).ok;
}

export function peekPendingPublicPlanSave(): PendingPublicPlanSave | null {
  try {
    const raw = readBrowserStorageItem(PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY);
    if (!raw) {
      return null;
    }
    const parsed = JSON.parse(raw) as PendingPublicPlanSave;
    if (typeof parsed.planId !== 'number' || parsed.planId <= 0) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

export function clearPendingPublicPlanSave(): void {
  removeBrowserStorageItem(PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY);
}
