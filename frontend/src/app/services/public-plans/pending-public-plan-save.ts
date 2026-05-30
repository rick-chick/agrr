const STORAGE_KEY = 'agrr_pending_public_plan_save';

export interface PendingPublicPlanSave {
  planId: number;
  at: string;
}

export function setPendingPublicPlanSave(planId: number): void {
  try {
    const payload: PendingPublicPlanSave = {
      planId,
      at: new Date().toISOString()
    };
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
  } catch {
    /* sessionStorage unavailable */
  }
}

export function consumePendingPublicPlanSave(): PendingPublicPlanSave | null {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return null;
    }
    sessionStorage.removeItem(STORAGE_KEY);
    const parsed = JSON.parse(raw) as PendingPublicPlanSave;
    if (typeof parsed.planId !== 'number' || parsed.planId <= 0) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}
