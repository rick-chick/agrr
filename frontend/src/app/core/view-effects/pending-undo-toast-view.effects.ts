import { UndoToastService } from '../../services/undo-toast.service';

export type PendingUndoToastRequest = {
  message: string;
  undoPath: string;
  undoToken: string;
  onRestored?: () => void;
  resourceLabel?: string;
};

interface PendingUndoToastViewEffectDeps {
  toast: Pick<UndoToastService, 'showWithUndo'>;
}

export function consumePendingUndoToast<T extends { pendingUndoToast: PendingUndoToastRequest | null }>(
  state: T,
  deps: PendingUndoToastViewEffectDeps
): T {
  const pending = state.pendingUndoToast;
  if (!pending) {
    return state;
  }
  deps.toast.showWithUndo(
    pending.message,
    pending.undoPath,
    pending.undoToken,
    pending.onRestored,
    pending.resourceLabel
  );
  return { ...state, pendingUndoToast: null };
}

/** Component control setter で pending undo toast を消費する。 */
export const applyPendingUndoToastViewEffects = consumePendingUndoToast;
