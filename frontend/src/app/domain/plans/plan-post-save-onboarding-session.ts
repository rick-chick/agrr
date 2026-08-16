const PENDING_KEY = 'agrr.planPostSave.pending';
const DISMISSED_KEY = 'agrr.planPostSave.dismissed';

function readPendingPlanIds(): Set<number> {
  if (typeof sessionStorage === 'undefined') {
    return new Set();
  }
  const raw = sessionStorage.getItem(PENDING_KEY);
  if (!raw) {
    return new Set();
  }
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) {
      return new Set();
    }
    return new Set(parsed.filter((id): id is number => typeof id === 'number' && id > 0));
  } catch {
    return new Set();
  }
}

function writePendingPlanIds(ids: Set<number>): void {
  if (typeof sessionStorage === 'undefined') {
    return;
  }
  if (ids.size === 0) {
    sessionStorage.removeItem(PENDING_KEY);
    return;
  }
  sessionStorage.setItem(PENDING_KEY, JSON.stringify([...ids]));
}

function readDismissedPlanIds(): Set<number> {
  if (typeof sessionStorage === 'undefined') {
    return new Set();
  }
  const raw = sessionStorage.getItem(DISMISSED_KEY);
  if (!raw) {
    return new Set();
  }
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) {
      return new Set();
    }
    return new Set(parsed.filter((id): id is number => typeof id === 'number' && id > 0));
  } catch {
    return new Set();
  }
}

function writeDismissedPlanIds(ids: Set<number>): void {
  if (typeof sessionStorage === 'undefined') {
    return;
  }
  if (ids.size === 0) {
    sessionStorage.removeItem(DISMISSED_KEY);
    return;
  }
  sessionStorage.setItem(DISMISSED_KEY, JSON.stringify([...ids]));
}

export function markPlanPostSaveOnboarding(planId: number): void {
  if (!Number.isFinite(planId) || planId <= 0) {
    return;
  }
  const pending = readPendingPlanIds();
  pending.add(planId);
  writePendingPlanIds(pending);
}

export function shouldShowPlanPostSaveBanner(planId: number): boolean {
  if (!Number.isFinite(planId) || planId <= 0) {
    return false;
  }
  const dismissed = readDismissedPlanIds();
  if (dismissed.has(planId)) {
    return false;
  }
  return readPendingPlanIds().has(planId);
}

export function dismissPlanPostSaveBanner(planId: number): void {
  if (!Number.isFinite(planId) || planId <= 0) {
    return;
  }
  const dismissed = readDismissedPlanIds();
  dismissed.add(planId);
  writeDismissedPlanIds(dismissed);

  const pending = readPendingPlanIds();
  pending.delete(planId);
  writePendingPlanIds(pending);
}

export function clearPlanPostSaveOnboardingSession(): void {
  if (typeof sessionStorage === 'undefined') {
    return;
  }
  sessionStorage.removeItem(PENDING_KEY);
  sessionStorage.removeItem(DISMISSED_KEY);
}
