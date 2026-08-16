const PENDING_KEY = 'agrr.planPostSaveOnboarding.pending';
const DISMISSED_KEY_PREFIX = 'agrr.planPostSaveOnboarding.dismissed';

function dismissedKey(planId: number): string {
  return `${DISMISSED_KEY_PREFIX}.${planId}`;
}

export function markPlanPostSaveOnboardingPending(planId: number): void {
  if (typeof sessionStorage === 'undefined' || planId <= 0) {
    return;
  }
  try {
    sessionStorage.setItem(PENDING_KEY, JSON.stringify({ planId }));
  } catch {
    /* sessionStorage unavailable */
  }
}

export function consumePlanPostSaveOnboardingPending(planId: number): boolean {
  if (typeof sessionStorage === 'undefined' || planId <= 0) {
    return false;
  }
  try {
    const raw = sessionStorage.getItem(PENDING_KEY);
    if (!raw) {
      return false;
    }
    const parsed = JSON.parse(raw) as { planId?: number };
    if (parsed.planId !== planId) {
      return false;
    }
    sessionStorage.removeItem(PENDING_KEY);
    return true;
  } catch {
    sessionStorage.removeItem(PENDING_KEY);
    return false;
  }
}

export function isPlanPostSaveOnboardingDismissed(planId: number): boolean {
  if (typeof sessionStorage === 'undefined' || planId <= 0) {
    return false;
  }
  return sessionStorage.getItem(dismissedKey(planId)) === '1';
}

export function dismissPlanPostSaveOnboarding(planId: number): void {
  if (typeof sessionStorage === 'undefined' || planId <= 0) {
    return;
  }
  try {
    sessionStorage.setItem(dismissedKey(planId), '1');
  } catch {
    /* sessionStorage unavailable */
  }
}

export function shouldShowPlanPostSaveOnboardingBanner(planId: number): boolean {
  if (planId <= 0 || isPlanPostSaveOnboardingDismissed(planId)) {
    return false;
  }
  return consumePlanPostSaveOnboardingPending(planId);
}
