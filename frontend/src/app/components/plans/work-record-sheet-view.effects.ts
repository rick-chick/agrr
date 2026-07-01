import { consumePendingToastKey, PendingToastViewEffectDeps } from './pending-toast-view.effects';

interface WorkRecordSheetViewEffectState {
  pendingToastKey: string | null;
}

export function applyWorkRecordSheetViewEffects<T extends WorkRecordSheetViewEffectState>(
  next: T,
  deps: PendingToastViewEffectDeps
): T {
  return consumePendingToastKey(
    next,
    next.pendingToastKey,
    (state) => ({ ...state, pendingToastKey: null }),
    deps
  );
}
