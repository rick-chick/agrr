import { consumePendingToastKey, PendingToastRequest, PendingToastViewEffectDeps } from '../../core/view-effects/pending-toast-view.effects';
import {
  consumePendingUndoToast,
  PendingUndoToastViewEffectDeps
} from '../../core/view-effects/pending-undo-toast-view.effects';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';

interface WorkRecordSheetViewEffectState {
  pendingToast: PendingToastRequest | null;
  pendingUndoToast: PendingUndoToastRequest | null;
}

type WorkRecordSheetViewEffectDeps = PendingToastViewEffectDeps & PendingUndoToastViewEffectDeps;

export function applyWorkRecordSheetViewEffects<T extends WorkRecordSheetViewEffectState>(
  next: T,
  deps: WorkRecordSheetViewEffectDeps
): T {
  const afterToast = consumePendingToastKey(
    next,
    next.pendingToast,
    (state) => ({ ...state, pendingToast: null }),
    deps
  );
  return consumePendingUndoToast(afterToast, deps);
}
