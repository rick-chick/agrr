import { consumePendingToastKey, PendingToastViewEffectDeps } from '../../core/view-effects/pending-toast-view.effects';
import {
  consumePendingUndoToast,
  PendingUndoToastViewEffectDeps
} from '../../core/view-effects/pending-undo-toast-view.effects';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';

interface WorkRecordSheetViewEffectState {
  pendingToastKey: string | null;
  pendingUndoToast: PendingUndoToastRequest | null;
}

type WorkRecordSheetViewEffectDeps = PendingToastViewEffectDeps & PendingUndoToastViewEffectDeps;

export function applyWorkRecordSheetViewEffects<T extends WorkRecordSheetViewEffectState>(
  next: T,
  deps: WorkRecordSheetViewEffectDeps
): T {
  const afterToast = consumePendingToastKey(
    next,
    next.pendingToastKey,
    (state) => ({ ...state, pendingToastKey: null }),
    deps
  );
  return consumePendingUndoToast(afterToast, deps);
}
